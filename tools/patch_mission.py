"""Patch único: suporte a missões feitas à mão (registro da mudança)."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

# ---------------- core ----------------
patch('js/core.js', [
    ("export const T_ROAD=0,T_WALK=1,T_BLD=2,T_GRASS=3,T_PLAZA=4,T_TREE=5;",
     "export const T_ROAD=0,T_WALK=1,T_BLD=2,T_GRASS=3,T_PLAZA=4,T_TREE=5,T_WATER=6,T_FENCE=7,T_POST=8;"),
    ("  {nome:'Docas Velhas',renda:1500,dif:1,tipo:'assassinato',riq:.2,",
     "  {nome:'Docas Velhas',renda:1500,dif:1,tipo:'assassinato',riq:.2,mission:'docas',\n   brief:'Halvard Reis, diretor de logística do Consórcio, vem às Docas Velhas fechar um acordo com um contrabandista. Ele chega em comboio e passa sob o guindaste 2. Se a cabine do guindaste for invadida, o contêiner pendurado resolve o problema sem disparar um tiro. Mate Reis antes que ele volte ao carro ou fuja de lancha e retorne à van. Há um buraco na cerca a oeste.',\n   short:'Missão roteirizada: emboscada ao comboio de Halvard Reis no porto.',"),
])

# ---------------- mundo ----------------
patch('js/world.js', [
    ("import {N,P,NB,TAU,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,DX8,DY8,clamp,RNG,pick,shade,",
     "import {DOCAS} from './missions/docas.js';\nimport {N,P,NB,TAU,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,T_WATER,T_FENCE,T_POST,DX8,DY8,clamp,RNG,pick,shade,"),
    ("export function genMission(di,demo,squad){\n  const D=DIST[di],",
     """const MISSIONS={docas:DOCAS};
const isWalk=t=>t!==T_BLD&&t!==T_TREE&&t!==T_WATER&&t!==T_FENCE&&t!==T_POST;
function genHandcrafted(di,def,squad){
  const D=DIST[di],n=N,NN=n*n,idx=(x,y)=>y*n+x;
  const tile=new Uint8Array(NN).fill(T_WALK),hgt=new Uint8Array(NN),blds=[];
  const m={di,D,demo:false,hand:true,tipo:D.tipo,tile,hgt,walk:new Uint8Array(NN),road:new Uint8Array(NN),blds,units:[],agents:[],cars:[],terms:[],lamps:[],trees:[],props:[],drops:[],
    parts:[],tracers:[],texts:[],nades:[],flashes:[],marks:[],sel:[],spawn:{x:def.spawn.x,y:def.spawn.y},evac:null,escape:null,vip:null,sci:null,followers:0,
    policeAggro:0,lastSeen:null,corpAlert:false,reinfT:20,t:0,shake:0,paused:false,ended:false,endT:0,win:false,reason:'',
    stats:{abates:0,civis:0,policiais:0,seguidores:0},hover:null,decalsDirty:false,
    objs:[],flags:{},bonus:[],decor:[],piers:[],falling:[],co:[],camGoal:null,cine:false,timer:null,scriptDef:def};
  setM(m);
  const B={m,
    tile(x,y,t){tile[idx(x,y)]=t;},
    rect(t,x0,y0,x1,y1){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++)tile[idx(x,y)]=t;},
    pier(x0,y0,x1,y1){B.rect(T_PLAZA,x0,y0,x1,y1);m.piers.push({x0,y0,x1,y1});},
    bld(o){const b=Object.assign({pal:0,v:0,neon:-1,sign:null,roof:0,ou:0,ov:0},o);blds.push(b);for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++){tile[idx(x,y)]=T_BLD;hgt[idx(x,y)]=b.fl;}},
    lamp(x,y,col='#ffb35c',tall=false){m.lamps.push({x,y,col,tall});},
    tree(x,y){m.trees.push({x,y,s:1,r:x*7+y});tile[idx(x|0,y|0)]=T_TREE;},
    prop(x,y){m.props.push({x,y,hp:20,dead:false});},
    decor(o){m.decor.push(o);},
    term(o){m.terms.push(o);},
    unit(kind,x,y){return mkUnit(kind,x,y);},
    arm(u,dif){armAI(u,dif,Math.random);},
    randTile(pred){for(let k=0;k<400;k++){const x=(Math.random()*n)|0,y=(Math.random()*n)|0;if(pred(tile[idx(x,y)],x,y))return {x:x+.5,y:y+.5};}return null;},
    lanes(list,count){const cols=['#8a1f2e','#1f4f8a','#c9c2b0','#2c2f36','#e0a020','#3c6e5a','#d8d8dc'];for(let k=0;k<count;k++){const L=list[k%list.length],pos=Math.random()*n;const c={x:L.x!==undefined?L.x:pos,y:L.y!==undefined?L.y:pos,dx:L.dx,dy:L.dy,v:3.2+Math.random()*2,cur:3,hp:70,dead:false,col:pick(cols),stopT:0,smokeT:0,occ:[],player:false,held:0,path:null,pi:0};c.ang=Math.atan2(c.dy,c.dx);m.cars.push(c);}},
  };
  def.build(B);
  for(let i=0;i<NN;i++){m.walk[i]=isWalk(tile[i])?1:0;m.road[i]=tile[i]===T_ROAD?1:0;}
  if(squad){const offs=[[-.5,-.5],[.5,-.5],[-.5,.5],[.5,.5]];squad.forEach((a,k)=>mkAgent(a,m.spawn.x+offs[k][0],m.spawn.y+offs[k][1],k));}
  return m;
}

