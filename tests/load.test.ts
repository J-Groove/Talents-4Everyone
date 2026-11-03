// Every file the TOC lists loads in order, /t4e opens the main window, and the windows build and fill, with a
// stand-in for the game's UI functions.
import { expect, it } from 'vitest';
import { TOC_FILES as tocFiles, UI_STUB as ui, addon, evaluateAll } from './lua.ts';

const CODE = '3.70532.8.7.0.60..012801.1~d1u~15r_5~d1w~~2f_g~exo.051__2';

it('loads every TOC file, and /t4e opens and closes the main window', async () => {
  expect(tocFiles).toEqual(['Core.lua', 'Data.lua', 'Character.lua', 'Builds.lua', 'Order.lua', 'Rules.lua', 'Windows.lua',
    'Planner.lua', 'Talents.lua', 'Reminder.lua', 'Settings.lua', 'Minimap.lua', 'Talents4e.lua']);
  const lua = await addon(tocFiles, ui);
  expect(await evaluateAll(lua, ['SLASH_TALENTS4E1 .. " " .. SLASH_TALENTS4E2'])).toEqual(['/t4e /talents4e']);
  await lua.doString(`
    Talents4eDB = ns.Builds.Init({})
    SlashCmdList.TALENTS4E("")
    shownAfterOpen = Talents4eMainFrame:IsShown()
    SlashCmdList.TALENTS4E("export")
    shownAfterClose = Talents4eMainFrame:IsShown()`);
  expect(await evaluateAll(lua, ['shownAfterOpen', 'shownAfterClose', 'Talents4eMainFrame.count:GetText()', 'Talents4eMainFrame.empty:IsShown()']))
    .toEqual(['true', 'false', '0 of 20', 'true']);
});

it('imports a pasted link, follows it, and lists it in the main window', async () => {
  const lua = await addon(tocFiles, ui);
  await lua.doString(`
    Talents4eDB = ns.Builds.Init({})
    ns.Windows.Import()
    f = Talents4eImportFrame
    f.box:SetText("not a build")
    f.box._scripts.OnTextChanged(f.box, true)
    badNote, badSave = f.notes:GetText(), f.save:IsEnabled()
    f.box:SetText("https://wow-4e.com/builds/new#b=${CODE}")
    f.box._scripts.OnTextChanged(f.box, true)
    f.save._scripts.OnClick(f.save)`);
  const out = await evaluateAll(lua, [
    'badSave', 'badNote',
    'f.line1:GetText()', 'f.line3:GetText()', 'f:IsShown()',
    '#Talents4eDB.builds', 'Talents4eDB.builds[1].name', 'Talents4eDB.following["Jeff-Realm"]',
    'Talents4eMainFrame:IsShown()', 'Talents4eMainFrame.count:GetText()', 'Talents4eMainFrame.rows[1].name:GetText()',
    'Talents4eMainFrame.rows[1].following:IsShown()', 'Talents4eMainFrame.follow:GetText()',
  ]);
  expect(out.slice(0, 2)).toEqual(['false', expect.stringMatching(/ReadyCheck-NotReady.*(No build code|could not be read)/)]);
  expect(out[2]).toBe('Mage · Gnome · Body 1 · level 60');
  expect(out[3]).toMatch(/^Talent order · gear in \d+ slots$/);
  expect(out.slice(4)).toEqual(['false', '1', 'Mage, Arcane', '1', 'true', '1 of 20', 'Mage, Arcane', 'true', 'Stop following']);
});
