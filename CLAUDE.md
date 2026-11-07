# Tanksign: notes for Claude Code sessions

A WoW Forever addon by Decoupled Lane Studio (Austin): it puts the skull raid marker on the
lowest-health mob among those the tank has top threat on. MIT license. Forever only (interface
16001, build 1.60.1.70840); logic files stay client-neutral so retail could be added later.
The structure, tooling and rules copy `D:\Claude Code\fellowship_ledger` (read its CLAUDE.md
when unsure).

## Working rules

1. **Do not guess WoW APIs.** Every API, event or value goes in `Tanksign/Debug/ProbeChecks.lua`
   (one per line). Run `python tools/gen_verify_doc.py` after editing it. Call uncertain APIs
   through `ns.Compat.Call(feature, "Path.To.Api", ...)`.
2. **Secret values.** Forever runs on the modern engine (`issecretvalue` exists, Plater treats
   it as "addon apocalypse" era). Never compare, add, concatenate or print a value from a unit
   API before `ns.Compat.IsSecret` (or `ProbeReport.Classify`) clears it.
3. **Never taint.** No protected calls (TargetUnit, SetBinding in combat, secure attribute
   changes in combat). Only the addon's own frames and events are touched.
4. **Pure modules** (logic, palette, check lists, report formatting) must not touch WoW globals at
   load time. List them in `tests/harness.lua` `PURE_FILES` in TOC order.
5. **Be honest about what is verified.** Unit tests prove logic; the probe and Austin's in-game
   checks prove the client. Report the two separately, with a short in-game checklist.
6. **Globals:** only `TanksignDB`, `SLASH_TANKSIGN1/2`, `SlashCmdList.TANKSIGN`, and (stage 4)
   the binding names and secure button names that key bindings require. A smoke test enforces it.
7. **Look:** Fellowship Ledger's Plain skin only (`UI/Palette.lua`, values copied, a test
   compares them with FL's file).
8. Commit after each stage with clear messages, using the GitHub noreply email. Ask before
   creating or pushing the public GitHub repo, and before anything on CurseForge.

## Commands (PowerShell, repo root)

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1        # unit + smoke tests (LuaJIT)
powershell -ExecutionPolicy Bypass -File tools\sync.ps1 -DryRun     # look first
powershell -ExecutionPolicy Bypass -File tools\sync.ps1             # copy into _forever_\Interface\AddOns
python tools/gen_verify_doc.py                                      # after editing ProbeChecks.lua
python tools/build_release.py --tag v0.1.0                          # release zip
python tools/make_icon.py                                           # redraw icon.tga, skull.tga, PNGs
```

Probe results: after `/reload`, read
`E:\Blizzard\World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\Tanksign.lua`
(`TanksignDB.probe`). Save a copy of the report under `docs/verify-reports/`.

## Status

See `docs/ROADMAP.md` for the stage plan and `docs/DECISIONS.md` for decisions.
