-- The probe check list: well formed, unique, documented.
local H = ...

local KINDS = { api = true, event = true, custom = true, manual = true }

H.test("check ids are unique and well formed", function()
    local ns = H.pureNamespace()
    local seen = {}
    for _, c in ipairs(ns.ProbeChecks) do
        H.ok(KINDS[c.kind], c.id .. " has unknown kind " .. tostring(c.kind))
        H.ok(not seen[c.id], "duplicate id " .. c.id)
        seen[c.id] = true
        H.ok(type(c.area) == "string" and c.area ~= "", c.id .. " needs an area")
        H.ok(type(c.why) == "string" and c.why ~= "", c.id .. " needs a why")
        if c.kind == "event" then H.ok(c.id:find("^ev:[A-Z_]+$"), c.id) end
        if c.kind == "custom" then H.ok(c.id:find("^x:"), c.id) end
        if c.kind == "manual" then H.ok(c.id:find("^m:"), c.id) end
        if c.kind == "api" then H.ok(c.id:find("^[%a_][%w_%.]*$"), c.id) end
    end
end)

H.test("the APIs the brief asks about are all probed", function()
    local ns = H.pureNamespace()
    local ids = {}
    for _, c in ipairs(ns.ProbeChecks) do ids[c.id] = true end
    for _, id in ipairs({ "UnitDetailedThreatSituation", "UnitThreatSituation", "SetRaidTarget", "GetRaidTargetIndex",
        "UnitGroupRolesAssigned", "GetPartyAssignment", "C_NamePlate.GetNamePlates", "ev:NAME_PLATE_UNIT_ADDED",
        "ev:NAME_PLATE_UNIT_REMOVED", "UnitIsUnit", "UnitAffectingCombat", "InCombatLockdown", "x:units.sample",
        "x:mark.test", "x:target.test" }) do
        H.ok(ids[id], "missing check " .. id)
    end
end)

H.test("the combat log and chat are never probed", function()
    local ns = H.pureNamespace()
    for _, c in ipairs(ns.ProbeChecks) do
        H.ok(not c.id:find("COMBAT_LOG"), c.id)
        H.ok(not c.id:find("CHAT_MSG"), c.id)
    end
end)

H.test("one check per line, as the doc generator expects", function()
    local src = H.readFile("Tanksign/Debug/ProbeChecks.lua")
    local lines = 0
    for line in src:gmatch("[^\n]+") do
        if line:find("^%s*{ id =") then
            lines = lines + 1
            H.ok(line:find("},%s*$"), "check not on one line: " .. line)
        end
    end
    H.eq(lines, #H.pureNamespace().ProbeChecks)
end)

H.test("every check is in docs/API-VERIFICATION.md", function()
    local doc = H.readFile("docs/API-VERIFICATION.md")
    for _, c in ipairs(H.pureNamespace().ProbeChecks) do
        H.ok(doc:find("`" .. c.id .. "`", 1, true), c.id .. " missing from the doc; run python tools/gen_verify_doc.py")
    end
end)
