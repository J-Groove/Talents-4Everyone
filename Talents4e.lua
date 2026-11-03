-- Saved data and the slash command. /t4e and /talents4e only open the main window; every feature is a button
-- there (Windows.lua).
local addonName, ns = ...
local Builds, Windows = ns.Builds, ns.Windows

SLASH_TALENTS4E1 = "/t4e"
SLASH_TALENTS4E2 = "/talents4e"
SlashCmdList.TALENTS4E = function()
  Windows.ToggleMain()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
  if name ~= addonName then return end
  Talents4eDB = Builds.Init(Talents4eDB or {})
  ns.Settings.Init()
  ns.Minimap.Refresh()
  self:UnregisterEvent("ADDON_LOADED")
end)
