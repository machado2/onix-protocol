"""Patch único: motor para as missões 3 e 4 — câmeras, monotrilho, agentes disfarçados, pista de dança, outdoors."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, marker, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    if marker in s:
        print('já aplicado:', fn); return
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('js/core.js', "mission:'mercado'", [
    ("  {nome:'Mercado Suspenso',renda:2600,dif:2,tipo:'sabotagem',riq:.4,",
     "  {nome:'Mercado Suspenso',renda:2600,dif:2,tipo:'sabotagem',riq:.4,mission:'mercado',\n   brief:'O Mercado Suspenso funciona debaixo do monotrilho e o Consórcio vigia cada banca com câmeras. Três terminais mantêm a rede de vigilância do distrito. O terminal da Central de Vigilância, ao norte, desliga todas as câmeras. As câmeras só reparam em armas à mostra. O trem passa a cada 40 segundos e o barulho dele cobre tiros. Depois de derrubar a rede, volte ao ponto de inserção.',\n   short:'Missão roteirizada: sabotagem sob o monotrilho, com câmeras de segurança.',"),
    ("  {nome:'Baixa Neon',renda:3000,dif:3,tipo:'eliminacao',riq:.5,",
     "  {nome:'Baixa Neon',renda:3000,dif:3,tipo:'eliminacao',riq:.5,mission:'neon',\n   brief:'Uma célula de cinco agentes do Consórcio está escondida no Clube Cobalto e nas calçadas da avenida, vestida como gente comum. Chegue perto: o scanner de implantes do esquadrão revela quem é quem. Atirar no civil errado custa caro. Há um carro de fuga no beco atrás do clube: se algum agente chegar até ele, a missão falha.',\n   short:'Missão roteirizada: caça a agentes disfarçados numa casa noturna.',"),
])

patch('js/world.js', "monorail(", [
    ("import {FAVELA} from './missions/favela.js';",
     "import {FAVELA} from './missions/favela.js';\nimport {MERCADO} from './missions/mercado.js';\nimport {NEON} from './missions/neon.js';"),
    ("const MISSIONS={docas:DOCAS,favela:FAVELA};", "const MISSIONS={docas:DOCAS,favela:FAVELA,mercado:MERCADO,neon:NEON};"),
    ("objs:[],flags:{},bonus:[],decor:[],piers:[],falling:[],co:[],", "objs:[],flags:{},bonus:[],decor:[],piers:[],falling:[],co:[],cams:[],rail:null,train:null,trainT:12,"),
    ("    lanes(list,count){",
     "    cam(x,y,ang,o){m.cams.push(Object.assign({x,y,base:ang,a:ang,sweep:.6,spd:.5,ph:Math.random()*6,fov:.42,range:7,see:0,dead:false,off:false},o||{}));},\n    monorail(y,xs){m.rail={y,xs};for(const x of xs)tile[idx(x,y)]=T_POST;},\n    disguise(u,dance){u.disguise=true;u.dance=!!dance;u.trueLook={coat:u.coat,trim:u.trim,long:u.long,visor:u.visor,hair:u.hair};u.coat=pick(['#6b4a3a','#3a5a6b','#7a6a50','#5a3a5a','#8a3a3a','#a07a4a','#5c6470']);u.trim=shade(u.coat,.25);u.long=false;u.visor=false;u.hair=pick(HAIR);u.cell=true;},\n    lanes(list,count){"),
])

SIM = r"""
/* ---------- câmeras de segurança ---------- */
function updCams(dt){
  for(const c of M.cams){
    if(c.dead||c.off)continue;
    c.a=c.base+Math.sin(M.t*c.spd+c.ph)*c.sweep;
    c.chk=(c.chk||0)-dt;if(c.chk>0)continue;c.chk=.2;
    let seen=null;
    for(const a of M.agents){
      if(a.dead||a.inCar||a.cloak)continue;if(!c.strict&&!isArmed(a))continue;
      const dx=a.x-c.x,dy=a.y-c.y,d=Math.hypot(dx,dy);if(d>c.range)continue;
      let da=Math.abs(Math.atan2(dy,dx)-c.a);if(da>Math.PI)da=TAU-da;if(da>c.fov)continue;
      if(los(c.x,c.y,a.x,a.y)){seen=a;break;}
    }
    if(seen){c.see+=.2;if(c.see>=.8&&!c.fired){c.fired=true;camAlarm(c,seen);}}else c.see=Math.max(0,c.see-.1);
  }
}
function camAlarm(c,a){
  log('Uma câmera de segurança viu o esquadrão!','red');hooks.vo('ctl:m3_camspot');
  let best=null,bd=1e9;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise){const d=Math.hypot(u.x-c.x,u.y-c.y);if(d<bd){bd=d;best=u;}}
  if(best)alertCorp(best,a.x,a.y);
  for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.alerted&&Math.hypot(u.x-c.x,u.y-c.y)<14){u.alerted=true;u.lkp={x:a.x,y:a.y};}
}
function hurtCam(c){if(c.dead)return;c.dead=true;for(let k=0;k<10;k++)part(c.x,c.y,75,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*30,.6,'#ffdc96',1,3);sfx('glass',c.x,c.y);}
/* ---------- monotrilho ---------- */
function updTrain(dt){
  if(!M.rail)return;
  if(!M.train){M.trainT-=dt;if(M.trainT<=0){M.train={x:-14,dir:1};M.trainT=40;}}
  else{
    M.train.x+=M.train.dir*11*dt;M.train.snd=(M.train.snd||0)-dt;
    if(M.train.snd<=0){M.train.snd=1.2;sfx('train',clamp(M.train.x,0,N),M.rail.y);}
    if(M.train.x>N+16)M.train=null;
  }
  M.flags.trainNoise=!!(M.train&&M.train.x>-6&&M.train.x<N+6);
}
/* ---------- agentes disfarçados ---------- */
function reveal(u){
  if(!u.disguise)return;u.disguise=false;u.dance=false;Object.assign(u,u.trueLook);u.r3rebuild=true;
  u.alerted=true;say(u,'Ônix!','#ff4d5e');M.revealed=(M.revealed||0)+1;
  if(M.revealed===1)hooks.vo('ctl:m4_reveal');
  alertCorp(u,u.x,u.y);
}
function updDisguise(u,dt){
  if(u.alerted){reveal(u);return;}
  let near=false;for(const a of M.agents)if(!a.dead&&!a.inCar&&Math.hypot(a.x-u.x,a.y-u.y)<2.6){near=true;break;}
  u.revealP=near?(u.revealP||0)+dt:Math.max(0,(u.revealP||0)-dt*.5);
  if(u.revealP>=1.6){reveal(u);return;}
  if(u.dance){u.path=null;return;}
  wander(u,dt,u.home?u.home.x:u.x,u.home?u.home.y:u.y,5,.9,sideTile);
}
"""

patch('js/sim.js', "function updCams(dt)", [
    ("function noise(x,y,r,src){", "function noise(x,y,r,src){\n  if(M.flags&&M.flags.trainNoise)r*=.35;"),
    ("    if(u.follower){updFollower(u,dt);continue;}", "    if(u.follower){updFollower(u,dt);continue;}\n    if(u.disguise){updDisguise(u,dt);continue;}"),
    ("  if(u.still&&u.panicT<=0)return;", "  if((u.still||u.dance)&&u.panicT<=0){u.path=null;return;}"),
    ("updDestruct(dt);", "updDestruct(dt);if(M.cams&&M.cams.length)updCams(dt);updTrain(dt);"),
    ("    if(v.fac==='corp')alertCorp(v,src.x,src.y);", "    if(v.fac==='corp'){if(v.disguise)reveal(v);alertCorp(v,src.x,src.y);}"),
    ("  for(const p of M.props){if(p.dead)continue;const rx=p.x-u.x,ry=p.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;",
     "  for(const c of M.cams||[]){if(c.dead)continue;const rx=c.x-u.x,ry=c.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.25){hurtCam(c);break;}}\n  for(const p of M.props){if(p.dead)continue;const rx=p.x-u.x,ry=p.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;"),
    ("  for(const p of M.props){if(!p.dead&&Math.hypot(p.x-x,p.y-y)<r+.3)hurtProp(p,999,src);}",
     "  for(const p of M.props){if(!p.dead&&Math.hypot(p.x-x,p.y-y)<r+.3)hurtProp(p,999,src);}\n  for(const c of M.cams||[])if(!c.dead&&Math.hypot(c.x-x,c.y-y)<r+.5)hurtCam(c);"),
    ("function updGuard(u,dt){\n  if(u.rival&&rivalTick(u,dt))return;",
     "function updGuard(u,dt){\n  if(u.fleeTo){if(!u.path)pathTo(u,u.fleeTo.x,u.fleeTo.y);moveAlong(u,dt,u.spd*1.25);if(Math.hypot(u.x-u.fleeTo.x,u.y-u.fleeTo.y)<1.4){u.dead=true;u.vanished=true;u.hp=0;M.flags.escaped=(M.flags.escaped||0)+1;}return;}\n  if(u.rival&&rivalTick(u,dt))return;"),
    ("/* ---------- guindaste: contêiner em queda ---------- */", SIM + "\n/* ---------- guindaste: contêiner em queda ---------- */"),
])

RENDER = r"""
/* ---------- câmeras, monotrilho, pista de dança e outdoors ---------- */
let camObjs=[],railObj=null,discoObjs=[];
const coneMatC=()=>new THREE.MeshBasicMaterial({color:'#ff3040',transparent:true,opacity:.13,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false,side:THREE.DoubleSide});
function buildSecurity(){
  camObjs=[];railObj=null;discoObjs=[];
  for(const c of M.cams||[]){
    const g=new THREE.Group();g.position.set(c.x,0,c.y);world.add(g);
    g.add(boxM(.08,2.4,.08,0,1.2,0,lam('#2a2f3a')));
    const head=new THREE.Group();head.position.y=2.35;g.add(head);
    const body=new THREE.Mesh(mergeGeometries([box(.32,.16,.18,.12,0,0,'#d8dce4'),box(.06,.1,.12,.29,0,0,'#1a1a1a')]),vcMat);head.add(body);
    const led=new THREE.Mesh(new THREE.SphereGeometry(.035,6,4),basic('#ff2030'));led.position.set(.2,.09,0);head.add(led);
    const cone=new THREE.Mesh(new THREE.CircleGeometry(c.range,16,-c.fov,c.fov*2).rotateX(-Math.PI/2),coneMatC());cone.position.y=.04;g.add(cone);
    camObjs.push({c,g,head,cone,led});
  }
  if(M.rail){
    const R=M.rail,y=R.y+.5,steel=lam('#3a404e');
    const g=new THREE.Group();world.add(g);
    g.add(boxM(N+30,.35,1.1,N/2,3.3,y,lam('#2c313d')));
    const edge=new THREE.Mesh(new THREE.BoxGeometry(N+30,.06,.06),basic('#38e8ff'));edge.position.set(N/2,3.1,y+.56);g.add(edge);
    const edge2=edge.clone();edge2.position.z=y-.56;g.add(edge2);
    for(const x of R.xs)g.add(boxM(.5,3.2,.5,x+.5,1.6,y,steel));
    const train=new THREE.Group();
    for(let k=0;k<3;k++){
      const car=new THREE.Mesh(mergeGeometries([box(4.6,1.05,.95,0,0,0,'#c9ccd4'),box(4.5,.3,.97,0,.18,0,'#16202e'),box(4.62,.08,.98,0,-.3,0,'#ff3d8b')]),vcMat);car.position.set(-k*4.9,4.05,0);car.castShadow=true;train.add(car);
      const win=new THREE.Mesh(new THREE.BoxGeometry(4.3,.22,1),basic('#ffe6b0'));win.position.set(-k*4.9,4.23,0);train.add(win);
    }
    const hl=new THREE.Mesh(new THREE.SphereGeometry(.12,8,6),basic('#ffffff'));hl.position.set(2.35,4,0);train.add(hl);
    train.position.z=y;train.visible=false;g.add(train);
    railObj={g,train};
  }
  for(const d of M.decor||[]){
    if(d.type==='disco'){
      const cols=['#ff3d8b','#38e8ff','#ffb13d','#a66bff','#5dffa0','#ff5a2a'];
      const spots=cols.map((col,i)=>{const m=new THREE.Mesh(new THREE.CircleGeometry(1.1,24).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.35,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));m.position.y=.03;world.add(m);return m;});
      const lights=[0,1].map(i=>{const l=new THREE.PointLight(cols[i],6,10,1.4);l.position.set((d.x0+d.x1)/2,2.5,(d.y0+d.y1)/2);world.add(l);return l;});
      discoObjs.push({d,spots,lights,cols});
    }else if(d.type==='billboard'){
      const c=document.createElement('canvas');c.width=512;c.height=192;const g2=c.getContext('2d');
      const gr=g2.createLinearGradient(0,0,512,192);gr.addColorStop(0,'#0a0614');gr.addColorStop(1,'#140a20');g2.fillStyle=gr;g2.fillRect(0,0,512,192);
      g2.strokeStyle=d.col;g2.lineWidth=6;g2.strokeRect(6,6,500,180);
      g2.font='700 64px "Chakra Petch", sans-serif';g2.textAlign='center';g2.textBaseline='middle';g2.fillStyle=d.col;g2.shadowColor=d.col;g2.shadowBlur=18;g2.fillText(d.text,256,84);
      g2.font='600 26px "JetBrains Mono", monospace';g2.shadowBlur=0;g2.fillStyle='#d3dcea';g2.fillText(d.sub||'',256,150);
      const mat=new THREE.MeshBasicMaterial({map:canvasTex(c),toneMapped:false});mat.userData.shared=false;
      const grp=new THREE.Group();grp.position.set(d.x,0,d.y);grp.rotation.y=d.ang||0;world.add(grp);
      const pl=new THREE.Mesh(new THREE.PlaneGeometry(d.w,d.w*192/512),mat);pl.position.y=d.h;grp.add(pl);
      for(const sx of [-d.w*.35,d.w*.35])grp.add(boxM(.12,d.h,.12,sx,d.h/2,-.06,lam('#22262e')));
      discoObjs.push({bb:true,mat,ph:Math.random()*9});
    }
  }
}
function syncSecurity(dt){
  for(const o of camObjs){
    const c=o.c;o.head.rotation.y=-c.a;o.cone.rotation.y=-c.a;
    o.cone.visible=!c.dead&&!c.off;o.cone.material.opacity=.1+(c.see||0)*.25;o.cone.material.color.set(c.see>0?'#ff6a20':'#ff3040');
    o.led.material=basic(c.dead||c.off?'#202020':(Math.sin(M.t*6)>0?'#ff2030':'#400408'));
    if(c.dead){o.head.rotation.z=.6;o.head.position.y=2.2;}
  }
  if(railObj){const t=M.train;railObj.train.visible=!!t;if(t)railObj.train.position.x=t.x;}
  for(const o of discoObjs){
    if(o.bb){o.mat.color.setScalar(Math.sin(M.t*13+o.ph)>.97?.35:1);continue;}
    const d=o.d,cx=(d.x0+d.x1+1)/2,cy=(d.y0+d.y1+1)/2,rx=(d.x1-d.x0)/2,ry=(d.y1-d.y0)/2;
    o.spots.forEach((m,i)=>{const a=M.t*(.6+i*.13)+i*1.7;m.position.x=cx+Math.cos(a)*rx*.8;m.position.z=cy+Math.sin(a*1.3)*ry*.8;});
    o.lights.forEach((l,i)=>{l.color.set(o.cols[(Math.floor(M.t*2)+i*3)%o.cols.length]);l.intensity=M.flags&&M.flags.blackout?0:5+Math.sin(M.t*8+i)*2;});
  }
}
"""

patch('js/render.js', "function buildSecurity()", [
    ("buildWater();buildFence();buildDecor();buildDestruct();", "buildWater();buildFence();buildDecor();buildDestruct();buildSecurity();"),
    ("  syncFx();syncDecor(dt);syncDestruct();syncVfx();", "  syncFx();syncDecor(dt);syncDestruct();syncVfx();syncSecurity(dt);"),
    ("  let r=u.r3;if(!r){r=u.r3=makeFigure(u);", "  if(u.r3&&u.r3rebuild){world.remove(u.r3.g);u.r3=null;u.r3rebuild=false;}\n  let r=u.r3;if(!r){r=u.r3=makeFigure(u);"),
    ("  if(u.kind==='agente'&&u.probing){aL=-1.9+Math.sin(M.t*12)*.08;aLz=-.2;}",
     "  if(u.kind==='agente'&&u.probing){aL=-1.9+Math.sin(M.t*12)*.08;aLz=-.2;}\n  const dancing=u.dance&&!(u.panicT>0);if(dancing){const s=Math.sin(M.t*7+u.id);aL=-2.3+s*.5;aR=-2.3-s*.5;}"),
    ("  r.fig.position.y=moving?Math.abs(Math.sin(ph))*.04*amp:Math.sin(M.t*2+u.id)*.004;",
     "  r.fig.position.y=dancing?Math.abs(Math.sin(M.t*7+u.id))*.07:moving?Math.abs(Math.sin(ph))*.04*amp:Math.sin(M.t*2+u.id)*.004;"),
    ("  for(const v of M.units){if(v.dead||!(v.hjT>0)||v.fac==='player')continue;",
     "  for(const v of M.units){if(v.dead||!v.disguise||!(v.revealP>0))continue;const p=toScreen(v.x,v.y,1.25);c.strokeStyle='rgba(255,165,61,.95)';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y,8,-Math.PI/2,-Math.PI/2+TAU*Math.min(1,v.revealP/1.6));c.stroke();c.fillStyle='#ffa53d';c.font='700 10px \"JetBrains Mono\",monospace';c.fillText('?',p.x,p.y+3.5);}\n  for(const v of M.units){if(v.dead||!(v.hjT>0)||v.fac==='player')continue;"),
    ("/* ---------- personagens ---------- */", RENDER + "\n/* ---------- personagens ---------- */"),
])

patch('js/audio.js', "case 'train'", [
    ("    case 'ric':", "    case 'train':{const o=chain(sp,.3);noise(o,1.5,140,.4,.55*v,'lowpass',0,SND.brown);for(let i=0;i<3;i++)noise(o,.05,900,2,.12*v,'bandpass',.2+i*.38);break;}\n    case 'ric':"),
])
print('ok')
