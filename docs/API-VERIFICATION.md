# API verification (WoW Forever)

Tanksign does not guess WoW APIs. Every API, event and value it relies on is listed in
`Tanksign/Debug/ProbeChecks.lua`, and `/ts probe` checks them in the game. The table below is
generated from that file by `python tools/gen_verify_doc.py`. The Forever column holds the result
of the latest probe report saved under `docs/verify-reports/`.

## How to run the probe

1. Sync the addon (`tools\sync.ps1 -Target Forever`), log in, type `/ts probe`. A report window
   opens; the same report is saved in `TanksignDB.probe.lastReport`.
2. Combat sampling is on by default in the probe build. Fight a few mobs (a pack of two or more is
   best); three samples are saved per fight.
3. `/ts probe mark` on a hostile target: solo, in a party as leader, in a party not as leader,
   and once in combat.
4. `/ts probe target` once (expect Blizzard's "addon blocked" popup; choose Ignore).
5. `/ts probe` again, then `/reload` (this writes SavedVariables to disk) and tell Claude. Claude
   reads `WTF\Account\<account>\SavedVariables\Tanksign.lua` directly; pasting the report works too.

## What matters most

The modern engine Forever runs on can return **secret values** to addons. A secret value can be
passed on to Blizzard widgets but cannot be compared, added or printed by addon code. If enemy
health or threat is secret in combat, the "lowest health among tanked mobs" choice cannot be made
by an addon at all. The `x:units.sample` lines and the combat samples answer this.

## Findings

From `docs/verify-reports/forever-2026-11-06-probe1.txt` (Durotar, 5-person party, Austin as
healer, then party leader; mobs fought solo-style with the tank elsewhere):

- **Enemy health is secret in combat.** `UnitHealth`, `UnitHealthMax` and `UnitHealthPercent`
  were SECRET on every hostile unit in every combat sample (6 samples, 2 fights), including a
  nearby mob that was not itself in combat. Out-of-combat health is not yet known (no mob was
  visible during the out-of-combat probe).
- **`SetRaidTarget` is forbidden to addon code**, in and out of combat and as party leader:
  `ADDON_ACTION_FORBIDDEN` ("UNKNOWN()"), marker unchanged. Automatic marking is impossible.
- **`TargetUnit` is forbidden**, as expected.
- **Threat is partly readable.** `UnitThreatSituation("player", mob)` was a plain number (3) on
  both the target and nameplate tokens. `UnitDetailedThreatSituation("player", mob)` was plain on
  the `target` token (`true,3,100,255,75`) but SECRET on the `nameplate1` token for the same mob.
  Party members returned nothing (they were not on those mobs' threat lists).
- **Identity is readable:** names, GUIDs, `UnitIsUnit`, `UnitCanAttack`, classification, creature
  type, power type, `GetRaidTargetIndex` and `CanBeRaidTarget` were plain.
- **Roles are readable:** `UnitGroupRolesAssigned` gives TANK/HEALER/DAMAGER per member;
  `GetPartyAssignment("MAINTANK")` exists (false for everyone in a party).
- Events fire as expected: `NAME_PLATE_UNIT_ADDED/REMOVED`, `UNIT_THREAT_LIST_UPDATE`,
  `UNIT_HEALTH`, `RAID_TARGET_UPDATE`, `PLAYER_REGEN_*`. All 66 probed APIs exist.
- `C_Secrets` exists with per-unit predicates (`ShouldUnitHealthMaxBeSecret`,
  `ShouldUnitThreatValuesBeSecret`, ...) and Blizzard ships a built-in `RAIDTARGET8` key binding.

From `docs/verify-reports/forever-2026-11-06-probe2.txt` (round 2, out of combat only):

- **Health is secret out of combat too** (mob not in combat, player not in combat), and
  `C_Secrets.ShouldUnitHealthMaxBeSecret(unit)` answers true. Health is never readable.
- **Secret health can be displayed:** `StatusBar:SetMinMaxValues`, `StatusBar:SetValue` and
  `FontString:SetText` all accepted secret health without error.
- **Secure buttons clicked by hand are not blocked:** the `type=raidtarget` button and the
  `/tm 8` macro button on `target` raised no blocked event, and `RAID_TARGET_UPDATE` fired.
- **The marker index becomes secret once a marker is set:** `GetRaidTargetIndex` was plain `nil`
  before the click and SECRET after. An addon cannot read which mob carries the skull.
- The tank's-target button did nothing because the tank had no target (`party3target` empty).
- `C_Secrets.ShouldUnitThreatValuesBeSecret` takes `(unit, mobUnit)`;
  `C_Secrets.CanCompareUnitTokens(unit, "target")` answered true; identity is not secret.
From `docs/verify-reports/forever-2026-11-06-probe3-dungeon.txt` (5-person dungeon, Austin healing,
a TANK-role tank in party1, 8 units per sample):

- **Inside an instance, identity is secret too:** mob names, GUIDs and creature types were SECRET
  (`C_Secrets.ShouldUnitIdentityBeSecret` true). Classification ("elite"), combat flag, dead,
  `UnitCanAttack` and `GetRaidTargetIndex` (before marking) stayed readable.
- **The tank's threat is readable on nameplate and target tokens:** `UnitThreatSituation(party1,
  nameplate3)` = 3, and the other members 0. Detailed threat is readable on `target` only. On
  `mouseover` and `partyNtarget` tokens everything threat-related was SECRET.
- `UnitIsUnit(nameplateN, "target")` readable; `UnitIsUnit(partyN.."target", x)` mostly SECRET.
- Health secret everywhere, as before; the status bar and font string accept it.
- Earlier note, now answered: the tank's threat on mobs in combat (no fight with the tank in this round), and
  secure clicks in combat (expected to work: secure buttons are built for combat).

<!-- GENERATED:BEGIN (tools/gen_verify_doc.py) -->


### Build

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `x:build` | custom | interface number, client version, project id, which TOC loaded | `/dump GetBuildInfo()` | ? |
| `GetBuildInfo` | api | read client version and interface number | `/dump type(GetBuildInfo)` -> "function" | ? |
| `C_AddOns.GetAddOnMetadata` | api | read our TOC fields (version, flavor) | `/dump type(C_AddOns.GetAddOnMetadata)` -> "function" | ? |
| `C_EventUtils.IsEventValid` | api | how the probe checks events | `/dump type(C_EventUtils.IsEventValid)` -> "function" | ? |
| `m:toc.icon` | manual | IconTexture shows in the AddOns list | Esc > AddOns: the skull icon shows next to Tanksign | ? |
| `m:slash` | manual | /ts and /tanksign are not taken by another addon | type /ts: the Tanksign command list appears | ? |

### Secrets

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `issecretvalue` | api | test a value before reading it | `/dump type(issecretvalue)` -> "function" | ? |
| `canaccesssecrets` | api | whether addon code may read secrets right now | `/dump type(canaccesssecrets)` -> "function" | ? |
| `canaccessvalue` | api | alternative per-value secret check | `/dump type(canaccessvalue)` -> "function" | ? |
| `x:secrets.context` | custom | canaccesssecrets() result and any C_Secrets functions | `/dump canaccesssecrets()` | ? |

### Threat

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `UnitDetailedThreatSituation` | api | isTanking, status, percent and raw threat of a group member on a mob | `/dump type(UnitDetailedThreatSituation)` -> "function" | ? |
| `UnitThreatSituation` | api | coarse threat status (0-3) of a group member on a mob | `/dump type(UnitThreatSituation)` -> "function" | ? |
| `UnitThreatPercentageOfLead` | api | optional: threat relative to the leader | `/dump type(UnitThreatPercentageOfLead)` -> "function" | ? |
| `ev:UNIT_THREAT_LIST_UPDATE` | event | a mob's threat list changed: re-evaluate | `/dump C_EventUtils.IsEventValid("UNIT_THREAT_LIST_UPDATE")` -> true | ? |
| `ev:UNIT_THREAT_SITUATION_UPDATE` | event | a unit's threat status changed | `/dump C_EventUtils.IsEventValid("UNIT_THREAT_SITUATION_UPDATE")` -> true | ? |

### Units

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `UnitHealth` | api | current health of a mob | `/dump type(UnitHealth)` -> "function" | ? |
| `UnitHealthMax` | api | maximum health, for percent mode | `/dump type(UnitHealthMax)` -> "function" | ? |
| `UnitHealthPercent` | api | optional: percent health without dividing | `/dump type(UnitHealthPercent)` -> "function" | ? |
| `UnitExists` | api | is a unit token filled | `/dump type(UnitExists)` -> "function" | ? |
| `UnitIsUnit` | api | are two tokens the same mob (dedupe nameplates, target, focus) | `/dump type(UnitIsUnit)` -> "function" | ? |
| `UnitGUID` | api | stable identity of a mob across tokens | `/dump type(UnitGUID)` -> "function" | ? |
| `UnitCanAttack` | api | hostile and attackable | `/dump type(UnitCanAttack)` -> "function" | ? |
| `UnitIsDead` | api | skip dead mobs | `/dump type(UnitIsDead)` -> "function" | ? |
| `UnitIsDeadOrGhost` | api | skip dead mobs (alternative) | `/dump type(UnitIsDeadOrGhost)` -> "function" | ? |
| `UnitAffectingCombat` | api | mob and player in combat | `/dump type(UnitAffectingCombat)` -> "function" | ? |
| `UnitClassification` | api | elite / rare / boss / trivial / minus | `/dump type(UnitClassification)` -> "function" | ? |
| `UnitCreatureType` | api | critters and totems | `/dump type(UnitCreatureType)` -> "function" | ? |
| `UnitPlayerControlled` | api | skip player pets and guardians | `/dump type(UnitPlayerControlled)` -> "function" | ? |
| `UnitIsPlayer` | api | skip enemy players | `/dump type(UnitIsPlayer)` -> "function" | ? |
| `UnitPowerType` | api | mana users count as casters | `/dump type(UnitPowerType)` -> "function" | ? |
| `UnitName` | api | mob name for debug lines | `/dump type(UnitName)` -> "function" | ? |
| `ev:UNIT_HEALTH` | event | a unit's health changed: re-evaluate | `/dump C_EventUtils.IsEventValid("UNIT_HEALTH")` -> true | ? |
| `ev:UNIT_FLAGS` | event | combat flags changed (existence only, not counted by the probe) | `/dump C_EventUtils.IsEventValid("UNIT_FLAGS")` -> true | ? |
| `x:units.sample` | custom | for every visible mob token: which values are readable and which are secret | `/ts probe (out of combat), then fight with combat sampling on` | ? |

### Nameplates

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `C_NamePlate.GetNamePlates` | api | list visible nameplates | `/dump type(C_NamePlate.GetNamePlates)` -> "function" | ? |
| `C_NamePlate.GetNamePlateForUnit` | api | find the plate frame of a unit (for the glow) | `/dump type(C_NamePlate.GetNamePlateForUnit)` -> "function" | ? |
| `ev:NAME_PLATE_UNIT_ADDED` | event | a nameplate token appeared | `/dump C_EventUtils.IsEventValid("NAME_PLATE_UNIT_ADDED")` -> true | ? |
| `ev:NAME_PLATE_UNIT_REMOVED` | event | a nameplate token went away | `/dump C_EventUtils.IsEventValid("NAME_PLATE_UNIT_REMOVED")` -> true | ? |
| `x:nameplates` | custom | visible plates, their unit tokens, nameplate CVars | `/dump #C_NamePlate.GetNamePlates()` | ? |

### Marking

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `SetRaidTarget` | api | put the skull (8) on a unit | `/dump type(SetRaidTarget)` -> "function" | ? |
| `GetRaidTargetIndex` | api | read the marker on a unit | `/dump type(GetRaidTargetIndex)` -> "function" | ? |
| `CanBeRaidTarget` | api | optional: can this unit carry a marker | `/dump type(CanBeRaidTarget)` -> "function" | ? |
| `ev:RAID_TARGET_UPDATE` | event | a marker moved (detect manual marks) | `/dump C_EventUtils.IsEventValid("RAID_TARGET_UPDATE")` -> true | ? |
| `x:secure.mark` | custom | results of /ts probe buttons: can a secure button you click place the skull | `/ts probe buttons` | ? |

### Secrets

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `C_Secrets.ShouldUnitHealthMaxBeSecret` | api | Blizzard's own answer: is this unit's health secret | `/dump type(C_Secrets.ShouldUnitHealthMaxBeSecret)` -> "function" | ? |
| `C_Secrets.ShouldUnitThreatValuesBeSecret` | api | Blizzard's own answer: are threat values on this unit secret | `/dump type(C_Secrets.ShouldUnitThreatValuesBeSecret)` -> "function" | ? |
| `C_Secrets.ShouldUnitThreatStateBeSecret` | api | Blizzard's own answer: is threat status on this unit secret | `/dump type(C_Secrets.ShouldUnitThreatStateBeSecret)` -> "function" | ? |

### Targeting

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `RegisterStateDriver` | api | secure [@nameplateN,harm,nodead] visibility for panel rows, also in combat | `/dump type(RegisterStateDriver)` -> "function" | ? |
| `UnregisterStateDriver` | api | remove a state driver | `/dump type(UnregisterStateDriver)` -> "function" | ? |
| `m:panel` | manual | panel rows appear for hostile plates, left-click marks, right-click targets, in combat too | fight a pack with the panel shown | ? |
| `RegisterUnitWatch` | api | secure frames that show and hide with a unit, even in combat | `/dump type(RegisterUnitWatch)` -> "function" | ? |

### Marking

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `x:mark.test` | custom | results of /ts probe mark (solo, party leader, party member, in combat) | `/ts probe mark` | ? |

### Group

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `UnitGroupRolesAssigned` | api | TANK / HEALER / DAMAGER role of a member | `/dump type(UnitGroupRolesAssigned)` -> "function" | ? |
| `UnitGroupRolesAssignedEnum` | api | optional: role as an enum | `/dump type(UnitGroupRolesAssignedEnum)` -> "function" | ? |
| `GetPartyAssignment` | api | Main Tank assignment ("MAINTANK") | `/dump type(GetPartyAssignment)` -> "function" | ? |
| `GetRaidRosterInfo` | api | raid role column (MAINTANK) | `/dump type(GetRaidRosterInfo)` -> "function" | ? |
| `IsInGroup` | api | party or raid | `/dump type(IsInGroup)` -> "function" | ? |
| `IsInRaid` | api | raid unit tokens | `/dump type(IsInRaid)` -> "function" | ? |
| `IsInInstance` | api | only active in group or instance | `/dump type(IsInInstance)` -> "function" | ? |
| `GetNumGroupMembers` | api | roster size | `/dump type(GetNumGroupMembers)` -> "function" | ? |
| `UnitIsGroupLeader` | api | marking permission | `/dump type(UnitIsGroupLeader)` -> "function" | ? |
| `UnitIsGroupAssistant` | api | marking permission | `/dump type(UnitIsGroupAssistant)` -> "function" | ? |
| `IsEveryoneAssistant` | api | marking permission when everyone is assistant | `/dump type(IsEveryoneAssistant)` -> "function" | ? |
| `ev:GROUP_ROSTER_UPDATE` | event | roster or roles changed | `/dump C_EventUtils.IsEventValid("GROUP_ROSTER_UPDATE")` -> true | ? |
| `ev:PLAYER_ROLES_ASSIGNED` | event | roles changed | `/dump C_EventUtils.IsEventValid("PLAYER_ROLES_ASSIGNED")` -> true | ? |
| `ev:PARTY_LEADER_CHANGED` | event | marking permission changed | `/dump C_EventUtils.IsEventValid("PARTY_LEADER_CHANGED")` -> true | ? |
| `x:group` | custom | each member's role, Main Tank flag, and the player's leader/assistant state | `/dump UnitGroupRolesAssigned("player")` | ? |

### Combat

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `InCombatLockdown` | api | secure frames are locked | `/dump type(InCombatLockdown)` -> "function" | ? |
| `GetTime` | api | switch delay and cooldown timers | `/dump type(GetTime)` -> "function" | ? |
| `C_Timer.After` | api | short one-off timers | `/dump type(C_Timer.After)` -> "function" | ? |
| `ev:PLAYER_REGEN_DISABLED` | event | combat started | `/dump C_EventUtils.IsEventValid("PLAYER_REGEN_DISABLED")` -> true | ? |
| `ev:PLAYER_REGEN_ENABLED` | event | combat ended | `/dump C_EventUtils.IsEventValid("PLAYER_REGEN_ENABLED")` -> true | ? |
| `ev:ADDON_ACTION_BLOCKED` | event | we hit a protected action in combat | `/dump C_EventUtils.IsEventValid("ADDON_ACTION_BLOCKED")` -> true | ? |
| `ev:ADDON_ACTION_FORBIDDEN` | event | we hit a protected action at any time | `/dump C_EventUtils.IsEventValid("ADDON_ACTION_FORBIDDEN")` -> true | ? |

### Targeting

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `TargetUnit` | api | exists, but protected on modern clients (tested by /ts probe target) | `/dump type(TargetUnit)` -> "function" | ? |
| `x:target.test` | custom | results of /ts probe target (is addon targeting blocked) | `/ts probe target` | ? |
| `x:secure.button` | custom | a SecureActionButtonTemplate button can be made and given a unit | `/ts probe (out of combat)` | ? |
| `SetOverrideBindingClick` | api | bind a key to our secure button | `/dump type(SetOverrideBindingClick)` -> "function" | ? |
| `GetBindingKey` | api | show which key is bound | `/dump type(GetBindingKey)` -> "function" | ? |
| `x:bindings` | custom | built-in key bindings about raid markers or nameplates | `/ts probe` | ? |

### Options

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `Settings.RegisterCanvasLayoutCategory` | api | options page in Interface Options | `/dump type(Settings.RegisterCanvasLayoutCategory)` -> "function" | ? |
| `Settings.RegisterAddOnCategory` | api | options page in Interface Options | `/dump type(Settings.RegisterAddOnCategory)` -> "function" | ? |
| `Settings.OpenToCategory` | api | /ts options opens our page | `/dump type(Settings.OpenToCategory)` -> "function" | ? |
| `PlaySound` | api | alert sound when the skull moves | `/dump type(PlaySound)` -> "function" | ? |
| `SOUNDKIT` | api | sound ids | `/dump type(SOUNDKIT)` -> "table" | ? |

### Discovery

| ID | Kind | What it is for | In-game test | Forever |
|---|---|---|---|---|
| `x:globals.search` | custom | global functions whose names mention threat, raid targets, roles, nameplates or secrets | `/ts probe` | ? |

<!-- GENERATED:END -->
