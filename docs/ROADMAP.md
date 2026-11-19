# Roadmap

Each stage ends with a commit, a test run, and an in-game checklist for Austin.

| Stage | Content | State |
|---|---|---|
| 1 | Repo skeleton, TOC, probe, MIT license, README stub, sync script | done; three Forever probe reports read |
| 2 | Mob panel core (D-007): secure rows per enemy nameplate, health bars, click to skull, right-click to target, tank detection and highlight, enable/disable (slash, button, keybind), keybinds for tank's target and mouseover | done: rows and left-click confirmed in game; right-click targeting impossible (D-010) |
| 3 | Row details: elite/rare/boss/caster tags, dim critters/totems/pets, target border | done (tags, target border and toggles confirmed; dimming not yet seen) |
| 4 | (dropped: Forever allows no addon targeting, not even secure clicks on nameplate tokens) | |
| 5 | Options panel and the remaining settings, alerts, profiles; right-click cross and marker icons (0.5.0) | done: confirmed in game |
| 6 | Icon and logo, README with screenshots, CHANGELOG, release packaging | done: v0.9.0 beta released on GitHub and CurseForge (file 9488491) |
| 7 | Beta: markers changed by others (0.9.1, D-014); tidier commands, saved data, profiles, nameplates-off hint, welcome, `/ts disable`/`enable`, centred skull (0.9.2) | 0.9.1 released (CurseForge file 9496090); 0.9.2 checks passed, released |
| 8 | 1.0.0 | released 2026-11-18 (Austin chose to ship before the raid and pet checks; listed as not seen) |

## Before 1.0.0

- [x] Used in a real group, with a tank, in dungeons: "worked great" (Austin, 2026-11-18).
- [x] 0.9.2 in-game checks (short help, nameplates-off hint, new profiles from defaults, centred
      skull, `/ts disable` / `/ts enable`), then release 0.9.2 (all passed, Austin, 2026-11-18).
- [ ] Raid without leader or assistant: "can't mark" in the title and a one-time chat warning
      (not seen in game at 1.0.0; listed in the README and CHANGELOG).
- [ ] A hunter pet or totem nearby: its row is dimmed (not seen in game at 1.0.0).
- [ ] A week or two of beta with no open bug reports: skipped; Austin shipped 1.0.0 the same day
      as 0.9.2 after group use went well.
- [x] Release: version 1.0.0, CHANGELOG, README status line. CurseForge description: Austin.

## Open questions the probe answers

- Are enemy health (`UnitHealth`, `UnitHealthMax`) and threat (`UnitDetailedThreatSituation`) secret
  in combat on Forever? If yes, the core choice cannot be made by an addon and stage 2 changes
  (see DECISIONS D-004).
- Can addon code call `SetRaidTarget` in combat, solo, and as a party member who is not leader?
- Is `TargetUnit` blocked for addons (expected: yes, on every modern client)?
- Do nameplate tokens, `UnitIsUnit` and `UnitGUID` come back readable, so mobs can be told apart?
- How does Forever's role feature show up (`UnitGroupRolesAssigned`, `GetPartyAssignment`)?
