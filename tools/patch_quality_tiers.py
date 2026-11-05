"""Patch: níveis de qualidade (Ultra/Alta/Média/Baixa) e resolução dinâmica."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, 'v2')

def patch(path, marker, reps):
    s = open(path, encoding='utf-8').read()
    if marker in s:
        print('já aplicado:', os.path.basename(path)); return
    for a, b in reps:
        if a not in s:
            sys.exit(f'{path}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8').write(s)
    print('ok:', os.path.basename(path))

patch(os.path.join(V2, 'js', 'render.js'), 'dynScale', [
    ("export let PR=1;", "export let PR=1;let dynScale=1,dynT=0,dynAvg=16;"),
    ("const pr=PR=Math.min(window.devicePixelRatio||1,2)*(settings.q||1);gtao.enabled=(settings.q||1)>=1;",
     "const pr=PR=Math.min(window.devicePixelRatio||1,2)*(settings.q||1)*dynScale;gtao.enabled=!!settings.ao;"),
    ("export function renderFrame(dt,ui){\n  if(!M||!world)return;\n",
     "/* resolução dinâmica: baixa a escala interna quando o quadro passa de ~22 ms e devolve quando sobra folga */\n"
     "function adaptRes(dt){\n"
     "  if(!(dt>0)||dt>.25)return;dynAvg+=(dt*1000-dynAvg)*.05;dynT-=dt;if(dynT>0)return;\n"
     "  let s=dynScale;if(dynAvg>22&&s>.6)s=Math.max(.6,s-.1);else if(dynAvg<13&&s<1)s=Math.min(1,s+.1);\n"
     "  if(s!==dynScale){dynScale=s;dynT=1.5;resize();}\n"
     "}\n"
     "export function renderFrame(dt,ui){\n  if(!M||!world)return;\n  adaptRes(dt);\n"),
])

patch(os.path.join(V2, 'js', 'core.js'), 'ao:false,', [
    ("export const settings={q:1,", "export const settings={q:1,ao:false,"),
])

patch(os.path.join(V2, 'js', 'ui.js'), '<option value="u">Ultra</option>', [
    ('<select id="gQ"><option value="1">Alta</option>', '<select id="gQ"><option value="u">Ultra</option><option value="1">Alta</option>'),
    ("  $('#gQ').value=String(settings.q||1);", "  $('#gQ').value=settings.ao?'u':String(settings.q||1);"),
    ("  $('#gQ').onchange=e=>{settings.q=+e.target.value;saveSettings();applyGfx();};",
     "  $('#gQ').onchange=e=>{const v=e.target.value;settings.ao=v==='u';settings.q=v==='u'?1:+v;saveSettings();applyGfx();};"),
    ("Alta usa resolução máxima e oclusão de ambiente. Em computadores mais fracos, use Média ou Baixa e desligue as sombras.",
     "Ultra liga a oclusão de ambiente. A resolução se ajusta sozinha quando o computador não acompanha; em máquinas fracas, use Média ou Baixa e desligue as sombras."),
])

patch(os.path.join(V2, 'js', 'en.js'), 'Ultra liga a oclusão', [
    ("  'Alta usa resolução máxima e oclusão de ambiente. Em computadores mais fracos, use Média ou Baixa e desligue as sombras.':'High uses full resolution and ambient occlusion. On weaker computers, use Medium or Low and turn shadows off.',",
     "  'Ultra liga a oclusão de ambiente. A resolução se ajusta sozinha quando o computador não acompanha; em máquinas fracas, use Média ou Baixa e desligue as sombras.':'Ultra turns on ambient occlusion. Resolution adjusts itself when the computer cannot keep up; on weak machines, use Medium or Low and turn shadows off.',"),
])
