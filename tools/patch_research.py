"""Patch único: Fase 2 — pesquisa e desenvolvimento (registro da mudança)."""
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

# ---------------- dados ----------------
patch('js/core.js', [
    ("  escopeta:{nome:'Escopeta Trovão',ab:'TROVÃO',arma:1,dano:10,pellets:6,alcance:4.5,cad:.8,pente:8,recarga:2,disp:.2,preco:4200,som:'shot',req:1,",
     "  escopeta:{nome:'Escopeta Trovão',ab:'TROVÃO',arma:1,dano:10,pellets:6,alcance:4.5,cad:.8,pente:8,recarga:2,disp:.2,preco:4200,som:'shot',res:'escopeta',"),
    ("preco:6500,som:'flame',req:2,", "preco:6500,som:'flame',res:'chamas',"),
    ("preco:12500,som:'laser',req:4,", "preco:12500,som:'laser',res:'feixe',"),
    ("preco:17000,som:'smg',req:6,", "preco:17000,som:'smg',res:'serra',"),
    ("  chave:{nome:'Chave Fantasma',ab:'CHAVE',hack:1,alcance:3,preco:2600,req:1,",
     "  incendiaria:{nome:'Granada incendiária',ab:'INCEND.',throw:1,incend:1,dano:35,raio:1.4,alcance:7,preco:900,res:'incend',desc:'Explosão menor, mas cobre a área de fogo por vários segundos.'},\n  manto:{nome:'Manto óptico',ab:'MANTO',manto:1,preco:3200,res:'manto',desc:'Equipado, deixa o agente invisível por até 25 s por missão. Com o manto ativo não dá para atirar.'},\n  chave:{nome:'Chave Fantasma',ab:'CHAVE',hack:1,alcance:3,preco:2600,res:'chave',"),
    ("export const SHOP=['pistola','smg','escopeta','chamas','feixe','serra','granada','medkit','chave','sonda'];",
     "export const SHOP=['pistola','smg','escopeta','chamas','feixe','serra','granada','incendiaria','medkit','chave','sonda','manto'];"),
    ("export const equipable=t=>{const w=WD[t];return !!(w.arma||w.throw||w.hack||w.sonda);};",
     """export const equipable=t=>{const w=WD[t];return !!(w.arma||w.throw||w.hack||w.sonda||w.manto);};

/* pesquisa e desenvolvimento */
export const RESEARCH=[
  {id:'escopeta',cat:'Armas',nome:'Escopeta Trovão',custo:40,desc:'Libera a Escopeta Trovão no arsenal.'},
  {id:'pentes',cat:'Armas',nome:'Pentes estendidos',custo:60,desc:'+50% de munição por pente em todas as armas do esquadrão.'},
  {id:'perfurante',cat:'Armas',nome:'Munição perfurante',custo:70,req:['escopeta'],desc:'Os disparos do esquadrão ignoram metade da blindagem inimiga.'},
  {id:'chamas',cat:'Armas',nome:'Lança-chamas Brasa',custo:80,req:['escopeta'],desc:'Libera o lança-chamas.'},
  {id:'incend',cat:'Armas',nome:'Granada incendiária',custo:90,req:['chamas'],desc:'Libera a granada que espalha fogo pela área.'},
  {id:'feixe',cat:'Armas',nome:'Rifle de feixe Agulha',custo:150,req:['perfurante'],desc:'Libera o rifle de feixe, que atravessa alvos em linha.'},
  {id:'serra',cat:'Armas',nome:'Minigun Serra',custo:200,req:['feixe','pentes'],desc:'Libera a minigun.'},
  {id:'impl2',cat:'Cibernética',nome:'Implantes Mk II',custo:90,desc:'Permite instalar implantes de nível 2.'},
  {id:'reparo',cat:'Cibernética',nome:'Reparo subdérmico',custo:100,desc:'Agentes regeneram integridade depois de 5 s sem serem atingidos.'},
  {id:'blindagem',cat:'Cibernética',nome:'Blindagem reativa',custo:130,req:['impl2'],desc:'+10% de blindagem em todos os agentes.'},
  {id:'impl3',cat:'Cibernética',nome:'Implantes Mk III',custo:220,req:['impl2'],desc:'Permite instalar implantes de nível 3.'},
  {id:'sonda2',cat:'Neural',nome:'Sonda amplificada',custo:70,desc:'Alcance da sonda +1 e força +30%.'},
  {id:'estab',cat:'Neural',nome:'Estabilizador neural',custo:80,desc:'A sobrecarga drena 30% menos e gera metade da dependência.'},
  {id:'armados',cat:'Neural',nome:'Seguidores armados',custo:90,req:['sonda2'],desc:'Civis recrutados pela sonda já vêm com uma pistola.'},
  {id:'limpa',cat:'Neural',nome:'Sobrecarga limpa',custo:170,req:['estab'],desc:'O colapso dura metade e a sobrecarga não gera dependência.'},
  {id:'sonda3',cat:'Neural',nome:'Sonda de massa',custo:180,req:['sonda2'],desc:'Força da sonda +60%. Até agentes do Consórcio cedem rápido.'},
  {id:'chave',cat:'Equipamento',nome:'Chave Fantasma',custo:50,desc:'Libera a ferramenta que invade torretas.'},
  {id:'nanomed',cat:'Equipamento',nome:'Nanomedkit',custo:60,desc:'O kit médico cura todos os agentes num raio de 2,5.'},
  {id:'manto',cat:'Equipamento',nome:'Manto óptico',custo:160,req:['chave'],desc:'Libera o manto: invisibilidade por 25 s por missão.'},
  {id:'informantes',cat:'Operações',nome:'Rede de informantes',custo:80,desc:'+20% de recompensa nas missões.'},
  {id:'trafego',cat:'Operações',nome:'Hackers de tráfego',custo:90,desc:'Reforços policiais demoram mais e a polícia desiste mais rápido.'},
  {id:'lavagem',cat:'Operações',nome:'Lavagem de dinheiro',custo:120,req:['informantes'],desc:'+25% na renda dos distritos.'},
];
export const RES_CATS=['Armas','Cibernética','Neural','Equipamento','Operações'];
export const CIENT_PRECO=2500,CIENT_SAL=150,PD_POR_CIENT=10,MAX_CIENT=20;
export const has=id=>!!(G&&G.pesq&&G.pesq.done[id]);
export const penteOf=(u,wk)=>Math.round(WD[wk].pente*(u&&u.kind==='agente'&&has('pentes')?1.5:1));"""),
])

