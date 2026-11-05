"""Lista as strings visíveis ao jogador (heurística) em JS e HTML, para a tradução."""
import re, os, json, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')
files = [os.path.join(V2, 'js', f) for f in os.listdir(os.path.join(V2, 'js')) if f.endswith('.js') and f not in ('vo.js', 'en.js', 'i18n.js')]
files += [os.path.join(V2, 'js', 'missions', f) for f in os.listdir(os.path.join(V2, 'js', 'missions'))]
lit = re.compile(r"'((?:[^'\\\n]|\\.)*)'|`((?:[^`\\]|\\.)*)`")
pt = re.compile(r"[a-zA-ZÀ-ú]{3,}.*\s|[ãõçáéíóúâêôà]", re.I)
skip = re.compile(r"^(#[0-9a-f]{3,8}|[\w-]+\.(js|mp3|png)|[a-z]+:[a-z_0-9]+|rgba?\(.*|\d.*px.*)$", re.I)
out = {}
for f in files:
    s = open(f, encoding='utf-8').read()
    for m in lit.finditer(s):
        t = m.group(1) if m.group(1) is not None else m.group(2)
        if not t or len(t) < 3 or skip.match(t) or not pt.search(t):
            continue
        out.setdefault(t, os.path.basename(f))
html = open(os.path.join(V2, 'body.html'), encoding='utf-8').read()
for t in re.findall(r">([^<>{}]*[a-zA-ZÀ-ú]{2,}[^<>{}]*)<", html):
    t = t.strip()
    if t:
        out.setdefault(t, 'body.html')
for t in re.findall(r'(?:title|aria-label|placeholder)="([^"]+)"', html):
    out.setdefault(t, 'body.html')
json.dump(out, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
print(len(out), 'strings;', sum(len(k) for k in out), 'chars')
from collections import Counter
print(Counter(out.values()))
