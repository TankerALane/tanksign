-- TOC fields, file lists, icon and version agreement.
local H = ...

local function parseToc(rel)
    local fields, files = {}, {}
    for line in (H.readFile(rel) .. "\n"):gmatch("(.-)\r?\n") do
        local k, v = line:match("^## ([%w%-_]+):%s*(.-)%s*$")
        if k then
            fields[k] = v
        elseif line ~= "" and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return fields, files
end

local FOREVER = "Tanksign/Tanksign_Forever.toc"
local GENERIC = "Tanksign/Tanksign.toc"

H.test("Forever TOC fields", function()
    local f = parseToc(FOREVER)
    H.eq(f.Interface, "16001")
    H.eq(f["X-Flavor"], "Forever")
    H.eq(f.Title, "Tanksign")
    H.eq(f.Author, "Decoupled Lane Studio")
    H.eq(f.SavedVariables, "TanksignDB")
    H.eq(f["X-License"], "MIT")
    H.ok(f.Notes and f.Notes:find("support@decoupledlane.com", 1, true), "support email in Notes")
end)

H.test("fallback TOC never loads the addon", function()
    local g, files = parseToc(GENERIC)
    H.eq(g.Interface, "00000")
    H.eq(files[#files], "Compat/Unsupported.lua")
    for _, rel in ipairs(files) do H.ok(rel ~= "Core/Init.lua", "fallback must not load Init") end
end)

H.test("every listed file exists", function()
    for _, toc in ipairs({ FOREVER, GENERIC }) do
        local _, files = parseToc(toc)
        for _, rel in ipairs(files) do
            H.ok(H.fileExists("Tanksign/" .. rel), toc .. " lists missing file " .. rel)
        end
    end
end)

H.test("pure files load in the same order as the TOC", function()
    local _, files = parseToc(FOREVER)
    local index = {}
    for i, rel in ipairs(files) do index[rel] = i end
    local last = 0
    for _, rel in ipairs(H.PURE_FILES) do
        H.ok(index[rel], rel .. " is not in the TOC")
        H.ok(index[rel] > last, rel .. " is out of order")
        last = index[rel]
    end
end)

H.test("icon file exists for IconTexture", function()
    local f = parseToc(FOREVER)
    local rel = f.IconTexture:gsub("^Interface\\AddOns\\", ""):gsub("\\", "/")
    H.ok(H.fileExists(rel .. ".tga"), "missing " .. rel .. ".tga")
end)

H.test("versions agree between TOCs and Namespace", function()
    local f = parseToc(FOREVER)
    local g = parseToc(GENERIC)
    H.eq(g.Version, f.Version)
    H.eq(H.pureNamespace().VERSION, f.Version)
end)

H.test("LICENSE is MIT with the studio copyright", function()
    local text = H.readFile("LICENSE")
    H.ok(text:find("MIT License", 1, true))
    H.ok(text:find("Copyright (c) 2026 Decoupled Lane Studio", 1, true))
end)
