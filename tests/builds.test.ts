// Builds.lua: the saved builds list and which build each character follows.
import { expect, it } from 'vitest';
import { addon, evaluateAll } from './lua.ts';

const FILES = ['Core.lua', 'Data.lua', 'Builds.lua'];
// Mage (class 8) from game build 70532, older than Data.lua's: one with ranks only, one with a talent order.
const MAGE_RANKS = '3.70532.8.7.1.60.2305__001..1~d1u~15r_5~d1w~~2f_g~exo.051__2';
const MAGE_ORDER = 'https://wow-4e.com/builds/new#b=3.70532.8.7.0.60..012801.1~d1u~15r_5~d1w~~2f_g~exo.051__2';
// A level 1 Warrior (class 1) with no game build and nothing in it.
const WARRIOR = '3.0.1.2.0.1....';

async function run(setup: string, expressions: string[]) {
  const lua = await addon(FILES, `db = {}\n`);
  await lua.doString(`B = ns.Builds; B.Init(db)\n${setup}`);
  return evaluateAll(lua, expressions);
}

it('adds builds with a default or given name, stores the code alone, and counts ids up', async () => {
  const out = await run(`
    a = B.Add(db, ${JSON.stringify(MAGE_ORDER)}, "", 100)
    b = B.Add(db, ${JSON.stringify(WARRIOR)}, "  My warrior  ", 200)
    bad, problem = B.Add(db, "nonsense", "x", 300)`, [
    'a.id', 'a.name', 'a.code', 'a.classId', 'a.added', 'b.id', 'b.name', 'b.classId', 'db.nextId', '#db.builds',
    'tostring(bad)', 'problem',
  ]);
  expect(out.slice(0, 10)).toEqual(['1', 'Mage, Arcane', '3.70532.8.7.0.60..012801.1~d1u~15r_5~d1w~~2f_g~exo.051__2', '8', '100',
    '2', 'My warrior', '1', '3', '2']);
  expect(out[10]).toBe('nil');
  expect(out[11]).toMatch(/No build code|could not be read/);
});

it('stops at 20 builds and cuts long names', async () => {
  const out = await run(`
    for i = 1, 20 do B.Add(db, ${JSON.stringify(WARRIOR)}, string.rep("n", 50), i) end
    full, problem = B.Add(db, ${JSON.stringify(WARRIOR)}, "", 21)`, ['#db.builds', 'tostring(full)', 'problem', '#db.builds[1].name']);
  expect(out).toEqual(['20', 'nil', 'You have 20 saved builds. Delete one to make room.', '40']);
});

it('names a build by class and main tree, and describes it', async () => {
  const out = await run(`
    r = ns.Core.TryDecode(${JSON.stringify(MAGE_RANKS)})
    w = ns.Core.TryDecode(${JSON.stringify(WARRIOR)})
    o = ns.Core.TryDecode(${JSON.stringify(MAGE_ORDER)})`, [
    'B.DefaultName(w)', 'B.Detail(r, 8)', 'B.Detail(o, 1)', 'B.Detail(w, 1)', 'select(2, B.Trees(r))', 'B.Trees(r)[2].points',
  ]);
  expect(out[0]).toBe('Warrior');
  expect(out[1]).toMatch(/^Ranks only · \d+ points · game build 70532$/);
  expect(out[2]).toMatch(/^For a Mage · Talent order · \d+ points? · game build 70532$/);
  expect(out[3]).toBe('Ranks only · 0 points');
});

it('warns about another class, an older game version, and a build with no order', async () => {
  const out = await run(`
    function kinds(list) local k = {}; for i, w in ipairs(list) do k[i] = w.kind .. ": " .. w.text end; return table.concat(k, " | ") end
    r = ns.Core.TryDecode(${JSON.stringify(MAGE_RANKS)})
    o = ns.Core.TryDecode(${JSON.stringify(MAGE_ORDER)})`, ['kinds(B.Warnings(r, 1))', 'kinds(B.Warnings(o, 8))']);
  expect(out[0]).toMatch(/^Warning: This build is for a Mage\. .* \| Warning: Made for an older game version \(70532\)\. .* \| Info: This build has ranks only/);
  expect(out[1]).toMatch(/^Warning: Made for an older game version \(70532\)\.[^|]*$/);
});

it('calls a build old only when its class layout moved since, and warns about a newer game version', async () => {
  const out = await run(`
    function b(classId, gameBuild, talents, legacy)
      return { classId = classId, gameBuild = gameBuild, talents = talents or { { 1 }, {}, {} }, legacy = legacy or {}, order = { 1 } }
    end
    function age(x) return tostring(B.GameVersionAge(x)) end
    function warn(x) local w = B.Warnings(x, x.classId)[1]; return w and w.text or "" end`, [
    'age(b(1, 70707))', // Warrior: same layout in 70707 and today's data
    'age(b(2, 70707))', // Paladin: a talent removed since
    'age(b(2, 70707, { {}, {}, {} }))', // Paladin with no talents spent: nothing to misplace
    'age(b(2, 0))', // no game build recorded
    'age(b(1, 99999))', // newer than the data knows
    'age(b(1, 60000))', // older than any layout the data knows
    'warn(b(2, 70707))',
    'warn(b(1, 99999))',
  ]);
  expect(out.slice(0, 6)).toEqual(['nil', 'older', 'nil', 'nil', 'newer', 'older']);
  expect(out[6]).toMatch(/^Made for an older game version \(70707\)\. Some talents have moved since/);
  expect(out[7]).toMatch(/^Made for a newer game version \(99999\) than this addon knows\..*update Talents-4Everyone\.$/);
});

it('renames, follows only its own class, and forgets followers when deleted', async () => {
  const out = await run(`
    a = B.Add(db, ${JSON.stringify(MAGE_ORDER)}, "", 1)
    w = B.Add(db, ${JSON.stringify(WARRIOR)}, "", 2)
    renamed = B.Rename(db, a.id, " Frost leveling ")
    kept = B.Rename(db, a.id, "   ")
    okMage = B.Follow(db, "Jeff-Realm", a.id, 8)
    noWarrior, why = B.Follow(db, "Jeff-Realm", w.id, 8)
    B.Follow(db, "Grunt-Realm", w.id, 1)
    newName = db.builds[1].name
    followed = B.Followed(db, "Jeff-Realm").name
    deleted = B.Delete(db, a.id)`, [
    'renamed', 'kept', 'newName', 'okMage', 'tostring(noWarrior)', 'why', 'followed', 'deleted',
    'tostring(B.Followed(db, "Jeff-Realm"))', 'B.Followed(db, "Grunt-Realm").id', '#db.builds', 'B.Delete(db, 99)',
  ]);
  expect(out).toEqual(['true', 'false', 'Frost leveling', 'true', 'false', 'Log in on a Warrior to follow this build.',
    'Frost leveling', 'true', 'nil', '2', '1', 'false']);
});
