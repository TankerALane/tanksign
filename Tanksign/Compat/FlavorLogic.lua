-- Compat/FlavorLogic.lua
-- PURE: must not touch WoW globals at load time.
-- Decides which client flavor we are on from the interface number. Tanksign ships
-- for WoW Forever only; the logic files never ask about the flavor, so retail
-- could be added later by adding a range here and a TOC.

local _, ns = ...

local FlavorLogic = {}
ns.FlavorLogic = FlavorLogic

FlavorLogic.FOREVER = "Forever"
FlavorLogic.UNKNOWN = "Unknown"

-- Forever uses 16xxx (16001 on build 1.60.1.70840; Questie and Fellowship Ledger use
-- the same 16000-16999 range).
function FlavorLogic.FromInterface(interface)
    local n = tonumber(interface)
    if not n then return FlavorLogic.UNKNOWN end
    if n >= 16000 and n < 17000 then return FlavorLogic.FOREVER end
    return FlavorLogic.UNKNOWN
end

function FlavorLogic.IsSupported(flavor)
    return flavor == FlavorLogic.FOREVER
end
