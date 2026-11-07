# Decisions

## D-001 Forever only, client-neutral logic (stage 1)

Tanksign ships one flavor TOC, `Tanksign_Forever.toc` (interface 16001), plus a fallback
`Tanksign.toc` (interface 00000) that only prints "unsupported client". This is the Fellowship
Ledger pattern; FL's verify report showed Forever loads the `_Forever` TOC. The interface number was
confirmed from the client: build 1.60.1.70840, `.flavor.info` = `wowf`, and 28 installed Forever
addons declare `## Interface: 16001` (no Blizzard_* TOCs are on disk; they live in the CASC archive).

## D-002 Saved-variables report instead of copy-paste

The probe saves its report and samples in `TanksignDB.probe`. After `/reload`, Claude reads
`WTF\Account\<account>\SavedVariables\Tanksign.lua` directly. The copy window remains for pasting.

## D-003 Release tooling as in Fellowship Ledger

The addon lives in `Tanksign/`, so the BigWigs packager (which expects a TOC at the repo root) is
not used. `tools/build_release.py` builds the zip and uploads to CurseForge from the tag workflow,
as in FL (its D-052).

## D-004 Secret values decide the design (pending the probe)

Forever runs on the modern engine: `issecretvalue` and `canaccesssecrets` exist, and Plater's
framework treats Forever as "addon apocalypse" era. If `UnitHealth` or `UnitDetailedThreatSituation`
return secret values in combat, addon code cannot compare them, so it cannot pick "the lowest
health mob the tank holds". Stage 2 will be designed from the probe's combat samples:

- readable in combat: build the brief as written.
- health secret, threat readable: the closest safe option is to be decided with Austin
  (for example skull the tanked mob that has the lowest health among those whose health can be
  read, or skull by a readable proxy). No unsafe workaround.
