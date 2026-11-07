-- Core/Profiles.lua
-- PURE: must not touch WoW globals at load time.
-- Named settings profiles (for example "Dungeon" and "Raid"). The saved variables hold
-- db.profiles[name] = settings and db.profile = the active name. Nothing else stores a
-- second reference to a profile table, because the game would save it twice.

local _, ns = ...

local Profiles = {}
ns.Profiles = Profiles

Profiles.DEFAULT = "Default"
Profiles.DUNGEON = "Dungeon"
Profiles.RAID = "Raid"
Profiles.MAX_NAME = 24

-- Make sure there is at least one valid profile and an active one. Returns its settings.
function Profiles.Ensure(db)
    if type(db.profiles) ~= "table" then db.profiles = {} end
    for name, s in pairs(db.profiles) do
        if type(name) ~= "string" or type(s) ~= "table" then
            db.profiles[name] = nil
        else
            ns.Settings.Apply(s)
        end
    end
    if next(db.profiles) == nil then db.profiles[Profiles.DEFAULT] = ns.Settings.Apply({}) end
    if type(db.profile) ~= "string" or not db.profiles[db.profile] then
        db.profile = db.profiles[Profiles.DEFAULT] and Profiles.DEFAULT or Profiles.List(db)[1]
    end
    return db.profiles[db.profile]
end

function Profiles.List(db)
    local names = {}
    for name in pairs(db.profiles or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function cleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > Profiles.MAX_NAME then return nil end
    return name
end

-- New profile, copied from `from` (default: the active one). Returns name or nil, error key.
function Profiles.Create(db, name, from)
    name = cleanName(name)
    if not name then return nil, "PROFILE_BAD_NAME" end
    if db.profiles[name] then return nil, "PROFILE_EXISTS" end
    local source = db.profiles[from or db.profile] or {}
    local copy = {}
    for k, v in pairs(source) do copy[k] = v end
    db.profiles[name] = ns.Settings.Apply(copy)
    return name
end

function Profiles.Delete(db, name)
    if not db.profiles[name] then return false, "PROFILE_UNKNOWN" end
    if name == db.profile then return false, "PROFILE_ACTIVE" end
    db.profiles[name] = nil
    return true
end

-- Returns the settings of the newly active profile, or nil if it does not exist.
function Profiles.Switch(db, name)
    if not db.profiles[name] then return nil end
    db.profile = name
    return db.profiles[name]
end

-- Next name in the sorted list (for a cycle button).
function Profiles.Next(db)
    local names = Profiles.List(db)
    for i, n in ipairs(names) do
        if n == db.profile then return names[i % #names + 1] end
    end
    return names[1]
end

-- Automatic choice for an instance type ("party", "raid", anything else): the
-- "Dungeon" or "Raid" profile if it exists, otherwise the profile picked by hand.
function Profiles.ForInstance(db, instanceType)
    if instanceType == "party" and db.profiles[Profiles.DUNGEON] then return Profiles.DUNGEON end
    if instanceType == "raid" and db.profiles[Profiles.RAID] then return Profiles.RAID end
    if db.manualProfile and db.profiles[db.manualProfile] then return db.manualProfile end
    return db.profile
end

-- Restore one profile to defaults in place.
function Profiles.Reset(settings)
    for k in pairs(settings) do settings[k] = nil end
    return ns.Settings.Apply(settings)
end
