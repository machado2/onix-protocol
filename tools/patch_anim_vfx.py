"""Patch único: polimento 2 — animação e efeitos visuais (registro da mudança)."""
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

patch('js/world.js', [
    ("u.walkT+=dt*spd*4.2;", "u.walkT+=dt*spd*4.2;u.curSpd=spd;"),
])

VX = "(M.vfx||(M.vfx=[]))"
patch('js/sim.js', [
    # explosões: arremesso dos corpos, bola de fogo e onda de choque
    ("if(d<r){v.burn=Math.max(v.burn,1.2);v.burnSrc=src;hurt(v,dmg*(1-.6*d/r),src);}}",
     "if(d<r){v.burn=Math.max(v.burn,1.2);v.burnSrc=src;v.kb={x:(v.x-x)/(d||1),y:(v.y-y)/(d||1),p:1-d/r};hurt(v,dmg*(1-.6*d/r),src);if(!v.dead)v.kb=null;}}\n  " + VX + ".push({k:'ring',x,y,life:.55,max:.55,size:r*1.5,col:'#ffb070'},{k:'ball',x,y,z:.7,life:.45,max:.45,size:r*1.2,col:'#ffa040'});"),
    ("  v.dead=true;v.deathT=0;v.path=null;v.hp=0;v.burn=0;v.hj=0;",
     "  v.dead=true;v.deathT=0;v.path=null;v.hp=0;v.burn=0;v.hj=0;\n  if(v.kb&&v.kb.p>.12&&v.kind!=='torre'){v.kbFrom={x:v.x,y:v.y};v.face=Math.atan2(-v.kb.y,-v.kb.x);for(let L=.6+v.kb.p*1.8;L>.2;L-=.3){const nx=v.x+v.kb.x*L,ny=v.y+v.kb.y*L;if(canStand(nx,ny)){v.x=nx;v.y=ny;break;}}}"),
    # clarão do cano e cápsulas ejetadas
    ("  M.flashes.push({x:mx,y:my,life:.06,max:.06,i:2.5,col:w.laser?'#ff4080':'#ffc070'});",
     "  M.flashes.push({x:mx,y:my,life:.06,max:.06,i:2.5,col:w.laser?'#ff4080':'#ffc070'});\n  if(!w.flame)" + VX + ".push({k:'muzzle',x:mx,y:my,z:.64,life:.055,max:.055,size:w.pellets?1:wk==='serra'?.8:w.laser?.7:.55,col:w.laser?'#ff5aa0':'#ffd890'});\n  if(!w.flame&&!w.laser&&M.debris&&Math.random()<.55){const s=Math.random()<.5?1:-1;M.debris.push({x:u.x+Math.cos(ang)*.12,y:u.y+Math.sin(ang)*.12,z:.6,vx:-Math.sin(ang)*s*1.4+(Math.random()-.5)*.6,vy:Math.cos(ang)*s*1.4+(Math.random()-.5)*.6,vz:2+Math.random()*1.5,rx:0,ry:Math.random()*3,rz:0,vr:22,s:.05,col:'#c8a040',life:2.2});if(M.debris.length>420)M.debris.shift();}"),
    ("  for(const arr of [M.tracers,M.flashes,M.texts,M.marks])", "  for(const arr of [M.tracers,M.flashes,M.texts,M.marks,M.vfx||[]])"),
    # sonda: pulso e conversão
    ("  say(v,'...sim.','#4fd8ff');sfx('convert',v.x,v.y);",
     "  say(v,'...sim.','#4fd8ff');sfx('convert',v.x,v.y);" + VX + ".push({k:'ring',x:v.x,y:v.y,life:.6,max:.6,size:1.6,col:'#4fd8ff'});for(let k=0;k<14;k++)part(v.x+(Math.random()-.5)*.4,v.y+(Math.random()-.5)*.4,10+Math.random()*20,0,0,30+Math.random()*30,.8,'#6fe4ff',1,1);"),
    ("  u.probing=any;",
     "  u.probing=any;u.pulseT=(u.pulseT||0)-dt;if(u.pulseT<=0){u.pulseT=.75;" + VX + ".push({k:'ring',x:u.x,y:u.y,life:.75,max:.75,size:(w.alcance+(has('sonda2')?1:0))*1.05,col:'#2fb8e0'});}"),
    # aura de sobrecarga e fumaça no colapso
    ("  const load=u.nr.r+u.nr.p+u.nr.c-1.5;",
     "  const load=u.nr.r+u.nr.p+u.nr.c-1.5;\n  if(!u.inCar){if(load>.4&&u.colapso<=0&&Math.random()<.22)part(u.x+(Math.random()-.5)*.35,u.y+(Math.random()-.5)*.35,12+Math.random()*14,0,0,22,.5,'#ffb040',1,1);if(u.colapso>0&&Math.random()<.12)part(u.x,u.y,30,(Math.random()-.5)*.3,(Math.random()-.5)*.3,10,1.2,'#5a5a66',1,2);}"),
    # escapamento dos carros
    ("    c.x+=c.dx*c.cur*dt;c.y+=c.dy*c.cur*dt;",
     "    c.x+=c.dx*c.cur*dt;c.y+=c.dy*c.cur*dt;if(c.cur>.5&&Math.random()<.035)part(c.x-c.dx*.85,c.y-c.dy*.85,6,-c.dx*.4,-c.dy*.4,6,1.1,'#4a4a52',1,2);"),
    ("  c.dx=ndx;c.dy=ndy;", "  c.dx=ndx;c.dy=ndy;if(c.cur>.5&&Math.random()<.05)part(c.x-ndx*.85,c.y-ndy*.85,6,-ndx*.5,-ndy*.5,6,1.1,'#4a4a52',1,2);"),
    # poeira nos impactos
    ("  if(!b){if(Math.random()<.25)sfx('ric',ex,ey);return;}",
     "  part(ex+h.nx*.05,ey+h.ny*.05,z*30,h.nx*.7,h.ny*.7,4,.55,'#8a8a90',1,2);\n  if(!b){if(Math.random()<.25)sfx('ric',ex,ey);return;}"),
    ("  else for(let k=0;k<2;k++)part(ex,ey,8,",
     "  else{part(ex,ey,2,0,0,8,.5,'#6a6460',1,2);}\n  if(!best&&!prop&&!car&&!(hw&&!hw.out&&bt>=hw.t-.001))for(let k=0;k<2;k++)part(ex,ey,8,"),
])

