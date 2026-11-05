"""Patch único: motor para as missões 7 e 8 — feixes de alarme, muros, soldados pesados, dirigível, VTOL que pousa."""
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
    print('ok:', fn)

patch('js/core.js', "mission:'retiro'", [
    ("  {nome:'Colinas de Vidro',renda:4200,dif:5,tipo:'extracao',riq:.8,",
     "  {nome:'Colinas de Vidro',renda:4200,dif:5,tipo:'extracao',riq:.8,mission:'retiro',\n   brief:'O Dr. Caio Ventura escreveu o firmware dos drones do Consórcio e quer mudar de lado. O Hélice o mantém no Retiro, uma mansão murada no alto das Colinas de Vidro, trabalhando numa estufa de vidro. Feixes de alarme cortam o jardim; alguns piscam em ciclos. O gerador fora do muro, a sudoeste, apaga feixes, câmeras e luzes. Leve o doutor até a zona de pouso no topo do morro, a noroeste, e segure a posição até o VTOL pousar.',\n   short:'Missão roteirizada: extração com feixes de alarme e defesa da zona de pouso.',"),
    ("  {nome:'Cais Aéreo',renda:3800,dif:6,tipo:'eliminacao',riq:.6,",
     "  {nome:'Cais Aéreo',renda:3800,dif:6,tipo:'eliminacao',riq:.6,mission:'doca',\n   brief:'Uma célula de oito agentes do Consórcio, dois deles com armadura pesada, está carregando um dirigível no Cais Aéreo. O dirigível parte em quatro minutos. No último minuto, a célula corre para a prancha de embarque: se algum agente embarcar, a missão falha. O terminal das amarras, na ponta do píer central, prende o dirigível no cais. Torretas automáticas vigiam os píeres.',\n   short:'Missão roteirizada: eliminação contra o relógio, com soldados pesados.',"),
])

patch('js/world.js', 'retiro:RETIRO', [
    ("import {LUMEN} from './missions/lumen.js';", "import {LUMEN} from './missions/lumen.js';\nimport {RETIRO} from './missions/retiro.js';\nimport {DOCA} from './missions/doca.js';"),
    ("fundicao:FUNDICAO,lumen:LUMEN};", "fundicao:FUNDICAO,lumen:LUMEN,retiro:RETIRO,doca:DOCA};"),
    ("vents:[],glassN:0,", "vents:[],glassN:0,lasers:[],"),
    ("    vent(x,y,o){",
     "    laser(x1,y1,x2,y2,o){const l=Object.assign({x1,y1,x2,y2,off:false,on:true,per:0,ph:0,duty:.5,tripT:0},o||{});m.lasers.push(l);return l;},\n"
     "    heavy(x,y,dif){const u=mkUnit('inimigo',x,y);armAI(u,dif||6,Math.random);Object.assign(u,{heavy:true,w:'serra',mun:WD.serra.pente,hp:380,maxHp:380,armor:.5,spd:1.35,nades:0,coat:'#2a2c34',trim:'#ffb13d'});return u;},\n"
     "    vent(x,y,o){"),
])

SIM = r"""
/* ---------- feixes de alarme ---------- */
function updLasers(dt){
  for(const l of M.lasers){
    l.on=!l.off&&(!l.per||((M.t+l.ph)%l.per)<l.per*l.duty);
    if(l.tripT>0)l.tripT-=dt;
    if(!l.on)continue;
    const dx=l.x2-l.x1,dy=l.y2-l.y1,L2=dx*dx+dy*dy||1;
    for(const a of M.agents){
      if(a.dead||a.inCar||a.cloak)continue;
      const t=clamp(((a.x-l.x1)*dx+(a.y-l.y1)*dy)/L2,0,1),px=l.x1+dx*t-a.x,py=l.y1+dy*t-a.y;
      if(px*px+py*py>.09)continue;
      l.tripT=1.2;
      if(!l.tripped){l.tripped=true;log('Um feixe de alarme foi cortado!','red');sfx('alarm');}
      if(!M.corpAlert){let best=null,bd=1e9;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise&&!u.cand){const d=Math.hypot(u.x-a.x,u.y-a.y);if(d<bd){bd=d;best=u;}}if(best){hooks.vo('ctl:laser');alertCorp(best,a.x,a.y);}}
      break;
    }
  }
}
"""

