-- tests/wowmock.lua
-- A small fake WoW API: enough to load the whole addon in TOC order, fire events,
-- run timers and slash commands. It proves code paths run and never touch secret
-- values; it does NOT prove the real client behaves like this.

local M = {}

-- A stand-in for a secret value: comparing, concatenating, indexing or printing
-- it raises, as it does for addon code on the real client.
function M.makeSecret()
    local p = newproxy(true)
    local mt = getmetatable(p)
    local function boom() error("touched a secret value", 2) end
    mt.__index, mt.__newindex, mt.__concat, mt.__tostring = boom, boom, boom, boom
    mt.__eq, mt.__lt, mt.__le, mt.__add, mt.__sub, mt.__mul, mt.__div = boom, boom, boom, boom, boom, boom, boom
    mt.__unm, mt.__len, mt.__call = boom, boom, boom
    return p
end

local STD = { "assert", "error", "ipairs", "next", "pairs", "pcall", "select", "tonumber", "tostring", "type",
    "unpack", "rawget", "rawset", "rawequal", "setmetatable", "getmetatable", "string", "table", "math", "print" }

local function noop() end

function M.new(opts)
    opts = opts or {}
    local ctl = {
        chat = {}, timers = {}, frames = {}, blockedCalls = {}, drivers = {}, watches = {}, time = 100, combat = false, units = {}, leader = false,
        assist = false, group = false, groupSize = 0, markBlocked = false,
        interface = opts.interface or 16001, toc = opts.toc or "Tanksign/Tanksign_Forever.toc",
        secret = M.makeSecret(),
    }
    local env = {}
    for _, k in ipairs(STD) do env[k] = _G[k] end
    env._G = env
    env.date = os.date

    -- Frames -----------------------------------------------------------------
    local Frame = {}
    -- Unknown methods are no-ops; unknown private fields ("_x") and lowercase fields are nil.
    local FrameMT = { __index = function(_, k)
        if Frame[k] then return Frame[k] end
        if type(k) == "string" and k:find("^%u") then return noop end
        return nil
    end }

    local function newFrame(kind)
        local f = setmetatable({ _kind = kind, _scripts = {}, _events = {}, _attrs = {}, _shown = true }, FrameMT)
        ctl.frames[#ctl.frames + 1] = f
        return f
    end
    function Frame:RegisterEvent(e)
        if ctl.validEvents and not ctl.validEvents[e] then error("unknown event " .. e) end
        self._events[e] = true
    end
    function Frame:UnregisterEvent(e) self._events[e] = nil end
    function Frame:UnregisterAllEvents() self._events = {} end
    function Frame:IsEventRegistered(e) return self._events[e] == true end
    function Frame:SetScript(name, fn) self._scripts[name] = fn end
    function Frame:GetScript(name) return self._scripts[name] end
    function Frame:CreateTexture() return newFrame("Texture") end
    function Frame:CreateFontString() return newFrame("FontString") end
    function Frame:SetText(t) self._text = t end
    function Frame:GetText() return self._text end
    -- Protected frames (secure templates and their parents) refuse changes in combat,
    -- like ADDON_ACTION_BLOCKED on the real client.
    local function guard(self, what)
        if ctl.combat and self._protected then
            ctl.blockedCalls[#ctl.blockedCalls + 1] = what
            error("blocked in combat: " .. what, 3)
        end
    end
    function Frame:SetAttribute(k, v) guard(self, "SetAttribute") self._attrs[k] = v end
    function Frame:SetPoint(...) guard(self, "SetPoint") self._point = { ... } end
    function Frame:ClearAllPoints() guard(self, "ClearAllPoints") end
    function Frame:SetScale(v) guard(self, "SetScale") self._scale = v end
    function Frame:SetShown(v) guard(self, "SetShown") self._shown = v and true or false end
    function Frame:EnableMouse(v) guard(self, "EnableMouse") self._mouse = v end
    function Frame:SetAlpha(v) self._alpha = v end
    function Frame:GetPoint() local p = self._point or {} return p[1], p[2], p[3], p[4], p[5] end
    function Frame:SetFrameRef(k, f) self._refs = self._refs or {} self._refs[k] = f end
    function Frame:Execute(body) self._executed = (self._executed or 0) + 1 end
    function Frame:SetStatusBarColor(r, g, b) self._barColor = { r, g, b } end
    function Frame:SetValue(v) self._value = v end
    function Frame:GetAttribute(k) return self._attrs[k] end
    function Frame:Show() guard(self, "Show") self._shown = true end
    function Frame:Hide() guard(self, "Hide") self._shown = false end
    function Frame:IsShown() return self._shown end
    -- A hand click on a secure button: runs the raidtarget action like Blizzard's secure code.
    function Frame:Click(button, down)
        if self._scripts.PreClick then self._scripts.PreClick(self, button or "LeftButton", down) end
        local a = self._attrs
        if self._template == "SecureActionButtonTemplate" and a.type == "raidtarget" then
            local x = ctl.units[a.unit]
            if x then x.mark = a.marker end
        end
        if self._scripts.PostClick then self._scripts.PostClick(self, button or "LeftButton", down) end
    end
    function Frame:GetVerticalScroll() return 0 end
    function Frame:GetVerticalScrollRange() return 0 end

    env.CreateFrame = function(kind, name, parent, template)
        local secure = type(template) == "string" and template:find("Secure") ~= nil
        if secure and ctl.combat then error("protected in combat") end
        local f = newFrame(kind)
        f._template = template
        f._parent = parent
        if secure then
            local x = f
            while x and x ~= env.UIParent do x._protected = true; x = x._parent end
        end
        ctl.lastFrame = f
        if name then env[name] = f end
        return f
    end
    env.UIParent = newFrame("Frame")
    env.GameTooltip = newFrame("GameTooltip")
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) ctl.chat[#ctl.chat + 1] = text end }
    for _, font in ipairs({ "GameFontHighlightSmall", "GameFontHighlight", "GameFontHighlightLarge",
        "GameFontNormalLarge", "GameFontNormal", "ChatFontNormal" }) do
        env[font] = {}
    end
    env.SlashCmdList = {}

    -- Build, metadata, events ---------------------------------------------------
    env.GetBuildInfo = function() return "1.60.1", "70840", "Nov 1 2026", ctl.interface end
    env.WOW_PROJECT_ID = 18
    local tocFields = {}
    env.C_AddOns = { GetAddOnMetadata = function(_, field) return tocFields[field] end }
    env.C_EventUtils = { IsEventValid = function(name) return not ctl.validEvents or ctl.validEvents[name] == true end }
    env.C_Timer = { After = function(s, fn) ctl.timers[#ctl.timers + 1] = { at = ctl.time + s, fn = fn } end }
    env.GetTime = function() return ctl.time end
    env.C_CVar = { GetCVar = function() return "1" end }
    env.issecretvalue = function(v) return rawequal(v, ctl.secret) end
    env.canaccesssecrets = function() return false end
    env.canaccessvalue = function(v) return not rawequal(v, ctl.secret) end

    -- Units ----------------------------------------------------------------------
    local function unit(u) return ctl.units[u] end
    env.UnitExists = function(u) return u == "player" or unit(u) ~= nil or (ctl.names and ctl.names[u] ~= nil) end
    env.UnitName = function(u)
        if ctl.names and ctl.names[u] then return ctl.names[u] end
        local x = unit(u)
        return x and x.name
    end
    env.UnitGUID = function(u) local x = unit(u) return x and x.guid end
    env.UnitCanAttack = function(_, u) local x = unit(u) return x ~= nil and x.hostile == true end
    env.UnitIsDead = function(u) local x = unit(u) return x ~= nil and (x.hp == 0) end
    env.UnitIsDeadOrGhost = env.UnitIsDead
    env.UnitAffectingCombat = function(u)
        if u == "player" then return ctl.combat end
        local x = unit(u)
        return x ~= nil and x.combat == true
    end
    env.UnitHealth = function(u) local x = unit(u) return x and x.hp or 0 end
    env.UnitHealthMax = function(u) local x = unit(u) return x and x.hpMax or 0 end
    env.UnitClassification = function(u) local x = unit(u) return x and x.class or "normal" end
    env.UnitCreatureType = function(u) local x = unit(u) if x then return x.ctype, x.ctypeId end end
    env.UnitPlayerControlled = function(u) local x = unit(u) return x ~= nil and x.pc == true end
    env.UnitIsPlayer = function(u) return u == "player" end
    env.UnitPowerType = function(u) local x = unit(u) return x and x.powerType or 1, "RAGE" end
    env.UnitIsUnit = function(a, b)
        if a == b then return true end
        local x, y = unit(a), unit(b)
        return x ~= nil and x == y
    end
    env.UnitThreatSituation = function(who, u)
        local x = unit(u)
        if not x then return nil end
        if x.threatBy then return x.threatBy[who] end
        return x.threatStatus
    end
    env.UnitDetailedThreatSituation = function(_, u)
        local x = unit(u)
        if not x then return nil end
        return x.isTanking, x.threatStatus, x.threatPct, x.threatPct, x.threatValue
    end
    env.GetRaidTargetIndex = function(u) local x = unit(u) return x and x.mark end
    env.SetRaidTarget = function(u, i)
        if ctl.markBlocked then
            ctl.fire("ADDON_ACTION_BLOCKED", "Tanksign", "SetRaidTarget()")
            return
        end
        local x = unit(u)
        if not x then return end
        if i == 0 or x.mark == i then x.mark = nil else x.mark = i end
    end
    env.CanBeRaidTarget = function(u) return unit(u) ~= nil end
    env.TargetUnit = function() ctl.fire("ADDON_ACTION_FORBIDDEN", "Tanksign", "TargetUnit()") end

    -- Group ------------------------------------------------------------------------
    env.IsInGroup = function() return ctl.group end
    env.IsInRaid = function() return false end
    env.IsInInstance = function() return false, "none" end
    env.GetNumGroupMembers = function() return ctl.groupSize end
    env.UnitIsGroupLeader = function() return ctl.leader end
    env.UnitIsGroupAssistant = function() return ctl.assist end
    env.IsEveryoneAssistant = function() return false end
    env.UnitGroupRolesAssigned = function(u) return (ctl.roles and ctl.roles[u]) or "NONE" end
    env.GetPartyAssignment = function() return false end
    env.InCombatLockdown = function() return ctl.combat end

    -- Nameplates and bindings ------------------------------------------------------
    env.C_NamePlate = {
        GetNamePlates = function()
            local list = {}
            for token in pairs(ctl.units) do
                if token:find("^nameplate") then list[#list + 1] = { namePlateUnitToken = token } end
            end
            return list
        end,
    }
    env.RegisterStateDriver = function(frame, state, conditions)
        if ctl.combat then error("RegisterStateDriver in combat") end
        ctl.drivers[#ctl.drivers + 1] = { frame = frame, state = state, conditions = conditions }
    end
    env.UnregisterStateDriver = function() end
    env.RegisterUnitWatch = function(frame, asState)
        if ctl.combat then error("RegisterUnitWatch in combat") end
        ctl.watches[#ctl.watches + 1] = { frame = frame, asState = asState }
    end
    env.GetBindingKey = function(command) return ctl.bindings and ctl.bindings[command] end
    env.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
    env.PlaySound = function(id) ctl.sounds = (ctl.sounds or 0) + 1 end
    env.Settings = {
        RegisterCanvasLayoutCategory = function(frame, name)
            ctl.optionsFrame = frame
            return { GetID = function() return 42 end, name = name }
        end,
        RegisterAddOnCategory = function() end,
        OpenToCategory = function(id) ctl.openedOptions = id end,
    }
    env.GetNumBindings = function() return 2 end
    env.GetBinding = function(i) return i == 1 and "RAIDTARGET8" or "TARGETNEARESTENEMY" end

    -- Control helpers --------------------------------------------------------------
    function ctl.fire(event, ...)
        for _, f in ipairs(ctl.frames) do
            if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
        end
    end

    function ctl.advance(seconds)
        ctl.time = ctl.time + (seconds or 0)
        local guard = 0
        repeat
            local ran = false
            for i, t in ipairs(ctl.timers) do
                if t.at <= ctl.time then
                    table.remove(ctl.timers, i)
                    t.fn()
                    ran = true
                    break
                end
            end
            guard = guard + 1
        until not ran or guard > 1000
    end

    function ctl.slash(msg)
        return env.SlashCmdList.TANKSIGN(msg)
    end

    function ctl.chatText()
        return table.concat(ctl.chat, "\n")
    end

    -- Load the addon -----------------------------------------------------------------
    function ctl.load(root)
        local ns = {}
        local path = root .. "/" .. ctl.toc
        local f = assert(io.open(path, "rb"))
        local files = {}
        for line in f:read("*a"):gmatch("[^\r\n]+") do
            local k, v = line:match("^## ([%w%-_]+):%s*(.-)%s*$")
            if k then
                tocFields[k] = v
            elseif not line:find("^#") then
                files[#files + 1] = line:gsub("\\", "/")
            end
        end
        f:close()
        ctl.globalsBefore = {}
        for k in pairs(env) do ctl.globalsBefore[k] = true end
        for _, rel in ipairs(files) do
            local chunk = assert(loadfile(root .. "/Tanksign/" .. rel))
            setfenv(chunk, env)
            chunk("Tanksign", ns)
        end
        ctl.ns = ns
        return ns
    end

    function ctl.newGlobals()
        local list = {}
        for k in pairs(env) do
            if not ctl.globalsBefore[k] then list[#list + 1] = k end
        end
        table.sort(list)
        return list
    end

    return env, ctl
end

return M