ANIM = r"""  const spd=u.path?(u.curSpd||1.5):0,moving=spd>0,amp=moving?Math.min(.95,.38+spd*.15):0,ph=u.walkT,sw=Math.sin(ph)*amp;
  const k=Math.min(1,dt*16),L=(o,p,v)=>{o[p]+=(v-o[p])*k;};
  const wk=curW(u),showGun=isArmed(u)&&(u.kind!=='policia'||u.follower||M.policeAggro>0||u.warned)&&(u.kind!=='guarda'||u.alerted||u.follower);
  if(showGun&&r.gunW!==wk){r.gun.geometry=getGun(wk);r.gunW=wk;}
  r.gun.visible=showGun;
  const rec=u.flash>0?(wk==='escopeta'?.6:wk==='feixe'?.45:wk==='serra'?.18:.28):0;
  let aL=-sw*.7,aR=sw*.7,aLz=0,lean=moving?Math.min(.22,spd*.05):0,back=0;
  if(u.hjT>0){aL=-.2+Math.sin(M.t*30)*.15;aR=-.2-Math.sin(M.t*30)*.15;}
  else if((u.kind==='civil'&&u.panicT>0&&!u.follower)||u.burn>0){const f=u.burn>0?22:9;aL=-2.7+Math.sin(M.t*f)*.4;aR=-2.7-Math.sin(M.t*f)*.4;}
  else if(showGun&&u.rel>0){aR=-.55;aL=-1.15;aLz=-.55;}
  else if(showGun&&u.aimT>0){aR=-Math.PI/2+rec;aL=-1.35+rec;aLz=-.35;lean=Math.max(lean*.5,.05);back=-rec*.12;}
  else if(showGun){aR=-.45;aL=-sw*.5;}
  if(u.kind==='agente'&&u.probing){aL=-1.9+Math.sin(M.t*12)*.08;aLz=-.2;}
  if(u.hitT>0)lean-=.3;
  L(r.legL.rotation,'x',sw);L(r.legR.rotation,'x',-sw);
  L(r.armL.rotation,'x',aL);L(r.armR.rotation,'x',aR);L(r.armL.rotation,'z',aLz);
  L(r.fig.rotation,'x',lean);r.fig.rotation.z=u.hjT>0?Math.sin(M.t*17)*.05:0;
  r.fig.position.y=moving?Math.abs(Math.sin(ph))*.04*amp:Math.sin(M.t*2+u.id)*.004;
  r.fig.position.z=back;
"""

