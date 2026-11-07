-- Core/Init.lua
-- Loaded last. Sets up the saved variables, detects the client, starts the panel and
-- key bindings, and registers /tanksign and /ts. Globals created on purpose:
-- TanksignDB (saved variables), SLASH_TANKSIGN1/2 and SlashCmdList.TANKSIGN.

local _, ns = ...
local L = ns.L

local Init = {}
ns.Init = Init

-- ns.db reads and writes TanksignDB, except `settings`, which is the active profile.
-- (The profile is not stored twice in the saved variables: `settings` lives only here.)
local function setupDB()
    local saved = ns.Settings.Migrate(_G.TanksignDB)
    _G.TanksignDB = saved
    ns.db = setmetatable({ settings = ns.Profiles.Ensure(saved) }, {
        __index = saved,
        __newindex = saved,
    })
end

-- Make `name` the active profile and redraw everything. manual = picked by the player.
function Init.UseProfile(name, manual)
    local settings = ns.Profiles.Switch(_G.TanksignDB, name)
    if not settings then return false end
    rawset(ns.db, "settings", settings)
    if manual then _G.TanksignDB.manualProfile = name end
    ns.Roster.Update()
    ns.State.Refresh()
    ns.Log.Info(L.PROFILE_ACTIVE_NOW, name)
    return true
end

local function autoProfile()
    local saved = _G.TanksignDB
    if not saved.autoProfile then return end
    local _, instanceType = ns.Roster.PlainCall("IsInInstance")
    local want = ns.Profiles.ForInstance(saved, instanceType)
    if want and want ~= saved.profile then Init.UseProfile(want, false) end
end

local function help()
    ns.Log.Info(L.HELP_HEADER, ns.VERSION)
    for _, line in ipairs(L.HELP_LINES) do ns.Log.Info("  " .. line) end
end

local function status()
    local s = ns.db.settings
    ns.Log.Info(L.STATUS_LINE, s.enabled and L.ON or L.OFF, ns.State.reason,
        #ns.Roster.tanks > 0 and table.concat(ns.Roster.tanks, ", ") or L.NONE, ns.Roster.source,
        L.MARKER_NAMES[s.marker] or tostring(s.marker), tostring(ns.Keys.TankTargetUnit() or L.NONE))
end

local function setSetting(key, value, message, ...)
    ns.db.settings[key] = value
    ns.Roster.Update()
    ns.State.Refresh()
    if message then ns.Log.Info(message, ...) end
end

local function markerFromText(text)
    local n = tonumber(text)
    if n and n >= 1 and n <= 8 and n % 1 == 0 then return n end
    text = (text or ""):lower()
    for i, name in pairs(L.MARKER_NAMES) do
        if name:lower() == text then return i end
    end
    return nil
end

local COMMANDS = {}

COMMANDS["on"] = function() ns.State.SetEnabled(true) end
COMMANDS["off"] = function() ns.State.SetEnabled(false) end
COMMANDS["toggle"] = function() ns.State.Toggle() end
COMMANDS["status"] = status
COMMANDS["show"] = function() setSetting("showPanel", true, L.PANEL_SHOWN) end
COMMANDS["hide"] = function() setSetting("showPanel", false, L.PANEL_HIDDEN) end
COMMANDS["lock"] = function() setSetting("locked", true, L.PANEL_LOCKED) end
COMMANDS["unlock"] = function() setSetting("locked", false, L.PANEL_UNLOCKED) end
COMMANDS["debug"] = function()
    setSetting("debug", not ns.db.settings.debug, ns.db.settings.debug and L.DEBUG_OFF or L.DEBUG_ON)
end

COMMANDS["tank"] = function(rest)
    if rest == "" then
        setSetting("tankName", "", L.TANK_CLEARED)
        return
    end
    setSetting("tankName", rest, L.TANK_SET, rest)
    if ns.db.settings.tankSource == "auto" and ns.Roster.source ~= "name" then
        ns.Log.Info(L.TANK_SHADOWED, ns.Roster.source)
    end
end

COMMANDS["source"] = function(rest)
    local want = rest:lower()
    if ns.Settings.IsValid("tankSource", want) then
        setSetting("tankSource", want, L.SOURCE_SET, want)
    else
        ns.Log.Warn(L.SOURCE_USAGE)
    end
end

COMMANDS["marker"] = function(rest)
    local m = markerFromText(rest)
    if m then
        setSetting("marker", m, L.MARKER_SET, L.MARKER_NAMES[m])
    else
        ns.Log.Warn(L.MARKER_USAGE)
    end
end

COMMANDS["rows"] = function(rest)
    local n = ns.Settings.ParseNumber(rest, 1, 15)
    if n and n % 1 == 0 then setSetting("maxRows", n, L.ROWS_SET, n) else ns.Log.Warn(L.ROWS_USAGE) end
end

COMMANDS["scale"] = function(rest)
    local n = ns.Settings.ParseNumber(rest, 0.5, 2)
    if n then setSetting("scale", n, L.SCALE_SET, n) else ns.Log.Warn(L.SCALE_USAGE) end
end

