"""Patch único: polimento 1 — minimapa girando, linhas de ordem, feedback de dano, dicas, cursor, zoom suave, fades."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    if reps[0][1] in s:
        print('já aplicado:', fn); return
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('js/core.js', [
    ("export const settings={pix:2,bloom:true,shadows:true,mus:.6,sfx:1,vo:1};",
     "export const settings={pix:2,bloom:true,shadows:true,mus:.6,sfx:1,vo:1,tips:true,seen:[]};"),
])

patch('js/sim.js', [
    ("v.lastHit=M.t;", "v.lastHit=M.t;if(v.kind==='agente')M.hurtFlash=Math.min(1,(M.hurtFlash||0)+dmg/35);"),
])

MINI = r"""let miniT={th:0,k:1,cx:0};
export function drawMini(mc){
  if(!miniBase||!M)return;
  const c=mc.getContext('2d'),W=mc.width,cx=W/2,k=W/(N*4)*.7;
  const a=Math.PI/4+camS.yawA,th=-Math.PI/2-Math.atan2(-Math.sin(a),-Math.cos(a));
  miniT={th,k,cx};
  c.setTransform(1,0,0,1,0,0);c.clearRect(0,0,W,W);
  c.translate(cx,cx);c.rotate(th);c.scale(k,k);c.translate(-N*2,-N*2);
  c.drawImage(miniBase,0,0);
  const dot=(x,y,r,col)=>{c.fillStyle=col;c.fillRect(x*4-r/2,y*4-r/2,r,r);};
  for(const u of M.units){
    if(u.dead||u.inCar)continue;
    if(u.follower)dot(u.x,u.y,5,'#2a9fc0');
    else if(u.kind==='civil')dot(u.x,u.y,4,'#6f7890');
    else if(u.kind==='policia')dot(u.x,u.y,6,M.policeAggro>0?'#7fa8ff':'#4a6aaa');
    else if(u.fac==='corp')dot(u.x,u.y,u.kind==='vip'||u.rival?11:7,u.kind==='vip'?'#ffd36b':u.rival?u.trim:u.alerted?'#ff4d5e':'#a03040');
    else if(u.kind==='cientista')dot(u.x,u.y,10,'#5dffa0');
    else if(u.kind==='torre')dot(u.x,u.y,7,'#4fd8ff');
  }
  for(const cr of M.cars)if(cr.player&&!cr.dead)dot(cr.x,cr.y,9,'#9fe8ff');
  for(const t of M.terms)dot(t.x,t.y,11,t.done?'#5dffa0':'#ffa53d');
  for(const e of (M.evacs||(M.evac?[M.evac]:[])))dot(e.x,e.y,14,'rgba(93,255,160,.6)');
  for(const a of M.agents)if(!a.dead){const p=a.inCar||a;dot(p.x,p.y,10,'#4fd8ff');}
  const cs=[[0,0],[VW,0],[VW,VH],[0,VH]].map(([x,y])=>toWorld(x,y));
  c.strokeStyle='rgba(255,255,255,.6)';c.lineWidth=3;c.beginPath();cs.forEach((p,i)=>i?c.lineTo(p.x*4,p.y*4):c.moveTo(p.x*4,p.y*4));c.closePath();c.stroke();
  c.setTransform(1,0,0,1,0,0);
}
/* converte um clique no scanner (pixels do canvas) em coordenadas do mundo */
export function miniToWorld(px,py){
  const {th,k,cx}=miniT,dx=px-cx,dy=py-cx,cs=Math.cos(-th),sn=Math.sin(-th);
  return {x:((dx*cs-dy*sn)/k+N*2)/4,y:((dx*sn+dy*cs)/k+N*2)/4};
}
"""

with open(os.path.join(V2, 'js/render.js'), encoding='utf-8') as fh:
    rs = fh.read()
if 'miniToWorld' not in rs:
    i = rs.index('export function drawMini(mc){')
    rs = rs[:i] + MINI
    open(os.path.join(V2, 'js/render.js'), 'w', encoding='utf-8').write(rs)

patch('js/render.js', [
    ("export function zoomCam(f){camS.zoom=clamp(camS.zoom*f,.55,2.2);}",
     "export function zoomCam(f){camS.zoomT=clamp((camS.zoomT??camS.zoom)*f,.55,2.2);}"),
    ("  camS.yawA+=(camS.yaw*Math.PI/2-camS.yawA)*Math.min(1,dt*7);",
     "  camS.yawA+=(camS.yaw*Math.PI/2-camS.yawA)*Math.min(1,dt*7);\n  if(camS.zoomT!=null){camS.zoom+=(camS.zoomT-camS.zoom)*Math.min(1,dt*12);if(Math.abs(camS.zoomT-camS.zoom)<.002){camS.zoom=camS.zoomT;camS.zoomT=null;}}"),
    ("  if(vignette)c.drawImage(vignette,0,0,VW,VH);",
     "  if(vignette)c.drawImage(vignette,0,0,VW,VH);\n  if(M.hurtFlash>0){M.hurtFlash=Math.max(0,M.hurtFlash-dt*1.8);const g=c.createRadialGradient(VW/2,VH/2,Math.min(VW,VH)*.32,VW/2,VH/2,Math.max(VW,VH)*.72);g.addColorStop(0,'rgba(255,40,60,0)');g.addColorStop(1,`rgba(255,40,60,${Math.min(.5,M.hurtFlash*.5)})`);c.fillStyle=g;c.fillRect(0,0,VW,VH);}"),
    ("  if(ui){\n    if(ui.drag)",
     """  if(!M.cine){
    c.lineWidth=1.5;
    for(const a of M.sel){
      if(a.dead)continue;
      const src=a.inCar||a,path=a.inCar?a.inCar.path:a.path,pi=a.inCar?a.inCar.pi:a.pi,o=a.ord;
      if(path&&path.length>pi){
        c.setLineDash([5,5]);c.strokeStyle='rgba(79,216,255,.55)';c.beginPath();let p=toScreen(src.x,src.y,.05);c.moveTo(p.x,p.y);
        for(let i=pi;i<path.length;i++){p=toScreen(path[i].x,path[i].y,.05);c.lineTo(p.x,p.y);}
        c.stroke();c.setLineDash([]);c.fillStyle='rgba(79,216,255,.75)';c.beginPath();c.arc(p.x,p.y,3,0,TAU);c.fill();
      }
      if(o&&o.k==='atk'&&o.t&&!o.t.dead){const tp=o.t.inCar||o.t,p1=toScreen(src.x,src.y,.6),p2=toScreen(tp.x,tp.y,.6);c.setLineDash([3,4]);c.strokeStyle='rgba(255,77,94,.6)';c.beginPath();c.moveTo(p1.x,p1.y);c.lineTo(p2.x,p2.y);c.stroke();}
      if(o&&o.k==='throw'){const p1=toScreen(src.x,src.y,.6),p2=toScreen(o.x,o.y,0);c.setLineDash([3,4]);c.strokeStyle='rgba(255,165,61,.65)';c.beginPath();c.moveTo(p1.x,p1.y);c.quadraticCurveTo((p1.x+p2.x)/2,Math.min(p1.y,p2.y)-60,p2.x,p2.y);c.stroke();}
      c.setLineDash([]);
    }
  }
  if(ui){
    if(ui.drag)"""),
])

patch('js/ui.js', [
    ("import {renderer,resize,applyGfx,buildScene,renderFrame,drawMini,",
     "import {miniToWorld,renderer,resize,applyGfx,buildScene,renderFrame,drawMini,"),
    ("$('#mini').addEventListener('pointerdown',e=>{const r=e.currentTarget.getBoundingClientRect();centerOn((e.clientX-r.left)/r.width*N,(e.clientY-r.top)/r.height*N);});",
     "$('#mini').addEventListener('pointerdown',e=>{const el=e.currentTarget,r=el.getBoundingClientRect(),k=el.width/r.width,w=miniToWorld((e.clientX-r.left)*k,(e.clientY-r.top)*k);centerOn(w.x,w.y);});"),
    ("  M.hoverCar=M.hover?null:pickCar(e.clientX,e.clientY);",
     "  M.hoverCar=M.hover?null:pickCar(e.clientX,e.clientY);\n  cv.style.cursor=M.hover?(M.hover.kind==='agente'?'pointer':(M.hover.fac==='corp'||M.hover.fac==='police')?'crosshair':'default'):(M.hoverCar&&M.sel.length?'pointer':'default');"),
    ("    b.classList.toggle('sel',!!u.sel);", "    b.classList.toggle('sel',!!u.sel);b.classList.toggle('hit',!u.dead&&M.t-(u.lastHit??-9)<.35);"),
    ("function showTitle(){\n  setState('demo');show('#scrTitle');hideModal();",
     r"""/* ---------- dicas contextuais (uma vez cada, podem ser desligadas) ---------- */
const TIPS={
  start:'Clique num agente (ou arraste para pegar o grupo) e clique no chão para mover. Botão direito ataca.',
  probe:'Um agente leva a SONDA: equipe-a e fique perto das pessoas para recrutá-las como seguidores.',
  police:'A polícia está advertindo: aperte H para guardar as armas e ela se acalma.',
  alert:'Combate! Espaço pausa o jogo para você dar ordens com calma.',
  hurt:'Agente ferido: clique no KIT MÉDICO no inventário para curá-lo.',
  cover:'O escudo azul indica cobertura: encostado em paredes, contêineres ou carros, o agente evita metade dos tiros.',
  car:'Com agentes selecionados, clique num carro para entrar. Depois clique no mapa para dirigir e V para sair.',
  rotate:'Z e X giram a câmera quando um prédio atrapalha a visão. O scanner gira junto.',
};
let tipT=0;const tipQ=[];
function tip(id){if(!settings.tips||(settings.seen||[]).includes(id)||tipQ.includes(id))return;tipQ.push(id);}
function tipTick(dt){
  tipT-=dt;if(tipT>0||!tipQ.length||(M&&M.cine))return;
  const id=tipQ.shift();(settings.seen=settings.seen||[]).push(id);saveSettings();
  const el=$('#tip');el.querySelector('span').textContent=TIPS[id];el.hidden=false;el.classList.add('on');
  clearTimeout(el._h);el._h=setTimeout(()=>el.classList.remove('on'),9000);tipT=11;
}
function tipChecks(){
  if(M.cine||M.ended)return;
  if(M.t>1)tip('start');
  if(M.t>6&&M.agents.some(a=>a.inv.some(q=>q.t==='sonda')))tip('probe');
  if(M.units.some(u=>u.kind==='policia'&&u.warned&&!u.dead))tip('police');
  if(M.corpAlert||M.policeAggro>0)tip('alert');
  if(M.agents.some(a=>!a.dead&&a.hp<a.maxHp*.5&&a.inv.some(q=>q.t==='medkit')))tip('hurt');
  if(M.agents.some(a=>a.covered&&!a.dead))tip('cover');
  if(M.hoverCar&&M.sel.length)tip('car');
  if(M.t>45)tip('rotate');
}
function fadeIn(){const f=$('#fade');f.classList.add('on');requestAnimationFrame(()=>requestAnimationFrame(()=>f.classList.remove('on')));}
$('#tip button').addEventListener('click',()=>$('#tip').classList.remove('on'));
function showTitle(){
  setState('demo');show('#scrTitle');hideModal();fadeIn();camS.zoomT=null;"""),
    ("function showMap(){\n  setState('menu');show('#scrMap');hideModal();",
     "function showMap(){\n  if(state==='jogo'||state==='demo')fadeIn();\n  setState('menu');show('#scrMap');hideModal();"),
    ("  setState('jogo');show('#hud');$('#msgs').innerHTML='';invSig='';",
     "  setState('jogo');show('#hud');$('#msgs').innerHTML='';invSig='';fadeIn();camS.zoomT=null;$('#tip').classList.remove('on');"),
    ("    <label><input type=\"checkbox\" id=\"gBloom\"> Brilho neon</label><label><input type=\"checkbox\" id=\"gShadow\"> Sombras</label>",
     "    <label><input type=\"checkbox\" id=\"gBloom\"> Brilho neon</label><label><input type=\"checkbox\" id=\"gShadow\"> Sombras</label><label><input type=\"checkbox\" id=\"gTips\"> Dicas</label>"),
    ("  $('#gShadow').onchange=e=>{settings.shadows=e.target.checked;saveSettings();applyGfx();};",
     "  $('#gShadow').onchange=e=>{settings.shadows=e.target.checked;saveSettings();applyGfx();};\n  $('#gTips').checked=settings.tips;$('#gTips').onchange=e=>{settings.tips=e.target.checked;if(settings.tips)settings.seen=[];saveSettings();};"),
    ("      renderFrame(dt,mouse);drawMini($('#mini'));",
     "      tipChecks();tipTick(dt);\n      renderFrame(dt,mouse);drawMini($('#mini'));"),
])

patch('body.html', [
    ("  <div id=\"sub\" aria-live=\"polite\"></div>",
     "  <div id=\"sub\" aria-live=\"polite\"></div>\n  <div id=\"tip\" hidden role=\"status\"><b>DICA</b><span></span><button aria-label=\"Fechar dica\">×</button></div>"),
    ("<div id=\"modal\" class=\"modal\" hidden>", "<div id=\"fade\"></div>\n<div id=\"modal\" class=\"modal\" hidden>"),
])
patch('hud.css', [
    (".rv.dead{opacity:.45;text-decoration:line-through}",
     """.rv.dead{opacity:.45;text-decoration:line-through}
#tip{position:absolute;left:50%;bottom:calc(205px + env(safe-area-inset-bottom,0px));transform:translate(-50%,8px);display:flex;gap:10px;align-items:center;max-width:min(560px,88vw);background:rgba(14,12,6,.92);border:1px solid var(--amber);padding:9px 10px 9px 14px;font-size:14px;line-height:1.4;opacity:0;pointer-events:none;transition:opacity .4s,transform .4s}
#tip.on{opacity:1;transform:translate(-50%,0);pointer-events:auto}
#tip b{font:600 10px/1 var(--mono);letter-spacing:.2em;color:var(--amber)}
#tip button{background:none;border:0;color:var(--dim);font-size:18px;cursor:pointer;padding:0 4px}
#tip button:hover{color:var(--fg)}
#fade{position:fixed;inset:0;background:#000;opacity:0;pointer-events:none;z-index:60;transition:opacity .7s}
#fade.on{opacity:1;transition:none}
.card.hit{border-color:var(--red);box-shadow:inset 0 0 0 1px rgba(255,77,94,.5)}
@media (prefers-reduced-motion:reduce){#fade{transition:none}}"""),
])
print('ok')