DEATH_OLD = """  if(u.dead){
    r.fall=Math.min(1,(r.fall||0)+dt*3.2);const e=1-Math.pow(1-r.fall,3);
    r.fig.rotation.x=-e*Math.PI/2;r.fig.position.y=e*.09;
    r.legL.rotation.x=r.legR.rotation.x=0;r.armL.rotation.x=-e*2.6;r.armR.rotation.x=-e*2.2;
    r.ring.visible=false;r.sh.visible=false;r.gun.visible=false;return;
  }"""
DEATH_NEW = """  if(u.dead){
    if(r.fdir===undefined){r.fdir=u.kbFrom?-1:(Math.random()<.55?-1:1);r.froll=(Math.random()-.5)*.7;}
    r.fall=Math.min(1,(r.fall||0)+dt*(u.kbFrom?2.2:3.2));const e=1-Math.pow(1-r.fall,3);
    r.fig.rotation.x=r.fdir*e*Math.PI/2;r.fig.rotation.z=e*r.froll;r.fig.position.y=e*.09;r.fig.position.z=0;
    r.legL.rotation.x=r.legR.rotation.x=e*.25*r.fdir;r.armL.rotation.x=-e*2.6;r.armR.rotation.x=-e*2.2;
    if(u.kbFrom&&!r.kbDone){r.kbT=(r.kbT||0)+dt;const t=Math.min(1,r.kbT/.55),q=1-Math.pow(1-t,2);r.g.position.set(u.kbFrom.x+(u.x-u.kbFrom.x)*q,Math.sin(Math.PI*t)*.85*(u.kb?u.kb.p+.3:.6),u.kbFrom.y+(u.y-u.kbFrom.y)*q);r.fig.rotation.y=t*Math.PI*1.4;if(t>=1)r.kbDone=true;}
    r.ring.visible=false;r.sh.visible=false;r.gun.visible=false;return;
  }"""

VFX = r"""
/* ---------- efeitos rápidos: clarão do cano, bola de fogo, ondas no chão ---------- */
const flareTex=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.25,'rgba(255,255,255,.7)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);g.globalCompositeOperation='lighter';g.strokeStyle='rgba(255,255,255,.6)';g.lineWidth=3;for(let k=0;k<4;k++){const a=k*Math.PI/4;g.beginPath();g.moveTo(32-Math.cos(a)*30,32-Math.sin(a)*30);g.lineTo(32+Math.cos(a)*30,32+Math.sin(a)*30);g.stroke();}return new THREE.CanvasTexture(c);})();
let vfxRings=[],vfxSprites=[];
function vfxRing(i){let m=vfxRings[i];if(!m){m=new THREE.Mesh(new THREE.RingGeometry(.86,1,40).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));world.add(m);vfxRings[i]=m;}return m;}
function vfxSprite(i){let s=vfxSprites[i];if(!s){s=new THREE.Sprite(new THREE.SpriteMaterial({map:flareTex,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));world.add(s);vfxSprites[i]=s;}return s;}
function syncVfx(){
  let ri=0,si=0;
  for(const v of (M.vfx||[])){
    const a=Math.max(0,v.life/v.max),t=1-a;
    if(v.k==='ring'){const m=vfxRing(ri++);m.visible=true;m.position.set(v.x,.05,v.y);m.scale.setScalar(.2+v.size*(1-Math.pow(a,2)));m.material.color.set(v.col);m.material.opacity=a*.9;}
    else{const s=vfxSprite(si++);s.visible=true;s.position.set(v.x,v.z||.6,v.y);const sc=v.k==='ball'?v.size*(.5+t*1.1):v.size*(.8+Math.random()*.4);s.scale.set(sc,sc,1);s.material.color.set(v.col);s.material.opacity=v.k==='ball'?a:1;s.material.rotation=Math.random()*TAU;}
  }
  for(;ri<vfxRings.length;ri++)vfxRings[ri].visible=false;
  for(;si<vfxSprites.length;si++)vfxSprites[si].visible=false;
}
"""