patch('js/sim.js', 'function updLasers(', [
    ("if(v.kb&&v.kb.p>.12&&!v.mech)", "if(v.kb&&v.kb.p>.12&&!v.mech&&!v.heavy)"),
    ("    if(v===best||v.dead||v.inCar||v.fac===u.fac||v.fac==='civ'||v.fac==='neutral')continue;",
     "    if(v===best||v.dead||v.inCar||v.fac===u.fac||v.fac==='civ'||v.fac==='neutral'||v.heavy)continue;"),
    ("if(M.decor&&M.decor.length)updDecorFx(dt);", "if(M.decor&&M.decor.length)updDecorFx(dt);if(M.lasers&&M.lasers.length)updLasers(dt);"),
    ("\n/* ---------- câmeras de segurança ---------- */", SIM + "\n/* ---------- câmeras de segurança ---------- */"),
])

patch('js/ui.js', 'u.heavy&&!u.follower', [
    ("    case 'inimigo':return u.follower?", "    case 'inimigo':if(u.heavy&&!u.follower)return 'Soldado pesado do Consórcio (blindagem alta)';return u.follower?"),
])

RENDER_SPECIAL = r"""function buildSpecial(b){
  if(b.style==='wall'){
    const H=1.6,m=new THREE.Mesh(new THREE.BoxGeometry(b.w,H,b.d),lam('#8a8478'));m.position.set(b.x+b.w/2,H/2,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);
    const cap=new THREE.Mesh(new THREE.BoxGeometry(b.w+.1,.1,b.d+.1),lam('#c8c0b0'));cap.position.set(b.x+b.w/2,H+.05,b.y+b.d/2);world.add(cap);
    b.parts=[m,cap];return;
  }"""

RENDER_DECOR = r"""
    }else if(d.type==='airship'){
      const L=d.len||14,ship=new THREE.Group();
      const env=new THREE.Mesh(new THREE.SphereGeometry(1,24,14),lam('#b8bcc4'));env.scale.set(L/2,2.3,2.3);env.castShadow=true;ship.add(env);
      const band=new THREE.Mesh(new THREE.CylinderGeometry(2.33,2.33,.25,24,1,true).rotateZ(Math.PI/2),lam('#c8301e'));band.position.x=L*.18;ship.add(band);
      const gon=new THREE.Mesh(mergeGeometries([box(4,.9,1.2,0,0,0,'#2a2f3a'),box(3.6,.3,1.22,0,.1,0,'#ffe6b0')]),vcMat);gon.position.y=-2.6;gon.castShadow=true;ship.add(gon);
      for(const s of [1,-1]){const f=new THREE.Mesh(new THREE.BoxGeometry(2,.08,1.6),lam('#8a8e98'));f.position.set(-L*.42,0,s*1.6);ship.add(f);}
      const fv=new THREE.Mesh(new THREE.BoxGeometry(2,1.6,.08),lam('#8a8e98'));fv.position.set(-L*.42,1.6,0);ship.add(fv);
      const sg=new THREE.Mesh(new THREE.PlaneGeometry(5,1.1),signMat(d.text||'HÉLICE',d.col||'#ff3d5a'));sg.position.set(L*.05,.4,2.32);ship.add(sg);
      const nav=new THREE.Mesh(new THREE.SphereGeometry(.12,6,4),blinkMat);nav.position.set(L/2,0,0);ship.add(nav);
      ship.position.set(d.x,d.h||6.5,d.y);g.add(ship);o.ship=ship;o.lift=0;o.base=d.h||6.5;
      if(d.mx!==undefined){g.add(boxM(.4,d.h||6.5,.4,d.mx,(d.h||6.5)/2,d.my,lam('#3a404e')));const ln=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,Math.hypot(d.mx-d.x-L/2,d.my-d.y),3).rotateZ(Math.PI/2),lam('#151515'));ln.position.set((d.mx+d.x+L/2)/2,(d.h||6.5),(d.my+d.y)/2);ln.rotation.y=-Math.atan2(d.my-d.y,d.mx-d.x-L/2);g.add(ln);o.line=ln;}
"""

