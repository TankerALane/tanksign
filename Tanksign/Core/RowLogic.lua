-- Core/RowLogic.lua
-- PURE: must not touch WoW globals at load time.
-- Tags and dimming for a panel row, from plain unit facts. Any fact that came back
-- secret arrives as nil and simply adds no tag and no dimming.

local _, ns = ...

local RowLogic = {}
ns.RowLogic = RowLogic

-- UnitCreatureType's second return: creature type ids (locale-independent).
RowLogic.CRITTER = 8
RowLogic.TOTEM = 11
RowLogic.NONCOMBAT_PET = 12
RowLogic.WILD_PET = 14
RowLogic.MANA = 0 -- UnitPowerType

-- facts: { classification = "elite"|..., powerType = number, creatureTypeId = number,
--          playerControlled = bool }
-- Returns a list of short tags, most important first: "B" boss, "R" rare, "E" elite, "C" caster.
function RowLogic.Tags(facts)
    local tags = {}
    local c = facts.classification
    if c == "worldboss" then
        tags[#tags + 1] = "B"
    elseif c == "rareelite" then
        tags[#tags + 1] = "R"
        tags[#tags + 1] = "E"
    elseif c == "rare" then
        tags[#tags + 1] = "R"
    elseif c == "elite" then
        tags[#tags + 1] = "E"
    end
    if facts.powerType == RowLogic.MANA then tags[#tags + 1] = "C" end
    return tags
end

-- Critters, totems, pets: returns true and a reason when the row should be dimmed.
function RowLogic.Dim(facts)
    local t = facts.creatureTypeId
    if t == RowLogic.CRITTER or t == RowLogic.NONCOMBAT_PET or t == RowLogic.WILD_PET then return true, "critter" end
    if t == RowLogic.TOTEM then return true, "totem" end
    if facts.playerControlled == true then return true, "pet" end
    return false, nil
end
