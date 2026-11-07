-- Locale/enUS.lua
-- PURE: strings only. Every user-facing string lives here so the addon can be
-- translated later. A missing key returns the key itself, so nothing errors.

local _, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L.ADDON_TITLE = "Tanksign"
L.UNSUPPORTED = "This client is not supported (interface %s). Tanksign only runs on WoW Forever; it will stay off."
L.FEATURE_DISABLED = "%s is turned off on this client: %s"
L.LOADED = "v%s loaded. Type /ts for commands."

L.HELP_HEADER = "Tanksign %s commands (/tanksign or /ts):"
L.HELP_LINES = {
    "/ts probe  - check which APIs this client has and show a report to copy",
    "/ts probe mark  - try to put a skull on your target (tests marking rights)",
    "/ts probe unmark  - remove the marker from your target",
    "/ts probe target  - try an addon target change (expect Blizzard's 'blocked' popup)",
    "/ts probe combat on|off  - sample unit values automatically in combat (on by default)",
    "/ts probe clear  - forget saved probe samples",
    "/ts version  - show the version",
}
L.STAGE1_NOTE = "This is the stage 1 probe build: it does not mark anything on its own yet."

L.PROBE_TITLE = "Tanksign probe report (Ctrl+A, Ctrl+C to copy)"
L.PROBE_SAVED = "Probe report saved. It is also in SavedVariables\\Tanksign.lua after /reload."
L.PROBE_COMBAT_ON = "Probe: combat sampling ON. Fight something; a few samples are saved per fight."
L.PROBE_COMBAT_OFF = "Probe: combat sampling OFF."
L.PROBE_COMBAT_SAMPLE = "Probe: combat sample %d saved (%d units seen, health secret on %s, threat secret on %s)."
L.PROBE_CLEARED = "Probe: saved samples cleared."
L.PROBE_NEED_TARGET = "Probe: target a mob first."
L.PROBE_ALREADY_SKULL = "Probe: your target already has the skull. Setting it again would toggle it off; pick another mob or /ts probe unmark first."
L.PROBE_MARK_RESULT = "Probe mark: call %s, marker before=%s after=%s, in combat=%s, blocked=%s."
L.PROBE_TARGET_WARN = "Probe target: trying TargetUnit(\"player\"). If Blizzard shows an 'addon blocked' popup, choose Ignore; that popup is the answer we need."
L.PROBE_TARGET_RESULT = "Probe target: call %s, blocked=%s, your target is now yourself=%s."
L.PROBE_UNKNOWN = "Unknown probe command. Try /ts probe, /ts probe mark, /ts probe target."

L.COPY_HINT = "Ctrl+A then Ctrl+C copies everything. Esc closes."
L.CLOSE = "Close"
