# Changelog

All notable changes to Tanksign. Versions follow semantic versioning; 0.x releases are pre-releases.

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
