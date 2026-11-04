// The Settings page (Settings.lua) against a stand-in of Blizzard's Settings API, and the minimap button
// (Minimap.lua): both set up on ADDON_LOADED, and a setting turned off applies at once.
import { expect, it } from 'vitest';
import { DATA_BUILD, TOC_FILES, UI_STUB, addon, evaluateAll } from './lua.ts';

const SETTINGS_STUB = `${UI_STUB}
  Minimap = CreateFrame("Frame")
  function Minimap:GetWidth() return 140 end
  registered, checkboxes, buttons, opened = {}, {}, {}, nil
  Settings = {
    RegisterVerticalLayoutCategory = function(name) return { name = name, GetID = function() return 77 end } end,
    RegisterAddOnCategory = function(category) registered[#registered + 1] = category.name end,
    RegisterAddOnSetting = function(_, variable, key, tbl, kind, name, default)
      return { variable = variable, key = key, tbl = tbl, name = name,
        SetValueChangedCallback = function(self, f) self.changed = f end,
        SetValue = function(self, v) self.tbl[self.key] = v; self.changed(self, v) end }
    end,
    CreateCheckbox = function(_, setting, help) checkboxes[#checkboxes + 1] = setting end,
    OpenToCategory = function(id) opened = id end,
  }
  SettingsPanel = { GetLayout = function() return { AddInitializer = function(_, i) buttons[#buttons + 1] = i end } end }
  function CreateSettingsButtonInitializer(name, text, click) return { name = name, text = text, click = click } end
  function CreateSettingsListSectionHeaderInitializer(text) return { name = text } end`;

it('adds the Settings page and the minimap button, and applies a setting at once', async () => {
  const lua = await addon(TOC_FILES, SETTINGS_STUB);
  await lua.doString(`
    fire("ADDON_LOADED", "Talents4e")
    shownAtStart = Talents4eMinimapButton:IsShown()
    checkboxes[1]:SetValue(false)
    shownAfterOff = Talents4eMinimapButton:IsShown()
    checkboxes[4]:SetValue(false)
    -- Left-click opens the main window, right-click the Settings page.
    Talents4eMinimapButton._scripts.OnClick(Talents4eMinimapButton, "LeftButton")
    mainShown = Talents4eMainFrame:IsShown()
    Talents4eMinimapButton._scripts.OnClick(Talents4eMinimapButton, "RightButton")`);
  const out = await evaluateAll(lua, [
    'registered[1]', '#checkboxes', 'checkboxes[2].name', 'Talents4eDB.settings.numbers', 'buttons[1].text', 'buttons[2].text',
    'buttons[3].name', 'shownAtStart', 'shownAfterOff', 'Talents4eDB.settings.minimap', 'Talents4eDB.settings.reminder',
    'ns.Settings.Get("reminder")', 'ns.Settings.Get("list")', 'mainShown', 'opened',
  ]);
  expect(out).toEqual([
    'Talents-4Everyone', '4', 'Level numbers on talents', 'true', 'Reset', 'Open Talents-4Everyone',
    `v0.1.0 · data ${DATA_BUILD}`, 'true', 'false', 'false', 'false', 'false', 'true', 'true', '77',
  ]);
});

it('places the minimap button round the edge from its saved angle', async () => {
  const lua = await addon(TOC_FILES, SETTINGS_STUB);
  const out = await evaluateAll(lua, [
    'string.format("%.1f %.1f", ns.Minimap.Offset(0, 80))',
    'string.format("%.1f %.1f", ns.Minimap.Offset(90, 80))',
  ]);
  expect(out).toEqual(['80.0 0.0', '0.0 80.0']);
});
