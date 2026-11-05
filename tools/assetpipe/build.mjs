// Empacota os modelos CC0 baixados (Quaternius, Kenney) em GLBs compactos para o jogo.
// Uso: node tools/assetpipe/build.mjs <pasta assets_dl> <pasta de saída>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTMeshoptCompression } from '@gltf-transform/extensions';
import { mergeDocuments, prune, dedup, weld, quantize, resample, unpartition } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptDecoder } from 'meshoptimizer';
import path from 'node:path';
import fs from 'node:fs';

const [SRC, OUT] = process.argv.slice(2);
await MeshoptEncoder.ready; await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder });

const CHARS = [
  ['m_suit', 'quaternius-men/Suit.gltf'], ['m_swat', 'quaternius-men/Swat.gltf'], ['m_punk', 'quaternius-men/Punk.gltf'],
  ['m_casual', 'quaternius-men/Casual_2.gltf'], ['m_hoodie', 'quaternius-men/Casual_Hoodie.gltf'], ['m_worker', 'quaternius-men/Worker.gltf'],
  ['m_space', 'quaternius-men/Spacesuit.gltf'],
  ['f_suit', 'quaternius-women/Suit.gltf'], ['f_formal', 'quaternius-women/Formal.gltf'], ['f_punk', 'quaternius-women/Punk.gltf'],
  ['f_casual', 'quaternius-women/Casual.gltf'], ['f_scifi', 'quaternius-women/SciFi.gltf'], ['f_soldier', 'quaternius-women/Soldier.gltf'],
  ['f_worker', 'quaternius-women/Worker.gltf'],
];
const KEEP_ANIMS = new Set(['Death', 'HitRecieve', 'Idle', 'Idle_Neutral', 'Idle_Gun', 'Idle_Gun_Pointing', 'Idle_Gun_Shoot', 'Gun_Shoot', 'Run', 'Run_Shoot', 'Walk', 'Wave', 'Interact', 'Punch_Right']);
const KEEP_POS = new Set(['Root', 'Body', 'Hips']);
const FINGER = /^(Index|Middle|Ring|Pinky|Thumb)\d/;

async function compress(doc, file) {
  await doc.transform(dedup(), prune(), resample(), weld(), quantize({ quantizeNormal: 8, quantizePosition: 14, quantizeWeight: 8 }), unpartition());
  doc.createExtension(EXTMeshoptCompression).setRequired(true).setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.QUANTIZE });
  await io.write(file, doc);
  console.log(path.basename(file), (fs.statSync(file).size / 1024).toFixed(0) + ' KB');
}

// personagens: só malha + esqueleto, uma cena por modelo
const chars = await io.read(path.join(SRC, CHARS[0][1]));
const scenesOf = d => d.getRoot().listScenes();
scenesOf(chars)[0].setName(CHARS[0][0]);
for (const [name, rel] of CHARS.slice(1)) {
  const d = await io.read(path.join(SRC, rel));
  scenesOf(d)[0].setName(name);
  mergeDocuments(chars, d);
}
for (const a of chars.getRoot().listAnimations()) { for (const c of a.listChannels()) c.dispose(); for (const sm of a.listSamplers()) sm.dispose(); a.dispose(); }
await compress(chars, path.join(OUT, 'chars.glb'));

// animações: tiradas do terno masculino, sem dedos e só com translação no quadril
const anims = await io.read(path.join(SRC, 'quaternius-men/Suit.gltf'));
for (const m of anims.getRoot().listMeshes()) m.dispose();
for (const a of anims.getRoot().listAnimations()) {
  if (!KEEP_ANIMS.has(a.getName())) { a.dispose(); continue; }
  for (const c of a.listChannels()) {
    const n = c.getTargetNode().getName(), p = c.getTargetPath();
    if (FINGER.test(n) || (p !== 'rotation' && !KEEP_POS.has(n))) { c.getSampler().dispose(); c.dispose(); }
  }
}
await compress(anims, path.join(OUT, 'anims.glb'));

// veículos da Kenney: uma cena por carro
const CARS = ['sedan', 'sedan-sports', 'suv', 'suv-luxury', 'hatchback-sports', 'taxi', 'police', 'van', 'truck', 'delivery', 'ambulance', 'garbage-truck'];
const KDIR = path.join(SRC, 'kenney-car-kit/Models/GLB format');
const cars = await io.read(path.join(KDIR, CARS[0] + '.glb'));
scenesOf(cars)[0].setName(CARS[0]);
for (const n of CARS.slice(1)) {
  const d = await io.read(path.join(KDIR, n + '.glb'));
  scenesOf(d)[0].setName(n);
  mergeDocuments(cars, d);
}
await compress(cars, path.join(OUT, 'cars.glb'));