COMMANDS["tags"] = function()
    setSetting("showTags", not ns.db.settings.showTags, ns.db.settings.showTags and L.TAGS_OFF or L.TAGS_ON)
end

COMMANDS["dim"] = function()
    setSetting("dimTrivial", not ns.db.settings.dimTrivial, ns.db.settings.dimTrivial and L.DIM_OFF or L.DIM_ON)
end

COMMANDS["group"] = function()
    setSetting("onlyInGroup", not ns.db.settings.onlyInGroup,
        ns.db.settings.onlyInGroup and L.GROUP_OFF or L.GROUP_ON)
end

COMMANDS["reset"] = function(rest)
    if rest == "position" then
        if ns.Panel.ResetPosition() then ns.Log.Info(L.POSITION_RESET) else ns.Log.Warn(L.NOT_IN_COMBAT) end
        return
    end
    ns.Profiles.Reset(ns.db.settings)
    ns.Roster.Update()
    ns.State.Refresh()
    ns.Log.Info(L.RESET_DONE)
end

COMMANDS["diag"] = function()
    local lines = ns.Panel.Diagnose(true)
    ns.db.lastDiag = lines
    for _, l in ipairs(lines) do ns.Log.Info(l) end
    ns.Log.Info(L.DIAG_SAVED)
end

COMMANDS["options"] = function() ns.Options.Open() end
COMMANDS["config"] = COMMANDS["options"]

COMMANDS["profile"] = function(rest)
    local db = _G.TanksignDB
    if rest == "" or rest == "list" then
        ns.Log.Info(L.PROFILE_LIST, db.profile, table.concat(ns.Profiles.List(db), ", "))
        return
    end
    if db.profiles[rest] then
        Init.UseProfile(rest, true)
        return
    end
    local name, err = ns.Profiles.Create(db, rest)
    if name then
        Init.UseProfile(name, true)
    else
        ns.Log.Warn(L[err])
    end
end

COMMANDS["probe"] = function(rest) ns.Probe.Command(rest) end
COMMANDS["version"] = function()
    ns.Log.Info("%s %s by %s (%s)", L.ADDON_TITLE, ns.VERSION, ns.AUTHOR, ns.SUPPORT)
end

function Init.Slash(msg)
    local cmd, rest = ns.util.splitCommand(msg)
    if ns.inert then
        ns.Log.Warn(L.UNSUPPORTED, tostring(ns.Compat.interface))
        return
    end
    local fn = COMMANDS[cmd]
    if fn then fn(rest) else help() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ns.ADDON_NAME then return end
        setupDB()
        local flavor = ns.Compat.Detect()
        ns.inert = not ns.FlavorLogic.IsSupported(flavor)
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if ns.inert then
            ns.Log.Warn(L.UNSUPPORTED, tostring(ns.Compat.interface))
            self:UnregisterAllEvents()
            return
        end
        ns.Probe.Start()
        ns.Roster.Update()
        ns.State.Refresh()
        local ok, err = pcall(ns.Panel.Init)
        if not ok then ns.Compat.Disable("panel", ns.Compat.Describe(err)) end
        ok, err = pcall(ns.Keys.Init)
        if not ok then ns.Compat.Disable("keys", ns.Compat.Describe(err)) end
        ok, err = pcall(ns.Options.Register)
        if not ok then ns.Compat.Disable("options", ns.Compat.Describe(err)) end
        -- Group and instance changes decide "active" and who the tank is. These two
        -- events stay registered while disabled, only to keep the state current.
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("PLAYER_ROLES_ASSIGNED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PARTY_LEADER_CHANGED")
        self:RegisterEvent("PLAYER_LOGOUT")
        self:UnregisterEvent("PLAYER_LOGIN")
        ns.Log.Info(L.LOADED, ns.VERSION)
    elseif event == "PLAYER_LOGOUT" then
        Init.SaveSession()
    else
        if event == "PLAYER_ENTERING_WORLD" then autoProfile() end
        ns.Roster.Update()
        ns.State.Refresh()
    end
end)

-- Written on /reload or logout, so a test session can be read from SavedVariables:
-- the last debug lines (kept even with debug printing off), actions Blizzard blocked
-- for Tanksign, and features turned off because an API failed.
function Init.SaveSession()
    local lines = {}
    for i, l in ipairs(ns.Log.recent) do lines[i] = l end
    local disabled = {}
    for feature, why in pairs(ns.Compat.disabled) do disabled[#disabled + 1] = feature .. ": " .. tostring(why) end
    ns.db.lastSession = {
        version = ns.VERSION,
        saved = type(_G.date) == "function" and _G.date("%Y-%m-%d %H:%M:%S") or "?",
        debugLog = lines,
        blocked = ns.Probe.blocked.count,
        lastBlocked = ns.Probe.blocked.last,
        disabled = disabled,
        tanks = table.concat(ns.Roster.tanks, ","),
        tankSource = ns.Roster.source,
        panelBuilt = ns.Panel.IsBuilt(),
        diag = ns.Panel.Diagnose(),
    }
end

_G.SLASH_TANKSIGN1 = "/tanksign"
_G.SLASH_TANKSIGN2 = "/ts"
_G.SlashCmdList.TANKSIGN = Init.Slash
