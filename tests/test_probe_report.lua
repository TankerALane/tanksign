-- ProbeReport: classification never touches secret values; report layout.
local H = ...

-- A stand-in for a secret value: any comparison, concatenation, arithmetic,
-- indexing or tostring raises, like a secret value does for addon code.
local function makeSecret()
    local p = newproxy(true)
    local mt = getmetatable(p)
    local function boom() error("touched a secret value", 2) end
    mt.__index, mt.__newindex, mt.__concat, mt.__tostring = boom, boom, boom, boom
    mt.__eq, mt.__lt, mt.__le, mt.__add, mt.__sub, mt.__len, mt.__call = boom, boom, boom, boom, boom, boom, boom
    return p
end

H.test("classify reports SECRET without touching the value", function()
    local R = H.pureNamespace().ProbeReport
    local secret = makeSecret()
    local isSecret = function(v) return v == secret end -- raw identity, no metamethod for same object
    H.eq(R.Classify(isSecret, secret), "SECRET")
    H.eq(R.Classify(isSecret, 1234), "1234")
    H.eq(R.Classify(isSecret, nil), "nil")
    H.eq(R.Classify(isSecret, true), "true")
    H.eq(R.Classify(isSecret, "Defias Pillager"), '"Defias Pillager"')
    H.eq(R.Classify(nil, 5), "5")
    H.eq(R.Classify(isSecret, {}), "table")
end)

H.test("classify truncates long strings", function()
    local R = H.pureNamespace().ProbeReport
    local s = R.Classify(nil, string.rep("x", 100))
    H.ok(#s < 60, s)
end)

H.test("CallClassified handles missing, errors and multiple returns", function()
    local R = H.pureNamespace().ProbeReport
    local secret = makeSecret()
    local isSecret = function(v) return v == secret end
    H.eq(R.CallClassified(isSecret, nil)[1], "MISSING")
    local res = R.CallClassified(isSecret, function() error("nope") end)
    H.ok(res[1]:find("^ERROR:"), res[1])
    res = R.CallClassified(isSecret, function() error(secret) end)
    H.eq(res[1], "ERROR:<secret>")
    res = R.CallClassified(isSecret, function() return true, 3, secret, nil end)
    H.eq(table.concat(res, ","), "true,3,SECRET,nil")
end)

H.test("tally counts secret, plain, missing and error per field", function()
    local R = H.pureNamespace().ProbeReport
    local units = {
        { token = "nameplate1", order = { "hp", "dThreat" }, fields = { hp = { "SECRET" }, dThreat = { "true", "3", "SECRET" } } },
        { token = "nameplate2", order = { "hp", "dThreat" }, fields = { hp = { "1200" }, dThreat = { "MISSING" } } },
        { token = "target", order = { "hp" }, fields = { hp = { "ERROR:bad" } } },
    }
    local tally, order = R.Tally(units)
    H.eq(order[1], "hp")
    H.eq(tally.hp.secret, 1)
    H.eq(tally.hp.plain, 1)
    H.eq(tally.hp.error, 1)
    H.eq(tally.dThreat.secret, 1)
    H.eq(tally.dThreat.missing, 1)
    H.eq(R.SecretShare(tally, "hp"), "1/3")
    H.eq(R.SecretShare(tally, "nope"), "-")
end)

H.test("report puts problems first and lists every section", function()
    local R = H.pureNamespace().ProbeReport
    local results = {
        { id = "SetRaidTarget", kind = "api", status = "PASS" },
        { id = "UnitThreatPercentageOfLead", kind = "api", status = "FAIL", detail = "is nil, expected function" },
        { id = "x:group", kind = "custom", status = "INFO", detail = "inGroup=false" },
        { id = "m:slash", kind = "manual", status = "MANUAL" },
    }
    local lines = R.Build({ version = "0.1.0", interface = 16001 }, results, {
        events = { UNIT_HEALTH = { count = 4, samples = { '"target"' } } },
        marks = { { at = "now", call = "ok", before = "nil", after = "8", combat = "false", blocked = "no" } },
    })
    local text = table.concat(lines, "\n")
    H.eq(lines[1], "Tanksign probe report")
    H.ok(text:find("summary pass=1 fail=1 error=0 info=1 manual=1", 1, true), text)
    local problems = text:find("-- problems", 1, true)
    local details = text:find("-- details", 1, true)
    H.ok(problems and details and problems < details, "problems before details")
    H.ok(text:find("FAIL UnitThreatPercentageOfLead: is nil", 1, true))
    H.ok(text:find("INFO x:group: inGroup=false", 1, true))
    H.ok(text:find("UNIT_HEALTH=4 | (\"target\")", 1, true), text)
    H.ok(text:find("mark at=now call=ok before=nil after=8", 1, true))
    H.ok(text:find("-- combat samples\nnone yet", 1, true))
    H.ok(text:find("-- manual (check by eye): m:slash", 1, true))
end)
