// Following a talent order: Order.lua (taken, next, off plan, the first talent level, the reminder's words) and
// Talents.lua (what the talent window shows), on a Mage's Arcane tree.
import { expect, it } from 'vitest';
import { TOC_FILES, UI_STUB, addon, evaluateAll } from './lua.ts';

// Arcane (tree 1): 1 Wand Specialization (2 ranks), 2 Improved Channeling (5), 3 Arcane Resilience (3),
// 4 Arcane Subtlety (2). Their node ids, and Talented's (Legacy tree 1, perk 3).
const NODE = { wand: 105815, channeling: 105813, resilience: 105802, subtlety: 105812, talented: 110298 };
// Channeling, Channeling, Resilience, Channeling, Wand.
const ORDER = '{ { tree = 1, index = 2 }, { tree = 1, index = 2 }, { tree = 1, index = 3 }, { tree = 1, index = 2 }, { tree = 1, index = 1 } }';
const BUILD = `{ gameBuild = 70707, classId = 8, raceId = 7, sex = 0, level = 14, talents = {}, order = ${ORDER}, gear = {}, legacy = {} }`;

/** The game: a level 13 Mage with these node ranks, following BUILD; plus a talent window whose buttons are stubs. */
function game(level: number, ranks: Record<number, number>) {
  const list = Object.entries(ranks).map(([node, rank]) => `[${node}] = ${rank}`).join(', ');
  return `${UI_STUB}
    function UnitLevel() return ${level} end
    ranks = { ${list} }
    C_ClassTalents = { GetActiveConfigID = function() return 1 end }
    C_Traits = {
      GetConfigIDBySystemID = function() return 2 end,
      GetNodeInfo = function(_, node) return { ID = node, ranksPurchased = ranks[node] or 0 } end,
    }`;
}

async function following(level: number, ranks: Record<number, number>) {
  const lua = await addon(TOC_FILES, game(level, ranks));
  await lua.doString(`
    fire("ADDON_LOADED", "Talents4e")
    local b = ${BUILD}
    b.talents = ns.Core.RanksFromOrder(b.order) -- a code with an order carries the ranks it adds up to
    entry = ns.Builds.Add(Talents4eDB, ns.Core.EncodeBuild(b), "Frost", 1)
    ns.Builds.Follow(Talents4eDB, "Jeff-Realm", entry.id, 8)
    build = ns.Builds.Decode(entry)
    function planAt(level) local t, l = ns.Character.Ranks(); return ns.Order.Plan(build, t, level, ns.Order.FirstLevel(l)) end
    function reminder(level) local h, b = ns.Order.Reminder(build, planAt(level), level); return tostring(h) .. " / " .. tostring(b) end
    function badges()
      local t, l = ns.Character.Ranks()
      local out = {}
      for _, b in pairs(ns.Talents.Badges(ns.Talents.State(UnitLevel("player"), t, l))) do
        out[#out + 1] = b.index .. "=" .. b.kind .. (b.text and (":" .. b.text) or "")
      end
      table.sort(out)
      return table.concat(out, " ")
    end`);
  return lua;
}

it('walks the order against the ranks: taken, next, levels and points off the build', async () => {
  const lua = await following(13, { [NODE.channeling]: 1, [NODE.resilience]: 1, [NODE.subtlety]: 1 });
  const out = await evaluateAll(lua, [
    '(function() local p = planAt(13); local s = {}; for k, st in ipairs(p.steps) do s[k] = st.level .. (st.taken and "T" or "-") .. st.rank end; return table.concat(s, " ") end)()',
    'planAt(13).next', 'planAt(13).spent', 'planAt(13).points', 'planAt(13).toSpend',
    'planAt(13).offPlan[1].index .. "+" .. planAt(13).offPlan[1].extra', '#planAt(13).offPlan',
    'badges()',
  ]);
  expect(out).toEqual(['10T1 11-2 12T1 13-3 14-1', '2', '3', '4', '1', '4+1', '1', '1=due:14 2=next:11 3=taken 4=off']);
});

