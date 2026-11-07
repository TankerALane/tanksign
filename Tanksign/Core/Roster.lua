-- Core/Roster.lua
-- Collects plain roster facts (unit, name, role, Main Tank flag) and asks TankLogic
-- who the tanks are. Secret values become "unknown" and are never compared.

local _, ns = ...
local Compat = ns.Compat

local Roster = {}
ns.Roster = Roster

Roster.tanks = {}        -- list of unit tokens
Roster.source = "none"   -- which source produced them

local function plainCall(path, ...)
    local fn = Compat.Resolve(path)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return Compat.Plain(a), Compat.Plain(b)
end
Roster.PlainCall = plainCall

function Roster.Members()
    local members = {}
    if plainCall("IsInRaid") then
        local n = plainCall("GetNumGroupMembers") or 0
        for i = 1, math.min(n, 40) do
            local unit = "raid" .. i
            local name, roleColumn
            local getInfo = _G.GetRaidRosterInfo
            if type(getInfo) == "function" then
                -- returns name, rank, subgroup, level, class, fileName, zone, online, isDead, role, ...
                local ok, n, _, _, _, _, _, _, _, _, role = pcall(getInfo, i)
                if ok then name, roleColumn = Compat.Plain(n), Compat.Plain(role) end
            end
            members[#members + 1] = {
                unit = unit, name = name, role = plainCall("UnitGroupRolesAssigned", unit),
                mainTank = roleColumn == "MAINTANK",
            }
        end
    else
        local units = { "player" }
        if plainCall("IsInGroup") then
            local n = plainCall("GetNumGroupMembers") or 0
            for i = 1, math.min(math.max(n - 1, 0), 4) do units[#units + 1] = "party" .. i end
        end
        for _, unit in ipairs(units) do
            members[#members + 1] = {
                unit = unit, name = plainCall("UnitName", unit), role = plainCall("UnitGroupRolesAssigned", unit),
                mainTank = plainCall("GetPartyAssignment", "MAINTANK", unit) == true,
            }
        end
    end
    return members
end

function Roster.Update()
    local s = ns.db.settings
    local before = table.concat(Roster.tanks, ",") .. "|" .. Roster.source
    Roster.tanks, Roster.source = ns.TankLogic.FindTanks(Roster.Members(), s.tankSource, s.tankName)
    local after = table.concat(Roster.tanks, ",") .. "|" .. Roster.source
    if before ~= after then
        ns.Log.Debug("tanks: %s (source %s)", #Roster.tanks > 0 and table.concat(Roster.tanks, ", ") or "none", Roster.source)
        if ns.Keys then ns.Keys.Update() end
    end
end

-- The unit whose target the "skull the tank's target" key marks: the first tank,
-- "target" when the first tank is you, nil when tanks come from threat only.
function Roster.MainTankUnit()
    if Roster.source == "threat" or Roster.source == "none" then return nil end
    return Roster.tanks[1]
end

-- Threat facts for one mob: a list with one entry per tank (number, nil or "?").
function Roster.ThreatStatuses(mobUnit)
    local list = {}
    local fn = _G.UnitThreatSituation
    for i, tank in ipairs(Roster.tanks) do
        local value
        if type(fn) == "function" then
            local ok, s = pcall(fn, tank, mobUnit)
            if ok then value = Compat.Plain(s, ns.TankLogic.UNKNOWN) else value = ns.TankLogic.UNKNOWN end
        else
            value = ns.TankLogic.UNKNOWN
        end
        list[i] = value
    end
    return list, #Roster.tanks
end

function Roster.InGroupFacts()
    local inInstance = plainCall("IsInInstance")
    return { inGroup = plainCall("IsInGroup") == true, inInstance = inInstance == true }
end