# ---------------- mundo ----------------
patch('js/world.js', [
    ("  M,G,setM,DIST,KIND,SKIN,HAIR,WD,VIPS,CIENT,SIGNS,NEON} from './core.js';",
     "  M,G,setM,DIST,KIND,SKIN,HAIR,WD,VIPS,CIENT,SIGNS,NEON,has,penteOf} from './core.js';"),
    ("u.armor=.07*im.chassi;", "u.armor=.07*im.chassi+(has('blindagem')?.1:0);"),
    ("  u.inv=a.inv.map(it=>({t:it.t,mun:WD[it.t].pente||0}));u.eq=-1;",
     "  u.inv=a.inv.map(it=>({t:it.t,mun:WD[it.t].pente?penteOf(u,it.t):0}));u.eq=-1;"),
])

# ---------------- simulação ----------------
patch('js/sim.js', [
    ("clamp,gauss,pick,M,flags,hooks,WD,MAXINV,RESIST,PRESETS,REDUCED,equipable} from './core.js';",
     "clamp,gauss,pick,M,flags,hooks,WD,MAXINV,RESIST,PRESETS,REDUCED,equipable,has,penteOf} from './core.js';"),
    # manto: invisível para quem procura alvos
    ("  for(const v of M.units){if(v===u||v.dead||!isEnemyOf(u,v))continue;const p=posOf(v),d=Math.hypot(p.x-u.x,p.y-u.y);if(d<bd&&los(",
     "  for(const v of M.units){if(v===u||v.dead||!isEnemyOf(u,v))continue;const p=posOf(v),d=Math.hypot(p.x-u.x,p.y-u.y);if(v.cloak&&d>1.5)continue;if(d<bd&&los("),
    ("    if(a.dead||a.inCar)continue;const d=Math.hypot(a.x-u.x,a.y-u.y);",
     "    if(a.dead||a.inCar||a.cloak)continue;const d=Math.hypot(a.x-u.x,a.y-u.y);"),
    ("for(const a of M.agents)if(!a.dead&&!a.inCar&&isArmed(a)&&", "for(const a of M.agents)if(!a.dead&&!a.inCar&&!a.cloak&&isArmed(a)&&"),
    ("  if(t&&(t.dead||!isEnemyOf(u,t)))t=u.tgt=null;",
     "  if(t&&(t.dead||!isEnemyOf(u,t)||(t.cloak&&Math.hypot(t.x-u.x,t.y-u.y)>1.5)))t=u.tgt=null;"),
    # polícia (hackers de tráfego)
    ("  M.policeAggro=40;", "  M.policeAggro=has('trafego')?26:40;"),
    ("else{M.reinfT-=dt;if(M.reinfT<=0&&!M.demo){M.reinfT=20;spawnReinforcements();}}",
     "else{M.reinfT-=dt;if(M.reinfT<=0&&!M.demo){M.reinfT=has('trafego')?35:20;spawnReinforcements();}}"),
    # munição perfurante e reparo
    ("  v.hp-=dmg*(1-(v.armor||0));v.hitT=.08;v.barT=3;",
     "  v.hp-=dmg*(1-(v.armor||0)*(src&&src.fac==='player'&&has('perfurante')?.5:1));v.hitT=.08;v.barT=3;v.lastHit=M.t;"),
    # sonda
    ("  const pw=Math.min(4,1+.2*M.followers)*(.7+.6*u.nr.c);",
     "  const pw=Math.min(4,1+.2*M.followers)*(.7+.6*u.nr.c)*(has('sonda2')?1.3:1)*(has('sonda3')?1.6:1),rng=w.alcance+(has('sonda2')?1:0);"),
    ("if(d>w.alcance||!los(u.x,u.y,v.x,v.y))continue;", "if(d>rng||!los(u.x,u.y,v.x,v.y))continue;"),
    ("  M.followers++;M.stats.seguidores++;",
     "  if(v.kind==='civil'&&has('armados')&&!v.w){v.w='pistola';v.mun=WD.pistola.pente;}\n  M.followers++;M.stats.seguidores++;"),
    # estabilidade neural
    ("  else if(load>0){u.estab-=dt*load*10*(1-cx*.2);u.over+=dt*load;if(u.estab<=0){u.estab=0;u.colapso=6;",
     "  else if(load>0){u.estab-=dt*load*10*(1-cx*.2)*(has('estab')?.7:1);u.over+=dt*load;if(u.estab<=0){u.estab=0;u.colapso=has('limpa')?3:6;"),
    ("  const m=u.neuro=neuroMods(u);",
     "  if(has('reparo')&&!u.dead&&u.hp<u.maxHp&&M.t-(u.lastHit??-99)>5)u.hp=Math.min(u.maxHp,u.hp+dt*2.5);\n  const m=u.neuro=neuroMods(u);"),
    # manto: bateria e estado
    ("  if(w&&w.sonda)hijackTick(u,dt,w);else u.probing=false;",
     "  if(w&&w.sonda)hijackTick(u,dt,w);else u.probing=false;\n  if(w&&w.manto){if(it.bat===undefined)it.bat=25;if(it.bat>0){it.bat-=dt;u.cloak=true;if(it.bat<=0){u.cloak=false;log(`O manto de ${u.nome} descarregou.`,'amber');flags.hud=true;}}else u.cloak=false;}else u.cloak=false;"),
    # granadas genéricas (incendiária)
    ("      const d=Math.hypot(o.x-u.x,o.y-u.y),ii=u.inv.findIndex(q=>q.t==='granada');",
     "      const gt=o.wt||'granada',d=Math.hypot(o.x-u.x,o.y-u.y),ii=u.inv.findIndex(q=>q.t===gt);"),
    ("M.nades.push({sx:u.x,sy:u.y,tx:o.x,ty:o.y,t:0,T:.5+d*.07,src:u});",
     "M.nades.push({sx:u.x,sy:u.y,tx:o.x,ty:o.y,t:0,T:.5+d*.07,src:u,wt:gt});"),
    ("        removeItem(u,ii);const nx=u.inv.findIndex(q=>q.t==='granada');",
     "        removeItem(u,ii);const nx=u.inv.findIndex(q=>q.t===gt);"),
    ("explode(q.tx,q.ty,WD.granada.raio,WD.granada.dano,q.src);}}}",
     "const W=WD[q.wt||'granada'];explode(q.tx,q.ty,W.raio,W.dano,q.src);if(W.incend)for(let k=0;k<8;k++){const a=k/8*TAU,r=k%2?1.5:.8;addFire(q.tx+Math.cos(a)*r,q.ty+Math.sin(a)*r,10+Math.random()*4);}}}}"),
    ("    else if(w&&w.throw)u.ord={k:'throw',x:t.x,y:t.y};", "    else if(w&&w.throw)u.ord={k:'throw',x:t.x,y:t.y,wt:it.t};"),
    ("if(w.throw)u.ord={k:'throw',x:p.x,y:p.y};", "if(w.throw)u.ord={k:'throw',x:p.x,y:p.y,wt:it.t};"),
    # pentes estendidos
    ("u.relSt.mun=WD[u.relW].pente;u.relSt=null;", "u.relSt.mun=penteOf(u,u.relW);u.relSt=null;"),
    ("u.inv.push({t:d.t,mun:WD[d.t].pente});", "u.inv.push({t:d.t,mun:penteOf(u,d.t)});"),
    # nanomedkit
    ("    L.hp=L.maxHp;removeItem(L,i);log(`${L.nome} usou um kit médico.`,'green');sfx('hack');return;",
     "    if(has('nanomed')){let n=0;for(const a of M.agents)if(!a.dead&&Math.hypot(a.x-L.x,a.y-L.y)<2.5){a.hp=a.maxHp;n++;}removeItem(L,i);log(`Nanomedkit: ${n} agente${n>1?'s':''} restaurado${n>1?'s':''}.`,'green');sfx('hack');return;}\n    L.hp=L.maxHp;removeItem(L,i);log(`${L.nome} usou um kit médico.`,'green');sfx('hack');return;"),
])

