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

## D-006 The brief's core feature is impossible on Forever (probe 1, 2026-11-06)

The first Forever probe showed (a) enemy health is secret to addon code in combat, so no addon can
find the lowest-health mob, and (b) `SetRaidTarget` raises `ADDON_ACTION_FORBIDDEN` for addon code
at any time, so no addon can place a marker by itself. Both are Blizzard restrictions; working
around them (for example reading back a status bar fed a secret value) would be exactly the kind of
unsafe workaround the brief rules out, and would likely break with any client patch.

Stages 2 to 6 are on hold until Austin picks a replacement design. Probe round 2 tests the
closest safe options: secure buttons the player clicks (a hardware event that runs Blizzard's
secure marking code, like the built-in "set skull" key binding), health bars that display secret
values without the addon reading them, and readable threat for the tank.

Round 2 (same day): health is secret even out of combat; secret health can be shown in a status
bar; hand-clicked secure buttons mark without being blocked; the marker index is secret once set,
so the addon cannot see where the skull is (manual-mark protection and "skull already on the best
mob" cannot be detected). Austin chooses the replacement design next.
