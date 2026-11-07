-- Debug/ProbeChecks.lua
-- PURE: data only, must not touch WoW globals at load time.
--
-- Every WoW API, event and value Tanksign plans to rely on. /ts probe runs these;
-- docs/API-VERIFICATION.md is generated from this file (tools/gen_verify_doc.py)
-- and a unit test fails if the two drift apart.
--
-- Keep ONE entry per line in this exact shape so the doc generator can read it:
--   { id = "...", kind = "...", area = "...", why = "..." [, expect = "..."] [, probe = false] [, test = "..."] },
--
-- kind:
--   api     id is a dotted global path; passes if it resolves to `expect` (default "function").
--   event   id is "ev:EVENT_NAME"; passes if the client knows the event. The probe also
--           counts how often it fires and keeps a few argument samples. probe = false
--           checks existence only.
--   custom  id is "x:name"; a function in Debug/Probe.lua inspects a value. `test` is the
--           matching command for running it by hand.
--   manual  id is "m:name"; only a person can check it by looking. `test` says how.

local _, ns = ...

ns.ProbeChecks = {
    -- Build
    { id = "x:build", kind = "custom", area = "Build", why = "interface number, client version, project id, which TOC loaded", test = "/dump GetBuildInfo()" },
    { id = "GetBuildInfo", kind = "api", area = "Build", why = "read client version and interface number" },
    { id = "C_AddOns.GetAddOnMetadata", kind = "api", area = "Build", why = "read our TOC fields (version, flavor)" },
    { id = "C_EventUtils.IsEventValid", kind = "api", area = "Build", why = "how the probe checks events" },
    { id = "m:toc.icon", kind = "manual", area = "Build", why = "IconTexture shows in the AddOns list", test = "Esc > AddOns: the skull icon shows next to Tanksign" },
    { id = "m:slash", kind = "manual", area = "Build", why = "/ts and /tanksign are not taken by another addon", test = "type /ts: the Tanksign command list appears" },

    -- Secret values (the modern engine can hide combat values from addons)
    { id = "issecretvalue", kind = "api", area = "Secrets", why = "test a value before reading it" },
    { id = "canaccesssecrets", kind = "api", area = "Secrets", why = "whether addon code may read secrets right now" },
    { id = "canaccessvalue", kind = "api", area = "Secrets", why = "alternative per-value secret check" },
    { id = "x:secrets.context", kind = "custom", area = "Secrets", why = "canaccesssecrets() result and any C_Secrets functions", test = "/dump canaccesssecrets()" },

    -- Threat
    { id = "UnitDetailedThreatSituation", kind = "api", area = "Threat", why = "isTanking, status, percent and raw threat of a group member on a mob" },
    { id = "UnitThreatSituation", kind = "api", area = "Threat", why = "coarse threat status (0-3) of a group member on a mob" },
    { id = "UnitThreatPercentageOfLead", kind = "api", area = "Threat", why = "optional: threat relative to the leader" },
    { id = "ev:UNIT_THREAT_LIST_UPDATE", kind = "event", area = "Threat", why = "a mob's threat list changed: re-evaluate" },
    { id = "ev:UNIT_THREAT_SITUATION_UPDATE", kind = "event", area = "Threat", why = "a unit's threat status changed" },

    -- Health and unit facts
    { id = "UnitHealth", kind = "api", area = "Units", why = "current health of a mob" },
    { id = "UnitHealthMax", kind = "api", area = "Units", why = "maximum health, for percent mode" },
    { id = "UnitHealthPercent", kind = "api", area = "Units", why = "optional: percent health without dividing" },
    { id = "UnitExists", kind = "api", area = "Units", why = "is a unit token filled" },
    { id = "UnitIsUnit", kind = "api", area = "Units", why = "are two tokens the same mob (dedupe nameplates, target, focus)" },
    { id = "UnitGUID", kind = "api", area = "Units", why = "stable identity of a mob across tokens" },
    { id = "UnitCanAttack", kind = "api", area = "Units", why = "hostile and attackable" },
    { id = "UnitIsDead", kind = "api", area = "Units", why = "skip dead mobs" },
    { id = "UnitIsDeadOrGhost", kind = "api", area = "Units", why = "skip dead mobs (alternative)" },
    { id = "UnitAffectingCombat", kind = "api", area = "Units", why = "mob and player in combat" },
    { id = "UnitClassification", kind = "api", area = "Units", why = "elite / rare / boss / trivial / minus" },
    { id = "UnitCreatureType", kind = "api", area = "Units", why = "critters and totems" },
    { id = "UnitPlayerControlled", kind = "api", area = "Units", why = "skip player pets and guardians" },
    { id = "UnitIsPlayer", kind = "api", area = "Units", why = "skip enemy players" },
    { id = "UnitPowerType", kind = "api", area = "Units", why = "mana users count as casters" },
    { id = "UnitName", kind = "api", area = "Units", why = "mob name for debug lines" },
    { id = "ev:UNIT_HEALTH", kind = "event", area = "Units", why = "a unit's health changed: re-evaluate" },
    { id = "ev:UNIT_FLAGS", kind = "event", area = "Units", why = "combat flags changed", probe = false },
    { id = "x:units.sample", kind = "custom", area = "Units", why = "for every visible mob token: which values are readable and which are secret", test = "/ts probe (out of combat), then fight with combat sampling on" },

    -- Nameplates
    { id = "C_NamePlate.GetNamePlates", kind = "api", area = "Nameplates", why = "list visible nameplates" },
    { id = "C_NamePlate.GetNamePlateForUnit", kind = "api", area = "Nameplates", why = "find the plate frame of a unit (for the glow)" },
    { id = "ev:NAME_PLATE_UNIT_ADDED", kind = "event", area = "Nameplates", why = "a nameplate token appeared" },
    { id = "ev:NAME_PLATE_UNIT_REMOVED", kind = "event", area = "Nameplates", why = "a nameplate token went away" },
    { id = "x:nameplates", kind = "custom", area = "Nameplates", why = "visible plates, their unit tokens, nameplate CVars", test = "/dump #C_NamePlate.GetNamePlates()" },

    -- Raid markers
    { id = "SetRaidTarget", kind = "api", area = "Marking", why = "put the skull (8) on a unit" },
    { id = "GetRaidTargetIndex", kind = "api", area = "Marking", why = "read the marker on a unit" },
    { id = "CanBeRaidTarget", kind = "api", area = "Marking", why = "optional: can this unit carry a marker" },
    { id = "ev:RAID_TARGET_UPDATE", kind = "event", area = "Marking", why = "a marker moved (detect manual marks)" },
    { id = "x:secure.mark", kind = "custom", area = "Marking", why = "results of /ts probe buttons: can a secure button you click place the skull", test = "/ts probe buttons" },
    { id = "C_Secrets.ShouldUnitHealthMaxBeSecret", kind = "api", area = "Secrets", why = "Blizzard's own answer: is this unit's health secret" },
    { id = "C_Secrets.ShouldUnitThreatValuesBeSecret", kind = "api", area = "Secrets", why = "Blizzard's own answer: are threat values on this unit secret" },
    { id = "C_Secrets.ShouldUnitThreatStateBeSecret", kind = "api", area = "Secrets", why = "Blizzard's own answer: is threat status on this unit secret" },
    { id = "RegisterStateDriver", kind = "api", area = "Targeting", why = "secure [@nameplateN,harm,nodead] visibility for panel rows, also in combat" },
    { id = "UnregisterStateDriver", kind = "api", area = "Targeting", why = "remove a state driver" },
    { id = "m:panel", kind = "manual", area = "Targeting", why = "panel rows appear for hostile plates, left-click marks, right-click targets, in combat too", test = "fight a pack with the panel shown" },
    { id = "RegisterUnitWatch", kind = "api", area = "Targeting", why = "secure frames that show and hide with a unit, even in combat" },
    { id = "x:mark.test", kind = "custom", area = "Marking", why = "results of /ts probe mark (solo, party leader, party member, in combat)", test = "/ts probe mark" },

    -- Group, roles and permissions
    { id = "UnitGroupRolesAssigned", kind = "api", area = "Group", why = "TANK / HEALER / DAMAGER role of a member" },
    { id = "UnitGroupRolesAssignedEnum", kind = "api", area = "Group", why = "optional: role as an enum" },
    { id = "GetPartyAssignment", kind = "api", area = "Group", why = "Main Tank assignment (\"MAINTANK\")" },
    { id = "GetRaidRosterInfo", kind = "api", area = "Group", why = "raid role column (MAINTANK)" },
    { id = "IsInGroup", kind = "api", area = "Group", why = "party or raid" },
    { id = "IsInRaid", kind = "api", area = "Group", why = "raid unit tokens" },
    { id = "IsInInstance", kind = "api", area = "Group", why = "only active in group or instance" },
    { id = "GetNumGroupMembers", kind = "api", area = "Group", why = "roster size" },
    { id = "UnitIsGroupLeader", kind = "api", area = "Group", why = "marking permission" },
    { id = "UnitIsGroupAssistant", kind = "api", area = "Group", why = "marking permission" },
    { id = "IsEveryoneAssistant", kind = "api", area = "Group", why = "marking permission when everyone is assistant" },
    { id = "ev:GROUP_ROSTER_UPDATE", kind = "event", area = "Group", why = "roster or roles changed" },
    { id = "ev:PLAYER_ROLES_ASSIGNED", kind = "event", area = "Group", why = "roles changed" },
    { id = "ev:PARTY_LEADER_CHANGED", kind = "event", area = "Group", why = "marking permission changed" },
    { id = "x:group", kind = "custom", area = "Group", why = "each member's role, Main Tank flag, and the player's leader/assistant state", test = "/dump UnitGroupRolesAssigned(\"player\")" },

    -- Combat state
    { id = "InCombatLockdown", kind = "api", area = "Combat", why = "secure frames are locked" },
    { id = "GetTime", kind = "api", area = "Combat", why = "switch delay and cooldown timers" },
    { id = "C_Timer.After", kind = "api", area = "Combat", why = "short one-off timers" },
    { id = "ev:PLAYER_REGEN_DISABLED", kind = "event", area = "Combat", why = "combat started" },
    { id = "ev:PLAYER_REGEN_ENABLED", kind = "event", area = "Combat", why = "combat ended" },
    { id = "ev:ADDON_ACTION_BLOCKED", kind = "event", area = "Combat", why = "we hit a protected action in combat" },
    { id = "ev:ADDON_ACTION_FORBIDDEN", kind = "event", area = "Combat", why = "we hit a protected action at any time" },

    -- Targeting
    { id = "TargetUnit", kind = "api", area = "Targeting", why = "exists, but protected on modern clients (tested by /ts probe target)" },
    { id = "x:target.test", kind = "custom", area = "Targeting", why = "results of /ts probe target (is addon targeting blocked)", test = "/ts probe target" },
    { id = "x:secure.button", kind = "custom", area = "Targeting", why = "a SecureActionButtonTemplate button can be made and given a unit", test = "/ts probe (out of combat)" },
    { id = "SetOverrideBindingClick", kind = "api", area = "Targeting", why = "bind a key to our secure button" },
    { id = "GetBindingKey", kind = "api", area = "Targeting", why = "show which key is bound" },
    { id = "x:bindings", kind = "custom", area = "Targeting", why = "built-in key bindings about raid markers or nameplates", test = "/ts probe" },

    -- Options panel and alerts
    { id = "Settings.RegisterCanvasLayoutCategory", kind = "api", area = "Options", why = "options page in Interface Options" },
    { id = "Settings.RegisterAddOnCategory", kind = "api", area = "Options", why = "options page in Interface Options" },
    { id = "Settings.OpenToCategory", kind = "api", area = "Options", why = "/ts options opens our page" },
    { id = "PlaySound", kind = "api", area = "Options", why = "alert sound when the skull moves" },
    { id = "SOUNDKIT", kind = "api", area = "Options", why = "sound ids", expect = "table" },

    -- Discovery (lists names that exist; nothing is called)
    { id = "x:globals.search", kind = "custom", area = "Discovery", why = "global functions whose names mention threat, raid targets, roles, nameplates or secrets", test = "/ts probe" },
}
