-- UI/Palette.lua
-- PURE: no WoW globals. The color roles every Tanksign window, button and option uses.
-- Values are copied unchanged from Fellowship Ledger's "Plain" skin
-- (FellowshipLedger/UI/Palette.lua, SKINS.plain). Plain is the only skin.

local _, ns = ...

local Palette = {}
ns.Palette = Palette

Palette.ROLES = { "bg", "panel", "border", "text", "muted", "heading", "accent", "buttonBg", "buttonBorder",
    "buttonText", "rule", "rowAlt", "good", "bad" }

Palette.PLAIN = {
    bg = { 0.05, 0.05, 0.06, 0.92 }, panel = { 0.1, 0.1, 0.12, 0.9 }, border = { 0.45, 0.45, 0.5, 1 },
    text = { 0.95, 0.95, 0.95, 1 }, muted = { 0.7, 0.7, 0.72, 1 }, heading = { 1, 0.82, 0, 1 },
    accent = { 1, 0.82, 0, 1 }, buttonBg = { 0.25, 0.25, 0.28, 0.9 }, buttonBorder = { 0.5, 0.5, 0.55, 1 },
    buttonText = { 1, 0.82, 0, 1 }, rule = { 0.45, 0.45, 0.5, 1 }, rowAlt = { 1, 1, 1, 0.04 },
    good = { 0.4, 0.85, 0.5, 1 }, bad = { 1, 0.45, 0.4, 1 },
}

function Palette.Color(role)
    return Palette.PLAIN[role] or Palette.PLAIN.text
end

-- "|cffRRGGBB" escape for a color, for colored text inside a string.
function Palette.Code(c)
    local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
    return string.format("|cff%02x%02x%02x", byte(c[1]), byte(c[2]), byte(c[3]))
end

-- Text wrapped in a role's color.
function Palette.Wrap(role, text)
    return Palette.Code(Palette.Color(role)) .. tostring(text) .. "|r"
end
