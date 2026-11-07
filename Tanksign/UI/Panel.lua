-- UI/Panel.lua
-- The mob panel (docs/DECISIONS.md D-007).
--
-- Rows are SECURE buttons, one per nameplate token (nameplate1..40):
--   left click  -> type "raidtarget", action "set", marker <setting>: Blizzard's code marks the mob
--   right click -> type "target": Blizzard's code targets the mob
-- A secure state driver per token reports "[@nameplateN,harm,nodead]" to a
-- SecureHandlerStateTemplate header, and a restricted snippet stacks the visible rows.
-- So rows appear, disappear and re-stack in combat without addon code touching a
-- protected frame. Addon code only fills in plain visuals (name, health bar, colors),
-- and only changes secure attributes, position, scale or visibility out of combat.
--
-- Health is secret on Forever: it is handed to the StatusBar and the font string as is
-- and never read, compared or formatted by addon code.

local _, ns = ...
local L = ns.L
local W = ns.Widgets
local Compat = ns.Compat

local Panel = {}
ns.Panel = Panel

local TOKENS = 40
local ROW_W, ROW_H, TITLE_H = 220, 20, 22
local FADED_ALPHA = 0.35

local container, header, toggleButton, titleText, emptyText
local rows = {}
local pending = false   -- a secure change waits for combat to end
local shown = false     -- what we last applied to the container
local eventFrame
local elapsed = 0
local UPDATE_EVERY = 0.25
Panel.rows = rows

-- Restricted snippet: stack the rows whose token is a living hostile unit.
-- Runs in Blizzard's secure environment (only a few functions exist there).
local LAYOUT = [[
    local active = self:GetAttribute("tsActive") == 1
    local maxRows = self:GetAttribute("tsMaxRows") or 8
    local h = self:GetAttribute("tsRowH") or 20
    local n = 0
    for i = 1, 40 do
        local row = self:GetFrameRef("row" .. i)
        if row then
            if active and n < maxRows and tostring(self:GetAttribute("state-np" .. i)) == "1" then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -n * h)
                row:Show()
                n = n + 1
            else
                row:Hide()
            end
        end
    end
    if n < 1 then n = 1 end
    self:SetHeight(n * h)
]]

----------------------------------------------------------------------------
-- Building (out of combat only, once)

local function savePosition()
    local point, _, relPoint, x, y = container:GetPoint(1)
    ns.db.panelPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function restorePosition()
    container:ClearAllPoints()
    local p = ns.db.panelPos
    if type(p) == "table" and p.point then
        container:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        container:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
end

local function buildRow(i)
    local token = "nameplate" .. i
    local row = CreateFrame("Button", nil, header, "SecureActionButtonTemplate")
    row:SetSize(ROW_W, ROW_H)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("unit", token)
    row:SetAttribute("type1", "raidtarget")
    row:SetAttribute("action1", "set")
    row:SetAttribute("marker1", ns.db.settings.marker)
    row:SetAttribute("type2", "target")
    row:Hide()
    row.token = token

    row.bg = W.Background(row, "panel")
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("TOPLEFT", 4, -3)
    row.bar:SetPoint("BOTTOMRIGHT", -4, 3)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)
    row.barBg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetAllPoints()
    W.Fill(row.barBg, "bg")
    row.held = row:CreateTexture(nil, "ARTWORK")
    row.held:SetPoint("TOPLEFT")
    row.held:SetPoint("BOTTOMLEFT")
    row.held:SetWidth(3)
    W.Fill(row.held, "good")
    row.held:Hide()
    row.edges = W.Border(row, "border", 1)
    row.name = W.Text(row.bar, "small", "text")
    row.name:SetPoint("LEFT", 4, 0)
    row.name:SetPoint("RIGHT", -52, 0)
    row.name:SetWordWrap(false)
    row.hp = W.Text(row.bar, "small", "text")
    row.hp:SetPoint("RIGHT", -4, 0)
    row.hp:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        W.Tooltip(self, L.ADDON_TITLE, { L.ROW_TIP_LEFT, L.ROW_TIP_RIGHT })
    end)
    row:SetScript("OnLeave", W.HideTooltip)
    -- Runs after Blizzard's secure click handler; only logs, never acts.
    row:SetScript("PostClick", function(self, button, down)
        if down then return end
        ns.Log.Debug("row %s %s-click (in combat %s)", self.token, button == "RightButton" and "right" or "left",
            tostring(Compat.InCombat()))
    end)

    header:SetFrameRef("row" .. i, row)
    _G.RegisterStateDriver(header, "np" .. i, "[@" .. token .. ",harm,nodead] 1; 0")
    header:SetAttribute("_onstate-np" .. i, LAYOUT)
    return row
