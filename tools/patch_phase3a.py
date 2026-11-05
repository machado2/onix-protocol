"""Patch único: Fase 3, entrega 1 — história, Ponteiros, região da favela e missão 2 (registro da mudança)."""
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

# ---------------- dados ----------------
patch('js/core.js', [
    ("['#2a3240','#121822','#1a2230'],['#6b5a3d','#3a2f1f','#4a3b27']];",
     "['#2a3240','#121822','#1a2230'],['#6b5a3d','#3a2f1f','#4a3b27'],\n  ['#7a5a64','#b8607a','#c97a90'],['#4a6a6a','#3f8a86','#52a09a'],['#7a6a4a','#c9a040','#d8b45a'],['#5a5a7a','#7a6aa8','#8e80bc'],['#5a4038','#8a4a38','#9a5a46']];"),
    ("  {nome:'Vila Ferrugem',renda:1800,dif:2,tipo:'extracao',riq:.25,",
     "  {nome:'Vila Ferrugem',renda:1800,dif:2,tipo:'extracao',riq:.25,mission:'favela',\n   brief:'O Consórcio montou uma clínica clandestina no alto da Vila Ferrugem. A Dra. Sofia Tanaka, pesquisadora de neuroimplantes, está presa lá dentro. Suba o morro, tire a doutora da clínica e leve-a à van na estrada sul ou à estação do teleférico a leste. O gerador da clínica alimenta as torretas. A polícia não sobe o morro, mas os moradores vão lembrar de quem atirar neles.',\n   short:'Missão roteirizada: resgate na favela, com duas rotas de fuga.',"),
])

# ---------------- mundo ----------------
patch('js/world.js', [
    ("import {DOCAS} from './missions/docas.js';",
     "import {DOCAS} from './missions/docas.js';\nimport {FAVELA} from './missions/favela.js';\nimport {RIVALS} from './story.js';"),
    ("const MISSIONS={docas:DOCAS};",
     """const MISSIONS={docas:DOCAS,favela:FAVELA};
export function spawnRival(id,x,y){
  const R=RIVALS.find(r=>r.id===id);if(!R)return null;
  const u=mkUnit('inimigo',x,y);
  Object.assign(u,{rival:id,nome:R.nome,w:R.w,mun:WD[R.w].pente,hp:R.hp,maxHp:R.hp,armor:R.armor,spd:R.spd,acc:R.acc,coat:R.coat,trim:R.trim,long:true,visor:true,nades:2,home:{x,y}});
  return u;
}"""),
    ("    lamp(x,y,col='#ffb35c',tall=false){m.lamps.push({x,y,col,tall});},",
     "    lamp(x,y,col='#ffb35c',tall=false,extra){m.lamps.push(Object.assign({x,y,col,tall},extra||{}));},"),
    ("    for(let k=0;k<nE;k++){const p=randTile(farFromSpawn);if(!p)continue;const e=mkUnit('inimigo',p.x,p.y);e.home={x:p.x,y:p.y};armAI(e,dif,rng);}",
     """    for(let k=0;k<nE;k++){const p=randTile(farFromSpawn);if(!p)continue;const e=mkUnit('inimigo',p.x,p.y);e.home={x:p.x,y:p.y};armAI(e,dif,rng);}
    if(G&&!revolta){
      const R=G.rivais||{},alive=RIVALS.filter(r=>!(R[r.id]&&R[r.id].morto));
      let list=[];
      if(D.hq)list=alive;
      else if(dif>=3&&rng()<.55){const c=alive.filter(r=>!r.hqOnly);if(c.length)list=[c[(G.dia+di)%c.length]];}
      for(const r of list){const p=randTile(farFromSpawn);if(p)spawnRival(r.id,p.x,p.y);}
    }"""),
])

