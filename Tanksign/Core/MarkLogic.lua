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
-- as unmarked: a "none" answer is ignored while the mark is pending (GRACE seconds, or
-- until the client first shows the unit as marked).

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
    if seen == "none" then
        if placedAt and now and now - placedAt < MarkLogic.GRACE then return end -- not arrived yet
        clearToken(state, token)
        return
    end
    state.pending[token] = nil -- the client shows a marker: the click arrived
    if type(seen) == "number" and seen >= 1 and seen <= 8 then
        if state.byToken[token] ~= seen then MarkLogic.Place(state, seen, token) end
    end
    -- "hidden": keep what we remember
end

function MarkLogic.Get(state, token)
    return state.byToken[token]
end
