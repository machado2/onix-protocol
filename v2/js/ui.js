/* Interface: telas, HUD, entrada, campanha e laço principal. */
import {LANG,setLang,tr} from './i18n.js';
import {bootFx,decorateMap,tickerHtml,agentPortrait,rivalPortrait,dossierHtml} from './brand.js';
import {N,M,G,setG,state,setState,flags,hooks,settings,saveSettings,clamp,fmt,pick,
  WD,SHOP,IMP,IMP_PRECO,RECRUTA,MAXINV,CLINICA,PRESETS,CODINOMES,TIPOS,DIST,BAY,ADJ,equipable,
  VERBA,RESEARCH,RES_CATS,CIENT_PRECO,CIENT_SAL,PD_POR_CIENT,MAX_CIENT,has,penteOf} from './core.js';
import {genMission,missionNames} from './world.js';
import {startScript,runScript} from './script.js';
import {MSGS,unlock,ENDINGS,RIVALS} from './story.js';
import {part,dropContainer,say,update,updateWorld,setSel,selectAgent,issueMove,issueAttack,issueGround,issueEnter,exitSelected,cycleWeapon,holster,setPreset,setDial,useSlot,curW,neuroMods} from './sim.js';
import {miniToWorld,renderer,resize,applyGfx,buildScene,renderFrame,drawMini,camS,camAxes,toWorld,toScreen,centerOn,rotateCam,zoomCam} from './render.js';
import {SND,audioInit,sfx,setMute,vo,setCommHandler,setIntensity,engine,applyVolumes} from './audio.js';

const $=s=>document.querySelector(s);
const cv=$('#cv');

/* ---------- mensagens ---------- */
hooks.log=(msg,cls)=>{
  const box=$('#msgs');const d=document.createElement('div');d.textContent=msg;if(cls)d.className=cls;box.appendChild(d);
  while(box.children.length>6)box.firstChild.remove();
  setTimeout(()=>{d.style.opacity='0';setTimeout(()=>d.remove(),700);},7000);
};
const log=hooks.log;
hooks.end=()=>showResult();
let subT=null;
function showSub(r){
  const el=$('#sub');el.textContent='';const b=document.createElement('b');b.textContent=(r.who||'')+': ';b.style.color=r.col;
  el.append(b,document.createTextNode(r.text));el.style.borderColor=r.col;el.style.opacity='1';
  clearTimeout(subT);subT=setTimeout(()=>{el.style.opacity='0';},2200+r.text.length*45);
}
hooks.vo=(key,u)=>{if(!M||M.demo||state!=='jogo')return;const r=vo(key,u);if(!r)return;if(r.comm)showSub(r);else if(u)say(u,r.text,r.col);};
setCommHandler(r=>showSub(r));

/* ---------- entrada ---------- */
const keys={};
const mouse={x:0,y:0,in:false,down:false,sx:0,sy:0,drag:false,label:'',labelCol:''};
let touchAtk=false,touch=null;
function pickUnit(sx,sy){
  let best=null,bd=22*Math.max(.8,camS.zoom);
  for(const u of M.units){if(u.dead||u.inCar)continue;const p=toScreen(u.x,u.y,u.fly?1.45:.55),d=Math.hypot(p.x-sx,p.y-sy);if(d<bd){bd=d;best=u;}}
  return best;
}
function pickCar(sx,sy){
  let best=null,bd=34*Math.max(.8,camS.zoom);
  for(const c of M.cars){if(c.dead||c.scripted)continue;const p=toScreen(c.x,c.y,.4),d=Math.hypot(p.x-sx,p.y-sy);if(d<bd){bd=d;best=c;}}
  return best;
}
function unitLabel(u){
  switch(u.kind){
    case 'agente':return `Agente ${u.nome}`;
    case 'civil':return u.follower?'Seguidor':'Civil';
    case 'policia':return u.follower?'Seguidor (policial)':M.policeAggro>0?'Policial (hostil)':u.warned?'Policial (advertindo)':'Policial';
    case 'guarda':return u.follower?'Seguidor (segurança)':u.alerted?'Segurança Hélice (alerta)':'Segurança Hélice';
    case 'inimigo':if(u.heavy&&!u.follower)return 'Soldado pesado do Consórcio (blindagem alta)';return u.follower?'Seguidor (agente)':u.alerted?'Agente do Consórcio (caçando)':'Agente do Consórcio';
    case 'vip':return u.cand&&!u.scanned&&u!==M.vip?'Alvo ou sósia? (aproxime-se para escanear)':u.double?`Sósia de ${u.nome}`:`ALVO: ${u.nome}`;
    case 'drone':return u.fac==='player'?'Drone (invadido)':u.alerted?'Drone de segurança (caçando)':'Drone de segurança · use a Chave Fantasma';
    case 'cientista':return u.nome;
    case 'torre':if(u.pylon)return u.fac==='player'?'Pilar de escudo (invadido)':'Pilar de escudo do Juiz · derrube ou use a Chave Fantasma';return u.fac==='player'?'Torreta (invadida)':'Torreta automática · use a Chave Fantasma';
  }
  return '';
}
function leftClick(x,y,shift){
  const u=pickUnit(x,y);
  if(u&&u.kind==='agente'){selectAgent(u,shift);return;}
  if(!M.sel.length)return;
  const c=pickCar(x,y);
  if(c&&!u&&!M.sel.some(a=>a.inCar===c)&&M.sel.some(a=>!a.inCar)){issueEnter(c);return;}
  issueMove(toWorld(x,y));
}
function rightClick(x,y){
  if(!M.sel.length)return;
  const u=pickUnit(x,y);
  if(u&&u.fac!=='player')issueAttack(u);else issueGround(toWorld(x,y));
}
cv.addEventListener('contextmenu',e=>e.preventDefault());
cv.addEventListener('pointerdown',e=>{
  if(state!=='jogo')return;audioInit();
  if(M.cine){M.cineSkip=true;return;}
  try{cv.setPointerCapture(e.pointerId);}catch(_){}
  mouse.x=e.clientX;mouse.y=e.clientY;mouse.in=true;
  if(e.pointerType==='touch'){touch={id:e.pointerId,sx:e.clientX,sy:e.clientY,lx:e.clientX,ly:e.clientY,pan:false};return;}
  if(e.button===0){mouse.down=true;mouse.sx=e.clientX;mouse.sy=e.clientY;mouse.drag=false;}
  else if(e.button===2)rightClick(e.clientX,e.clientY);
  else if(e.button===1){e.preventDefault();mouse.rot=e.clientX;}
});
cv.addEventListener('pointermove',e=>{
  mouse.x=e.clientX;mouse.y=e.clientY;mouse.in=true;
  if(state!=='jogo')return;
  if(touch&&e.pointerId===touch.id){
    if(Math.hypot(e.clientX-touch.sx,e.clientY-touch.sy)>10)touch.pan=true;
    if(touch.pan){const a=toWorld(touch.lx,touch.ly),b=toWorld(e.clientX,e.clientY);camS.x+=a.x-b.x;camS.y+=a.y-b.y;}
    touch.lx=e.clientX;touch.ly=e.clientY;return;
  }
  if(mouse.rot!==undefined&&e.buttons&4){const d=e.clientX-mouse.rot;if(Math.abs(d)>60){rotateCam(d>0?1:-1);mouse.rot=e.clientX;}return;}
  if(mouse.down&&Math.hypot(e.clientX-mouse.sx,e.clientY-mouse.sy)>6)mouse.drag=true;
  M.hover=pickUnit(e.clientX,e.clientY);
  M.hoverCar=M.hover?null:pickCar(e.clientX,e.clientY);
  cv.style.cursor=M.hover?(M.hover.kind==='agente'?'pointer':(M.hover.fac==='corp'||M.hover.fac==='police')?'crosshair':'default'):(M.hoverCar&&M.sel.length?'pointer':'default');
  if(M.hover){mouse.label=unitLabel(M.hover);mouse.labelCol=M.hover.fac==='corp'?'#ff8a96':M.hover.fac==='police'?'#9fc3ff':M.hover.fac==='player'?'#4fd8ff':'#d3dcea';}
  else if(M.hoverCar&&M.sel.length){mouse.label=M.hoverCar.player?'Veículo do esquadrão':'Clique para entrar no veículo';mouse.labelCol='#ffa53d';}
  else mouse.label='';
});
cv.addEventListener('pointerup',e=>{
  if(state!=='jogo')return;
  if(e.button===1){mouse.rot=undefined;return;}
  if(touch&&e.pointerId===touch.id){if(!touch.pan){if(touchAtk)rightClick(e.clientX,e.clientY);else leftClick(e.clientX,e.clientY,false);}touch=null;mouse.in=false;return;}
  if(e.button===0&&mouse.down){
    mouse.down=false;
    if(mouse.drag){
      const x0=Math.min(mouse.sx,e.clientX),x1=Math.max(mouse.sx,e.clientX),y0=Math.min(mouse.sy,e.clientY),y1=Math.max(mouse.sy,e.clientY);
      const inside=M.agents.filter(a=>{if(a.dead)return false;const s=a.inCar||a,p=toScreen(s.x,s.y,.5);return p.x>=x0&&p.x<=x1&&p.y>=y0&&p.y<=y1;});
      if(inside.length)setSel(e.shiftKey?[...new Set([...M.sel,...inside])]:inside);
      mouse.drag=false;
    }else leftClick(e.clientX,e.clientY,e.shiftKey);
  }
});
cv.addEventListener('pointerleave',()=>{mouse.in=false;});
cv.addEventListener('wheel',e=>{if(state!=='jogo')return;e.preventDefault();zoomCam(e.deltaY<0?1.1:1/1.1);},{passive:false});
$('#mini').addEventListener('pointerdown',e=>{const el=e.currentTarget,r=el.getBoundingClientRect(),k=el.width/r.width,w=miniToWorld((e.clientX-r.left)*k,(e.clientY-r.top)*k);centerOn(w.x,w.y);});
addEventListener('keydown',e=>{
  if(!$('#modal').hidden){if(e.code==='Escape'&&modalEsc)modalEsc();return;}
  if(state!=='jogo')return;
  keys[e.code]=true;const k=e.code;
  if(M.cine){if(k==='Space'||k==='Escape'||k==='Enter'){e.preventDefault();M.cineSkip=true;}return;}
  if(k==='KeyG'){dropContainer();return;}
  if(/^Digit[1-4]$/.test(k)){const a=M.agents[+k[5]-1];if(a&&!a.dead){if(e.shiftKey)selectAgent(a,true);else{if(M.sel.length===1&&M.sel[0]===a){const s=a.inCar||a;centerOn(s.x,s.y);}selectAgent(a,false);}}}
  else if(k==='Digit0'||k==='Backquote'){setSel(M.agents.filter(a=>!a.dead));sfx('ui');}
  else if(k==='KeyQ'||k==='KeyE')cycleWeapon(k==='KeyE'?1:-1);
  else if(k==='KeyH')holster();
  else if(k==='KeyF'){const L=M.sel[0];const cur=L?PRESETS.findIndex(p=>Math.abs(p.r-L.nr.r)<.01&&Math.abs(p.p-L.nr.p)<.01&&Math.abs(p.c-L.nr.c)<.01):-1;setPreset((cur+1)%3);}
  else if(k==='KeyV')exitSelected();
  else if(k==='KeyZ')rotateCam(-1);
  else if(k==='KeyX')rotateCam(1);
  else if(k==='Space'){e.preventDefault();togglePause();}
  else if(k==='Escape')openPause();
  else if(k==='KeyM'){setMute(SND.on);log(SND.on?'Som ativado.':'Som desativado.','cyan');}
  else if(k==='KeyC'){const L=M.sel[0];if(L){const s=L.inCar||L;centerOn(s.x,s.y);}}
  if(k.startsWith('Arrow'))e.preventDefault();
});
addEventListener('keyup',e=>{keys[e.code]=false;});
addEventListener('blur',()=>{for(const k in keys)keys[k]=false;mouse.in=false;});
document.addEventListener('visibilitychange',()=>{if(document.hidden&&state==='jogo'&&M&&!M.paused&&!M.ended)togglePause();});
function panCamera(dt){
  let f=0,r=0;const s=16*dt/camS.zoom;
  if(keys.KeyW||keys.ArrowUp)f+=s;if(keys.KeyS||keys.ArrowDown)f-=s;if(keys.KeyD||keys.ArrowRight)r+=s;if(keys.KeyA||keys.ArrowLeft)r-=s;
  if(mouse.in&&!mouse.down&&matchMedia('(pointer:fine)').matches){const e=6;if(mouse.x<e)r-=s;if(mouse.x>innerWidth-e)r+=s;if(mouse.y<e)f+=s;if(mouse.y>innerHeight-e)f-=s;}
  if(f||r){const a=camAxes();centerOn(camS.x+a.fx*f+a.rx*r,camS.y+a.fy*f+a.ry*r);}
}
function togglePause(){if(M.ended)return;M.paused=!M.paused;}

