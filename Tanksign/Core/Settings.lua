-- Core/Settings.lua
-- PURE: must not touch WoW globals at load time.
-- Default settings, value checks, and the saved-variables migration.

local _, ns = ...

local Settings = {}
ns.Settings = Settings

Settings.SCHEMA = 2

Settings.TANK_SOURCES = { "auto", "role", "maintank", "name", "threat" }
Settings.MARKERS = { 8, 7, 6, 5, 4, 3, 2, 1 } -- skull first

Settings.DEFAULTS = {
    enabled = true,
    onlyInGroup = false,     -- only active in a group or an instance
    tankSource = "auto",     -- auto = role, then Main Tank, then fixed name, then threat
    tankName = "",           -- for tankSource "name" (and the auto chain)
    marker = 8,              -- skull
    showPanel = true,
    showToggle = true,       -- the small ON/OFF skull button on the panel
    locked = false,
    scale = 1.0,
    alpha = 1.0,
    maxRows = 8,
    showTags = true,         -- E elite, R rare, B boss, C caster (mana)
    dimTrivial = true,       -- dim critters, totems and pets
    debug = false,
}

local function valid(key, value)
    local d = Settings.DEFAULTS[key]
    if d == nil or type(value) ~= type(d) then return false end
    if key == "tankSource" then
        for _, s in ipairs(Settings.TANK_SOURCES) do if s == value then return true end end
        return false
    end
    if key == "marker" then return value >= 1 and value <= 8 and value % 1 == 0 end
    if key == "scale" then return value >= 0.5 and value <= 2 end
    if key == "alpha" then return value >= 0.2 and value <= 1 end
    if key == "maxRows" then return value >= 1 and value <= 15 and value % 1 == 0 end
    return true
end
Settings.IsValid = valid

-- Fill missing or invalid settings with defaults (in place) and return the table.
function Settings.Apply(settings)
    settings = type(settings) == "table" and settings or {}
    for k, v in pairs(Settings.DEFAULTS) do
        if not valid(k, settings[k]) then settings[k] = v end
    end
    return settings
end

-- Bring a saved-variables table up to the current schema. Returns the table.
function Settings.Migrate(db)
    if type(db) ~= "table" then db = {} end
    local from = tonumber(db.schema) or 0
    if from > Settings.SCHEMA then
        db.newerSchema = from -- written by a newer version; keep what we understand
    end
    if from < 2 and type(db.probe) == "table" then
        db.probe.combatSampling = false -- the probe build had it on; it is a debug tool now
    end
    db.settings = Settings.Apply(db.settings)
    if from < Settings.SCHEMA then db.schema = Settings.SCHEMA end
    return db
end

-- Parse "1.5" style user input into a number within [lo, hi], or nil.
function Settings.ParseNumber(text, lo, hi)
    local n = tonumber(text)
    if not n or n ~= n then return nil end
    if n < lo or n > hi then return nil end
    return n
end
