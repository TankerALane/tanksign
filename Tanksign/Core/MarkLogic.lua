-- Core/MarkLogic.lua
-- PURE: must not touch WoW globals at load time.
-- Remembers which nameplate token got which marker from Tanksign's own clicks, because
-- on Forever an addon cannot read a marked unit's marker (GetRaidTargetIndex comes back
-- secret once a marker is set; an unmarked unit still reads as plain nil).
--
-- state = { byToken = { [token] = marker }, byMarker = { [marker] = token },
--           pending = { [token] = time placed } }
-- A marker is on at most one unit (Blizzard moves it), so placing it again moves it here.
-- A click reaches the server a moment later, so right after a click the unit still reads
-- as unmarked: a "none" answer is ignored for GRACE seconds after the click. Only time ends
-- the grace: a "marked" answer right after the click may still be the unit's OLD marker
-- (cross replaced by skull), and the swap can read as unmarked for a moment.

local _, ns = ...

local MarkLogic = {}
ns.MarkLogic = MarkLogic

MarkLogic.GRACE = 3

function MarkLogic.New()
    return { byToken = {}, byMarker = {}, pending = {} }
end

local function clearToken(state, token)
    local old = state.byToken[token]
    state.pending[token] = nil
    if old then
        state.byToken[token] = nil
        if state.byMarker[old] == token then state.byMarker[old] = nil end
    end
end

-- You placed `marker` on `token` (a nameplate token) at time `now` (GetTime()).
function MarkLogic.Place(state, marker, token, now)
    if type(marker) ~= "number" or type(token) ~= "string" then return end
    local previous = state.byMarker[marker]
    if previous then clearToken(state, previous) end
    clearToken(state, token) -- a unit carries one marker; the new one replaces the old
    state.byToken[token] = marker
    state.byMarker[marker] = token
    if now then state.pending[token] = now end
end

-- The nameplate token went away (the mob left view or died); its unit is gone from that token.
function MarkLogic.Removed(state, token)
    clearToken(state, token)
end

-- What the client says about `token` at time `now`: "none" (plain nil: no marker),
-- "hidden" (secret: some marker), or a plain number (the marker itself).
function MarkLogic.Observe(state, token, seen, now)
    local placedAt = state.pending[token]
    if placedAt and now and now - placedAt >= MarkLogic.GRACE then
        state.pending[token] = nil
        placedAt = nil
    end
    if seen == "none" then
        if placedAt then return end -- the click has not arrived yet
        clearToken(state, token)
        return
    end
    if type(seen) == "number" and seen >= 1 and seen <= 8 then
        if state.byToken[token] ~= seen then MarkLogic.Place(state, seen, token) end
    end
    -- "hidden": keep what we remember
end

function MarkLogic.Get(state, token)
    return state.byToken[token]
end

function MarkLogic.HasAny(state)
    return next(state.byToken) ~= nil
end

function MarkLogic.Forget(state)
    state.byToken, state.byMarker, state.pending = {}, {}, {}
end

----------------------------------------------------------------------------
-- Changes made by someone else (D-014). The recorder (/ts probe marks, 2026-11-07) showed
-- that a mob whose marker is REPLACED reads "marked" the whole time, with no break. What
-- an addon does get: a RAID_TARGET_UPDATE event, and which nameplates went from unmarked
-- to marked (a gain) or marked to unmarked (a loss). A marker is on one unit at a time,
-- so when no Tanksign click explains the event:
--   * nothing visible changed: a marker changed on a mob that already had one (or on a
--     mob without a nameplate). It may be your skull or X mob; we cannot tell which.
--   * more losses than gains: a marker left a mob and went nowhere visible: it was
--     removed, or moved onto a marked mob (your X onto your skull mob). Cannot tell.
-- In both cases Tanksign forgets its skull and X rather than show a wrong icon.

MarkLogic.CLICK_WINDOW = 1.0 -- an event this close to a Tanksign click is that click
MarkLogic.SETTLE = 0.5       -- wait this long after the last event before judging

-- before/after: token -> "none" | "marked". Only tokens in both count.
function MarkLogic.Diff(before, after)
    local gains, losses = 0, 0
    for token, now in pairs(after) do
        local was = before[token]
        if was == "none" and now == "marked" then gains = gains + 1 end
        if was == "marked" and now == "none" then losses = losses + 1 end
    end
    return gains, losses
end

function MarkLogic.Unexplained(gains, losses)
    return losses > gains or (gains == 0 and losses == 0)
end

-- check = { firstAt, lastAt, gains, losses } gathered over a burst of events.
-- Returns true when the burst should make Tanksign forget its markers.
function MarkLogic.ShouldForget(check, lastClickAt)
    if lastClickAt and lastClickAt >= check.firstAt - MarkLogic.CLICK_WINDOW
        and lastClickAt <= check.lastAt + MarkLogic.CLICK_WINDOW then
        return false -- our own click
    end
    return MarkLogic.Unexplained(check.gains, check.losses)
end
