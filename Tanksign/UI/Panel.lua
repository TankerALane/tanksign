-- UI/Panel.lua
-- The mob panel (docs/DECISIONS.md D-007).
--
-- Rows are SECURE buttons, one per nameplate token (nameplate1..40):
--   left click  -> type "raidtarget", action "set", marker <setting>: Blizzard's code marks the mob
-- (Right-click targeting was removed: Forever ignores every secure way of targeting
-- through a nameplate token, docs/DECISIONS.md D-010.)
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
Panel.errors = {} -- step -> first error message, shown by /ts diag and saved with the session

-- Run one setup step; on failure remember why, say so once, and carry on.
local function step(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local msg = Compat.Describe(err)
        if not Panel.errors[name] then
            Panel.errors[name] = msg
            ns.Log.Warn(L.PANEL_STEP_FAILED, name, msg)
        end
        ns.Log.Debug("panel step %s failed: %s", name, msg)
    end
    return ok
end

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
    local row = CreateFrame("Button", nil, header, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    row:SetSize(ROW_W, ROW_H)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:SetAttribute("unit", token)
    row:SetAttribute("type1", "raidtarget")
    row:SetAttribute("action1", "set")
    row:SetAttribute("marker1", ns.db.settings.marker)
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
        W.Tooltip(self, L.ADDON_TITLE, { L.ROW_TIP_LEFT })
    end)
    row:SetScript("OnLeave", W.HideTooltip)
    -- Runs after Blizzard's secure click handler; only logs, never acts.
    row:SetScript("PostClick", function(self, button, down)
        if down then return end
        ns.Log.Debug("row %s %s-click (in combat %s)", self.token, button == "LeftButton" and "left" or tostring(button),
            tostring(Compat.InCombat()))
    end)

    step("frameref", header.SetFrameRef, header, "row" .. i, row)
    step("onstate", header.SetAttribute, header, "_onstate-np" .. i, LAYOUT)
    -- Forever answers 0 to "[@nameplateN,harm,nodead]" even for a living enemy (probe,
    -- /ts diag 2026-11-06), so rows follow Blizzard's unit watch instead: it sets the
    -- row's "state-unitexists" while the nameplate token exists, and the row passes that
    -- to the header, whose layout snippet stacks the rows. All of it runs in secure code.
    step("frameref", row.SetFrameRef, row, "header", header)
    step("rowstate", row.SetAttribute, row, "_onstate-unitexists",
        'self:GetFrameRef("header"):SetAttribute("state-np' .. i .. '", newstate and "1" or "0")')
    step("unitwatch", _G.RegisterUnitWatch, row, true)
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
        step("scale", container.SetScale, container, s.scale)
        step("alpha", container.SetAlpha, container, s.alpha)
        step("mouse", container.EnableMouse, container, not s.locked)
        step("attributes", function()
            header:SetAttribute("tsActive", st.rows and 1 or 0)
            header:SetAttribute("tsMaxRows", s.maxRows)
            for _, row in ipairs(rows) do row:SetAttribute("marker1", s.marker) end
        end)
        step("show", function()
            container:SetShown(st.show)
            header:SetShown(st.rows)
        end)
        step("layout", header.Execute, header, LAYOUT)
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

-- /ts diag: what the client really did with the secure rows. Reads only.
-- Live tests of the secure pieces, run only by /ts diag out of combat (not at logout).
local function secureSelfTest(add)
    if Compat.InCombat() then
        add("self-test skipped: in combat")
        return
    end
    local ok, err = pcall(header.Execute, header, [[ self:SetAttribute("tsDiagRan", "yes") ]])
    add("restricted Execute: ok=%s ran=%s err=%s", tostring(ok), Compat.Describe(header:GetAttribute("tsDiagRan")),
        ok and "none" or Compat.Describe(err))
    ok, err = pcall(header.Execute, header,
        [[ local r = self:GetFrameRef("row1") self:SetAttribute("tsDiagRef", r and "yes" or "no") ]])
    add("GetFrameRef in snippet: ok=%s ref=%s err=%s", tostring(ok), Compat.Describe(header:GetAttribute("tsDiagRef")),
        ok and "none" or Compat.Describe(err))
    ok, err = pcall(header.Execute, header, [[ self:SetAttribute("tsDiagStr", tostring(12)) ]])
    add("tostring in snippet: ok=%s value=%s err=%s", tostring(ok), Compat.Describe(header:GetAttribute("tsDiagStr")),
        ok and "none" or Compat.Describe(err))
    ok, err = pcall(header.Execute, header, LAYOUT)
    local shownNow = 0
    for _, row in ipairs(rows) do if row:IsShown() then shownNow = shownNow + 1 end end
    add("layout run by hand: ok=%s rows shown after=%d err=%s", tostring(ok), shownNow, ok and "none" or Compat.Describe(err))
end
Panel.secureSelfTest = secureSelfTest

function Panel.Diagnose(selfTest)
    local out = {}
    -- tostring of the first return value, even when a method returns nothing
    local function str(...) return tostring((...)) end
    local function add(fmt, ...) out[#out + 1] = string.format(fmt, ...) end
    if not container then
        add("panel not built")
        return out
    end
    add("container shown=%s visible=%s; header shown=%s visible=%s height=%s",
        str(container:IsShown()), str(container:IsVisible()), str(header:IsShown()),
        str(header:IsVisible()), Compat.Describe(header:GetHeight()))
    add("tsActive=%s tsMaxRows=%s active=%s (%s) listening=%s",
        Compat.Describe(header:GetAttribute("tsActive")), Compat.Describe(header:GetAttribute("tsMaxRows")),
        tostring(ns.State.active), tostring(ns.State.reason), str(eventFrame and eventFrame:IsEventRegistered("UNIT_HEALTH")))
    local onstate = header:GetAttribute("_onstate-np1")
    add("onstate snippet set=%s, frameref row1=%s", tostring(type(onstate) == "string"),
        tostring(header:GetAttribute("frameref-row1") ~= nil))
    local any = false
    local variantsDone = false
    for i, row in ipairs(rows) do
        local exists = Compat.Plain(_G.UnitExists(row.token), "SECRET")
        local state = header:GetAttribute("state-np" .. i)
        if exists == true or row:IsShown() or (state ~= nil and tostring(state) ~= "0") then
            any = true
            -- What the macro conditional itself answers, asked from addon code.
            local cond = "n/a"
            local parse = _G.SecureCmdOptionParse
            if type(parse) == "function" then
                local okP, r = pcall(parse, "[@" .. row.token .. ",harm,nodead] 1; 0")
                cond = okP and Compat.Describe(r) or ("error " .. Compat.Describe(r))
            end
            add("%s exists=%s canAttack=%s dead=%s watch=%s headerState=%s condition=%s rowShown=%s",
                row.token, tostring(exists), Compat.Describe(Compat.Plain(_G.UnitCanAttack("player", row.token), "SECRET")),
                Compat.Describe(Compat.Plain(_G.UnitIsDead(row.token), "SECRET")),
                Compat.Describe(row:GetAttribute("state-unitexists")), Compat.Describe(state), cond, str(row:IsShown()))
            if type(parse) == "function" and not variantsDone then
                -- Which part of the macro condition does Forever reject for nameplates?
                variantsDone = true
                local parts = {}
                for _, c in ipairs({ "[@TOKEN] 1; 0", "[@TOKEN,exists] 1; 0", "[@TOKEN,harm] 1; 0",
                    "[@TOKEN,nodead] 1; 0", "[@TOKEN,harm,nodead] 1; 0", "[@target,harm,nodead] 1; 0" }) do
                    local text = c:gsub("TOKEN", row.token)
                    local okP, r = pcall(parse, text)
                    parts[#parts + 1] = text:match("^(%b[])") .. "=" .. (okP and Compat.Describe(r) or "error")
                end
                add("conditions: %s", table.concat(parts, " "))
            end
        end
    end
    if not any then add("no nameplate tokens exist and no row has a state") end
    if selfTest then secureSelfTest(add) end
    local errs = {}
    for k, v in pairs(Panel.errors) do errs[#errs + 1] = k .. ": " .. v end
    add("step errors: %s", #errs > 0 and table.concat(errs, " | ") or "none")
    local disabled = {}
    for k, v in pairs(Compat.disabled) do disabled[#disabled + 1] = k .. ": " .. tostring(v) end
    add("disabled features: %s", #disabled > 0 and table.concat(disabled, " | ") or "none")
    return out
end

function Panel.IsBuilt()
    return container ~= nil
end
