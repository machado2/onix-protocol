"""Patch único: Fase 2 — economia de território (registro da mudança)."""
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

patch('js/core.js', [
    ("  {id:'lavagem',cat:'Operações',nome:'Lavagem de dinheiro',custo:120,req:['informantes'],desc:'+25% na renda dos distritos.'},",
     "  {id:'lavagem',cat:'Operações',nome:'Lavagem de dinheiro',custo:120,req:['informantes'],desc:'+25% na renda dos distritos.'},\n  {id:'propaganda',cat:'Operações',nome:'Propaganda',custo:100,desc:'+5 de lealdade por dia em todos os distritos da Ônix.'},"),
])

patch('js/world.js', [
    ("export function genMission(di,demo,squad){\n  if(!demo&&DIST[di].mission&&MISSIONS[DIST[di].mission])return genHandcrafted(di,MISSIONS[DIST[di].mission],squad);\n  const D=DIST[di],rng=",
     "export function genMission(di,demo,squad,opts){\n  const revolta=!!(opts&&opts.revolta);\n  if(!demo&&!revolta&&DIST[di].mission&&MISSIONS[DIST[di].mission])return genHandcrafted(di,MISSIONS[DIST[di].mission],squad);\n  const D=DIST[di],tipo=revolta?'eliminacao':D.tipo,rng="),
    ("    if(D.tipo==='sabotagem'||D.hq){", "    if(tipo==='sabotagem'||D.hq){"),
    ("  const m={di,D,demo:!!demo,tipo:D.tipo,", "  const m={di,D,demo:!!demo,revolta,tipo,"),
    ("    if(D.tipo==='assassinato'){", "    if(tipo==='assassinato'){"),
    ("    }else if(D.tipo==='extracao'){", "    }else if(tipo==='extracao'){"),
    ("    }else if(D.tipo==='sabotagem'){", "    }else if(tipo==='sabotagem'){"),
    ("    const nE=D.tipo==='eliminacao'?(D.hq?9:3+Math.ceil(dif/2)):", "    const nE=tipo==='eliminacao'?(revolta?2+Math.ceil(dif/3):D.hq?9:3+Math.ceil(dif/2)):"),
    ("  const nC=30+Math.round(D.riq*16);", "  const nC=30+Math.round(D.riq*16)+(revolta?22:0);"),
])

TERR = r"""/* --- território: impostos, lealdade e revoltas --- */
function terr(i){G.terr=G.terr||{};return G.terr[i]||(G.terr[i]={imposto:.3,lealdade:60,revolta:0});}
function distIncome(i){const t=terr(i);if(t.revolta)return 0;let v=DIST[i].renda*t.imposto/.3;if(t.lealdade<25)v*=.5;return Math.round(v*(has('lavagem')?1.25:1));}
const totalIncome=()=>DIST.reduce((s,q,i)=>s+(G.dono[i]==='player'?distIncome(i):0),0);
function loyaltyDelta(i){const t=terr(i);let d=(.3-t.imposto)*60;d-=Math.min(6,ADJ[i].filter(j=>G.dono[j]==='corp').length*3);if(has('propaganda'))d+=5;return Math.round(d);}
function territoryTick(skip){
  const out=[];
  DIST.forEach((d,i)=>{
    if(G.dono[i]!=='player'||i===skip)return;const t=terr(i);
    if(t.revolta){t.revolta--;if(t.revolta<=0){G.dono[i]='corp';delete G.terr[i];out.push(`<b style="color:var(--red)">${d.nome} se rebelou e voltou ao Consórcio.</b>`);}else out.push(`<span style="color:var(--red)">${d.nome} continua em revolta: ${t.revolta} dia para reprimir.</span>`);return;}
    const before=t.lealdade;t.lealdade=clamp(t.lealdade+loyaltyDelta(i),0,100);
    if(t.lealdade<=0){t.revolta=2;out.push(`<b style="color:var(--red)">${d.nome} entrou em revolta!</b> Reprima-a em até 2 dias ou o distrito volta ao Consórcio.`);}
    else if(t.lealdade<25&&before>=25)out.push(`<span style="color:var(--amber)">${d.nome} está agitado: a renda do distrito caiu pela metade.</span>`);
  });
  return out.map(t=>`<p>${t}</p>`).join('');
}
const loyCol=v=>v<25?'#ff4d5e':v<50?'#ffa53d':'#4fd8ff';
"""

