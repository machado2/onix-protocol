"""Patch único: motor para a missão final — feixes que varrem e ferem, pilares de escudo, portas arrombáveis, terceiro final."""
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

patch('js/core.js', "mission:'torre'", [
    ("  {nome:'Torre Central',renda:8000,dif:9,tipo:'eliminacao',riq:1,hq:true,",
     "  {nome:'Torre Central',renda:8000,dif:9,tipo:'eliminacao',riq:1,hq:true,mission:'torre',\n   brief:'O último bastião do Consórcio. A praça da Torre Central é um campo fortificado: torretas, drones e soldados pesados guardam o portão blindado. Invadam os dois terminais de segurança da praça para arrombar o portão. No átrio, o Juiz espera com os Ponteiros que restarem; dois pilares de escudo o protegem enquanto estiverem de pé. Quando ele cair, Ilse Varga vai mandar apagar os servidores do andar 90. Cheguem lá antes.',\n   short:'Missão final roteirizada: assalto à torre, o Juiz e os servidores do Coral.',"),
])

patch('js/world.js', 'hgt[idx(x,y)]=b.fl;}return b;},', [
    ("hgt[idx(x,y)]=b.fl;}},", "hgt[idx(x,y)]=b.fl;}return b;},"),
])

SIM_LASER = r"""    if(l.sweep){const s=l.sweep,L=s.b-s.a,ph=(M.t*s.spd)%(2*L),p=s.a+(ph<L?ph:2*L-ph);if(s.ax==='y')l.y1=l.y2=p;else l.x1=l.x2=p;}
    if(l.dmg){
      l.tick=(l.tick||0)-dt;if(l.tick>0)continue;l.tick=.2;
      const dx=l.x2-l.x1,dy=l.y2-l.y1,L2=dx*dx+dy*dy||1;
      for(const u of M.units){
        if(u.dead||u.inCar||u.mech||u.boss)continue;
        const t=clamp(((u.x-l.x1)*dx+(u.y-l.y1)*dy)/L2,0,1),px=l.x1+dx*t-u.x,py=l.y1+dy*t-u.y;
        if(px*px+py*py>.16)continue;
        hurt(u,l.dmg*.2,null);l.tripT=.3;for(let k=0;k<3;k++)part(u.x,u.y,18,(Math.random()-.5)*2,(Math.random()-.5)*2,20+Math.random()*20,.3,'#ff6070',1,3);
      }
      continue;
    }
"""

patch('js/sim.js', 'if(l.sweep){', [
    ("    if(!l.on)continue;\n    const dx=l.x2-l.x1,dy=l.y2-l.y1,L2=dx*dx+dy*dy||1;\n    for(const a of M.agents){",
     "    if(!l.on)continue;\n" + SIM_LASER + "    const dx=l.x2-l.x1,dy=l.y2-l.y1,L2=dx*dx+dy*dy||1;\n    for(const a of M.agents){"),
    ("  if(v.hold)dmg*=.3;\n",
     "  if(v.hold)dmg*=.3;\n  if(v.shield){if(Math.random()<.5)sfx('ric',v.x,v.y);for(let k=0;k<2;k++)part(v.x,v.y,22,(Math.random()-.5)*2.5,(Math.random()-.5)*2.5,15+Math.random()*20,.35,'#6fe4ff',1,3);if(src&&src.fac==='player'&&v.fac==='corp')alertCorp(v,src.x,src.y);return;}\n"),
    ("function destroyBld(b,src){", "export function destroyBld(b,src){"),
])

patch('js/script.js', 'breach(b)', [
    ("import {endMission,explode,alertCorp} from './sim.js';", "import {endMission,explode,alertCorp,destroyBld} from './sim.js';"),
    ("    boom(x,y,r,dmg){explode(x,y,r,dmg,null);},", "    boom(x,y,r,dmg){explode(x,y,r,dmg,null);},\n    breach(b){if(!b.dead){explode(b.x+b.w/2,b.y+b.d/2,1.6,40,null);destroyBld(b,null);}},"),
])

