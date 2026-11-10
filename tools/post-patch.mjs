// After a game patch: rebuild Data.lua from the website's game data, say what changed, check the TOC's interface
// number against the installed Forever client, and run the tests.
//
//   node tools/post-patch.mjs [--site <wow-4e\apps\web\public\data\v1>] [--game "D:\Games\World of Warcraft"] [--no-tests]
//
// Run the website's `npm run post-patch` first, so its data is for the new build. The site data path defaults as in
// make-data.mjs (the website repo beside the addons folder; TALENTS4E_SITE_DATA also sets it). The game folder
// defaults to WOW_DIR or D:\Games\World of Warcraft; its .build.info names each installed client's version, and
// Forever's (product wowf) gives the interface number: 1.60.1 -> 16001. Exits 1 when make-data or the tests fail.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { readData } from './data-lua.mjs';

const { values } = parseArgs({
  options: {
    site: { type: 'string' },
    game: { type: 'string' },
    tests: { type: 'boolean', default: true },
  },
  allowNegative: true,
});

const addon = resolve(import.meta.dirname, '..');
const dataFile = join(addon, 'Data.lua');
const tocFile = join(addon, 'Talents4e.toc');
const needsYou = [];
const report = ['## Talents-4Everyone'];
let failed = false;

/** The installed Forever client's version from the game folder's .build.info, or undefined. */
export function foreverVersion(gameDir) {
  const file = join(gameDir, '.build.info');
  if (!existsSync(file)) return undefined;
  const [head, ...rows] = readFileSync(file, 'utf8').split(/\r?\n/).filter(Boolean);
  const cols = head.split('|').map((c) => c.split('!')[0]);
  const at = (row, name) => row.split('|')[cols.indexOf(name)];
  const row = rows.find((r) => at(r, 'Product') === 'wowf');
  return row ? at(row, 'Version') : undefined;
}

/** "1.60.1.70790" -> 16001, as GetBuildInfo's fourth value. */
export const interfaceNumber = (version) => {
  const [major, minor, patch] = version.split('.').map(Number);
  return major * 10000 + minor * 100 + patch;
};

const before = existsSync(dataFile) ? readData(readFileSync(dataFile, 'utf8')) : { build: 'none', trees: new Map(), classes: new Map(), layouts: new Map() };

// 1. Data.lua from the site's data.
console.log('== Rebuilding Data.lua (tools/make-data.mjs) ==');
const make = spawnSync(process.execPath, [join(import.meta.dirname, 'make-data.mjs'), ...(values.site ? [values.site] : [])], { cwd: addon, encoding: 'utf8' });
process.stdout.write(`${make.stdout}${make.stderr}`);
if (make.status !== 0) { failed = true; needsYou.push('make-data.mjs failed; output above.'); }
const after = readData(readFileSync(dataFile, 'utf8'));

report.push('', before.build === after.build ? `Data.lua: build ${after.build} (unchanged)` : `Data.lua: build ${before.build} -> ${after.build}`);
const lines = [];
for (const [name, tree] of after.trees) {
  const was = before.trees.get(name) ?? new Map();
  for (const [talent, facts] of tree) {
    if (!was.has(talent)) lines.push(`${name}: new ${talent} (${facts})`);
    else if (was.get(talent) !== facts) lines.push(`${name}: ${talent}: ${was.get(talent)} -> ${facts}`);
  }
  for (const talent of was.keys()) if (!tree.has(talent)) lines.push(`${name}: removed ${talent}`);
}
for (const name of before.trees.keys()) if (!after.trees.has(name)) lines.push(`removed tree ${name}`);
report.push(...(lines.length > 0 ? lines.map((l) => `- ${l}`) : ['- No talent changes (names, ranks, grid, prerequisites, spells).']));
const newLayouts = [...after.layouts.keys()].filter((b) => !before.layouts.has(b));
if (newLayouts.length > 0) report.push(`- Layout fingerprints added for build ${newLayouts.join(', ')}`);
if (before.build !== after.build) {
  needsYou.push(`Data.lua moved to ${after.build}: players on the released version see "talent data is from game build ${before.build.split('.').pop()}" on export and call codes from the new build "newer", so this needs a release (version in the TOC and CHANGELOG.md).`);
}

// 2. TOC interface numbers.
const toc = readFileSync(tocFile, 'utf8');
const listed = (/^## Interface:\s*(.+)$/m.exec(toc)?.[1] ?? '').split(',').map((n) => Number(n.trim())).filter(Boolean);
const gameDir = values.game ?? process.env.WOW_DIR ?? 'D:\\Games\\World of Warcraft';
const version = foreverVersion(gameDir);
if (!version) {
  needsYou.push(`No Forever client in ${gameDir}\\.build.info: check the interface number in game with /dump select(4, GetBuildInfo()).`);
  report.push(`- TOC Interface: ${listed.join(', ')} (game version not found)`);
} else {
  const want = interfaceNumber(version);
  report.push(`- TOC Interface: ${listed.join(', ')}; installed Forever client ${version} wants ${want}`);
  if (!listed.includes(want)) needsYou.push(`Talents4e.toc lists Interface ${listed.join(', ')}, but the Forever client is ${version} (${want}): set "## Interface: ${want}" (README, CurseForge game version too).`);
  const others = listed.filter((n) => n !== want);
  if (others.length > 0) needsYou.push(`Talents4e.toc also lists ${others.join(', ')}: a release TOC lists Forever's number only (..\\CLAUDE.md, "TOC").`);
}

// 3. Tests.
if (values.tests) {
  const tests = join(addon, 'tests');
  if (!existsSync(join(tests, 'node_modules'))) {
    needsYou.push('Tests not run: run `npm install` in tests\\ first.');
  } else {
    console.log('\n== Tests (tests\\: npm test) ==');
    const run = spawnSync('npm test', { cwd: tests, shell: true, encoding: 'utf8' });
    const output = `${run.stdout}${run.stderr}`.replace(/\x1b\[[0-9;]*m/g, '');
    const summary = output.match(/^\s*Tests\s+.*$/m)?.[0]?.trim();
    report.push(`- Tests: ${run.status === 0 ? 'passed' : `FAILED (exit ${run.status})`}${summary ? ` · ${summary}` : ''}`);
    if (run.status !== 0) { failed = true; console.log(output.split('\n').slice(-40).join('\n')); needsYou.push('Tests failed: run `npm test` in tests\\ to see why.'); }
  }
}

report.push('', '### Needs you', ...(needsYou.length > 0 ? needsYou.map((n) => `- ${n}`) : ['- Nothing.']));
console.log(`\n${report.join('\n')}\n`);
process.exitCode = failed ? 1 : 0;