# ---------------- roteiro ----------------
patch('js/script.js', [
    ("import {mkUnit,armAI,pathTo} from './world.js';", "import {mkUnit,armAI,pathTo,spawnRival} from './world.js';"),
    ("    fork(gen){M.co.push({gen});},",
     "    fork(gen){M.co.push({gen});},\n    rival(id,x,y){const u=spawnRival(id,x,y);if(u)u.alerted=true;return u;},\n    lampOff(l){hooks.destroy('lampoff',l);},"),
])

# ---------------- simulação ----------------
patch('js/sim.js', [
    ("import {sfx} from './audio.js';", "import {sfx} from './audio.js';\nimport {RIVALS} from './story.js';"),
    ("clamp,gauss,pick,M,flags,hooks,WD,", "clamp,gauss,pick,M,G,flags,hooks,WD,"),
    ("    if(tm.prog>=4){tm.done=true;if(tm.crane){",
     "    if(tm.prog>=4){tm.done=true;if(tm.flag){M.flags[tm.flag]=true;if(tm.vo)hooks.vo(tm.vo);if(tm.msg)log(tm.msg,'cyan');sfx('hack');flags.hud=true;continue;}if(tm.crane){"),
    ("function updTurret(u,dt){\n", "function updTurret(u,dt){\n  if(u.off)return;\n"),
    ("function updGuard(u,dt){\n",
     """function rivalTick(u,dt){
  const R=RIVALS.find(r=>r.id===u.rival);
  if(u.escaping){
    u.escT-=dt;moveAlong(u,dt,u.spd*1.4);
    if(!u.path||u.escT<=0||u.x<1.3||u.y<1.3||u.x>N-1.3||u.y>N-1.3){
      u.dead=true;u.vanished=true;u.hp=0;(M.rivalEsc=M.rivalEsc||[]).push(u.rival);
      if(G&&G.rivais){const s=G.rivais[u.rival]||(G.rivais[u.rival]={});s.fugas=(s.fugas||0)+1;}
      log(`${u.nome} escapou.`,'amber');hooks.vo('ctl:riv_esc');
    }
    return true;
  }
  if(R&&!R.hqOnly&&u.hp<u.maxHp*.3){
    u.escaping=true;u.escT=10;u.tgt=null;hooks.vo(`riv:${u.rival}_esc`,u);
    const ex=[[1,u.y],[N-1.5,u.y],[u.x,1],[u.x,N-1.5]].sort((a,b)=>Math.hypot(a[0]-u.x,a[1]-u.y)-Math.hypot(b[0]-u.x,b[1]-u.y))[0];
    pathTo(u,ex[0],ex[1]);return true;
  }
  return false;
}
function updGuard(u,dt){
  if(u.rival&&rivalTick(u,dt))return;
"""),
    ("if(!u.contact&&!u.follower){u.contact=true;if(u.kind==='guarda')",
     "if(!u.contact&&!u.follower){u.contact=true;if(u.rival){hooks.vo('riv:'+u.rival+'_intro',u);hooks.vo('ctl:riv_spot');(M.rivalSeen=M.rivalSeen||new Set()).add(u.rival);log(`${u.nome}, um dos Ponteiros do Consórcio, entrou no combate.`,'red');}else if(u.kind==='guarda')"),
    ("  if(v.kind==='vip')log(",
     "  if(v.rival&&!v.vanished){hooks.vo('riv:'+v.rival+'_death',v);hooks.vo('ctl:riv_kill');(M.bonus=M.bonus||[]).push({text:'Ponteiro eliminado: '+v.nome,val:3000});(M.rivalDead=M.rivalDead||[]).push(v.rival);if(G&&G.rivais)(G.rivais[v.rival]||(G.rivais[v.rival]={})).morto=true;log(`${v.nome} está morto.`,'green');}\n  if(v.kind==='vip')log("),
    ("  const inWin=!b.kiosk&&fl<b.fl&&", "  const inWin=!b.kiosk&&!b.favela&&fl<b.fl&&"),
])

# ---------------- áudio ----------------
patch('js/audio.js', [
    ("const ROLE={ag:{comm:1,fx:'radio',col:'#4fd8ff'},", "const ROLE={riv:{fx:'helmet',col:'#ff8a5a'},ag:{comm:1,fx:'radio',col:'#4fd8ff'},"),
])

