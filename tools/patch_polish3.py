"""Polimento: dicas para as mecânicas novas, rótulo dos pilares, zumbido dos drones."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')
def patch(fn, marker, reps):
    p = os.path.join(V2, fn); s = open(p, encoding='utf-8').read()
    if marker in s: print('já aplicado:', fn); return
    for a, b in reps:
        if a not in s: sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s); print('ok:', fn)
near=lambda M_,x,y,r: f"M.agents.some(a=>!a.dead&&Math.hypot(a.x-({x}),a.y-({y}))<{r})"
patch('js/ui.js', "drone:'Drones", [
    ("  rotate:'Z e X giram a câmera quando um prédio atrapalha a visão. O scanner gira junto.',\n",
     "  rotate:'Z e X giram a câmera quando um prédio atrapalha a visão. O scanner gira junto.',\n"
     "  drone:'Drones de segurança voam por cima dos muros. Equipe a CHAVE FANTASMA e clique num drone para invadi-lo.',\n"
     "  vent:'A grade fica laranja e chia antes do vapor sair. Afaste o esquadrão e atraia os guardas para ela.',\n"
     "  laser:'Cruzar um feixe vermelho dispara o alarme. Alguns piscam: espere apagar para passar.',\n"
     "  glass:'Vidro não segura balas: os tiros atravessam e estilhaçam as paredes.',\n"
     "  heavy:'Soldados pesados aguentam muita bala comum. Granadas e munição perfurante funcionam melhor.',\n"
     "  shield:'O escudo azul vem dos pilares ligados por feixes. Derrube os pilares ou invada-os com a CHAVE FANTASMA.',\n"
     "  scan:'Sósias: fique perto de um suspeito, com as armas guardadas, até o anel do scanner fechar.',\n"),
    ("  if(M.t>45)tip('rotate');\n",
     "  if(M.t>45)tip('rotate');\n"
     "  const near=(x,y,r)=>M.agents.some(a=>!a.dead&&!a.inCar&&Math.hypot(a.x-x,a.y-y)<r);\n"
     "  if(M.units.some(u=>u.kind==='drone'&&!u.dead&&u.fac==='corp'&&near(u.x,u.y,10)))tip('drone');\n"
     "  if(M.vents&&M.vents.some(v=>!v.off&&near(v.x,v.y,4)))tip('vent');\n"
     "  if(M.lasers&&M.lasers.some(l=>l.on&&!l.dmg&&near((l.x1+l.x2)/2,(l.y1+l.y2)/2,6)))tip('laser');\n"
     "  if(M.glassN>0&&M.t>25)tip('glass');\n"
     "  if(M.units.some(u=>u.heavy&&u.contact&&!u.dead))tip('heavy');\n"
     "  if(M.boss&&M.boss.shield&&!M.boss.dead&&near(M.boss.x,M.boss.y,12))tip('shield');\n"
     "  if(M.cands&&!M.vip&&M.cands.some(v=>!v.dead&&near(v.x,v.y,7)))tip('scan');\n"),
    ("    case 'torre':return u.fac==='player'?'Torreta (invadida)':'Torreta automática · use a Chave Fantasma';",
     "    case 'torre':if(u.pylon)return u.fac==='player'?'Pilar de escudo (invadido)':'Pilar de escudo do Juiz · derrube ou use a Chave Fantasma';return u.fac==='player'?'Torreta (invadida)':'Torreta automática · use a Chave Fantasma';"),
])
patch('js/sim.js', "sfx('drone'", [
    ("function updDrone(u,dt){\n  u.path=null;\n",
     "function updDrone(u,dt){\n  u.path=null;\n  u.sndT=(u.sndT??Math.random()*2)-dt;if(u.sndT<=0){u.sndT=1.3+Math.random()*.6;sfx('drone',u.x,u.y);}\n"),
])
patch('js/audio.js', "case 'drone':", [
    ("    case 'steam':{", "    case 'drone':{const o=chain(sp,.1);tone(o,118*vary,124*vary,1.2,.05*v,'sawtooth');tone(o,236*vary,230*vary,1.2,.025*v,'square');break;}\n    case 'steam':{"),
])
