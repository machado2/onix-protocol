// Converte um .glb em .json (glTF com buffers embutidos em data URI), para hospedagens que não servem .glb.
// Uso: node tools/assetpipe/tojson.mjs in.glb out.json
import fs from 'node:fs';
const [inp, out] = process.argv.slice(2);
const b = fs.readFileSync(inp);
const jsonLen = b.readUInt32LE(12);
const gltf = JSON.parse(b.subarray(20, 20 + jsonLen).toString('utf8'));
let off = 20 + jsonLen, bin = null;
while (off < b.length) {
  const len = b.readUInt32LE(off), type = b.readUInt32LE(off + 4);
  if (type === 0x004E4942) bin = b.subarray(off + 8, off + 8 + len);
  off += 8 + len;
}
gltf.buffers.forEach((buf, i) => {
  if (i === 0 && buf.uri === undefined && bin) buf.uri = 'data:application/octet-stream;base64,' + bin.subarray(0, buf.byteLength).toString('base64');
});
fs.writeFileSync(out, JSON.stringify(gltf));
console.log(out, (fs.statSync(out).size / 1024).toFixed(0) + ' KB');
