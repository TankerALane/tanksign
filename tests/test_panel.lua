-- The mob panel, toggle and key bindings against the mock, including combat rules.
local H = ...
local M = require("wowmock")

local function boot(setup)
    local env, ctl = M.new()
    if setup then setup(env, ctl) end
    ctl.load(H.ROOT)
    ctl.fire("ADDON_LOADED", "Tanksign")
    ctl.fire("PLAYER_LOGIN")
    return env, ctl
end

local function party(ctl, tankUnit)
    ctl.group, ctl.groupSize = true, 3
    ctl.roles = { [tankUnit] = "TANK" }
    ctl.names = { party1 = "Shieldy", party2 = "Stabby" }
end

local function mob(ctl, token, fields)
    local u = { name = "Razormane Thornweaver", hostile = true, combat = true, hp = ctl.secret, hpMax = ctl.secret }
    for k, v in pairs(fields or {}) do u[k] = v end
    ctl.units[token] = u
    return u
end

local function eventFrameFor(ctl, event)
    for _, f in ipairs(ctl.frames) do if f._events[event] and f._scripts.OnUpdate then return f end end
end

H.test("40 secure rows: left click marks, driven by nameplate unit watch", function()
    local env, ctl = boot()
    local rows = ctl.ns.Panel.rows
    H.eq(#rows, 40)
    H.eq(rows[7]._attrs.unit, "nameplate7")
    H.eq(rows[7]._attrs.type1, "raidtarget")
    H.eq(rows[7]._attrs.action1, "set")
    H.eq(rows[7]._attrs.marker1, 8)
    H.eq(rows[7]._attrs.type2, nil, "no right-click targeting on Forever")
    H.eq(#ctl.drivers, 0, "no macro-condition drivers: Forever answers 0 for nameplates")
    H.eq(#ctl.watches, 40)
    H.ok(ctl.watches[3].frame == rows[3] and ctl.watches[3].asState == true)
    H.eq(rows[3]._template, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    H.ok(rows[3]._attrs["_onstate-unitexists"]:find('SetAttribute("state-np3"', 1, true))
    local header = rows[1]._parent
    H.ok(header._attrs["_onstate-np1"]:find("GetFrameRef", 1, true))
    H.eq(header._attrs.tsActive, 1)
    H.eq(header._attrs.tsMaxRows, 8)
    H.ok(header._refs.row40 == rows[40])
    H.eq(#ctl.blockedCalls, 0)
    H.ok(env.TanksignSkullTankTarget and env.TanksignSkullMouseover)
end)

H.test("rows show name, secret health and who holds the mob", function()
    local _, ctl = boot(function(_, c) party(c, "party1") end)
    mob(ctl, "nameplate1", { threatBy = { party1 = 3 } })
    mob(ctl, "nameplate2", { name = "Loose Boar", threatBy = { party1 = 0, player = 3 } })
    mob(ctl, "nameplate3", { threatBy = { party1 = ctl.secret } })
    mob(ctl, "nameplate4", { combat = false, name = ctl.secret })
    ctl.combat = true
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.fire("UNIT_HEALTH", "nameplate1")
    ctl.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    local rows = ctl.ns.Panel.rows
    H.eq(rows[1].name._text, "Razormane Thornweaver")
    H.ok(rawequal(rows[4].name._text, ctl.secret), "secret name handed to the font string")
    H.eq(rows[4].bar._barColor[2], ctl.ns.Palette.Color("rule")[2], "not pulled yet: neutral")
    H.ok(rawequal(rows[1].bar._value, ctl.secret), "secret health handed to the bar")
    local P = ctl.ns.Palette
    H.eq(rows[1].bar._barColor[2], P.Color("good")[2])
    H.eq(rows[2].bar._barColor[2], P.Color("bad")[2])
    H.eq(rows[3].bar._barColor[2], P.Color("rule")[2])
    H.eq(#ctl.blockedCalls, 0, "nothing protected touched in combat")
end)

H.test("toggle out of combat: inert when off, back on when on", function()
    local env, ctl = boot()
    local header = ctl.ns.Panel.rows[1]._parent
    ctl.slash("off")
    H.ok(ctl.chatText():find("DISABLED", 1, true))
    H.eq(env.TanksignDB.settings.enabled, false)
    H.eq(header._attrs.tsActive, 0)
    H.eq(eventFrameFor(ctl, "UNIT_HEALTH"), nil, "no unit events while off")
    H.eq(env.TanksignSkullMouseover._attrs.unit, nil, "keys do nothing while off")
    env.SlashCmdList.TANKSIGN("toggle") -- what the key binding runs
    H.ok(ctl.chatText():find("ENABLED", 1, true))
    H.eq(env.TanksignDB.settings.enabled, true)
    H.eq(header._attrs.tsActive, 1)
    H.ok(eventFrameFor(ctl, "UNIT_HEALTH"), "unit events back")
    H.eq(env.TanksignSkullMouseover._attrs.unit, "mouseover")
end)

H.test("toggle in combat: no protected call, fades now, applies after combat", function()
    local env, ctl = boot()
    local header = ctl.ns.Panel.rows[1]._parent
    ctl.combat = true
    ctl.fire("PLAYER_REGEN_DISABLED")
    ctl.slash("off")
    H.eq(#ctl.blockedCalls, 0)
    H.eq(header._attrs.tsActive, 1, "secure state waits")
    H.eq(eventFrameFor(ctl, "UNIT_HEALTH"), nil, "but updates stop now")
    ctl.combat = false
    ctl.fire("PLAYER_REGEN_ENABLED")
    H.eq(header._attrs.tsActive, 0)
    H.eq(env.TanksignSkullMouseover._attrs.unit, nil)
end)

H.test("tank's-target key follows the tank, out of combat only", function()
    local env, ctl = boot(function(_, c) party(c, "party1") end)
    H.eq(env.TanksignSkullTankTarget._attrs.unit, "party1target")
    ctl.combat = true
    ctl.roles = { party2 = "TANK" }
    ctl.fire("GROUP_ROSTER_UPDATE")
    H.eq(#ctl.blockedCalls, 0)
    H.eq(env.TanksignSkullTankTarget._attrs.unit, "party1target", "unchanged in combat")
    ctl.combat = false
    ctl.fire("PLAYER_REGEN_ENABLED")
    H.eq(env.TanksignSkullTankTarget._attrs.unit, "party2target")
    ctl.roles = { player = "TANK" }
    ctl.fire("PLAYER_ROLES_ASSIGNED")
    H.eq(env.TanksignSkullTankTarget._attrs.unit, "target")
    ctl.slash("source threat")
    H.eq(env.TanksignSkullTankTarget._attrs.unit, nil)
end)

H.test("marker setting reaches every row and both keys", function()
    local env, ctl = boot()
    ctl.slash("marker cross")
    H.eq(ctl.ns.Panel.rows[12]._attrs.marker1, 7)
    H.eq(env.TanksignSkullMouseover._attrs.marker, 7)
    ctl.slash("marker 9")
    H.ok(ctl.chatText():find("Usage: /ts marker", 1, true))
    H.eq(env.TanksignDB.settings.marker, 7)
end)

H.test("only in group: solo is inactive", function()
    local _, ctl = boot()
    ctl.slash("group")
    H.eq(ctl.ns.Panel.rows[1]._parent._attrs.tsActive, 0)
    H.eq(ctl.ns.State.reason, "not in group")
    ctl.group, ctl.groupSize = true, 2
    ctl.fire("GROUP_ROSTER_UPDATE")
    H.eq(ctl.ns.Panel.rows[1]._parent._attrs.tsActive, 1)
end)

H.test("a /reload in combat builds the panel after the fight", function()
    local _, ctl = boot(function(_, c) c.combat = true end)
    H.eq(ctl.ns.Panel.IsBuilt(), false)
    H.ok(ctl.chatText():find("when this fight ends", 1, true), ctl.chatText())
    ctl.combat = false
    ctl.fire("PLAYER_REGEN_ENABLED")
    H.eq(ctl.ns.Panel.IsBuilt(), true)
    H.eq(#ctl.blockedCalls, 0)
end)

H.test("status, tank name, rows, scale, reset commands", function()
    local env, ctl = boot(function(_, c) party(c, "party1") end)
    ctl.slash("status")
    H.ok(ctl.chatText():find("Tanks: party1 (source role)", 1, true), ctl.chatText())
    ctl.slash("tank Stabby")
    H.ok(ctl.chatText():find("comes before a fixed name", 1, true))
    ctl.slash("source name")
    H.eq(ctl.ns.Roster.tanks[1], "party2")
    ctl.slash("rows 4")
    H.eq(ctl.ns.Panel.rows[1]._parent._attrs.tsMaxRows, 4)
    ctl.slash("scale 1.25")
    H.eq(env.TanksignDB.settings.scale, 1.25)
    ctl.slash("reset")
    H.eq(env.TanksignDB.settings.tankSource, "auto")
    H.eq(env.TanksignDB.settings.maxRows, 8)
end)

H.test("logout saves a session record for reading from SavedVariables", function()
    local env, ctl = boot(function(_, c) party(c, "party1") end)
    mob(ctl, "nameplate1", { threatBy = { party1 = 3 } })
    ctl.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    ctl.slash("probe mark") -- no target: nothing blocked
    ctl.fire("PLAYER_LOGOUT")
    local s = env.TanksignDB.lastSession
    H.eq(s.version, "0.3.0")
    H.eq(s.tanks, "party1")
    H.eq(s.panelBuilt, true)
    H.eq(s.blocked, 0)
    local text = table.concat(s.debugLog, "\n")
    H.ok(text:find("nameplate1 Razormane Thornweaver: held by a tank", 1, true), text)
end)

H.test("/ts diag reports rows, states and the secure self-test, and saves it", function()
    local env, ctl = boot()
    mob(ctl, "nameplate2")
    env.SecureCmdOptionParse = function() return "1" end
    ctl.slash("diag")
    local text = table.concat(env.TanksignDB.lastDiag, "\n")
    H.ok(text:find("nameplate2 exists=true", 1, true), text)
    H.ok(text:find("condition=1", 1, true), text)
    H.ok(text:find("conditions: [@nameplate2]=1", 1, true), text)
    H.ok(text:find("restricted Execute: ok=true", 1, true), text)
    H.ok(text:find("step errors: none", 1, true), text)
    ctl.combat = true
    ctl.slash("diag")
    H.ok(table.concat(env.TanksignDB.lastDiag, "\n"):find("self-test skipped: in combat", 1, true))
    H.eq(#ctl.blockedCalls, 0)
end)

H.test("rows: tags for elite and caster, dimming for critters and pets, secret type left alone", function()
    local env, ctl = boot()
    mob(ctl, "nameplate1", { class = "elite", powerType = 0 })
    mob(ctl, "nameplate2", { ctypeId = 8 })
    mob(ctl, "nameplate3", { pc = true })
    mob(ctl, "nameplate4", { ctypeId = ctl.secret, class = ctl.secret, powerType = ctl.secret })
    ctl.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    local rows = ctl.ns.Panel.rows
    H.eq(rows[1].tag._text, "E C")
    H.eq(rows[1].bar._alpha, 1)
    H.eq(rows[2].bar._alpha, 0.4)
    H.eq(rows[3].bar._alpha, 0.4)
    H.eq(rows[4].tag._text, "")
    H.eq(rows[4].bar._alpha, 1)
    ctl.slash("tags")
    ctl.slash("dim")
    ctl.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    H.eq(rows[1].tag._text, "")
    H.eq(rows[2].bar._alpha, 1)
    H.eq(env.TanksignDB.settings.showTags, false)
end)