- threat secret: tank detection from threat is impossible; only role, Main Tank and fixed-name
  tank sources could remain, and "the tank holds it" could only be approximated (for example the
  tank's own target). To be decided with Austin.

## D-005 No globals except the required ones

Only `TanksignDB` and the slash command globals in stage 1. The report window is unnamed, so it
does not join `UISpecialFrames`; Esc closes it while its text box has focus. A smoke test lists
every global the addon creates.

## D-006 The brief's core feature is impossible on Forever (probe 1, 2026-11-06)

The first Forever probe showed (a) enemy health is secret to addon code in combat, so no addon can
find the lowest-health mob, and (b) `SetRaidTarget` raises `ADDON_ACTION_FORBIDDEN` for addon code
at any time, so no addon can place a marker by itself. Both are Blizzard restrictions; working
around them (for example reading back a status bar fed a secret value) would be exactly the kind of
unsafe workaround the brief rules out, and would likely break with any client patch.

Stages 2 to 6 are on hold until Austin picks a replacement design. Probe round 2 tests the
closest safe options: secure buttons the player clicks (a hardware event that runs Blizzard's
secure marking code, like the built-in "set skull" key binding), health bars that display secret
values without the addon reading them, and readable threat for the tank.

Round 2 (same day): health is secret even out of combat; secret health can be shown in a status
bar; hand-clicked secure buttons mark without being blocked; the marker index is secret once set,
so the addon cannot see where the skull is (manual-mark protection and "skull already on the best
mob" cannot be detected). Austin chooses the replacement design next.

## D-007 New design: the mob panel (Austin's choice, 2026-11-06)

Tanksign becomes a click-to-mark panel. One row per hostile, living enemy nameplate, each with
the mob's name and a live health bar (the bar is fed the secret health value; the addon never
reads it). Rows the tank holds are highlighted when the tank's threat status is readable.
Left-click a row places the skull (or the chosen marker); right-click targets the mob. Both are
secure clicks run by Blizzard's code, so they work in combat.

How it stays legal: every row is a `SecureActionButtonTemplate` button fixed to one token
(`nameplate1` to `nameplate40`, `type=raidtarget`, `action=set`). A secure state driver per token
(`[@nameplateN,harm,nodead]`) tells a `SecureHandlerStateTemplate` header which rows to show, and a
restricted snippet stacks the visible rows, so showing, hiding and re-ordering work in combat
without addon code touching protected frames. Rows cannot be sorted by health (secret).

From the brief, kept: enable/disable everywhere, only in group or instance, tank source (Role >
Main Tank > fixed name > auto from threat), marker choice, panel settings, keybinds (toggle, skull
the tank's target, skull mouseover), debug, profiles, Plain palette. Dropped as impossible:
automatic choice and marking, switch delay, cooldown, hysteresis, manual-mark protection (marker
positions are secret), auto-target, "target skull mob" (no macro conditional targets by marker).

Limits that remain: in combat the panel cannot be hidden or moved (protected), so turning
Tanksign off in combat fades it and stops its updates, and hides it when combat ends. The
tank's-target key is pointed at the tank out of combat; a roster change in combat applies after it.
Global names added for key bindings: `TanksignSkullTankTarget`, `TanksignSkullMouseover` and the
`BINDING_*` strings.

## D-008 Dungeon probe adjustments (2026-11-06)

In instances mob names are secret, so rows hand `UnitName` to the font string unread instead of
showing "?". The held highlight uses `UnitThreatSituation(tank, nameplateN)`, readable in the
dungeon probe. A mob that is not in combat is shown neutral (grey), not "loose" (red): red means
in combat and no tank holds it.

## D-009 Rows follow Blizzard's unit watch, not a macro condition (2026-11-06)

`/ts diag` in a dungeon: seven living, attackable enemy nameplates, and
`SecureCmdOptionParse("[@nameplateN,harm,nodead] 1; 0")` answered 0 for every one, both from
addon code and in the secure state drivers. Every other secure piece worked (restricted Execute,
GetFrameRef, tostring, the layout snippet). So rows now use `RegisterUnitWatch(row, true)`: the
row (also a `SecureHandlerStateTemplate`) receives `state-unitexists` while its nameplate token
exists and passes it to the header, whose layout snippet stacks the rows. Cost: a row also shows
for a friendly nameplate if friendly nameplates are turned on. `/ts diag` now tests condition
variants to learn which part Forever rejects.

Confirmed the same day: with unit watch the rows appear, stack and follow nameplates in combat, and
left-clicks run in combat. `/ts diag` on a living enemy plate: `[@nameplate1]`=1,
`[@nameplate1,nodead]`=1, but `[@nameplate1,exists]`=0 and `[@nameplate1,harm]`=0. Forever
seems to refuse unit-identity conditions on nameplate tokens. Right-click (`type2=target`,
unit `nameplateN`) reached the row ~20 times, nothing was blocked, and the target did not change.
`/ts probe buttons` now tries `/target nameplate1`, `/target [@nameplate1]` and `/assist party1`.

## D-010 No targeting from the panel (2026-11-06)

`/ts probe buttons`, out of combat, nameplate1 visible: `type=target unit=nameplate1`,
`/target nameplate1` and `/target [@nameplate1]` all left nameplate1 untargeted, with nothing
blocked; the panel's right-click (`type2=target`) did the same in ~20 clicks in and out of combat.
Right-click targeting is removed. `/assist party1` was inconclusive (the check only looked at
nameplate1); a "target the tank's target" key is added only if Austin sees it work.
Left-click marking is confirmed by eye in a dungeon, in combat.
Key bindings "Skull the tank's target" and "Skull the mob under the mouse" confirmed working in
game by Austin (2026-11-06).

## D-011 Stage 3 row details (2026-11-06)

Tags come from `UnitClassification` and `UnitPowerType` (both readable in the dungeon probe).
Dimming uses the creature type id (second return of `UnitCreatureType`: 8 critter, 11 totem,
12 and 14 pets), which is locale-independent but secret inside instances, plus
`UnitPlayerControlled` (readable). Dimming changes only the alpha of the row's bar (not a
protected frame), so it works in combat. Left out as impossible: health-threshold filtering and
the "within 90% of top threat" option (detailed threat is secret on nameplate tokens).

## D-012 Stage 5: options, profiles, alerts (2026-11-06)

Settings live in `TanksignDB.profiles[name]`, the active name in `TanksignDB.profile` (schema 3).
At runtime `ns.db` is a proxy over `TanksignDB` whose `settings` field is the active profile, so the
profile is never stored twice in the saved variables. Automatic switching picks "Dungeon" in party
instances and "Raid" in raids when those profiles exist, else the profile last picked by hand.
Alerts fire only for markers YOU place (row PostClick, key PostClick); markers placed by others are
invisible to addons. Marking rights follow Blizzard's rule (party: anyone; raid: leader, assistants).
From the brief, impossible and explained on the options page: clear skull on disable or combat end,
"skull moved" alerts, the glow on the marked nameplate.
