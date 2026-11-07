-- UI/Alerts.lua
-- After YOU place a marker with a row click or a Tanksign key: optional sound and chat
-- line, and a one-time message if you are not allowed to mark. Tanksign cannot see
-- markers placed by others (marker positions are secret on Forever), so there is no
-- "the skull moved" alert.

local _, ns = ...
local L = ns.L
local Compat = ns.Compat

local Alerts = {}
ns.Alerts = Alerts

local warnedNoRights = false

function Alerts.MarkingFacts()
    local call = ns.Roster.PlainCall
    return {
        inRaid = call("IsInRaid") == true,
        leader = call("UnitIsGroupLeader", "player"),
        assist = call("UnitIsGroupAssistant", "player"),
        everyoneAssist = call("IsEveryoneAssistant"),
    }
end

function Alerts.CanMark()
    return ns.ActiveLogic.CanMark(Alerts.MarkingFacts())
end

-- Called from PostClick (after Blizzard's secure code ran). unit = the marked token.
function Alerts.OnMark(unit)
    local s = ns.db.settings
    if not Alerts.CanMark() then
        if not warnedNoRights then
            warnedNoRights = true
            ns.Log.Warn(L.NO_MARK_RIGHTS)
        end
        return
    end
    if s.soundOnMark then
        local kit = _G.SOUNDKIT
        local id = type(kit) == "table" and kit.IG_MAINMENU_OPTION_CHECKBOX_ON
        if id and type(_G.PlaySound) == "function" then pcall(_G.PlaySound, id) end
    end
    if s.chatOnMark then
        local name = Compat.Plain(_G.UnitName(unit))
        ns.Log.Info(L.MARK_PLACED, L.MARKER_NAMES[s.marker] or "?", type(name) == "string" and name or L.A_MOB)
    end
end
