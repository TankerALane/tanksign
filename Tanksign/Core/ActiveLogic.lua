-- Core/ActiveLogic.lua
-- PURE: must not touch WoW globals at load time.
-- Whether Tanksign should be active right now, and how the panel should look,
-- from plain facts. One place, so the slash command, the button, the keybind and
-- the options checkbox all agree.

local _, ns = ...

local ActiveLogic = {}
ns.ActiveLogic = ActiveLogic

-- settings: the saved settings; facts: { inGroup = bool, inInstance = bool }
function ActiveLogic.IsActive(settings, facts)
    if not settings.enabled then return false, "disabled" end
    if settings.onlyInGroup and not (facts.inGroup or facts.inInstance) then return false, "not in group" end
    return true, "active"
end

-- What the panel should do. Protected frames cannot be hidden in combat, so a
-- change that would hide them waits for combat to end and the panel only fades.
-- Returns { show = bool, rows = bool, faded = bool }.
function ActiveLogic.PanelState(settings, active, inCombat, currentlyShown)
    local wantShown = settings.showPanel and (active or settings.showToggle)
    local wantRows = settings.showPanel and active
    if inCombat then
        return { show = currentlyShown, rows = currentlyShown and wantRows, faded = not active, deferred = wantShown ~= currentlyShown }
    end
    return { show = wantShown, rows = wantRows, faded = false, deferred = false }
end
