// Writes Media\Icon.tga, the minimap button's and the addon list's icon, from the website's 4E crest (Figma
// "4E/Crest"; wow-4e\apps\web\public\img\brand\crest.svg: bronze ring, teal disc, cream 4, gold E), round already,
// so it sits inside the minimap button's round border. The game reads TGA, not SVG or PNG. Run it after the site's
// crest changes:   node tools/make-icon.mjs [path to wow-4e]
// Uses sharp from the website repo's node_modules (npm install there first).
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';

const here = import.meta.dirname;
const site = resolve(process.argv[2] ?? join(here, '../../../wow-4e'));
const sharp = createRequire(join(site, 'package.json'))('sharp');

const SIZE = 64;
const svg = readFileSync(join(site, 'apps/web/public/img/brand/crest.svg'), 'utf8');

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