# ---------------- render: agente com manto fica translúcido ----------------
patch('js/render.js', [
    ("  r.fig.position.y=u.hitT>0?.03:0;",
     "  r.fig.position.y=u.hitT>0?.03:0;\n  const cl=!!u.cloak;if(r.cl!==cl){r.cl=cl;r.fig.traverse(o=>{if(o.isMesh&&o.material===(cl?vcMat:cloakMat))o.material=cl?cloakMat:vcMat;});}"),
    ("const vcMat=new THREE.MeshLambertMaterial({vertexColors:true});vcMat.userData.shared=true;",
     "const vcMat=new THREE.MeshLambertMaterial({vertexColors:true});vcMat.userData.shared=true;\nconst cloakMat=new THREE.MeshLambertMaterial({vertexColors:true,transparent:true,opacity:.18,depthWrite:false,emissive:'#1a6f88'});cloakMat.userData.shared=true;"),
])

# ---------------- interface ----------------
patch('js/ui.js', [
    ("  WD,SHOP,IMP,IMP_PRECO,RECRUTA,MAXINV,CLINICA,PRESETS,CODINOMES,TIPOS,DIST,BAY,ADJ,equipable} from './core.js';",
     "  WD,SHOP,IMP,IMP_PRECO,RECRUTA,MAXINV,CLINICA,PRESETS,CODINOMES,TIPOS,DIST,BAY,ADJ,equipable,\n  RESEARCH,RES_CATS,CIENT_PRECO,CIENT_SAL,PD_POR_CIENT,MAX_CIENT,has,penteOf} from './core.js';"),
    ("w.heal?'USAR':w.throw?'ARREMESSAR':w.sonda?'SEQUESTRAR':'INVADIR'}",
     "w.heal?'USAR':w.throw?'ARREMESSAR':w.sonda?'SEQUESTRAR':w.manto?Math.ceil(it.bat??25)+' s':'INVADIR'}"),
    ("if(el)el.textContent=(L.rel>0&&L.relSt===it)?'RECARGA':`${it.mun}/${w.pente}`;});",
     "if(el)el.textContent=(L.rel>0&&L.relSt===it)?'RECARGA':`${it.mun}/${penteOf(L,it.t)}`;});\n  if(L)L.inv.forEach((it,i)=>{if(!WD[it.t].manto)return;const el=document.querySelector(`[data-mun=\"${i}\"]`);if(el)el.textContent=Math.max(0,Math.ceil(it.bat??25))+' s';});"),
    ("const g=JSON.parse(s);g.agentes.forEach(a=>{a.dep=a.dep||0;});return g;}",
     "const g=JSON.parse(s);g.agentes.forEach(a=>{a.dep=a.dep||0;});g.pesq=g.pesq||{done:{},prog:{},ativo:null};if(g.cientistas===undefined)g.cientistas=3;return g;}"),
    ("  setG({v:2,dinheiro:16000,dia:1,prox:1,agentes:[],esq:[],dono:DIST.map(()=>'corp'),abates:0,vitoria:false});",
     "  setG({v:3,dinheiro:16000,dia:1,prox:1,agentes:[],esq:[],dono:DIST.map(()=>'corp'),abates:0,vitoria:false,cientistas:3,pesq:{done:{},prog:{},ativo:'escopeta'}});"),
    # loja trava por pesquisa
    ("    const w=WD[t],lock=own<w.req;", "    const w=WD[t],lock=!!w.res&&!has(w.res),resName=w.res?(RESEARCH.find(r=>r.id===w.res)||{}).nome:'';"),
    ("${lock?`<span class=\"st\">Requer ${w.req} distrito${w.req>1?'s':''} sob controle</span>`",
     "${lock?`<span class=\"st\">Requer pesquisa: ${resName}</span>`"),
    # implantes limitados pela pesquisa
    ("    for(const k in IMP){const lv=a.imp[k],pr=IMP_PRECO[lv];mid+=`<div class=\"imp\"><span class=\"t\">${IMP[k].nome}</span>${pips(lv,3)}${lv<3?`<button",
     "    const cap=1+(has('impl2')?1:0)+(has('impl3')?1:0);\n    for(const k in IMP){const lv=a.imp[k],pr=IMP_PRECO[lv];mid+=`<div class=\"imp\"><span class=\"t\">${IMP[k].nome}</span>${pips(lv,3)}${lv<3&&lv>=cap?`<span class=\"mono\" style=\"color:var(--dim);font-size:11px\">Requer Mk ${lv===1?'II':'III'}</span>`:lv<3?`<button"),
    ("if(a.imp[k]<3&&G.dinheiro>=pr){", "if(a.imp[k]<1+(has('impl2')?1:0)+(has('impl3')?1:0)&&G.dinheiro>=pr){"),
    # relatório: pesquisa, cientistas, bônus de operações
    ("a.dep=Math.min(50,(a.dep||0)+Math.round(u.over*1.5));}",
     "a.dep=Math.min(50,(a.dep||0)+Math.round(u.over*1.5*(has('estab')?.5:1)*(has('limpa')?0:1)));}"),
    ("  if(win){G.dono[di]='player';reward=D.recompensa+bonus;G.dinheiro+=reward;}\n  const renda=DIST.reduce((s,q,i)=>s+(G.dono[i]==='player'?q.renda:0),0);G.dinheiro+=renda;",
     """  if(win){G.dono[di]='player';reward=Math.round((D.recompensa+bonus)*(has('informantes')?1.2:1));G.dinheiro+=reward;}
  const renda=Math.round(DIST.reduce((s,q,i)=>s+(G.dono[i]==='player'?q.renda:0),0)*(has('lavagem')?1.25:1));G.dinheiro+=renda;
  const lab=researchTick(win&&D.tipo==='extracao');"""),
    ("    ${contra?`<p style=\"color:var(--red)\">${contra}</p>`:''}",
     "    <div class=\"labrep\">${lab}</div>\n    ${contra?`<p style=\"color:var(--red)\">${contra}</p>`:''}"),
    # botões e telas
    ("$('#btnArs').onclick=()=>showArsenal();", "$('#btnArs').onclick=()=>showArsenal();\n$('#btnLab').onclick=()=>showLab();"),
    ("  <dl class=\"kv\"><dt>Renda atual da Ônix</dt><dd>${fmt(incomes)}/dia</dd><dt>Esquadrão</dt><dd>${G.esq.length}/4 agentes</dd></dl>",
     "  <dl class=\"kv\"><dt>Renda atual da Ônix</dt><dd>${fmt(incomes)}/dia</dd><dt>Esquadrão</dt><dd>${G.esq.length}/4 agentes</dd><dt>Laboratório</dt><dd>${labLine()}</dd></dl>"),
    ("function show(id){['#scrTitle','#scrMap','#scrArs','#hud'].forEach(",
     "function show(id){['#scrTitle','#scrMap','#scrArs','#scrLab','#hud'].forEach("),
    ("/* ---------- missão ---------- */",
     r"""/* --- laboratório --- */
const resById=id=>RESEARCH.find(r=>r.id===id);
const resAvail=r=>!has(r.id)&&(r.req||[]).every(has);
const pdDia=()=>G.cientistas*PD_POR_CIENT;
function labLine(){const a=G.pesq.ativo&&resById(G.pesq.ativo);if(!a)return '<span style="color:var(--amber)">ocioso</span>';const p=G.pesq.prog[a.id]||0;return `${a.nome} · ${Math.ceil((a.custo-p)/Math.max(1,pdDia()))} dia(s)`;}
function researchTick(extracted){
  const out=[];
  if(extracted){const n=2;G.cientistas=Math.min(MAX_CIENT,G.cientistas+n);out.push(`<b>+${n} cientistas</b> desertaram com a extraída e se juntaram ao laboratório.`);}
  const sal=G.cientistas*CIENT_SAL;G.dinheiro-=sal;
  const a=G.pesq.ativo&&resById(G.pesq.ativo);
  if(a){
    G.pesq.prog[a.id]=(G.pesq.prog[a.id]||0)+pdDia();
    if(G.pesq.prog[a.id]>=a.custo){G.pesq.done[a.id]=true;G.pesq.ativo=null;out.push(`<b style="color:var(--green)">Pesquisa concluída: ${a.nome}.</b> ${a.desc}`);
      const nxt=RESEARCH.find(resAvail);if(nxt){G.pesq.ativo=nxt.id;out.push(`O laboratório começou ${nxt.nome}.`);}}
    else out.push(`Laboratório: +${pdDia()} PD em ${a.nome} (${G.pesq.prog[a.id]}/${a.custo}).`);
  }else out.push('<span style="color:var(--amber)">O laboratório ficou ocioso. Escolha uma pesquisa.</span>');
  out.push(`Salários de ${G.cientistas} cientistas: ${fmt(sal)}.`);
  return out.map(t=>`<p>${t}</p>`).join('');
}
function showLab(){setState('menu');show('#scrLab');hideModal();renderLab();}
function renderLab(){
  $('#labStats').innerHTML=`<span>FUNDOS <b>${fmt(G.dinheiro)}</b></span><span>CIENTISTAS <b>${G.cientistas}</b></span><span>PRODUÇÃO <b>${pdDia()} PD/dia</b></span><span>SALÁRIOS <b>${fmt(G.cientistas*CIENT_SAL)}/dia</b></span>`;
  const a=G.pesq.ativo&&resById(G.pesq.ativo),p=a?(G.pesq.prog[a.id]||0):0;
  let side=`<h3>Projeto em andamento</h3>`;
  if(a)side+=`<div class="labcur"><b>${a.nome}</b><span class="mono">${p}/${a.custo} PD · ${Math.ceil((a.custo-p)/Math.max(1,pdDia()))} dia(s)</span><span class="bar"><i style="width:${p/a.custo*100}%"></i></span><small>${a.desc}</small></div>`;
  else side+=`<p class="hint" style="color:var(--amber)">Nenhum projeto ativo. Escolha um ao lado.</p>`;
  side+=`<h3>Equipe científica</h3><p class="hint">Cada cientista produz ${PD_POR_CIENT} PD por dia e custa ${fmt(CIENT_SAL)} de salário. Um dia passa a cada missão. Missões de extração trazem cientistas desertores de graça.</p>
    <button class="btn sm" data-act="hire" ${G.dinheiro<CIENT_PRECO||G.cientistas>=MAX_CIENT?'disabled':''}>Contratar cientista · ${fmt(CIENT_PRECO)}</button>
    <button class="btn sm" data-act="fire" ${G.cientistas<=1?'disabled':''}>Dispensar um cientista</button>
    <h3>Concluídas</h3><p class="hint">${RESEARCH.filter(r=>has(r.id)).map(r=>r.nome).join(' · ')||'nenhuma ainda'}</p>`;
  let tree='';
  for(const cat of RES_CATS){
    tree+=`<div class="rcol"><h3>${cat}</h3>`;
    for(const r of RESEARCH.filter(q=>q.cat===cat)){
      const done=has(r.id),av=resAvail(r),act=G.pesq.ativo===r.id,pr=G.pesq.prog[r.id]||0;
      const st=done?'done':act?'act':av?'av':'lock';
      const reqTxt=(r.req||[]).filter(x=>!has(x)).map(x=>resById(x).nome).join(', ');
      tree+=`<button class="rnode ${st}" data-act="res" data-id="${r.id}" ${done||!av?'disabled':''}><span class="rn">${r.nome}</span><span class="rc mono">${done?'CONCLUÍDA':act?'EM ANDAMENTO':`${r.custo} PD`}</span><small>${r.desc}</small>${pr&&!done?`<span class="bar"><i style="width:${pr/r.custo*100}%"></i></span>`:''}${!done&&!av?`<span class="rq">Requer ${reqTxt}</span>`:''}</button>`;
    }
    tree+='</div>';
  }
  $('#labGrid').innerHTML=`<div class="col labside">${side}</div><div class="col labtree">${tree}</div>`;
}
$('#scrLab').addEventListener('click',e=>{
  const b=e.target.closest('[data-act]');if(!b||b.disabled)return;const act=b.dataset.act;
  if(act==='back'){showMap();return;}
  if(act==='res'){G.pesq.ativo=b.dataset.id;}
  else if(act==='hire'){if(G.dinheiro>=CIENT_PRECO&&G.cientistas<MAX_CIENT){G.dinheiro-=CIENT_PRECO;G.cientistas++;}}
  else if(act==='fire'){if(G.cientistas>1)G.cientistas--;}
  sfx('ui');save();renderLab();
});

/* ---------- missão ---------- */"""),
])

