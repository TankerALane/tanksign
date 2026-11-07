-- Debug/Probe.lua
-- /ts probe: confirms which APIs this client really has, and which unit values are
-- readable or SECRET in and out of combat, before any marking logic relies on them.
--
-- Safety rules:
--   * Every value goes through ProbeReport.Classify, which asks issecretvalue FIRST,
--     so a secret value is never compared, concatenated or printed.
--   * Nothing here marks or targets on its own. Only /ts probe mark (SetRaidTarget on
--     your target) and /ts probe target (TargetUnit("player"), expected to be blocked)
--     act, and only when you type them.
--   * Results are saved in TanksignDB.probe so they can be read from
--     WTF\Account\<account>\SavedVariables\Tanksign.lua after a /reload.

local _, ns = ...
local L = ns.L
local R = ns.ProbeReport

local Probe = {}
ns.Probe = Probe

local MAX_UNITS = 12
local MAX_GROUP_THREAT = 5
local MAX_COMBAT_SAMPLES = 8
local MAX_TESTS = 10
local MAX_EVENT_SAMPLES = 3
local COMBAT_SAMPLE_DELAYS = { 1.5, 4, 8 }

Probe.events = {}       -- this session: NAME -> { count, samples }
Probe.blocked = { count = 0, last = nil }
local eventFrame
local secureButton
local fightId = 0

local function secretFn()
    local f = _G.issecretvalue
    if type(f) == "function" then return f end
    return nil
end

local function classify(v)
    return R.Classify(secretFn(), v)
end

local function call(path, ...)
    return R.CallClassified(secretFn(), ns.Compat.Resolve(path), ...)
end

local function first(path, ...)
    return call(path, ...)[1]
end

local function now()
    local d = _G.date
    if type(d) == "function" then return d("%Y-%m-%d %H:%M:%S") end
    return "?"
end

local function state()
    local db = ns.db
    db.probe = db.probe or {}
    local p = db.probe
    if p.combatSampling == nil then p.combatSampling = false end
    p.combat = p.combat or {}
    p.marks = p.marks or {}
    p.targets = p.targets or {}
    return p
end