/* ---------- HUD ---------- */
function buildCards(){
  const box=$('#cards');box.innerHTML='';
  M.agents.forEach(u=>{
    const b=document.createElement('button');b.className='card';
    b.innerHTML=`<span class="num"><img src="${agentPortrait(u.ag)}" alt=""><b>${u.num}</b></span><span class="nm"></span><span class="bars"><span class="bar bhp"><i></i></span><span class="bar bst"><i></i></span></span><span class="wp"></span>`;
    b.querySelector('.nm').textContent=u.nome;
    b.addEventListener('click',e=>selectAgent(u,e.shiftKey));
    b.addEventListener('dblclick',()=>{const s=u.inCar||u;centerOn(s.x,s.y);});
    u.card=b;box.appendChild(b);
  });
}
let invSig='';
function buildInv(){
  const L=M.sel[0],box=$('#invSlots');
  const sig=L?L.id+'|'+L.eq+'|'+L.inv.map(q=>q.t).join(','):'';
  if(sig===invSig)return;invSig=sig;
  if(!L){box.innerHTML='<span class="hint">Selecione um agente (1–4) ou arraste para selecionar o grupo.</span>';return;}
  let h=`<button class="slot ${L.eq<0?'on':''}" data-i="-1"><b>—</b><small>GUARDADA</small></button>`;
  L.inv.forEach((it,i)=>{const w=WD[it.t];h+=`<button class="slot ${L.eq===i?'on':''}" data-i="${i}"><b>${w.ab}</b><small data-mun="${i}">${w.arma?'':w.heal?'USAR':w.throw?'ARREMESSAR':w.sonda?'SEQUESTRAR':w.manto?Math.ceil(it.bat??25)+' s':'INVADIR'}</small></button>`;});
  box.innerHTML=h;
}
$('#invSlots').addEventListener('click',e=>{const b=e.target.closest('.slot');if(b)useSlot(+b.dataset.i);});
$('#presets').addEventListener('click',e=>{const b=e.target.closest('button');if(b)setPreset(+b.dataset.p);});
document.querySelectorAll('.dial').forEach(d=>{
  const set=e=>{const r=d.getBoundingClientRect();setDial(d.dataset.k,1-(e.clientY-r.top)/r.height);updateHud();};
  d.addEventListener('pointerdown',e=>{d.setPointerCapture(e.pointerId);d._down=true;set(e);});
  d.addEventListener('pointermove',e=>{if(d._down)set(e);});
  d.addEventListener('pointerup',()=>{d._down=false;});
  d.addEventListener('keydown',e=>{const L=M&&M.sel[0];if(!L)return;const v=L.nr[d.dataset.k];if(e.key==='ArrowUp'){setDial(d.dataset.k,v+.1);e.preventDefault();}if(e.key==='ArrowDown'){setDial(d.dataset.k,v-.1);e.preventDefault();}});
});
$('#btnMenu').addEventListener('click',()=>openPause());
$('#btnExit').addEventListener('click',()=>exitSelected());
$('#btnDrop').addEventListener('click',()=>dropContainer());
$('#btnAtk').addEventListener('click',()=>{touchAtk=!touchAtk;$('#btnAtk').classList.toggle('on',touchAtk);});
function objectiveHtml(){
  const esc=s=>s.replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
  let h=M.objs.filter(o=>o.primary||o.state!=='hidden').map(o=>`<span class="ob ${o.state} ${o.primary?'pri':''}">${o.state==='done'?'✓':o.state==='failed'?'✗':o.primary?'◆':'○'} ${esc(o.text)}</span>`).join('');
  if(M.timer){const s=Math.max(0,Math.ceil(M.timer.end-M.t));h+=`<span class="ob timer">${esc(M.timer.label)} ${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}</span>`;}
  return h;
}
function objectiveText(){
  if(M.hand){const o=M.objs.find(q=>q.primary&&q.state==='active');return o?o.text:'';}
  switch(M.tipo){
    case 'assassinato':return M.vip.dead?'Alvo eliminado':`Elimine ${M.vip.nome}${M.vip.fleeing?' — ele está fugindo!':''}`;
    case 'extracao':return M.sci.follow?`Escolte ${M.sci.nome} até a zona de evacuação`:`Alcance ${M.sci.nome} no complexo do Consórcio`;
    case 'sabotagem':return `Invada os terminais: ${M.terms.filter(t=>t.done).length}/${M.terms.length} (fique ao lado de cada um)`;
    case 'eliminacao':{const n=M.units.filter(u=>u.kind==='inimigo'&&!u.dead&&!u.follower).length;return `Elimine os agentes do Consórcio: ${n} restante${n===1?'':'s'}`;}
  }
}
function updateHud(){
  flags.hud=false;
  if(M.hand)$('#objTxt').innerHTML=objectiveHtml();else $('#objTxt').textContent=objectiveText();
  $('#hud').classList.toggle('cine',!!M.cine);
  {const b=$('#hudTop').getBoundingClientRect().bottom;$('#msgs').style.top=Math.round(b+8)+'px';}
  $('#btnDrop').hidden=!(M.flags&&M.flags.crane&&!M.flags.dropped);
  const ap=$('#alPol');
  if(M.policeAggro>0){ap.textContent='POLÍCIA · HOSTIL';ap.className='chip hot';}
  else if(M.units.some(u=>u.kind==='policia'&&u.warned&&!u.dead&&!u.follower)){ap.textContent='POLÍCIA · ADVERTÊNCIA';ap.className='chip warn';}
  else{ap.textContent='POLÍCIA · CALMA';ap.className='chip';}
  const ac=$('#alCorp');
  if(M.corpAlert){ac.textContent='SEGURANÇA · ALERTA';ac.className='chip hot';}else{ac.textContent='SEGURANÇA · ALHEIA';ac.className='chip';}
  $('#alFol').textContent=`SEGUIDORES · ${M.followers}`;$('#alFol').className=M.followers?'chip cy':'chip';
  for(const u of M.agents){
    const b=u.card;if(!b)continue;
    b.classList.toggle('sel',!!u.sel);b.classList.toggle('hit',!u.dead&&M.t-(u.lastHit??-9)<.35);b.classList.toggle('dead',u.dead);b.classList.toggle('crash',u.colapso>0);
    b.classList.toggle('over',u.nr.r+u.nr.p+u.nr.c>1.55&&u.colapso<=0);
    b.querySelector('.bhp i').style.width=(u.hp/u.maxHp*100)+'%';
    b.querySelector('.bst i').style.width=(u.colapso>0?100:u.estab)+'%';
    const it=u.eq>=0?u.inv[u.eq]:null,w=it&&WD[it.t];
    b.querySelector('.wp').textContent=u.dead?'ABATIDO':`${u.colapso>0?'COLAPSO':u.inCar?'NO VEÍCULO':u.supp>0?'SUPRIMIDO':u.covered?'EM COBERTURA':'OK'} · ${w?w.ab+(w.arma?(u.rel>0&&u.relSt===it?' recarga':' '+it.mun):''):'arma guardada'}`;
  }
  buildInv();
  const L=M.sel[0];
  if(L)L.inv.forEach((it,i)=>{const w=WD[it.t];if(!w.arma)return;const el=document.querySelector(`[data-mun="${i}"]`);if(el)el.textContent=(L.rel>0&&L.relSt===it)?'RECARGA':`${it.mun}/${penteOf(L,it.t)}`;});
  if(L)L.inv.forEach((it,i)=>{if(!WD[it.t].manto)return;const el=document.querySelector(`[data-mun="${i}"]`);if(el)el.textContent=Math.max(0,Math.ceil(it.bat??25))+' s';});
  document.querySelectorAll('.dial').forEach(d=>{const v=L?L.nr[d.dataset.k]:0;d.querySelector('i').style.height=(v*100)+'%';d.classList.toggle('hi',v>.75);d.setAttribute('aria-valuenow',Math.round(v*100));});
  $('#stabTxt').textContent=L?(L.colapso>0?'COLAPSO':`ESTAB ${Math.round(L.estab)}/${L.maxEstab}`):'';
  $('#stabTxt').className=L&&L.colapso>0?'crash':'';
  $('#btnExit').hidden=!M.sel.some(u=>u.inCar);
}

