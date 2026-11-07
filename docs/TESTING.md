# Testing

| Kind | Proves | Who runs it |
|---|---|---|
| Unit and smoke tests (`tests/`) | the logic of pure modules, and that the addon's code paths run against a fake API without touching secret values | anyone, outside the game (CI too) |
| In-game probe and checklists | the real Forever client behaves as assumed | Austin |

A feature counts as done only when both agree.

## Unit tests

They need Lua 5.1 semantics (WoW runs Lua 5.1): LuaJIT or Lua 5.1. Installed: LuaJIT 2.1
(`winget install --id DEVCOM.LuaJIT`).

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
```

Covered in stage 1:

- **Purity**: every file in `PURE_FILES` loads with standard Lua only.
- **Namespace, flavor, palette**: the palette equals Fellowship Ledger's Plain skin value for value
  (and is compared with FL's file when it sits next to this repo).
- **TOCs**: fields, every listed file exists, the icon exists, versions agree, the fallback TOC
  never loads the addon, the license is MIT.
- **Probe checks**: unique and well formed, the brief's APIs are all present, the combat log and
  chat are never probed, every check is in `docs/API-VERIFICATION.md`.
- **Probe report**: secret values are classified without being touched (a stand-in that raises on
  any comparison, concatenation or print), tallies, report layout.
- **Smoke** (`test_smoke.lua` + `wowmock.lua`): the whole addon loads in TOC order, creates only
  the allowed globals, runs every probe command with secret health and threat, combat sampling,
  mark tests (including the toggle guard and a blocked call), the target test, an unsupported
  client and the fallback TOC.

The mock proves code paths run. It does **not** prove the real client behaves like the mock.

## Syncing to the game

```powershell
powershell -ExecutionPolicy Bypass -File tools\sync.ps1 -DryRun     # always look first
powershell -ExecutionPolicy Bypass -File tools\sync.ps1
```

The script mirrors only `Tanksign\` into `<AddOns>\Tanksign` and refuses any destination that does
not end in `\Interface\AddOns` or does not exist.
