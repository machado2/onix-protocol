"""Patch único: motor para a missão dos Jardins Altos — sebes, holofotes, bunker com porta blindada."""
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

patch('js/core.js', "mission:'jardins'", [
    ("  {nome:'Jardins Altos',renda:5000,dif:7,tipo:'assassinato',riq:.9,",
     "  {nome:'Jardins Altos',renda:5000,dif:7,tipo:'assassinato',riq:.9,mission:'jardins',\n   brief:'O senador Augusto Calvino vende ao Consórcio os contratos de segurança da cidade inteira. Toda noite ele caminha pelo labirinto de sebes da própria mansão, com dois guarda-costas. As sebes escondem o esquadrão; os holofotes das torres, não: eles enxergam qualquer um, armado ou não, e podem ser derrubados a tiros. Ao primeiro alarme, Calvino corre para o bunker a nordeste. Se ele entrar, a porta blindada se fecha e um túnel de fuga começa a ser preparado: sobrecarreguem os dois relés do lado de fora para arrombar a porta antes que ele suma.',\n   short:'Missão roteirizada: assassinato num labirinto de sebes, com holofotes e bunker.',"),
])

patch('js/world.js', 'jardins:JARDINS', [
    ("import {TORRE} from './missions/torre.js';", "import {TORRE} from './missions/torre.js';\nimport {JARDINS} from './missions/jardins.js';"),
    ("doca:DOCA,torre:TORRE};", "doca:DOCA,torre:TORRE,jardins:JARDINS};"),
])

patch('js/sim.js', 'u.safeRoom', [
    ("function updVip(u,dt){\n", "function updVip(u,dt){\n  if(u.safe){u.path=null;return;}\n"),
    ("else{M.flags.heliGo=true;endMission", "else if(u.safeRoom){u.safe=true;u.path=null;}else{M.flags.heliGo=true;endMission"),
    ("if(!u.fleeing){u.fleeing=true;u.path=null;if(!u.double)log(`${u.nome} está fugindo para o transporte de evacuação!`",
     "if(!u.fleeing){u.fleeing=true;u.path=null;if(!u.double)log(u.fleeMsg||`${u.nome} está fugindo para o transporte de evacuação!`"),
])

patch('js/script.js', 'block(x0,y0,x1,y1,on)', [
    ("    lampOff(l){hooks.destroy('lampoff',l);},",
     "    lampOff(l){hooks.destroy('lampoff',l);},\n    block(x0,y0,x1,y1,on){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){const i=y*57+x;M.tile[i]=on?2:4;M.walk[i]=on?0:1;}},"),
])

RENDER_HEDGE = r"""  buildGlassVents();
  {const hs=(M.blds||[]).filter(b=>b.style==='hedge');
   if(hs.length){const geos=[];for(const b of hs){const H=1.45+((b.x*7+b.y*13)%5)*.03;geos.push(box(b.w,H,b.d,b.x+b.w/2,H/2,b.y+b.d/2,'#1f4a2c'),box(b.w+.06,.08,b.d+.06,b.x+b.w/2,H,b.y+b.d/2,'#2e6a3c'));}
     const m=new THREE.Mesh(mergeGeometries(geos),vcMat);m.castShadow=m.receiveShadow=true;world.add(m);}}
"""

patch('js/render.js', "b.style==='hedge'", [
    ("function buildSpecial(b){\n", "function buildSpecial(b){\n  if(b.style==='hedge')return;\n"),
    ("  buildGlassVents();\n", RENDER_HEDGE),
    ("    camObjs.push({c,g,head,cone,led});",
     "    let spot=null;if(c.spot){spot=new THREE.Mesh(new THREE.CircleGeometry(1.5,20).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:'#fff2c0',transparent:true,opacity:.32,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));g.add(spot);g.children[0].scale.y=1.7;g.children[0].position.y=2.04;head.position.y=4;}\n    camObjs.push({c,g,head,cone,led,spot});"),
    ("    if(c.dead){o.head.rotation.z=.6;o.head.position.y=2.2;}",
     "    if(c.dead){o.head.rotation.z=.6;o.head.position.y=c.spot?3.8:2.2;}\n    if(o.spot){o.spot.visible=!c.dead&&!c.off;const d=c.range*.62;o.spot.position.set(Math.cos(c.a)*d,.05,Math.sin(c.a)*d);o.spot.material.opacity=c.see>0?.5:.3;}"),
    ("    if(o.heli&&o.d.alt!==undefined)", "    if(o.bdoor)o.bdoor.visible=!!M.flags[o.d.flag];\n    if(o.heli&&o.d.alt!==undefined)"),
    ("    }else if(d.type==='pipe'){",
     "    }else if(d.type==='blastdoor'){\n      const m=new THREE.Mesh(mergeGeometries([box(d.w||1,1.6,.3,0,.8,0,'#5a5f6a'),box((d.w||1)*.9,.12,.32,0,1.1,0,'#ffb13d'),box((d.w||1)*.9,.12,.32,0,.5,0,'#ffb13d')]),vcMat);m.castShadow=true;m.position.set(d.x,0,d.y);g.add(m);o.bdoor=m;m.visible=false;\n    }else if(d.type==='pipe'){"),
])
