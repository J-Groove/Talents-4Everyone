// The talent planner (Planner.lua): placing points in order with the site's rules, the pool from a ranks-only
// build or the character's talents, and saving from its window, on a Mage's Arcane tree.
import { expect, it } from 'vitest';
import { TOC_FILES, UI_STUB, addon, evaluateAll } from './lua.ts';

// Arcane (tree 1): 1 Wand Specialization (2 ranks), 2 Improved Channeling (5), 3 Arcane Resilience (3),
// 4 Arcane Subtlety (2, row 2). Node ids for the character's ranks; Talented is Legacy tree 1, perk 3.
const NODE = { channeling: 105813, resilience: 105802, talented: 110298 };

/** A level `level` Mage with these node ranks. */
function game(level: number, ranks: Record<number, number>) {
  const list = Object.entries(ranks).map(([node, rank]) => `[${node}] = ${rank}`).join(', ');
  return `${UI_STUB}
    function UnitLevel() return ${level} end
    function UnitRace() return "Gnome", "Gnome", 7 end
    function UnitSex() return 3 end
    function GetBuildInfo() return "1.60.1", "70707" end
    function GetInventoryItemLink() return nil end
    function StaticPopup_Show(which, a) popup = which .. ":" .. tostring(a) end
    ranks = { ${list} }
    C_ClassTalents = { GetActiveConfigID = function() return 1 end }
    C_Traits = {
      GetConfigIDBySystemID = function() return 2 end,
      GetNodeInfo = function(_, node) return { ID = node, ranksPurchased = ranks[node] or 0 } end,
    }
    function orderLine(p)
      local out = {}
      for i, s in ipairs(p.order) do out[i] = s.tree .. ":" .. s.index end
      return table.concat(out, " ")
    end`;
}

async function planner(level: number, ranks: Record<number, number> = {}) {
  const lua = await addon(TOC_FILES, game(level, ranks));
  await lua.doString(`fire("ADDON_LOADED", "Talents4e")`);
  return lua;
}

it('places points one per level and refuses what the rules refuse, in words', async () => {
  const lua = await planner(16);
  await lua.doString(`
    p = ns.Planner.New({ classId = 8, level = 16 })
    first = ns.Planner.Hint(p).text
    lockedOk = ns.Planner.Click(p, 1, 4)
    locked = p.message.text
    for _ = 1, 5 do ns.Planner.Click(p, 1, 2) end
    ns.Planner.Click(p, 1, 4)
    ns.Planner.Click(p, 1, 1)
    full = ns.Planner.Click(p, 1, 1)
    fullText = p.message.text
    -- Channeling's last point holds Arcane Subtlety's row: refused. Wand's comes off.
    channelOff = ns.Planner.Click(p, 1, 2, true)
    channelText = p.message.text
    wandOff = ns.Planner.Click(p, 1, 1, true)`);
  const out = await evaluateAll(lua, [
    'first', 'lockedOk', 'locked', 'full', 'fullText', 'channelOff', 'channelText', 'wandOff', 'orderLine(p)',
    'ns.Planner.Summary(p, 16)', 'table.concat(ns.Planner.Levels(p, 1, 2), ",")', 'ns.Planner.Rows(p)[6].rank',
    'ns.Planner.Rows(p)[6].level', 'ns.Planner.Hint(p).text', 'p.dirty',
  ]);
  expect(out).toEqual([
    'Click a talent to take it at level 10.', 'false', 'Arcane Subtlety needs 5 points in Arcane above it first.',
    'false', 'Every point you have at this level is placed.',
    'false', 'Arcane Subtlety cannot be taken at level 14: it needs 5 points in Arcane above it first.', 'true',
    '1:2 1:2 1:2 1:2 1:2 1:4', '6 of 7 points · level 16 · first point at level 10', '10,11,12,13,14', '1 of 2', '15',
    'Left-click adds a point at level 16. Right-click takes a talent\'s last point off.', 'true',
  ]);
});

