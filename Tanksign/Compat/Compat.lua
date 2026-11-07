-- Compat/Compat.lua
-- The only place that decides "does this client have API X?".
-- Rule: every uncertain call goes through Compat.Call (or is checked with Compat.Has
-- first), so a missing or failing API disables that one feature with a clear
-- message instead of raising a Lua error.

local _, ns = ...
local L = ns.L
local unpack = unpack or table.unpack

local Compat = {}
ns.Compat = Compat

Compat.flavor = nil     -- "Forever" | "Unknown", set by Detect()
Compat.tocFlavor = nil  -- the X-Flavor line of the TOC the client actually loaded
Compat.interface = nil
Compat.build = nil
Compat.version = nil

Compat.disabled = {} -- feature name -> reason it was disabled

-- Resolve a dotted path such as "C_NamePlate.GetNamePlates" against _G.
-- Never errors; returns nil if any part is missing.
function Compat.Resolve(path)
    local ok, value = pcall(function()
        local obj = _G
        for part in string.gmatch(path, "[^%.]+") do
            if type(obj) ~= "table" then return nil end
            obj = obj[part]
        end
        return obj
    end)
    if ok then return value end
    return nil
end

function Compat.Has(path)
    return type(Compat.Resolve(path)) == "function"
end

function Compat.IsDisabled(feature)
    return Compat.disabled[feature] ~= nil
end

function Compat.Disable(feature, reason)
    if Compat.disabled[feature] then return end
    Compat.disabled[feature] = reason or "unknown reason"
    ns.Log.Warn(L.FEATURE_DISABLED, feature, tostring(reason))
end

-- Call the API at `path` on behalf of `feature`. Returns ok followed by the
-- API's return values. A missing or failing API disables the feature.
function Compat.Call(feature, path, ...)
    if Compat.disabled[feature] then return false end
    local fn = Compat.Resolve(path)
    if type(fn) ~= "function" then
        Compat.Disable(feature, path .. " is missing")
        return false
    end
    local result = ns.util.pack(pcall(fn, ...))
    if not result[1] then
        Compat.Disable(feature, path .. " failed: " .. Compat.Describe(result[2]))
        return false
    end
    return true, unpack(result, 2, result.n)
end

-- Like Call, but never disables anything or logs. For the probe.
function Compat.Try(path, ...)
    local fn = Compat.Resolve(path)
    if type(fn) ~= "function" then return false end
    local result = ns.util.pack(pcall(fn, ...))
    if not result[1] then return false end
    return true, unpack(result, 2, result.n)
end

-- True if `value` is a secret value we must not inspect. On clients without
-- issecretvalue nothing is secret.
function Compat.IsSecret(value)
    local fn = _G.issecretvalue
    if type(fn) ~= "function" then return false end
    local ok, secret = pcall(fn, value)
    return ok and secret == true
end

-- Safe tostring that never inspects a secret value.
function Compat.Describe(value)
    if Compat.IsSecret(value) then return "<secret>" end
    local ok, text = pcall(tostring, value)
    if ok then return text end
    return "<unprintable>"
end

function Compat.GetAddOnMetadata(field)
    local fn = Compat.Resolve("C_AddOns.GetAddOnMetadata") or _G.GetAddOnMetadata
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ns.ADDON_NAME, field)
    if ok then return value end
    return nil
end

-- Work out which client we are on. Called once from Init at ADDON_LOADED.
function Compat.Detect()
    local ok, version, build, _, interface = pcall(_G.GetBuildInfo)
    if ok then
        Compat.version = version
        Compat.build = build
        Compat.interface = interface
    end
    Compat.flavor = ns.FlavorLogic.FromInterface(Compat.interface)
    Compat.tocFlavor = Compat.GetAddOnMetadata("X-Flavor")
    local tocVersion = Compat.GetAddOnMetadata("Version")
    if tocVersion and tocVersion ~= "" then ns.VERSION = tocVersion end
    return Compat.flavor
end

-- The value itself if it is readable, or `unknown` (default nil) if it is secret.
-- Use this on every unit fact before comparing it.
function Compat.Plain(value, unknown)
    if Compat.IsSecret(value) then return unknown end
    return value
end

function Compat.InCombat()
    local fn = _G.InCombatLockdown
    return type(fn) == "function" and fn() == true
end
