-- Core/State.lua
-- The one saved "enabled" flag, shared by /ts, the ON/OFF button, the key binding
-- and the options checkbox. Every change goes through State.SetEnabled, which
-- prints the new state and tells every listener (panel, options) to redraw.

local _, ns = ...
local L = ns.L

local State = {}
ns.State = State

local listeners = {}
State.active = false
State.reason = "starting"

function State.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function notify()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn)
        if not ok then ns.Log.Debug("listener error: %s", ns.Compat.Describe(err)) end
    end
end

-- Recompute "active" from the settings and group facts, then redraw everything.
function State.Refresh()
    local active, reason = ns.ActiveLogic.IsActive(ns.db.settings, ns.Roster.InGroupFacts())
    if active ~= State.active or reason ~= State.reason then
        ns.Log.Debug("state: %s (%s)", active and "active" or "inactive", reason)
    end
    State.active, State.reason = active, reason
    notify()
end

function State.SetEnabled(on)
    on = on == true
    ns.db.settings.enabled = on
    ns.Log.Info(on and L.ENABLED or L.DISABLED)
    State.Refresh()
end

function State.Toggle()
    State.SetEnabled(not ns.db.settings.enabled)
end
