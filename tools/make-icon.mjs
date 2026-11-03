// Writes Media\Icon.tga, the minimap button's and the addon list's icon, from the website's 4E monogram (Figma
// "4E — favicon master", node 13:3; wow-4e\apps\web\public\favicon.svg). The game reads TGA, not SVG or PNG, so the
// letters are drawn on a round leather disc to sit inside the minimap button's round border. Run it after the
// site's monogram changes:   node tools/make-icon.mjs [path to wow-4e]
// Uses sharp from the website repo's node_modules (npm install there first).
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';

const here = import.meta.dirname;
const site = resolve(process.argv[2] ?? join(here, '../../../wow-4e'));
const sharp = createRequire(join(site, 'package.json'))('sharp');

const SIZE = 64;
const favicon = readFileSync(join(site, 'apps/web/public/favicon.svg'), 'utf8');
// The favicon's letters, without its square tile, shrunk a little so their corners stay inside the circle.
const letters = favicon.match(/<g[\s\S]*<\/g>/)[0];
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">
<circle cx="80" cy="80" r="80" fill="#170E09"/>
<g transform="translate(80 80) scale(0.84) translate(-80 -80)">${letters}</g>
</svg>`;

const { data } = await sharp(Buffer.from(svg), { density: 300 })
  .resize(SIZE, SIZE)
  .ensureAlpha()
  .raw()
  .toBuffer({ resolveWithObject: true });

// Uncompressed 32-bit TGA, rows bottom to top, pixels as BGRA.
const header = Buffer.alloc(18);
header[2] = 2;
header.writeUInt16LE(SIZE, 12);
header.writeUInt16LE(SIZE, 14);
header[16] = 32;
header[17] = 8;
const pixels = Buffer.alloc(SIZE * SIZE * 4);
for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const from = (y * SIZE + x) * 4;
    const to = ((SIZE - 1 - y) * SIZE + x) * 4;
    pixels[to] = data[from + 2];
    pixels[to + 1] = data[from + 1];
    pixels[to + 2] = data[from];
    pixels[to + 3] = data[from + 3];
  }
}
mkdirSync(join(here, '../Media'), { recursive: true });
writeFileSync(join(here, '../Media/Icon.tga'), Buffer.concat([header, pixels]));
// A larger PNG to look at, in the git-ignored release folder.
mkdirSync(join(here, '../.release'), { recursive: true });
await sharp(Buffer.from(svg), { density: 300 }).resize(256, 256).png().toFile(join(here, '../.release/icon-preview.png'));
console.log('Wrote Media/Icon.tga (and .release/icon-preview.png, a larger copy for checking)');
