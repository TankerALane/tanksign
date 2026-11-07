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
    "/ts on | off | toggle  - turn Tanksign on or off",
    "/ts status  - state, tanks, marker",
    "/ts show | hide  - show or hide the mob panel",
    "/ts lock | unlock  - stop or allow dragging the panel",
    "/ts tank <Name>  - fixed tank name (/ts tank alone clears it)",
    "/ts source auto|role|maintank|name|threat  - where the tank comes from",
    "/ts marker <1-8 or name>  - marker that a click places (default skull)",
    "/ts rows <1-15>  - most rows shown   /ts scale <0.5-2>",
    "/ts group  - only active in a group or instance (toggle)",
    "/ts reset [position]  - default settings, or only the panel position",
    "/ts debug  - explain each row decision in chat",
    "/ts probe  - API report (see /ts probe help)",
}
L.ON = "ON"
L.OFF = "OFF"
L.NONE = "none"
L.ENABLED = "ENABLED"
L.DISABLED = "DISABLED"
L.STATUS_LINE = "%s (%s). Tanks: %s (source %s). Marker: %s. Tank's-target key marks: %s."
L.PANEL_SHOWN = "Panel shown."
L.PANEL_HIDDEN = "Panel hidden. /ts show brings it back."
L.PANEL_LOCKED = "Panel locked."
L.PANEL_UNLOCKED = "Panel unlocked: drag the title bar to move it."
L.PANEL_EMPTY = "No enemy nameplates"
L.PANEL_AFTER_COMBAT = "The panel will appear when this fight ends (secure frames cannot be built in combat)."
L.DEBUG_ON = "Debug ON: row decisions are explained in chat."
L.DEBUG_OFF = "Debug OFF."
L.TANK_SET = "Fixed tank name: %s."
L.TANK_CLEARED = "Fixed tank name cleared."
L.TANK_SHADOWED = "Note: tank source is auto, and '%s' comes before a fixed name. Use /ts source name to use the name."
L.SOURCE_SET = "Tank source: %s."
L.SOURCE_USAGE = "Usage: /ts source auto|role|maintank|name|threat"
L.MARKER_SET = "Clicks now place: %s."
L.MARKER_USAGE = "Usage: /ts marker <1-8> or a name (skull, cross, square, moon, triangle, diamond, circle, star)"
L.ROWS_SET = "Up to %d rows."
L.ROWS_USAGE = "Usage: /ts rows <1-15>"
L.SCALE_SET = "Panel scale %.2f."
L.SCALE_USAGE = "Usage: /ts scale <0.5-2>"
L.GROUP_ON = "Only active in a group or instance."
L.GROUP_OFF = "Active everywhere, also solo."
L.POSITION_RESET = "Panel position reset."
L.NOT_IN_COMBAT = "Not possible in combat; try again after the fight."
L.RESET_DONE = "Settings reset to defaults."
L.MARKER_NAMES = { [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle", [5] = "Moon", [6] = "Square",
    [7] = "Cross", [8] = "Skull" }
L.ROW_TIP_LEFT = "Left-click: put the marker on this mob"
L.ROW_TIP_RIGHT = "Right-click: target this mob"
L.TOGGLE_TIP_ON = "Tanksign is ON. Click to turn it off."
L.TOGGLE_TIP_OFF = "Tanksign is OFF. Click to turn it on."
L.TOGGLE_TIP_DRAG = "Drag the title bar to move the panel (when unlocked, out of combat)."
L.BIND_TOGGLE = "Toggle Tanksign"
L.BIND_TANK_TARGET = "Skull the tank's target"
L.BIND_MOUSEOVER = "Skull the mob under the mouse"
L.PROBE_HELP = {
    "/ts probe  - check which APIs this client has and show a report to copy",
    "/ts probe mark | unmark  - addon SetRaidTarget test (blocked on Forever)",
    "/ts probe target  - addon target change test (blocked on Forever)",
    "/ts probe buttons  - secure skull buttons you click (out of combat)",
    "/ts probe combat on|off  - sample unit values in combat",
    "/ts probe clear  - forget saved probe samples",
}

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
L.PROBE_SECURE_RESULT = "Probe button [%s] down=%s: marker before=%s after=%s, blocked=%s."
L.PROBE_BUTTONS_ON = "Probe: secure skull buttons shown (drag to move). Target a mob and click each one; also try them in combat. /ts probe buttons again (out of combat) hides them."
L.PROBE_BUTTONS_OFF = "Probe: secure skull buttons hidden."
L.PROBE_BUTTONS_COMBAT = "Probe: secure buttons can only be shown or hidden out of combat."
L.PROBE_BUTTONS_TITLE = "Tanksign probe: click to mark"
L.PROBE_BTN_RAIDTARGET = "Skull target (secure)"
L.PROBE_BTN_MACRO = "Skull target (/tm 8 macro)"
L.PROBE_BTN_TANK = "Skull tank's target (secure)"
L.PROBE_UNKNOWN = "Unknown probe command. /ts probe help lists them."

L.COPY_HINT = "Ctrl+A then Ctrl+C copies everything. Esc closes."
L.CLOSE = "Close"