# ---------------- render ----------------
DECOR3 = """    }else if(d.type==='generator'){
      g.add(boxM(.9,.75,.6,d.x,.38,d.y,lam('#5a5a40')),boxM(.12,.5,.12,d.x+.3,1,d.y,lam('#2a2a2a')));
      const led=new THREE.Mesh(new THREE.BoxGeometry(.1,.06,.02),basic('#5dffa0'));led.position.set(d.x-.2,.6,d.y+.31);g.add(led);o.led=led;
    }else if(d.type==='laundry'){
      const L=Math.hypot(d.x2-d.x1,d.y2-d.y1),a=Math.atan2(d.y2-d.y1,d.x2-d.x1);
      const line=new THREE.Mesh(new THREE.CylinderGeometry(.01,.01,L,3).rotateZ(Math.PI/2),lam('#202020'));line.position.set((d.x1+d.x2)/2,d.h,(d.y1+d.y2)/2);line.rotation.y=-a;g.add(line);
      const n=Math.max(2,Math.floor(L*1.6));
      for(let k=0;k<n;k++){const t=(k+.5)/n,cl=new THREE.Mesh(new THREE.PlaneGeometry(.26,.34),new THREE.MeshLambertMaterial({color:pick(['#e8e4dc','#c23a5a','#2a7a9a','#d0a040','#5a3a8a','#2e8a6a','#f0f0f0'],Math.random),side:THREE.DoubleSide}));cl.position.set(d.x1+(d.x2-d.x1)*t,d.h-.19,d.y1+(d.y2-d.y1)*t);cl.rotation.y=-a;g.add(cl);}
    }else if(d.type==='cable'){
      const steel=lam('#3a404e');
      g.add(boxM(.45,5.8,.45,d.x,2.9,d.y,steel),boxM(3,.15,2.4,d.x-.6,3.2,d.y,lam('#2a3040')));
      for(const [x,z] of [[-1.9,-1],[-1.9,1],[.7,-1],[.7,1]])g.add(boxM(.12,3.2,.12,d.x+x,1.6,d.y+z,steel));
      const cab=new THREE.Mesh(mergeGeometries([box(1.1,.8,.8,0,0,0,'#c8301e'),box(.9,.3,.82,0,.12,0,'#1a2433'),box(.06,.6,.06,0,.7,0,'#2a2a2a')]),vcMat);cab.position.set(d.x+3.2,4.6,d.y);cab.castShadow=true;g.add(cab);
      const c1=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,26,3).rotateZ(Math.PI/2),lam('#151515'));c1.position.set(d.x+13,5.6,d.y);g.add(c1);
      o.cab=cab;
    }else if(d.type==='van'){"""