local function push(list, item, max)
    list[#list + 1] = item
    while #list > max do table.remove(list, 1) end
end

local function after(seconds, fn)
    local timer = ns.Compat.Resolve("C_Timer.After")
    if type(timer) == "function" then
        timer(seconds, fn)
    else
        fn()
    end
end

----------------------------------------------------------------------------
-- Unit sampling

-- Group unit tokens (never the player's name; only tokens go in the report).
local function groupUnits()
    local list = {}
    local inRaid = first("IsInRaid") == "true"
    local n = tonumber(first("GetNumGroupMembers")) or 0
    if inRaid then
        for i = 1, math.min(n, 40) do list[#list + 1] = "raid" .. i end
    else
        list[#list + 1] = "player"
        for i = 1, math.min(math.max(n - 1, 0), 4) do list[#list + 1] = "party" .. i end
    end
    return list
end

local function candidateTokens()
    local tokens = { "target", "focus" }
    for i = 1, 5 do tokens[#tokens + 1] = "boss" .. i end
    for i = 1, 40 do tokens[#tokens + 1] = "nameplate" .. i end
    tokens[#tokens + 1] = "mouseover"
    for _, u in ipairs(groupUnits()) do
        if u ~= "player" then tokens[#tokens + 1] = u .. "target" end
    end
    return tokens
end

local function sampleUnit(token, members)
    local u = { token = token, fields = {}, order = {} }
    local function put(field, values)
        u.fields[field] = values
        u.order[#u.order + 1] = field
    end
    put("exists", call("UnitExists", token))
    put("name", call("UnitName", token))
    put("guid", call("UnitGUID", token))
    put("canAttack", call("UnitCanAttack", "player", token))
    put("dead", call("UnitIsDead", token))
    put("combat", call("UnitAffectingCombat", token))
    put("hp", call("UnitHealth", token))
    put("hpMax", call("UnitHealthMax", token))
    put("hpPct", call("UnitHealthPercent", token))
    put("class", call("UnitClassification", token))
    put("ctype", call("UnitCreatureType", token))
    put("pc", call("UnitPlayerControlled", token))
    put("power", call("UnitPowerType", token))
    put("mark", call("GetRaidTargetIndex", token))
    put("canMark", call("CanBeRaidTarget", token))
    put("isTarget", call("UnitIsUnit", token, "target"))
    put("threat", call("UnitThreatSituation", "player", token))
    put("dThreat", call("UnitDetailedThreatSituation", "player", token))
    for i, m in ipairs(members) do
        if i > MAX_GROUP_THREAT then break end
        if m ~= "player" then
            put("dThreat." .. m, call("UnitDetailedThreatSituation", m, token))
            put("threat." .. m, call("UnitThreatSituation", m, token))
            put("tgtOf." .. m, call("UnitIsUnit", m .. "target", token))
        end
    end
    -- Blizzard's own secrecy predicates, asked about this unit.
    put("s.hpMax", call("C_Secrets.ShouldUnitHealthMaxBeSecret", token))
    put("s.thrVal", call("C_Secrets.ShouldUnitThreatValuesBeSecret", token))
    put("s.thrState", call("C_Secrets.ShouldUnitThreatStateBeSecret", token))
    put("s.identity", call("C_Secrets.ShouldUnitIdentityBeSecret", token))
    put("s.compare", call("C_Secrets.CanCompareUnitTokens", token, "target"))
    -- Can a secret health value be handed to a status bar and a font string (display only)?
    put("bar", Probe.DisplayTest(token))
    return u
end

local displayBar, displayText
local function try(fn)
    local ok, err = pcall(fn)
    if ok then return "ok" end
    return "ERROR:" .. ns.Compat.Describe(err)
end

function Probe.DisplayTest(token)
    if not displayBar then
        displayBar = CreateFrame("StatusBar", nil, UIParent)
        displayBar:SetSize(100, 8)
        displayBar:Hide()
        displayText = displayBar:CreateFontString(nil, "OVERLAY")
        displayText:SetFontObject(_G.GameFontHighlightSmall)
    end
    local hp, hpMax = _G.UnitHealth, _G.UnitHealthMax
    return {
        try(function() displayBar:SetMinMaxValues(0, hpMax(token)) end),
        try(function() displayBar:SetValue(hp(token)) end),
        try(function() displayText:SetText(hp(token)) end),
    }
end

-- One snapshot of every hostile-looking unit token that exists right now.
function Probe.SampleUnits()
    local sample = {
        at = now(),
        combat = first("UnitAffectingCombat", "player"),
        lockdown = first("InCombatLockdown"),
        units = {},
    }
    local members = groupUnits()
    for _, token in ipairs(candidateTokens()) do
        if #sample.units >= MAX_UNITS then break end
        local exists = first("UnitExists", token)
        if exists == "true" or exists == "SECRET" then
            local attack = first("UnitCanAttack", "player", token)
            -- Friendly plates are skipped; a SECRET answer is kept, since that is what we want to learn.
            if attack == "true" or attack == "SECRET" or token == "target" then
                sample.units[#sample.units + 1] = sampleUnit(token, members)
            end
        end
    end
    return sample
end

----------------------------------------------------------------------------
-- Custom checks: each returns status, detail

local custom = {}
Probe.custom = custom
local currentMeta

custom["x:build"] = function()
    local ok, version, build, _, interface = pcall(_G.GetBuildInfo)
    if not ok then return "ERROR", "GetBuildInfo failed" end
    local flavor = ns.FlavorLogic.FromInterface(interface)
    local detail = string.format("interface=%s version=%s build=%s flavor=%s project=%s toc=%s",
        tostring(interface), tostring(version), tostring(build), flavor, classify(_G.WOW_PROJECT_ID),
        tostring(ns.Compat.tocFlavor))
    if flavor == ns.FlavorLogic.FOREVER and ns.Compat.tocFlavor == "Forever" then return "PASS", detail end
    return "FAIL", detail
end

custom["x:secrets.context"] = function()
    local parts = { "canaccesssecrets()=" .. first("canaccesssecrets") }
    local cs = _G.C_Secrets
    if type(cs) == "table" then
        local names = {}
        for k, v in pairs(cs) do if type(v) == "function" then names[#names + 1] = tostring(k) end end
        table.sort(names)
        parts[#parts + 1] = "C_Secrets: " .. table.concat(names, ",")
        -- Ask the predicate functions about health and threat if they exist (no arguments needed).
        for _, k in ipairs(names) do
            if k:find("^Should") or k:find("^Is") or k:find("^Get") then
                local ok, v = pcall(cs[k])
                if ok then parts[#parts + 1] = k .. "()=" .. classify(v) end
            end
        end
    else
        parts[#parts + 1] = "C_Secrets: none"
    end
    return "INFO", table.concat(parts, "; ")
end

custom["x:units.sample"] = function()
    local sample = Probe.SampleUnits()
    if currentMeta then currentMeta.unitSample = sample end
    return "INFO", string.format("%d units sampled now (combat=%s); lines follow below", #sample.units, sample.combat)
end

custom["x:nameplates"] = function()
    local parts = {}
    local get = ns.Compat.Resolve("C_NamePlate.GetNamePlates")
    if type(get) == "function" then
        local ok, plates = pcall(get)
        if ok and type(plates) == "table" then
            parts[#parts + 1] = "visible=" .. #plates
            local tokens = {}
            for i, plate in ipairs(plates) do
                if i > 8 then break end
                local token = rawget(plate, "namePlateUnitToken")
                if token == nil and type(rawget(plate, "UnitFrame")) == "table" then token = rawget(plate.UnitFrame, "unit") end
                tokens[#tokens + 1] = classify(token)
            end
            parts[#parts + 1] = "tokens=" .. table.concat(tokens, ",")
        else
            parts[#parts + 1] = "GetNamePlates failed"
        end
    end
    for _, cvar in ipairs({ "nameplateShowEnemies", "nameplateMaxDistance", "nameplateShowAll" }) do
        parts[#parts + 1] = cvar .. "=" .. first("C_CVar.GetCVar", cvar)
    end
    return "INFO", table.concat(parts, " ")
end

custom["x:mark.test"] = function()
    local n = #state().marks
    if n == 0 then return "MANUAL", "not run yet: /ts probe mark" end
    return "INFO", n .. " mark tests saved (see 'mark tests' below)"
end

custom["x:secure.mark"] = function()
    local n = #(state().secureMarks or {})
    if n == 0 then return "MANUAL", "not run yet: /ts probe buttons, then click them with a mob targeted" end
    return "INFO", n .. " secure button clicks saved (see 'secure button marks' below)"
end

custom["x:target.test"] = function()
    local n = #state().targets
    if n == 0 then return "MANUAL", "not run yet: /ts probe target" end
    return "INFO", n .. " target tests saved (see 'target tests' below)"
end

custom["x:group"] = function()
    local parts = {
        "inGroup=" .. first("IsInGroup"), "inRaid=" .. first("IsInRaid"), "members=" .. first("GetNumGroupMembers"),
        "leader=" .. first("UnitIsGroupLeader", "player"), "assist=" .. first("UnitIsGroupAssistant", "player"),
        "everyoneAssist=" .. first("IsEveryoneAssistant"), "instance=" .. table.concat(call("IsInInstance"), ","),
    }
    for _, u in ipairs(groupUnits()) do
        parts[#parts + 1] = string.format("%s role=%s mt=%s", u, first("UnitGroupRolesAssigned", u),
            first("GetPartyAssignment", "MAINTANK", u))
    end
    return "INFO", table.concat(parts, " ")
end

custom["x:secure.button"] = function()
    if first("InCombatLockdown") == "true" then return "INFO", "skipped: in combat (run again out of combat)" end
    local ok, err = pcall(function()
        if not secureButton then
            secureButton = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
            secureButton:Hide()
        end
        secureButton:SetAttribute("type", "target")
        secureButton:SetAttribute("unit", "nameplate1")
    end)
    if not ok then return "FAIL", "could not build: " .. ns.Compat.Describe(err) end
    return "PASS", "type=" .. classify(secureButton:GetAttribute("type")) .. " unit=" .. classify(secureButton:GetAttribute("unit"))
end

custom["x:bindings"] = function()
    local count = tonumber(first("GetNumBindings")) or 0
    local getBinding = _G.GetBinding
    if count == 0 or type(getBinding) ~= "function" then return "INFO", "GetNumBindings/GetBinding unavailable" end
    local found = {}
    for i = 1, count do
        local ok, command = pcall(getBinding, i)
        if ok and type(command) == "string" then
            local up = command:upper()
            if up:find("RAIDTARGET") or up:find("MARK") or up:find("NAMEPLATE") or up:find("FOCUS")
                or up:find("TARGETNEAREST") or up:find("ASSIST") then
                found[#found + 1] = command
            end
        end
    end
    return "INFO", count .. " bindings; matching: " .. table.concat(found, ",")
end

local SEARCH = { "threat", "raidtarget", "rolesassigned", "partyassignment", "secret", "nameplate", "maintank",
    "grouprole", "targetmarker", "worldmarker" }

local function matches(name)
    local lower = name:lower()
    for _, p in ipairs(SEARCH) do if lower:find(p, 1, true) then return true end end
    return false
end

custom["x:globals.search"] = function()
    local found = {}
    for k, v in pairs(_G) do
        if type(k) == "string" then
            local t = type(v)
            if t == "function" and matches(k) then
                found[#found + 1] = k
            elseif t == "table" and k:sub(1, 2) == "C_" then
                local whole = matches(k)
                local ok = pcall(function()
                    for fk, fv in pairs(v) do
                        if type(fk) == "string" and type(fv) == "function" and (whole or matches(fk)) then
                            found[#found + 1] = k .. "." .. fk
                        end
                    end
                end)
                if not ok then found[#found + 1] = k .. ".<unreadable>" end
            end
        end
    end
    table.sort(found)
    return "INFO", #found .. " names: " .. table.concat(found, ", ")
end

----------------------------------------------------------------------------
-- Running the checks

local function eventValid(name)
    local valid = ns.Compat.Resolve("C_EventUtils.IsEventValid")
    if type(valid) == "function" then
        local ok, yes = pcall(valid, name)
        if ok then return yes == true end
    end
    local f = CreateFrame("Frame")
    local ok = pcall(f.RegisterEvent, f, name)
    f:UnregisterAllEvents()
    return ok
end

local function runCheck(check)
    local r = { id = check.id, kind = check.kind, area = check.area }
    if check.kind == "api" then
        local want = check.expect or "function"
        local got = type(ns.Compat.Resolve(check.id))
        r.status = got == want and "PASS" or "FAIL"
        if got ~= want then r.detail = "is " .. got .. ", expected " .. want end
    elseif check.kind == "event" then
        local name = check.id:gsub("^ev:", "")
        r.status = eventValid(name) and "PASS" or "FAIL"
        if r.status == "FAIL" then r.detail = "event unknown to this client" end
    elseif check.kind == "custom" then
        local fn = custom[check.id]
        if not fn then
            r.status, r.detail = "ERROR", "no implementation"
        else
            local ok, status, detail = pcall(fn)
            if ok then
                r.status, r.detail = status, detail
            else
                r.status, r.detail = "ERROR", ns.Compat.Describe(status)
            end
        end
    else
        r.status = "MANUAL"
        r.detail = check.test
    end
    return r
end

function Probe.BuildReport()
    local _, _, _, interface = pcall(_G.GetBuildInfo)
    currentMeta = {
        version = ns.VERSION, interface = ns.Compat.interface or interface, clientVersion = ns.Compat.version,
        build = ns.Compat.build, at = now(), tocFlavor = ns.Compat.tocFlavor, projectId = classify(_G.WOW_PROJECT_ID),
    }
    local results = {}
    for _, check in ipairs(ns.ProbeChecks) do results[#results + 1] = runCheck(check) end
    local p = state()
    local lines = R.Build(currentMeta, results, {
        combat = p.combat, marks = p.marks, targets = p.targets, events = Probe.events, secureMarks = p.secureMarks,
    })
    currentMeta = nil
    return lines
end

function Probe.Run()
    local lines = Probe.BuildReport()
    local p = state()
    p.lastReport = lines
    p.lastRun = now()
    ns.CopyWindow.Show(L.PROBE_TITLE, table.concat(lines, "\n"))
    ns.Log.Info(L.PROBE_SAVED)
end

----------------------------------------------------------------------------
-- Event counting and combat sampling

local function onEvent(_, event, ...)
    local e = Probe.events[event]
    if not e then
        e = { count = 0, samples = {} }
        Probe.events[event] = e
    end
    e.count = e.count + 1
    if #e.samples < MAX_EVENT_SAMPLES then
        local parts = {}
        for i = 1, math.min(select("#", ...), 6) do parts[i] = classify((select(i, ...))) end
        e.samples[#e.samples + 1] = table.concat(parts, ", ")
    end

    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addon, fn = ...
        if not ns.Compat.IsSecret(addon) and addon == ns.ADDON_NAME then
            Probe.blocked.count = Probe.blocked.count + 1
            Probe.blocked.last = event .. ":" .. classify(fn)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        Probe.OnCombatStart()
    end
end

function Probe.OnCombatStart()
    local p = state()
    if not p.combatSampling then return end
    fightId = fightId + 1
    local fight = fightId
    for _, delay in ipairs(COMBAT_SAMPLE_DELAYS) do
        after(delay, function()
            if fight ~= fightId then return end
            if first("UnitAffectingCombat", "player") == "false" then return end
            local sample = Probe.SampleUnits()
            sample.fight = fight
            sample.delay = delay
            push(p.combat, sample, MAX_COMBAT_SAMPLES)
            local tally = R.Tally(sample.units)
            ns.Log.Info(L.PROBE_COMBAT_SAMPLE, #p.combat, #sample.units, R.SecretShare(tally, "hp"),
                R.SecretShare(tally, "dThreat"))
        end)
    end
end

function Probe.Start()
    state()
    eventFrame = eventFrame or CreateFrame("Frame")
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", onEvent)
    for _, check in ipairs(ns.ProbeChecks) do
        if check.kind == "event" and check.probe ~= false then
            pcall(eventFrame.RegisterEvent, eventFrame, (check.id:gsub("^ev:", "")))
        end
    end
end

function Probe.SetCombatSampling(on)
    state().combatSampling = on
    ns.Log.Info(on and L.PROBE_COMBAT_ON or L.PROBE_COMBAT_OFF)
end

function Probe.Clear()
    local p = state()
    p.combat, p.marks, p.targets, p.secureMarks, p.lastReport = {}, {}, {}, {}, nil
    ns.Log.Info(L.PROBE_CLEARED)
end

----------------------------------------------------------------------------
-- Manual action tests

local function groupFacts(rec)
    rec.group = first("IsInGroup")
    rec.leader = first("UnitIsGroupLeader", "player")
    rec.assist = first("UnitIsGroupAssistant", "player")
    rec.combat = first("InCombatLockdown")
end

-- /ts probe mark (index 8) and /ts probe unmark (index 0), on your target.
function Probe.MarkTest(index)
    if first("UnitExists", "target") ~= "true" then
        ns.Log.Warn(L.PROBE_NEED_TARGET)
        return
    end
    local before = first("GetRaidTargetIndex", "target")
    if index == 8 and before == "8" then
        ns.Log.Warn(L.PROBE_ALREADY_SKULL)
        return
    end
    local rec = { at = now(), index = index, before = before }
    groupFacts(rec)
    local blockedBefore = Probe.blocked.count
    local res = call("SetRaidTarget", "target", index)
    rec.call = res[1] and res[1]:sub(1, 6) == "ERROR:" and res[1] or (res[1] == "MISSING" and "MISSING" or "ok")
    after(0.5, function()
        rec.after = first("GetRaidTargetIndex", "target")
        rec.blocked = Probe.blocked.count > blockedBefore and tostring(Probe.blocked.last) or "no"
        if index == 8 then push(state().marks, rec, MAX_TESTS) end
        ns.Log.Info(L.PROBE_MARK_RESULT, rec.call, rec.before, rec.after, rec.combat, rec.blocked)
    end)
end

-- /ts probe target: TargetUnit("player") from addon code. Expected to be blocked.
function Probe.TargetTest()
    ns.Log.Info(L.PROBE_TARGET_WARN)
    local rec = { at = now() }
    groupFacts(rec)
    local blockedBefore = Probe.blocked.count
    local res = call("TargetUnit", "player")
    rec.call = res[1] and res[1]:sub(1, 6) == "ERROR:" and res[1] or (res[1] == "MISSING" and "MISSING" or "returned")
    after(0.3, function()
        rec.blocked = Probe.blocked.count > blockedBefore and tostring(Probe.blocked.last) or "no"
        rec.self = first("UnitIsUnit", "target", "player")
        push(state().targets, rec, MAX_TESTS)
        ns.Log.Info(L.PROBE_TARGET_RESULT, rec.call, rec.blocked, rec.self)
    end)
end

-- /ts probe buttons: a small panel of SECURE buttons you click yourself. A click is a
-- hardware event run by Blizzard's secure code, which is how the built-in "set skull"
-- key binding works. This tests whether that path can place the skull when addon
-- code calling SetRaidTarget cannot. Built and removed only out of combat.
local panel
local W = ns.Widgets

local function tankUnit()
    for _, u in ipairs(groupUnits()) do
        if u ~= "player" and first("UnitGroupRolesAssigned", u) == '"TANK"' then return u end
    end
    return nil
end

local function secureButton(parent, label, attrs, unitForCheck)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetSize(200, 22)
    b:RegisterForClicks("AnyUp", "AnyDown")
    for k, v in pairs(attrs) do b:SetAttribute(k, v) end
    W.Background(b, "buttonBg")
    W.Border(b, "buttonBorder", 1)
    local text = W.Text(b, "small", "buttonText")
    text:SetPoint("CENTER")
    text:SetText(label)
    b:SetScript("PreClick", function(self)
        self.before = first("GetRaidTargetIndex", unitForCheck)
        self.blockedBefore = Probe.blocked.count
    end)
    b:SetScript("PostClick", function(self, button, down)
        local rec = { at = now(), kind = label, unit = unitForCheck, down = tostring(down), before = self.before }
        groupFacts(rec)
        local blockedBefore = self.blockedBefore or Probe.blocked.count
        after(0.4, function()
            rec.after = first("GetRaidTargetIndex", unitForCheck)
            rec.blocked = Probe.blocked.count > blockedBefore and tostring(Probe.blocked.last) or "no"
            local p = state()
            p.secureMarks = p.secureMarks or {}
            push(p.secureMarks, rec, MAX_TESTS * 2)
            ns.Log.Info(L.PROBE_SECURE_RESULT, label, tostring(down), rec.before, rec.after, rec.blocked)
        end)
    end)
    return b
end

function Probe.ToggleButtons()
    if first("InCombatLockdown") == "true" then
        ns.Log.Warn(L.PROBE_BUTTONS_COMBAT)
        return
    end
    if panel then
        panel:Hide()
        panel = nil -- the old buttons stay hidden; a new panel is built next time
        ns.Log.Info(L.PROBE_BUTTONS_OFF)
        return
    end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(224, 132)
    panel:SetPoint("CENTER", 0, -160)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    W.Background(panel, "bg")
    W.Border(panel, "border", 1)
    local title = W.Text(panel, "small", "heading")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetText(L.PROBE_BUTTONS_TITLE)

    local tank = tankUnit()
    local rows = {
        { L.PROBE_BTN_RAIDTARGET, { type = "raidtarget", action = "set", marker = 8, unit = "target" }, "target" },
        { L.PROBE_BTN_MACRO, { type = "macro", macrotext = "/tm 8" }, "target" },
    }
    if tank then
        rows[#rows + 1] = { L.PROBE_BTN_TANK, { type = "raidtarget", action = "set", marker = 8, unit = tank .. "target" },
            tank .. "target" }
    end
    for i, row in ipairs(rows) do
        local b = secureButton(panel, row[1], row[2], row[3])
        b:SetPoint("TOP", 0, -28 - (i - 1) * 30)
    end
    panel:Show()
    ns.Log.Info(L.PROBE_BUTTONS_ON)
end

-- /ts probe <sub>
function Probe.Command(rest)
    local sub, arg = ns.util.splitCommand(rest)
    if sub == "" then
        Probe.Run()
    elseif sub == "mark" then
        Probe.MarkTest(8)
    elseif sub == "unmark" then
        Probe.MarkTest(0)
    elseif sub == "target" then
        Probe.TargetTest()
    elseif sub == "buttons" then
        Probe.ToggleButtons()
    elseif sub == "combat" then
        local a = arg:lower()
        if a == "on" or a == "off" then
            Probe.SetCombatSampling(a == "on")
        else
            Probe.SetCombatSampling(not state().combatSampling)
        end
    elseif sub == "clear" then
        Probe.Clear()
    elseif sub == "help" then
        for _, line in ipairs(L.PROBE_HELP) do ns.Log.Info("  " .. line) end
    else
        ns.Log.Warn(L.PROBE_UNKNOWN)
    end
end
