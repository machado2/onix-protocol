"""Patch: alarme e explosões no roteiro, rivais mortos não voltam, sósias no registro de abates."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')
def patch(fn, marker, reps):
    p = os.path.join(V2, fn); s = open(p, encoding='utf-8').read()
    if marker in s: print('já aplicado:', fn); return
    for a, b in reps:
        if a not in s: sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s); print('ok:', fn)
patch('js/script.js', 'alarm(){', [
    ("import {M,flags,hooks} from './core.js';", "import {M,G,flags,hooks} from './core.js';"),
    ("import {endMission,explode} from './sim.js';", "import {endMission,explode,alertCorp} from './sim.js';"),
    ("    boom(x,y,r,dmg){explode(x,y,r,dmg,M.agents.find(a=>!a.dead)||null);},",
     "    boom(x,y,r,dmg){explode(x,y,r,dmg,null);},\n"
     "    alarm(){const a=M.agents.find(q=>!q.dead),v=M.units.find(u=>!u.dead&&u.fac==='corp'&&!u.alerted&&!u.disguise&&!u.cand);if(a&&v)alertCorp(v,a.x,a.y);M.corpAlert=true;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise&&!u.cand){u.alerted=true;if(a)u.lkp={x:a.x,y:a.y};}},"),
    ("rival(id,x,y,hpMul=1){const u=spawnRival(id,x,y);", "rival(id,x,y,hpMul=1){if(G&&G.rivais&&G.rivais[id]&&G.rivais[id].morto)return null;const u=spawnRival(id,x,y);"),
])
patch('js/sim.js', 'export function alertCorp(', [
    ("function alertCorp(v,x,y){", "export function alertCorp(v,x,y){"),
    ("if(v.kind==='vip')log(`Alvo eliminado: ${v.nome}.`,'green');", "if(v.kind==='vip')log(v.double?'Um sósia foi abatido.':`Alvo eliminado: ${v.nome}.`,v.double?'amber':'green');"),
])