RENDER_LASER = r"""  ventObjs=[];glassRefs=null;
  for(const l of M.lasers||[]){
    const dx=l.x2-l.x1,dy=l.y2-l.y1,L=Math.hypot(dx,dy),a=-Math.atan2(dy,dx);
    const mat=new THREE.MeshBasicMaterial({color:'#ff2030',transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false});
    const g=new THREE.Group();g.position.set((l.x1+l.x2)/2,0,(l.y1+l.y2)/2);g.rotation.y=a;world.add(g);
    const beams=[.35,.75].map(h=>{const m=new THREE.Mesh(new THREE.BoxGeometry(L,.025,.025),mat);m.position.y=h;g.add(m);return m;});
    for(const s of [-1,1])g.add(boxM(.1,.95,.1,s*L/2,.475,0,lam('#2a2f3a')));
    ventObjs.push({l,g,beams,mat});
  }"""

patch('js/render.js', "b.style==='wall'", [
    ("function buildSpecial(b){", RENDER_SPECIAL),
    ("  const tall=u.rival?1.15:", "  const tall=u.heavy?1.32:u.rival?1.15:"),
    ("  if(u.kind==='vip')parts.push(box(.05,.2,.02,0,.62,.135,'#8a1a22'));",
     "  if(u.kind==='vip')parts.push(box(.05,.2,.02,0,.62,.135,'#8a1a22'));\n  if(u.heavy)parts.push(box(.44,.14,.26,0,.74,0,'#3a3e48'),box(.12,.12,.28,-.2,.8,0,u.trim),box(.12,.12,.28,.2,.8,0,u.trim),box(.3,.3,.08,0,.6,.15,'#3a3e48'),box(.2,.06,.04,0,.89,.09,u.trim));"),
    ("o.heli=hg;o.rotor=rotor;o.lift=0;", "o.heli=hg;o.rotor=rotor;o.lift=0;if(d.alt!==undefined)hg.position.y=d.alt;"),
    ("    if(o.heli){const busy=M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead);o.rotor.rotation.y+=dt*(M.flags.heliGo?40:busy?28:2.5);",
     "    if(o.heli&&o.d.alt!==undefined){o.g.visible=o.d.vis!==false;if(!M.flags.heliGo)o.heli.position.y+=(o.d.alt-o.heli.position.y)*Math.min(1,dt*.7);}\n"
     "    if(o.ship){o.ship.position.y=o.base+Math.sin(M.t*.5)*.15;o.ship.rotation.x=Math.sin(M.t*.4)*.02;if(M.flags.airshipGo){o.lift+=dt;o.ship.position.y+=o.lift*o.lift*.35;o.ship.position.x=o.d.x+o.lift*o.lift*.9;if(o.line)o.line.visible=false;}}\n"
     "    if(o.heli){const busy=M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead)||(o.d.alt!==undefined&&o.d.vis!==false);o.rotor.rotation.y+=dt*(M.flags.heliGo?40:busy?28:2.5);"),
    ("g.rotation.y=-(d.ang||0);\n    }else if(d.type==='pipe'){", "g.rotation.y=-(d.ang||0);" + RENDER_DECOR + "    }else if(d.type==='pipe'){"),
    ("  ventObjs=[];glassRefs=null;", RENDER_LASER),
    ("function syncVents(){\n", "function syncVents(){\n  for(const o of ventObjs){if(!o.l)continue;o.g.visible=o.l.on||o.l.tripT>0;o.mat.color.set(o.l.tripT>0&&Math.sin(M.t*30)>0?'#ffffff':'#ff2030');o.mat.opacity=.6+.3*Math.sin(M.t*9);}\n"),
    ("  for(const o of ventObjs){const s=o.v.state;", "  for(const o of ventObjs){if(!o.v)continue;const s=o.v.state;"),
])
