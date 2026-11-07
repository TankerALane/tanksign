-- Runtime smoke tests: the whole addon against tests/wowmock.lua.
local H = ...
local M = require("wowmock")

local function boot(opts)
    local env, ctl = M.new(opts)
    ctl.load(H.ROOT)
    ctl.fire("ADDON_LOADED", "Tanksign")
    ctl.fire("PLAYER_LOGIN")
    return env, ctl
end

local function hostile(ctl, token, fields)
    local u = { name = "Defias Thug", guid = "Creature-0-1-2-3-" .. token, hostile = true, combat = true, hp = 900,
        hpMax = 1000, isTanking = true, threatStatus = 3, threatPct = 100, threatValue = 5000 }
    for k, v in pairs(fields or {}) do u[k] = v end
    ctl.units[token] = u
    return u
end

H.test("loads on Forever, creates only the allowed globals", function()
    local env, ctl = boot()
    H.ok(ctl.chatText():find("v0.9.1 loaded", 1, true), ctl.chatText())
    H.eq(type(env.TanksignDB), "table")
    H.eq(env.TanksignDB.profiles.Default.enabled, true)
    H.eq(table.concat(ctl.newGlobals(), ","), table.concat({ "BINDING_HEADER_TANKSIGN",
        "BINDING_NAME_CLICK TanksignSkullMouseover:LeftButton", "BINDING_NAME_CLICK TanksignSkullTankTarget:LeftButton",
        "BINDING_NAME_TANKSIGN_TOGGLE", "SLASH_TANKSIGN1", "SLASH_TANKSIGN2", "TanksignDB", "TanksignSkullMouseover",
        "TanksignSkullTankTarget" }, ","))
    H.eq(env.SLASH_TANKSIGN2, "/ts")
    H.eq(type(env.SlashCmdList.TANKSIGN), "function")
end)

H.test("help and version commands", function()
    local _, ctl = boot()
    ctl.slash("")
    H.ok(ctl.chatText():find("/ts on | off | toggle", 1, true))
    ctl.slash("probe help")
    H.ok(ctl.chatText():find("/ts probe buttons", 1, true))
    ctl.slash("version")
    H.ok(ctl.chatText():find("Decoupled Lane Studio", 1, true))
end)