patch('js/render.js', 'shieldGeo', [
    ("function syncVents(){\n  for(const o of ventObjs){if(!o.l)continue;",
     "function syncVents(){\n  for(const o of ventObjs){if(!o.l)continue;o.g.position.set((o.l.x1+o.l.x2)/2,0,(o.l.y1+o.l.y2)/2);"),
    ("const ringGeo=new THREE.RingGeometry(.3,.37,28)",
     "const shieldGeo=new THREE.SphereGeometry(.62,16,10);shieldGeo.userData.shared=true;\nconst ringGeo=new THREE.RingGeometry(.3,.37,28)"),
    ("  const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.9,toneMapped:false,depthWrite:false}));ring.position.y=.02;ring.visible=false;g.add(ring);\n  return {g,fig,body,legL,legR,armL,armR,gun,gunW:null,visor,ring,sh};",
     "  const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.9,toneMapped:false,depthWrite:false}));ring.position.y=.02;ring.visible=false;g.add(ring);\n  let bubble=null;if(u.shield!==undefined){bubble=new THREE.Mesh(shieldGeo,new THREE.MeshBasicMaterial({color:'#6fe4ff',transparent:true,opacity:.22,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));bubble.position.y=.6;g.add(bubble);}\n  return {g,fig,body,legL,legR,armL,armR,gun,gunW:null,visor,ring,sh,bubble};"),
    ("  r.g.rotation.y=Math.PI/2-u.face;\n  if(u.dead){\n",
     "  r.g.rotation.y=Math.PI/2-u.face;\n  if(r.bubble){r.bubble.visible=!!u.shield&&!u.dead;if(r.bubble.visible){r.bubble.material.opacity=.16+.1*Math.sin(M.t*7);r.bubble.scale.setScalar(1.25+.04*Math.sin(M.t*11));}}\n  if(u.dead){\n"),
    ("  for(const u of M.units)if(u.rival&&!u.dead){",
     "  if(M.boss&&M.boss.shield&&!M.boss.dead)for(const p of M.units){if(!p.pylon||p.dead||p.fac!=='corp')continue;const p1=toScreen(p.x,p.y,1),p2=toScreen(M.boss.x,M.boss.y,.9);c.strokeStyle=`rgba(111,228,255,${.35+Math.random()*.35})`;c.lineWidth=2;c.beginPath();c.moveTo(p1.x,p1.y);c.lineTo(p2.x,p2.y);c.stroke();}\n  for(const u of M.units)if(u.rival&&!u.dead){"),
])

patch('js/story.js', 'apagado:', [
    ("export const ENDINGS={\n",
     "export const ENDINGS={\n  apagado:{titulo:'Cinzas no andar 90',texto:'Quando vocês arrombaram a sala dos servidores, as telas já estavam pretas. Ilse Varga cumpriu a última ordem: o Coral virou cinza junto com o Hélice.\\nAbel Rocha chamou de fracasso. O Controle chamou de sorte. A Ônix ficou com a cidade, com as revoltas e com o rádio pirata, e ninguém precisou decidir nada.'},\n"),
])

patch('js/ui.js', 'G.wiped', [
    ("const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;unlock(G,'fim');}",
     "const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;G.wiped=!!(M.flags&&M.flags.wiped);if(!G.wiped)unlock(G,'fim');}"),
    ("function showFinalChoice(){\n  const d=MSGS.fim;\n  showModal(",
     "function showFinalChoice(){\n  const d=MSGS.fim;\n  if(G.wiped){const e=ENDINGS.apagado;G.final='apagado';save();showModal(`<div class=\"eyebrow\">Epílogo</div><h2>${e.titulo}</h2>${e.texto.split('\\n').map(p=>`<p>${escH(p)}</p>`).join('')}<div class=\"acts\"><button class=\"btn pri\" id=\"epOk\">Voltar ao mapa</button></div>`,null);$('#epOk').onclick=()=>{hideModal();showMap();};return;}\n  showModal("),
])
