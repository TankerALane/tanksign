-- Debug/ProbeReport.lua
-- PURE: must not touch WoW globals at load time.
-- Classifies values without ever inspecting a secret one, tallies which unit
-- fields came back secret, and turns probe results into a text report.

local _, ns = ...

local ProbeReport = {}
ns.ProbeReport = ProbeReport

ProbeReport.STATUSES = { "PASS", "FAIL", "ERROR", "INFO", "MANUAL" }
ProbeReport.MAX_STRING = 40

-- Describe one value as a short string. `isSecret` is a function (issecretvalue
-- or a stand-in); it is asked FIRST, so a secret value is never compared,
-- concatenated or printed.
function ProbeReport.Classify(isSecret, v)
    if isSecret then
        local ok, secret = pcall(isSecret, v)
        if ok and secret then return "SECRET" end
    end
    local t = type(v)
    if t == "nil" then return "nil" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
        local ok, s = pcall(string.format, "%.6g", v)
        return ok and s or "number"
    end
    if t == "string" then
        if #v > ProbeReport.MAX_STRING then v = v:sub(1, ProbeReport.MAX_STRING) .. "..." end
        return '"' .. v .. '"'
    end
    return t
end

-- Classify every return value of fn(...), safely. Returns a list of strings, or
-- { "ERROR:<message>" } if the call raised, or { "MISSING" } if fn is not a function.
function ProbeReport.CallClassified(isSecret, fn, ...)
    if type(fn) ~= "function" then return { "MISSING" } end
    local function collect(ok, ...)
        if not ok then
            local msg = ...
            if isSecret then
                local okS, secret = pcall(isSecret, msg)
                if okS and secret then msg = "<secret>" end
            end
            local okT, text = pcall(tostring, msg)
            return { "ERROR:" .. (okT and text or "?") }
        end
        local out = {}
        for i = 1, select("#", ...) do out[i] = ProbeReport.Classify(isSecret, (select(i, ...))) end
        return out
    end
    return collect(pcall(fn, ...))
end

