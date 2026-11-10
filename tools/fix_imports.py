"""Ajusta os .import das texturas do Godot: compressão VRAM, mipmaps e mapas normais marcados."""
import glob, re, os, sys
root = sys.argv[1] if len(sys.argv) > 1 else 'godot'
for f in glob.glob(os.path.join(root, 'assets', 'tex', '*.png.import')):
    s = open(f, encoding='utf-8').read()
    s = re.sub(r'compress/mode=\d', 'compress/mode=2', s)
    s = re.sub(r'mipmaps/generate=\w+', 'mipmaps/generate=true', s)
    if f.endswith('_n.png.import'):
        s = re.sub(r'compress/normal_map=\d', 'compress/normal_map=1', s)
    s = re.sub(r'detect_3d/compress_to=\d', 'detect_3d/compress_to=0', s)
    open(f, 'w', encoding='utf-8').write(s)
