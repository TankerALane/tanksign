# Changelog

All notable changes to Tanksign. Versions follow semantic versioning; 0.x releases are pre-releases.

## 0.5.0 (unreleased): right-click cross and marker icons

- Right-click a row puts the cross (red X) on that mob; left-click still puts the skull. Both
  markers are settings (`/ts marker`, `/ts rightmarker`, options page).
- Marker icons on the row and above the nameplate of mobs you marked with Tanksign. Forever hides
  a marked unit's marker from addons, so Tanksign remembers its own clicks and clears an icon when
  the client shows the mob as unmarked or its nameplate goes away. Markers placed by others are not
  shown. `/ts icons` toggles the icons.
- Fix (found in game): an icon vanished right after the click, because the server applies the
  marker a moment later and the unit still read as unmarked. A fresh mark now has a 3-second grace
  time, and Tanksign re-checks on RAID_TARGET_UPDATE.

## 0.4.0 (unreleased): stage 5, options and profiles

- Options page (Esc > Options > AddOns > Tanksign, or `/ts options`) in the Plain palette, with the
  sections Core, Choosing the mob, Marking, Panel, Alerts, Key bindings, Profiles and Other. It
  redraws when a setting changes anywhere (slash command, ON/OFF button, key binding).
- Profiles: create (as a copy), switch, delete, reset; `/ts profile <name>`; optional automatic
  switch to "Dungeon" and "Raid" profiles. Saved settings move into profiles (schema 3).
- Optional sound and chat line when you place a marker with a row or a key.
- Marking rights: in a raid without leader or assistant, the panel title says "can't mark" and a
  one-time message explains.
- Not possible on Forever and explained on the options page: clearing the skull, a "skull moved"
  alert, and a glow on the marked nameplate (addons cannot see or remove markers).

## 0.3.0 (unreleased): stage 3, row details

- Row tags: E elite, R rare, B boss, C caster (uses mana). `/ts tags` toggles them.
- Critters, totems and pets are dimmed (`/ts dim`). Uses creature type ids, so it works on any
  client language; inside instances the creature type is secret, so only pets are dimmed there.
- Not possible on Forever and left out: ignoring mobs below a health threshold (health is secret)
  and counting mobs within 90% of top threat (threat values are secret on nameplates).

## 0.2.0 (unreleased): stage 2, the mob panel

Forever does not let addons read enemy health or place markers, so Tanksign is now a click-to-mark
panel (docs/DECISIONS.md D-006 to D-008).

- Mob panel: one row per hostile, living enemy nameplate with its name and a live health bar. Green
  bar: a tank holds it. Red: in combat and no tank holds it. Grey: not pulled yet, or unknown.
- Left-click a row puts the skull (or the chosen marker) on that mob. It is a secure click and works
  in combat (confirmed in a Forever dungeon). Right-click targeting was tried and removed: Forever
  ignores secure targeting through nameplate tokens.
- Rows follow Blizzard's unit watch (Forever answers 0 to `[@nameplateN,harm]` conditions).
- Session log saved on /reload or logout, and `/ts diag`, for bug reports.
- Tank detection: role, then Main Tank, then a fixed name (`/ts tank <Name>`), then top threat.
- One enabled flag for `/ts on|off|toggle`, the skull button on the panel and the "Toggle Tanksign"
  key binding. Off means no events and no updates; in combat the panel fades and hides after the fight.
- Key bindings: Toggle Tanksign, Skull the tank's target, Skull the mob under the mouse (both marking
  keys confirmed in game).
- Commands: status, show, hide, lock, unlock, tank, source, marker, rows, scale, group, reset, debug.

## 0.1.0 (unreleased): stage 1, probe build

- Repository skeleton, MIT license, Forever TOC (interface 16001) and a fallback TOC that only prints "unsupported client".
- `/ts probe`: checks every API and event Tanksign plans to use, samples which unit values (health, threat, markers, GUIDs) are readable or secret, in and out of combat, and saves the report in SavedVariables.
- `/ts probe mark`, `/ts probe unmark`, `/ts probe target`: hand-run tests of marking rights and addon targeting.
- Probe round 2: `/ts probe buttons` (secure skull buttons you click), per-member threat, Blizzard's
  `C_Secrets` answers per unit, and whether secret health can be shown in a status bar.
- The build does not mark anything on its own.
