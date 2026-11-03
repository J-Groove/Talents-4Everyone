// Rules.lua must refuse and allow the same points as the website's talents.ts. When the website repo sits beside
// the addons folder, random builds for every class are checked against it; without it, the fixed cases still run.
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { beforeEach, describe, expect, it } from 'vitest';
import type { LuaEngine } from 'wasmoon';
import { addon, evaluate, evaluateAll } from './lua.ts';

const WEBSITE = join(import.meta.dirname, '../../../wow-4e');
const SITE_RULES = join(WEBSITE, 'packages/core/src/talents.ts');
const SITE_DATA = join(WEBSITE, 'apps/web/public/data/v1');
const hasSite = existsSync(SITE_RULES);

interface SiteTalent { row: number; col: number; ranks: unknown[]; requires?: { index: number; rank: number } }
interface Shape { row: number; max: number; requires?: { index: number; rank: number } }
type Step = { tree: number; index: number };

let lua: LuaEngine;
beforeEach(async () => {
  lua = await addon(['Data.lua', 'Order.lua', 'Rules.lua']);
});

// Arcane (tree 1): Wand Specialization 1 (2 ranks), Improved Channeling 2 (5), Arcane Resilience 3 (3),
// Arcane Subtlety 4 (2, row 2), Arcane Focus 6 (5, row 2), Arcane Meditation needs index 6 at rank 5.
const order = (steps: string) => `{ ${steps.split(' ').map((s) => { const [t, i] = s.split(':'); return `{ tree = ${t}, index = ${i} }`; }).join(', ')} }`;

describe('Rules.lua', () => {
  it('opens a row after 5 points above it and refuses with the site\'s words', async () => {
    const out = await evaluateAll(lua, [
      'ns.Rules.AddBlock(ns.Rules.Shapes(8), {}, 5, 1, 4)',
      'ns.Rules.AddBlock(ns.Rules.Shapes(8), { { 0, 5 } }, 6, 1, 4) or "ok"',
      'ns.Rules.AddBlock(ns.Rules.Shapes(8), { { 0, 5 } }, 5, 1, 4)',
      'ns.Rules.AddBlock(ns.Rules.Shapes(8), { { 2 } }, 5, 1, 1)',
      'ns.Rules.BlockText(8, 1, 4, "row-locked")',
      'ns.Rules.BlockText(8, 1, 4, "row-locked", 12)',
    ]);
    expect(out).toEqual(['row-locked', 'ok', 'no-points', 'max-rank',
      'Arcane Subtlety needs 5 points in Arcane above it first.',
      'Arcane Subtlety cannot be taken at level 12: it needs 5 points in Arcane above it first.']);
  });

  it('adds at the end and removes a step only when the rest still holds', async () => {
    const five = order('1:2 1:2 1:2 1:2 1:2');
    const out = await evaluateAll(lua, [
      `#ns.Rules.AddStep(ns.Rules.Shapes(8), ${five}, 6, 1, 4)`,
      `select(2, ns.Rules.AddStep(ns.Rules.Shapes(8), ${five}, 5, 1, 4))`,
      // Removing an early Improved Channeling rank would leave Arcane Subtlety at its turn with 4 points above.
      `select(2, ns.Rules.RemoveStep(ns.Rules.Shapes(8), ${order('1:2 1:2 1:2 1:2 1:2 1:4')}, 2)).step`,
      `#ns.Rules.RemoveStep(ns.Rules.Shapes(8), ${order('1:2 1:2 1:2 1:2 1:2 1:4 1:1')}, 7)`,
      `ns.Rules.LastStep(${order('1:2 1:1 1:2 1:3')}, 1, 2)`,
    ]);
    expect(out).toEqual(['6', 'no-points', '5', '6', '3']);
  });
});