export function genMission(di,demo,squad){
  if(!demo&&DIST[di].mission&&MISSIONS[DIST[di].mission])return genHandcrafted(di,MISSIONS[DIST[di].mission],squad);
  const D=DIST[di],"""),
])

# ---------------- áudio ----------------
patch('js/audio.js', [
    ("let onComm=null;export function setCommHandler(f){onComm=f;}",
     "let onComm=null;export function setCommHandler(f){onComm=f;}\nexport function commFree(){return performance.now()/1000>=commBusyUntil&&!commQueue.length;}"),
    ("    if(key.startsWith('ctl:')&&commQueue.length<2)commQueue.push({key,u,t:now});",
     "    if(key.startsWith('ctl:')&&commQueue.length<3)commQueue.push({key,u,t:now});"),
])

# ---------------- simulação ----------------
patch('js/sim.js', [
    ("function updCiv(u,dt){\n  if(u.panicT>0){",
     "function updCiv(u,dt){\n  if(u.still&&u.panicT<=0)return;\n  if(u.panicT>0){"),
    ("  wander(u,dt,u.x,u.y,10,1,sideTile);\n}",
     "  if(u.home)wander(u,dt,u.home.x,u.home.y,6,1,sideTile);else wander(u,dt,u.x,u.y,10,1,sideTile);\n}"),
    ("function updVip(u,dt){\n  if(!M.corpAlert&&!u.alerted){\n    detect(u,dt,6,3);",
     "function updVip(u,dt){\n  if(u.scripted&&!M.corpAlert&&!u.alerted){detect(u,dt,6,3);moveAlong(u,dt,u.spd);return;}\n  if(!M.corpAlert&&!u.alerted){\n    detect(u,dt,6,3);"),
    ("    if(tm.prog>=4){tm.done=true;hooks.vo('ctl:term');log(",
     "    if(tm.prog>=4){tm.done=true;if(tm.crane){M.flags.crane=true;hooks.vo('ctl:m1_crane');log('Cabine do guindaste invadida. Tecla G solta o contêiner.','cyan');sfx('hack');flags.hud=true;continue;}hooks.vo('ctl:term');log("),
    ("function checkEnd(){\n  if(!M.agents.some(a=>!a.dead))return endMission(false,'Todo o esquadrão foi abatido.');",
     "function checkEnd(){\n  if(!M.agents.some(a=>!a.dead))return endMission(false,'Todo o esquadrão foi abatido.');\n  if(M.hand)return;"),
    ("    if(u.hjT>0){u.hjT-=dt;u.path=null;continue;}",
     "    if(u.inCar&&u.kind!=='agente'){u.x=u.inCar.x;u.y=u.inCar.y;continue;}\n    if(u.hjT>0){u.hjT-=dt;u.path=null;continue;}"),
    ("  separate();updCars(dt);updNades(dt);updFx(dt);",
     "  separate();updCars(dt);updNades(dt);updFx(dt);if(M.falling)updFalling(dt);"),
    ("    if(c.player){driveCar(c,dt);continue;}",
     "    if(c.player||c.scripted){driveCar(c,dt);continue;}"),
    ("  if(c.cur>2.5){\n    const drv=",
     "  if(c.scripted&&c.cur>.5)for(const u of M.units){if(u.dead||u.inCar||u.kind==='torre')continue;const rx=u.x-c.x,ry=u.y-c.y,f=rx*ndx+ry*ndy,l=rx*ndy-ry*ndx;if(Math.abs(f)<1&&Math.abs(l)<.55){const s=l>=0?1:-1,px=u.x+ndy*s*.12,py=u.y-ndx*s*.12;if(canStand(px,py)){u.x=px;u.y=py;}}}\n  if(c.player&&c.cur>2.5){\n    const drv="),
    ("/* ---------- ordens do jogador ---------- */",
     """/* ---------- guindaste: contêiner em queda ---------- */
export function dropContainer(){
  if(!M.flags||!M.flags.crane||M.flags.dropped||!M.dropPoint)return;
  M.flags.dropped=true;M.falling.push({x:M.dropPoint.x,y:M.dropPoint.y,t:0,T:.8});sfx('door',M.dropPoint.x,M.dropPoint.y);flags.hud=true;
}
function updFalling(dt){
  for(const f of M.falling){
    if(f.landed)continue;f.t+=dt;if(f.t<f.T)continue;f.landed=true;
    const src=M.agents.find(a=>!a.dead)||null;
    sfx('boom',f.x,f.y);M.shake=Math.min(1,M.shake+.8);
    for(let i=0;i<30;i++){const a=Math.random()*TAU,s=1+Math.random()*3;part(f.x+Math.cos(a)*.8,f.y+Math.sin(a)*.4,6,Math.cos(a)*s,Math.sin(a)*s,10+Math.random()*25,1.4+Math.random(),'#5a5650',1,2);}
    for(let i=0;i<20;i++){const a=Math.random()*TAU,s=2+Math.random()*4;part(f.x,f.y,10,Math.cos(a)*s,Math.sin(a)*s,40+Math.random()*50,.7,'#ffdc96',1,3);}
    for(const c of M.cars)if(!c.dead&&Math.abs(c.x-f.x)<1.8&&Math.abs(c.y-f.y)<1.1){c.hp=1;hurtCar(c,999,src);}
    const vipAlive=M.vip&&!M.vip.dead;
    for(const u of M.units)if(!u.dead&&!u.inCar&&Math.abs(u.x-f.x)<1.7&&Math.abs(u.y-f.y)<1)hurt(u,999,src);
    if(vipAlive&&M.vip.dead)M.flags.accident=true;
    for(let x=Math.floor(f.x-1.4);x<=Math.floor(f.x+1.4);x++){const i=Math.floor(f.y)*N+x;M.tile[i]=T_BLD;M.walk[i]=0;M.road[i]=0;}
    hooks.decal('scorch',f.x,f.y,1.6);
  }
}

/* ---------- ordens do jogador ---------- */"""),
])

# ---------------- interface ----------------
patch('js/ui.js', [
    ("import {say,update,updateWorld,setSel,",
     "import {startScript,runScript} from './script.js';\nimport {dropContainer,say,update,updateWorld,setSel,"),
    ("  for(const c of M.cars){if(c.dead)continue;const p=toScreen(c.x,c.y,.4)",
     "  for(const c of M.cars){if(c.dead||c.scripted)continue;const p=toScreen(c.x,c.y,.4)"),
    ("cv.addEventListener('pointerdown',e=>{\n  if(state!=='jogo')return;audioInit();",
     "cv.addEventListener('pointerdown',e=>{\n  if(state!=='jogo')return;audioInit();\n  if(M.cine){M.cineSkip=true;return;}"),
    ("  keys[e.code]=true;const k=e.code;",
     "  keys[e.code]=true;const k=e.code;\n  if(M.cine){if(k==='Space'||k==='Escape'||k==='Enter'){e.preventDefault();M.cineSkip=true;}return;}\n  if(k==='KeyG'){dropContainer();return;}"),
    ("function objectiveText(){",
     """function objectiveHtml(){
  const esc=s=>s.replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
  let h=M.objs.filter(o=>o.primary||o.state!=='hidden').map(o=>`<span class="ob ${o.state} ${o.primary?'pri':''}">${o.state==='done'?'✓':o.state==='failed'?'✗':o.primary?'◆':'○'} ${esc(o.text)}</span>`).join('');
  if(M.timer){const s=Math.max(0,Math.ceil(M.timer.end-M.t));h+=`<span class="ob timer">${esc(M.timer.label)} ${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}</span>`;}
  return h;
}
function objectiveText(){
  if(M.hand){const o=M.objs.find(q=>q.primary&&q.state==='active');return o?o.text:'';}"""),
    ("  $('#objTxt').textContent=objectiveText();",
     "  if(M.hand)$('#objTxt').innerHTML=objectiveHtml();else $('#objTxt').textContent=objectiveText();\n  $('#hud').classList.toggle('cine',!!M.cine);\n  $('#btnDrop').hidden=!(M.flags&&M.flags.crane&&!M.flags.dropped);"),
    ("$('#btnExit').addEventListener('click',()=>exitSelected());",
     "$('#btnExit').addEventListener('click',()=>exitSelected());\n$('#btnDrop').addEventListener('click',()=>dropContainer());"),
    ("  genMission(i,false,squad);buildScene();",
     "  genMission(i,false,squad);buildScene();startScript();"),
    ("  log(`Inserção em ${M.D.nome}. ${TIPOS[M.tipo]}.`,'cyan');setTimeout(()=>hooks.vo('ctl:ins'),600);",
     "  log(`Inserção em ${M.D.nome}. ${M.hand?M.scriptDef.nome:TIPOS[M.tipo]}.`,'cyan');if(!M.hand)setTimeout(()=>hooks.vo('ctl:ins'),600);"),
    ("      panCamera(dt);if(!M.paused)update(dt);",
     """      if(!M.cine)panCamera(dt);if(!M.paused){update(dt);runScript();}
      if(M.camGoal){const g=M.camGoal;if(!g.from)g.from={x:camS.x,y:camS.y,z:camS.zoom};g.t+=dt;if(M.cineSkip)g.t=g.dur;const k=g.dur>0?Math.min(1,g.t/g.dur):1,e=k<.5?2*k*k:1-Math.pow(-2*k+2,2)/2;
        camS.x=g.from.x+(g.x-g.from.x)*e;camS.y=g.from.y+(g.y-g.from.y)*e;camS.zoom=g.from.z+(g.z-g.from.z)*e;if(k>=1&&!M.cine)M.camGoal=null;}"""),
    ("  if(win){G.dono[di]='player';reward=D.recompensa;G.dinheiro+=reward;}",
     "  const bonus=(M.bonus||[]).reduce((s,b)=>s+b.val,0);\n  if(win){G.dono[di]='player';reward=D.recompensa+bonus;G.dinheiro+=reward;}"),
    ("<dt>Recompensa</dt><dd>${fmt(reward)}</dd><dt>Renda dos distritos</dt>",
     "${(M.bonus||[]).map(b=>`<dt>Bônus · ${b.text}</dt><dd>${fmt(b.val)}</dd>`).join('')}<dt>Recompensa total</dt><dd>${fmt(reward)}</dd><dt>Renda dos distritos</dt>"),
    ("  return base+' Armas à mostra atraem a polícia.",
     "  if(d.brief)return d.brief;\n  return base+' Armas à mostra atraem a polícia."),
    ("    case 'assassinato':return `Alvo: ${nm.vip}. Elimine-o antes que alcance o transporte de fuga.`;",
     "    case 'assassinato':if(d.short)return d.short;return `Alvo: ${nm.vip}. Elimine-o antes que alcance o transporte de fuga.`;"),
])
patch('body.html', [
    ("    <button id=\"btnExit\" hidden>SAIR DO<br>VEÍCULO · V</button>",
     "    <button id=\"btnExit\" hidden>SAIR DO<br>VEÍCULO · V</button>\n    <button id=\"btnDrop\" hidden>SOLTAR<br>CONTÊINER · G</button>"),
])
patch('hud.css', [
    ("#sub b{font-weight:600;letter-spacing:.08em}",
     "#sub b{font-weight:600;letter-spacing:.08em}\n#btnDrop{font:600 11px/1.2 var(--mono);letter-spacing:.1em;padding:10px 12px;background:#2a1606;border:1px solid var(--amber);color:var(--amber);cursor:pointer;animation:blink 1s steps(2) infinite}\n#objTxt .ob{display:block;font-size:13px;line-height:1.45}\n#objTxt .ob.pri{font-size:15px}\n#objTxt .ob:not(.pri){color:var(--dim)}\n#objTxt .ob.done{color:var(--green)}\n#objTxt .ob.failed{color:#7a4a52;text-decoration:line-through}\n#objTxt .ob.timer{color:var(--amber);font-family:var(--mono);font-size:13px}\n#hud.cine #hudBot,#hud.cine #keysHint,#hud.cine #hudTop,#hud.cine #miniBox{opacity:0;pointer-events:none}\n#hudBot,#hudTop,#miniBox{transition:opacity .5s}"),
])
print('ok')