H.test("probe report runs with secret health and threat and never errors", function()
    local env, ctl = boot()
    hostile(ctl, "target", { hp = ctl.secret, isTanking = ctl.secret, threatValue = ctl.secret })
    hostile(ctl, "nameplate1", { hp = 400 })
    ctl.units.nameplate2 = { name = "Friendly", hostile = false }
    ctl.slash("probe")
    local lines = env.TanksignDB.probe.lastReport
    H.ok(lines and #lines > 10, "report saved")
    local text = table.concat(lines, "\n")
    H.ok(text:find("summary pass=%d+ fail=%d+ error=0"), text:match("summary[^\n]*"))
    H.ok(text:find("PASS x:build: interface=16001", 1, true), text)
    H.ok(text:find("hp secret=1 plain=1", 1, true), text)
    H.ok(text:find("target: exists=true", 1, true))
    H.ok(not text:find("nameplate2:", 1, true), "friendly plate skipped")
    H.ok(text:find("RAIDTARGET8", 1, true), "bindings listed")
    H.ok(text:find("UnitDetailedThreatSituation", 1, true))
    H.ok(not text:find("touched a secret", 1, true), "never touched a secret")
end)

H.test("unknown APIs show as FAIL, not as Lua errors", function()
    local env, ctl = boot()
    env.UnitThreatPercentageOfLead = nil
    env.UnitHealthPercent = nil
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(text:find("FAIL UnitHealthPercent: is nil, expected function", 1, true), text)
    H.ok(text:find("hpPct=MISSING", 1, true) or not text:find("target:", 1, true))
end)

H.test("combat sampling saves three samples per fight", function()
    local env, ctl = boot()
    hostile(ctl, "nameplate1", { hp = ctl.secret })
    ctl.combat = true
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.advance(10)
    H.eq(#env.TanksignDB.probe.combat, 0, "off by default")
    ctl.slash("probe combat on")
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.advance(10)
    H.eq(#env.TanksignDB.probe.combat, 3)
    H.ok(ctl.chatText():find("health secret on 1/1", 1, true), ctl.chatText())
    ctl.slash("probe combat off")
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.advance(10)
    H.eq(#env.TanksignDB.probe.combat, 3)
end)

H.test("combat samples stop when combat ends early", function()
    local env, ctl = boot()
    hostile(ctl, "nameplate1")
    ctl.slash("probe combat on")
    ctl.combat = true
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.advance(2)
    ctl.combat = false
    ctl.advance(10)
    H.eq(#env.TanksignDB.probe.combat, 1)
end)

H.test("mark test records success, toggling guard and blocked calls", function()
    local env, ctl = boot()
    ctl.marksReadable = true -- probe logic; Forever itself hides marked units' markers
    ctl.slash("probe mark")
    H.ok(ctl.chatText():find("target a mob first", 1, true))
    local u = hostile(ctl, "target")
    ctl.slash("probe mark")
    ctl.advance(1)
    H.eq(u.mark, 8)
    local m = env.TanksignDB.probe.marks[1]
    H.eq(m.call, "ok")
    H.eq(m.before, "nil")
    H.eq(m.after, "8")
    H.eq(m.blocked, "no")
    ctl.slash("probe mark")
    H.ok(ctl.chatText():find("already has the skull", 1, true))
    H.eq(u.mark, 8)
    ctl.slash("probe unmark")
    ctl.advance(1)
    H.eq(u.mark, nil)
    ctl.markBlocked = true
    ctl.slash("probe mark")
    ctl.advance(1)
    H.eq(env.TanksignDB.probe.marks[2].blocked, "ADDON_ACTION_BLOCKED:\"SetRaidTarget()\"")
end)

H.test("target test records the forbidden action", function()
    local env, ctl = boot()
    ctl.slash("probe target")
    ctl.advance(1)
    local t = env.TanksignDB.probe.targets[1]
    H.eq(t.blocked, "ADDON_ACTION_FORBIDDEN:\"TargetUnit()\"")
    H.eq(t.self, "false")
end)

H.test("secure button check is skipped in combat", function()
    local env, ctl = boot()
    ctl.combat = true
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(text:find("x:secure.button: skipped: in combat", 1, true), text)
end)

H.test("probe clear empties saved samples", function()
    local env, ctl = boot()
    hostile(ctl, "target")
    ctl.slash("probe mark")
    ctl.advance(1)
    ctl.slash("probe clear")
    H.eq(#env.TanksignDB.probe.marks, 0)
end)

H.test("an unsupported client stays inert", function()
    local _, ctl = boot({ interface = 120105 })
    H.ok(ctl.chatText():find("not supported", 1, true), ctl.chatText())
    ctl.slash("probe")
    H.ok(not ctl.ns.db.probe or not ctl.ns.db.probe.lastReport, "no probe on an unsupported client")
end)

H.test("fallback TOC only prints a message", function()
    local _, ctl = boot({ toc = "Tanksign/Tanksign.toc", interface = 11508 })
    H.ok(ctl.chatText():find("not supported", 1, true), ctl.chatText())
    H.eq(ctl.ns.Probe, nil)
end)

H.test("secure skull buttons: built out of combat, clicks recorded, tank's target button", function()
    local env, ctl = boot()
    ctl.marksReadable = true
    ctl.group, ctl.groupSize = true, 3
    ctl.roles = { party2 = "TANK" }
    local u = hostile(ctl, "target")
    ctl.combat = true
    ctl.slash("probe buttons")
    H.ok(ctl.chatText():find("only be shown or hidden out of combat", 1, true))
    ctl.combat = false
    ctl.slash("probe buttons")
    local buttons = {}
    for _, f in ipairs(ctl.frames) do
        if f._template == "SecureActionButtonTemplate" and f._attrs.type and f._parent ~= env.UIParent then buttons[#buttons + 1] = f end
    end
    H.eq(#buttons, 7)
    H.eq(buttons[3]._attrs.unit, "party2target")
    buttons[1]:Click("LeftButton", true)
    ctl.advance(1)
    H.eq(u.mark, 8)
    local rec = env.TanksignDB.probe.secureMarks[1]
    H.eq(rec.before, "nil")
    H.eq(rec.after, "8")
    H.eq(rec.blocked, "no")
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(text:find("secure at=", 1, true) and text:find("after=8", 1, true), text)
    ctl.slash("probe buttons")
    H.ok(ctl.chatText():find("buttons hidden", 1, true))
end)

H.test("unit samples include group threat, secrecy predicates and the display test", function()
    local env, ctl = boot()
    ctl.group, ctl.groupSize = true, 2
    env.C_Secrets = { ShouldUnitHealthMaxBeSecret = function() return true end }
    hostile(ctl, "target", { hp = ctl.secret, hpMax = ctl.secret })
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(text:find("threat.party1=", 1, true), text)
    H.ok(text:find("tgtOf.party1=", 1, true))
    H.ok(text:find("s.hpMax=true", 1, true))
    H.ok(text:find("s.thrVal=MISSING", 1, true))
    H.ok(text:find("bar=ok,ok,ok", 1, true))
    H.ok(not text:find("touched a secret", 1, true))
end)

H.test("probe reports never contain other players' names or GUIDs", function()
    local env, ctl = boot()
    ctl.units.target = { name = "Somebody", guid = "Player-1-ABC", hostile = false }
    local isPlayer = env.UnitIsPlayer
    env.UnitIsPlayer = function(u) return u == "target" or isPlayer(u) end
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(not text:find("Somebody", 1, true), "name kept out")
    H.ok(not text:find("Player-1-ABC", 1, true), "guid kept out")
    H.ok(text:find('name=<player>', 1, true), text)
end)

H.test("mark recorder: counts a marked -> unmarked -> marked gap, not a seamless swap", function()
    local env, ctl = boot()
    local a = hostile(ctl, "nameplate1", { mark = 8 })
    local b = hostile(ctl, "nameplate2", { mark = 7 })
    ctl.slash("probe marks")
    local watch
    for _, f in ipairs(ctl.frames) do if f._events.RAID_TARGET_UPDATE and f._scripts.OnUpdate then watch = f end end
    H.ok(watch, "recorder listening")
    local function frameTick() ctl.time = ctl.time + 0.016; watch._scripts.OnUpdate(watch, 0.016) end
    -- someone puts a square on the skull mob, with a short break
    ctl.fire("RAID_TARGET_UPDATE")
    a.mark = nil; frameTick()
    a.mark = 6; frameTick()
    -- someone puts a moon on the X mob, seamlessly (no break)
    ctl.fire("RAID_TARGET_UPDATE")
    b.mark = 5; frameTick()
    -- the skull mob is cleared, and marked again 4 seconds later: two events, not a gap
    ctl.time = ctl.time + 3; ctl.fire("RAID_TARGET_UPDATE")
    a.mark = nil; frameTick()
    ctl.time = ctl.time + 4; a.mark = 8; ctl.fire("RAID_TARGET_UPDATE")
    ctl.slash("probe marks")
    H.ok(env.TanksignDB.probe.markWatchSummary:find("1 marked->unmarked->marked gaps", 1, true),
        env.TanksignDB.probe.markWatchSummary)
    ctl.slash("probe")
    local text = table.concat(env.TanksignDB.probe.lastReport, "\n")
    H.ok(text:find("nameplate1 GAP", 1, true), text)
    H.ok(not text:find("nameplate2 GAP", 1, true))
    H.ok(text:find("-- mark watch", 1, true))
end)
