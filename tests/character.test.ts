// Character.lua against a stand-in for the game's API: a level 42 Body 2 Gnome Mage (class 8, race 7).
import { describe, expect, it } from 'vitest';
import { addon, evaluate } from './lua.ts';

const FILES = ['Core.lua', 'Data.lua', 'Character.lua'];

/** Stubs for the game API. ranks maps node id -> ranks bought; nodes not listed are unknown to the "game". */
function game({ talentConfig = 'TALENTS', legacyConfig = 'LEGACY', clientBuild = '70707' } = {}): string {
  return `
    function UnitClass() return "Mage", "MAGE", 8 end
    function UnitRace() return "Gnome", "Gnome", 7 end
    function UnitSex() return 3 end
    function UnitLevel() return 42 end
    function GetBuildInfo() return "1.60.1", "${clientBuild}", "Oct 30 2026", 16001 end
    links = { [1] = "|cffa335ee|Hitem:16914:1503:0:0:0:0:87:0:42|h[Crown]|h|r", [16] = "|Hitem:19356::::::::42|h[Staff]|h" }
    function GetInventoryItemLink(unit, slot) return links[slot] end
    ranks = {}
    C_ClassTalents = { GetActiveConfigID = function() return ${talentConfig === null ? 'nil' : `"${talentConfig}"`} end }
    C_Traits = {
      GetConfigIDBySystemID = function(id) if id == 45 then return ${legacyConfig === null ? 'nil' : `"${legacyConfig}"`} end end,
      GetNodeInfo = function(config, node)
        local known = config == "TALENTS" and ns.Data.classes[8] or ns.Data.legacy
        for _, tree in ipairs(known) do
          for _, id in ipairs(tree.nodes) do
            if id == node then return { ID = node, ranksPurchased = ranks[node] or 0 } end
          end
        end
        return { ID = 0 }
      end,
    }`;
}

/** Ranks the stub game reports, set by tree and position (1-based) so the test reads like a build. */
const spend = `
  local mage, legacy = ns.Data.classes[8], ns.Data.legacy
  ranks[mage[1].nodes[1]] = 2
  ranks[mage[1].nodes[2]] = 3
  ranks[mage[3].nodes[3]] = 1
  ranks[legacy[1].nodes[2]] = 2`;

const read = `(function() local b, p = ns.Character.Read(); return ns.Core.EncodeBuild(b) .. "|" .. table.concat(p, "; ") end)()`;

describe('Character.Read', () => {
  it('reads class, race, body type, level, talents, Legacy perks and gear into a build code', async () => {
    const lua = await addon(FILES, game());
    await lua.doString(spend);
    expect(await evaluate(lua, read)).toBe('3.70707.8.7.1.42.23__001..1~d1u~15r~2f_g~exo.02|');
  });

  it('leaves out what the game does not give, and says so', async () => {
    const lua = await addon(FILES, game({ talentConfig: null, legacyConfig: null, clientBuild: '70800' }));
    const [code, problems] = (await evaluate<string>(lua, read)).split('|');
    expect(code).toBe('3.70707.8.7.1.42...1~d1u~15r~2f_g~exo.');
    expect(problems).toMatch(/data is from game build 70707, the game is 70800/);
    expect(problems).toMatch(/Talents left out/);
    expect(problems).toMatch(/Legacy perks left out/);
  });

  it('on Retail, writes what it can and says what it left out', async () => {
    const lua = await addon(FILES, retail);
    const [code, problems] = (await evaluate<string>(lua, read)).split('|');
    expect(code).toBe('3.70707.6.1.0.60...g~exo.');
    expect(problems).toMatch(/Level 80 is above Forever's 60/);
    expect(problems).toMatch(/No talent data for this class/);
    expect(problems).toMatch(/Legacy perks left out/);
  });
});

describe('Character.Check', () => {
  it("lists the game's own talent trees, so the trait API can be checked on Retail", async () => {
    const lua = await addon(FILES, retail);
    const lines = await evaluate<string>(lua, 'table.concat(ns.Character.Check(), "; ")');
    expect(lines).toMatch(/Active talent config: RETAIL/);
    expect(lines).toMatch(/Legacy config \(system 45\): nil/);
    expect(lines).toMatch(/Talent tree 790: 3 nodes, 2 with points \(3 points\)/);
  });
});

/** Retail 12.1.5: a level 80 Death Knight, trait API present, no Legacy system, none of Forever's nodes. */
const retail = `
  WOW_PROJECT_ID = 1
  function UnitClass() return "Death Knight", "DEATHKNIGHT", 6 end
  function UnitRace() return "Human", "Human", 1 end
  function UnitSex() return 2 end
  function UnitLevel() return 80 end
  function GetBuildInfo() return "12.1.5", "70688", "Oct 28 2026", 120105 end
  function GetInventoryItemLink(unit, slot) if slot == 16 then return "|Hitem:19356::::::::80|h[Staff]|h" end end
  local bought = { [1] = 1, [2] = 0, [3] = 2 }
  C_ClassTalents = { GetActiveConfigID = function() return "RETAIL" end }
  C_Traits = {
    GetConfigIDBySystemID = function() return nil end,
    GetConfigInfo = function(config) return { treeIDs = { 790 } } end,
    GetTreeNodes = function(tree) return { 1, 2, 3 } end,
    GetNodeInfo = function(config, node)
      if bought[node] then return { ID = node, ranksPurchased = bought[node] } end
      return { ID = 0 }
    end,
  }`;
