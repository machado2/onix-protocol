import sys, os
root = sys.argv[1]
src = open(os.path.join(root, 'protocolo-onix.html'), encoding='utf-8').read()
css = src[src.index('<style>') + 7:src.index('</style>')]
css = css.replace("#cv{position:fixed;inset:0;width:100%;height:100%;display:block;cursor:crosshair;touch-action:none}",
  "#cv{position:fixed;inset:0;width:100%;height:100%;display:block;cursor:crosshair;touch-action:none}\n#ov{position:fixed;inset:0;width:100%;height:100%;pointer-events:none;z-index:2}")
css = css.replace("#mini{display:block;width:228px;height:114px;cursor:pointer}", "#mini{display:block;width:170px;height:170px;cursor:pointer}")
css = css.replace("right:calc(250px + max(12px,env(safe-area-inset-right,0px)))", "right:calc(196px + max(12px,env(safe-area-inset-right,0px)))")
start = css.index('#modes{'); end = css.index('#btnAtk{')
css = css[:start] + open(os.path.join(root, 'v2', 'hud.css'), encoding='utf-8').read() + css[end:]
css += open(os.path.join(root, 'v2', 'theme.css'), encoding='utf-8').read()
body = open(os.path.join(root, 'v2', 'body.html'), encoding='utf-8').read()
head = '''<!doctype html>
<html lang="pt-BR">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Protocolo Ônix</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap">
'''
importmap = '<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}</script>\n'
open(os.path.join(root, 'v2', 'index.html'), 'w', encoding='utf-8').write(head + '<style>' + css + '</style>\n' + importmap + body)
print('ok')