end

local function build()
    container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(ROW_W, TITLE_H)
    container:SetClampedToScreen(true)
    container:SetMovable(true)
    container:EnableMouse(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self)
        if not ns.db.settings.locked and not Compat.InCombat() then self:StartMoving() end
    end)
    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    W.Background(container, "bg")
    W.Border(container, "border", 1)

    toggleButton = CreateFrame("Button", nil, container)
    toggleButton:SetSize(18, 18)
    toggleButton:SetPoint("LEFT", 3, 0)
    toggleButton.icon = toggleButton:CreateTexture(nil, "ARTWORK")
    toggleButton.icon:SetAllPoints()
    toggleButton.icon:SetTexture("Interface\\AddOns\\Tanksign\\media\\skull")
    toggleButton:SetScript("OnClick", function() ns.State.Toggle() end)
    toggleButton:SetScript("OnEnter", function(self)
        W.Tooltip(self, L.ADDON_TITLE, { ns.db.settings.enabled and L.TOGGLE_TIP_ON or L.TOGGLE_TIP_OFF, L.TOGGLE_TIP_DRAG })
    end)
    toggleButton:SetScript("OnLeave", W.HideTooltip)

    titleText = W.Text(container, "small", "heading")
    titleText:SetPoint("LEFT", toggleButton, "RIGHT", 5, 0)

    header = CreateFrame("Frame", nil, container, "SecureHandlerStateTemplate")
    header:SetSize(ROW_W, ROW_H)
    header:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 0, 0)
    header:SetAttribute("tsRowH", ROW_H)

    emptyText = W.Text(header, "small", "muted")
    emptyText:SetPoint("LEFT", 6, 0)
    emptyText:SetText(L.PANEL_EMPTY)

    for i = 1, TOKENS do rows[i] = buildRow(i) end
end

----------------------------------------------------------------------------
-- Plain visuals (allowed any time: these are not protected)

local function color(region, role)
    local c = W.Color(role)
    region:SetStatusBarColor(c[1], c[2], c[3], 1)
end

local function updateHealth(row)
    local u = row.token
    -- Secret values go straight to Blizzard widgets; addon code never reads them.
    pcall(row.bar.SetMinMaxValues, row.bar, 0, _G.UnitHealthMax(u))
    pcall(row.bar.SetValue, row.bar, _G.UnitHealth(u))
    pcall(row.hp.SetText, row.hp, _G.UnitHealth(u))
end

local function updateRow(row)
    local u = row.token
    if Compat.Plain(_G.UnitExists(u)) ~= true then return end
    -- Names are secret inside instances: hand the value to the font string unread.
    if not pcall(row.name.SetText, row.name, _G.UnitName(u)) then row.name:SetText("?") end
    updateHealth(row)
    local held
    local mobInCombat = Compat.Plain(_G.UnitAffectingCombat(u), "?")
    if mobInCombat == false then
        held = nil -- not pulled yet: neither held nor loose
    else
        local statuses, count = ns.Roster.ThreatStatuses(u)
        held = ns.TankLogic.IsHeld(statuses, count)
        if held == false and mobInCombat == "?" then held = nil end
    end
    if held ~= row.lastHeld then
        ns.Log.Debug("%s %s: %s", u, tostring(Compat.Plain(_G.UnitName(u), "(name secret)")),
            held == true and "held by a tank" or held == false and "in combat, NOT held by a tank (loose)"
            or mobInCombat == false and "not in combat yet" or "tank threat unknown (secret)")
        row.lastHeld = held
    end
    if held == true then
        color(row.bar, "good"); row.held:Show()
    elseif held == false then
        color(row.bar, "bad"); row.held:Hide()
    else
        color(row.bar, "rule"); row.held:Hide()
    end
    local isTarget = Compat.Plain(_G.UnitIsUnit(u, "target")) == true
    for _, e in ipairs(row.edges) do W.Fill(e, isTarget and "accent" or "border") end