patch('js/ui.js', [
    ("function avail(i){", TERR + "function avail(i){"),
    ("<span>DISTRITOS <b>${owned()}/${DIST.length}</b></span><span>AGENTES <b>${G.agentes.length}</b></span>`;\n  let s=",
     "<span>DISTRITOS <b>${owned()}/${DIST.length}</b></span><span>RENDA <b>${fmt(totalIncome())}/dia</b></span><span>AGENTES <b>${G.agentes.length}</b></span>`;\n  let s="),
    ("    s+=`<g class=\"dist ${st} ${i===mapSel?'sel':''}\"",
     "    const T=st==='own'?terr(i):null,ex=T?(T.revolta?'revolt':T.lealdade<25?'unrest':''):'';\n    const bar=T?`<rect x=\"${cx-40}\" y=\"${cy+24}\" width=\"80\" height=\"5\" fill=\"#121a2a\"/><rect x=\"${cx-40}\" y=\"${cy+24}\" width=\"${.8*T.lealdade}\" height=\"5\" fill=\"${loyCol(T.lealdade)}\"/>`:'';\n    s+=`<g class=\"dist ${st} ${ex} ${i===mapSel?'sel':''}\""),
    ("NV ${d.dif}</text></g>`;", "NV ${d.dif}</text>${bar}</g>`;"),
    ("  const incomes=DIST.reduce((a,q,i)=>a+(G.dono[i]==='player'?q.renda:0),0);\n  el.innerHTML=",
     "  const incomes=totalIncome();\n  if(st==='own'){renderOwnedSide(el,mapSel,incomes);return;}\n  el.innerHTML="),
    ("function openBriefing(i){\n  const d=DIST[i],nm=missionNames(i);",
     r"""function renderOwnedSide(el,i,incomes){
  const d=DIST[i],t=terr(i),dl=loyaltyDelta(i),stt=t.revolta?['EM REVOLTA','var(--red)']:t.lealdade<25?['AGITADO','var(--amber)']:['CONTROLADO PELA ÔNIX','var(--cyan)'];
  el.innerHTML=`<div class="eyebrow">Distrito da Ônix</div><h2>${d.nome}</h2>
  <span class="chipst" style="color:${stt[1]};align-self:flex-start">${stt[0]}</span>
  <div class="tax"><label for="taxR">Imposto <b id="taxV">${Math.round(t.imposto*100)}%</b></label><input type="range" id="taxR" min="0" max="60" step="5" value="${Math.round(t.imposto*100)}" ${t.revolta?'disabled':''}></div>
  <dl class="kv"><dt>Renda do distrito</dt><dd id="taxInc">${fmt(distIncome(i))}/dia</dd><dt>Lealdade</dt><dd><span class="loy"><i style="width:${t.lealdade}%;background:${loyCol(t.lealdade)}"></i></span> ${t.lealdade}</dd><dt>Tendência</dt><dd id="taxDl" style="color:${dl<0?'var(--red)':'var(--green)'}">${dl>0?'+':''}${dl}/dia</dd></dl>
  <p>${t.revolta?`Agitadores do Consórcio tomaram as ruas. Reprima a revolta em ${t.revolta} dia${t.revolta>1?'s':''} ou o distrito volta ao Consórcio.`:'Imposto acima de 30% derruba a lealdade a cada dia; abaixo disso, ela sobe. Fronteiras com o Consórcio também pesam. Abaixo de 25 o distrito paga metade; em zero, se revolta.'}</p>
  <dl class="kv"><dt>Renda total da Ônix</dt><dd>${fmt(incomes)}/dia</dd><dt>Laboratório</dt><dd>${labLine()}</dd></dl>
  <div class="acts">${t.revolta?`<button class="btn pri" id="btnRev">Reprimir revolta</button>`:''}<button class="btn" id="btnArs2">Equipe e arsenal</button></div>`;
  const r=$('#taxR');
  if(r){r.oninput=()=>{t.imposto=+r.value/100;const n=loyaltyDelta(i);$('#taxV').textContent=r.value+'%';$('#taxInc').textContent=fmt(distIncome(i))+'/dia';const e=$('#taxDl');e.textContent=(n>0?'+':'')+n+'/dia';e.style.color=n<0?'var(--red)':'var(--green)';};r.onchange=()=>{save();renderMap();};}
  const rv=$('#btnRev');if(rv)rv.onclick=()=>openBriefing(i,{revolta:true});
  $('#btnArs2').onclick=()=>showArsenal();
}
function openBriefing(i,opts){
  if(opts&&opts.revolta)return openRevoltBriefing(i);
  const d=DIST[i],nm=missionNames(i);"""),
    ("export function startMission(i){\n  audioInit();\n  const squad=G.esq.map(id=>G.agentes.find(a=>a.id===id)).filter(Boolean);\n  genMission(i,false,squad);",
     r"""function openRevoltBriefing(i){
  const d=DIST[i],sq=G.esq.map(id=>G.agentes.find(a=>a.id===id)).filter(Boolean);
  showModal(`<div class="eyebrow">Briefing · Repressão · ${terr(i).revolta} dia(s) restante(s)</div><h2>${d.nome} em revolta</h2>
   <p>Agitadores do Consórcio incitaram a população de ${d.nome} contra a Ônix. Elimine os agitadores antes que o distrito caia. As ruas estão cheias: cada civil morto deixa o distrito menos leal depois da operação.</p>
   <div class="sqlist">${sq.map(a=>`<div><span>${a.nome}</span><span>${a.inv.map(q=>WD[q.t].ab).join(' · ')}</span></div>`).join('')||'<div><span>Nenhum agente no esquadrão.</span><span></span></div>'}</div>
   <div class="acts"><button class="btn" id="mbBack">Voltar</button><button class="btn pri" id="mbGo" ${sq.length?'':'disabled'}>Iniciar repressão</button></div>`,hideModal);
  $('#mbBack').onclick=hideModal;$('#mbGo').onclick=()=>{hideModal();startMission(i,{revolta:true});};
}
export function startMission(i,opts){
  audioInit();
  const squad=G.esq.map(id=>G.agentes.find(a=>a.id===id)).filter(Boolean);
  genMission(i,false,squad,opts);"""),
    ("  if(win){G.dono[di]='player';reward=Math.round((D.recompensa+bonus)*(has('informantes')?1.2:1));G.dinheiro+=reward;}\n  const renda=Math.round(DIST.reduce((s,q,i)=>s+(G.dono[i]==='player'?q.renda:0),0)*(has('lavagem')?1.25:1));G.dinheiro+=renda;",
     """  let terrNote='';
  if(win&&M.revolta){const t=terr(di);t.revolta=0;t.lealdade=clamp(45-3*M.stats.civis,10,60);reward=1500;G.dinheiro+=reward;terrNote=`<p style="color:var(--green)">A revolta em ${D.nome} foi contida. Lealdade: ${t.lealdade}.</p>`;}
  else if(win){G.dono[di]='player';reward=Math.round((D.recompensa+bonus)*(has('informantes')?1.2:1));G.dinheiro+=reward;const t=terr(di);t.imposto=.3;t.revolta=0;t.lealdade=clamp(55-3*M.stats.civis-4*M.stats.policiais,10,85);terrNote=`<p>${D.nome} começa com lealdade ${t.lealdade}${M.stats.civis?' (as vítimas civis pesaram)':''}.</p>`;}
  const renda=totalIncome();G.dinheiro+=renda;"""),
    ("  let contra='';\n  if(owned()>=3&&Math.random()<.12){\n    const cands=DIST.map((q,i)=>i).filter(i=>G.dono[i]==='player'&&i!==di&&ADJ[i].some(j=>G.dono[j]==='corp'));\n    if(cands.length){const k=pick(cands);G.dono[k]='corp';contra=`Durante a noite, o Consórcio retomou ${DIST[k].nome}.`;}\n  }",
     "  const contra='',terrRep=terrNote+territoryTick(win&&!M.revolta?di:-1);"),
    ("    <div class=\"labrep\">${lab}</div>", "    <div class=\"labrep\">${lab}${terrRep}</div>"),
    ("<h2 class=\"${win?'ok':'bad'}\">${vitoria?'NOVA AURORA É DA ÔNIX':win?'Missão cumprida':'Missão fracassada'}</h2>",
     "<h2 class=\"${win?'ok':'bad'}\">${vitoria?'NOVA AURORA É DA ÔNIX':win?(M.revolta?'Revolta contida':'Missão cumprida'):'Missão fracassada'}</h2>"),
])

patch('hud.css', [
    ("@media (max-width:620px){.labtree{grid-template-columns:1fr}}",
     "@media (max-width:620px){.labtree{grid-template-columns:1fr}}\n.dist.own.unrest polygon{stroke:var(--amber);fill:rgba(255,165,61,.12)}\n.dist.own.revolt polygon{stroke:var(--red);fill:rgba(255,77,94,.18);stroke-dasharray:6 5;animation:dash 1s linear infinite}\n.dist.own.revolt .ds{fill:var(--red)}\n.tax{display:flex;flex-direction:column;gap:6px;font:13px var(--mono);color:var(--dim)}\n.tax b{color:var(--fg)}\n.tax input{accent-color:var(--amber);width:100%}\n.loy{display:inline-block;width:70px;height:5px;background:#1a2132;vertical-align:middle;position:relative}\n.loy i{position:absolute;inset:0 auto 0 0;display:block}"),
])
print('ok')
