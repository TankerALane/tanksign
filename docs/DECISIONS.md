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