with open(os.path.join(V2, 'js/render.js'), encoding='utf-8') as fh:
    rs = fh.read()
if 'function syncVfx' not in rs:
    a = rs.index("  const moving=!!u.path,sw=moving?Math.sin(u.walkT)*.65:0;")
    b_ = rs.index("  r.fig.position.y=u.hitT>0?.03:0;") + len("  r.fig.position.y=u.hitT>0?.03:0;")
    rs = rs[:a] + ANIM + rs[b_:]
    assert DEATH_OLD in rs
    rs = rs.replace(DEATH_OLD, DEATH_NEW, 1)
    rs = rs.replace("/* ---------- personagens ---------- */", VFX + "\n/* ---------- personagens ---------- */", 1)
    reps = [
        ("  if(u.sel){r.ring.visible=true;r.ring.material.color.set('#4fd8ff');}",
         "  r.ring.scale.setScalar(u.sel?1+.07*Math.sin(M.t*6):1);\n  if(u.sel){r.ring.visible=true;r.ring.material.color.set('#4fd8ff');}"),
        ("  syncFx();syncDecor(dt);syncDestruct();", "  syncFx();syncDecor(dt);syncDestruct();syncVfx();cloakMat.opacity=.13+.08*Math.sin(M.t*9);"),
        ("  tracerLines=new THREE.LineSegments(", "  vfxRings=[];vfxSprites=[];\n  tracerLines=new THREE.LineSegments("),
        ("  for(const t of M.terms){if(t.done||t.prog<=0)continue;",
         "  for(const v of M.units){if(v.dead||!(v.hjT>0)||v.fac==='player')continue;const a=M.agents.find(q=>q.probing&&!q.dead&&Math.hypot(q.x-v.x,q.y-v.y)<4);if(!a)continue;const p1=toScreen(a.x,a.y,.95),p2=toScreen(v.x,v.y,.9);c.strokeStyle=`rgba(111,228,255,${.45+Math.random()*.4})`;c.lineWidth=1.5;c.setLineDash([2,3]);c.beginPath();c.moveTo(p1.x,p1.y);c.quadraticCurveTo((p1.x+p2.x)/2,(p1.y+p2.y)/2-14,p2.x,p2.y);c.stroke();c.setLineDash([]);}\n  for(const t of M.terms){if(t.done||t.prog<=0)continue;"),
    ]
    for x, y in reps:
        assert x in rs, x[:60]
        rs = rs.replace(x, y, 1)
    open(os.path.join(V2, 'js/render.js'), 'w', encoding='utf-8').write(rs)
    print('render ok')

patch('js/ui.js', [
    ("if(!M.paused){update(dt);runScript();}",
     "if(!M.paused){update(dt);runScript();if(!M.cine)for(let k=0;k<3;k++){const p=toWorld(Math.random()*innerWidth,Math.random()*innerHeight);if(p.x>0&&p.y>0&&p.x<N&&p.y<N)part(p.x,p.y,1,0,0,18,.22,'#a8c0f0',1,3);}}"),
    ("import {dropContainer,say,update,", "import {part,dropContainer,say,update,"),
])
print('ok')