it('moves every step earlier with Talented, as the site does', async () => {
  const lua = await following(13, { [NODE.talented]: 2 });
  const out = await evaluateAll(lua, ['ns.Order.FirstLevel({ { 0, 0, 2 } })', 'ns.Order.FirstLevel(nil)',
    'planAt(13).steps[1].level', 'planAt(13).steps[5].level', 'planAt(13).points', 'ns.Order.PointsAtLevel(60, 5)']);
  expect(out).toEqual(['8', '10', '8', '12', '6', '51']);
});

it('words the level-up reminder', async () => {
  const lua = await following(13, { [NODE.channeling]: 1, [NODE.resilience]: 1 });
  const out = await evaluateAll(lua, ['reminder(12)', 'reminder(13)', 'reminder(10)']);
  expect(out).toEqual([
    'Level 12: Improved Channeling / Rank 2 of 5',
    'Level 13: 2 points to spend / First: Improved Channeling, rank 2 of 5',
    'nil / nil', // the next step (level 11) isn't due yet
  ]);
  const done = await following(14, { [NODE.channeling]: 3, [NODE.resilience]: 1, [NODE.wand]: 1 });
  expect(await evaluateAll(done, ['reminder(14)'])).toEqual(['Build complete / Every talent in your build is taken.']);
  const off = await following(14, { [NODE.channeling]: 3, [NODE.resilience]: 1, [NODE.wand]: 1, [NODE.subtlety]: 1 });
  expect(await evaluateAll(off, ['reminder(14)'])).toEqual(["Off your build / Arcane Subtlety has points your build doesn't plan."]);
});

it('fills the order list on the talent window when it opens', async () => {
  const lua = await following(13, { [NODE.channeling]: 1, [NODE.resilience]: 1, [NODE.subtlety]: 1 });
  await lua.doString(`
    PlayerSpellsFrame = CreateFrame("Frame", "PlayerSpellsFrame")
    tab = CreateFrame("Frame")
    buttons = {}
    function tab:GetTalentButtonByNodeID(node) buttons[node] = buttons[node] or CreateFrame("Button"); return buttons[node] end
    PlayerSpellsFrame.TalentsFrame = tab
    fire("ADDON_LOADED", "Blizzard_PlayerSpells")
    tab:Show()
    L = Talents4eOrderList
    function row(i) local r = L.rows[i]; return r.level:GetText() .. "|" .. r.name:GetText() .. "|" .. r.rank:GetText() end`);
  const out = await evaluateAll(lua, ['L:IsShown()', 'L.name:GetText()', 'L.summary:GetText()', 'L.message:IsShown()',
    'row(1)', 'row(2)', 'L.rows[2].bg:IsShown()', 'row(5)', 'row(6)', 'row(7)', 'tostring(L.rows[8])']);
  expect(out).toEqual(['true', 'Frost', 'Level 13 · 3 of 5 points', 'false',
    '10|Improved Channeling||TInterface\\RaidFrame\\ReadyCheck-Ready:12|t Taken',
    '11|Improved Channeling|2 of 5', 'true',
    '|cff80808014|r|Wand Specialization|1 of 2',
    '||cffff9919Not in your build|r|',
    '|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:12|t|Arcane Subtlety|1 of 2',
    'nil']);
});

it('says why there is nothing to follow', async () => {
  const lua = await addon(TOC_FILES, game(13, {}));
  await lua.doString(`
    fire("ADDON_LOADED", "Talents4e")
    warrior = ns.Builds.Add(Talents4eDB, "3.0.1.2.0.1....", "", 1)
    ranksOnly = ns.Builds.Add(Talents4eDB, "3.70707.8.7.0.60.2305...", "", 2)
    function message() local s = ns.Talents.State(13, ns.Character.Ranks()); return s.message and s.message.text or "none" end`);
  const out = await evaluateAll(lua, [
    'message()',
    '(function() Talents4eDB.following["Jeff-Realm"] = warrior.id; return message() end)()',
    '(function() Talents4eDB.following["Jeff-Realm"] = ranksOnly.id; return message() end)()',
  ]);
  expect(out[0]).toBe('Follow a build in Talents-4Everyone to see its talent order here.');
  expect(out[1]).toBe('The build you follow is for a Warrior. Follow one for this class.');
  expect(out[2]).toMatch(/^This build has no talent order\./);
});
