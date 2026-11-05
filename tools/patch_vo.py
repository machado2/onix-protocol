"""Patch único: liga as falas aos eventos da simulação (já aplicado; mantido como registro)."""
import os, sys
JS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2', 'js')

def patch(fn, reps):
    p = os.path.join(JS, fn)
    s = open(p, encoding='utf-8').read()
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:80]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('core.js', [
    ("export const hooks={log(){},end(){},decal(){},convert(){}};", "export const hooks={log(){},end(){},decal(){},convert(){},vo(){}};"),
    ("export const settings={pix:2,bloom:true,shadows:true};", "export const settings={pix:2,bloom:true,shadows:true,mus:.6,sfx:1,vo:1};"),
])
patch('world.js', [
    ("u.ag=a;u.nome=a.nome;u.num=k+1;", "u.ag=a;u.nome=a.nome;u.num=k+1;u.voz=a.voz||(a.id%2?'m':'f');u.vozRate=.95+((a.id*37)%10)/100;"),
])
patch('sim.js', [
    ("  if(!M.corpAlert){M.corpAlert=true;log('ALERTA: a segurança do Consórcio detectou o esquadrão.','red');sfx('alarm');}",
     "  if(!M.corpAlert){M.corpAlert=true;log('ALERTA: a segurança do Consórcio detectou o esquadrão.','red');sfx('alarm');hooks.vo(v.kind==='inimigo'?'ene:alert':'grd:alert',v);hooks.vo('ctl:alarm');}"),
    ("function triggerPolice(msg){\n  if(M.policeAggro<=0){log(msg,'red');sfx('siren');M.reinfT=14;}",
     "function triggerPolice(msg,who){\n  if(M.policeAggro<=0){log(msg,'red');sfx('siren');M.reinfT=14;const p=who||M.units.find(q=>q.kind==='policia'&&!q.dead&&!q.follower);if(p)hooks.vo('pol:fire',p);hooks.vo('ctl:police');}"),
    ("      if(d<9&&los(v.x,v.y,src.x,src.y))triggerPolice('A polícia viu o esquadrão atirando.');",
     "      if(d<9&&los(v.x,v.y,src.x,src.y))triggerPolice('A polícia viu o esquadrão atirando.',v);"),
    ("    if(v.kind==='civil'){if(v.panicT<=0)v.path=null;v.panicT=6+Math.random()*4;v.pfx=x;v.pfy=y;}",
     "    if(v.kind==='civil'){if(v.panicT<=0){v.path=null;if(Math.random()<.15)hooks.vo('civ',v);}v.panicT=6+Math.random()*4;v.pfx=x;v.pfy=y;}"),
    ("  st.mun--;if(st.mun<=0){u.rel=w.recarga;u.relSt=st;u.relW=wk;}",
     "  st.mun--;if(st.mun<=0){u.rel=w.recarga;u.relSt=st;u.relW=wk;if(u.kind==='agente'&&Math.random()<.5)hooks.vo('ag:rel',u);}\n  if(u.fac==='player'||u.alerted||(u.fac==='police'&&M.policeAggro>0))M.lastCombat=M.t;"),
    ("  else{if(car)hurtCar(car,dmg,u);for(let k=0;k<3;k++)",
     "  else{if(car)hurtCar(car,dmg,u);else if(bt<range-.2&&Math.random()<.25)sfx('ric',ex,ey);for(let k=0;k<3;k++)"),
    ("  v.hp-=dmg*(1-(v.armor||0));v.hitT=.08;v.barT=3;",
     "  v.hp-=dmg*(1-(v.armor||0));v.hitT=.08;v.barT=3;if(v.kind!=='torre')sfx('hit',v.x,v.y);\n  if(v.kind==='agente'){M.lastCombat=M.t;if(v.hp>0&&v.hp<v.maxHp*.55)hooks.vo('ag:hurt',v);}"),
    ("    if(v.fac==='police')triggerPolice('O esquadrão atacou a polícia.');",
     "    if(v.fac==='police')triggerPolice('O esquadrão atacou a polícia.',v);"),
    ("    if(src.kind==='agente')src.kills++;\n  }",
     "    if(src.kind==='agente'){src.kills++;if(v.kind!=='civil'&&Math.random()<.55)hooks.vo('ag:kill',src);}\n  }\n  if(v.kind==='guarda'&&!v.follower){const b=M.units.find(q=>q.kind==='guarda'&&!q.dead&&!q.follower&&Math.hypot(q.x-v.x,q.y-v.y)<8);if(b&&Math.random()<.4)hooks.vo('grd:down',b);}"),
    ("  if(v.kind==='agente'){log(`Agente ${v.nome} foi abatido.`,'red');M.sel=M.sel.filter(a=>a!==v);v.sel=false;flags.hud=true;}",
     "  if(v.kind==='agente'){log(`Agente ${v.nome} foi abatido.`,'red');M.sel=M.sel.filter(a=>a!==v);v.sel=false;flags.hud=true;const o=M.agents.find(a=>!a.dead);if(o)hooks.vo('ag:down',o);hooks.vo('ctl:lost');}"),
    ("  say(v,'...sim.','#4fd8ff');sfx('convert',v.x,v.y);hooks.convert(v);",
     "  say(v,'...sim.','#4fd8ff');sfx('convert',v.x,v.y);hooks.convert(v);if(Math.random()<.6)hooks.vo('ag:conv',owner);"),
    ("    if(u.kind==='policia'&&!u.follower){M.policeAggro=Math.max(M.policeAggro,30);M.lastSeen={x:tp.x,y:tp.y};}",
     "    if(u.kind==='policia'&&!u.follower){M.policeAggro=Math.max(M.policeAggro,30);M.lastSeen={x:tp.x,y:tp.y};}\n    if(!u.contact&&!u.follower){u.contact=true;if(u.kind==='guarda')hooks.vo('grd:contact',u);else if(u.kind==='inimigo')hooks.vo('ene:alert',u);}"),
    ("if(!u.warned){u.warned=true;u.warnT=3.5;say(u,'LARGUEM AS ARMAS!','#9fc3ff');log(",
     "if(!u.warned){u.warned=true;u.warnT=3.5;hooks.vo('pol:warn',u);log("),
    ("triggerPolice('A polícia abriu fogo contra o esquadrão!');}return;}",
     "triggerPolice('A polícia abriu fogo contra o esquadrão!',u);}return;}"),
    ("log(`${u.nome} está fugindo para o transporte de evacuação!`,'amber');say(u,'SEGURANÇA!','#ffd36b');}",
     "log(`${u.nome} está fugindo para o transporte de evacuação!`,'amber');hooks.vo('vip:flee',u);hooks.vo('ctl:target');}"),
    ("if(a){u.follow=true;say(u,'Me tirem daqui!','#c9ffe0');log(",
     "if(a){u.follow=true;hooks.vo('sci:join',u);log("),
    ("log(`${u.nome} entrou em colapso neural.`,'red');say(u,'COLAPSO','#ff4d5e');flags.hud=true;}",
     "log(`${u.nome} entrou em colapso neural.`,'red');hooks.vo('ag:crash',u);flags.hud=true;}"),
    ("M.nades.push({sx:u.x,sy:u.y,tx:o.x,ty:o.y,t:0,T:.5+d*.07,src:u});",
     "M.nades.push({sx:u.x,sy:u.y,tx:o.x,ty:o.y,t:0,T:.5+d*.07,src:u});hooks.vo('ag:grn',u);"),
    ("    if(tm.prog>=4){tm.done=true;log(",
     "    if(tm.prog>=4){tm.done=true;hooks.vo('ctl:term');log("),
    ("  if(c.occ.filter(o=>o.kind==='agente').length===1)log(",
     "  if(c.occ.filter(o=>o.kind==='agente').length===1)hooks.vo('ag:car',u);\n  if(c.occ.filter(o=>o.kind==='agente').length===1)log("),
    ("const u=mkUnit('policia',p.x,p.y);u.spd=1.9;}",
     "const u=mkUnit('policia',p.x,p.y);u.spd=1.9;if(!k)hooks.vo('pol:reinf',u);}"),
    ("  hooks.log(win?'OBJETIVO CUMPRIDO':'MISSÃO FRACASSADA',win?'green':'red');",
     "  hooks.log(win?'OBJETIVO CUMPRIDO':'MISSÃO FRACASSADA',win?'green':'red');hooks.vo(win?'ctl:win':'ctl:fail');"),
    ("  M.marks.push({x:p.x,y:p.y,life:.6,col:'#4fd8ff'});sfx('ui');\n}\nexport function issueAttack",
     "  M.marks.push({x:p.x,y:p.y,life:.6,col:'#4fd8ff'});sfx('ui');hooks.vo('ag:mov',sel[0]);\n}\nexport function issueAttack"),
    ("  M.marks.push({x:t.x,y:t.y,life:.6,col:'#ff4d5e'});flags.hud=true;",
     "  M.marks.push({x:t.x,y:t.y,life:.6,col:'#ff4d5e'});flags.hud=true;hooks.vo('ag:atk',sel[0]);"),
    ("else setSel([u]);sfx('ui');}",
     "else{setSel([u]);hooks.vo('ag:sel',u);}sfx('ui');}"),
    ("u.nr={r:p.r,p:p.p,c:p.c};});flags.hud=true;sfx('ui');}",
     "u.nr={r:p.r,p:p.p,c:p.c};});flags.hud=true;sfx('ui');if(i===2&&M.sel[0])hooks.vo('ag:over',M.sel[0]);}"),
])
print('ok')
