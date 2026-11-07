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
    local ns = H.pureNamespace()
    local db = S.Migrate({ schema = 1, settings = { enabled = true, debug = true }, probe = { combatSampling = true } })
    H.eq(db.schema, 3)
    H.eq(db.probe.combatSampling, false)
    H.eq(db.settings, nil, "settings moved into profiles")
    local active = ns.Profiles.Ensure(db)
    H.eq(db.profile, "Default")
    H.eq(active.debug, true)
    H.eq(active.marker, 8)
    local fresh = S.Migrate(nil)
    H.eq(fresh.schema, 3)
    H.eq(ns.Profiles.Ensure(fresh).enabled, true)
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

H.test("profiles: create copies, switch, cycle, delete rules, auto choice, reset", function()
    local ns = H.pureNamespace()
    local P = ns.Profiles
    local db = {}
    local s = P.Ensure(db)
    H.eq(db.profile, "Default")
    s.marker = 7
    H.eq(P.Create(db, "  Dungeon ", nil), "Dungeon")
    H.eq(db.profiles.Dungeon.marker, 7, "copied from the active profile")
    H.eq(select(2, P.Create(db, "Dungeon")), "PROFILE_EXISTS")
    H.eq(select(2, P.Create(db, "")), "PROFILE_BAD_NAME")
    H.eq(select(2, P.Create(db, string.rep("x", 30))), "PROFILE_BAD_NAME")
    H.eq(P.Next(db), "Dungeon")
    H.ok(P.Switch(db, "Dungeon"))
    H.eq(P.Next(db), "Default")
    H.eq(P.Switch(db, "Nope"), nil)
    H.eq(select(2, P.Delete(db, "Dungeon")), "PROFILE_ACTIVE")
    P.Create(db, "Raid")
    db.manualProfile = "Default"
    H.eq(P.ForInstance(db, "party"), "Dungeon")
    H.eq(P.ForInstance(db, "raid"), "Raid")
    H.eq(P.ForInstance(db, "none"), "Default")
    H.ok(P.Delete(db, "Raid"))
    H.eq(P.ForInstance(db, "raid"), "Default")
    local r = P.Reset(db.profiles.Dungeon)
    H.eq(r.marker, 8)
    db.profile = "Gone"
    P.Ensure(db)
    H.eq(db.profile, "Default")
end)

H.test("someone else's marker change: forget when it cannot be explained", function()
    local M = H.pureNamespace().MarkLogic
    -- square on your skull mob: nothing visible changes
    H.eq(M.Unexplained(M.Diff({ nameplate1 = "marked", nameplate2 = "marked" },
        { nameplate1 = "marked", nameplate2 = "marked" })), true)
    -- your X moved onto your skull mob: the X mob reads unmarked, nothing new is marked
    local g, l = M.Diff({ nameplate1 = "marked", nameplate2 = "marked" }, { nameplate1 = "marked", nameplate2 = "none" })
    H.eq(g, 0); H.eq(l, 1); H.eq(M.Unexplained(g, l), true)
    -- a marker moved to an unmarked mob, or a new marker on an unmarked mob: explained
    H.eq(M.Unexplained(M.Diff({ nameplate1 = "marked", nameplate3 = "none" },
        { nameplate1 = "none", nameplate3 = "marked" })), false)
    H.eq(M.Unexplained(M.Diff({ nameplate3 = "none" }, { nameplate3 = "marked" })), false)
    -- plates that came or went are not counted
    H.eq(select(2, M.Diff({ nameplate9 = "marked" }, {})), 0)
    -- our own click, just before or just after the event, explains it
    local c = { firstAt = 10, lastAt = 10.1, gains = 0, losses = 0 }
    H.eq(M.ShouldForget(c, 10.08), false)
    H.eq(M.ShouldForget(c, 9.5), false)
    H.eq(M.ShouldForget(c, 5), true)
    H.eq(M.ShouldForget(c, nil), true)
    local s = M.New()
    M.Place(s, 8, "nameplate1"); M.Place(s, 7, "nameplate2")
    H.eq(M.HasAny(s), true)
    M.Forget(s)
    H.eq(M.HasAny(s), false); H.eq(M.Get(s, "nameplate1"), nil); H.eq(s.byMarker[7], nil)
end)

H.test("marking rights: party yes, raid only leader or assistant", function()
    local A = H.pureNamespace().ActiveLogic
    H.eq(A.CanMark({ inRaid = false, leader = false }), true)
    H.eq(A.CanMark({ inRaid = true, leader = false, assist = false }), false)
    H.eq(A.CanMark({ inRaid = true, leader = true }), true)
    H.eq(A.CanMark({ inRaid = true, leader = false, assist = true }), true)
    H.eq(A.CanMark({ inRaid = true, leader = false, everyoneAssist = true }), true)
end)

H.test("mark memory: place, move, replace, observe, removed", function()
    local M = H.pureNamespace().MarkLogic
    local s = M.New()
    M.Place(s, 8, "nameplate1")
    M.Place(s, 7, "nameplate2")
    H.eq(M.Get(s, "nameplate1"), 8)
    H.eq(M.Get(s, "nameplate2"), 7)
    M.Place(s, 8, "nameplate3")              -- skull moves
    H.eq(M.Get(s, "nameplate1"), nil)
    H.eq(M.Get(s, "nameplate3"), 8)
    M.Place(s, 7, "nameplate3")              -- cross on the skull mob replaces its skull
    H.eq(M.Get(s, "nameplate3"), 7)
    H.eq(s.byMarker[8], nil)
    H.eq(M.Get(s, "nameplate2"), nil, "cross moved away from nameplate2")
    M.Observe(s, "nameplate3", "hidden")
    H.eq(M.Get(s, "nameplate3"), 7, "hidden keeps memory")
    M.Observe(s, "nameplate3", "none")
    H.eq(M.Get(s, "nameplate3"), nil, "plain nil clears")
    -- a fresh click: the unit still reads unmarked for a moment
    M.Place(s, 8, "nameplate4", 100)
    M.Observe(s, "nameplate4", "none", 100.2)
    H.eq(M.Get(s, "nameplate4"), 8, "not cleared before the click arrives")
    M.Observe(s, "nameplate4", "hidden", 100.5) -- may be the old marker
    M.Observe(s, "nameplate4", "none", 101)     -- the swap reads unmarked for a moment
    H.eq(M.Get(s, "nameplate4"), 8, "still in the grace time")
    M.Observe(s, "nameplate4", "hidden", 102)
    M.Observe(s, "nameplate4", "none", 104)
    H.eq(M.Get(s, "nameplate4"), nil, "after the grace time, unmarked clears")
    M.Place(s, 7, "nameplate6", 200)
    M.Observe(s, "nameplate6", "none", 202)
    H.eq(M.Get(s, "nameplate6"), 7)
    M.Observe(s, "nameplate6", "none", 203.5)
    H.eq(M.Get(s, "nameplate6"), nil, "never arrived (no rights): cleared after the grace time")
    M.Observe(s, "nameplate5", 8)
    H.eq(M.Get(s, "nameplate5"), 8, "a readable marker is learned")
    M.Removed(s, "nameplate5")
    H.eq(M.Get(s, "nameplate5"), nil)
    H.eq(s.byMarker[8], nil)
end)
