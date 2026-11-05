"""Patch único: legendas, trilha dinâmica, motor e volumes na interface (mantido como registro)."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:80]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('js/ui.js', [
    ("import {update,updateWorld,setSel,", "import {say,update,updateWorld,setSel,"),
    ("import {SND,audioInit,sfx,setMute} from './audio.js';",
     "import {SND,audioInit,sfx,setMute,vo,setCommHandler,setIntensity,engine,applyVolumes} from './audio.js';"),
    ("hooks.end=()=>showResult();",
     """hooks.end=()=>showResult();
let subT=null;
function showSub(r){
  const el=$('#sub');el.textContent='';const b=document.createElement('b');b.textContent=(r.who||'')+': ';b.style.color=r.col;
  el.append(b,document.createTextNode(r.text));el.style.borderColor=r.col;el.style.opacity='1';
  clearTimeout(subT);subT=setTimeout(()=>{el.style.opacity='0';},2200+r.text.length*45);
}
hooks.vo=(key,u)=>{if(!M||M.demo||state!=='jogo')return;const r=vo(key,u);if(!r)return;if(r.comm)showSub(r);else if(u)say(u,r.text,r.col);};
setCommHandler(r=>showSub(r));"""),
    ("  log(`Inserção em ${M.D.nome}. ${TIPOS[M.tipo]}.`,'cyan');",
     "  log(`Inserção em ${M.D.nome}. ${TIPOS[M.tipo]}.`,'cyan');setTimeout(()=>hooks.vo('ctl:ins'),600);"),
    ("    <label><input type=\"checkbox\" id=\"gBloom\"> Brilho neon</label><label><input type=\"checkbox\" id=\"gShadow\"> Sombras</label></div>`;",
     "    <label><input type=\"checkbox\" id=\"gBloom\"> Brilho neon</label><label><input type=\"checkbox\" id=\"gShadow\"> Sombras</label>\n    <span class=\"l\">Som</span><label>Música <input type=\"range\" id=\"vMus\" min=\"0\" max=\"1\" step=\"0.05\"></label><label>Efeitos <input type=\"range\" id=\"vSfx\" min=\"0\" max=\"1\" step=\"0.05\"></label><label>Vozes <input type=\"range\" id=\"vVo\" min=\"0\" max=\"1\" step=\"0.05\"></label></div>`;"),
    ("  $('#gShadow').onchange=e=>{settings.shadows=e.target.checked;saveSettings();applyGfx();};",
     "  $('#gShadow').onchange=e=>{settings.shadows=e.target.checked;saveSettings();applyGfx();};\n  [['#vMus','mus'],['#vSfx','sfx'],['#vVo','vo']].forEach(([id,k])=>{const el=$(id);el.value=String(settings[k]);el.oninput=()=>{settings[k]=+el.value;applyVolumes();saveSettings();};el.onchange=()=>{if(k==='vo')hooks.vo('ctl:ins');};});"),
    ("      panCamera(dt);if(!M.paused)update(dt);",
     "      panCamera(dt);if(!M.paused)update(dt);\n      setIntensity(M.ended?0:M.t-(M.lastCombat??-99)<7?3:(M.corpAlert||M.policeAggro>0)?2:1);\n      {const car=M.cars.find(c=>c.player&&!c.dead&&c.occ.length);engine(car&&!M.paused?car.cur:0,car&&car.x,car&&car.y);}"),
    ("    }else if(M&&state==='demo'){",
     "    }else{setIntensity(0);engine(0);}\n    if(M&&state==='demo'){"),
])
patch('body.html', [
    ("  <div id=\"msgs\"></div>", "  <div id=\"msgs\"></div>\n  <div id=\"sub\" aria-live=\"polite\"></div>"),
])
patch('hud.css', [
    (".gfx input{accent-color:var(--amber)}",
     ".gfx input{accent-color:var(--amber)}\n.gfx input[type=range]{width:110px;vertical-align:middle;margin-left:6px}\n#sub{position:absolute;left:50%;bottom:calc(150px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);font:13px/1.4 var(--mono);color:var(--fg);background:rgba(6,8,14,.82);padding:7px 14px;border-left:3px solid var(--cyan);max-width:min(640px,86vw);opacity:0;transition:opacity .5s;pointer-events:none;text-align:left}\n#sub b{font-weight:600;letter-spacing:.08em}"),
])
print('ok')
