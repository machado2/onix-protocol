"""Resumo de um .gltf/.glb: nós, malhas, materiais, ossos, animações e triângulos."""
import json, struct, sys

def load(p):
    b = open(p, 'rb').read()
    if b[:4] == b'glTF':
        n = struct.unpack('<I', b[12:16])[0]
        return json.loads(b[20:20 + n])
    return json.loads(b)

for p in sys.argv[1:]:
    g = load(p)
    acc = g.get('accessors', [])
    tris = 0
    for m in g.get('meshes', []):
        for pr in m['primitives']:
            if 'indices' in pr:
                tris += acc[pr['indices']]['count'] // 3
    print('==', p.replace('\\', '/').split('/')[-1], 'tris', tris)
    print('  meshes:', [m['name'] for m in g.get('meshes', [])])
    print('  materials:', [(m.get('name'), m.get('pbrMetallicRoughness', {}).get('baseColorFactor')) for m in g.get('materials', [])])
    print('  images:', len(g.get('images', [])), 'skins:', [len(s['joints']) for s in g.get('skins', [])])
    print('  anims:', [a['name'] for a in g.get('animations', [])])
    if '-v' in sys.argv[0:1] or len(sys.argv) == 2:
        sk = g.get('skins', [])
        if sk:
            print('  joints:', [g['nodes'][j]['name'] for j in sk[0]['joints']])
