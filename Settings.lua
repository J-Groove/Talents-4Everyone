-- The Settings page (docs\ui-design.md screen 7): a category in Blizzard's Settings panel (AddOns tab), so the
-- addon needs no settings window of its own. Check boxes for the minimap button, the level numbers, the order list
-- and the level-up reminder, and buttons to reset the reminder's position and open the main window. Changes apply
-- at once and are saved account-wide in Talents4eDB.settings (missing means on).
local addonName, ns = ...
local Data = ns.Data

local Settings_ = {}
ns.Settings = Settings_

-- Each check box: the key in Talents4eDB.settings, its label and its line of help. The panel cuts labels at about
-- 28 characters, so the label stays short and the help says the rest.
Settings_.OPTIONS = {
  { key = "minimap", name = "Minimap button", help = "A button on the minimap that opens Talents-4Everyone. /t4e "
    .. "opens it too." },
  { key = "numbers", name = "Level numbers on talents", help = "On the talent window, the level each planned "
    .. "talent is due, and the glow on the next one to take." },
  { key = "list", name = "Talent order list", help = "Your build's talent order, docked to the "
    .. "right of the talent window." },
  { key = "reminder", name = "Level-up reminder", help = "When you level up, a note names the next talent to take." },
}

local function db() return Talents4eDB end

-- Whether a setting is on: missing means on.
function Settings_.Get(key)
  local settings = db() and db().settings
  return not (settings and settings[key] == false)
end

-- Turns a setting on or off and applies it at once.
function Settings_.Set(key, on)
  db().settings = db().settings or {}
  db().settings[key] = on and true or false
  if key == "minimap" and ns.Minimap then ns.Minimap.Refresh() end
  if (key == "numbers" or key == "list") and ns.Talents then ns.Talents.Refresh() end
end

local category

-- Adds the category to Blizzard's Settings panel. Does nothing on a client without the modern Settings API.
function Settings_.Init()
  db().settings = db().settings or {}
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  category = Settings.RegisterVerticalLayoutCategory("Talents-4Everyone")
  for _, option in ipairs(Settings_.OPTIONS) do
    local variable = addonName .. "_" .. option.key
    local stored = db().settings[option.key]
    if stored == nil then db().settings[option.key] = true end
    -- 11.0 and later: (category, variable, key, table, type, name, default).
    local ok, setting = pcall(Settings.RegisterAddOnSetting, category, variable, option.key, db().settings,
      "boolean", option.name, true)
    if ok and setting then
      local create = Settings.CreateCheckbox or Settings.CreateCheckBox
      create(category, setting, option.help)
      if setting.SetValueChangedCallback then
        setting:SetValueChangedCallback(function(_, value) Settings_.Set(option.key, value) end)
      elseif Settings.SetOnValueChangedCallback then
        Settings.SetOnValueChangedCallback(variable, function(_, _, value) Settings_.Set(option.key, value) end)
      end
    end
  end

  local layout = SettingsPanel and SettingsPanel.GetLayout and SettingsPanel:GetLayout(category)
  if layout and CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("Reminder position", "Reset", function()
      ns.Reminder.ResetPosition()
    end, "Puts the reminder back beside the talent button.", false))
    layout:AddInitializer(CreateSettingsButtonInitializer("Saved builds", "Open Talents-4Everyone", function()
      if SettingsPanel and SettingsPanel.Close then SettingsPanel:Close(true) end
      ns.Windows.ShowMain()
    end, "Your saved builds, import, export and the talent planner.", false))
    if CreateSettingsListSectionHeaderInitializer then
      local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("v"
        .. tostring(getMeta and getMeta(addonName, "Version") or "?") .. " · data " .. Data.build))
    end
  end
  Settings.RegisterAddOnCategory(category)
end

-- Opens the Settings panel on this addon's page.
function Settings_.Open()
  if category and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  end
end