/* ---------- telas e modais ---------- */
let modalEsc=null,mapSel=-1,arsSel=null;
function showModal(html,esc){$('#mbox').dataset.code='ONX-'+(1000+Math.random()*9000|0)+' · '+tr('CLASSIFICADO');$('#mbox').innerHTML=html;$('#modal').hidden=false;modalEsc=esc||null;const f=$('#mbox').querySelector('.btn.pri')||$('#mbox').querySelector('.btn');if(f)f.focus();}
function hideModal(){$('#modal').hidden=true;modalEsc=null;}
function show(id){['#scrTitle','#scrMap','#scrArs','#scrLab','#hud'].forEach(s=>$(s).hidden=s!==id);$('#ov').hidden=!(id==='#hud'||id==='#scrTitle');}
const owned=()=>G.dono.filter(o=>o==='player').length;
/* --- território: impostos, lealdade e revoltas --- */
function terr(i){G.terr=G.terr||{};return G.terr[i]||(G.terr[i]={imposto:.3,lealdade:60,revolta:0});}
function distIncome(i){const t=terr(i);if(t.revolta)return 0;let v=DIST[i].renda*t.imposto/.3;if(t.lealdade<25)v*=.5;return Math.round(v*(has('lavagem')?1.25:1));}
const totalIncome=()=>DIST.reduce((s,q,i)=>s+(G.dono[i]==='player'?distIncome(i):0),0);
function loyaltyDelta(i){const t=terr(i);let d=(.3-t.imposto)*40+3;d-=Math.min(4,ADJ[i].filter(j=>G.dono[j]==='corp').length*2);if(has('propaganda'))d+=5;return Math.round(d);}
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
function avail(i){if(G.dono[i]==='player')return false;if(!G.dono.includes('player'))return i===0;return ADJ[i].some(j=>G.dono[j]==='player');}
function save(){try{localStorage.setItem('protocolo-onix-v1',JSON.stringify(G));}catch(e){}}
function load(){try{const s=localStorage.getItem('protocolo-onix-v1');if(!s)return null;const g=JSON.parse(s);g.agentes.forEach(a=>{a.dep=a.dep||0;});g.pesq=g.pesq||{done:{},prog:{},ativo:null};if(g.cientistas===undefined)g.cientistas=3;g.rivais=g.rivais||{};g.msgs=g.msgs||[];return g;}catch(e){return null;}}
function novoAgente(){const usados=new Set(G.agentes.map(a=>a.nome));const nome=CODINOMES.find(n=>!usados.has(n))||('Agente '+G.prox);return {id:G.prox++,nome,imp:{chassi:0,motor:0,otica:0,cortex:0},inv:[{t:'pistola'}],missoes:0,abates:0,dep:0};}
function novoJogo(){
  setG({v:3,dinheiro:18000,dia:1,prox:1,agentes:[],esq:[],dono:DIST.map(()=>'corp'),abates:0,vitoria:false,rivais:{},msgs:[],cientistas:3,pesq:{done:{},prog:{},ativo:'escopeta'}});
  for(let k=0;k<4;k++)G.agentes.push(novoAgente());
  G.agentes[0].inv.push({t:'granada'});G.agentes[1].inv.push({t:'medkit'});G.agentes[2].inv.push({t:'sonda'});
  G.esq=G.agentes.map(a=>a.id);unlock(G,'inicio');save();
}
/* ---------- dicas contextuais (uma vez cada, podem ser desligadas) ---------- */
const TIPS={
  start:'Clique num agente (ou arraste para pegar o grupo) e clique no chão para mover. Botão direito ataca.',
  probe:'Um agente leva a SONDA: equipe-a e fique perto das pessoas para recrutá-las como seguidores.',
  police:'A polícia está advertindo: aperte H para guardar as armas e ela se acalma.',
  alert:'Combate! Espaço pausa o jogo para você dar ordens com calma.',
  hurt:'Agente ferido: clique no KIT MÉDICO no inventário para curá-lo.',
  cover:'O escudo azul indica cobertura: encostado em paredes, contêineres ou carros, o agente evita metade dos tiros.',
  car:'Com agentes selecionados, clique num carro para entrar. Depois clique no mapa para dirigir e V para sair.',
  rotate:'Z e X giram a câmera quando um prédio atrapalha a visão. O scanner gira junto.',
  drone:'Drones de segurança voam por cima dos muros. Equipe a CHAVE FANTASMA e clique num drone para invadi-lo.',
  vent:'A grade fica laranja e chia antes do vapor sair. Afaste o esquadrão e atraia os guardas para ela.',
  laser:'Cruzar um feixe vermelho dispara o alarme. Alguns piscam: espere apagar para passar.',
  glass:'Vidro não segura balas: os tiros atravessam e estilhaçam as paredes.',
  heavy:'Soldados pesados aguentam muita bala comum. Granadas e munição perfurante funcionam melhor.',
  shield:'O escudo azul vem dos pilares ligados por feixes. Derrube os pilares ou invada-os com a CHAVE FANTASMA.',
  scan:'Sósias: fique perto de um suspeito, com as armas guardadas, até o anel do scanner fechar.',
};
let tipT=0;const tipQ=[];
function tip(id){if(!settings.tips||(settings.seen||[]).includes(id)||tipQ.includes(id))return;tipQ.push(id);}
function tipTick(dt){
  tipT-=dt;if(tipT>0||!tipQ.length||(M&&M.cine))return;
  const id=tipQ.shift();(settings.seen=settings.seen||[]).push(id);saveSettings();
  const el=$('#tip');el.querySelector('span').textContent=TIPS[id];el.hidden=false;el.classList.add('on');
  clearTimeout(el._h);el._h=setTimeout(()=>el.classList.remove('on'),9000);tipT=11;
}
function tipChecks(){
  if(M.cine||M.ended)return;
  if(M.t>1)tip('start');
  if(M.t>6&&M.agents.some(a=>a.inv.some(q=>q.t==='sonda')))tip('probe');
  if(M.units.some(u=>u.kind==='policia'&&u.warned&&!u.dead))tip('police');
  if(M.corpAlert||M.policeAggro>0)tip('alert');
  if(M.agents.some(a=>!a.dead&&a.hp<a.maxHp*.5&&a.inv.some(q=>q.t==='medkit')))tip('hurt');
  if(M.agents.some(a=>a.covered&&!a.dead))tip('cover');
  if(M.hoverCar&&M.sel.length)tip('car');
  if(M.t>45)tip('rotate');
  const near=(x,y,r)=>M.agents.some(a=>!a.dead&&!a.inCar&&Math.hypot(a.x-x,a.y-y)<r);
  if(M.units.some(u=>u.kind==='drone'&&!u.dead&&u.fac==='corp'&&near(u.x,u.y,10)))tip('drone');
  if(M.vents&&M.vents.some(v=>!v.off&&near(v.x,v.y,4)))tip('vent');
  if(M.lasers&&M.lasers.some(l=>l.on&&!l.dmg&&near((l.x1+l.x2)/2,(l.y1+l.y2)/2,6)))tip('laser');
  if(M.glassN>0&&M.t>25)tip('glass');
  if(M.units.some(u=>u.heavy&&u.contact&&!u.dead))tip('heavy');
  if(M.boss&&M.boss.shield&&!M.boss.dead&&near(M.boss.x,M.boss.y,12))tip('shield');
  if(M.cands&&!M.vip&&M.cands.some(v=>!v.dead&&near(v.x,v.y,7)))tip('scan');
}
function fadeIn(){bootFx((Math.random()*3)|0);const f=$('#fade');f.classList.add('on');requestAnimationFrame(()=>requestAnimationFrame(()=>f.classList.remove('on')));}
$('#tip button').addEventListener('click',()=>$('#tip').classList.remove('on'));
function showTitle(){
  setState('demo');show('#scrTitle');hideModal();fadeIn();camS.zoomT=null;$('#btnCont').hidden=!load();
  genMission(3,true);buildScene();camS.zoom=1.05;camS.yaw=0;camS.yawA=0;centerOn(22,20);
}
function showMap(){
  if(state==='jogo'||state==='demo')fadeIn();
  setState('menu');show('#scrMap');hideModal();
  if(!$('#scrMap .tk'))$('#scrMap').insertAdjacentHTML('beforeend',tickerHtml());
  if(mapSel<0||!avail(mapSel))mapSel=DIST.findIndex((d,i)=>avail(i));
  renderMap();
}
function renderMap(){
  $('#mapStats').innerHTML=`<span>DIA <b>${G.dia}</b></span><span>FUNDOS <b>${fmt(G.dinheiro)}</b></span><span>DISTRITOS <b>${owned()}/${DIST.length}</b></span><span>RENDA <b>${fmt(totalIncome())}/dia</b></span><span>AGENTES <b>${G.agentes.length}</b></span>`;
  let s=`<defs><pattern id="hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="7" stroke="#132a40" stroke-width="2"/></pattern><pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M20 0H0V20" fill="none" stroke="#111827" stroke-width="1"/></pattern></defs>`;
  s+=`<rect width="1000" height="620" fill="url(#grid)"/>`;
  s+=`<polygon points="${BAY.map(p=>p.join(',')).join(' ')}" fill="url(#hatch)" stroke="#1b3550"/><text x="860" y="500" fill="#2e5a80" font-family="JetBrains Mono,monospace" font-size="12" letter-spacing="3" text-anchor="middle">BAÍA DE AURORA</text>`;
  DIST.forEach((d,i)=>{
    const st=G.dono[i]==='player'?'own':avail(i)?'avail':'enemy';
    const cx=d.poly.reduce((a,p)=>a+p[0],0)/d.poly.length,cy=d.poly.reduce((a,p)=>a+p[1],0)/d.poly.length;
    const T=st==='own'?terr(i):null,ex=T?(T.revolta?'revolt':T.lealdade<25?'unrest':''):'';
    const bar=T?`<rect x="${cx-40}" y="${cy+24}" width="80" height="5" fill="#121a2a"/><rect x="${cx-40}" y="${cy+24}" width="${.8*T.lealdade}" height="5" fill="${loyCol(T.lealdade)}"/>`:'';
    s+=`<g class="dist ${st} ${ex} ${i===mapSel?'sel':''}" data-i="${i}" tabindex="0" role="button" aria-label="${d.nome}"><polygon points="${d.poly.map(p=>p.join(',')).join(' ')}"/><text class="dn" x="${cx}" y="${cy-2}">${d.nome}</text><text class="ds" x="${cx}" y="${cy+16}">${st==='own'?'ÔNIX':d.hq?'QG HÉLICE':'HÉLICE'} · NV ${d.dif}</text>${bar}</g>`;
  });
  $('#mapSvg').innerHTML=s;decorateMap($('#mapSvg'),DIST,G.dono,avail);renderMapSide();
  const un=(G.msgs||[]).filter(m=>!m.lida).length;$('#btnMsgs').textContent=un?`Interceptações (${un})`:'Interceptações';$('#btnMsgs').classList.toggle('pri',un>0);
}
$('#mapSvg').addEventListener('click',e=>{const g=e.target.closest('.dist');if(!g)return;mapSel=+g.dataset.i;sfx('ui');renderMap();});
$('#mapSvg').addEventListener('keydown',e=>{if(e.key!=='Enter')return;const g=e.target.closest('.dist');if(!g)return;mapSel=+g.dataset.i;renderMap();});
function pips(n,max=10){let h='<span class="pips">';for(let k=0;k<max;k++)h+=`<i class="${k<n?'on':''}"></i>`;return h+'</span>';}
function briefShort(i,nm){
  const d=DIST[i];
  switch(d.tipo){
    case 'assassinato':if(d.short)return d.short;return `Alvo: ${nm.vip}. Elimine-o antes que alcance o transporte de fuga.`;
    case 'extracao':return `${nm.sci} quer desertar. Resgate-a e traga-a ao ponto de inserção.`;
    case 'sabotagem':return 'Invada três terminais de vigilância protegidos pelo Consórcio.';
    case 'eliminacao':return d.hq?'Ataque final: elimine a guarda de elite do Consórcio na Torre Central.':'Uma célula de agentes do Consórcio domina o distrito. Elimine todos.';
  }
}
function briefLong(i,nm){
  const d=DIST[i];
  const base={
    assassinato:`${nm.vip} coordena as operações do Consórcio Hélice em ${d.nome}. Ele circula com escolta pelo distrito. Ao primeiro sinal de alarme, correrá para um transporte de evacuação: se chegar lá, a missão falha.`,
    extracao:`${nm.sci}, pesquisadora de neuroimplantes, está retida no pátio de um complexo do Consórcio. Chegue até ela e ela seguirá o agente mais próximo, inclusive para dentro de um veículo. Leve-a viva até o ponto de inserção, marcado em verde.`,
    sabotagem:`Três terminais mantêm a rede de vigilância de ${d.nome}. Posicione um agente ao lado de cada terminal por alguns segundos para invadi-lo. Cada invasão dispara um alarme local.`,
    eliminacao:d.hq?'A Torre Central abriga a guarda de elite do Consórcio, torretas automáticas e dois complexos fortificados. Elimine todos os agentes inimigos para tomar a cidade.':`Uma célula de agentes do Consórcio patrulha ${d.nome}. Eles são blindados e caçam o esquadrão assim que soar o alarme. Elimine todos.`,
  }[d.tipo];
  if(d.brief)return d.brief;
  return base+' Armas à mostra atraem a polícia. A Sonda Neural recruta seguidores em silêncio, e carros podem ser tomados com um clique.';
}
function renderMapSide(){
  const el=$('#mapSide');
  if(mapSel<0){el.innerHTML=`<div class="eyebrow">Mapa de Nova Aurora</div><h2>Selecione um distrito</h2><p>Distritos em âmbar podem ser atacados.</p>`;return;}
  const d=DIST[mapSel],st=G.dono[mapSel]==='player'?'own':avail(mapSel)?'avail':'enemy',nm=missionNames(mapSel);
  const incomes=totalIncome();
  if(st==='own'){renderOwnedSide(el,mapSel,incomes);return;}
  el.innerHTML=`<div class="eyebrow">${d.hq?'Quartel-general do Consórcio':'Distrito'}</div><h2>${d.nome}</h2>
  <span class="chipst" style="color:${st==='own'?'var(--cyan)':st==='avail'?'var(--amber)':'var(--red)'};align-self:flex-start">${st==='own'?'CONTROLADO PELA ÔNIX':st==='avail'?'ALVO DISPONÍVEL':'FORA DE ALCANCE'}</span>
  <dl class="kv"><dt>Operação</dt><dd>${TIPOS[d.tipo]}</dd><dt>Ameaça</dt><dd>${pips(d.dif)}</dd><dt>Recompensa</dt><dd>${fmt(d.recompensa)}</dd><dt>Renda diária</dt><dd>${fmt(d.renda)}</dd></dl>
  <p>${st==='own'?'Este distrito já paga tributo à Ônix.':st==='avail'?briefShort(mapSel,nm):'Conquiste um distrito vizinho para alcançar este setor.'}</p>
  <dl class="kv"><dt>Renda atual da Ônix</dt><dd>${fmt(incomes)}/dia</dd><dt>Esquadrão</dt><dd>${G.esq.length}/4 agentes</dd><dt>Laboratório</dt><dd>${labLine()}</dd></dl>
  <div class="acts">${st==='avail'?`<button class="btn pri" id="btnBrief">Briefing da missão</button>`:''}<button class="btn" id="btnArs2">Equipe e arsenal</button></div>`;
  const bb=$('#btnBrief');if(bb)bb.onclick=()=>openBriefing(mapSel);
  $('#btnArs2').onclick=()=>showArsenal();
}
function renderOwnedSide(el,i,incomes){
  const d=DIST[i],t=terr(i),dl=loyaltyDelta(i),stt=t.revolta?['EM REVOLTA','var(--red)']:t.lealdade<25?['AGITADO','var(--amber)']:['CONTROLADO PELA ÔNIX','var(--cyan)'];
  el.innerHTML=`<div class="eyebrow">Distrito da Ônix</div><h2>${d.nome}</h2>
  <span class="chipst" style="color:${stt[1]};align-self:flex-start">${stt[0]}</span>
  <div class="tax"><label for="taxR">Imposto <b id="taxV">${Math.round(t.imposto*100)}%</b></label><input type="range" id="taxR" min="0" max="60" step="5" value="${Math.round(t.imposto*100)}" ${t.revolta?'disabled':''}></div>
  <dl class="kv"><dt>Renda do distrito</dt><dd id="taxInc">${fmt(distIncome(i))}/dia</dd><dt>Lealdade</dt><dd><span class="loy"><i style="width:${t.lealdade}%;background:${loyCol(t.lealdade)}"></i></span> ${t.lealdade}</dd><dt>Tendência</dt><dd id="taxDl" style="color:${dl<0?'var(--red)':'var(--green)'}">${dl>0?'+':''}${dl}/dia</dd></dl>
  <p>${t.revolta?`Agitadores do Consórcio tomaram as ruas. Reprima a revolta em ${t.revolta} dia${t.revolta>1?'s':''} ou o distrito volta ao Consórcio.`:'Impostos altos derrubam a lealdade a cada dia; impostos baixos a recuperam. Cada fronteira com o Consórcio pesa um pouco. Abaixo de 25 o distrito paga metade; em zero, se revolta.'}</p>
  <dl class="kv"><dt>Renda total da Ônix</dt><dd>${fmt(incomes)}/dia</dd><dt>Laboratório</dt><dd>${labLine()}</dd></dl>
  <div class="acts">${t.revolta?`<button class="btn pri" id="btnRev">Reprimir revolta</button>`:''}<button class="btn" id="btnArs2">Equipe e arsenal</button></div>`;
  const r=$('#taxR');
  if(r){r.oninput=()=>{t.imposto=+r.value/100;const n=loyaltyDelta(i);$('#taxV').textContent=r.value+'%';$('#taxInc').textContent=fmt(distIncome(i))+'/dia';const e=$('#taxDl');e.textContent=(n>0?'+':'')+n+'/dia';e.style.color=n<0?'var(--red)':'var(--green)';};r.onchange=()=>{save();renderMap();};}
  const rv=$('#btnRev');if(rv)rv.onclick=()=>openBriefing(i,{revolta:true});
  $('#btnArs2').onclick=()=>showArsenal();
}
function openBriefing(i,opts){
  if(opts&&opts.revolta)return openRevoltBriefing(i);
  const d=DIST[i],nm=missionNames(i);
  const sq=G.esq.map(id=>G.agentes.find(a=>a.id===id)).filter(Boolean);
  const list=sq.length?sq.map(a=>`<div><span class="sqn"><img class="pf sm" src="${agentPortrait(a)}" alt="">${a.nome}</span><span>${a.inv.map(q=>WD[q.t].ab).join(' · ')}</span></div>`).join(''):'<div><span>Nenhum agente no esquadrão.</span><span>Monte a equipe no arsenal.</span></div>';
  showModal(`<div class="eyebrow">Briefing · ${TIPOS[d.tipo]} · ameaça ${d.dif}/10</div><h2>${d.nome}</h2>${dossierHtml(d.mission)}<p>${briefLong(i,nm)}</p>
   <div class="sqlist">${list}</div>
   <div class="acts"><button class="btn" id="mbBack">Voltar</button><button class="btn" id="mbArs">Arsenal</button><button class="btn pri" id="mbGo" ${sq.length?'':'disabled'}>Iniciar missão</button></div>`,hideModal);
  $('#mbBack').onclick=hideModal;$('#mbArs').onclick=()=>{hideModal();showArsenal();};
  $('#mbGo').onclick=()=>{hideModal();startMission(i);};
}
function showArsenal(){setState('menu');show('#scrArs');hideModal();if(!G.agentes.some(a=>a.id===arsSel))arsSel=G.agentes[0]?G.agentes[0].id:null;renderArsenal();}
function renderArsenal(){
  $('#arsStats').innerHTML=`<span>FUNDOS <b>${fmt(G.dinheiro)}</b></span><span>ESQUADRÃO <b>${G.esq.length}/4</b></span><span>DISTRITOS <b>${owned()}</b></span>`;
  const a=G.agentes.find(q=>q.id===arsSel);
  let ros=`<h3>Agentes</h3>`;
  G.agentes.forEach(q=>{const inS=G.esq.includes(q.id);ros+=`<div class="ros ${q.id===arsSel?'cur':''}" data-act="pick" data-id="${q.id}"><img class="pf sm" src="${agentPortrait(q)}" alt=""><span class="nm">${q.nome}</span><button class="sq ${inS?'on':''}" data-act="squad" data-id="${q.id}">${inS?'NO ESQUADRÃO':'RESERVA'}</button></div>`;});
  ros+=`<button class="btn sm" data-act="recruit" ${G.dinheiro<RECRUTA||G.agentes.length>=8?'disabled':''}>Recrutar agente · ${fmt(RECRUTA)}</button><p class="hint">Até 8 agentes na folha e 4 em campo. Agentes abatidos em missão não voltam.</p>`;
  let mid='';
  if(a){
    mid=`<div class="agh"><img class="pf big" src="${agentPortrait(a)}" alt=""><h2>${a.nome}</h2><span class="mono">${a.missoes} missões · ${a.abates} abates</span></div><h3>Implantes cibernéticos</h3>`;
    const cap=1+(has('impl2')?1:0)+(has('impl3')?1:0);
    for(const k in IMP){const lv=a.imp[k],pr=IMP_PRECO[lv];mid+=`<div class="imp"><span class="t">${IMP[k].nome}</span>${pips(lv,3)}${lv<3&&lv>=cap?`<span class="mono" style="color:var(--dim);font-size:11px">Requer Mk ${lv===1?'II':'III'}</span>`:lv<3?`<button class="btn sm" data-act="up" data-k="${k}" ${G.dinheiro<pr?'disabled':''}>${fmt(pr)}</button>`:'<span class="mono" style="color:var(--cyan)">MÁX</span>'}<small>${IMP[k].desc}</small></div>`;}
    mid+=`<div class="imp"><span class="t">Dependência neural</span><span class="mono" style="color:${a.dep>20?'var(--red)':'var(--dim)'}">${a.dep||0}%</span>${a.dep?`<button class="btn sm" data-act="detox" ${G.dinheiro<CLINICA?'disabled':''}>Clínica ${fmt(CLINICA)}</button>`:'<span></span>'}<small>Tempo em sobrecarga gera dependência, que reduz a estabilidade máxima nas missões.</small></div>`;
    mid+=`<h3>Inventário · clique para vender por 50%</h3><div class="inv">`;
    for(let k=0;k<MAXINV;k++){const it=a.inv[k];mid+=it?`<button class="ivs" data-act="sell" data-idx="${k}"><b>${WD[it.t].ab}</b><small>vender ${fmt(WD[it.t].preco/2)}</small></button>`:`<div class="ivs empty"><small>vazio</small></div>`;}
    mid+='</div>';
  }else mid='<p class="hint">Nenhum agente. Recrute alguém para continuar.</p>';
  let shop='<h3>Fornecedores do mercado cinza</h3><div class="shop">';
  const own=owned();
  SHOP.forEach(t=>{
    const w=WD[t],lock=!!w.res&&!has(w.res),resName=w.res?(RESEARCH.find(r=>r.id===w.res)||{}).nome:'';
    const st=w.arma?(w.flame?`fogo · alcance ${w.alcance}`:`dano ${w.dano}${w.pellets?'×'+w.pellets:''} · alcance ${w.alcance} · ${(1/w.cad).toFixed(1)} tiros/s · pente ${w.pente}`):w.throw?`dano ${w.dano} em área · alcance ${w.alcance}`:'';
    shop+=`<div class="sh ${lock?'lock':''}"><span class="n">${w.nome}</span><span class="p">${fmt(w.preco)}</span><small>${w.desc}</small>${st?`<span class="st">${st}</span>`:''}${lock?`<span class="st">Requer pesquisa: ${resName}</span>`:`<button class="btn sm" data-act="buy" data-t="${t}" ${!a||a.inv.length>=MAXINV||G.dinheiro<w.preco?'disabled':''}>Comprar para ${a?a.nome:'—'}</button>`}</div>`;
  });
  shop+='</div>';
  $('#arsGrid').innerHTML=`<div class="col">${ros}</div><div class="col">${mid}</div><div class="col">${shop}</div>`;
}
$('#scrArs').addEventListener('click',e=>{
  const b=e.target.closest('[data-act]');if(!b||b.disabled)return;
  const act=b.dataset.act,a=G.agentes.find(q=>q.id===arsSel);
  if(act==='back'){showMap();return;}
  if(act==='squad'){e.stopPropagation();const id=+b.dataset.id;if(G.esq.includes(id))G.esq=G.esq.filter(x=>x!==id);else if(G.esq.length<4)G.esq.push(id);}
  else if(act==='pick')arsSel=+b.dataset.id;
  else if(act==='recruit'){if(G.dinheiro>=RECRUTA&&G.agentes.length<8){G.dinheiro-=RECRUTA;const n=novoAgente();G.agentes.push(n);if(G.esq.length<4)G.esq.push(n.id);arsSel=n.id;}}
  else if(act==='up'&&a){const k=b.dataset.k,pr=IMP_PRECO[a.imp[k]];if(a.imp[k]<1+(has('impl2')?1:0)+(has('impl3')?1:0)&&G.dinheiro>=pr){G.dinheiro-=pr;a.imp[k]++;}}
  else if(act==='detox'&&a){if(G.dinheiro>=CLINICA){G.dinheiro-=CLINICA;a.dep=0;}}
  else if(act==='sell'&&a){const i=+b.dataset.idx,it=a.inv[i];if(it){G.dinheiro+=WD[it.t].preco/2;a.inv.splice(i,1);}}
  else if(act==='buy'&&a){const w=WD[b.dataset.t];if(a.inv.length<MAXINV&&G.dinheiro>=w.preco){G.dinheiro-=w.preco;a.inv.push({t:b.dataset.t});}}
  sfx('ui');save();renderArsenal();
});

