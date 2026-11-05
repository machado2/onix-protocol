"""Patch: personagens e carros com modelos 3D (chars.js), mantendo os bonecos de blocos como reserva."""
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

GLB_FIG = r"""  const tall=u.heavy?1.32:u.rival?1.15:(u.kind==='agente'||u.kind==='inimigo')?1.07:1;
  const C=assets.ready?makeChar(u,tall):null;
  if(C){
    fig.add(C.root);
    const gun=new THREE.Mesh(getGun2('pistola'),vcMat);gun.visible=false;gun.castShadow=true;attach(C,'gun',gun);
    let visor=null;
    if(u.visor&&C.key!=='m_space'&&C.key!=='m_swat'){visor=new THREE.Mesh(visorGeo,basic(u.trim));attach(C,'visor',visor);}
    if(u.umb){const um=new THREE.Mesh(mergeGeometries([cyl(.012,.012,.55,4,.16,1.05,.08,'#15161a'),colGeo(new THREE.ConeGeometry(.46,.18,8).translate(.16,1.35,.08),u.umb)]),vcMat);um.castShadow=true;fig.add(um);}
    const sh=new THREE.Mesh(shadowGeo,shadowMat);sh.position.y=.012;g.add(sh);
    const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.9,toneMapped:false,depthWrite:false}));ring.position.y=.02;ring.visible=false;g.add(ring);
    let bubble=null;if(u.shield!==undefined){bubble=new THREE.Mesh(shieldGeo,new THREE.MeshBasicMaterial({color:'#6fe4ff',transparent:true,opacity:.22,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));bubble.position.y=.6;g.add(bubble);}
    play(C,'Idle',1,0);C.mixer.update(Math.random()*1.5);
    return {g,fig,C,gun,gunW:null,visor,ring,sh,bubble,lag:0};
  }
  fig.scale.setScalar(tall);
"""

GLB_SYNC = r"""/* personagem com modelo 3D: escolhe a animação pelo estado da unidade */
function syncGlb(u,r,dt){
  const C=r.C;
  const tick=()=>{if(onScreen(u.x,u.y)){C.mixer.update(dt+r.lag);r.lag=0;}else r.lag=Math.min(1,r.lag+dt);};
  if(u.dead){
    if(C.cur!=='Death')play(C,'Death',u.kbFrom?1.4:1,.08);
    if(u.kbFrom&&!r.kbDone){r.kbT=(r.kbT||0)+dt;const t=Math.min(1,r.kbT/.55),q=1-Math.pow(1-t,2);r.g.position.set(u.kbFrom.x+(u.x-u.kbFrom.x)*q,Math.sin(Math.PI*t)*.85*(u.kb?u.kb.p+.3:.6),u.kbFrom.y+(u.y-u.kbFrom.y)*q);r.fig.rotation.y=t*Math.PI*1.4;if(t>=1)r.kbDone=true;}
    r.ring.visible=false;r.sh.visible=false;r.gun.visible=false;if(r.bubble)r.bubble.visible=false;
    if(C.act&&C.act.time<C.act.getClip().duration||u.kbFrom&&!r.kbDone)tick();
    return;
  }
  const spd=u.path?(u.curSpd||1.5):0,moving=spd>0;
  const wk=curW(u),showGun=isArmed(u)&&(u.kind!=='policia'||u.follower||M.policeAggro>0||u.warned)&&(u.kind!=='guarda'||u.alerted||u.follower);
  if(showGun&&r.gunW!==wk){r.gun.geometry=getGun2(wk);r.gunW=wk;}
  r.gun.visible=showGun;
  const dancing=u.dance&&!(u.panicT>0),panic=(u.kind==='civil'&&u.panicT>0&&!u.follower)||u.burn>0;
  let a,ts=1;
  if(u.hjT>0||(u.kind==='agente'&&u.probing)||(showGun&&u.rel>0&&!moving))a='Interact';
  else if(moving){
    const run=spd>=1.9||panic;
    if(showGun&&u.aimT>0){a='Run_Shoot';ts=clamp(spd*.4,.7,1.5);}
    else if(run){a='Run';ts=clamp(spd*.38,.75,1.5);}
    else{a='Walk';ts=clamp(spd*1.05,.6,1.7);}
  }
  else if(dancing){a='Wave';ts=1.4;}
  else if(showGun&&u.aimT>0)a=u.flash>0?'Idle_Gun_Shoot':'Idle_Gun_Pointing';
  else if(showGun)a='Idle_Gun';
  else if(u.hitT>0)a='HitRecieve';
  else a=u.kind==='civil'||u.disguise?'Idle_Neutral':'Idle';
  play(C,a,ts);
  r.fig.position.y=0;r.fig.rotation.set(0,0,0);
  tick();
  const cl=!!u.cloak;if(r.cl!==cl){r.cl=cl;cloakChar(C,cl);}
  const hov=M.hover===u;
  r.ring.scale.setScalar(u.sel?1+.07*Math.sin(M.t*6):1);
  if(u.sel){r.ring.visible=true;r.ring.material.color.set('#4fd8ff');}
  else if(hov){r.ring.visible=true;r.ring.material.color.set(u.fac==='corp'?'#ff4d5e':u.fac==='police'?'#7fb0ff':'#ffa53d');}
  else if(u.follower){r.ring.visible=true;r.ring.material.color.set('#1d5f78');}
  else r.ring.visible=false;
}
function syncUnit(u,dt){
  if(u.r3&&!u.r3.C&&!u.r3.tried&&!u.mech&&assets.ready)u.r3rebuild=true;
  if(u.r3&&u.r3rebuild){world.remove(u.r3.g);if(u.r3.C){u.r3.C.mat.dispose();if(u.r3.C.cmat)u.r3.C.cmat.dispose();}u.r3=null;u.r3rebuild=false;}
"""