patch('body.html', [
    ("      <button class=\"btn sm\" id=\"btnArs\">Equipe e arsenal</button>",
     "      <button class=\"btn sm\" id=\"btnArs\">Equipe e arsenal</button>\n      <button class=\"btn sm\" id=\"btnLab\">Laboratório</button>"),
    ("<div id=\"hud\" hidden>",
     """<div id="scrLab" class="screen" hidden>
  <div class="topbar">
    <h1>LABORATÓRIO <span>ÔNIX</span></h1>
    <div class="stats" id="labStats"></div>
    <button class="btn sm" data-act="back">Voltar ao mapa</button>
  </div>
  <div class="labgrid" id="labGrid"></div>
</div>

<div id="hud" hidden>"""),
])

patch('hud.css', [
    ("#hudBot,#hudTop,#miniBox{transition:opacity .5s}",
     """#hudBot,#hudTop,#miniBox{transition:opacity .5s}
#scrLab{background:var(--bg);display:grid;grid-template-rows:auto 1fr;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
.labgrid{display:grid;grid-template-columns:300px minmax(0,1fr);gap:16px;padding-block:16px;min-height:0}
.labtree{display:grid!important;grid-template-columns:repeat(5,minmax(170px,1fr));gap:12px;align-items:start;overflow:auto}
.rcol{display:flex;flex-direction:column;gap:8px;min-width:0}
.rnode{display:flex;flex-direction:column;gap:5px;text-align:left;padding:10px;border:1px solid var(--line);background:#0b0f19;cursor:pointer;color:var(--fg);font-family:var(--display)}
.rnode .rn{font-weight:600;font-size:14px}
.rnode .rc{font-size:11px;color:var(--amber);letter-spacing:.06em}
.rnode small{font-size:12px;color:var(--dim);line-height:1.4}
.rnode .rq{font:11px var(--mono);color:#8a6a70}
.rnode.av:hover{border-color:var(--amber);background:#17140e}
.rnode.act{border-color:var(--amber);background:#1b150b;box-shadow:inset 3px 0 0 var(--amber)}
.rnode.done{border-color:#1f5a3e;cursor:default}
.rnode.done .rc{color:var(--green)}
.rnode.lock{opacity:.45;cursor:not-allowed}
.rnode .bar,.labcur .bar{height:4px;background:#1a2132;display:block;position:relative}
.rnode .bar i,.labcur .bar i{position:absolute;inset:0 auto 0 0;background:var(--amber);display:block}
.labcur{display:flex;flex-direction:column;gap:6px;border:1px solid var(--amber);padding:12px}
.labcur .mono{font-size:12px;color:var(--dim)}
.labcur small{color:var(--dim);font-size:12px;line-height:1.4}
.labside .btn{align-self:flex-start}
.labrep p{font-size:13px;margin:0 0 4px}
@media (max-width:1100px){.labgrid{grid-template-columns:1fr;overflow:auto}.labtree{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media (max-width:620px){.labtree{grid-template-columns:1fr}}"""),
])
print('ok')
