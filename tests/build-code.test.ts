// Core.lua must write and read build codes exactly as the website does. When the website repo sits beside the
// addons folder, every case is checked against its build-code.ts; without it, the fixed expected codes still run.
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { LuaEngine } from 'wasmoon';
import { addon, evaluate, evaluateAll } from './lua.ts';

const WEBSITE = join(import.meta.dirname, '../../../wow-4e');
const SITE_CODE = join(WEBSITE, 'packages/core/src/build-code.ts');
const SITE_DATA = join(WEBSITE, 'apps/web/public/data/v1');
const hasSite = existsSync(SITE_CODE);

/** The website's Build shape: trees and indexes 0-based. */
interface Build {
  gameBuild: number; classId: number; raceId: number; sex: 0 | 1; level: number;
  talents: number[][]; order: { tree: number; index: number }[];
  gear: Record<number, { item: number; enchant?: number; suffix?: number }>; legacy: number[][];
}

const luaTrees = (trees: number[][]) => `{ ${trees.map((t) => `{ ${t.join(', ')} }`).join(', ')} }`;
/** A website build as a Lua table literal (1-based trees and indexes). */
function toLua(b: Build): string {
  const order = b.order.map((s) => `{ tree = ${s.tree + 1}, index = ${s.index + 1} }`).join(', ');
  const gear = Object.entries(b.gear)
    .map(([slot, p]) => `[${slot}] = { item = ${p.item}${p.enchant ? `, enchant = ${p.enchant}` : ''}${p.suffix ? `, suffix = ${p.suffix}` : ''} }`)
    .join(', ');
  return `{ gameBuild = ${b.gameBuild}, classId = ${b.classId}, raceId = ${b.raceId}, sex = ${b.sex}, level = ${b.level},
    talents = ${luaTrees(b.talents)}, order = { ${order} }, gear = { ${gear} }, legacy = ${luaTrees(b.legacy)} }`;
}

/** The same one-line form as canonical() in lua.ts. */
function canonical(b: Build): string {
  const trees = (list: number[][]) => list.map((t) => t.join(',')).join('/');
  const gear = Object.keys(b.gear).map(Number).sort((x, y) => x - y)
    .map((slot) => { const p = b.gear[slot]!; return `${slot}:${p.item}:${p.enchant ?? ''}:${p.suffix ?? ''}`; });
  return [b.gameBuild, b.classId, b.raceId, b.sex, b.level, trees(b.talents),
    b.order.map((s) => `${s.tree + 1}:${s.index + 1}`).join(' '), gear.join(' '), trees(b.legacy)].join('|');
}

const mage: Build = {
  gameBuild: 70532, classId: 8, raceId: 7, sex: 1, level: 60,
  talents: [[2, 3, 0, 5, 0, 0], [], [0, 0, 1]], order: [],
  gear: { 1: { item: 16914, enchant: 1503 }, 16: { item: 19356 }, 5: { item: 16916, suffix: 87 } },
  legacy: [[0, 5, 1], [], [2]],
};
const ordered: Build = {
  ...mage, sex: 0, talents: [[0, 2], [], [1]],
  order: [{ tree: 0, index: 1 }, { tree: 2, index: 0 }, { tree: 0, index: 1 }],
};
const fresh: Build = { gameBuild: 0, classId: 1, raceId: 2, sex: 0, level: 1, talents: [[], [0], []], order: [], gear: {}, legacy: [[0]] };

let lua: LuaEngine;
beforeEach(async () => {
  lua = await addon(['Core.lua']);
});

const encode = (b: Build) => evaluate<string>(lua, `ns.Core.EncodeBuild(${toLua(b)})`);
const decode = (code: string) => evaluate<string>(lua, `canonical(ns.Core.DecodeBuild(${JSON.stringify(code)}))`);
const decodeError = (code: string) => evaluate<string | null>(lua, `select(2, ns.Core.TryDecode(${JSON.stringify(code)}))`);

