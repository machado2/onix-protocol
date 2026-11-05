/* Bot de balanceamento (ferramenta de desenvolvimento; não é carregado pelo jogo).
   Joga campanhas inteiras em simulação acelerada e registra métricas. */
import {M,G,DIST,WD,RESEARCH,IMP_PRECO,RECRUTA,MAXINV,CIENT_PRECO,has,settings} from './core.js';
import * as sim from './sim.js';
import {runScript} from './script.js';
import {setMute,SND} from './audio.js';

const o=()=>window.__onix;
const WEAP=['serra','feixe','escopeta','smg','pistola'];
const RES_ORDER=['escopeta','pentes','impl2','perfurante','reparo','sonda2','informantes','feixe','chave','blindagem','estab','lavagem','impl3','serra','propaganda','chamas','incend','nanomed','trafego','armados','limpa','sonda3','manto'];
const unlocked=t=>!WD[t].res||has(WD[t].res);

function shop(log){
  const g=G;
  while(g.agentes.length<4&&g.dinheiro>=RECRUTA){o().__recruit();}
  g.esq=g.agentes.slice(0,4).map(a=>a.id);
  if(!g.pesq.ativo){const r=RES_ORDER.map(id=>RESEARCH.find(q=>q.id===id)).find(r=>r&&!has(r.id)&&(r.req||[]).every(has));if(r)g.pesq.ativo=r.id;}
  for(const a of g.agentes.slice(0,4)){
    const best=WEAP.find(t=>unlocked(t)&&(a.inv.some(q=>q.t===t)||g.dinheiro>=WD[t].preco+2000));
    if(best&&!a.inv.some(q=>q.t===best)){a.inv=a.inv.filter(q=>!WD[q.t].arma||q.t==='pistola');a.inv.unshift({t:best});g.dinheiro-=WD[best].preco;}
    const need=t=>a.inv.filter(q=>q.t===t).length;
    while(need('medkit')<2&&a.inv.length<MAXINV&&g.dinheiro>=WD.medkit.preco+1500){a.inv.push({t:'medkit'});g.dinheiro-=WD.medkit.preco;}
    while(need('granada')<1&&a.inv.length<MAXINV&&g.dinheiro>=WD.granada.preco+1500){a.inv.push({t:'granada'});g.dinheiro-=WD.granada.preco;}
    const cap=1+(has('impl2')?1:0)+(has('impl3')?1:0);
    for(const k of ['chassi','otica','motor','cortex']){const lv=a.imp[k];if(lv<cap&&g.dinheiro>=IMP_PRECO[lv]*2){g.dinheiro-=IMP_PRECO[lv];a.imp[k]++;}}
    a.dep=0;
  }
  if(g.dinheiro>25000&&g.cientistas<10){g.dinheiro-=CIENT_PRECO;g.cientistas++;}
}
function pickTarget(){
  const t=o().__terr||{};
  const rev=DIST.findIndex((d,i)=>G.dono[i]==='player'&&G.terr&&G.terr[i]&&G.terr[i].revolta);
  if(rev>=0)return {i:rev,revolta:true};
  const F=window.__botFails||(window.__botFails={});
  const av=DIST.map((d,i)=>i).filter(i=>o().__avail(i)).sort((a,b)=>(DIST[a].dif+(F[a]||0)*1.5)-(DIST[b].dif+(F[b]||0)*1.5));
  return av.length?{i:av[0]}:null;
}
function botStep(){
  const sel=M.agents.filter(a=>!a.dead);sim.setSel(sel);
  for(const a of sel)if(a.hp<a.maxHp*.4){const k=a.inv.findIndex(q=>q.t==='medkit');if(k>=0){a.hp=a.maxHp;sim.removeItem(a,k);}}
  if(!(M.tipo==='assassinato'&&!M.vip))for(const a of sel){const wi=a.inv.findIndex(q=>WD[q.t].arma);if(wi>=0&&a.eq!==wi)a.eq=wi;}
  let tgt=null,move=null;
  if(M.scriptDef&&M.scriptDef.nome==='Torre Central'){
    const sec=M.terms.find(q=>!q.done&&q.flag!=='srv'),j=M.boss;
    if(sec){const near=M.units.filter(u=>!u.dead&&u.fac==='corp'&&u.alerted&&Math.hypot(u.x-sel[0].x,u.y-sel[0].y)<7).sort((p,q)=>Math.hypot(p.x-sel[0].x,p.y-sel[0].y)-Math.hypot(q.x-sel[0].x,q.y-sel[0].y))[0];if(near)tgt=near;else move=sec;}
    else if(j&&!j.dead){tgt=j.shield?M.units.find(u=>u.pylon&&!u.dead&&u.fac==='corp')||j:j;}
    else if(j)move=M.terms.find(q=>q.flag==='srv');
    if(tgt)sim.issueAttack(tgt);else if(move)sim.issueMove(move);
    return;
  }
  if(M.hand&&M.objs.some(q=>q.id==='exfil'&&q.state==='active')&&!(M.tipo==='extracao'))move=M.spawn;
  else if(M.tipo==='assassinato'&&M.vip&&M.vip.safe&&M.flags.shut)move=M.terms.find(q=>!q.done&&(q.flag==='rel1'||q.flag==='rel2'));
  else if(M.tipo==='assassinato')tgt=M.vip||null;
  else if(M.tipo==='extracao'){if(!M.sci)return;move=M.sci.follow?(M.evacs?M.evacs[0]:M.evac):M.sci;}
  else if(M.tipo==='sabotagem')move=M.terms.find(q=>!q.done);
  else tgt=M.units.filter(u=>u.kind==='inimigo'&&!u.dead&&!u.follower).sort((p,q)=>Math.hypot(p.x-sel[0].x,p.y-sel[0].y)-Math.hypot(q.x-sel[0].x,q.y-sel[0].y))[0];
  if(M.tipo==='assassinato'&&!M.vip){for(const a of sel)a.eq=-1;const c=M.cands&&M.cands.find(v=>!v.scanned&&!v.dead);if(c)sim.issueMove({x:c.x,y:c.y});return;}
  if(tgt)sim.issueAttack(tgt);else if(move)sim.issueMove(move);
}
function playMission(target,dt=1/30){
  o().startMission(target.i,target.revolta?{revolta:true}:null);
  M.paused=true;
  const t0=M.t;let k=0;
  while(!M.shown&&M.t-t0<300){
    if(M.cine)M.cineSkip=true;
    if(k%45===0&&!M.ended)botStep();
    o().update(dt);runScript();k++;
  }
  if(!M.ended){sim.endMission(false,'tempo esgotado');for(let i=0;i<200&&!M.shown;i++)o().update(dt);}
  const r={di:target.i,rev:!!target.revolta,dif:DIST[target.i].dif,win:M.win,t:Math.round(M.t),lost:M.agents.filter(a=>a.dead).length,civ:M.stats.civis,pol:M.stats.policiais,rivals:M.units.filter(u=>u.rival).map(u=>u.rival+(u.vanished?'(f)':u.dead?'(m)':'')).join(','),reason:M.reason};
  const md=document.querySelector('#modal');if(md)md.hidden=true;
  return r;
}
export function runCampaign(maxMissions=24){
  setMute(true);settings.tips=false;
  o().novoJogo();window.__botFails={};
  const log=[];
  for(let n=0;n<maxMissions;n++){
    shop(log);
    if(!G.agentes.length){log.push({end:'sem agentes'});break;}
    const tgt=pickTarget();if(!tgt){log.push({end:'sem alvo'});break;}
    const before=G.dinheiro;
    const r=playMission(tgt);if(!r.win){const F=window.__botFails||(window.__botFails={});F[tgt.i]=(F[tgt.i]||0)+1;}
    r.dia=G.dia-1;r.money=Math.round(G.dinheiro);r.delta=Math.round(G.dinheiro-before);r.own=G.dono.filter(x=>x==='player').length;
    r.res=Object.keys(G.pesq.done).length;r.civ=M.stats.civis;r.sci=G.cientistas;r.agents=G.agentes.length;
    r.loy=Object.entries(G.terr||{}).map(([i,t])=>t.revolta?'R':Math.round(t.lealdade)).join('/');
    log.push(r);
    if(G.vitoria){log.push({end:'vitória',dia:G.dia});break;}
  }
  return log;
}