patch('js/render.js', [
    ("  for(let j=0;j<8;j++)for(let i=0;i<8;i++){\n    const x=i*S,y=j*S;\n",
     """  for(let j=0;j<8;j++)for(let i=0;i<8;i++){
    const x=i*S,y=j*S;
    if(pal>=6){
      if(rng()<.35){g.fillStyle=rng()<.5?'rgba(0,0,0,.1)':'rgba(255,255,255,.07)';g.fillRect(x,y,S,S);}
      g.fillStyle='rgba(0,0,0,.3)';g.fillRect(x,y+S-2,S,2);
      const lit=rng()<.35,col=lit?pick(['#ffcf7a','#ffd99a','#9fe8ff','#ff9ad8'],rng):(rng()<.5?'#14181f':'#3a2e28');
      g.fillStyle=col;g.fillRect(x+10,y+9,12,12);if(lit){ge.fillStyle=col;ge.fillRect(x+10,y+9,12,12);}
      g.fillStyle='rgba(0,0,0,.35)';g.fillRect(x+9,y+21,14,2);
      if(rng()<.12){g.fillStyle=pick(['#e0e0e0','#ff5a8a','#5ad0ff','#ffd040'],rng);g.globalAlpha=.5;g.fillRect(x+2,y+24,S-4,3);g.globalAlpha=1;}
      continue;
    }
"""),
    ("const roofGeoTank=cyl(.3,.3,.55,8,0,.28,0,'#4a3f36');roofGeoTank.userData.shared=true;",
     "const roofGeoTank=cyl(.3,.3,.55,8,0,.28,0,'#4a3f36');roofGeoTank.userData.shared=true;\nconst roofGeoTankBlue=cyl(.3,.3,.5,8,0,.25,0,'#2a6ab0');roofGeoTankBlue.userData.shared=true;"),
    ("    if(!b.kiosk&&b.fl>2&&b.roof>0){\n      const r=new THREE.Mesh(b.roof===1?roofGeoAC:roofGeoTank,vcMat);",
     "    if(!b.kiosk&&b.fl>=(b.favela?2:3)&&b.roof>0){\n      const r=new THREE.Mesh(b.roof===1?roofGeoAC:b.favela?roofGeoTankBlue:roofGeoTank,vcMat);"),
    ("    }else if(d.type==='van'){", DECOR3),
    ("  if(M.evac){evacRing=new THREE.Mesh(new THREE.RingGeometry(1.9,2.15,48),ringMat('#5dffa0'));evacRing.rotation.x=-Math.PI/2;evacRing.position.set(M.evac.x,.03,M.evac.y);world.add(evacRing);}else evacRing=null;",
     "  evacRing=(M.evacs||(M.evac?[M.evac]:[])).map(e=>{const r=new THREE.Mesh(new THREE.RingGeometry(1.9,2.15,48),ringMat('#5dffa0'));r.rotation.x=-Math.PI/2;r.position.set(e.x,.03,e.y);world.add(r);return r;});"),
    ("  if(evacRing){evacRing.material.opacity=.45+.35*Math.sin(M.t*4);}",
     "  if(evacRing)for(const r of evacRing)r.material.opacity=.45+.35*Math.sin(M.t*4);"),
    ("  if(M.evac){const p=toScreen(M.evac.x,M.evac.y,.05);c.fillStyle='#5dffa0';c.fillText('EVACUAÇÃO',p.x,p.y+4);}",
     "  for(const e of (M.evacs||(M.evac?[M.evac]:[]))){const p=toScreen(e.x,e.y,.05);c.fillStyle='#5dffa0';c.fillText('EVACUAÇÃO',p.x,p.y+4);}\n  for(const u of M.units)if(u.rival&&!u.dead){const p=toScreen(u.x,u.y,1.62);c.fillStyle=u.trim;c.fillText('▼ '+u.nome.toUpperCase(),p.x,p.y);}"),
    ("  const tall=(u.kind==='agente'||u.kind==='inimigo')?1.07:1;", "  const tall=u.rival?1.15:(u.kind==='agente'||u.kind==='inimigo')?1.07:1;"),
    ("  r.g.visible=!u.inCar;if(u.inCar)return;", "  r.g.visible=!u.inCar&&!u.vanished;if(u.inCar||u.vanished)return;"),
    ("    else if(u.fac==='corp')r.eye.material=basic(u.alerted?'#ff3040':'#ffaa3c');",
     "    else if(u.off)r.eye.material=basic('#202020');\n    else if(u.fac==='corp')r.eye.material=basic(u.alerted?'#ff3040':'#ffaa3c');"),
    ("  }else if(type==='tree'&&treeRefs){",
     "  }else if(type==='lampoff'&&lampRefs){\n    const i=M.lamps.indexOf(o);if(i<0)return;lampRefs.head.setColorAt(i,c3.set('#050505'));lampRefs.head.instanceColor.needsUpdate=true;lampT=0;\n  }else if(type==='tree'&&treeRefs){"),
    ("  // poças (reflexo)", "  if(M.paint)M.paint(g,TS);\n  // poças (reflexo)"),
])

