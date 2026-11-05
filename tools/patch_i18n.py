"""Patch: seletor de idioma nas opções e carga do módulo de tradução antes da interface."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')
def patch(fn, marker, reps):
    p = os.path.join(V2, fn); s = open(p, encoding='utf-8').read()
    if marker in s: print('já aplicado:', fn); return
    for a, b in reps:
        if a not in s: sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s); print('ok:', fn)
patch('js/ui.js', "id=\"gLang\"", [
    ("/* Interface: telas, HUD, entrada, campanha e laço principal. */\n",
     "/* Interface: telas, HUD, entrada, campanha e laço principal. */\nimport {LANG,setLang} from './i18n.js';\n"),
    ("<label>Vozes <input type=\"range\" id=\"vVo\" min=\"0\" max=\"1\" step=\"0.05\"></label></div>`;",
     "<label>Vozes <input type=\"range\" id=\"vVo\" min=\"0\" max=\"1\" step=\"0.05\"></label>\n    <span class=\"l\">Idioma</span><label><select id=\"gLang\"><option value=\"pt\">Português</option><option value=\"en\">English</option></select></label></div>`;"),
    ("  $('#gPix').value=String(settings.pix);",
     "  $('#gLang').value=LANG;$('#gLang').onchange=e=>setLang(e.target.value);\n  $('#gPix').value=String(settings.pix);"),
])
