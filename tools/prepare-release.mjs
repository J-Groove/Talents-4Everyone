// Gets a release ready after Data.lua changed: compares Data.lua with the last released version (the newest v* tag),
// raises "## Version:" in Talents4e.toc and writes the new version's section at the top of CHANGELOG.md. Commits
// nothing; the workspace's release-talents4e.ps1 does that after an in-game check.
//
//   node tools/prepare-release.mjs              next patch version (1.0.4 -> 1.0.5)
//   node tools/prepare-release.mjs --version 1.1.0
//   node tools/prepare-release.mjs --dry-run    print what it would write; changes nothing
//   node tools/prepare-release.mjs --force      rewrite the CHANGELOG section of a version prepared but not released yet
//
// Exits 0 with nothing written when there is nothing to release, 1 on a problem.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { movedLayouts, readData, talentChanges } from './data-lua.mjs';

const { values } = parseArgs({
  options: {
    version: { type: 'string' },
    'dry-run': { type: 'boolean', default: false },
    force: { type: 'boolean', default: false },
  },
});

const addon = resolve(import.meta.dirname, '..');
const tocFile = join(addon, 'Talents4e.toc');
const changelogFile = join(addon, 'CHANGELOG.md');
const siteData = process.env.TALENTS4E_SITE_DATA ?? join(addon, '..', '..', 'wow-4e', 'apps', 'web', 'public', 'data', 'v1');
const git = (...args) => execFileSync('git', args, { cwd: addon, encoding: 'utf8' }).trim();
const stop = (text) => { console.error(`Stopped: ${text}`); process.exit(1); };
const isVersion = (v) => /^\d+\.\d+\.\d+$/.test(v);

// The last release, as players have it.
let tag;
try { tag = git('describe', '--tags', '--abbrev=0', '--match', 'v*'); } catch { stop('no v* release tag found.'); }
const released = tag.replace(/^v/, '');
const before = readData(git('show', `${tag}:Data.lua`));
const after = readData(readFileSync(join(addon, 'Data.lua'), 'utf8'));

// Data.lua must be the site's data (post-patch.ps1 rebuilds it).
const siteClasses = join(siteData, 'classes.json');
if (existsSync(siteClasses)) {
  const siteBuild = JSON.parse(readFileSync(siteClasses, 'utf8')).build;
  if (siteBuild !== after.build) stop(`Data.lua is build ${after.build} but the site's data is ${siteBuild}. Run ..\\..\\post-patch.ps1 -NoRefresh first.`);
}

const changes = talentChanges(before, after);
const moved = movedLayouts(after, before.build, after.build);
console.log(`Last release: ${tag}, Data.lua build ${before.build}`);
console.log(`Now:          Data.lua build ${after.build}`);
if (before.build === after.build && changes.length === 0) {
  console.log(`\nData.lua is the same as in ${tag}: no data release needed.`);
  process.exit(0);
}
for (const c of changes) {
  console.log(`  ${c.tree}:`);
  for (const t of c.added) console.log(`    new      ${t}`);
  for (const t of c.gone) console.log(`    gone     ${t}`);
  for (const t of c.changed) console.log(`    changed  ${t.talent}: ${t.from} -> ${t.to}`);
}
if (changes.length === 0) console.log('  No talent changed (names, ranks, grid, prerequisites, spells).');
if (moved.length > 0) console.log(`  Layout moved for: ${moved.join(', ')} (older builds of these import with a warning)`);

// The version.
const toc = readFileSync(tocFile, 'utf8');
const tocVersion = /^## Version:\s*(\S+)/m.exec(toc)?.[1];
if (!tocVersion) stop('Talents4e.toc has no "## Version:" line.');
const changelog = readFileSync(changelogFile, 'utf8');
const topSection = /^## (\S+)/m.exec(changelog)?.[1];
let version;
if (tocVersion !== released) {
  // Already raised since the last release: prepared earlier, not released yet.
  if (!values.force) {
    console.log(`\nAlready prepared: the TOC says ${tocVersion} (last release ${released})${topSection === tocVersion ? ' and CHANGELOG.md has its section' : ''}.`);
    console.log('Check it, then run ..\\..\\release-talents4e.ps1. To write the CHANGELOG section again: --force.');
    process.exit(0);
  }
  version = values.version ?? tocVersion;
} else {
  const [major, minor, patch] = released.split('.').map(Number);
  version = values.version ?? `${major}.${minor}.${patch + 1}`;
}
if (!isVersion(version)) stop(`"${version}" is not a version like 1.0.5.`);
if (git('tag', '--list', `v${version}`)) stop(`tag v${version} already exists; pick another with --version.`);

// The CHANGELOG section, in the players' words.
const wrap = (text, first = '- ', rest = '  ') => {
  const lines = [];
  let line = first;
  for (const word of text.split(' ')) {
    if (line.length + word.length > 116 && line.trim() !== first.trim()) { lines.push(line.trimEnd()); line = rest; }
    line += `${word} `;
  }
  lines.push(line.trimEnd());
  return lines;
};
const list = (names) => names.join(', ');
const entry = [`## ${version}`];
if (changes.length === 0) {
  entry.push(...wrap(`Talent data for game build ${after.build}, the same as wow-4e.com. No talents changed, so your saved builds read the same; without this update the export box warns that the data is from an older game build.`));
} else {
  entry.push(...wrap(`Talent data for game build ${after.build}, the same as wow-4e.com:`));
  for (const c of changes) {
    const parts = [];
    if (c.added.length) parts.push(`new: ${list(c.added)}`);
    if (c.gone.length) parts.push(`gone: ${list(c.gone)}`);
    if (c.changed.length) parts.push(`changed: ${list(c.changed.map((t) => t.talent))}`);
    entry.push(...wrap(`${c.tree}: ${parts.join('; ')}.`, '  - ', '    '));
  }
}
if (moved.length > 0) {
  entry.push(...wrap(`Builds for ${list(moved)} made before this update import with a warning that their talents have moved: open them in the Build Calculator on wow-4e.com, fix them and import them again.`));
}
const section = `${entry.join('\n')}\n\n`;

console.log(`\nVersion: ${released} -> ${version}\n\nCHANGELOG.md section:\n\n${section}`);
if (values['dry-run']) { console.log('Dry run: nothing written.'); process.exit(0); }

writeFileSync(tocFile, toc.replace(/^## Version:\s*\S+/m, `## Version: ${version}`));
let rest = changelog;
if (tocVersion !== released && topSection === tocVersion) {
  // --force: drop the unreleased section being rewritten.
  rest = changelog.replace(/^## \S+\r?\n[\s\S]*?(?=^## |(?![\s\S]))/m, '');
}
writeFileSync(changelogFile, rest.replace(/^(# Changelog\r?\n\r?\n)/, `$1${section}`));
console.log(`Written: Talents4e.toc (Version ${version}) and CHANGELOG.md. Read the section over and edit the words if you like.`);
