-- Compat/Unsupported.lua
-- Loaded only by the fallback Tanksign.toc, which a client reads when it did not
-- pick Tanksign_Forever.toc. It prints one message and does nothing else.

local _, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    local ok, _, _, _, interface = pcall(GetBuildInfo)
    local msg = ns.L.UNSUPPORTED:format(ok and tostring(interface) or "?")
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Tanksign|r: " .. msg) end
end)
