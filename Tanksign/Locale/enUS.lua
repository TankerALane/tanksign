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
    "/ts tags  - E elite, R rare, B boss, C caster tags on rows (toggle)",
    "/ts dim  - dim critters, totems and pets (toggle)",
    "/ts reset [position]  - default settings, or only the panel position",
    "/ts options  - open the options page",
    "/ts profile [name | list]  - switch to (or create) a profile",
    "/ts debug  - explain each row decision in chat",
    "/ts diag  - show what the client did with the panel rows (for bug reports)",
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
L.PANEL_STEP_FAILED = "Panel setup step '%s' failed: %s (please report; /ts diag shows details)"
L.DIAG_SAVED = "Diagnosis saved; it is in SavedVariables\\Tanksign.lua after /reload."
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
L.TAGS_ON = "Row tags on: E elite, R rare, B boss, C caster."
L.TAGS_OFF = "Row tags off."
L.DIM_ON = "Critters, totems and pets are dimmed (where the client lets Tanksign tell)."
L.DIM_OFF = "No dimming."
L.NO_MARK_RIGHTS = "You cannot place markers here: in a raid only the leader and assistants can. (Shown once.)"
L.NO_RIGHTS_SHORT = "can't mark"
L.MARK_PLACED = "%s on %s."
L.A_MOB = "a mob (name hidden by the client)"
L.OPTIONS_UNAVAILABLE = "The options page is not available on this client; use /ts commands."
L.PROFILE_ACTIVE_NOW = "Profile: %s."
L.PROFILE_LIST = "Profile %s. All profiles: %s."
L.PROFILE_BAD_NAME = "A profile name needs 1 to 24 characters."
L.PROFILE_EXISTS = "That profile already exists."
L.PROFILE_UNKNOWN = "No such profile."
L.PROFILE_ACTIVE = "The active profile cannot be deleted."
L.PROFILE_LAST = "The last profile cannot be deleted."
L.PROFILE_DELETED = "Profile %s deleted."
L.AUTO_PROFILE_ON = "Profiles switch automatically: 'Dungeon' in dungeons, 'Raid' in raids (when they exist)."
L.AUTO_PROFILE_OFF = "Profiles no longer switch automatically."
L.SOURCE_NAMES = { auto = "Auto (role, Main Tank, name, threat)", role = "Role", maintank = "Main Tank",
    name = "Fixed name", threat = "Auto from threat", none = "none found" }
L.OPT_INTRO = "Click a row in the Tanksign panel to put the marker on that mob. Forever hides enemy health and markers from addons, so you pick the mob; Tanksign shows the bars and places the marker."
L.OPT_STATUS = "Now: %s (%s). Tanks: %s (%s). Profile: %s."
L.OPT_CORE = "Core"
L.OPT_ENABLED = "Enable Tanksign"
L.OPT_ONLY_GROUP = "Only active in a group or instance"
L.OPT_TANK_SOURCE = "Tank source"
L.OPT_TANK_NAME = "Fixed tank name (Enter)"
L.OPT_ROWS = "Choosing the mob"
L.OPT_TAGS = "Show tags: E elite, R rare, B boss, C caster"
L.OPT_DIM = "Dim critters, totems and pets"
L.OPT_MAX_ROWS = "Most rows shown"
L.OPT_ROWS_NOTE = "Not possible on Forever: sorting by health, ignoring mobs below a health threshold, and the 'within 90% of top threat' option (health and exact threat are secret to addons)."
L.OPT_MARKING = "Marking"
L.OPT_MARKER = "Marker a click places"
L.OPT_MARKING_NOTE = "In a raid only the leader and assistants can mark; the panel title says so. Not possible on Forever: clearing the skull on disable or at combat end (addons cannot remove markers)."
L.OPT_PANEL = "Panel"
L.OPT_SHOW_PANEL = "Show the panel"
L.OPT_SHOW_TOGGLE = "Show the ON/OFF skull button"
L.OPT_LOCK = "Lock the panel position"
L.OPT_SCALE = "Scale"
L.OPT_ALPHA = "Opacity"
L.OPT_RESET_POSITION = "Reset panel position"
L.OPT_ALERTS = "Alerts"
L.OPT_SOUND = "Sound when you place a marker"
L.OPT_CHAT = "Chat line when you place a marker"
L.OPT_ALERTS_NOTE = "Markers placed by others cannot be seen by addons on Forever, so there is no 'skull moved' alert and no glow on the marked nameplate."
L.OPT_KEYS = "Key bindings"
L.OPT_KEYS_LIST = "Toggle Tanksign: %s    Skull the tank's target: %s    Skull the mob under the mouse: %s"
L.OPT_KEYS_NOTE = "Set them in Esc > Options > Keybindings > AddOns > Tanksign. Targeting keys are not possible on Forever."
L.OPT_NOT_BOUND = "not bound"
L.OPT_PROFILES = "Profiles"
L.OPT_PROFILE = "Active profile (click to switch)"
L.OPT_NEW_PROFILE = "New profile, copy of this one (Enter)"
L.OPT_DELETE_PROFILE = "Delete this profile"
L.OPT_AUTO_PROFILE = "Switch to 'Dungeon' / 'Raid' profiles automatically"
L.OPT_OTHER = "Other"
L.OPT_DEBUG = "Debug: explain each row decision in chat"
L.OPT_RESET = "Reset this profile"
L.OPT_CREDIT = "Tanksign by Decoupled Lane Studio. MIT License. Support: support@decoupledlane.com"
L.GROUP_ON = "Only active in a group or instance."
L.GROUP_OFF = "Active everywhere, also solo."
L.POSITION_RESET = "Panel position reset."
L.NOT_IN_COMBAT = "Not possible in combat; try again after the fight."
L.RESET_DONE = "Settings reset to defaults."
L.MARKER_NAMES = { [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle", [5] = "Moon", [6] = "Square",
    [7] = "Cross", [8] = "Skull" }
L.ROW_TIP_LEFT = "Left-click: put the marker on this mob"
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
L.PROBE_BTN_T_TYPE = "Target nameplate1 (type=target)"
L.PROBE_BTN_T_SLASH = "Target nameplate1 (/target nameplate1)"
L.PROBE_BTN_T_COND = "Target nameplate1 (/target [@nameplate1])"
L.PROBE_BTN_T_ASSIST = "Target the tank's target (/assist party1)"
L.PROBE_UNKNOWN = "Unknown probe command. /ts probe help lists them."

L.COPY_HINT = "Ctrl+A then Ctrl+C copies everything. Esc closes."
L.CLOSE = "Close"
