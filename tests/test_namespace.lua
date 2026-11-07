-- Namespace helpers, flavor detection and the palette.
local H = ...

H.test("splitCommand lower-cases the command and trims the rest", function()
    local ns = H.pureNamespace()
    local cmd, rest = ns.util.splitCommand("  Probe   Combat On ")
    H.eq(cmd, "probe")
    H.eq(rest, "Combat On")
    cmd, rest = ns.util.splitCommand(nil)
    H.eq(cmd, "")
    H.eq(rest, "")
end)

H.test("pack keeps trailing nils", function()
    local ns = H.pureNamespace()
    local p = ns.util.pack(1, nil, nil)
    H.eq(p.n, 3)
end)

H.test("flavor: only 16xxx is Forever", function()
    local F = H.pureNamespace().FlavorLogic
    H.eq(F.FromInterface(16001), "Forever")
    H.eq(F.FromInterface("16001"), "Forever")
    H.eq(F.FromInterface(120105), "Unknown")
    H.eq(F.FromInterface(11508), "Unknown")
    H.eq(F.FromInterface(nil), "Unknown")
    H.ok(F.IsSupported("Forever"))
    H.ok(not F.IsSupported("Unknown"))
end)

H.test("palette is Fellowship Ledger's Plain skin, value for value", function()
    local P = H.pureNamespace().Palette
    -- Copied from FellowshipLedger/UI/Palette.lua SKINS.plain; a change here must be deliberate.
    local want = {
        bg = { 0.05, 0.05, 0.06, 0.92 }, panel = { 0.1, 0.1, 0.12, 0.9 }, border = { 0.45, 0.45, 0.5, 1 },
        text = { 0.95, 0.95, 0.95, 1 }, muted = { 0.7, 0.7, 0.72, 1 }, heading = { 1, 0.82, 0, 1 },
        accent = { 1, 0.82, 0, 1 }, buttonBg = { 0.25, 0.25, 0.28, 0.9 }, buttonBorder = { 0.5, 0.5, 0.55, 1 },
        buttonText = { 1, 0.82, 0, 1 }, rule = { 0.45, 0.45, 0.5, 1 }, rowAlt = { 1, 1, 1, 0.04 },
        good = { 0.4, 0.85, 0.5, 1 }, bad = { 1, 0.45, 0.4, 1 },
    }
    for role, c in pairs(want) do
        for i = 1, 4 do H.eq(P.Color(role)[i], c[i], role .. "[" .. i .. "]") end
    end
    for _, role in ipairs(P.ROLES) do H.ok(want[role], "role " .. role .. " has a value") end
    H.eq(P.Code(P.Color("heading")), "|cffffd100")
end)

H.test("palette matches the Fellowship Ledger file when it is next door", function()
    local f = io.open(H.ROOT .. "/../fellowship_ledger/FellowshipLedger/UI/Palette.lua", "rb")
    if not f then return end -- only checked on Austin's machine
    local src = f:read("*a")
    f:close()
    local plain = src:match("plain = (%b{})")
    H.ok(plain, "found SKINS.plain")
    local fl = assert(loadstring("return " .. plain))()
    local P = H.pureNamespace().Palette
    for role, c in pairs(fl) do
        for i = 1, 4 do H.eq(P.Color(role)[i], c[i], role .. "[" .. i .. "]") end
    end
end)

H.test("locale falls back to the key", function()
    local L = H.pureNamespace().L
    H.eq(L.ADDON_TITLE, "Tanksign")
    H.eq(L.NO_SUCH_KEY, "NO_SUCH_KEY")
end)
