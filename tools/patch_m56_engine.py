"""Patch único: motor para as missões 5 e 6 — drones, saídas de vapor, paredes de vidro, sósias, reatores, helicóptero."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, marker, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    if marker in s:
        print('já aplicado:', fn); return
    for a, b, *flag in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b) if flag else s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('ok:', fn)

patch('js/core.js', 'T_GLASS=9', [
    ("T_FENCE=7,T_POST=8;", "T_FENCE=7,T_POST=8,T_GLASS=9;"),
    ("  torre:{fac:'corp',hp:160,spd:0,w:'smg',acc:.6,armor:.3},",
     "  torre:{fac:'corp',hp:160,spd:0,w:'smg',acc:.6,armor:.3},\n  drone:{fac:'corp',hp:60,spd:2.8,w:'smg',acc:.5,armor:.15},"),
    ("  {nome:'Setor Industrial 9',renda:2400,dif:4,tipo:'sabotagem',riq:.3,",
     "  {nome:'Setor Industrial 9',renda:2400,dif:4,tipo:'sabotagem',riq:.3,mission:'fundicao',\n   brief:'A Fundição Hélice do Setor Industrial 9 abastece metade das fábricas do Consórcio. Instale cargas nos três reatores da planta. Depois da terceira carga, vocês têm 45 segundos para voltar ao portão antes da reação em cadeia. As saídas de vapor da tubulação disparam em ciclos e queimam quem estiver perto, aliado ou inimigo. Drones de segurança patrulham o pátio: a Chave Fantasma consegue invadi-los. O Ferro-Velho guarda o reator central.',\n   short:'Missão roteirizada: sabotagem numa fundição com vapor, drones e contagem regressiva.',"),
    ("  {nome:'Distrito Lúmen',renda:3600,dif:5,tipo:'assassinato',riq:.7,",
     "  {nome:'Distrito Lúmen',renda:3600,dif:5,tipo:'assassinato',riq:.7,mission:'lumen',\n   brief:'Otávio Brandt, diretor financeiro do Consórcio, dá uma festa no pavilhão de vidro da Praça Lúmen. Ele sabe que é alvo: dois sósias idênticos circulam com ele. De perto, o scanner de implantes do esquadrão distingue o verdadeiro. O terminal da guarita de segurança revela os três de uma vez. Atirar em qualquer um dispara o alarme, e o alvo corre para o helicóptero no heliporto. As paredes do pavilhão são de vidro e não seguram balas.',\n   short:'Missão roteirizada: assassinato numa festa, com sósias e helicóptero de fuga.',"),
])

patch('js/world.js', 'fundicao:FUNDICAO', [
    ("import {NEON as MIS_NEON} from './missions/neon.js';",
     "import {NEON as MIS_NEON} from './missions/neon.js';\nimport {FUNDICAO} from './missions/fundicao.js';\nimport {LUMEN} from './missions/lumen.js';"),
    ("mercado:MERCADO,neon:MIS_NEON};", "mercado:MERCADO,neon:MIS_NEON,fundicao:FUNDICAO,lumen:LUMEN};"),
    ("T_FENCE,T_POST,DX8", "T_FENCE,T_POST,T_GLASS,DX8"),
    ("&&t!==T_FENCE&&t!==T_POST;", "&&t!==T_FENCE&&t!==T_POST&&t!==T_GLASS;"),
    ("cams:[],rail:null,train:null,trainT:12,", "cams:[],rail:null,train:null,trainT:12,vents:[],glassN:0,"),
    ("  if(kind==='cientista'){u.coat='#e6edf4';u.trim='#5dffa0';u.legs='#2b3240';u.long=true;}",
     "  if(kind==='cientista'){u.coat='#e6edf4';u.trim='#5dffa0';u.legs='#2b3240';u.long=true;}\n  if(kind==='torre'||kind==='drone')u.mech=true;\n  if(kind==='drone')u.fly=true;"),
    ("    monorail(y,xs){",
     "    vent(x,y,o){m.vents.push(Object.assign({x,y,per:7,dur:2.2,ph:Math.random()*7,r:1.15,dmg:60,state:0},o||{}));},\n"
     "    drone(x,y,route,dif){const u=mkUnit('drone',x,y);u.route=route||null;u.ri=0;if(dif){u.acc=.42+dif*.03;u.hp=u.maxHp=50+dif*5;}return u;},\n"
     "    glass(x0,y0,x1,y1){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){if(tile[idx(x,y)]!==T_GLASS)m.glassN++;tile[idx(x,y)]=T_GLASS;}},\n"
     "    monorail(y,xs){"),
])

SIM = r"""
/* ---------- drones de segurança ---------- */
function flyTo(u,x,y,dt,spd){
  const dx=x-u.x,dy=y-u.y,d=Math.hypot(dx,dy);if(d<.2){u.curSpd=0;return true;}
  const s=Math.min(d,spd*dt);u.x=clamp(u.x+dx/d*s,1,N-1);u.y=clamp(u.y+dy/d*s,1,N-1);u.curSpd=spd;
  if(!(u.aimT>0))u.face=Math.atan2(dy,dx);
  return false;
}
function orbit(u,p,R,dt){
  const dir=u.id%2?1:-1,a=Math.atan2(u.y-p.y,u.x-p.x)+.45*dir;
  for(const r of [R,R*.7,R*.45]){const tx=p.x+Math.cos(a)*r,ty=p.y+Math.sin(a)*r;if(canStand(tx,ty)){flyTo(u,tx,ty,dt,u.spd);return;}}
  flyTo(u,p.x,p.y,dt,u.spd*.5);
}
function updDrone(u,dt){
  u.path=null;
  if(u.fac==='player'){
    const t=nearestHostile(u,7.5);if(t){const p=posOf(t);aimAt(u,p.x,p.y);fireWeapon(u,u.w,u,p.x,p.y);}
    const a=nearestAgent(u,999);
    if(a){const p=posOf(a);if(Math.hypot(p.x-u.x,p.y-u.y)>2.4)flyTo(u,p.x+Math.cos(u.id)*1.3,p.y+Math.sin(u.id)*1.3,dt,u.spd*1.2);else u.curSpd=0;}
    return;
  }
  if(!u.alerted){
    detect(u,dt,7.5,4.2);
    if(!u.alerted&&M.corpAlert&&nearestAgent(u,14))u.alerted=true;
    if(!u.alerted){
      const r=u.route;
      if(r&&r.length){const p=r[u.ri%r.length];if(flyTo(u,p.x,p.y,dt,u.spd*.55))u.ri++;}
      else{u.face+=dt*.8;u.curSpd=0;}
      return;
    }
  }
  let t=u.tgt;
  if(t&&(t.dead||!isEnemyOf(u,t)||(t.cloak&&Math.hypot(t.x-u.x,t.y-u.y)>1.5)))t=u.tgt=null;
  u.scanT-=dt;if(u.scanT<=0){u.scanT=.35;const nt=nearestHostile(u,9.5);if(nt)t=u.tgt=nt;}
  if(t){
    const p=posOf(t),d=Math.hypot(p.x-u.x,p.y-u.y);u.lkp={x:p.x,y:p.y};orbit(u,p,4.6,dt);
    if(d<8.5&&los(u.x,u.y,p.x,p.y)){aimAt(u,p.x,p.y);fireWeapon(u,u.w,u,p.x,p.y,u.supp>0?.6:1);}
    return;
  }
  let g=u.lkp;if(!g){const a=nearestAgent(u,22);if(a)g=posOf(a);}
  if(g){if(flyTo(u,g.x,g.y,dt,u.spd))u.lkp=null;}else u.curSpd=0;
}
/* ---------- saídas de vapor ---------- */
function updVents(dt){
  const over=(M.ventOver||0)>M.t;
  for(const v of M.vents){
    if(v.off){v.state=0;continue;}
    const ph=over?v.per:(M.t+v.ph)%v.per,b0=v.per-v.dur,warn=!over&&ph>b0-1.2&&ph<b0,burst=over||ph>=b0;
    v.state=burst?2:warn?1:0;
    if(warn&&Math.random()<.35)part(v.x+(Math.random()-.5)*.4,v.y+(Math.random()-.5)*.4,3,0,0,12,.6,'#b8c0c8',1,2);
    if(!burst){v.was=false;continue;}
    if(!v.was){v.was=true;sfx('steam',v.x,v.y);}
    for(let k=0;k<3;k++)part(v.x+(Math.random()-.5)*.5,v.y+(Math.random()-.5)*.5,4,(Math.random()-.5)*.9,(Math.random()-.5)*.9,55+Math.random()*50,.9+Math.random()*.6,'#e8eef4',1,2);
    v.tick=(v.tick||0)-dt;
    if(v.tick<=0){v.tick=.25;for(const u of M.units)if(!u.dead&&!u.inCar&&!u.mech&&Math.hypot(u.x-v.x,u.y-v.y)<v.r){hurt(u,v.dmg*.25,over?M.ventSrc:null);if(u.kind==='civil'&&!u.follower)u.panicT=3;}}
  }
}
/* ---------- paredes de vidro ---------- */
function shatterGlass(tx,ty){
  const i=ty*N+tx;if(M.tile[i]!==T_GLASS)return;
  M.tile[i]=T_PLAZA;M.walk[i]=1;M.glassN--;
  for(let k=0;k<14;k++)part(tx+.5+(Math.random()-.5)*.8,ty+.5+(Math.random()-.5)*.8,10+Math.random()*35,(Math.random()-.5)*3,(Math.random()-.5)*3,Math.random()*20,1.6,'#bfe8ff',1,3);
  sfx('glass',tx+.5,ty+.5);hooks.destroy('glasswall',{x:tx,y:ty});hooks.decal('shards',tx+.5,ty+.5,.6);
  for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const x=tx+dx,y=ty+dy;if(x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_GLASS&&Math.random()<.35)(M.glassQ||(M.glassQ=[])).push({x,y,t:M.t+.08+Math.random()*.15});}
  noise(tx+.5,ty+.5,5,null);
}
function updGlass(){const q=M.glassQ;M.glassQ=[];for(const g of q){if(M.t>=g.t)shatterGlass(g.x,g.y);else M.glassQ.push(g);}}
function updDecorFx(dt){
  for(const d of M.decor){
    if(d.type==='chimney'&&!d.dead){if(Math.random()<dt*5)part(d.x+(Math.random()-.5)*.3,d.y+(Math.random()-.5)*.3,(d.h||7)*30,.4,.15,8+Math.random()*6,3+Math.random()*2,'#3a3a40',1,2);}
    else if(d.type==='fountain'&&!M.flags.fountainOff){if(Math.random()<dt*30)part(d.x+(Math.random()-.5)*.2,d.y+(Math.random()-.5)*.2,32,(Math.random()-.5)*1.4,(Math.random()-.5)*1.4,40+Math.random()*30,.9,'#bfe8ff',1,3);}
  }
}
"""

patch('js/sim.js', 'function updDrone(', [
    ("T_WATER,T_FENCE,clamp,", "T_WATER,T_FENCE,T_GLASS,clamp,"),
    ("hooks.vo(v.kind==='inimigo'?'ene:alert':'grd:alert',v);", "if(v.mech)hooks.vo('ctl:drone');else hooks.vo(v.kind==='inimigo'?'ene:alert':'grd:alert',v);"),
    ("(v.kind==='torre'?.38:.3)", "(v.mech?.38:.3)"),
    ("  const ex=u.x+dx*bt,ey=u.y+dy*bt;",
     "  if(M.glassN>0)for(let s=.25;s<bt;s+=.2){const gx=Math.floor(u.x+dx*s),gy=Math.floor(u.y+dy*s);if(gx>=0&&gy>=0&&gx<N&&gy<N&&M.tile[gy*N+gx]===T_GLASS)shatterGlass(gx,gy);}\n  const ex=u.x+dx*bt,ey=u.y+dy*bt;"),
    ("if(v.kind!=='torre')sfx('hit',v.x,v.y);", "if(!v.mech)sfx('hit',v.x,v.y);else if(Math.random()<.5)sfx('ric',v.x,v.y);"),
    ("if(v.kind!=='torre'&&Math.random()<.6)part(v.x,v.y,16", "if(!v.mech&&Math.random()<.6)part(v.x,v.y,16"),
    ("if(v.kb&&v.kb.p>.12&&v.kind!=='torre'){", "if(v.kb&&v.kb.p>.12&&!v.mech){"),
    ("  sfx('die',v.x,v.y);\n  if(v.kind==='torre'){explode(v.x,v.y,1.2,25,src);return;}",
     "  if(!v.mech)sfx('die',v.x,v.y);\n  if(v.kind==='torre'){explode(v.x,v.y,1.2,25,src);return;}\n  if(v.kind==='drone'){explode(v.x,v.y,.9,14,src);spawnDebris(v.x,v.y,1.4,6,['#2a2f3a','#d8dce4','#111318'],3,[.06,.16]);if(src&&src.fac==='player'&&v.fac!=='player')M.stats.abates++;return;}"),
    ("function explode(x,y,r,dmg,src){", "export function explode(x,y,r,dmg,src){"),
    ("      case 'torre':updTurret(u,dt);break;", "      case 'torre':updTurret(u,dt);break;\n      case 'drone':updDrone(u,dt);break;"),
    ("if(a.dead||a.inCar||a.kind==='torre')continue;", "if(a.dead||a.inCar||a.mech)continue;"),
    ("if(b.dead||b.inCar||b.kind==='torre')continue;", "if(b.dead||b.inCar||b.mech)continue;"),
    ("||u.kind==='torre'", "||u.mech", 'all'),
    ("&&u.kind!=='torre'&&Math.abs(u.x-f.x)", "&&!u.mech&&Math.abs(u.x-f.x)"),
    ("if(w&&w.hack&&t.kind==='torre'&&t.fac==='corp')", "if(w&&w.hack&&t.mech&&t.fac==='corp')"),
    ("t.fac='player';t.alerted=false;t.tgt=null;t.hackP=0;log('Torreta invadida: agora ela protege o esquadrão.','cyan');",
     "t.fac='player';t.alerted=false;t.tgt=null;t.lkp=null;t.hackP=0;log(t.kind==='drone'?'Drone invadido: agora ele protege o esquadrão.':'Torreta invadida: agora ela protege o esquadrão.','cyan');"),
    ("if(!u.fleeing){u.fleeing=true;u.path=null;log(", "if(!u.fleeing){u.fleeing=true;u.path=null;if(!u.double)log("),
    ("hooks.vo('vip:flee',u);hooks.vo('ctl:target');}", "if(!u.double){hooks.vo('vip:flee',u);hooks.vo('ctl:target');}}"),
    ("<1.3&&!M.ended)endMission(false,`${u.nome} alcançou o transporte e escapou.`);",
     "<1.3&&!M.ended){if(u.double){u.dead=true;u.vanished=true;u.hp=0;}else{M.flags.heliGo=true;endMission(false,`${u.nome} alcançou o transporte e escapou.`);}}"),
    ("    detect(u,dt,6,3);\n    if(!u.path){u.idleT", "    detect(u,dt,6,u.cand?1.3:3);\n    if(!u.path){u.idleT"),
    ("    if(t===T_FENCE){M.tile[i]=T_WALK;", "    if(t===T_GLASS)shatterGlass(tx,ty);\n    else if(t===T_FENCE){M.tile[i]=T_WALK;"),
    ("if(M.cams&&M.cams.length)updCams(dt);updTrain(dt);",
     "if(M.cams&&M.cams.length)updCams(dt);updTrain(dt);if(M.vents&&M.vents.length)updVents(dt);if(M.glassQ&&M.glassQ.length)updGlass();if(M.decor&&M.decor.length)updDecorFx(dt);"),
    ("\n/* ---------- câmeras de segurança ---------- */", SIM + "\n/* ---------- câmeras de segurança ---------- */"),
])

patch('js/script.js', 'boom(x,y,r,dmg)', [
    ("import {endMission} from './sim.js';", "import {endMission,explode} from './sim.js';"),
    ("    lampOff(l){hooks.destroy('lampoff',l);},",
     "    lampOff(l){hooks.destroy('lampoff',l);},\n    boom(x,y,r,dmg){explode(x,y,r,dmg,M.agents.find(a=>!a.dead)||null);},"),
])

patch('js/audio.js', "case 'steam':", [
    ("    case 'train':{", "    case 'steam':{const o=chain(sp,.15);noise(o,.9,3400,.5,.2*v,'highpass');noise(o,.7,1100,.7,.1*v);break;}\n    case 'train':{"),
])

patch('js/ui.js', "case 'drone':", [
    ("    case 'vip':return `ALVO: ${u.nome}`;",
     "    case 'vip':return u.cand&&!u.scanned&&u!==M.vip?'Alvo ou sósia? (aproxime-se para escanear)':u.double?`Sósia de ${u.nome}`:`ALVO: ${u.nome}`;\n    case 'drone':return u.fac==='player'?'Drone (invadido)':u.alerted?'Drone de segurança (caçando)':'Drone de segurança · use a Chave Fantasma';"),
    ("const p=toScreen(u.x,u.y,.55),d=Math.hypot(p.x-sx,p.y-sy);if(d<bd){bd=d;best=u;}}",
     "const p=toScreen(u.x,u.y,u.fly?1.45:.55),d=Math.hypot(p.x-sx,p.y-sy);if(d<bd){bd=d;best=u;}}"),
])

RENDER_DECOR = r"""
    }else if(d.type==='pipe'){
      const L=Math.hypot(d.x2-d.x1,d.y2-d.y1),a=Math.atan2(d.y2-d.y1,d.x2-d.x1),R=d.r||.18,H=d.h||2.2;
      const p=new THREE.Mesh(new THREE.CylinderGeometry(R,R,L,8).rotateZ(Math.PI/2),lam(d.col||'#6a5a48'));p.position.set((d.x1+d.x2)/2,H,(d.y1+d.y2)/2);p.rotation.y=-a;p.castShadow=true;g.add(p);
      const n=Math.max(1,Math.round(L/4));for(let k=0;k<=n;k++){const t=k/n;g.add(boxM(.12,H,.12,d.x1+(d.x2-d.x1)*t,H/2,d.y1+(d.y2-d.y1)*t,lam('#2a2f3a')));}
    }else if(d.type==='chimney'){
      const H=d.h||7,m=new THREE.Mesh(mergeGeometries([cyl(.45,.6,H,10,0,H/2,0,'#5a4a42'),cyl(.47,.47,.35,10,0,H*.8,0,'#c8301e'),cyl(.47,.47,.35,10,0,H*.6,0,'#e8e4dc'),cyl(.5,.5,.2,10,0,H,0,'#2a2a2a')]),vcMat);m.castShadow=true;g.add(m);
      const l=new THREE.Mesh(new THREE.SphereGeometry(.07,6,4),blinkMat);l.position.set(0,H+.15,0);g.add(l);g.position.set(d.x,0,d.y);
    }else if(d.type==='reactor'){
      const R=d.r||1.3,body=new THREE.Mesh(mergeGeometries([cyl(R,R*1.05,2.4,16,0,1.2,0,'#4a505c'),cyl(R*1.08,R*1.08,.25,16,0,.4,0,'#2a2f3a'),cyl(R*1.08,R*1.08,.25,16,0,2.1,0,'#2a2f3a'),cyl(R*.6,R*.8,.6,12,0,2.7,0,'#3a404e')]),vcMat);body.castShadow=true;g.add(body);
      const core=new THREE.Mesh(new THREE.CylinderGeometry(R*1.01,R*1.01,.18,16,1,true),new THREE.MeshBasicMaterial({color:'#38e8ff',toneMapped:false}));core.position.y=1.3;g.add(core);
      const pl=new THREE.PointLight('#38e8ff',3,6,1.6);pl.position.y=1.6;g.add(pl);
      g.position.set(d.x,0,d.y);o.core=core;o.light=pl;
    }else if(d.type==='heli'){
      const body=new THREE.Mesh(mergeGeometries([box(1.5,.7,.8,0,.6,0,'#d8dce4'),box(.6,.45,.7,.85,.55,0,'#1a2433'),box(1.6,.18,.18,-1.4,.75,0,'#d8dce4'),box(.08,.5,.3,-2.15,.95,0,'#c8301e'),box(1.4,.06,.06,0,.15,.4,'#2a2a2a'),box(1.4,.06,.06,0,.15,-.4,'#2a2a2a')]),vcMat);body.castShadow=true;
      const rotor=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(3.6,.03,.14),new THREE.BoxGeometry(.14,.03,3.6)]),lam('#15181f'));rotor.position.y=1.05;
      const hg=new THREE.Group();hg.add(body,rotor);g.add(hg);g.position.set(d.x,0,d.y);g.rotation.y=-(d.ang||0);o.heli=hg;o.rotor=rotor;o.lift=0;
    }else if(d.type==='fountain'){
      const st=lam('#c8ccd4');
      g.add(new THREE.Mesh(mergeGeometries([cyl(.2,.3,1,10,d.x,.5,d.y,'#c8ccd4'),cyl(.6,.5,.12,12,d.x,1,d.y,'#c8ccd4')]),vcMat));
      const w=d.x1-d.x0+1,h=d.y1-d.y0+1,cx=(d.x0+d.x1+1)/2,cy=(d.y0+d.y1+1)/2;
      g.add(boxM(w+.3,.3,.15,cx,.15,d.y0-.05,st),boxM(w+.3,.3,.15,cx,.15,d.y1+1.05,st),boxM(.15,.3,h,d.x0-.05,.15,cy,st),boxM(.15,.3,h,d.x1+1.05,.15,cy,st));
"""

RENDER_SEC = r"""let ventObjs=[],glassRefs=null;
const grateTex=(()=>{const c=document.createElement('canvas');c.width=c.height=32;const g=c.getContext('2d');g.fillStyle='#1a1c22';g.fillRect(0,0,32,32);g.fillStyle='#c8ccd4';for(let i=3;i<32;i+=5)g.fillRect(2,i,28,2);g.strokeStyle='#c8ccd4';g.lineWidth=2;g.strokeRect(1,1,30,30);const t=new THREE.CanvasTexture(c);t.magFilter=THREE.NearestFilter;return t;})();
function buildGlassVents(){
  ventObjs=[];glassRefs=null;
  for(const v of M.vents||[]){
    const m=new THREE.Mesh(new THREE.PlaneGeometry(.9,.9).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({map:grateTex,color:'#55606e',toneMapped:false}));m.position.set(v.x,.025,v.y);world.add(m);
    ventObjs.push({v,m});
  }
  const gt=[];for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(M.tile[y*N+x]===T_GLASS)gt.push([x,y]);
  if(!gt.length)return;
  const isG=(x,y)=>x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_GLASS;
  const pane=new THREE.InstancedMesh(new THREE.BoxGeometry(1,1.6,.06),new THREE.MeshLambertMaterial({color:'#9fe8ff',transparent:true,opacity:.24,depthWrite:false,emissive:'#0c2430'}),gt.length);
  const frame=new THREE.InstancedMesh(new THREE.BoxGeometry(1.02,.08,.1),lam('#c8ccd4'),gt.length);
  const o=new THREE.Object3D();
  gt.forEach(([x,y],i)=>{const ax=isG(x-1,y)||isG(x+1,y);o.position.set(x+.5,.8,y+.5);o.rotation.set(0,ax?0:Math.PI/2,0);o.updateMatrix();pane.setMatrixAt(i,o.matrix);o.position.y=1.62;o.updateMatrix();frame.setMatrixAt(i,o.matrix);});
  glassRefs={pane,frame,idx:new Map(gt.map(([x,y],i)=>[y*N+x,i]))};world.add(pane,frame);
}
function syncVents(){
  for(const o of ventObjs){const s=o.v.state;o.m.material.color.set(s===2?'#ffe2c0':s===1?(Math.sin(M.t*20)>0?'#ff8a3c':'#7a3a20'):'#55606e');}
}
"""

RENDER_DRONE_FIG = r"""  if(u.kind==='drone'){
    const body=new THREE.Mesh(mergeGeometries([box(.34,.1,.34,0,0,0,'#2a2f3a'),box(.56,.03,.05,0,.02,0,'#15181f'),box(.05,.03,.56,0,.02,0,'#15181f'),box(.1,.08,.12,0,-.08,.15,'#111318'),box(.3,.02,.3,0,.06,0,'#c8301e')]),vcMat);body.castShadow=true;
    const rot=[];for(const [x,z] of [[.27,.27],[-.27,.27],[.27,-.27],[-.27,-.27]]){const m=new THREE.Mesh(rotorGeo,rotorMat);m.position.set(x,.06,z);fig.add(m);rot.push(m);}
    const eye=new THREE.Mesh(new THREE.BoxGeometry(.12,.04,.02),basic('#ffaa3c'));eye.position.set(0,-.07,.22);
    fig.add(body,eye);fig.position.y=1.45;
    const sh=new THREE.Mesh(shadowGeo,shadowMat);sh.position.y=.012;sh.scale.setScalar(.8);g.add(sh);
    return {g,fig,eye,rot,sh,ring:null};
  }
  if(u.kind==='torre'){
    const base="""

RENDER_DRONE_SYNC = r"""  if(u.kind==='drone'){
    r.g.rotation.y=Math.PI/2-u.face;
    if(u.dead){r.fall=Math.min(1,(r.fall||0)+dt*2.5);r.fig.position.y=1.37*(1-r.fall*r.fall)+.08;r.fig.rotation.z=r.fall*.9;r.sh.visible=false;return;}
    r.fig.position.y=1.42+Math.sin(M.t*3+u.id)*.06;r.fig.rotation.z=Math.sin(M.t*2+u.id)*.05;r.fig.rotation.x=Math.min(.25,(u.curSpd||0)*.06);
    for(const m of r.rot)m.rotation.y+=dt*40;
    r.eye.material=basic(u.fac==='player'?'#4fd8ff':u.alerted?'#ff3040':'#ffaa3c');
    return;
  }
  if(u.kind==='torre'){
    r.head.rotation.y=Math.PI/2-u.face;"""

patch('js/render.js', 'function buildGlassVents(', [
    ("T_FENCE,T_POST,M,", "T_FENCE,T_POST,T_GLASS,M,"),
    ("    else if(t===T_PLAZA){", "    else if(t===T_PLAZA||t===T_GLASS){"),
    ("g.rotation.y=-(d.ang||0);\n    }\n    decorObjs.push(o);", "g.rotation.y=-(d.ang||0);" + RENDER_DECOR + "    }\n    decorObjs.push(o);"),
    ("    if(o.hang){o.hang.visible=o.cable.visible=!(M.flags&&M.flags.dropped);if(o.hang.visible)o.hang.rotation.y=Math.sin(M.t*.7)*.04;}",
     "    if(o.hang){o.hang.visible=o.cable.visible=!(M.flags&&M.flags.dropped);if(o.hang.visible)o.hang.rotation.y=Math.sin(M.t*.7)*.04;}\n"
     "    if(o.core){if(o.d.dead){if(!o.wreck){o.wreck=true;o.g.scale.y=.3;o.core.visible=false;o.light.intensity=0;}}else{const a=o.d.armed,col=a?(Math.sin(M.t*(M.timer?14:5))>0?'#ff3040':'#400408'):'#38e8ff';o.core.material.color.set(col);o.light.color.set(a?'#ff3040':'#38e8ff');}}\n"
     "    if(o.heli){const busy=M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead);o.rotor.rotation.y+=dt*(M.flags.heliGo?40:busy?28:2.5);if(M.flags.heliGo){o.lift+=dt;o.heli.position.y=Math.min(16,o.lift*o.lift*1.4);o.heli.position.x=o.lift*o.lift*.7;}}"),
    ("let camObjs=[],railObj=null,discoObjs=[];", RENDER_SEC + "let camObjs=[],railObj=null,discoObjs=[];"),
    ("  camObjs=[];railObj=null;discoObjs=[];", "  buildGlassVents();\n  camObjs=[];railObj=null;discoObjs=[];"),
    ("function syncSecurity(dt){\n", "function syncSecurity(dt){\n  syncVents();\n"),
    ("const ringGeo=new THREE.RingGeometry(.3,.37,28)",
     "const rotorGeo=new THREE.CircleGeometry(.12,10).rotateX(-Math.PI/2);rotorGeo.userData.shared=true;\nconst rotorMat=new THREE.MeshBasicMaterial({color:'#9aa4b4',transparent:true,opacity:.4,depthWrite:false,side:THREE.DoubleSide});rotorMat.userData.shared=true;\nconst ringGeo=new THREE.RingGeometry(.3,.37,28)"),
    ("  if(u.kind==='torre'){\n    const base=", RENDER_DRONE_FIG),
    ("  if(u.kind==='torre'){r.eye.material=basic('#4fd8ff');return;}", "  if(u.kind==='torre'||u.kind==='drone'){r.eye.material=basic('#4fd8ff');return;}"),
    ("  if(u.kind==='torre'){\n    r.head.rotation.y=Math.PI/2-u.face;", RENDER_DRONE_SYNC),
    ("  }else if(type==='lamp'&&lampRefs){",
     "  }else if(type==='glasswall'&&glassRefs){\n"
     "    const i=glassRefs.idx.get(o.y*N+o.x);if(i===undefined)return;\n"
     "    o3.position.set(0,-50,0);o3.rotation.set(0,0,0);o3.scale.set(0,0,0);o3.updateMatrix();glassRefs.pane.setMatrixAt(i,o3.matrix);glassRefs.pane.instanceMatrix.needsUpdate=true;\n"
     "    o3.position.set(o.x+.5,.05,o.y+.5);o3.rotation.set(0,Math.random()*3,0);o3.scale.set(1,1,1);o3.updateMatrix();glassRefs.frame.setMatrixAt(i,o3.matrix);glassRefs.frame.instanceMatrix.needsUpdate=true;\n"
     "  }else if(type==='lamp'&&lampRefs){"),
    ("  else{const R=r*TS*.9,gr=g.createRadialGradient(",
     "  else if(type==='shards'){for(let k=0;k<14;k++){g.fillStyle=`rgba(${170+Math.random()*60},${220+Math.random()*30},255,.55)`;g.fillRect(x*TS+(Math.random()-.5)*TS*1.4,y*TS+(Math.random()-.5)*TS*1.4,1+Math.random()*3,1+Math.random()*2);}}\n  else{const R=r*TS*.9,gr=g.createRadialGradient("),
    ("const p=toScreen(u.x,u.y,1.18),w=22", "const p=toScreen(u.x,u.y,u.fly?1.9:1.18),w=22"),
    ("if(u.hackP>0){const p=toScreen(u.x,u.y,1.1);", "if(u.hackP>0){const p=toScreen(u.x,u.y,u.fly?1.8:1.1);"),
    ("  if(M.vip&&!M.vip.dead){const p=toScreen(M.vip.x,M.vip.y,1.45);c.fillStyle='#ffd36b';c.fillText('▼ ALVO',p.x,p.y);}",
     "  if(M.vip&&!M.vip.dead){const p=toScreen(M.vip.x,M.vip.y,1.45);c.fillStyle='#ffd36b';c.fillText('▼ ALVO',p.x,p.y);}\n"
     "  for(const u of M.units){if(!u.cand||u.dead||u===M.vip)continue;const p=toScreen(u.x,u.y,1.45);if(u.scanned){c.fillStyle='#8a92a4';c.fillText('▼ SÓSIA',p.x,p.y);}else{c.fillStyle='#ffa53d';c.fillText('▼ ?',p.x,p.y);if(u.scanP>0){c.strokeStyle='#4fd8ff';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y-14,8,-Math.PI/2,-Math.PI/2+TAU*Math.min(1,u.scanP/1.6));c.stroke();}}}"),
    ("  if(M.escape&&M.vip&&M.vip.fleeing&&!M.vip.dead){", "  if(M.escape&&M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead&&!u.double)){"),
    ("t===T_FENCE?'#6a7088':", "t===T_FENCE?'#6a7088':t===T_GLASS?'#5a9ab0':"),
])
