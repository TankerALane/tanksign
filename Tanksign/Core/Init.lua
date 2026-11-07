-- Core/Init.lua
-- Loaded last. Sets up the saved variables, detects the client, and registers
-- /tanksign and /ts. Globals created on purpose: TanksignDB (saved variables),
-- SLASH_TANKSIGN1/2 and SlashCmdList.TANKSIGN.

local _, ns = ...
local L = ns.L

local Init = {}
ns.Init = Init

local SCHEMA = 1

local function setupDB()
    local db = _G.TanksignDB
    if type(db) ~= "table" then db = {} end
    db.schema = db.schema or SCHEMA
    db.settings = db.settings or {}
    if db.settings.enabled == nil then db.settings.enabled = true end
    if db.settings.debug == nil then db.settings.debug = false end
    _G.TanksignDB = db
    ns.db = db
end

local function help()
    ns.Log.Info(L.HELP_HEADER, ns.VERSION)
    for _, line in ipairs(L.HELP_LINES) do ns.Log.Info("  " .. line) end
    ns.Log.Info(L.STAGE1_NOTE)
end

function Init.Slash(msg)
    local cmd, rest = ns.util.splitCommand(msg)
    if ns.inert then
        ns.Log.Warn(L.UNSUPPORTED, tostring(ns.Compat.interface))
        return
    end
    if cmd == "probe" then
        ns.Probe.Command(rest)
    elseif cmd == "version" then
        ns.Log.Info("%s %s by %s (%s)", L.ADDON_TITLE, ns.VERSION, ns.AUTHOR, ns.SUPPORT)
    else
        help()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ns.ADDON_NAME then
        setupDB()
        local flavor = ns.Compat.Detect()
        ns.inert = not ns.FlavorLogic.IsSupported(flavor)
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if ns.inert then
            ns.Log.Warn(L.UNSUPPORTED, tostring(ns.Compat.interface))
            return
        end
        ns.Probe.Start()
        ns.Log.Info(L.LOADED, ns.VERSION)
    end
end)

_G.SLASH_TANKSIGN1 = "/tanksign"
_G.SLASH_TANKSIGN2 = "/ts"
_G.SlashCmdList.TANKSIGN = Init.Slash