describe('Core.lua build codes', () => {
  it('writes the "3." form like the website', async () => {
    expect(await encode(mage)).toBe('3.70532.8.7.1.60.2305__001..1~d1u~15r_5~d1w~~2f_g~exo.051__2');
    expect(await encode(ordered)).toBe('3.70532.8.7.0.60..012801.1~d1u~15r_5~d1w~~2f_g~exo.051__2');
    expect(await encode(fresh)).toBe('3.0.1.2.0.1....');
  });

  it('leaves out an order that no longer adds up to the talents', async () => {
    expect(await encode({ ...ordered, talents: [[0, 3]] })).toBe('3.70532.8.7.0.60.03..1~d1u~15r_5~d1w~~2f_g~exo.051__2');
  });

  it('reads back what it writes', async () => {
    const again = (code: string) => evaluate<string>(lua, `ns.Core.EncodeBuild(ns.Core.DecodeBuild(${JSON.stringify(code)}))`);
    for (const b of [mage, ordered, fresh]) {
      const code = await encode(b);
      expect(await again(code)).toBe(code);
    }
    expect(await decode(await encode(ordered))).toBe('70532|8|7|0|60|0,2//1|1:2 3:1 1:2|1:16914:1503: 5:16916::87 16:19356::|0,5,1//2');
  });

  it('reads the older forms as Body 1 with no order', async () => {
    expect(await decode('70532.8.7.60.2305__001.1~d1u.05')).toBe('70532|8|7|0|60|2,3,0,5//0,0,1||1:16914::|0,5');
    expect(await decode('2.8.7.60.2305.1~d1u.05')).toBe('0|8|7|0|60|2,3,0,5||1:16914::|0,5');
    expect(await decode('1.8.7.60.2305__5301.1~d1u')).toBe('0|8|7|0|60|2,3,0,5//5,3,0,1||1:16914::|');
  });

  it('refuses bad codes', async () => {
    for (const code of ['', '4.1.2', '3.70532.8.7.0.60.1.01...', '3.70532.8.7.0.60...1~2~3~4~5.', '1.8.7.60..1~2~3',
      '3.70532.8.7.2.60.....', '3.70532.8.7.0.61.....', '3.70532.8.7.0.60...1~1_1~2.', '3.70532.8.7.0.60..0.', 'x'.repeat(513)]) {
      expect(await decodeError(code), code).toMatch(/could not be read|No build code/);
    }
  });

  it('finds the code in pasted text', async () => {
    const find = (text: string) => evaluate<string | null>(lua, `ns.Core.CodeFromText(${JSON.stringify(text)})`);
    expect(await find('https://wow-4e.com/builds/new#b=3.70532.8.7.0.60.....')).toBe('3.70532.8.7.0.60.....');
    expect(await find('  3.0.1.2.0.1.....  ')).toBe('3.0.1.2.0.1.....');
    expect(await find('#b=3.0.1.2.0.1...1%7Ed1u.')).toBe('3.0.1.2.0.1...1~d1u.');
    expect(await find('hello')).toBeNull();
  });

  it('reads item links', async () => {
    const parse = (link: string) => evaluate<string>(lua,
      `(function(a, b, c) return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) end)(ns.Core.ParseItemLink(${JSON.stringify(link)}))`);
    expect(await parse('|cffa335ee|Hitem:16914:1503:0:0:0:0:87:0:60:0:0:0:0|h[Netherwind Crown]|h|r')).toBe('16914 1503 87');
    expect(await parse('|cffffffff|Hitem:19356::::::::60:::::|h[Staff]|h|r')).toBe('19356 nil nil');
    expect(await parse('|Hitem:15000:0:0:0:0:0:-12:0|h[x]|h')).toBe('15000 nil nil');
    expect(await parse('no link')).toBe('nil nil nil');
  });

  it('turns UnitSex into the body type', async () => {
    expect(await evaluate(lua, 'ns.Core.SexFromUnitSex(2) .. ns.Core.SexFromUnitSex(3) .. ns.Core.SexFromUnitSex(1)')).toBe('010');
  });
});

