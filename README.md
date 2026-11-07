# Tanksign

**Tanksign puts the skull on the mob your tank should finish first.** It finds the lowest-health
mob among those the tank is holding (top threat) and marks it with the skull, then moves the skull
as the fight changes. It is an addon for World of Warcraft, built for **WoW Forever**.

> **Status: stage 1 of 6, the probe build.** This version marks nothing on its own. It checks
> which game functions and values this client gives to addons, so that the real feature is built
> only on what works. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Install

Download the zip from the GitHub releases page (CurseForge will follow) and extract it into
`World of Warcraft\_forever_\Interface\AddOns\`, so the result is `...\AddOns\Tanksign\`.

## Commands (probe build)

| Command | What it does |
|---|---|
| `/ts` or `/tanksign` | list commands |
| `/ts probe` | check the APIs and show a report you can copy |
| `/ts probe mark` / `unmark` | try to put the skull on your target, or remove it |
| `/ts probe target` | try an addon target change (Blizzard's "blocked" popup is expected) |
| `/ts probe combat on` / `off` | sample unit values automatically in combat |
| `/ts version` | version and support contact |

## Known limits

To be written once the probe has run on Forever: combat lockdown, mobs without a unit token,
marking permissions, and any values the client keeps secret from addons.

## Credits and support

Made by **Decoupled Lane Studio**. Support: support@decoupledlane.com.

Released under the [MIT License](LICENSE). World of Warcraft is a trademark of Blizzard
Entertainment; this project is not affiliated with Blizzard.
