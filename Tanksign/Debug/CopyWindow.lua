-- Debug/CopyWindow.lua
-- A movable window with a read-only, selectable text box, so a report can be
-- copied out of the game with Ctrl+A, Ctrl+C. Plain palette. If building the
-- window fails, the text goes to chat instead. The frame is unnamed (no global);
-- Esc closes it while the text box has focus.

local _, ns = ...
local L = ns.L
local W = ns.Widgets

local CopyWindow = {}
ns.CopyWindow = CopyWindow

local frame, title, edit
local current = ""

local function build()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(720, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.Background(f, "bg")
    W.Border(f, "border", 1)

    title = W.Text(f, "heading", "heading")
    title:SetPoint("TOPLEFT", 14, -12)

    local hint = W.Text(f, "small", "muted")
    hint:SetPoint("BOTTOMLEFT", 14, 16)
    hint:SetText(L.COPY_HINT)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 14, -38)
    scroll:SetPoint("BOTTOMRIGHT", -14, 44)
    W.Background(scroll, "panel")

    edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(680)
    edit:SetHeight(380)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnTextChanged", function(box, userInput)
        if userInput then box:SetText(current) end -- read-only
    end)
    scroll:SetScrollChild(edit)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(sf, delta)
        local range = sf:GetVerticalScrollRange() or 0
        local new = (sf:GetVerticalScroll() or 0) - delta * 40
        if new < 0 then new = 0 end
        if new > range then new = range end
        sf:SetVerticalScroll(new)
    end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local close = W.Button(f, L.CLOSE, 80, 22, function() f:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -14, 12)

    f:Hide()
    return f
end

function CopyWindow.Show(heading, text)
    current = text or ""
    if not frame then
        local ok, result = pcall(build)
        if not ok then
            ns.Log.Warn("Could not build the report window (%s). Printing to chat instead.", tostring(result))
            for line in current:gmatch("[^\n]+") do ns.Log.Info(line) end
            return
        end
        frame = result
    end
    title:SetText(heading or "")
    edit:SetText(current)
    edit:SetCursorPosition(0)
    frame:Show()
    edit:SetFocus()
    edit:HighlightText()
end

function CopyWindow.IsShown()
    return frame ~= nil and frame:IsShown()
end
