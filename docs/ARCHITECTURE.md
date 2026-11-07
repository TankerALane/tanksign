# Architecture

```
Tanksign/
  Tanksign_Forever.toc   the real TOC (interface 16001)
  Tanksign.toc           fallback: prints "unsupported client" only
  Core/      Namespace (pure), Log, Init (saved variables, slash commands; loaded last)
  Locale/    enUS (pure): every user-facing string
  Compat/    FlavorLogic (pure), Compat (API lookups, secret checks), Unsupported (fallback only)
  UI/        Palette (pure, Plain skin), Widgets
  Debug/     ProbeChecks (pure data), ProbeReport (pure), Probe, CopyWindow
  media/     icon.tga (AddOns list), skull.tga (white skull for the on/off button, tinted in game)
```

## Pure vs WoW-API files

Pure files must not read or write any WoW global when they load. They only define functions and
data on `ns`. `tests/harness.lua` lists them in `PURE_FILES` (in TOC order); the purity test loads
each in an environment that raises on any non-standard global. Stage 2 adds the logic modules
(tank detection, candidate filtering, best-mob choice, switch timers) to this list, each taking
plain tables of facts that a thin WoW-side layer collects.

## Secret values

Unit facts are read through `ns.Compat` and checked with `issecretvalue` before any comparison.
A secret fact is treated as unknown, never as a number.
