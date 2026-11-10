"""Extrai os textos entre aspas dos scripts do Godot para conferir a tradução.
Uso (dentro de godot/): python ../tools/i18n_extract.py textos.json  e depois  godot --headless --path . -- --i18ncheck=textos.json,faltando.json"""
import re, io, glob, json, sys
out = sys.argv[1]
S = set()
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
for f in glob.glob('scripts/**/*.gd', recursive=True):
    f2 = f.replace('\\', '/')
    if '/dev/' in f2 or 'i18n' in f2 or 'core/lang' in f2:
        continue
    for line in io.open(f, encoding='utf-8'):
        if line.strip().startswith('#'):
            continue
        for m in STR.finditer(line):
            t = m.group(1).replace('\\n', '\n').replace('\\"', '"')
            if len(t) < 3 or not re.search(r'[a-zà-ú]{2}', t.lower()):
                continue
            if re.fullmatch(r'[A-Za-z_0-9/.:|+]+', t) and t.lower() == t:
                continue
            if t.startswith(('res://', 'user://', '--', '#')):
                continue
            S.add(t)
L = sorted(S)
json.dump(L, io.open(out, 'w', encoding='utf-8'), ensure_ascii=False)
print(len(L))
