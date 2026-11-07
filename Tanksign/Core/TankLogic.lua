-- Core/TankLogic.lua
-- PURE: must not touch WoW globals at load time.
-- Decides who the tanks are from plain roster facts, and whether a mob is "held"
-- by a tank from plain threat facts. The WoW side collects the facts; anything
-- that came back secret arrives here as nil (unknown).

local _, ns = ...

local TankLogic = {}
ns.TankLogic = TankLogic

-- members: list of { unit = "party3", name = "Tankname", role = "TANK"|..., mainTank = bool }
-- source:  "auto" | "role" | "maintank" | "name" | "threat"
-- Returns tanks (list of unit tokens) and the source actually used:
--   "role", "maintank", "name", "threat" (everyone counts: top threat decides), or "none".
local function byRole(members)
    local out = {}
    for _, m in ipairs(members) do if m.role == "TANK" then out[#out + 1] = m.unit end end
    return out
end

local function byMainTank(members)
    local out = {}
    for _, m in ipairs(members) do if m.mainTank == true then out[#out + 1] = m.unit end end
    return out
end

local function normalize(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name:lower()
end

local function byName(members, wanted)
    local out = {}
    local want = normalize(wanted)
    if want == "" then return out end
    for _, m in ipairs(members) do
        local n = normalize(m.name)
        -- "Name" matches "Name" and "Name-Realm".
        if n == want or n:match("^([^%-]+)") == want then out[#out + 1] = m.unit end
    end
    return out
end

local function everyone(members)
    local out = {}
    for _, m in ipairs(members) do out[#out + 1] = m.unit end
    return out
end

function TankLogic.FindTanks(members, source, fixedName)
    members = members or {}
    if source == "role" then
        local t = byRole(members)
        return t, #t > 0 and "role" or "none"
    elseif source == "maintank" then
        local t = byMainTank(members)
        return t, #t > 0 and "maintank" or "none"
    elseif source == "name" then
        local t = byName(members, fixedName)
        return t, #t > 0 and "name" or "none"
    elseif source == "threat" then
        return everyone(members), "threat"
    end
    -- auto: the brief's priority order
    local t = byRole(members)
    if #t > 0 then return t, "role" end
    t = byMainTank(members)
    if #t > 0 then return t, "maintank" end
    t = byName(members, fixedName)
    if #t > 0 then return t, "name" end
    return everyone(members), "threat"
end

-- Threat status (UnitThreatSituation): 0 lower threat, 1 higher threat but not
-- tanking, 2 tanking insecurely, 3 tanking securely. "Held" = top threat = 2 or 3.
-- statuses: one entry per tank: a number, nil (not on the mob's threat list, counts
-- as 0) or "?" (the value was secret: unknown).
-- Returns true (a tank holds it), false (no tank does) or nil (cannot tell).
TankLogic.UNKNOWN = "?"

function TankLogic.IsHeld(statuses, count)
    count = count or #statuses
    if count == 0 then return nil end
    local unknown = false
    for i = 1, count do
        local s = statuses[i]
        if s == TankLogic.UNKNOWN then
            unknown = true
        elseif type(s) == "number" and s >= 2 then
            return true
        end
    end
    if unknown then return nil end
    return false
end