/* --- laboratório --- */
const resById=id=>RESEARCH.find(r=>r.id===id);
const resAvail=r=>!has(r.id)&&(r.req||[]).every(has);
const pdDia=()=>G.cientistas*PD_POR_CIENT;
function labLine(){const a=G.pesq.ativo&&resById(G.pesq.ativo);if(!a)return '<span style="color:var(--amber)">ocioso</span>';const p=G.pesq.prog[a.id]||0;return `${a.nome} · ${Math.ceil((a.custo-p)/Math.max(1,pdDia()))} dia(s)`;}
function researchTick(extracted){
  const out=[];
  if(extracted){const n=2;G.cientistas=Math.min(MAX_CIENT,G.cientistas+n);out.push(`<b>+${n} cientistas</b> desertaram com a extraída e se juntaram ao laboratório.`);}
  let saiu=0;while(G.cientistas>1&&G.dinheiro<G.cientistas*CIENT_SAL){G.cientistas--;saiu++;}
  if(saiu)out.push(`<span style="color:var(--red)">Sem verba para salários: ${saiu} cientista${saiu>1?'s':''} deixou o laboratório.</span>`);
  const sal=Math.min(G.dinheiro,G.cientistas*CIENT_SAL);G.dinheiro=Math.max(0,G.dinheiro-sal);
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

/* ---------- missão ---------- */
function openRevoltBriefing(i){
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
  genMission(i,false,squad,opts);buildScene();startScript();
  setState('jogo');show('#hud');$('#msgs').innerHTML='';invSig='';fadeIn();camS.zoomT=null;$('#tip').classList.remove('on');
  camS.zoom=1.25;camS.yaw=0;camS.yawA=0;centerOn(M.spawn.x,M.spawn.y);
  buildCards();setSel(M.agents.slice());
  log(`Inserção em ${M.D.nome}. ${M.hand?M.scriptDef.nome:TIPOS[M.tipo]}.`,'cyan');if(!M.hand)setTimeout(()=>hooks.vo('ctl:ins'),600);
  log('Armas guardadas. Q/E troca de arma · Z/X gira a câmera.');
  if(M.agents.some(a=>a.inv.some(q=>q.t==='sonda')))log('Equipe a SONDA e aproxime-se de pessoas para recrutá-las como seguidores.','cyan');
  if(M.tipo==='assassinato'&&!M.hand)log('O alvo está marcado em dourado no scanner.','amber');
  flags.hud=true;updateHud();
}
function gfxRow(){
  return `<div class="gfx"><span class="l">Gráficos</span>
    <label>Qualidade <select id="gQ"><option value="u">Ultra</option><option value="1">Alta</option><option value="0.75">Média</option><option value="0.55">Baixa</option></select></label>
    <label><input type="checkbox" id="gBloom"> Brilho neon</label><label><input type="checkbox" id="gShadow"> Sombras</label><label><input type="checkbox" id="gTips"> Dicas</label>
    <span class="l">Som</span><label>Música <input type="range" id="vMus" min="0" max="1" step="0.05"></label><label>Efeitos <input type="range" id="vSfx" min="0" max="1" step="0.05"></label><label>Vozes <input type="range" id="vVo" min="0" max="1" step="0.05"></label>
    <span class="l">Idioma</span><label><select id="gLang"><option value="pt">Português</option><option value="en">English</option></select></label></div>`;
}
function bindGfx(){
  $('#gLang').value=LANG;$('#gLang').onchange=e=>setLang(e.target.value);
  $('#gQ').value=settings.ao?'u':String(settings.q||1);$('#gBloom').checked=settings.bloom;$('#gShadow').checked=settings.shadows;
  $('#gQ').onchange=e=>{const v=e.target.value;settings.ao=v==='u';settings.q=v==='u'?1:+v;saveSettings();applyGfx();};
  $('#gBloom').onchange=e=>{settings.bloom=e.target.checked;saveSettings();};
  $('#gShadow').onchange=e=>{settings.shadows=e.target.checked;saveSettings();applyGfx();};
  $('#gTips').checked=settings.tips;$('#gTips').onchange=e=>{settings.tips=e.target.checked;if(settings.tips)settings.seen=[];saveSettings();};
  [['#vMus','mus'],['#vSfx','sfx'],['#vVo','vo']].forEach(([id,k])=>{const el=$(id);el.value=String(settings[k]);el.oninput=()=>{settings[k]=+el.value;applyVolumes();saveSettings();};el.onchange=()=>{if(k==='vo')hooks.vo('ctl:ins');};});
}
function openPause(){
  if(M.ended)return;
  if(!M.paused)togglePause();
  showModal(`<div class="eyebrow">Pausa tática</div><h2>${M.D.nome}</h2><p>${objectiveText()}.</p>
    <p class="mono" style="font-size:12px;color:var(--dim)">Esq: mover, selecionar, entrar em carro · Dir: atacar, disparar, arremessar, invadir · 1–4 / 0 agentes · Q/E armas · H guardar · F predefinição neural · V sair do carro · Z/X girar câmera · Espaço pausa · M som</p>
    ${gfxRow()}
    <div class="acts"><button class="btn" id="pzSom">${SND.on?'Desativar som':'Ativar som'}</button><button class="btn" id="pzAb">Abortar missão</button><button class="btn pri" id="pzOk">Continuar</button></div>`,closePause);
  bindGfx();
  $('#pzOk').onclick=closePause;
  $('#pzSom').onclick=()=>{setMute(SND.on);$('#pzSom').textContent=SND.on?'Desativar som':'Ativar som';};
  $('#pzAb').onclick=()=>{
    $('#mbox .acts').innerHTML=`<span class="hint" style="margin-right:auto">Os sobreviventes recuam e o distrito continua com o Consórcio.</span><button class="btn" id="pzNo">Cancelar</button><button class="btn pri" id="pzYes">Abortar</button>`;
    $('#pzNo').onclick=closePause;$('#pzYes').onclick=()=>{hideModal();M.paused=false;M.ended=true;M.win=false;M.reason='Missão abortada. O esquadrão recuou.';M.shown=true;showResult();};
  };
}
function closePause(){hideModal();if(M.paused)togglePause();}
function showResult(){
  const win=M.win,di=M.di,D=M.D,lost=M.agents.filter(a=>a.dead);
  for(const u of M.agents){
    const a=u.ag;
    if(u.dead){G.agentes=G.agentes.filter(q=>q!==a);G.esq=G.esq.filter(id=>id!==a.id);}
    else{a.inv=u.inv.map(it=>({t:it.t}));a.missoes++;a.abates+=u.kills;a.dep=Math.min(50,(a.dep||0)+Math.round(u.over*1.5*(has('estab')?.5:1)*(has('limpa')?0:1)));}
  }
  let reward=0;
  const bonus=(M.bonus||[]).reduce((s,b)=>s+b.val,0);
  let terrNote='';
  if(win&&M.revolta){const t=terr(di);t.revolta=0;t.lealdade=clamp(45-2*M.stats.civis,10,60);reward=1500;G.dinheiro+=reward;terrNote=`<p style="color:var(--green)">A revolta em ${D.nome} foi contida. Lealdade: ${t.lealdade}.</p>`;}
  else if(win){G.dono[di]='player';reward=Math.round((D.recompensa+bonus)*(has('informantes')?1.2:1));G.dinheiro+=reward;const t=terr(di);t.imposto=.3;t.revolta=0;t.lealdade=clamp(55-2*M.stats.civis-3*M.stats.policiais,10,85);terrNote=`<p>${D.nome} começa com lealdade ${t.lealdade}${M.stats.civis?' (as vítimas civis pesaram)':''}.</p>`;}
  const renda=totalIncome()+VERBA;G.dinheiro+=renda;
  const lab=researchTick(win&&D.tipo==='extracao');
  G.dia++;G.abates+=M.stats.abates;
  const contra='',terrRep=terrNote+territoryTick(win?di:-1);
  const novas=[],U=id=>{if(unlock(G,id))novas.push(id);};
  (M.rivalSeen?[...M.rivalSeen]:[]).forEach(id=>U(id+'_visto'));(M.rivalDead||[]).forEach(id=>U(id+'_morto'));
  if(win&&!M.revolta){if(di===0)U('docas');if(di===1)U('tanaka');}
  {const own=owned();if(own>=3)U('tres');if(own>=5)U('cinco');if(own>=7)U('sete');}
  if(DIST.some((d,i)=>d.hq&&avail(i)))U('hq');
  if(Object.values(G.terr||{}).some(t=>t.revolta))U('revolta');
  const rivNote=[...(M.rivalDead||[]).map(id=>`<p style="color:var(--green)">${RIVALS.find(r=>r.id===id).nome} está morto. Os Ponteiros perderam um dos seus.</p>`),...(M.rivalEsc||[]).map(id=>`<p style="color:var(--amber)">${RIVALS.find(r=>r.id===id).nome} escapou e vai voltar.</p>`)].join('');
  const msgNote=novas.length?`<p style="color:var(--cyan)">${novas.length} nova${novas.length>1?'s':''} mensage${novas.length>1?'ns':'m'} interceptada${novas.length>1?'s':''}. Veja em Interceptações no mapa.</p>`:'';
  const vitoria=win&&D.hq;if(vitoria){G.vitoria=true;G.wiped=!!(M.flags&&M.flags.wiped);if(!G.wiped)unlock(G,'fim');}
  let reposicao='';
  const novos=[];while(G.agentes.length<3){const n=novoAgente();G.agentes.push(n);if(G.esq.length<4)G.esq.push(n.id);novos.push(n.nome);}
  if(novos.length)reposicao=`<p style="color:var(--cyan)">A Ônix enviou ${novos.length>1?'agentes':'um agente'} de reposição: ${novos.join(', ')}.</p>`;
  save();setState('menu');
  const gameOver=!G.agentes.length&&G.dinheiro<RECRUTA;
  showModal(`<div class="eyebrow">Relatório · ${D.nome} · dia ${G.dia-1}</div><h2 class="${win?'ok':'bad'}">${vitoria?'NOVA AURORA É DA ÔNIX':win?(M.revolta?'Revolta contida':'Missão cumprida'):'Missão fracassada'}</h2><div class="stamp ${win?'ok':'bad'}">${win?'CUMPRIDA':'FRACASSO'}</div><p>${M.reason}</p>
    <dl class="kv"><dt>Abates do esquadrão</dt><dd>${M.stats.abates}</dd><dt>Seguidores recrutados</dt><dd>${M.stats.seguidores}</dd><dt>Civis atingidos</dt><dd>${M.stats.civis}</dd><dt>Policiais abatidos</dt><dd>${M.stats.policiais}</dd><dt>Agentes perdidos</dt><dd>${lost.length?lost.map(a=>a.nome).join(', '):'nenhum'}</dd>${(win?M.bonus||[]:[]).map(b=>`<dt>Bônus · ${b.text}</dt><dd>${fmt(b.val)}</dd>`).join('')}<dt>Recompensa total</dt><dd>${fmt(reward)}</dd><dt>Renda dos distritos + verba do Conselho</dt><dd>${fmt(renda)}</dd><dt>Fundos</dt><dd>${fmt(G.dinheiro)}</dd></dl>
    <div class="labrep">${rivNote}${reposicao}${lab}${terrRep}${msgNote}</div>
    ${contra?`<p style="color:var(--red)">${contra}</p>`:''}
    ${vitoria?'<p>O Consórcio Hélice colapsou. Cada distrito agora paga tributo à Ônix.</p>':''}
    ${gameOver?'<p style="color:var(--red)">Sem agentes e sem fundos para recrutar. A Ônix foi dissolvida.</p>':''}
    <div class="acts">${gameOver?'<button class="btn pri" id="rsNew">Nova campanha</button>':'<button class="btn pri" id="rsOk">Voltar ao mapa</button>'}</div>`,null);
  const ok=$('#rsOk');if(ok)ok.onclick=()=>{hideModal();if(vitoria&&!G.final)showFinalChoice();else showMap();};
  const nw=$('#rsNew');if(nw)nw.onclick=()=>{hideModal();novoJogo();showMap();};
}
$('#btnNovo').onclick=()=>{audioInit();sfx('ui');novoJogo();mapSel=0;showMap();};
$('#btnCont').onclick=()=>{audioInit();const s=load();if(!s)return;setG(s);sfx('ui');showMap();};
$('#btnArs').onclick=()=>showArsenal();
$('#btnLab').onclick=()=>showLab();
$('#btnSair').onclick=()=>showTitle();
$('#btnMsgs').onclick=()=>showInbox();
const escH=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
function showInbox(){
  const list=(G.msgs||[]).slice().reverse();
  const riv=RIVALS.map(r=>{const s=(G.rivais||{})[r.id]||{};return `<span class="rv ${s.morto?'dead':''}" style="--c:${r.trim}"><img src="${rivalPortrait(r)}" alt="">${r.nome}<small>${s.morto?'morto':s.fugas?`${s.fugas} fuga${s.fugas>1?'s':''}`:'à solta'}</small></span>`;}).join('');
  showModal(`<div class="eyebrow">Interceptações · ${list.length} mensage${list.length===1?'m':'ns'}</div><h2>Caixa de entrada</h2>
    <div class="rvs"><span class="l">Os Ponteiros</span>${riv}</div>
    <div class="inbox">${list.map(m=>{const d=MSGS[m.id];return `<button class="msg ${m.lida?'':'new'}" data-id="${m.id}"><span class="mf">${escH(d.de)}</span><span class="ms">${escH(d.assunto)}</span><span class="md mono">dia ${m.dia}</span></button>`;}).join('')||'<p class="hint">Nenhuma mensagem ainda.</p>'}</div>
    <div class="acts"><button class="btn pri" id="ibClose">Fechar</button></div>`,()=>{hideModal();renderMap();});
  $('#ibClose').onclick=()=>{hideModal();renderMap();};
  $('#mbox').querySelectorAll('.msg').forEach(b=>b.onclick=()=>showMsg(b.dataset.id));
}
function showMsg(id){
  const m=(G.msgs||[]).find(q=>q.id===id),d=MSGS[id];if(m)m.lida=true;save();
  showModal(`<div class="eyebrow">De ${escH(d.de)} · para ${escH(d.para)}</div><h2>${escH(d.assunto)}</h2>${d.corpo.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}
    <div class="acts"><button class="btn" id="mgBack">Voltar à caixa</button></div>`,showInbox);
  $('#mgBack').onclick=showInbox;
}
function showFinalChoice(){
  const d=MSGS.fim;
  if(G.wiped){const e=ENDINGS.apagado;G.final='apagado';save();showModal(`<div class="eyebrow">Epílogo</div><h2>${e.titulo}</h2>${e.texto.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}<div class="acts"><button class="btn pri" id="epOk">Voltar ao mapa</button></div>`,null);$('#epOk').onclick=()=>{hideModal();showMap();};return;}
  showModal(`<div class="eyebrow">De ${escH(d.de)} · para ${escH(d.para)}</div><h2>${escH(d.assunto)}</h2>${d.corpo.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}
    <div class="acts"><button class="btn" id="fnDes">Destruir o Coral</button><button class="btn pri" id="fnAti">Ativar o Coral</button></div>`,null);
  const pickEnd=k=>{G.final=k;save();const e=ENDINGS[k];showModal(`<div class="eyebrow">Epílogo</div><h2>${e.titulo}</h2>${e.texto.split('\n').map(p=>`<p>${escH(p)}</p>`).join('')}<div class="acts"><button class="btn pri" id="epOk">Voltar ao mapa</button></div>`,null);$('#epOk').onclick=()=>{hideModal();showMap();};};
  $('#fnAti').onclick=()=>pickEnd('ativar');$('#fnDes').onclick=()=>pickEnd('destruir');
}
$('#btnGfx').onclick=()=>{showModal(`<div class="eyebrow">Opções</div><h2>Gráficos</h2>${gfxRow()}<p class="hint">Ultra liga a oclusão de ambiente. A resolução se ajusta sozinha quando o computador não acompanha; em máquinas fracas, use Média ou Baixa e desligue as sombras.</p><div class="acts"><button class="btn pri" id="gOk">Fechar</button></div>`,hideModal);bindGfx();$('#gOk').onclick=hideModal;};

/* ---------- laço principal ---------- */
let last=performance.now();
function frame(t){
  const dt=Math.min(.05,(t-last)/1000);last=t;
  try{
    if(M&&state==='jogo'){
      if(!M.cine)panCamera(dt);if(!M.paused){update(dt);runScript();if(!M.cine)for(let k=0;k<3;k++){const p=toWorld(Math.random()*innerWidth,Math.random()*innerHeight);if(p.x>0&&p.y>0&&p.x<N&&p.y<N)part(p.x,p.y,1,0,0,18,.22,'#a8c0f0',1,3);}}
      if(M.camGoal){const g=M.camGoal;if(!g.from)g.from={x:camS.x,y:camS.y,z:camS.zoom};g.t+=dt;if(M.cineSkip)g.t=g.dur;const k=g.dur>0?Math.min(1,g.t/g.dur):1,e=k<.5?2*k*k:1-Math.pow(-2*k+2,2)/2;
        camS.x=g.from.x+(g.x-g.from.x)*e;camS.y=g.from.y+(g.y-g.from.y)*e;camS.zoom=g.from.z+(g.z-g.from.z)*e;if(k>=1&&!M.cine)M.camGoal=null;}
      setIntensity(M.ended?0:M.t-(M.lastCombat??-99)<7?3:(M.corpAlert||M.policeAggro>0)?2:1);
      {const car=M.cars.find(c=>c.player&&!c.dead&&c.occ.length);engine(car&&!M.paused?car.cur:0,car&&car.x,car&&car.y);}
      if(flags.hud||((t/100)|0)!==frame.hb){frame.hb=(t/100)|0;updateHud();}
      tipChecks();tipTick(dt);
      renderFrame(dt,mouse);drawMini($('#mini'));
    }else{setIntensity(0);engine(0);}
    if(M&&state==='demo'){
      updateWorld(dt);camS.yaw+=dt*.05;camS.yawA=camS.yaw*Math.PI/2;
      renderFrame(dt,null);
    }
  }catch(err){console.error(err);}
  requestAnimationFrame(frame);
}
export function boot(){
  resize();showTitle();
  if(!renderer.capabilities.isWebGL2)log('WebGL2 indisponível; o jogo pode não rodar bem neste navegador.','red');
  requestAnimationFrame(t=>{last=t;frame(t);});
}
window.__onix={get M(){return M;},get G(){return G;},startMission,novoJogo,showMap,camS,update,__avail:avail,__recruit:()=>{if(G.dinheiro>=RECRUTA&&G.agentes.length<8){G.dinheiro-=RECRUTA;G.agentes.push(novoAgente());}}};
boot();