describe.skipIf(!hasSite)('against the website', () => {
  it('Data.lua carries the same rows, columns and prerequisites', async () => {
    for (const file of readdirSync(join(SITE_DATA, 'talents'))) {
      const json = JSON.parse(readFileSync(join(SITE_DATA, 'talents', file), 'utf8'));
      const want = json.trees.map((t: { talents: SiteTalent[] }) => t.talents
        .map((x) => `${x.row + 1},${x.col + 1},${x.requires ? `${x.requires.index + 1}:${x.requires.rank}` : ''}`).join(' ')).join('/');
      const got = await evaluate<string>(lua, `(function() local out = {}
        for t, tree in ipairs(ns.Data.classes[${json.classId}]) do
          local line = {}
          for i, x in ipairs(tree.talents) do
            line[i] = x.row .. "," .. x.col .. "," .. (x.req and (x.req.index .. ":" .. x.req.rank) or "")
          end
          out[t] = table.concat(line, " ")
        end
        return table.concat(out, "/") end)()`);
      expect(got, `${file}: run node tools/make-data.mjs`).toBe(want);
    }
  });

  it('agrees with talents.ts on random builds and orders for every class', async () => {
    const site = await import(SITE_RULES);
    // A small seeded random, so a failure can be run again.
    let seed = 4242;
    const rand = (n: number) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n; };

    for (const file of readdirSync(join(SITE_DATA, 'talents'))) {
      const json = JSON.parse(readFileSync(join(SITE_DATA, 'talents', file), 'utf8'));
      const shapes: Shape[][] = json.trees.map((t: { talents: SiteTalent[] }) =>
        t.talents.map((x) => ({ row: x.row, max: x.ranks.length, requires: x.requires })));
      const exprs: string[] = [];
      const want: string[] = [];
      const luaRanks = (ranks: number[][]) => `{ ${ranks.map((t) => `{ ${t.join(', ')} }`).join(', ')} }`;
      const luaOrder = (o: Step[]) => `{ ${o.map((s) => `{ tree = ${s.tree + 1}, index = ${s.index + 1} }`).join(', ')} }`;
      const line = (o: Step[]) => o.map((s) => `${s.tree + 1}:${s.index + 1}`).join(' ');
      const S = `ns.Rules.Shapes(${json.classId})`;

      for (let n = 0; n < 40; n++) {
        // Random ranks, mostly legal: fill random talents through the site's rules, then sometimes break one.
        let ranks: number[][] = shapes.map((s) => s.map(() => 0));
        const points = rand(52);
        for (let k = 0; k < 400 && site.totalSpent(ranks) < points; k++) {
          const t = rand(shapes.length);
          ranks = site.addPoint(shapes, ranks, points, t, rand(shapes[t]!.length));
        }
        if (rand(3) === 0) { const t = rand(shapes.length); ranks[t]![rand(shapes[t]!.length)] = 1; }
        const available = rand(52);
        for (let t = 0; t < shapes.length; t++) {
          for (let i = 0; i < shapes[t]!.length; i++) {
            if (rand(4) !== 0) continue;
            exprs.push(`ns.Rules.AddBlock(${S}, ${luaRanks(ranks)}, ${available}, ${t + 1}, ${i + 1}) or "-"`);
            want.push(site.addBlock(shapes, ranks, available, t, i) ?? '-');
            exprs.push(`ns.Rules.RemoveBlock(${S}, ${luaRanks(ranks)}, ${t + 1}, ${i + 1}) or "-"`);
            want.push(site.removeBlock(shapes, ranks, t, i) ?? '-');
          }
        }
        // Orders: the default order, a shuffled one (its problem and its legal order).
        const def: Step[] = site.defaultOrder(shapes, ranks);
        exprs.push(`(function() local o = ns.Rules.DefaultOrder(${S}, ${luaRanks(ranks)}); local out = {}
          for i, s in ipairs(o) do out[i] = s.tree .. ":" .. s.index end; return table.concat(out, " ") end)()`);
        want.push(line(def));
        const shuffled = [...def];
        for (let i = shuffled.length - 1; i > 0; i--) { const j = rand(i + 1); [shuffled[i], shuffled[j]] = [shuffled[j]!, shuffled[i]!]; }
        const problem = site.orderProblem(shapes, shuffled);
        exprs.push(`(function() local p = ns.Rules.OrderProblem(${S}, ${luaOrder(shuffled)})
          return p and (p.step .. " " .. p.tree .. ":" .. p.index .. " " .. p.block) or "-" end)()`);
        want.push(problem ? `${problem.step + 1} ${problem.talent.tree + 1}:${problem.talent.index + 1} ${problem.block}` : '-');
        exprs.push(`(function() local o = ns.Rules.LegalOrder(${S}, ${luaOrder(shuffled)}); local out = {}
          for i, s in ipairs(o) do out[i] = s.tree .. ":" .. s.index end; return table.concat(out, " ") end)()`);
        want.push(line(site.legalOrder(shapes, shuffled)));
      }
      // A fresh engine per class: wasmoon tires of long runs on one engine.
      lua = await addon(['Data.lua', 'Order.lua', 'Rules.lua']);
      const got = await evaluateAll(lua, exprs);
      got.forEach((g, k) => expect(g, `${file}: ${exprs[k]!.slice(0, 160)}`).toBe(want[k]));
    }
  });
});