describe.skipIf(!hasSite)('against the website', () => {
  let site: {
    encodeBuild(b: Build): string; decodeBuild(code: string): Build; ranksFromOrder(o: Build['order']): number[][];
  };
  beforeAll(async () => {
    site = await import(SITE_CODE);
  });

  // Random builds, with a seeded generator so a failure can be repeated.
  function* randomBuilds(count: number): Generator<Build> {
    let seed = 42;
    const next = (n: number) => { seed = (seed * 1103515245 + 12345) % 2 ** 31; return seed % n; };
    for (let i = 0; i < count; i++) {
      const trees = (n: number) => Array.from({ length: next(n + 1) }, () => Array.from({ length: next(20) }, () => next(10)));
      const order = next(2) ? Array.from({ length: 1 + next(50) }, () => ({ tree: next(3), index: next(40) })) : [];
      const gear: Build['gear'] = {};
      for (let s = 0; s < next(20); s++) {
        gear[1 + next(19)] = { item: 1 + next(2_000_000), ...(next(2) ? { enchant: 1 + next(50_000) } : {}), ...(next(3) ? {} : { suffix: 1 + next(3_000) }) };
      }
      yield {
        gameBuild: next(4) ? 70000 + next(1000) : 0, classId: 1 + next(11), raceId: 1 + next(40), sex: next(2) as 0 | 1,
        level: 1 + next(60), talents: order.length && next(4) ? site.ranksFromOrder(order) : trees(3), order, gear, legacy: trees(3),
      };
    }
  }

  it('writes the same code as build-code.ts', async () => {
    const builds: Build[] = [];
    const expected: string[] = [];
    for (const b of [mage, ordered, fresh, ...randomBuilds(300)]) {
      try { expected.push(site.encodeBuild(b)); } catch { continue; } // only builds the site accepts
      builds.push(b);
    }
    expect(builds.length).toBeGreaterThan(100);
    const got = await evaluateAll(lua, builds.map((b) => `ns.Core.EncodeBuild(${toLua(b)})`));
    got.forEach((code, i) => expect(code, toLua(builds[i]!)).toBe(expected[i]));
  });

  it('reads codes the same way as build-code.ts', async () => {
    const codes: string[] = [];
    for (const b of randomBuilds(300)) {
      try { codes.push(site.encodeBuild(b)); } catch { continue; }
    }
    const got = await evaluateAll(lua, codes.map((c) => `canonical(ns.Core.DecodeBuild(${JSON.stringify(c)}))`));
    got.forEach((line, i) => expect(line, codes[i]).toBe(canonical(site.decodeBuild(codes[i]!))));
  });

  it('refuses the codes build-code.ts refuses', async () => {
    const codes = ['3.70532.8.7.0.60.1.01...', '3.70532.8.7.0.60.ab....', '3.70532.8.7.0.60...1~0.', '3.70532.8.7.0.60.' + '1'.repeat(41) + '....',
      '3.70532.8.7.0.60..' + '01'.repeat(52) + '..', '3.9999.8.7.0.60.....', '3.70532.0.7.0.60.....', '3.70532.8.7.0.60...k~1.', '2.8.7.60..1~2~3.'];
    const got = await evaluateAll(lua, codes.map((c) => `ns.Core.DecodeBuild(${JSON.stringify(c)}) and "ok"`));
    codes.forEach((code, i) => {
      let siteRefuses = false;
      try { site.decodeBuild(code); } catch { siteRefuses = true; }
      expect(got[i]!.startsWith('ERROR'), code).toBe(siteRefuses);
    });
  });

  it('Data.lua lists the same talents and Legacy perks, in the same order, as the site data', async () => {
    const data = await addon(['Data.lua']);
    const nodes = (expr: string) => evaluate<string>(data, `(function() local t = ${expr}; local out = {}
      for i, tree in ipairs(t) do out[i] = tree.id .. "=" .. table.concat(tree.nodes, ",") end
      return table.concat(out, " ") end)()`);
    const line = (trees: { id: number; talents?: { id: number }[]; perks?: { id: number }[] }[]) =>
      trees.map((t) => `${t.id}=${(t.talents ?? t.perks)!.map((n) => n.id).join(',')}`).join(' ');
    for (const file of readdirSync(join(SITE_DATA, 'talents'))) {
      const json = JSON.parse(readFileSync(join(SITE_DATA, 'talents', file), 'utf8'));
      expect(await nodes(`ns.Data.classes[${json.classId}]`), `${file}: run node tools/make-data.mjs`).toBe(line(json.trees));
    }
    const legacy = JSON.parse(readFileSync(join(SITE_DATA, 'legacy.json'), 'utf8'));
    expect(await nodes('ns.Data.legacy'), 'run node tools/make-data.mjs').toBe(line(legacy.trees));
  });
});
