// Empacota as texturas PBR da Poly Haven (CC0) em dois atlas verticais para o jogo:
//   pbr_alb.jpg  — cor (sRGB), uma camada de 512 px por material
//   pbr_nrm.jpg  — R,G = normal (OpenGL), B = rugosidade
// e pbr.json com a ordem das camadas, a escala (tiles por repetição) e o brilho médio de cada uma.
// Uso: node tools/assetpipe/textures.mjs <pasta polyhaven> <pasta de saída>
import sharp from 'sharp';
import path from 'node:path';
import fs from 'node:fs';

const [SRC, OUT] = process.argv.slice(2);
const S = 512, TILE_M = 1.56;   // um tile do jogo tem ~1,56 m (pessoa de 1,75 m = 1,12 tile)
const LAYERS = ['asphalt_02', 'concrete_pavers_02', 'granite_tile', 'leafy_grass', 'weathered_planks',
  'concrete_wall_008', 'concrete_panels', 'red_bricks_04', 'plastered_wall_05', 'worn_corrugated_iron', 'tarred_gravel'];
const SIZE_M = { asphalt_02: 3, concrete_pavers_02: 2, granite_tile: 2.3, leafy_grass: 2, weathered_planks: 2, concrete_wall_008: 2.71,
  concrete_panels: 8, red_bricks_04: 2.5, plastered_wall_05: 2, worn_corrugated_iron: 1.8, tarred_gravel: 2.2 };

const raw = async (f, ch) => (await sharp(f).resize(S, S).removeAlpha().toColourspace(ch === 1 ? 'b-w' : 'srgb').raw().toBuffer());
const lin = c => { c /= 255; return c <= .04045 ? c / 12.92 : Math.pow((c + .055) / 1.055, 2.4); };

const alb = Buffer.alloc(S * S * 3 * LAYERS.length), nrm = Buffer.alloc(S * S * 3 * LAYERS.length), meta = [];
for (const [i, name] of LAYERS.entries()) {
  const d = path.join(SRC, name);
  const a = await raw(path.join(d, 'diff.jpg'), 3), n = await raw(path.join(d, 'nor.jpg'), 3), r = await raw(path.join(d, 'rough.jpg'), 1);
  a.copy(alb, i * S * S * 3);
  let lum = 0, rs = 0;
  for (let p = 0; p < S * S; p++) {
    const o = i * S * S * 3 + p * 3;
    nrm[o] = n[p * 3]; nrm[o + 1] = n[p * 3 + 1]; nrm[o + 2] = r[p];
    lum += .2126 * lin(a[p * 3]) + .7152 * lin(a[p * 3 + 1]) + .0722 * lin(a[p * 3 + 2]); rs += r[p] / 255;
  }
  meta.push({ name, scale: +(TILE_M / SIZE_M[name]).toFixed(4), lum: +(lum / (S * S)).toFixed(4), rough: +(rs / (S * S)).toFixed(3) });
}
const opt = { width: S, height: S * LAYERS.length, channels: 3 };
await sharp(alb, { raw: opt }).jpeg({ quality: 84, chromaSubsampling: '4:2:0', mozjpeg: true }).toFile(path.join(OUT, 'pbr_alb.jpg'));
await sharp(nrm, { raw: opt }).jpeg({ quality: 90, chromaSubsampling: '4:4:4', mozjpeg: true }).toFile(path.join(OUT, 'pbr_nrm.jpg'));
fs.writeFileSync(path.join(OUT, 'pbr.json'), JSON.stringify({ size: S, layers: meta }, null, 1));
for (const f of ['pbr_alb.jpg', 'pbr_nrm.jpg']) console.log(f, (fs.statSync(path.join(OUT, f)).size / 1024).toFixed(0) + ' KB');
console.log(meta.map(m => `${m.name} scale ${m.scale} lum ${m.lum} rough ${m.rough}`).join('\n'));
