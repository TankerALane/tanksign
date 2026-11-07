-- UI/Options.lua
-- The options page under Esc > Options > AddOns > Tanksign (Settings API canvas), in the
-- Plain palette. Every control reads and writes the active profile and redraws when a
-- setting changes anywhere (slash command, ON/OFF button, key binding), through
-- State.OnChange. Opened with /ts options.

local _, ns = ...
local L = ns.L
local W = ns.Widgets
local Compat = ns.Compat

local Options = {}
ns.Options = Options

local panel, content
local controls = {}
local statusText, keysText, profileEdit

local function settings() return ns.db.settings end

-- Change one setting and let everything redraw.
local function set(key, value)
    settings()[key] = value
    ns.Roster.Update()
    ns.State.Refresh()
end

local function nextIn(list, current)
    for i, v in ipairs(list) do
        if v == current then return list[i % #list + 1] end
    end
    return list[1]
end

local function keyText(command)
    local fn = _G.GetBindingKey
    local key = type(fn) == "function" and fn(command) or nil
    return key and ns.Palette.Wrap("heading", key) or ns.Palette.Wrap("muted", L.OPT_NOT_BOUND)
end

local function build()
    panel = CreateFrame("Frame")
    panel.name = L.ADDON_TITLE
    W.Background(panel, "bg")
    local scroll
    scroll, content = W.ScrollArea(panel)
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -4, 4)

    local y = -12
    local function place(widget, height, indent)
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 16 + (indent or 0), y)
        y = y - (height or 24)
        return widget
    end
    local function heading(text)
        y = y - 8
        place(W.Heading(content, text), 30)
    end
    local function note(text, role)
        local fs = W.Text(content, "small", role or "muted")
        fs:SetWidth(540)
        fs:SetText(text)
        place(fs, 18 * math.max(1, math.ceil(#text / 95)))
        return fs
    end
    local function toggle(label, key, onSet)
        local t = W.Toggle(content, label, function() return settings()[key] end, function(v)
            if onSet then onSet(v) else set(key, v) end
        end)
        controls[#controls + 1] = t
        return place(t)
    end
    local function add(widget)
        controls[#controls + 1] = widget
        return place(widget, 26)
    end

    local title = W.Text(content, "heading", "heading")
    title:SetText(L.ADDON_TITLE .. "  " .. ns.Palette.Wrap("muted", ns.VERSION))
    place(title, 22)
    note(L.OPT_INTRO)
    statusText = note("")

    heading(L.OPT_CORE)
    toggle(L.OPT_ENABLED, "enabled", function(v) ns.State.SetEnabled(v) end)
    toggle(L.OPT_ONLY_GROUP, "onlyInGroup")
    add(W.Cycle(content, L.OPT_TANK_SOURCE, function() return L.SOURCE_NAMES[settings().tankSource] end,
        function() set("tankSource", nextIn(ns.Settings.TANK_SOURCES, settings().tankSource)) end, 200))
    local nameLabel = W.Text(content, "body", "text")
    nameLabel:SetText(L.OPT_TANK_NAME)
    place(nameLabel, 0)
    local nameBox = W.EditBox(content, 150, function(text) set("tankName", text) end)
    nameBox:SetPoint("TOPLEFT", content, "TOPLEFT", 186, y + 2)
    nameBox.Refresh = function(self) if not self:HasFocus() then self:SetText(settings().tankName) end end
    controls[#controls + 1] = nameBox
    y = y - 26

    heading(L.OPT_ROWS)
    toggle(L.OPT_TAGS, "showTags")
    toggle(L.OPT_DIM, "dimTrivial")
    add(W.Slider(content, L.OPT_MAX_ROWS, 1, 15, 1, function() return settings().maxRows end,
        function(v) set("maxRows", v) end, "%d"))
    note(L.OPT_ROWS_NOTE)

    heading(L.OPT_MARKING)
    add(W.Cycle(content, L.OPT_MARKER, function() return L.MARKER_NAMES[settings().marker] end,
        function() set("marker", nextIn(ns.Settings.MARKERS, settings().marker)) end))
    add(W.Cycle(content, L.OPT_RIGHT_MARKER, function() return L.MARKER_NAMES[settings().rightMarker] end,
        function() set("rightMarker", nextIn(ns.Settings.MARKERS, settings().rightMarker)) end))
    toggle(L.OPT_ROW_ICONS, "rowIcons")
    toggle(L.OPT_PLATE_ICONS, "plateIcons")
    note(L.MARKS_NOTE)
    note(L.OPT_MARKING_NOTE)

    heading(L.OPT_PANEL)
    toggle(L.OPT_SHOW_PANEL, "showPanel")
    toggle(L.OPT_SHOW_TOGGLE, "showToggle")
    toggle(L.OPT_LOCK, "locked")
    add(W.Slider(content, L.OPT_SCALE, 0.5, 2, 0.05, function() return settings().scale end,
        function(v) set("scale", v) end))
    add(W.Slider(content, L.OPT_ALPHA, 0.2, 1, 0.05, function() return settings().alpha end,
        function(v) set("alpha", v) end))
    place(W.Button(content, L.OPT_RESET_POSITION, 170, 22, function()
        if ns.Panel.ResetPosition() then ns.Log.Info(L.POSITION_RESET) else ns.Log.Warn(L.NOT_IN_COMBAT) end
    end), 30)

    heading(L.OPT_ALERTS)
    toggle(L.OPT_SOUND, "soundOnMark")
    toggle(L.OPT_CHAT, "chatOnMark")
    note(L.OPT_ALERTS_NOTE)

    heading(L.OPT_KEYS)
    keysText = note("", "text")
    note(L.OPT_KEYS_NOTE)

    heading(L.OPT_PROFILES)
    add(W.Cycle(content, L.OPT_PROFILE, function() return _G.TanksignDB.profile end,
        function() ns.Init.UseProfile(ns.Profiles.Next(_G.TanksignDB), true) end, 200))
    local newLabel = W.Text(content, "body", "text")
    newLabel:SetText(L.OPT_NEW_PROFILE)
    place(newLabel, 0)
    profileEdit = W.EditBox(content, 150, function(text) Options.NewProfile(text) end)
    profileEdit:SetPoint("TOPLEFT", content, "TOPLEFT", 186, y + 2)
    y = y - 28
    place(W.Button(content, L.OPT_DELETE_PROFILE, 170, 22, function() Options.DeleteProfile() end), 30)
    local auto = W.Toggle(content, L.OPT_AUTO_PROFILE, function() return _G.TanksignDB.autoProfile == true end,
        function(v)
            _G.TanksignDB.autoProfile = v
            ns.Log.Info(v and L.AUTO_PROFILE_ON or L.AUTO_PROFILE_OFF)
        end)
    controls[#controls + 1] = auto
    place(auto)

    heading(L.OPT_OTHER)
    toggle(L.OPT_DEBUG, "debug")
    place(W.Button(content, L.OPT_RESET, 170, 22, function()
        ns.Profiles.Reset(settings())
        ns.Roster.Update()
        ns.State.Refresh()
        ns.Log.Info(L.RESET_DONE)
    end), 30)
    note(L.OPT_CREDIT)

    content:SetHeight(-y + 20)
end

function Options.Refresh()
    if not panel then return end
    for _, c in ipairs(controls) do
        if c.Refresh then pcall(c.Refresh, c) end
    end
    local s = settings()
    statusText:SetText(string.format(L.OPT_STATUS, s.enabled and ns.Palette.Wrap("good", L.ON) or ns.Palette.Wrap("bad", L.OFF),
        ns.State.reason, #ns.Roster.tanks > 0 and table.concat(ns.Roster.tanks, ", ") or L.NONE,
        L.SOURCE_NAMES[ns.Roster.source] or ns.Roster.source, _G.TanksignDB.profile))
    keysText:SetText(string.format(L.OPT_KEYS_LIST, keyText("TANKSIGN_TOGGLE"),
        keyText("CLICK TanksignSkullTankTarget:LeftButton"), keyText("CLICK TanksignSkullMouseover:LeftButton")))
end

function Options.NewProfile(text)
    local name, err = ns.Profiles.Create(_G.TanksignDB, text)
    if not name then
        ns.Log.Warn(L[err])
        return
    end
    profileEdit:SetText("")
    ns.Init.UseProfile(name, true)
end

function Options.DeleteProfile()
    local list = ns.Profiles.List(_G.TanksignDB)
    if #list < 2 then
        ns.Log.Warn(L.PROFILE_LAST)
        return
    end
    local old = _G.TanksignDB.profile
    ns.Init.UseProfile(ns.Profiles.Next(_G.TanksignDB), true)
    ns.Profiles.Delete(_G.TanksignDB, old)
    ns.Log.Info(L.PROFILE_DELETED, old)
    Options.Refresh()
end

function Options.Register()
    if Options.category or Compat.IsDisabled("options") then return end
    local ok, err = pcall(function()
        build()
        local category = _G.Settings.RegisterCanvasLayoutCategory(panel, L.ADDON_TITLE)
        _G.Settings.RegisterAddOnCategory(category)
        Options.category = category
    end)
    if not ok then
        Compat.Disable("options", Compat.Describe(err))
        return
    end
    panel:SetScript("OnShow", Options.Refresh)
    ns.State.OnChange(Options.Refresh)
    Options.Refresh()
end

function Options.Open()
    if not Options.category then
        ns.Log.Warn(L.OPTIONS_UNAVAILABLE)
        return
    end
    local category = Options.category
    local id = type(category.GetID) == "function" and category:GetID() or category.ID
    local ok = pcall(_G.Settings.OpenToCategory, id)
    if not ok then pcall(_G.Settings.OpenToCategory, category) end
end