it('counts Talented, and takes a step out of the middle only when the rest still holds', async () => {
  const lua = await planner(12, { [NODE.talented]: 1 });
  await lua.doString(`
    local _, legacy = ns.Character.Ranks()
    p = ns.Planner.New({ classId = 8, level = 12, legacyRanks = legacy })
    for _, i in ipairs({ 3, 2, 3, 1 }) do ns.Planner.Click(p, 1, i) end
    middle = ns.Planner.RemoveAt(p, 2)`);
  expect(await evaluateAll(lua, ['p.firstLevel', 'p.limit', 'middle', 'orderLine(p)', 'ns.Planner.Summary(p, 12)']))
    .toEqual(['9', '4', 'true', '1:3 1:3 1:1', '3 of 4 points · level 12 · first point at level 9 (Talented)']);
});

it('puts a ranks-only build or the character\'s talents in order from a pool', async () => {
  const lua = await planner(20, { [NODE.channeling]: 3, [NODE.resilience]: 2 });
  await lua.doString(`
    local b = { gameBuild = 70707, classId = 8, raceId = 7, sex = 0, level = 60, order = {}, gear = {}, legacy = {},
      talents = { { 0, 5, 0, 2 } } }
    p = ns.Planner.New({ classId = 8, level = 20, build = b })
    _, poolBefore = ns.Planner.PoolLeft(p)
    ns.Planner.Click(p, 1, 2)
    hint = ns.Planner.Hint(p).text
    ns.Planner.PlaceRest(p)
    placed = orderLine(p)
    mine = ns.Planner.New({ classId = 8, level = 20 })
    ns.Planner.StartFrom(mine, (ns.Character.Ranks()))
    _, mineLeft = ns.Planner.PoolLeft(mine)`);
  expect(await evaluateAll(lua, ['p.limit', 'poolBefore', 'hint', 'placed', 'mineLeft']))
    .toEqual(['11', '7', 'Points from your talents still to place: 6. Click them in the order you took them, or Place the rest.',
      '1:2 1:2 1:2 1:2 1:2 1:4 1:4', '5']);
});

it('opens from the main window, saves a new build and follows it, and saves over an edited one', async () => {
  const lua = await planner(14);
  await lua.doString(`
    Talents4eDB = ns.Builds.Init({})
    ns.Windows.ShowMain()
    newPlan = nil
    ns.Planner.Open(nil)
    f = Talents4ePlannerFrame
    p = ns.Planner.Current()
    for _ = 1, 3 do f.trees[1].buttons[2]._scripts.OnClick(f.trees[1].buttons[2], "LeftButton") end
    rankText = f.trees[1].buttons[2].rank:GetText()
    rowName = f.rows[3].name:GetText()
    f.trees[1].buttons[2]._scripts.OnClick(f.trees[1].buttons[2], "RightButton")
    afterRight = #p.order
    f.save._scripts.OnClick(f.save)
    saved = Talents4eDB.builds[1]
    savedBuild = ns.Builds.Decode(saved)
    -- Edit it: one more point, then Save asks and saves over it.
    ns.Planner.Open(saved)
    q = ns.Planner.Current()
    ns.Planner.Click(q, 1, 3)
    f.save._scripts.OnClick(f.save)
    asked = popup
    StaticPopupDialogs.TALENTS4E_SAVE_OVER.OnAccept()
    edited = ns.Builds.Decode(Talents4eDB.builds[1])`);
  const out = await evaluateAll(lua, [
    'rankText', 'rowName', 'afterRight', '#Talents4eDB.builds', 'saved.name', 'Talents4eDB.following["Jeff-Realm"] == saved.id',
    '#savedBuild.order', 'savedBuild.raceId', 'savedBuild.level', 'f:IsShown()', 'Talents4eMainFrame:IsShown()',
    'q.entry.id == saved.id', '#q.order', 'asked', '#Talents4eDB.builds', '#edited.order', 'Talents4eDB.builds[1].name',
  ]);
  expect(out).toEqual([
    '|cff40ff403/5|r', 'Improved Channeling', '2', '1', 'Mage, Arcane', 'true',
    '2', '7', '14', 'false', 'true',
    'true', '3', 'TALENTS4E_SAVE_OVER:Mage, Arcane', '1', '3', 'Mage, Arcane',
  ]);
});
