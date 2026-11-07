# Roadmap

Each stage ends with a commit, a test run, and an in-game checklist for Austin.

| Stage | Content | State |
|---|---|---|
| 1 | Repo skeleton, TOC, probe, MIT license, README stub, sync script | done; probe 1 read; probe round 2 waiting |
| 2 | Core: tank detection, candidate mobs, lowest-health choice, skull marking, enable/disable | on hold: health is secret and SetRaidTarget is forbidden (D-006) |
| 3 | Switch delay, cooldown, hysteresis, manual-mark protection | |
| 4 | Targeting: auto where allowed, keybind and secure buttons otherwise | |
| 5 | Options panel, remaining settings, best-mob frame, alerts, profiles | |
| 6 | Icon and logo, README with screenshots, CHANGELOG, release packaging | |

## Open questions the probe answers

- Are enemy health (`UnitHealth`, `UnitHealthMax`) and threat (`UnitDetailedThreatSituation`) secret
  in combat on Forever? If yes, the core choice cannot be made by an addon and stage 2 changes
  (see DECISIONS D-004).
- Can addon code call `SetRaidTarget` in combat, solo, and as a party member who is not leader?
- Is `TargetUnit` blocked for addons (expected: yes, on every modern client)?
- Do nameplate tokens, `UnitIsUnit` and `UnitGUID` come back readable, so mobs can be told apart?
- How does Forever's role feature show up (`UnitGroupRolesAssigned`, `GetPartyAssignment`)?
