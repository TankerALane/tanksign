-- UI/Marks.lua
-- Marker icons for mobs YOU marked with Tanksign: on the panel row and above the mob's
-- nameplate. Forever hides a marked unit's marker from addons (GetRaidTargetIndex is
-- secret once set), so Tanksign remembers its own clicks (Core/MarkLogic.lua) and only
-- uses what the client still shows: an unmarked unit reads as plain nil, which clears
-- the memory. Markers placed by other players cannot be shown.
--
-- Nameplate icons are plain textures parented to the nameplate. If the client refuses
-- (forbidden nameplates), the feature turns itself off once, with a message.

local _, ns = ...
local Compat = ns.Compat

local Marks = {}
ns.Marks = Marks

local state = ns.MarkLogic.New()
Marks.state = state
local plateIcons = {} -- token -> texture shown on that token's nameplate

-- Blizzard's raid marker icons (1 star ... 7 cross, 8 skull).
function Marks.Icon(marker)
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. tostring(marker)
end

local function hidePlateIcon(token)
    local tex = plateIcons[token]
    if tex then
        tex:Hide()
        plateIcons[token] = nil
    end
end

local function showPlateIcon(token, marker)
    if Compat.IsDisabled("plateIcons") then return end
    local get = Compat.Resolve("C_NamePlate.GetNamePlateForUnit")
    if type(get) ~= "function" then return end
    local ok, err = pcall(function()
        local plate = get(token)
        if not plate then return end
        local tex = plate.tanksignMark
        if not tex then
            tex = plate:CreateTexture(nil, "OVERLAY")
            tex:SetSize(24, 24)
            tex:SetPoint("BOTTOM", plate, "TOP", 0, 2)
            plate.tanksignMark = tex
        end
        tex:SetTexture(Marks.Icon(marker))
        tex:Show()
        plateIcons[token] = tex
    end)
    if not ok then Compat.Disable("plateIcons", Compat.Describe(err)) end
end

local function refreshPlate(token)
    local marker = ns.MarkLogic.Get(state, token)
    if marker and ns.db.settings.plateIcons then
        showPlateIcon(token, marker)
    else
        hidePlateIcon(token)
    end
end

-- Hide every icon, then draw the ones the memory holds (after any change).
local function refreshAll()
    for token in pairs(plateIcons) do hidePlateIcon(token) end
    for token in pairs(state.byToken) do refreshPlate(token) end
end

function Marks.Placed(marker, token)
    ns.MarkLogic.Place(state, marker, token)
    ns.Log.Debug("marker %d placed on %s (remembered)", marker, token)
    refreshAll()
    if ns.Panel then ns.Panel.UpdateAll() end
end

function Marks.Removed(token)
    ns.MarkLogic.Removed(state, token)
    hidePlateIcon(token)
end

-- A plate frame was (re)used for a new unit: clear any icon left on it.
function Marks.PlateAdded(token)
    hidePlateIcon(token)
    local get = Compat.Resolve("C_NamePlate.GetNamePlateForUnit")
    if type(get) == "function" then
        local ok, plate = pcall(get, token)
        if ok and plate and plate.tanksignMark then plate.tanksignMark:Hide() end
    end
end

-- Check the client's answer for this token and update the memory.
function Marks.Observe(token)
    local fn = _G.GetRaidTargetIndex
    if type(fn) ~= "function" or not ns.MarkLogic.Get(state, token) then
        -- Learn readable markers placed by others too, when the client shows them.
        if type(fn) == "function" then
            local ok, v = pcall(fn, token)
            if ok and not Compat.IsSecret(v) and type(v) == "number" then
                ns.MarkLogic.Observe(state, token, v)
                refreshPlate(token)
            end
        end
        return
    end
    local ok, v = pcall(fn, token)
    if not ok then return end
    local seen
    if Compat.IsSecret(v) then seen = "hidden" elseif v == nil then seen = "none" else seen = v end
    local before = ns.MarkLogic.Get(state, token)
    ns.MarkLogic.Observe(state, token, seen)
    if ns.MarkLogic.Get(state, token) ~= before then
        ns.Log.Debug("%s: marker %s no longer there (client says %s)", token, tostring(before), tostring(seen))
        refreshPlate(token)
    end
end

function Marks.Get(token)
    return ns.MarkLogic.Get(state, token)
end

-- The nameplate token for a unit like "mouseover" or "party1target", if the client lets
-- us tell (UnitIsUnit can be secret). nil when unknown.
function Marks.PlateFor(unit)
    for i = 1, 40 do
        local token = "nameplate" .. i
        local ok, same = pcall(_G.UnitIsUnit, token, unit)
        if ok and Compat.Plain(same) == true then return token end
    end
    return nil
end

function Marks.Refresh()
    refreshAll()
end
