-- UI/Widgets.lua
-- Builders shared by every Tanksign window, button and option. Styling follows
-- Fellowship Ledger's UI/Widgets.lua with its "Plain" skin: flat fills from the
-- palette roles, 1px borders, game fonts with a black drop shadow.

local _, ns = ...
local Palette = ns.Palette

local W = {}
ns.Widgets = W

-- Font roles -> Blizzard font objects (Fellowship Ledger's "normal" size row).
local FONTS = { small = "GameFontHighlightSmall", body = "GameFontHighlight", large = "GameFontHighlightLarge",
    heading = "GameFontNormalLarge" }

function W.Color(role)
    return Palette.Color(role)
end

local function paint(region, role, alpha)
    local c = W.Color(role)
    region:SetColorTexture(c[1], c[2], c[3], alpha or c[4])
end
W.Paint = paint

local function style(fs, fontRole, colorRole)
    local fo = _G[FONTS[fontRole] or FONTS.body]
    if fo then fs:SetFontObject(fo) end
    local c = W.Color(colorRole)
    fs:SetTextColor(c[1], c[2], c[3], c[4])
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

function W.Fill(region, role, alpha)
    paint(region, role, alpha)
    return region
end

function W.Background(frame, role, alpha)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    return W.Fill(bg, role or "bg", alpha)
end

function W.Border(frame, role, size)
    size = size or 1
    local edges = {}
    local function edge(p1, p2, w, h)
        local t = frame:CreateTexture(nil, "BORDER")
        W.Fill(t, role or "border")
        t:SetPoint(p1); t:SetPoint(p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        edges[#edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", nil, size)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, size)
    edge("TOPLEFT", "BOTTOMLEFT", size, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", size, nil)
    return edges
end

function W.Rule(parent, role)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    return W.Fill(t, role or "rule")
end

-- fontRole: "small" | "body" | "large" | "heading"; colorRole: a Palette role.
function W.Text(parent, fontRole, colorRole)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    style(fs, fontRole or "body", colorRole or "text")
    fs:SetJustifyH("LEFT")
    return fs
end

function W.SetTextRole(fs, colorRole)
    local c = W.Color(colorRole)
    fs:SetTextColor(c[1], c[2], c[3], c[4])
end

-- A flat text button. b:SetSelected(on) draws a stronger fill.
function W.Button(parent, label, width, height, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 90, height or 22)
    b.selected = false
    b.bg = W.Background(b, "buttonBg")
    W.Border(b, "buttonBorder", 1)
    b.text = W.Text(b, "small", "buttonText")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) if not self.selected then paint(self.bg, "buttonBg", 0.6) end end)
    b:SetScript("OnLeave", function(self) if not self.selected then paint(self.bg, "buttonBg") end end)
    function b:SetSelected(on)
        self.selected = on
        paint(self.bg, on and "accent" or "buttonBg", on and 0.55 or nil)
    end
    return b
end

function W.Tooltip(owner, title, lines)
    local tip = _G.GameTooltip
    if not tip then return end
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:SetText(title or "", 1, 1, 1)
    for _, l in ipairs(lines or {}) do tip:AddLine(l, 0.9, 0.9, 0.9, true) end
    tip:Show()
end

function W.HideTooltip()
    if _G.GameTooltip then _G.GameTooltip:Hide() end
end

-- A section heading with a rule under it (Fellowship Ledger's settings style).
function W.Heading(parent, text)
    local fs = W.Text(parent, "large", "heading")
    fs:SetText(text)
    local rule = W.Rule(parent, "rule")
    rule:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    rule:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    return fs
end

-- A toggle drawn as "[x] Label" / "[ ] Label" (text, not color, shows the state), as in
-- Fellowship Ledger. get() returns the value; set(v) stores it. t:Refresh() redraws.
function W.Toggle(parent, label, get, set, width)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(width or 360, 20)
    t.text = W.Text(t, "body", "text")
    t.text:SetPoint("LEFT")
    function t:Refresh()
        self.text:SetText((get() and "[x] " or "[ ] ") .. label)
    end
    t:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
    end)
    t:Refresh()
    return t
end

-- "Label: [ value ]" button that steps through choices. getText() shows the current
-- value; onClick advances it.
function W.Cycle(parent, label, getText, onClick, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(360, 22)
    f.label = W.Text(f, "body", "text")
    f.label:SetPoint("LEFT")
    f.label:SetText(label)
    f.button = W.Button(f, "", width or 150, 20, function() onClick(); f:Refresh() end)
    f.button:SetPoint("LEFT", 170, 0)
    function f:Refresh() self.button.text:SetText(getText()) end
    f:Refresh()
    return f
end

-- A horizontal slider in the Plain palette: track, gold thumb, value text.
function W.Slider(parent, label, lo, hi, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(360, 22)
    f.label = W.Text(f, "body", "text")
    f.label:SetPoint("LEFT")
    f.label:SetText(label)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(150, 14)
    s:SetPoint("LEFT", 170, 0)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    W.Fill(track, "buttonBg")
    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(8, 14)
    W.Fill(thumb, "accent")
    s:SetThumbTexture(thumb)
    f.value = W.Text(f, "small", "muted")
    f.value:SetPoint("LEFT", s, "RIGHT", 8, 0)
    f.slider = s
    local updating = false
    s:SetScript("OnValueChanged", function(_, v)
        if updating then return end
        v = math.floor(v / step + 0.5) * step
        set(v)
        f.value:SetText(string.format(fmt or "%.2f", v))
    end)
    function f:Refresh()
        updating = true
        s:SetValue(get())
        updating = false
        f.value:SetText(string.format(fmt or "%.2f", get()))
    end
    f:Refresh()
    return f
end

-- A one-line text box with the panel background and a border. onEnter(text) on Enter.
function W.EditBox(parent, width, onEnter)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(width or 150, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(_G.GameFontHighlightSmall)
    e:SetTextInsets(5, 5, 0, 0)
    W.Background(e, "panel")
    W.Border(e, "buttonBorder", 1)
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnter then onEnter(self:GetText()) end
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

-- A vertical scroll area: returns scrollFrame, content. Mouse wheel scrolls.
function W.ScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local new = (self:GetVerticalScroll() or 0) - delta * 40
        if new < 0 then new = 0 end
        if new > range then new = range end
        self:SetVerticalScroll(new)
    end)
    scroll:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w or 10) end)
    return scroll, content
end
