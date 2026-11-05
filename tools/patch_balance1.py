"""Patch único: balanceamento 1 — sobrevivência inicial, tempo de reação, economia e rede de segurança."""
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
    ("u.hp=u.maxHp=120+45*im.chassi;u.armor=.07*im.chassi+", "u.hp=u.maxHp=150+45*im.chassi;u.armor=.08+.07*im.chassi+"),
    ("u.hp=u.maxHp=60+dif*6;u.acc=.45+dif*.02;}", "u.hp=u.maxHp=60+dif*6;u.acc=.38+dif*.025;}"),
    ("u.hp=u.maxHp=100+dif*12;u.acc=.55+dif*.025;", "u.hp=u.maxHp=100+dif*12;u.acc=.5+dif*.028;"),
])
patch('js/core.js', [
    ("export const RECRUTA=6000,MAXINV=6,CLINICA=1200;", "export const RECRUTA=4000,MAXINV=6,CLINICA=1200;"),
])
patch('js/sim.js', [
    # tempo de reação: ninguém atira no mesmo instante em que percebe o esquadrão ou troca de alvo
    ("  v.alerted=true;v.lkp={x,y};", "  v.alerted=true;v.lkp={x,y};v.cool=Math.max(v.cool,.5+Math.random()*.6);"),
    ("if(nt)t=u.tgt=nt;}", "if(nt){if(nt!==t)u.cool=Math.max(u.cool,.25+Math.random()*.3);t=u.tgt=nt;}}"),
])
patch('js/missions/docas.js', [
    ("[39,27.5,0],[48.5,27.6,0],[36,14.2,0]", "[39,27.5,0]"),
    ("for(const c of [cars[0],cars[2]])if(!c.dead)for(let k=0;k<2;k++){", "for(const c of [cars[0],cars[2]])if(!c.dead)for(let k=0;k<1;k++){"),
])
patch('js/ui.js', [
    ("dinheiro:16000,", "dinheiro:18000,"),
    ("t.lealdade=clamp(45-3*M.stats.civis,10,60);", "t.lealdade=clamp(45-2*M.stats.civis,10,60);"),
    ("t.lealdade=clamp(55-3*M.stats.civis-4*M.stats.policiais,10,85);", "t.lealdade=clamp(55-2*M.stats.civis-3*M.stats.policiais,10,85);"),
    ("  const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;unlock(G,'fim');}",
     "  const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;unlock(G,'fim');}\n  let reposicao='';\n  if(G.agentes.length<2){const n=novoAgente();G.agentes.push(n);if(G.esq.length<4)G.esq.push(n.id);reposicao=`<p style=\"color:var(--cyan)\">A Ônix enviou um agente de reposição: ${n.nome}.</p>`;}"),
    ("    <div class=\"labrep\">${rivNote}${lab}${terrRep}${msgNote}</div>", "    <div class=\"labrep\">${rivNote}${reposicao}${lab}${terrRep}${msgNote}</div>"),
])
print('ok')
