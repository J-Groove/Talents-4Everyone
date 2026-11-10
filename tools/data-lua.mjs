// Reads the facts the release tools compare out of Data.lua's text (written by make-data.mjs).
// Used by post-patch.mjs and prepare-release.mjs.

/**
 * build: Data.lua's game build. trees: "Class Tree" -> Map(talent name -> "ranks, row, col, req, spell").
 * classes: class id -> name. layouts: Map(short build -> Map(class id or "legacy" -> fingerprint)).
 */
export function readData(text) {
  const trees = new Map();
  const classes = new Map();
  const layouts = new Map();
  let className = '';
  let tree = null;
  for (const line of text.split(/\r?\n/)) {
    const cls = /^ {4}\[(\d+)\] = \{ name = "([^"]+)", icon = "classicon_/.exec(line);
    if (cls) { className = cls[2]; classes.set(cls[1], cls[2]); continue; }
    const layout = /^ {4}\[(\d+)\] = \{ (.*) \},?$/.exec(line);
    if (layout && /= "[0-9a-f]+"/.test(layout[2])) {
      const prints = new Map([...layout[2].matchAll(/(?:\[(\d+)\]|(legacy)) = "([0-9a-f]+)"/g)].map((m) => [m[1] ?? m[2], m[3]]));
      layouts.set(layout[1], prints);
      continue;
    }
    const t = /^ {6}\{ id = \d+, name = "([^"]+)"/.exec(line);
    if (t) { tree = new Map(); trees.set(`${className} ${t[1]}`, tree); continue; }
    const talent = /^ {10}\{ name = "((?:[^"\\]|\\.)*)", icon = "[^"]*", ranks = (\d+), spell = (\d+), row = (\d+), col = (\d+)(?:, req = \{ index = (\d+), rank = (\d+) \})?/.exec(line);
    if (talent && tree) tree.set(talent[1], `${talent[2]} ranks, row ${talent[4]} col ${talent[5]}${talent[6] ? `, needs #${talent[6]} at ${talent[7]}` : ''}, spell ${talent[3]}`);
  }
  const build = /build = "([^"]+)"/.exec(text)?.[1] ?? '?';
  return { build, trees, classes, layouts };
}

/** Per tree, the talents new, gone and changed between two readData results. */
export function talentChanges(before, after) {
  const out = [];
  for (const [name, tree] of after.trees) {
    const was = before.trees.get(name) ?? new Map();
    const added = [...tree.keys()].filter((t) => !was.has(t));
    const gone = [...was.keys()].filter((t) => !tree.has(t));
    const changed = [...tree.keys()].filter((t) => was.has(t) && was.get(t) !== tree.get(t))
      .map((t) => ({ talent: t, from: was.get(t), to: tree.get(t) }));
    if (added.length || gone.length || changed.length) out.push({ tree: name, added, gone, changed });
  }
  for (const name of before.trees.keys()) {
    if (!after.trees.has(name)) out.push({ tree: name, added: [], gone: [...before.trees.get(name).keys()], changed: [] });
  }
  return out;
}

/** Classes (names) and "Legacy" whose talent layout differs between two builds' fingerprints. */
export function movedLayouts(data, fromBuild, toBuild) {
  const from = data.layouts.get(String(fromBuild).split('.').pop());
  const to = data.layouts.get(String(toBuild).split('.').pop());
  if (!from || !to) return [];
  return [...to.keys()].filter((k) => from.get(k) !== to.get(k))
    .map((k) => (k === 'legacy' ? 'Legacy perks' : data.classes.get(k) ?? `class ${k}`));
}