GLB_CAR = r"""function makeCar(c){
  const M3=makeCarModel(c);
  if(M3){
    const g=new THREE.Group(),L=M3.len/2,W=M3.wid/2,H=M3.ht;
    M3.holder.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
    const hl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.03,.05,.13).translate(L,H*.42,W*.62),new THREE.BoxGeometry(.03,.05,.13).translate(L,H*.42,-W*.62)]),basic('#fff3c8'));
    const tl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.03,.05,.14).translate(-L,H*.45,W*.62),new THREE.BoxGeometry(.03,.05,.14).translate(-L,H*.45,-W*.62)]),basic('#ff2030'));
    const cone=new THREE.Mesh(coneGeo,coneMat);cone.position.x=L-.8;
    const ring=new THREE.Mesh(new THREE.RingGeometry(L*1.12,L*1.12+.1,32).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.85,toneMapped:false,depthWrite:false}));ring.position.y=.03;ring.visible=false;
    g.add(M3.holder,hl,tl,cone,ring);world.add(g);
    return {g,body:null,glb:M3,hl,tl,cone,ring,dead:false};
  }
"""

patch(os.path.join(V2, 'js', 'render.js'), 'syncGlb', [
    ("import {curW,isArmed} from './sim.js';",
     "import {curW,isArmed} from './sim.js';\nimport {assets,makeChar,attach,play,cloakChar,makeCarModel,cullBegin,onScreen} from './chars.js';"),
    ("function makeFigure(u){",
     "function getGun2(w){const k='g2'+w;if(!gunGeo[k]){const L=WD[w].len||.2,f=w==='feixe';const g=mergeGeometries([box(.045,.06,L,0,.02,L/2-.03,f?'#3a2a40':'#23262e'),box(.03,.03,.05,0,.02,L-.01,f?'#ff3c78':'#111111'),box(.035,.08,.045,0,-.03,0,'#15161a')]);g.userData.shared=true;gunGeo[k]=g;}return gunGeo[k];}\n"
     "const visorGeo=new THREE.BoxGeometry(.15,.03,.02);visorGeo.userData.shared=true;\n"
     "function makeFigure(u){"),
    ("  const tall=u.heavy?1.32:u.rival?1.15:(u.kind==='agente'||u.kind==='inimigo')?1.07:1;fig.scale.setScalar(tall);\n", GLB_FIG),
    ("  if(r.visor)r.visor.material=basic('#4fd8ff');\n  else{",
     "  if(r.visor)r.visor.material=basic('#4fd8ff');\n  else if(r.C){r.visor=new THREE.Mesh(visorGeo,basic('#4fd8ff'));attach(r.C,'visor',r.visor);}\n  else{"),
    ("function syncUnit(u,dt){\n  if(u.r3&&u.r3rebuild){world.remove(u.r3.g);u.r3=null;u.r3rebuild=false;}\n", GLB_SYNC),
    ("  r.g.rotation.y=Math.PI/2-u.face;\n  if(r.bubble){",
     "  r.g.rotation.y=Math.PI/2-u.face;\n  if(r.C){if(r.bubble){r.bubble.visible=!!u.shield&&!u.dead;if(r.bubble.visible){r.bubble.material.opacity=.16+.1*Math.sin(M.t*7);r.bubble.scale.setScalar(1.25+.04*Math.sin(M.t*11));}}syncGlb(u,r,dt);return;}\n  if(r.bubble){"),
    ("function makeCar(c){\n", GLB_CAR),
    ("function syncCar(c){\n  let r=c.r3;if(!r)r=c.r3=makeCar(c);",
     "function syncCar(c,dt){\n  if(c.r3&&!c.r3.glb&&assets.ready){world.remove(c.r3.g);c.r3=null;}\n  let r=c.r3;if(!r)r=c.r3=makeCar(c);\n  if(r.glb&&!c.dead){const sp=c.player?(c.spd||c.cur||0):(c.stopT>0?0:(c.cur||c.v||0));for(const w of r.glb.wheels)w.rotation.x+=sp*dt*2.2;}"),
    ("  if(c.dead&&!r.dead){r.dead=true;r.body.material=wreckMat;",
     "  if(c.dead&&!r.dead&&r.glb){r.dead=true;r.glb.holder.traverse(o=>{if(o.isMesh)o.material=lam('#24221f');});r.hl.visible=r.tl.visible=r.cone.visible=false;r.g.position.y=-.03;}\n  if(c.dead&&!r.dead){r.dead=true;r.body.material=wreckMat;"),
    ("  for(const u of M.units)syncUnit(u,dt);\n  for(const c of M.cars)syncCar(c);",
     "  cullBegin(camera);\n  for(const u of M.units)syncUnit(u,dt);\n  for(const c of M.cars)syncCar(c,dt);"),
])