end

function Panel.UpdateAll()
    if not container then return end
    local any = false
    for _, row in ipairs(rows) do
        if Compat.Plain(_G.UnitExists(row.token)) == true then
            updateRow(row)
            any = true
        end
    end
    emptyText:SetShown(not any)
    -- How many rows the secure layout shows: the check that the restricted snippet works.
    local visible = 0
    for _, row in ipairs(rows) do if row:IsShown() then visible = visible + 1 end end
    local plates = 0
    for _, row in ipairs(rows) do if Compat.Plain(_G.UnitExists(row.token)) == true then plates = plates + 1 end end
    if visible ~= Panel.lastVisible or plates ~= Panel.lastPlates then
        ns.Log.Debug("panel: %d rows shown, %d nameplate tokens exist", visible, plates)
        Panel.lastVisible, Panel.lastPlates = visible, plates
    end
end

function Panel.UpdateToken(unit)
    local i = type(unit) == "string" and tonumber(unit:match("^nameplate(%d+)$"))
    if i and rows[i] then updateRow(rows[i]) end
end

local function drawToggle()
    if not toggleButton then return end
    local on = ns.db.settings.enabled
    local c = W.Color(on and "good" or "bad")
    toggleButton.icon:SetVertexColor(c[1], c[2], c[3], 1)
    titleText:SetText(L.ADDON_TITLE .. "  " .. ns.Palette.Wrap(on and "good" or "bad", on and L.ON or L.OFF))
end

----------------------------------------------------------------------------
-- Events (registered only while active)

local EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_TARGET_CHANGED" }

local function onEvent(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Panel.Apply() end
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "NAME_PLATE_UNIT_ADDED" then
        Panel.UpdateToken(unit)
    else
        Panel.UpdateAll()
    end
end

local function onUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    Panel.UpdateAll()
end

local function setListening(on)
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnUpdate", nil)
    if on then
        for _, e in ipairs(EVENTS) do pcall(eventFrame.RegisterEvent, eventFrame, e) end
        eventFrame:SetScript("OnUpdate", onUpdate)
    end
    -- A change that had to wait for combat to end is applied then, even when inactive.
    if pending then eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") end
end

----------------------------------------------------------------------------
-- Applying settings and state

function Panel.Apply()
    if not container then return end
    local s = ns.db.settings
    local inCombat = Compat.InCombat()
    local st = ns.ActiveLogic.PanelState(s, ns.State.active, inCombat, shown)
    drawToggle()
    toggleButton:SetShown(s.showToggle)
    if inCombat then
        -- Protected: only fade. Everything else waits for PLAYER_REGEN_ENABLED.
        pcall(container.SetAlpha, container, st.faded and FADED_ALPHA or s.alpha)
        pending = true
    else
        pending = false
        container:SetScale(s.scale)
        container:SetAlpha(s.alpha)
        container:EnableMouse(not s.locked)
        header:SetAttribute("tsActive", st.rows and 1 or 0)
        header:SetAttribute("tsMaxRows", s.maxRows)
        for _, row in ipairs(rows) do row:SetAttribute("marker1", s.marker) end
        header:Execute(LAYOUT)
        container:SetShown(st.show)
        header:SetShown(st.rows)
        shown = st.show
    end
    setListening(ns.State.active and st.rows)
    if ns.State.active and st.rows then Panel.UpdateAll() end
end

function Panel.Init()
    if container then return end
    if Compat.InCombat() then
        -- Secure frames cannot be created in combat (a /reload mid-fight): build afterwards.
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            Panel.Init()
        end)
        ns.Log.Info(L.PANEL_AFTER_COMBAT)
        return
    end
    build()
    restorePosition()
    eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", onEvent)
    ns.State.OnChange(Panel.Apply)
    Panel.Apply()
end

function Panel.ResetPosition()
    if not container or Compat.InCombat() then return false end
    ns.db.panelPos = nil
    restorePosition()
    return true
end

function Panel.IsBuilt()
    return container ~= nil
end
