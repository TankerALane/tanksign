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
    H.ok(ctl.chatText():find("v0.1.0 loaded", 1, true), ctl.chatText())
    H.eq(type(env.TanksignDB), "table")
    H.eq(env.TanksignDB.settings.enabled, true)
    H.eq(table.concat(ctl.newGlobals(), ","), "SLASH_TANKSIGN1,SLASH_TANKSIGN2,TanksignDB")
    H.eq(env.SLASH_TANKSIGN2, "/ts")
    H.eq(type(env.SlashCmdList.TANKSIGN), "function")
end)

H.test("help and version commands", function()
    local _, ctl = boot()
    ctl.slash("")
    H.ok(ctl.chatText():find("/ts probe mark", 1, true))
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
    ctl.combat = true
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.advance(2)
    ctl.combat = false
    ctl.advance(10)
    H.eq(#env.TanksignDB.probe.combat, 1)
end)

H.test("mark test records success, toggling guard and blocked calls", function()
    local env, ctl = boot()
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
