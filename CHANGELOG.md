# Changelog

All notable changes to Tanksign. Versions follow semantic versioning; 0.x releases are pre-releases.

## 0.1.0 (unreleased): stage 1, probe build

- Repository skeleton, MIT license, Forever TOC (interface 16001) and a fallback TOC that only prints "unsupported client".
- `/ts probe`: checks every API and event Tanksign plans to use, samples which unit values (health, threat, markers, GUIDs) are readable or secret, in and out of combat, and saves the report in SavedVariables.
- `/ts probe mark`, `/ts probe unmark`, `/ts probe target`: hand-run tests of marking rights and addon targeting.
- Probe round 2: `/ts probe buttons` (secure skull buttons you click), per-member threat, Blizzard's
  `C_Secrets` answers per unit, and whether secret health can be shown in a status bar.
- The build does not mark anything on its own.
