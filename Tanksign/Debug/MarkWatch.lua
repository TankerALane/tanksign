-- Debug/MarkWatch.lua
-- /ts probe marks: records, with millisecond timing, what the client tells addons about
-- raid markers on every nameplate while markers change. It answers two questions:
--
--   1. When a marker on a mob is REPLACED by another marker (someone puts an X or a
--      square on your skull), does the mob read as unmarked for a moment ("none") before
--      it reads as marked again, or does it stay "hidden" (marked) the whole time?
--   2. Is the raid icon Blizzard draws on its own nameplate readable by addons?
--
-- Nothing is marked or changed by this recorder. Results go to TanksignDB.probe.markWatch
-- and into the /ts probe report.

local _, ns = ...
local L = ns.L
local Compat = ns.Compat

local MarkWatch = {}
ns.MarkWatch = MarkWatch

local RUN_FOR = 180         -- seconds the recorder stays on
local FAST_FOR = 2.0        -- seconds of every-frame sampling after each marker event
local MAX_LINES = 400

local frame
local running, startedAt, fastUntil = false, 0, 0
local last = {}             -- token -> last status text
local events = 0
local noneBetweenMarked = 0 -- how often a token went hidden -> none -> hidden within FAST_FOR seconds

local function now() return _G.GetTime() end

local function log(text)
    local p = ns.db.probe
    p.markWatch = p.markWatch or {}
    local list = p.markWatch
    list[#list + 1] = string.format("+%.3fs %s", now() - startedAt, text)
    while #list > MAX_LINES do table.remove(list, 1) end
end

-- What GetRaidTargetIndex says: "none" (plain nil), "hidden" (secret) or the number.
local function status(token)
    local ok, v = pcall(_G.GetRaidTargetIndex, token)
    if not ok then return "error" end
    if Compat.IsSecret(v) then return "hidden" end
    if v == nil then return "none" end
    return tostring(v)
end

-- Blizzard's own raid icon on the nameplate: is it shown, and are its texture
-- coordinates readable? (Frame names are looked up, never assumed; missing = "n/a".)
local function blizzardIcon(token)
    local get = Compat.Resolve("C_NamePlate.GetNamePlateForUnit")
    if type(get) ~= "function" then return "n/a" end
    local ok, result = pcall(function()
        local plate = get(token)
        local uf = plate and rawget(plate, "UnitFrame")
        local rtf = uf and rawget(uf, "RaidTargetFrame")
        local icon = rtf and rawget(rtf, "RaidTargetIcon")
        if not icon then return "n/a" end
        local shown = icon:IsShown()
        local l, r, t, b = icon:GetTexCoord()
        local parts = { "shown=" .. ns.ProbeReport.Classify(_G.issecretvalue, shown) }
        parts[#parts + 1] = "coord=" .. ns.ProbeReport.Classify(_G.issecretvalue, l) .. ","
            .. ns.ProbeReport.Classify(_G.issecretvalue, t)
        return table.concat(parts, " ")
    end)
    if not ok then return "error" end
    return result
end

local history = {} -- token -> recent statuses within the fast window, for the none-gap count

local function sample(reason)
    for i = 1, 40 do
        local token = "nameplate" .. i
        local exists = Compat.Plain(_G.UnitExists(token)) == true
        local s = exists and status(token) or "gone"
        if s ~= last[token] then
            if exists or last[token] then
                log(string.format("%s %s -> %s (%s)", token, tostring(last[token] or "new"), s, reason))
            end
            -- A gap counts only when all three states fall inside one FAST_FOR window, so a
            -- marker leaving after one click and coming back after a later click is not a gap.
            local h = history[token] or {}
            h[#h + 1] = { s = s, t = now() }
            local n = #h
            if n >= 3 and h[n].s == "hidden" and h[n - 1].s == "none" and h[n - 2].s == "hidden"
                and h[n].t - h[n - 2].t <= FAST_FOR then
                noneBetweenMarked = noneBetweenMarked + 1
                log(token .. " GAP: marked -> unmarked -> marked (a swap shows a break)")
            end
            history[token] = h
            last[token] = s
        end
    end
end

local function onEvent(_, event, unit)
    if event == "RAID_TARGET_UPDATE" then
        events = events + 1
        log("RAID_TARGET_UPDATE #" .. events)
        sample("event")
        for i = 1, 40 do
            local token = "nameplate" .. i
            if Compat.Plain(_G.UnitExists(token)) == true then
                log("  " .. token .. " blizzard icon: " .. blizzardIcon(token))
            end
        end
        fastUntil = now() + FAST_FOR
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        sample(event == "NAME_PLATE_UNIT_ADDED" and "plate added" or "plate removed")
    end
end

local function onUpdate()
    local t = now()
    if t - startedAt > RUN_FOR then
        MarkWatch.Stop()
        return
    end
    if t < fastUntil then
        sample("frame")
    end
end

-- Tanksign's own clicks go into the timeline too, so the log reads as one story.
function MarkWatch.Note(text)
    if running then log(text) end
end

function MarkWatch.Start()
    frame = frame or CreateFrame("Frame")
    ns.db.probe.markWatch = {}
    last, history, events, noneBetweenMarked = {}, {}, 0, 0
    startedAt, fastUntil = now(), 0
    running = true
    frame:SetScript("OnEvent", onEvent)
    frame:SetScript("OnUpdate", onUpdate)
    frame:RegisterEvent("RAID_TARGET_UPDATE")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    log("recorder started")
    sample("start")
    ns.Log.Info(L.MARKWATCH_ON, RUN_FOR)
end

function MarkWatch.Stop()
    if not running then return end
    running = false
    frame:UnregisterAllEvents()
    frame:SetScript("OnUpdate", nil)
    local summary = string.format("recorder stopped: %d marker events, %d marked->unmarked->marked gaps",
        events, noneBetweenMarked)
    log(summary)
    ns.db.probe.markWatchSummary = summary
    ns.Log.Info(L.MARKWATCH_OFF, events, noneBetweenMarked)
end

function MarkWatch.Toggle()
    if running then MarkWatch.Stop() else MarkWatch.Start() end
end

function MarkWatch.IsRunning()
    return running
end
