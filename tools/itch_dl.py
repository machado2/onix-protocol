"""Baixa um arquivo gratuito ("pague quanto quiser", mínimo zero) de uma página do itch.io.
Uso: python tools/itch_dl.py <url do jogo> <trecho do nome do arquivo> <destino>"""
import http.cookiejar, json, re, sys, urllib.parse, urllib.request

page, want, out = sys.argv[1:4]
cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
op.addheaders = [('User-Agent', 'Mozilla/5.0')]

def get(u):
    return op.open(u).read().decode('utf-8', 'replace')

def post(u, data):
    r = urllib.request.Request(u, data=urllib.parse.urlencode(data).encode(), headers={'X-Requested-With': 'XMLHttpRequest'})
    return json.loads(op.open(r).read())

csrf = lambda h: re.search(r'name="csrf_token" value="([^"]+)"', h).group(1)
h = get(page)
dl = post(page.rstrip('/') + '/download_url', {'csrf_token': csrf(h)})['url']
key = urllib.parse.unquote(dl.rsplit('/download/', 1)[1])
h2 = get(dl)
ups = re.findall(r'data-upload_id="(\d+)".{0,600}?title="([^"]+)"', h2, re.S)
print('arquivos:', ups)
uid = next(u for u, n in ups if want in n)
f = post(f"{page.rstrip('/')}/file/{uid}?source=game_download&key={urllib.parse.quote(key)}", {'csrf_token': csrf(h2)})
if 'url' not in f:
    f = post(f"{page.rstrip('/')}/file/{uid}?source=game_download", {'csrf_token': csrf(h2)})
print('baixando', uid, f)
with op.open(f['url']) as r, open(out, 'wb') as w:
    while True:
        b = r.read(1 << 20)
        if not b: break
        w.write(b)
print('ok', out)