# ---------------- interface ----------------
patch('js/ui.js', [
    ("import {startScript,runScript} from './script.js';",
     "import {startScript,runScript} from './script.js';\nimport {MSGS,unlock,ENDINGS,RIVALS} from './story.js';"),
    ("abates:0,vitoria:false,cientistas:3,", "abates:0,vitoria:false,rivais:{},msgs:[],cientistas:3,"),
    ("  G.esq=G.agentes.map(a=>a.id);save();", "  G.esq=G.agentes.map(a=>a.id);unlock(G,'inicio');save();"),
    ("if(g.cientistas===undefined)g.cientistas=3;", "if(g.cientistas===undefined)g.cientistas=3;g.rivais=g.rivais||{};g.msgs=g.msgs||[];"),
    ("  $('#mapSvg').innerHTML=s;renderMapSide();",
     "  $('#mapSvg').innerHTML=s;renderMapSide();\n  const un=(G.msgs||[]).filter(m=>!m.lida).length;$('#btnMsgs').textContent=un?`Interceptações (${un})`:'Interceptações';$('#btnMsgs').classList.toggle('pri',un>0);"),
    ("  const contra='',terrRep=terrNote+territoryTick(win?di:-1);",
     """  const contra='',terrRep=terrNote+territoryTick(win?di:-1);
  const novas=[],U=id=>{if(unlock(G,id))novas.push(id);};
  (M.rivalSeen?[...M.rivalSeen]:[]).forEach(id=>U(id+'_visto'));(M.rivalDead||[]).forEach(id=>U(id+'_morto'));
  if(win&&!M.revolta){if(di===0)U('docas');if(di===1)U('tanaka');}
  {const own=owned();if(own>=3)U('tres');if(own>=5)U('cinco');if(own>=7)U('sete');}
  if(DIST.some((d,i)=>d.hq&&avail(i)))U('hq');
  if(Object.values(G.terr||{}).some(t=>t.revolta))U('revolta');
  const rivNote=[...(M.rivalDead||[]).map(id=>`<p style="color:var(--green)">${RIVALS.find(r=>r.id===id).nome} está morto. Os Ponteiros perderam um dos seus.</p>`),...(M.rivalEsc||[]).map(id=>`<p style="color:var(--amber)">${RIVALS.find(r=>r.id===id).nome} escapou e vai voltar.</p>`)].join('');
  const msgNote=novas.length?`<p style="color:var(--cyan)">${novas.length} nova${novas.length>1?'s':''} mensage${novas.length>1?'ns':'m'} interceptada${novas.length>1?'s':''}. Veja em Interceptações no mapa.</p>`:'';"""),
    ("    <div class=\"labrep\">${lab}${terrRep}</div>", "    <div class=\"labrep\">${rivNote}${lab}${terrRep}${msgNote}</div>"),
    ("  const vitoria=win&&D.hq;if(vitoria)G.vitoria=true;", "  const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;unlock(G,'fim');}"),
    ("  const ok=$('#rsOk');if(ok)ok.onclick=()=>{hideModal();showMap();};",
     "  const ok=$('#rsOk');if(ok)ok.onclick=()=>{hideModal();if(vitoria&&!G.final)showFinalChoice();else showMap();};"),
    ("$('#btnSair').onclick=()=>showTitle();",
     r"""$('#btnSair').onclick=()=>showTitle();
$('#btnMsgs').onclick=()=>showInbox();
const escH=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function showInbox(){
  const list=(G.msgs||[]).slice().reverse();
  const riv=RIVALS.map(r=>{const s=(G.rivais||{})[r.id]||{};return `<span class="rv ${s.morto?'dead':''}" style="--c:${r.trim}">${r.nome}<small>${s.morto?'morto':s.fugas?`${s.fugas} fuga${s.fugas>1?'s':''}`:'à solta'}</small></span>`;}).join('');
  showModal(`<div class="eyebrow">Interceptações · ${list.length} mensage${list.length===1?'m':'ns'}</div><h2>Caixa de entrada</h2>
    <div class="rvs"><span class="l">Os Ponteiros</span>${riv}</div>
    <div class="inbox">${list.map(m=>{const d=MSGS[m.id];return `<button class="msg ${m.lida?'':'new'}" data-id="${m.id}"><span class="mf">${escH(d.de)}</span><span class="ms">${escH(d.assunto)}</span><span class="md mono">dia ${m.dia}</span></button>`;}).join('')||'<p class="hint">Nenhuma mensagem ainda.</p>'}</div>
    <div class="acts"><button class="btn pri" id="ibClose">Fechar</button></div>`,()=>{hideModal();renderMap();});
  $('#ibClose').onclick=()=>{hideModal();renderMap();};
  $('#mbox').querySelectorAll('.msg').forEach(b=>b.onclick=()=>showMsg(b.dataset.id));
}
function showMsg(id){
  const m=(G.msgs||[]).find(q=>q.id===id),d=MSGS[id];if(m)m.lida=true;save();
  showModal(`<div class="eyebrow">De ${escH(d.de)} · para ${escH(d.para)}</div><h2>${escH(d.assunto)}</h2>${d.corpo.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}
    <div class="acts"><button class="btn" id="mgBack">Voltar à caixa</button></div>`,showInbox);
  $('#mgBack').onclick=showInbox;
}
function showFinalChoice(){
  const d=MSGS.fim;
  showModal(`<div class="eyebrow">De ${escH(d.de)} · para ${escH(d.para)}</div><h2>${escH(d.assunto)}</h2>${d.corpo.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}
    <div class="acts"><button class="btn" id="fnDes">Destruir o Coral</button><button class="btn pri" id="fnAti">Ativar o Coral</button></div>`,null);
  const pickEnd=k=>{G.final=k;save();const e=ENDINGS[k];showModal(`<div class="eyebrow">Epílogo</div><h2>${e.titulo}</h2>${e.texto.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}<div class="acts"><button class="btn pri" id="epOk">Voltar ao mapa</button></div>`,null);$('#epOk').onclick=()=>{hideModal();showMap();};};
  $('#fnAti').onclick=()=>pickEnd('ativar');$('#fnDes').onclick=()=>pickEnd('destruir');
}"""),
])

