-- UI/Keys.lua
-- Key bindings (Bindings.xml). Two are SECURE buttons that Blizzard's code runs on a
-- key press, so they mark in combat:
--   TanksignSkullTankTarget  marks the tank's target ("target" when you are the tank)
--   TanksignSkullMouseover   marks the mob under the mouse
-- Key bindings need global button names; these two (and the BINDING_* strings) are
-- the only globals besides the saved variables and slash commands (D-005, D-007).
-- Their unit and marker attributes change only out of combat.

local _, ns = ...
local L = ns.L
local Compat = ns.Compat

local Keys = {}
ns.Keys = Keys

local tankButton, mouseoverButton
local pending = false
local waitFrame

_G.BINDING_HEADER_TANKSIGN = L.ADDON_TITLE
_G.BINDING_NAME_TANKSIGN_TOGGLE = L.BIND_TOGGLE
_G["BINDING_NAME_CLICK TanksignSkullTankTarget:LeftButton"] = L.BIND_TANK_TARGET
_G["BINDING_NAME_CLICK TanksignSkullMouseover:LeftButton"] = L.BIND_MOUSEOVER

local function makeButton(name, unit)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "raidtarget")
    b:SetAttribute("action", "set")
    b:SetAttribute("marker", ns.db.settings.marker)
    if unit then b:SetAttribute("unit", unit) end
    b:Hide()
    return b
end

function Keys.TankTargetUnit()
    local tank = ns.Roster.MainTankUnit()
    if not tank then return nil end
    if tank == "player" then return "target" end
    return tank .. "target"
end

function Keys.Update()
    if not tankButton then return end
    if Compat.InCombat() then
        if not pending then
            pending = true
            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end
    pending = false
    local marker = ns.db.settings.marker
    tankButton:SetAttribute("marker", marker)
    mouseoverButton:SetAttribute("marker", marker)
    -- Disabled or no known tank: the key does nothing (no unit).
    local unit = ns.db.settings.enabled and Keys.TankTargetUnit() or nil
    tankButton:SetAttribute("unit", unit)
    mouseoverButton:SetAttribute("unit", ns.db.settings.enabled and "mouseover" or nil)
    ns.Log.Debug("keys: tank's target key -> %s", tostring(unit))
end

function Keys.Init()
    if tankButton or Compat.InCombat() then return end
    tankButton = makeButton("TanksignSkullTankTarget")
    mouseoverButton = makeButton("TanksignSkullMouseover", "mouseover")
    waitFrame = CreateFrame("Frame")
    waitFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Keys.Update()
    end)
    ns.State.OnChange(Keys.Update)
    Keys.Update()
end
