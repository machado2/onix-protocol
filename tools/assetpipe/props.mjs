// Empacota os objetos de cenário CC0 (Kenney e Quaternius Cyberpunk Game Kit) num props.glb, uma cena por objeto.
// Uso: node tools/assetpipe/props.mjs <pasta assets_dl> <pasta de saída>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTMeshoptCompression } from '@gltf-transform/extensions';
import { mergeDocuments, prune, dedup, weld, quantize, unpartition } from '@gltf-transform/functions';
import { MeshoptEncoder, MeshoptDecoder } from 'meshoptimizer';
import path from 'node:path';
import fs from 'node:fs';

const [SRC, OUT] = process.argv.slice(2);
await MeshoptEncoder.ready; await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder });

const K = kit => path.join(SRC, 'kenney-' + kit, 'Models', kit === 'nature-kit' ? 'GLTF format' : 'GLB format');
const PROPS = [
  ['tree_a', K('nature-kit'), 'tree_default.glb'], ['tree_b', K('nature-kit'), 'tree_oak.glb'],
  ['tree_c', K('nature-kit'), 'tree_detailed.glb'], ['tree_d', K('nature-kit'), 'tree_fat.glb'],
  ['bush', K('nature-kit'), 'plant_bushLarge.glb'],
  ['lamp_k', K('city-kit-roads'), 'light-curved.glb'], ['lamp_k2', K('city-kit-roads'), 'light-square.glb'],
  ['traffic', K('city-kit-roads'), 'traffic-light.glb'], ['cone', K('city-kit-roads'), 'construction-cone.glb'],
  ['cbarrier', K('city-kit-roads'), 'construction-barrier.glb'], ['dumpster', K('city-kit-roads'), 'dumpster.glb'],
  ['sign_stop', K('city-kit-roads'), 'road-sign-stop.glb'], ['sign_warn', K('city-kit-roads'), 'road-sign-warning.glb'],
  ['barrel', K('survival-kit'), 'barrel.glb'], ['box', K('survival-kit'), 'box.glb'], ['box_large', K('survival-kit'), 'box-large.glb'],
  ['awning', K('city-kit-commercial'), 'detail-awning.glb'], ['parasol', K('city-kit-commercial'), 'detail-parasol-a.glb'],
  ['planter', K('city-kit-suburban'), 'planter.glb'],
  ['ac', path.join(SRC, 'cyberpunk'), 'AC.gltf'], ['ac_side', path.join(SRC, 'cyberpunk'), 'AC_Side.gltf'],
  ['ac_stack', path.join(SRC, 'cyberpunk'), 'AC_Stacked.gltf'], ['antenna_a', path.join(SRC, 'cyberpunk'), 'Antenna_1.gltf'],
  ['antenna_b', path.join(SRC, 'cyberpunk'), 'Antenna_2.gltf'], ['computer', path.join(SRC, 'cyberpunk'), 'Computer.gltf'],
  ['computer_l', path.join(SRC, 'cyberpunk'), 'Computer_Large.gltf'], ['tv_a', path.join(SRC, 'cyberpunk'), 'TV_1.gltf'],
  ['tv_b', path.join(SRC, 'cyberpunk'), 'TV_2.gltf'], ['lamp_c', path.join(SRC, 'cyberpunk'), 'Light_Street_1.gltf'],
  ['lamp_c2', path.join(SRC, 'cyberpunk'), 'Light_Street_2.gltf'],
];

let doc = null;
for (const [name, dir, file] of PROPS) {
  const d = await io.read(path.join(dir, file));
  d.getRoot().listScenes()[0].setName(name);
  if (!doc) doc = d; else mergeDocuments(doc, d);
}
await doc.transform(dedup(), prune(), weld(), quantize({ quantizeNormal: 8, quantizePosition: 14 }), unpartition());
doc.createExtension(EXTMeshoptCompression).setRequired(true).setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.QUANTIZE });
const out = path.join(OUT, 'props.glb');
await io.write(out, doc);
console.log('props.glb', (fs.statSync(out).size / 1024).toFixed(0) + ' KB', doc.getRoot().listTextures().length, 'texturas');