patch('body.html', [
    ("      <button class=\"btn sm\" id=\"btnLab\">Laboratório</button>",
     "      <button class=\"btn sm\" id=\"btnLab\">Laboratório</button>\n      <button class=\"btn sm\" id=\"btnMsgs\">Interceptações</button>"),
])
patch('hud.css', [
    (".loy i{position:absolute;inset:0 auto 0 0;display:block}",
     """.loy i{position:absolute;inset:0 auto 0 0;display:block}
.inbox{display:flex;flex-direction:column;gap:6px;max-height:46vh;overflow:auto}
.msg{display:grid;grid-template-columns:1fr auto;gap:2px 12px;text-align:left;padding:10px 12px;border:1px solid var(--line);background:#0b0f19;cursor:pointer;color:var(--fg);font-family:var(--display)}
.msg:hover{border-color:var(--cyan)}
.msg .mf{font:12px var(--mono);color:var(--dim)}
.msg .ms{grid-column:1;font-weight:600}
.msg .md{grid-row:1/3;grid-column:2;align-self:center;font-size:11px;color:var(--dim)}
.msg.new{border-left:3px solid var(--cyan)}
.msg.new .ms::after{content:' · nova';color:var(--cyan);font:600 11px var(--mono)}
.rvs{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
.rvs .l{font:600 10px/1 var(--mono);letter-spacing:.2em;color:var(--dim);width:100%}
.rv{display:flex;flex-direction:column;border:1px solid var(--c);color:var(--c);padding:5px 8px;font-weight:600;font-size:13px}
.rv small{font:10px var(--mono);color:var(--dim)}
.rv.dead{opacity:.45;text-decoration:line-through}"""),
])
print('ok')
