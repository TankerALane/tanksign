-- Core/Log.lua
-- Chat output helpers. Only touches WoW globals when a function is called.

local _, ns = ...

local Log = {}
ns.Log = Log

local function prefix(label)
    return ns.Palette.Wrap("heading", label) .. ": "
end

-- Recent debug lines, kept even when debug printing is off.
Log.recent = {}
local RECENT_MAX = 400

local function out(text)
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame and frame.AddMessage then
        frame:AddMessage(text)
    else
        print(text)
    end
end

local function format(fmt, ...)
    if select("#", ...) > 0 then return fmt:format(...) end
    return fmt
end

function Log.Info(fmt, ...)
    out(prefix("Tanksign") .. format(fmt, ...))
end

function Log.Warn(fmt, ...)
    out(prefix("Tanksign") .. ns.Palette.Wrap("bad", format(fmt, ...)))
end

function Log.IsDebug()
    return ns.db ~= nil and ns.db.settings ~= nil and ns.db.settings.debug == true
end

function Log.Debug(fmt, ...)
    local text = format(fmt, ...)
    local clock = _G.date
    if type(clock) == "function" then text = clock("%H:%M:%S ") .. text end
    local recent = Log.recent
    recent[#recent + 1] = text
    if #recent > RECENT_MAX then table.remove(recent, 1) end
    if Log.IsDebug() then out(prefix("TS debug") .. text) end
end
