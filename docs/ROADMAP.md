# Roadmap

Each stage ends with a commit, a test run, and an in-game checklist for Austin.

| Stage | Content | State |
|---|---|---|
| 1 | Repo skeleton, TOC, probe, MIT license, README stub, sync script | done; three Forever probe reports read |
| 2 | Mob panel core (D-007): secure rows per enemy nameplate, health bars, click to skull, right-click to target, tank detection and highlight, enable/disable (slash, button, keybind), keybinds for tank's target and mouseover | built, waiting for in-game test |
| 3 | Row details: elite and caster tags, dim critters/pets/totems, threat-percent option, target and marker indicators where readable | |
| 4 | (folded into 2: secure targeting by right-click; no auto-target on Forever) | |
| 5 | Options panel and the remaining settings, alerts, profiles | |
| 6 | Icon and logo, README with screenshots, CHANGELOG, release packaging | |

## Open questions the probe answers

- Are enemy health (`UnitHealth`, `UnitHealthMax`) and threat (`UnitDetailedThreatSituation`) secret
  in combat on Forever? If yes, the core choice cannot be made by an addon and stage 2 changes
  (see DECISIONS D-004).
- Can addon code call `SetRaidTarget` in combat, solo, and as a party member who is not leader?
- Is `TargetUnit` blocked for addons (expected: yes, on every modern client)?
- Do nameplate tokens, `UnitIsUnit` and `UnitGUID` come back readable, so mobs can be told apart?
- How does Forever's role feature show up (`UnitGroupRolesAssigned`, `GetPartyAssignment`)?