-- Tally a list of unit samples: for each field, how many units had it SECRET,
-- readable, MISSING or ERROR. sample = { fields = { name = { "...", ... } } }.
function ProbeReport.Tally(units)
    local tally, order = {}, {}
    for _, u in ipairs(units) do
        for _, field in ipairs(u.order or {}) do
            local values = u.fields[field] or {}
            local first = values[1] or "nil"
            local t = tally[field]
            if not t then
                t = { secret = 0, plain = 0, missing = 0, error = 0 }
                tally[field] = t
                order[#order + 1] = field
            end
            local anySecret = false
            for _, v in ipairs(values) do if v == "SECRET" then anySecret = true end end
            if first == "MISSING" then t.missing = t.missing + 1
            elseif first:sub(1, 6) == "ERROR:" then t.error = t.error + 1
            elseif anySecret then t.secret = t.secret + 1
            else t.plain = t.plain + 1 end
        end
    end
    return tally, order
end

-- "3/5" style count of units with the field secret (or "-" if the field was never seen).
function ProbeReport.SecretShare(tally, field)
    local t = tally[field]
    if not t then return "-" end
    return string.format("%d/%d", t.secret, t.secret + t.plain + t.missing + t.error)
end

function ProbeReport.Count(results)
    local counts = { PASS = 0, FAIL = 0, ERROR = 0, INFO = 0, MANUAL = 0 }
    for _, r in ipairs(results) do counts[r.status] = (counts[r.status] or 0) + 1 end
    return counts
end

local function unitLine(u)
    local parts = {}
    for _, field in ipairs(u.order or {}) do
        parts[#parts + 1] = field .. "=" .. table.concat(u.fields[field] or {}, ",")
    end
    return "  " .. tostring(u.token) .. ": " .. table.concat(parts, " ")
end

function ProbeReport.UnitSampleLines(sample, add)
    add(string.format("sample at=%s combat=%s lockdown=%s units=%d", tostring(sample.at), tostring(sample.combat),
        tostring(sample.lockdown), #(sample.units or {})))
    local tally, order = ProbeReport.Tally(sample.units or {})
    local parts = {}
    for _, field in ipairs(order) do
        local t = tally[field]
        parts[#parts + 1] = string.format("%s secret=%d plain=%d%s%s", field, t.secret, t.plain,
            t.missing > 0 and (" missing=" .. t.missing) or "", t.error > 0 and (" error=" .. t.error) or "")
    end
    if #parts > 0 then add("  tally: " .. table.concat(parts, " | ")) end
    for _, u in ipairs(sample.units or {}) do add(unitLine(u)) end
end

-- meta: { version, interface, clientVersion, build, at, tocFlavor, projectId }
-- results: list of { id, kind, area, status, detail }
-- extra: { combat = {samples}, marks = {...}, targets = {...}, events = { NAME = { count, samples } } }
function ProbeReport.Build(meta, results, extra)
    extra = extra or {}
    local out = {}
    local function add(s) out[#out + 1] = s end
    local counts = ProbeReport.Count(results)

    add("Tanksign probe report")
    add(string.format("addon=%s interface=%s client=%s build=%s project=%s toc=%s at=%s",
        tostring(meta.version), tostring(meta.interface), tostring(meta.clientVersion), tostring(meta.build),
        tostring(meta.projectId), tostring(meta.tocFlavor), tostring(meta.at)))
    add(string.format("summary pass=%d fail=%d error=%d info=%d manual=%d",
        counts.PASS, counts.FAIL, counts.ERROR, counts.INFO, counts.MANUAL))

    local problems = {}
    for _, r in ipairs(results) do
        if r.status == "FAIL" or r.status == "ERROR" then problems[#problems + 1] = r end
    end
    if #problems > 0 then
        add("-- problems (missing or failing)")
        for _, r in ipairs(problems) do add(r.status .. " " .. r.id .. (r.detail and (": " .. r.detail) or "")) end
    end

    add("-- details")
    for _, r in ipairs(results) do
        if r.kind == "custom" and r.status ~= "FAIL" and r.status ~= "ERROR" then
            add(r.status .. " " .. r.id .. ": " .. tostring(r.detail or ""))
        end
    end
    if meta.unitSample then ProbeReport.UnitSampleLines(meta.unitSample, add) end

    add("-- combat samples")
    if not extra.combat or #extra.combat == 0 then
        add("none yet: keep combat sampling on (/ts probe combat on) and fight a group of mobs")
    else
        for i, s in ipairs(extra.combat) do
            add("combat sample " .. i)
            ProbeReport.UnitSampleLines(s, add)
        end
    end

    add("-- mark tests")
    if not extra.marks or #extra.marks == 0 then
        add("none yet: /ts probe mark on a mob (solo, in a party as leader and not leader, and in combat)")
    else
        for _, m in ipairs(extra.marks) do
            add(string.format("mark at=%s call=%s before=%s after=%s combat=%s blocked=%s group=%s leader=%s assist=%s",
                tostring(m.at), tostring(m.call), tostring(m.before), tostring(m.after), tostring(m.combat),
                tostring(m.blocked), tostring(m.group), tostring(m.leader), tostring(m.assist)))
        end
    end

    add("-- target tests")
    if not extra.targets or #extra.targets == 0 then
        add("none yet: /ts probe target (once out of combat is enough)")
    else
        for _, t in ipairs(extra.targets) do
            add(string.format("target at=%s call=%s blocked=%s self=%s combat=%s",
                tostring(t.at), tostring(t.call), tostring(t.blocked), tostring(t.self), tostring(t.combat)))
        end
    end

    add("-- events seen since login (count | first samples)")
    local names = {}
    for name in pairs(extra.events or {}) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then add("none") end
    for _, name in ipairs(names) do
        local e = extra.events[name]
        local line = name .. "=" .. tostring(e.count)
        for _, s in ipairs(e.samples or {}) do line = line .. " | (" .. s .. ")" end
        add(line)
    end

    local passes = {}
    for _, r in ipairs(results) do
        if r.status == "PASS" and r.kind ~= "custom" then passes[#passes + 1] = r.id end
    end
    add("-- pass (" .. #passes .. ")")
    local line = ""
    for _, id in ipairs(passes) do
        if #line + #id > 150 then add(line); line = "" end
        line = line == "" and id or (line .. ", " .. id)
    end
    if line ~= "" then add(line) end

    local manual = {}
    for _, r in ipairs(results) do
        if r.status == "MANUAL" then manual[#manual + 1] = r.id end
    end
    if #manual > 0 then add("-- manual (check by eye): " .. table.concat(manual, ", ")) end
    return out
end
