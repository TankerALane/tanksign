-- Pure logic: settings, tank detection, held status, active state.
local H = ...

H.test("settings: defaults fill missing and invalid values", function()
    local S = H.pureNamespace().Settings
    local s = S.Apply({ marker = 12, scale = 0.7, tankSource = "nonsense", enabled = false, maxRows = 3.5 })
    H.eq(s.marker, 8)
    H.eq(s.scale, 0.7)
    H.eq(s.tankSource, "auto")
    H.eq(s.enabled, false)
    H.eq(s.maxRows, 8)
    H.eq(S.Apply(nil).enabled, true)
end)

H.test("settings: migration from the probe build turns combat sampling off", function()
    local S = H.pureNamespace().Settings
    local db = S.Migrate({ schema = 1, settings = { enabled = true, debug = true }, probe = { combatSampling = true } })
    H.eq(db.schema, 2)
    H.eq(db.probe.combatSampling, false)
    H.eq(db.settings.debug, true)
    H.eq(db.settings.marker, 8)
    local fresh = S.Migrate(nil)
    H.eq(fresh.schema, 2)
    H.eq(fresh.settings.enabled, true)
    local newer = S.Migrate({ schema = 9, settings = {} })
    H.eq(newer.schema, 9)
    H.eq(newer.newerSchema, 9)
end)

H.test("settings: number parsing", function()
    local S = H.pureNamespace().Settings
    H.eq(S.ParseNumber("1.5", 0.5, 2), 1.5)
    H.eq(S.ParseNumber("3", 0.5, 2), nil)
    H.eq(S.ParseNumber("abc", 0, 10), nil)
end)

local members = {
    { unit = "player", name = "Healbot", role = "HEALER" },
    { unit = "party1", name = "Stabby-Realm", role = "DAMAGER" },
    { unit = "party2", name = "Shieldy", role = "TANK" },
    { unit = "party3", name = "Bigbear", role = "DAMAGER", mainTank = true },
}

H.test("tanks: auto prefers role, then Main Tank, then name, then threat", function()
    local T = H.pureNamespace().TankLogic
    local t, src = T.FindTanks(members, "auto", "")
    H.eq(table.concat(t, ","), "party2"); H.eq(src, "role")
    local noRole = {
        { unit = "player", role = "NONE", name = "A" }, { unit = "party1", role = "NONE", name = "B", mainTank = true },
        { unit = "party2", role = "NONE", name = "C" },
    }
    t, src = T.FindTanks(noRole, "auto", "c")
    H.eq(table.concat(t, ","), "party1"); H.eq(src, "maintank")
    noRole[2].mainTank = false
    t, src = T.FindTanks(noRole, "auto", " C ")
    H.eq(table.concat(t, ","), "party2"); H.eq(src, "name")
    t, src = T.FindTanks(noRole, "auto", "")
    H.eq(#t, 3); H.eq(src, "threat")
end)

H.test("tanks: explicit sources, several tanks, realm names", function()
    local T = H.pureNamespace().TankLogic
    local two = { { unit = "raid1", role = "TANK" }, { unit = "raid2", role = "TANK" }, { unit = "raid3", role = "HEALER" } }
    local t = T.FindTanks(two, "role")
    H.eq(table.concat(t, ","), "raid1,raid2")
    local _, src = T.FindTanks(members, "maintank")
    H.eq(src, "maintank")
    t, src = T.FindTanks(members, "name", "stabby")
    H.eq(table.concat(t, ","), "party1"); H.eq(src, "name")
    t, src = T.FindTanks(members, "name", "nobody")
    H.eq(#t, 0); H.eq(src, "none")
    t, src = T.FindTanks({ { unit = "player", role = "DAMAGER" } }, "role")
    H.eq(src, "none")
    t, src = T.FindTanks(members, "threat")
    H.eq(#t, 4); H.eq(src, "threat")
end)

H.test("held: top threat by any tank; nil is 'not on list'; '?' is unknown", function()
    local T = H.pureNamespace().TankLogic
    H.eq(T.IsHeld({ 3 }, 1), true)
    H.eq(T.IsHeld({ 2 }, 1), true)
    H.eq(T.IsHeld({ 1 }, 1), false)
    H.eq(T.IsHeld({ nil, 3 }, 2), true)
    H.eq(T.IsHeld({ nil, nil }, 2), false)
    H.eq(T.IsHeld({ "?", 0 }, 2), nil)
    H.eq(T.IsHeld({ "?", 3 }, 2), true)
    H.eq(T.IsHeld({}, 0), nil)
end)

H.test("active: enabled flag and only-in-group", function()
    local A = H.pureNamespace().ActiveLogic
    local s = { enabled = true, onlyInGroup = false, showPanel = true, showToggle = true }
    H.eq((A.IsActive(s, { inGroup = false })), true)
    s.onlyInGroup = true
    H.eq((A.IsActive(s, { inGroup = false, inInstance = false })), false)
    H.eq((A.IsActive(s, { inGroup = false, inInstance = true })), true)
    s.enabled = false
    local active, why = A.IsActive(s, { inGroup = true })
    H.eq(active, false); H.eq(why, "disabled")
end)

H.test("panel state: out of combat applies, in combat only fades and defers", function()
    local A = H.pureNamespace().ActiveLogic
    local s = { showPanel = true, showToggle = true }
    local st = A.PanelState(s, false, false, true)
    H.eq(st.show, true); H.eq(st.rows, false); H.eq(st.faded, false)
    s.showToggle = false
    st = A.PanelState(s, false, false, true)
    H.eq(st.show, false)
    st = A.PanelState(s, false, true, true)
    H.eq(st.show, true); H.eq(st.faded, true); H.eq(st.deferred, true)
    st = A.PanelState(s, true, true, true)
    H.eq(st.rows, true); H.eq(st.faded, false)
end)

H.test("row tags: boss, rare, elite, caster; unknown facts add nothing", function()
    local R = H.pureNamespace().RowLogic
    H.eq(table.concat(R.Tags({ classification = "elite", powerType = 0 }), " "), "E C")
    H.eq(table.concat(R.Tags({ classification = "rareelite" }), " "), "R E")
    H.eq(table.concat(R.Tags({ classification = "worldboss", powerType = 1 }), " "), "B")
    H.eq(table.concat(R.Tags({ classification = "normal", powerType = 3 }), " "), "")
    H.eq(#R.Tags({}), 0)
end)

H.test("row dimming: critters, wild and non-combat pets, totems, player pets", function()
    local R = H.pureNamespace().RowLogic
    H.eq(select(2, R.Dim({ creatureTypeId = 8 })), "critter")
    H.eq(select(2, R.Dim({ creatureTypeId = 14 })), "critter")
    H.eq(select(2, R.Dim({ creatureTypeId = 11 })), "totem")
    H.eq(select(2, R.Dim({ creatureTypeId = 7, playerControlled = true })), "pet")
    H.eq((R.Dim({ creatureTypeId = 7 })), false)
    H.eq((R.Dim({})), false, "secret creature type: no dimming")
end)
