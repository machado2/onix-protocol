/* Simulação: combate, IA, agentes, sequestro neural, veículos, objetivos. */
import {N,TAU,FLOOR,T_BLD,T_WALK,T_PLAZA,T_GRASS,T_TREE,T_WATER,T_FENCE,T_GLASS,clamp,gauss,pick,M,G,flags,hooks,WD,MAXINV,RESIST,PRESETS,REDUCED,equipable,has,penteOf} from './core.js';
import {mkUnit,canStand,walkAt,los,findPath,pathTo,moveAlong,randomNear,sideTile} from './world.js';
import {sfx} from './audio.js';
import {RIVALS} from './story.js';

const log=(m,c)=>hooks.log(m,c);
export const curW=u=>u.kind==='agente'?(u.eq>=0?u.inv[u.eq].t:null):u.w;
export const isArmed=u=>{const w=curW(u);return !!(w&&WD[w].arma);};
export const posOf=u=>u.inCar?u.inCar:u;

/* ---------- relações e percepção ---------- */
export function isEnemyOf(a,b){
  if(b.dead)return false;
  if(a.fac==='player'){if(b.fac==='corp')return b.alerted;if(b.fac==='police')return M.policeAggro>0;return false;}
  if(a.fac==='corp')return a.alerted&&b.fac==='player';
  if(a.fac==='police')return M.policeAggro>0&&b.fac==='player';
  return false;
}
function nearestHostile(u,range){
  let best=null,bd=range;
  for(const v of M.units){if(v===u||v.dead||!isEnemyOf(u,v))continue;const p=posOf(v),d=Math.hypot(p.x-u.x,p.y-u.y);if(v.cloak&&d>1.5)continue;if(d<bd&&los(u.x,u.y,p.x,p.y)){best=v;bd=d;}}
  return best;
}
export function nearestAgent(u,r){let best=null,bd=r;for(const a of M.agents){if(a.dead)continue;const p=posOf(a),d=Math.hypot(p.x-u.x,p.y-u.y);if(d<bd){best=a;bd=d;}}return best;}
export function alertCorp(v,x,y){
  if(v.alerted||v.fac!=='corp')return;
  v.alerted=true;v.lkp={x,y};v.cool=Math.max(v.cool,.5+Math.random()*.6);
  for(const w of M.units)if(!w.dead&&w.fac==='corp'&&!w.alerted&&Math.hypot(w.x-v.x,w.y-v.y)<11){w.alerted=true;w.lkp={x,y};}
  if(!M.corpAlert){M.corpAlert=true;log('ALERTA: a segurança do Consórcio detectou o esquadrão.','red');sfx('alarm');if(v.mech)hooks.vo('ctl:drone');else hooks.vo(v.kind==='inimigo'?'ene:alert':'grd:alert',v);hooks.vo('ctl:alarm');}
}
function triggerPolice(msg,who){
  if(M.policeAggro<=0){log(msg,'red');sfx('siren');M.reinfT=14;const p=who||M.units.find(q=>q.kind==='policia'&&!q.dead&&!q.follower);if(p)hooks.vo('pol:fire',p);hooks.vo('ctl:police');}
  M.policeAggro=has('trafego')?26:40;
}
function policeSees(x,y,r){for(const p of M.units)if(p.kind==='policia'&&!p.dead&&!p.follower&&Math.hypot(p.x-x,p.y-y)<r&&los(p.x,p.y,x,y))return true;return false;}
function noise(x,y,r,src){
  if(M.flags&&M.flags.trainNoise)r*=.35;
  for(const v of M.units){
    if(v.dead||v.follower)continue;const d=Math.hypot(v.x-x,v.y-y);if(d>r)continue;
    if(v.kind==='civil'){if(v.panicT<=0){v.path=null;if(Math.random()<.15)hooks.vo('civ',v);}v.panicT=6+Math.random()*4;v.pfx=x;v.pfy=y;}
    else if(v.fac==='corp'&&!v.alerted&&src&&src.fac==='player')alertCorp(v,x,y);
    else if(v.kind==='policia'&&src&&src.fac==='player'&&M.policeAggro<=0){
      if(d<9&&los(v.x,v.y,src.x,src.y))triggerPolice('A polícia viu o esquadrão atirando.',v);
      else if(!v.invest){v.invest=true;pathTo(v,x,y);}
    }
  }
}
function detect(u,dt,dr,hr){
  u.percT-=dt;if(u.percT>0)return;u.percT=.3;
  for(const a of M.agents){
    if(a.dead||a.inCar||a.cloak)continue;const d=Math.hypot(a.x-u.x,a.y-u.y);
    let r=isArmed(a)?dr:hr;r*=1.2-.5*a.nr.c;if(!litAt(a.x,a.y))r*=.72;
    if(d<r&&los(u.x,u.y,a.x,a.y)){alertCorp(u,a.x,a.y);u.tgt=a;return;}
  }
}

/* ---------- combate ---------- */
function aimAt(u,x,y){u.face=Math.atan2(y-u.y,x-u.x);u.aimT=.6;}
export function part(x,y,z,vx,vy,vz,life,col,size,type){if(M.parts.length<1600)M.parts.push({x,y,z,vx,vy,vz,life,max:life,col,size,type});}
export function say(u,txt,col){M.texts.push({u,x:u.x,y:u.y,txt,col:col||'#ffd27a',life:2.4});}
function fireWeapon(u,wk,st,tx,ty,accMul=1,rofMul=1,rngMul=1){
  if(u.heavy)rofMul*=2.5;
  const w=WD[wk];if(!w||!w.arma||u.cool>0||u.rel>0)return false;
  if(st.mun<=0){u.rel=w.recarga;u.relSt=st;u.relW=wk;return false;}
  st.mun--;if(st.mun<=0){u.rel=w.recarga;u.relSt=st;u.relW=wk;if(u.kind==='agente'&&Math.random()<.5)hooks.vo('ag:rel',u);}
  if(u.fac==='player'||u.alerted||(u.fac==='police'&&M.policeAggro>0))M.lastCombat=M.t;
  u.cool=w.cad*rofMul;u.flash=.07;aimAt(u,tx,ty);
  const ang=u.face,acc=Math.min(1.15,u.acc*accMul),range=w.alcance*(u.rngMul||1)*rngMul;
  const mx=u.x+Math.cos(ang)*.45,my=u.y+Math.sin(ang)*.45;
  M.flashes.push({x:mx,y:my,life:.06,max:.06,i:2.5,col:w.laser?'#ff4080':'#ffc070'});
  if(!w.flame)(M.vfx||(M.vfx=[])).push({k:'muzzle',x:mx,y:my,z:.64,life:.055,max:.055,size:w.pellets?1:wk==='serra'?.8:w.laser?.7:.55,col:w.laser?'#ff5aa0':'#ffd890'});
  if(!w.flame&&!w.laser&&M.debris&&Math.random()<.55){const s=Math.random()<.5?1:-1;M.debris.push({x:u.x+Math.cos(ang)*.12,y:u.y+Math.sin(ang)*.12,z:.6,vx:-Math.sin(ang)*s*1.4+(Math.random()-.5)*.6,vy:Math.cos(ang)*s*1.4+(Math.random()-.5)*.6,vz:2+Math.random()*1.5,rx:0,ry:Math.random()*3,rz:0,vr:22,s:.05,col:'#c8a040',life:2.2});if(M.debris.length>420)M.debris.shift();}
  if(!w.flame)part(mx,my,19,0,0,0,.05,w.laser?'#ff5090':'#ffd080',1,1);
  if(w.flame){
    for(let k=0;k<3;k++){const a=ang+(Math.random()-.5)*.45,s=4+Math.random()*3;part(mx,my,18,Math.cos(a)*s,Math.sin(a)*s,(Math.random()-.3)*10,.42+Math.random()*.2,'#ff8c28',1,1);}
    for(const v of M.units){
      if(v===u||v.dead||v.fac===u.fac||v.inCar)continue;const dx=v.x-u.x,dy=v.y-u.y,d=Math.hypot(dx,dy);if(d>range)continue;
      let da=Math.abs(Math.atan2(dy,dx)-ang);if(da>Math.PI)da=TAU-da;
      if(da<.34&&los(u.x,u.y,v.x,v.y)){hurt(v,w.dano,u);v.burn=Math.max(v.burn,2.5);v.burnSrc=u;}
    }
    for(const c of M.cars){if(c.dead)continue;const dx=c.x-u.x,dy=c.y-u.y,d=Math.hypot(dx,dy);if(d<range+.4){let da=Math.abs(Math.atan2(dy,dx)-ang);if(da>Math.PI)da=TAU-da;if(da<.4)hurtCar(c,w.dano*.6,u);}}
    for(const p of M.props){if(!p.dead&&Math.hypot(p.x-u.x,p.y-u.y)<range)hurtProp(p,w.dano*.5,u);}
    if(Math.random()<.05){const d=range*(.6+Math.random()*.4);addFire(u.x+Math.cos(ang)*d,u.y+Math.sin(ang)*d,5);}
    for(const tr of M.trees){if(tr.dead)continue;const d=Math.hypot(tr.x-u.x,tr.y-u.y);if(d<range+.5&&Math.random()<.03){let da=Math.abs(Math.atan2(tr.y-u.y,tr.x-u.x)-ang);if(da>Math.PI)da=TAU-da;if(da<.4)burnTree(tr);}}
  }else if(w.laser){
    const dx=Math.cos(ang),dy=Math.sin(ang),hw=rayWall(u.x,u.y,dx,dy,range);let wt=hw?hw.t:range;
    if(hw&&!hw.out){wallHit(hw,u.x+dx*wt,u.y+dy*wt,.62,u,w.dano);const ex=u.x+dx*wt,ey=u.y+dy*wt;addDecal({kind:'scorch',x:ex,y:ey,z:.62,nx:hw.nx,ny:hw.ny,w:.35,h:.35});}
    for(const l of M.lamps){if(l.dead)continue;const rx=l.x-u.x,ry=l.y-u.y,t=rx*dx+ry*dy;if(t>.3&&t<wt&&Math.abs(rx*dy-ry*dx)<.15)breakLamp(l);}
    for(const v of M.units){if(v===u||v.dead||v.fac===u.fac||v.inCar)continue;const rx=v.x-u.x,ry=v.y-u.y,t=rx*dx+ry*dy;if(t<.2||t>wt)continue;if(Math.abs(rx*dy-ry*dx)<.38)hurt(v,w.dano,u);}
    for(const c of M.cars){if(c.dead)continue;const rx=c.x-u.x,ry=c.y-u.y,t=rx*dx+ry*dy;if(t<.2||t>wt)continue;if(Math.abs(rx*dy-ry*dx)<.6)hurtCar(c,w.dano,u);}
    for(const p of M.props){if(p.dead)continue;const rx=p.x-u.x,ry=p.y-u.y,t=rx*dx+ry*dy;if(t>.2&&t<wt&&Math.abs(rx*dy-ry*dx)<.35)hurtProp(p,w.dano,u);}
    M.tracers.push({x1:mx,y1:my,x2:u.x+dx*wt,y2:u.y+dy*wt,life:.3,max:.3,col:'#ff3c78',beam:1});
    for(let k=0;k<8;k++){const t=Math.random()*wt;part(u.x+dx*t,u.y+dy*t,17,0,0,4,.25,'#ff4c8c',1,1);}
  }else{
    const pel=w.pellets||1,sp=(w.disp||.05)+(1-Math.min(acc,1))*.22;
    for(let k=0;k<pel;k++)bullet(u,ang+gauss()*sp,range*1.12,w.dano,mx,my);
  }
  sfx(w.som,u.x,u.y);
  noise(u.x,u.y,w.flame?7:w.laser?9:11,u);
  return true;
}
function bullet(u,a,range,dmg,mx,my){
  const dx=Math.cos(a),dy=Math.sin(a),hw=rayWall(u.x,u.y,dx,dy,range);let wt=hw?hw.t:range;
  let best=null,bt=wt,car=null,prop=null;
  for(const v of M.units){
    if(v===u||v.dead||v.fac===u.fac||v.inCar||(u.fac==='player'&&v.kind==='cientista')||v.hold)continue;
    const rx=v.x-u.x,ry=v.y-u.y,t=rx*dx+ry*dy;if(t<.2||t>bt)continue;
    if(Math.abs(rx*dy-ry*dx)<(v.mech?.38:.3)){best=v;bt=t;}
  }
  for(const c of M.cars){if(c.dead||c.occ.some(o=>o.fac===u.fac))continue;const rx=c.x-u.x,ry=c.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.5){car=c;best=null;bt=t;}}
  for(const c of M.cams||[]){if(c.dead)continue;const rx=c.x-u.x,ry=c.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.25){hurtCam(c);break;}}
  for(const p of M.props){if(p.dead)continue;const rx=p.x-u.x,ry=p.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.28){prop=p;car=null;best=null;bt=t;}}
  for(const l of M.lamps){if(l.dead)continue;const rx=l.x-u.x,ry=l.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.1&&Math.random()<.4)breakLamp(l);}
  if(best&&Math.hypot(best.x-u.x,best.y-u.y)>1.6&&coverAt(best.x,best.y,u)&&Math.random()<.5){const q=Math.max(.2,bt-.45);bt=q;best=null;sfx('ric',u.x+dx*q,u.y+dy*q);}
  for(const v of M.units){
    if(v===best||v.dead||v.inCar||v.fac===u.fac||v.fac==='civ'||v.fac==='neutral'||v.heavy)continue;
    const rx=v.x-u.x,ry=v.y-u.y,t=rx*dx+ry*dy;if(t<.2||t>bt+.6)continue;
    if(Math.abs(rx*dy-ry*dx)<.7){v.suppP=(v.suppP||0)+.22;if(v.suppP>=1){if(!(v.supp>0))v.coverT=Math.min(v.coverT??1,.15);v.supp=1.2;v.suppP=.5;}}
  }
  if(M.glassN>0)for(let s=.25;s<bt;s+=.2){const gx=Math.floor(u.x+dx*s),gy=Math.floor(u.y+dy*s);if(gx>=0&&gy>=0&&gx<N&&gy<N&&M.tile[gy*N+gx]===T_GLASS)shatterGlass(gx,gy);}
  const ex=u.x+dx*bt,ey=u.y+dy*bt;
  M.tracers.push({x1:mx,y1:my,x2:ex,y2:ey,life:.07,max:.07,col:u.fac==='player'?'#ffe6a0':'#ffaa78'});
  if(best)hurt(best,dmg,u);
  else if(prop)hurtProp(prop,dmg,u);
  else if(car){hurtCar(car,dmg,u);for(let k=0;k<3;k++)part(ex,ey,12,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*20,.25,'#ffd28c',1,3);}
  else if(hw&&!hw.out&&bt>=hw.t-.001)wallHit(hw,ex,ey,.6+gauss()*.12,u,dmg);
  else{part(ex,ey,2,0,0,8,.5,'#6a6460',1,2);}
  if(!best&&!prop&&!car&&!(hw&&!hw.out&&bt>=hw.t-.001))for(let k=0;k<2;k++)part(ex,ey,8,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*20,.25,'#ffd28c',1,3);
}
export function hurt(v,dmg,src){
  if(v.dead)return;
  if(v.kind==='agente'&&v.neuro)dmg*=1-v.neuro.res;
  if(v.hold)dmg*=.3;
  if(v.shield){if(Math.random()<.5)sfx('ric',v.x,v.y);for(let k=0;k<2;k++)part(v.x,v.y,22,(Math.random()-.5)*2.5,(Math.random()-.5)*2.5,15+Math.random()*20,.35,'#6fe4ff',1,3);if(src&&src.fac==='player'&&v.fac==='corp')alertCorp(v,src.x,src.y);return;}
  v.hp-=dmg*(1-(v.armor||0)*(src&&src.fac==='player'&&has('perfurante')?.5:1));v.hitT=.08;v.barT=3;v.lastHit=M.t;if(v.kind==='agente')M.hurtFlash=Math.min(1,(M.hurtFlash||0)+dmg/35);if(!v.mech)sfx('hit',v.x,v.y);else if(Math.random()<.5)sfx('ric',v.x,v.y);
  if(v.kind==='agente'){M.lastCombat=M.t;if(v.hp>0&&v.hp<v.maxHp*.55)hooks.vo('ag:hurt',v);}
  if(!v.mech&&Math.random()<.6)part(v.x,v.y,16,(Math.random()-.5)*2,(Math.random()-.5)*2,10,.4,'#8a0a18',1,0);
  if(src&&src.fac==='player'&&src!==v){
    if(v.fac==='corp'){if(v.disguise)reveal(v);alertCorp(v,src.x,src.y);}
    if(v.fac==='police')triggerPolice('O esquadrão atacou a polícia.',v);
    if((v.fac==='civ'||v.fac==='neutral')&&M.policeAggro<=0&&policeSees(v.x,v.y,10))triggerPolice('A polícia testemunhou um ataque a civis.');
  }
  if(src&&src!==v&&!v.tgt&&v.fac!=='civ'&&v.fac!=='neutral'&&isEnemyOf(v,src))v.tgt=src;
  if(v.hp<=0)kill(v,src);
}
function kill(v,src){
  v.dead=true;v.deathT=0;v.path=null;v.hp=0;v.burn=0;v.hj=0;
  if(v.kb&&v.kb.p>.12&&!v.mech&&!v.heavy){v.kbFrom={x:v.x,y:v.y};v.face=Math.atan2(-v.kb.y,-v.kb.x);for(let L=.6+v.kb.p*1.8;L>.2;L-=.3){const nx=v.x+v.kb.x*L,ny=v.y+v.kb.y*L;if(canStand(nx,ny)){v.x=nx;v.y=ny;break;}}}
  if(!v.mech)sfx('die',v.x,v.y);
  if(v.kind==='torre'){explode(v.x,v.y,1.2,25,src);return;}
  if(v.kind==='drone'){explode(v.x,v.y,.9,14,src);spawnDebris(v.x,v.y,1.4,6,['#2a2f3a','#d8dce4','#111318'],3,[.06,.16]);if(src&&src.fac==='player'&&v.fac!=='player')M.stats.abates++;return;}
  const dropW=v.kind==='agente'?(isArmed(v)?v.inv[v.eq].t:null):(v.w&&WD[v.w].arma?v.w:null);
  if(dropW)M.drops.push({x:v.x+(Math.random()-.5)*.3,y:v.y+(Math.random()-.5)*.3,t:dropW});
  if(v.follower)M.followers=Math.max(0,M.followers-1);
  if(src&&src.fac==='player'&&!v.follower){
    M.stats.abates++;if(v.kind==='civil')M.stats.civis++;if(v.kind==='policia')M.stats.policiais++;
    if(src.kind==='agente'){src.kills++;if(v.kind!=='civil'&&Math.random()<.55)hooks.vo('ag:kill',src);}
  }
  if(v.kind==='guarda'&&!v.follower){const b=M.units.find(q=>q.kind==='guarda'&&!q.dead&&!q.follower&&Math.hypot(q.x-v.x,q.y-v.y)<8);if(b&&Math.random()<.4)hooks.vo('grd:down',b);}
  if(v.kind==='agente'){log(`Agente ${v.nome} foi abatido.`,'red');M.sel=M.sel.filter(a=>a!==v);v.sel=false;flags.hud=true;const o=M.agents.find(a=>!a.dead);if(o)hooks.vo('ag:down',o);hooks.vo('ctl:lost');}
  if(v.rival&&!v.vanished){hooks.vo('riv:'+v.rival+'_death',v);hooks.vo('ctl:riv_kill');(M.bonus=M.bonus||[]).push({text:'Ponteiro eliminado: '+v.nome,val:3000});(M.rivalDead=M.rivalDead||[]).push(v.rival);if(G&&G.rivais)(G.rivais[v.rival]||(G.rivais[v.rival]={})).morto=true;log(`${v.nome} está morto.`,'green');}
  if(v.kind==='vip')log(v.double?'Um sósia foi abatido.':`Alvo eliminado: ${v.nome}.`,v.double?'amber':'green');
  if(v.kind==='cientista')log(`${v.nome} foi morta no fogo cruzado.`,'red');
  hooks.decal('blood',v.x,v.y);
}
function hurtCar(c,dmg,src){
  if(c.dead)return;c.hp-=dmg;c.hitT=.08;
  if(c.hp<=0){
    c.dead=true;c.cur=0;c.path=null;
    const occ=c.occ.slice();exitCar(c);
    explode(c.x,c.y,2,60,src);spawnDebris(c.x,c.y,.5,10,[c.col,'#111318','#2a2a2a','#0a0a0a'],5,[.12,.3]);addFire(c.x,c.y,14);
    occ.forEach(u=>{if(!u.dead){hurt(u,30,src);u.burn=Math.max(u.burn,2);}});
  }
}
function hurtProp(p,dmg,src){if(p.dead)return;p.hp-=dmg;if(p.hp<=0){p.dead=true;explode(p.x,p.y,2.4,75,src);}}
export function explode(x,y,r,dmg,src){
  sfx('boom',x,y);if(!REDUCED)M.shake=Math.min(1,M.shake+.6);
  for(let i=0;i<26;i++){const a=Math.random()*TAU,s=Math.random()*3.2;part(x,y,6,Math.cos(a)*s,Math.sin(a)*s,Math.random()*30+8,.45+Math.random()*.4,i%3?'#ff8c28':'#ffd060',1,1);}
  for(let i=0;i<16;i++){const a=Math.random()*TAU,s=Math.random()*1.2;part(x,y,10,Math.cos(a)*s,Math.sin(a)*s,20+Math.random()*20,1.6+Math.random(),'#2a2c34',1,2);}
  for(let i=0;i<18;i++){const a=Math.random()*TAU,s=2+Math.random()*5;part(x,y,8,Math.cos(a)*s,Math.sin(a)*s,40+Math.random()*60,.7,'#ffdc96',1,3);}
  M.flashes.push({x,y,life:.5,max:.5,i:30,col:'#ff9a40'});
  hooks.decal('scorch',x,y,r);
  for(const v of M.units){if(v.dead||v.inCar)continue;const d=Math.hypot(v.x-x,v.y-y);if(d<r){v.burn=Math.max(v.burn,1.2);v.burnSrc=src;v.kb={x:(v.x-x)/(d||1),y:(v.y-y)/(d||1),p:1-d/r};hurt(v,dmg*(1-.6*d/r),src);if(!v.dead)v.kb=null;}}
  (M.vfx||(M.vfx=[])).push({k:'ring',x,y,life:.55,max:.55,size:r*1.5,col:'#ffb070'},{k:'ball',x,y,z:.7,life:.45,max:.45,size:r*1.2,col:'#ffa040'});
  for(const c of M.cars){if(!c.dead&&Math.hypot(c.x-x,c.y-y)<r+.6)hurtCar(c,dmg*.8,src);}
  for(const p of M.props){if(!p.dead&&Math.hypot(p.x-x,p.y-y)<r+.3)hurtProp(p,999,src);}
  for(const c of M.cams||[])if(!c.dead&&Math.hypot(c.x-x,c.y-y)<r+.5)hurtCam(c);
  blast(x,y,r,dmg,src);
  noise(x,y,16,src);
}

/* ---------- sequestro neural ---------- */
function convert(v,owner){
  v.fac='player';v.follower=true;v.owner=owner;v.hj=0;v.hjT=0;v.alerted=false;v.tgt=null;v.path=null;v.panicT=0;v.warned=false;v.invest=false;v.escort=null;
  v.spd=Math.max(v.spd,2.15);if(v.kind==='civil')v.hp=v.maxHp=Math.max(v.maxHp,45);
  if(v.kind==='civil'&&has('armados')&&!v.w){v.w='pistola';v.mun=WD.pistola.pente;}
  M.followers++;M.stats.seguidores++;
  say(v,'...sim.','#4fd8ff');sfx('convert',v.x,v.y);(M.vfx||(M.vfx=[])).push({k:'ring',x:v.x,y:v.y,life:.6,max:.6,size:1.6,col:'#4fd8ff'});for(let k=0;k<14;k++)part(v.x+(Math.random()-.5)*.4,v.y+(Math.random()-.5)*.4,10+Math.random()*20,0,0,30+Math.random()*30,.8,'#6fe4ff',1,1);hooks.convert(v);if(Math.random()<.6)hooks.vo('ag:conv',owner);
  if(M.followers===1)log('Primeiro seguidor recrutado. Seguidores apanham armas do chão e lutam pelo esquadrão.','cyan');
}
function hijackTick(u,dt,w){
  const pw=Math.min(4,1+.2*M.followers)*(.7+.6*u.nr.c)*(has('sonda2')?1.3:1)*(has('sonda3')?1.6:1),rng=w.alcance+(has('sonda2')?1:0);
  let any=false;
  for(const v of M.units){
    if(v.dead||v.fac==='player'||v.inCar)continue;
    const res=RESIST[v.kind];if(!res)continue;
    const d=Math.hypot(v.x-u.x,v.y-u.y);if(d>rng||!los(u.x,u.y,v.x,v.y))continue;
    v.hj+=dt*pw/(res*(v.alerted?1.5:1));v.hjT=.25;any=true;
    if(v.hj>=1)convert(v,u);
  }
  u.probing=any;u.pulseT=(u.pulseT||0)-dt;if(u.pulseT<=0){u.pulseT=.75;(M.vfx||(M.vfx=[])).push({k:'ring',x:u.x,y:u.y,life:.75,max:.75,size:(w.alcance+(has('sonda2')?1:0))*1.05,col:'#2fb8e0'});}
}
function updFollower(u,dt){
  if(u.w&&WD[u.w].arma){if(aiCombat(u,dt,WD[u.w].alcance))return;}
  else{
    let best=null,bd=7;for(const d of M.drops){const dd=Math.hypot(d.x-u.x,d.y-u.y);if(dd<bd){bd=dd;best=d;}}
    if(best){
      if(bd<.6){u.w=best.t;u.mun=WD[best.t].pente;M.drops.splice(M.drops.indexOf(best),1);hooks.convert(u);return;}
      u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.8;pathTo(u,best.x,best.y);}moveAlong(u,dt,u.spd);return;
    }
  }
  const L=u.owner&&!u.owner.dead?u.owner:nearestAgent(u,999);if(!L)return;
  const p=posOf(L),d=Math.hypot(p.x-u.x,p.y-u.y);
  if(d>2.4){u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.7+Math.random()*.4;pathTo(u,p.x+(Math.random()-.5)*2,p.y+(Math.random()-.5)*2);}moveAlong(u,dt,u.spd*(d>6?1.3:1));}
  else if(u.path)moveAlong(u,dt,u.spd*.8);
}

/* ---------- IA ---------- */
/* ---------- cobertura ---------- */
const N8=[[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]];
/* coberto contra 'from' se há parede, contêiner ou carro colado no lado voltado para o atirador */
export function coverAt(x,y,from){
  const dx=from.x-x,dy=from.y-y,l=Math.hypot(dx,dy)||1,ux=dx/l,uy=dy/l,tx=Math.floor(x),ty=Math.floor(y);
  for(const [ox,oy] of N8){
    const ol=Math.hypot(ox,oy);if((ox*ux+oy*uy)/ol<.72)continue;
    const X=tx+ox,Y=ty+oy;if(X<0||Y<0||X>=N||Y>=N)continue;
    if(M.tile[Y*N+X]===T_BLD)return true;
  }
  const px=x+ux*.7,py=y+uy*.7;
  for(const c of M.cars)if(Math.abs(c.x-px)<.7&&Math.abs(c.y-py)<.7&&!c.occ.length)return true;
  return false;
}
function findCover(u,tp,range,retreat){
  let best=null,bs=-1e9;const R=retreat?7:5;
  const allies=M.units.filter(o=>o!==u&&!o.dead&&o.fac===u.fac&&o.cover&&o.tgt===u.tgt);
  for(let k=0;k<36;k++){
    const x=Math.floor(u.x+(Math.random()*2-1)*R)+.5,y=Math.floor(u.y+(Math.random()*2-1)*R)+.5;
    if(!canStand(x,y))continue;
    const dt=Math.hypot(tp.x-x,tp.y-y);if(dt<2.2||(!retreat&&dt>range*.95))continue;
    if(!coverAt(x,y,tp))continue;
    if(!retreat&&!los(x,y,tp.x,tp.y))continue;
    let s=-Math.hypot(x-u.x,y-u.y)*.5+(retreat?dt*.8:-Math.abs(dt-range*.7)*.4);
    const a=Math.atan2(y-tp.y,x-tp.x);
    for(const o of allies){
      const od=Math.hypot(o.cover.x-x,o.cover.y-y);if(od<2)s-=(2-od)*3;
      let da=Math.abs(Math.atan2(o.cover.y-tp.y,o.cover.x-tp.x)-a);if(da>Math.PI)da=TAU-da;s-=Math.max(0,.9-da)*2.5;
    }
    if(s>bs){bs=s;best={x,y};}
  }
  return best;
}
function enemyNade(u,tp,d){
  u.nades--;u.nadeT=M.t+7;
  const tx=tp.x+(Math.random()-.5)*.8,ty=tp.y+(Math.random()-.5)*.8;
  aimAt(u,tx,ty);M.nades.push({sx:u.x,sy:u.y,tx,ty,t:0,T:1.15+d*.06,src:u,wt:'granada'});
  say(u,'GRANADA!','#ff4d5e');
}
const smartAI=u=>!u.follower&&u.spd>0&&(u.kind==='guarda'||u.kind==='inimigo'||u.kind==='policia');

/* ---------- IA de combate ---------- */
function aiCombat(u,dt,range){
  let t=u.tgt;
  if(t&&(t.dead||!isEnemyOf(u,t)||(t.cloak&&Math.hypot(t.x-u.x,t.y-u.y)>1.5)))t=u.tgt=null;
  u.scanT-=dt;
  if(u.scanT<=0){u.scanT=.35+Math.random()*.2;const nt=nearestHostile(u,range*1.3);if(nt){if(nt!==t)u.cool=Math.max(u.cool,.25+Math.random()*.3);t=u.tgt=nt;}}
  if(!t)return false;
  const tp=posOf(t),d=Math.hypot(tp.x-u.x,tp.y-u.y),vis=d<=range*1.35&&los(u.x,u.y,tp.x,tp.y);
  const smart=smartAI(u),acc=u.supp>0?.6:1;
  if(vis){
    u.lostT=0;u.lkp={x:tp.x,y:tp.y};
    if(u.kind==='policia'&&!u.follower){M.policeAggro=Math.max(M.policeAggro,30);M.lastSeen={x:tp.x,y:tp.y};}
    if(!u.contact&&!u.follower){u.contact=true;if(u.rival){hooks.vo('riv:'+u.rival+'_intro',u);hooks.vo('ctl:riv_spot');(M.rivalSeen=M.rivalSeen||new Set()).add(u.rival);log(`${u.nome}, um dos Ponteiros do Consórcio, entrou no combate.`,'red');}else if(u.kind==='guarda')hooks.vo('grd:contact',u);else if(u.kind==='inimigo')hooks.vo('ene:alert',u);}
    if(smart){
      u.coverT=(u.coverT??Math.random()*.8)-dt;
      if(u.hp<u.maxHp*.35&&!u.retreated){u.retreated=true;const c=findCover(u,tp,range,true);if(c){u.cover=c;pathTo(u,c.x,c.y);}}
      else if(u.coverT<=0){u.coverT=2.5+Math.random()*2;if(d>range||!coverAt(u.x,u.y,tp)){const c=findCover(u,tp,range,false);if(c&&Math.hypot(c.x-u.x,c.y-u.y)>.5){u.cover=c;pathTo(u,c.x,c.y);}}}
      if(u.nades>0&&M.t>=(u.nadeT||0)&&d>3&&d<7.5&&!t.inCar&&(coverAt(tp.x,tp.y,u)||M.agents.filter(a=>!a.dead&&!a.inCar&&Math.hypot(a.x-tp.x,a.y-tp.y)<2.2).length>=2))enemyNade(u,tp,d);
      if(u.path&&u.cover){moveAlong(u,dt,u.spd*1.3);if(d<=range){aimAt(u,tp.x,tp.y);fireWeapon(u,u.w,u,tp.x,tp.y,.55*acc);}return true;}
    }
    if(d<=range){u.path=null;aimAt(u,tp.x,tp.y);fireWeapon(u,u.w,u,tp.x,tp.y,acc);return true;}
  }else{u.lostT+=dt;if(u.lostT>4){u.tgt=null;u.cover=null;return false;}}
  if(u.spd>0){
    if(smart&&u.path&&u.cover){moveAlong(u,dt,u.spd*1.3);return true;}
    u.cover=null;
    u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.8+Math.random()*.5;pathTo(u,tp.x,tp.y);}moveAlong(u,dt,u.spd*1.15);
  }
  return true;
}
function wander(u,dt,cx,cy,r,mul,pred){
  if(u.path){moveAlong(u,dt,u.spd*mul);return;}
  u.idleT-=dt;if(u.idleT>0)return;u.idleT=1+Math.random()*4;
  const t=randomNear(cx,cy,r,pred);if(t)pathTo(u,t.x,t.y);
}
function updCiv(u,dt){
  if((u.still||u.dance)&&u.panicT<=0){u.path=null;return;}
  if(u.panicT>0){
    u.panicT-=dt;
    if(!u.path){const dx=u.x-u.pfx,dy=u.y-u.pfy,d=Math.hypot(dx,dy)||1;const t=randomNear(u.x+dx/d*7,u.y+dy/d*7,3);if(t)pathTo(u,t.x,t.y);}
    moveAlong(u,dt,2.6);return;
  }
  if(u.home)wander(u,dt,u.home.x,u.home.y,6,1,sideTile);else wander(u,dt,u.x,u.y,10,1,sideTile);
}
function updPolice(u,dt){
  if(M.policeAggro>0){
    u.warned=false;
    if(aiCombat(u,dt,WD[u.w].alcance))return;
    if(M.lastSeen){if(!u.path){u.repT-=dt;if(u.repT<=0){u.repT=2;pathTo(u,M.lastSeen.x+(Math.random()-.5)*3,M.lastSeen.y+(Math.random()-.5)*3);}}moveAlong(u,dt,u.spd*1.4);}
    else wander(u,dt,u.x,u.y,8,1,sideTile);
    return;
  }
  u.percT-=dt;
  if(u.percT<=0){
    u.percT=.3;let seen=null;
    for(const a of M.agents)if(!a.dead&&!a.inCar&&!a.cloak&&isArmed(a)&&Math.hypot(a.x-u.x,a.y-u.y)<7&&los(u.x,u.y,a.x,a.y)){seen=a;break;}
    u.seeing=seen;
    if(seen){u.path=null;aimAt(u,seen.x,seen.y);u.lost=0;if(!u.warned){u.warned=true;u.warnT=3.5;hooks.vo('pol:warn',u);log('Polícia: guardem as armas (tecla H) ou haverá confronto.','amber');sfx('siren');}}
    else if(u.warned){u.lost=(u.lost||0)+.3;if(u.lost>2.5)u.warned=false;}
  }
  if(u.warned&&u.seeing){u.warnT-=dt;if(u.warnT<=0){u.warned=false;M.lastSeen={x:u.seeing.x,y:u.seeing.y};triggerPolice('A polícia abriu fogo contra o esquadrão!',u);}return;}
  if(u.invest){if(!moveAlong(u,dt,u.spd*1.3))u.invest=false;return;}
  wander(u,dt,u.x,u.y,9,.9,t=>t===T_WALK);
}
function rivalTick(u,dt){
  const R=RIVALS.find(r=>r.id===u.rival);
  if(u.escaping){
    u.escT-=dt;moveAlong(u,dt,u.spd*1.4);
    if(!u.path||u.escT<=0||u.x<1.3||u.y<1.3||u.x>N-1.3||u.y>N-1.3){
      u.dead=true;u.vanished=true;u.hp=0;(M.rivalEsc=M.rivalEsc||[]).push(u.rival);
      if(G&&G.rivais){const s=G.rivais[u.rival]||(G.rivais[u.rival]={});s.fugas=(s.fugas||0)+1;}
      log(`${u.nome} escapou.`,'amber');hooks.vo('ctl:riv_esc');
    }
    return true;
  }
  if(R&&!R.hqOnly&&u.hp<u.maxHp*.3){
    u.escaping=true;u.escT=10;u.tgt=null;hooks.vo(`riv:${u.rival}_esc`,u);
    const ex=[[1,u.y],[N-1.5,u.y],[u.x,1],[u.x,N-1.5]].sort((a,b)=>Math.hypot(a[0]-u.x,a[1]-u.y)-Math.hypot(b[0]-u.x,b[1]-u.y))[0];
    pathTo(u,ex[0],ex[1]);return true;
  }
  return false;
}
function updGuard(u,dt){
  if(u.fleeTo){
    if(M.escCar&&M.escCar.dead){u.fleeTo=null;u.path=null;}
    else{
      if(Math.hypot(u.x-u.fleeTo.x,u.y-u.fleeTo.y)<1.4){u.path=null;u.boardT=(u.boardT||0)+dt;if(u.boardT>4){u.dead=true;u.vanished=true;u.hp=0;M.flags.escaped=(M.flags.escaped||0)+1;}}
      else{if(!u.path)pathTo(u,u.fleeTo.x,u.fleeTo.y);moveAlong(u,dt,u.spd*1.1);}
      return;
    }
  }
  if(u.rival&&rivalTick(u,dt))return;
  if(!u.alerted){
    if(u.kind==='inimigo'&&M.corpAlert)u.alerted=true;
    else{
      detect(u,dt,u.kind==='inimigo'?8.5:7,3.4);
      if(!u.alerted){
        if(u.escort&&!u.escort.dead){if(Math.hypot(u.escort.x-u.x,u.escort.y-u.y)>1.8){u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.8;pathTo(u,u.escort.x+(Math.random()-.5),u.escort.y+(Math.random()-.5));}moveAlong(u,dt,u.spd);}}
        else{const h=u.home||u;wander(u,dt,h.x,h.y,u.kind==='inimigo'?10:3.5,.55,sideTile);}
        return;
      }
    }
  }
  if(aiCombat(u,dt,WD[u.w].alcance))return;
  if(u.lkp){
    if(Math.hypot(u.lkp.x-u.x,u.lkp.y-u.y)<1.5)u.lkp=null;
    else{if(!u.path){u.repT-=dt;if(u.repT<=0){u.repT=1.2;if(!pathTo(u,u.lkp.x,u.lkp.y))u.lkp=null;}}moveAlong(u,dt,u.spd*1.25);return;}
  }
  u.huntT-=dt;
  if(u.huntT<=0){u.huntT=2.5;const a=nearestAgent(u,u.kind==='inimigo'?999:18);if(a){const p=posOf(a);pathTo(u,p.x+(Math.random()-.5)*2,p.y+(Math.random()-.5)*2);}else if(u.home)pathTo(u,u.home.x,u.home.y);}
  moveAlong(u,dt,u.spd*1.1);
}
function updVip(u,dt){
  if(u.safe){u.path=null;return;}
  if(u.scripted&&!M.corpAlert&&!u.alerted){detect(u,dt,6,3);moveAlong(u,dt,u.spd);return;}
  if(!M.corpAlert&&!u.alerted){
    detect(u,dt,6,u.cand?1.3:3);
    if(!u.path){u.idleT-=dt;if(u.idleT<=0){u.ri=(u.ri+1)%u.route.length;const p=u.route[u.ri];pathTo(u,p.x,p.y);u.idleT=4+Math.random()*3;}}
    moveAlong(u,dt,u.spd);return;
  }
  if(!u.fleeing){u.fleeing=true;u.path=null;if(!u.double)log(u.fleeMsg||`${u.nome} está fugindo para o transporte de evacuação!`,'amber');if(!u.double){hooks.vo('vip:flee',u);hooks.vo('ctl:target');}}
  if(!u.path){u.repT-=dt;if(u.repT<=0){u.repT=1;pathTo(u,M.escape.x,M.escape.y);}}
  moveAlong(u,dt,u.spd*1.2);
  if(Math.hypot(u.x-M.escape.x,u.y-M.escape.y)<1.3&&!M.ended){if(u.double){u.dead=true;u.vanished=true;u.hp=0;}else if(u.safeRoom){u.safe=true;u.path=null;}else{M.flags.heliGo=true;endMission(false,`${u.nome} alcançou o transporte e escapou.`);}}
}
function updSci(u,dt){
  if(u.inCar){u.x=u.inCar.x;u.y=u.inCar.y;return;}
  if(u.hold){if(u.path)moveAlong(u,dt,u.spd);return;}
  if(!u.follow){const a=nearestAgent(u,1.9);if(a){u.follow=true;hooks.vo('sci:join',u);log(`${u.nome} se juntou ao esquadrão. Leve-a ao ponto de evacuação.`,'green');flags.hud=true;}return;}
  const a=nearestAgent(u,999);if(!a)return;
  const p=posOf(a),d=Math.hypot(p.x-u.x,p.y-u.y);
  if(a.inCar&&d<1.5&&!a.inCar.dead){u.inCar=a.inCar;a.inCar.occ.push(u);u.path=null;return;}
  if(d>1.5){u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.6;pathTo(u,p.x,p.y);}moveAlong(u,dt,u.spd);}else u.path=null;
}
function updTurret(u,dt){
  if(u.off)return;
  if(u.fac==='corp'&&!u.alerted){u.face+=dt*.7;detect(u,dt,6.5,4.5);if(M.corpAlert&&nearestAgent(u,8))u.alerted=true;return;}
  if(!aiCombat(u,dt,7))u.face+=dt*.4;
}

/* ---------- agentes do jogador ---------- */
export function neuroMods(u){
  if(u.colapso>0)return {spd:.5,acc:.5,rof:1.4,rng:.9,res:0};
  const n=u.nr;return {spd:.75+.75*n.r,rof:1.2-.5*n.r,acc:.75+.65*n.p,rng:1+.15*n.p,res:.3*n.c};
}
export function removeItem(u,i){u.inv.splice(i,1);if(u.eq===i)u.eq=-1;else if(u.eq>i)u.eq--;flags.hud=true;}
export function equipFirstWeapon(u){const i=u.inv.findIndex(it=>WD[it.t].arma);if(i>=0)u.eq=i;flags.hud=true;return i>=0;}
function updAgent(u,dt){
  const cx=u.ag.imp.cortex;
  // estabilidade neural
  const load=u.nr.r+u.nr.p+u.nr.c-1.5;
  if(!u.inCar){if(load>.4&&u.colapso<=0&&Math.random()<.22)part(u.x+(Math.random()-.5)*.35,u.y+(Math.random()-.5)*.35,12+Math.random()*14,0,0,22,.5,'#ffb040',1,1);if(u.colapso>0&&Math.random()<.12)part(u.x,u.y,30,(Math.random()-.5)*.3,(Math.random()-.5)*.3,10,1.2,'#5a5a66',1,2);}
  if(u.colapso>0){u.colapso-=dt;if(u.colapso<=0){u.nr={r:.25,p:.45,c:.85};flags.hud=true;}}
  else if(load>0){u.estab-=dt*load*10*(1-cx*.2)*(has('estab')?.7:1);u.over+=dt*load;if(u.estab<=0){u.estab=0;u.colapso=has('limpa')?3:6;log(`${u.nome} entrou em colapso neural.`,'red');hooks.vo('ag:crash',u);flags.hud=true;}}
  else u.estab=Math.min(u.maxEstab,u.estab+dt*(3-load*10)*(1+cx*.3));
  if(has('reparo')&&!u.dead&&u.hp<u.maxHp&&M.t-(u.lastHit??-99)>5)u.hp=Math.min(u.maxHp,u.hp+dt*2.5);
  const m=u.neuro=neuroMods(u);if(u.supp>0)m.acc*=.65;
  u.covT=(u.covT||0)-dt;
  if(u.covT<=0&&!u.inCar){
    u.covT=.3;const h=nearestHostile(u,9);u.covered=!!(h&&coverAt(u.x,u.y,posOf(h)));
    if(!u.ord||u.ord.k!=='move')for(const q of M.nades){if(!q.src||q.src.fac==='player'||Math.hypot(q.tx-u.x,q.ty-u.y)>2.6)continue;const ax=u.x-q.tx,ay=u.y-q.ty,l=Math.hypot(ax,ay)||1,p=randomNear(u.x+ax/l*3.2,u.y+ay/l*3.2,1.2);if(p){pathTo(u,p.x,p.y);u.ord={k:'move'};}break;}
  }
  if(u.inCar){u.x=u.inCar.x;u.y=u.inCar.y;return;}
  const it=u.eq>=0?u.inv[u.eq]:null,w=it?WD[it.t]:null;
  const spd=u.spd*m.spd*(w&&w.peso?.78:1);
  const range=w&&w.arma?w.alcance*u.rngMul*m.rng:0;
  const o=u.ord;
  if(o){
    if(o.k==='move'){if(!u.path)u.ord=null;}
    else if(o.k==='atk'){
      const t=o.t;
      if(t.dead||!w||!w.arma||t.fac==='player')u.ord=null;
      else{
        const tp=posOf(t),d=Math.hypot(tp.x-u.x,tp.y-u.y);
        o.engaged=d<=range&&los(u.x,u.y,tp.x,tp.y);
        if(o.engaged){u.path=null;fireWeapon(u,it.t,it,tp.x,tp.y,m.acc,m.rof,m.rng);aimAt(u,tp.x,tp.y);}
        else{o.rep=(o.rep||0)-dt;if(o.rep<=0||!u.path){o.rep=.7;pathTo(u,tp.x,tp.y);}}
      }
    }else if(o.k==='fire'){
      o.time-=dt;if(o.time<=0||!w||!w.arma)u.ord=null;else{aimAt(u,o.x,o.y);fireWeapon(u,it.t,it,o.x,o.y,m.acc,m.rof,m.rng);}
    }else if(o.k==='throw'){
      const gt=o.wt||'granada',d=Math.hypot(o.x-u.x,o.y-u.y),ii=u.inv.findIndex(q=>q.t===gt);
      if(ii<0)u.ord=null;
      else if(d<=WD.granada.alcance){
        u.path=null;aimAt(u,o.x,o.y);M.nades.push({sx:u.x,sy:u.y,tx:o.x,ty:o.y,t:0,T:.5+d*.07,src:u,wt:gt});hooks.vo('ag:grn',u);
        removeItem(u,ii);const nx=u.inv.findIndex(q=>q.t===gt);if(nx>=0)u.eq=nx;else if(!equipFirstWeapon(u))u.eq=-1;u.ord=null;
      }else if(!u.path)pathTo(u,o.x,o.y);
    }else if(o.k==='hack'){
      const t=o.t;
      if(t.dead||t.fac==='player'){u.ord=null;t.hackP=0;}
      else{
        const d=Math.hypot(t.x-u.x,t.y-u.y);
        if(d<=WD.chave.alcance&&los(u.x,u.y,t.x,t.y)){u.path=null;aimAt(u,t.x,t.y);o.p+=dt;t.hackP=o.p/2.2;
          if(o.p>=2.2){t.fac='player';t.alerted=false;t.tgt=null;t.lkp=null;t.hackP=0;log(t.kind==='drone'?'Drone invadido: agora ele protege o esquadrão.':'Torreta invadida: agora ela protege o esquadrão.','cyan');sfx('hack');u.ord=null;hooks.convert(t);}}
        else if(!u.path)pathTo(u,t.x,t.y);
      }
    }else if(o.k==='enter'){
      const c=o.c;
      if(c.dead){u.ord=null;}
      else{c.held=1;const d=Math.hypot(c.x-u.x,c.y-u.y);if(d<1.15)boardCar(u,c);else{o.rep=(o.rep||0)-dt;if(o.rep<=0||!u.path){o.rep=.6;pathTo(u,c.x,c.y);}}}
    }
  }
  if(w&&w.arma&&!(o&&(o.k==='fire'||(o.k==='atk'&&o.engaged)))){
    u.scanT-=dt;
    if(u.scanT<=0){u.scanT=.25;u.autoT=nearestHostile(u,range);}
    const t=u.autoT;
    if(t){if(t.dead||!isEnemyOf(u,t))u.autoT=null;else{const tp=posOf(t),d=Math.hypot(tp.x-u.x,tp.y-u.y);if(d<=range&&los(u.x,u.y,tp.x,tp.y)){aimAt(u,tp.x,tp.y);fireWeapon(u,it.t,it,tp.x,tp.y,m.acc,m.rof,m.rng);}}}
  }
  if(w&&w.sonda)hijackTick(u,dt,w);else u.probing=false;
  if(w&&w.manto){if(it.bat===undefined)it.bat=25;if(it.bat>0){it.bat-=dt;u.cloak=true;if(it.bat<=0){u.cloak=false;log(`O manto de ${u.nome} descarregou.`,'amber');flags.hud=true;}}else u.cloak=false;}else u.cloak=false;
  if(u.inCar)return;
  moveAlong(u,dt,spd);
  for(let i=M.drops.length-1;i>=0;i--){
    const d=M.drops[i];if(Math.hypot(d.x-u.x,d.y-u.y)>.7||u.inv.length>=MAXINV)continue;
    u.inv.push({t:d.t,mun:penteOf(u,d.t)});M.drops.splice(i,1);log(`${u.nome} pegou ${WD[d.t].ab}.`,'cyan');sfx('pickup');flags.hud=true;
  }
  for(const tm of M.terms){
    if(tm.done||Math.hypot(tm.x-u.x,tm.y-u.y)>1.4)continue;
    tm.prog+=dt;tm.touch=.2;
    if(tm.prog>=4){tm.done=true;if(tm.flag){M.flags[tm.flag]=true;if(tm.vo)hooks.vo(tm.vo);if(tm.msg)log(tm.msg,'cyan');sfx('hack');flags.hud=true;continue;}if(tm.crane){M.flags.crane=true;hooks.vo('ctl:m1_crane');log('Cabine do guindaste invadida. Tecla G solta o contêiner.','cyan');sfx('hack');flags.hud=true;continue;}hooks.vo('ctl:term');log(`Terminal invadido (${M.terms.filter(q=>q.done).length}/${M.terms.length}).`,'cyan');sfx('hack');noise(tm.x,tm.y,9,u);flags.hud=true;}
  }
}

/* ---------- veículos ---------- */
export function boardCar(u,c){
  if(u.inCar||c.dead)return;
  u.inCar=c;c.occ.push(u);c.player=true;c.path=null;c.cur=0;u.path=null;u.ord=null;
  sfx('door',c.x,c.y);flags.hud=true;
  if(c.occ.filter(o=>o.kind==='agente').length===1)hooks.vo('ag:car',u);
  if(c.occ.filter(o=>o.kind==='agente').length===1)log('Agente no veículo. Clique no mapa para dirigir · V para sair.','cyan');
}
function spotNear(x,y,k){for(let r=.8;r<3.5;r+=.4)for(let a=k*1.3;a<k*1.3+TAU;a+=.5){const px=x+Math.cos(a)*r,py=y+Math.sin(a)*r;if(canStand(px,py))return {x:px,y:py};}return {x,y};}
export function exitCar(c){
  const occ=c.occ.slice();c.occ=[];
  occ.forEach((u,k)=>{const s=spotNear(c.x,c.y,k);u.x=s.x;u.y=s.y;u.inCar=null;u.path=null;});
  c.path=null;c.cur=0;if(occ.length){sfx('door',c.x,c.y);flags.hud=true;}
}
function driveCar(c,dt){
  if(!c.path)c.cur=Math.max(0,c.cur-10*dt);
  else{
    const p=c.path[c.pi],dx=p.x-c.x,dy=p.y-c.y,dd=Math.hypot(dx,dy);
    if(dd<.55){c.pi++;if(c.pi>=c.path.length)c.path=null;}
    else{
      const ta=Math.atan2(dy,dx);let da=ta-c.ang;while(da>Math.PI)da-=TAU;while(da<-Math.PI)da+=TAU;
      c.ang+=clamp(da,-6*dt,6*dt);
      const last=c.pi>=c.path.length-1,target=Math.abs(da)>.9?2.2:(last&&dd<2.5?3:7.5);
      c.cur+=clamp(target-c.cur,-14*dt,5*dt);
    }
  }
  const ndx=Math.cos(c.ang),ndy=Math.sin(c.ang),nx=c.x+ndx*c.cur*dt,ny=c.y+ndy*c.cur*dt;
  if(walkAt(nx+ndx*.7,ny+ndy*.7)||walkAt(nx,ny,M.road)){c.x=clamp(nx,.4,N-.4);c.y=clamp(ny,.4,N-.4);}
  else if(c.path){const p=c.path[c.pi];c.ang=Math.atan2(p.y-c.y,p.x-c.x);c.cur=1;}
  else c.cur=0;
  c.dx=ndx;c.dy=ndy;if(c.cur>.5&&Math.random()<.05)part(c.x-ndx*.85,c.y-ndy*.85,6,-ndx*.5,-ndy*.5,6,1.1,'#4a4a52',1,2);
  if(c.scripted&&c.cur>.5)for(const u of M.units){if(u.dead||u.inCar||u.mech)continue;const rx=u.x-c.x,ry=u.y-c.y,f=rx*ndx+ry*ndy,l=rx*ndy-ry*ndx;if(Math.abs(f)<1&&Math.abs(l)<.55){const s=l>=0?1:-1,px=u.x+ndy*s*.12,py=u.y-ndx*s*.12;if(canStand(px,py)){u.x=px;u.y=py;}}}
  if(c.player&&c.cur>2.5){
    const drv=c.occ.find(o=>o.kind==='agente');
    for(const u of M.units){
      if(u.dead||u.inCar||u.mech||u.runT>0||(u.fac==='player'&&!u.follower&&u.kind==='agente'))continue;
      if(Math.hypot(u.x-c.x,u.y-c.y)<.6){u.runT=1;hurt(u,55,drv||null);const s=spotNear(u.x+ndy*.6,u.y-ndx*.6,0);u.x=s.x;u.y=s.y;}
    }
  }
}
function updCars(dt){
  for(const c of M.cars){
    if(c.hitT>0)c.hitT-=dt;
    if(c.dead){c.smokeT-=dt;if(c.smokeT<=0){c.smokeT=.15;part(c.x,c.y,16,(Math.random()-.5)*.3,(Math.random()-.5)*.3,18,2,'#1e1e24',1,2);if(Math.random()<.4)part(c.x,c.y,12,0,0,8,.4,'#ff7828',1,1);}continue;}
    if(c.player||c.scripted){driveCar(c,dt);continue;}
    if(c.held>0){c.held-=dt;c.cur=Math.max(0,c.cur-14*dt);continue;}
    let blocked=false;
    for(const u of M.units){if(u.dead||u.inCar||u.mech)continue;const rx=u.x-c.x,ry=u.y-c.y,f=rx*c.dx+ry*c.dy,l=Math.abs(rx*c.dy-ry*c.dx);if(f>.3&&f<1.8&&l<.6){blocked=true;break;}}
    if(!blocked)for(const o of M.cars){if(o===c)continue;const rx=o.x-c.x,ry=o.y-c.y,f=rx*c.dx+ry*c.dy,l=Math.abs(rx*c.dy-ry*c.dx);if(f>.3&&f<2.1&&l<.75){blocked=true;break;}}
    if(blocked&&c.stopT<3.5){c.stopT+=dt;c.cur=Math.max(0,c.cur-14*dt);if(c.stopT>1.6&&!c.honked){c.honked=true;sfx('honk',c.x,c.y);}}
    else{if(!blocked){c.stopT=0;c.honked=false;}c.cur=Math.min(c.v,c.cur+4*dt);}
    c.x+=c.dx*c.cur*dt;c.y+=c.dy*c.cur*dt;if(c.cur>.5&&Math.random()<.035)part(c.x-c.dx*.85,c.y-c.dy*.85,6,-c.dx*.4,-c.dy*.4,6,1.1,'#4a4a52',1,2);
    if(c.x<-2)c.x=N+2;if(c.x>N+2)c.x=-2;if(c.y<-2)c.y=N+2;if(c.y>N+2)c.y=-2;
    if(c.cur>.5)for(const u of M.units){if(u.dead||u.inCar||u.mech)continue;const rx=u.x-c.x,ry=u.y-c.y,f=rx*c.dx+ry*c.dy,l=rx*c.dy-ry*c.dx;if(Math.abs(f)<.8&&Math.abs(l)<.5){const s=l>=0?1:-1,px=u.x+c.dy*s*.08,py=u.y-c.dx*s*.08;if(canStand(px,py)){u.x=px;u.y=py;}}}
  }
}
function updNades(dt){for(let i=M.nades.length-1;i>=0;i--){const q=M.nades[i];q.t+=dt;if(q.t>=q.T){M.nades.splice(i,1);const W=WD[q.wt||'granada'];explode(q.tx,q.ty,W.raio,W.dano,q.src);if(W.incend)for(let k=0;k<8;k++){const a=k/8*TAU,r=k%2?1.5:.8;addFire(q.tx+Math.cos(a)*r,q.ty+Math.sin(a)*r,10+Math.random()*4);}}}}
function updFx(dt){
  for(let i=M.parts.length-1;i>=0;i--){const p=M.parts[i];p.life-=dt;if(p.life<=0){M.parts[i]=M.parts[M.parts.length-1];M.parts.pop();continue;}
    p.x+=p.vx*dt;p.y+=p.vy*dt;p.z+=p.vz*dt;
    if(p.type===3){p.vz-=160*dt;if(p.z<0){p.z=0;p.vz*=-.3;p.vx*=.6;p.vy*=.6;}}
    else if(p.type===2)p.vz*=.98;
    else{p.vx*=.92;p.vy*=.92;if(p.type===0){p.vz-=60*dt;if(p.z<0){p.z=0;p.vz=0;}}}
  }
  for(const arr of [M.tracers,M.flashes,M.texts,M.marks,M.vfx||[]])for(let i=arr.length-1;i>=0;i--){arr[i].life-=dt;if(arr[i].life<=0)arr.splice(i,1);}
  for(const t of M.texts)if(t.u&&!t.u.dead){t.x=t.u.x;t.y=t.u.y;}
  M.shake=Math.max(0,M.shake-dt*2);
}
function separate(){
  const U=M.units;
  for(let i=0;i<U.length;i++){const a=U[i];if(a.dead||a.inCar||a.mech||a.hold)continue;
    for(let j=i+1;j<U.length;j++){const b=U[j];if(b.dead||b.inCar||b.mech||b.hold)continue;
      const dx=b.x-a.x,dy=b.y-a.y;if(Math.abs(dx)>.42||Math.abs(dy)>.42)continue;
      const d2=dx*dx+dy*dy;if(d2>=.1764||d2<1e-6)continue;
      const d=Math.sqrt(d2),push=(.42-d)*.5,nx=dx/d*push,ny=dy/d*push;
      if(canStand(a.x-nx,a.y-ny)){a.x-=nx;a.y-=ny;}if(canStand(b.x+nx,b.y+ny)){b.x+=nx;b.y+=ny;}
    }}
}

/* ---------- laço da simulação ---------- */
export function updateWorld(dt){
  M.t+=dt;
  for(const u of M.units){
    if(u.dead){u.deathT+=dt;continue;}
    if(u.cool>0)u.cool-=dt;if(u.supp>0)u.supp-=dt;if(u.suppP>0)u.suppP-=dt*.8;
    if(u.rel>0){u.rel-=dt;if(u.rel<=0&&u.relSt){u.relSt.mun=penteOf(u,u.relW);u.relSt=null;}}
    if(u.flash>0)u.flash-=dt;if(u.hitT>0)u.hitT-=dt;if(u.aimT>0)u.aimT-=dt;if(u.barT>0)u.barT-=dt;if(u.runT>0)u.runT-=dt;
    if(u.burn>0){u.burn-=dt;if(Math.random()<.5)part(u.x,u.y,8+Math.random()*20,(Math.random()-.5)*.4,(Math.random()-.5)*.4,20,.35,'#ff8228',1,1);hurt(u,9*dt,u.burnSrc);if(u.dead)continue;if(u.kind==='civil'&&!u.follower)u.panicT=3;}
    if(u.inCar&&u.kind!=='agente'){u.x=u.inCar.x;u.y=u.inCar.y;continue;}
    if(u.hjT>0){u.hjT-=dt;u.path=null;continue;}
    if(u.hj>0)u.hj=Math.max(0,u.hj-dt*.3);
    if(u.follower){updFollower(u,dt);continue;}
    if(u.disguise){updDisguise(u,dt);continue;}
    switch(u.kind){
      case 'agente':updAgent(u,dt);break;
      case 'civil':updCiv(u,dt);break;
      case 'policia':updPolice(u,dt);break;
      case 'guarda':case 'inimigo':updGuard(u,dt);break;
      case 'vip':updVip(u,dt);break;
      case 'cientista':updSci(u,dt);break;
      case 'torre':updTurret(u,dt);break;
      case 'drone':updDrone(u,dt);break;
    }
  }
  separate();updCars(dt);updNades(dt);updFx(dt);if(M.falling)updFalling(dt);updDestruct(dt);if(M.cams&&M.cams.length)updCams(dt);updTrain(dt);if(M.vents&&M.vents.length)updVents(dt);if(M.glassQ&&M.glassQ.length)updGlass();if(M.decor&&M.decor.length)updDecorFx(dt);if(M.lasers&&M.lasers.length)updLasers(dt);
  if(M.policeAggro>0){
    M.policeAggro-=dt;
    if(M.policeAggro<=0){M.policeAggro=0;log('A polícia recuou.','cyan');}
    else{M.reinfT-=dt;if(M.reinfT<=0&&!M.demo){M.reinfT=has('trafego')?35:20;spawnReinforcements();}}
  }
}
function spawnReinforcements(){
  const alive=M.units.filter(u=>u.kind==='policia'&&!u.dead&&!u.follower).length;if(alive>=14)return;
  const e=pick([[1,(Math.random()*N)|0],[N-2,(Math.random()*N)|0],[(Math.random()*N)|0,1],[(Math.random()*N)|0,N-2]]);
  for(let k=0;k<2;k++){const p=randomNear(e[0],e[1],2);if(!p)continue;const u=mkUnit('policia',p.x,p.y);u.spd=1.9;if(!k)hooks.vo('pol:reinf',u);}
  log('Reforços policiais chegaram ao distrito.','amber');
}
export function update(dt){
  updateWorld(dt);
  if(!M.ended)checkEnd();
  else{M.endT+=dt;if(M.endT>2.4&&!M.shown){M.shown=true;hooks.end();}}
}
function checkEnd(){
  if(!M.agents.some(a=>!a.dead))return endMission(false,'Todo o esquadrão foi abatido.');
  if(M.hand)return;
  switch(M.tipo){
    case 'assassinato':if(M.vip.dead)endMission(true,`${M.vip.nome} foi eliminado.`);break;
    case 'extracao':if(M.sci.dead)endMission(false,`${M.sci.nome} morreu durante a operação.`);else if(M.sci.follow&&Math.hypot(M.sci.x-M.evac.x,M.sci.y-M.evac.y)<2.3)endMission(true,`${M.sci.nome} foi extraída com sucesso.`);break;
    case 'sabotagem':if(M.terms.every(t=>t.done))endMission(true,'A rede de vigilância do distrito caiu.');break;
    case 'eliminacao':if(M.units.every(u=>u.kind!=='inimigo'||u.dead||u.follower))endMission(true,'A célula de agentes do Consórcio foi eliminada.');break;
  }
}
export function endMission(win,reason){
  if(M.ended)return;M.ended=true;M.win=win;M.reason=reason;M.endT=0;
  hooks.log(win?'OBJETIVO CUMPRIDO':'MISSÃO FRACASSADA',win?'green':'red');hooks.vo(win?'ctl:win':'ctl:fail');M.banner=win?'OBJETIVO CUMPRIDO':'MISSÃO FRACASSADA';
  sfx(win?'win':'lose');
}


/* ---------- destruição de cenário ---------- */
const DIRT=['#5a5f6a','#3a3f4a','#6b6f78','#4a4238'];
export function rayWall(x0,y0,dx,dy,maxT){
  let tx=Math.floor(x0),ty=Math.floor(y0);
  const sx=dx>0?1:-1,sy=dy>0?1:-1,tdx=dx?Math.abs(1/dx):Infinity,tdy=dy?Math.abs(1/dy):Infinity;
  let tmx=dx>0?(tx+1-x0)/dx:dx<0?(x0-tx)/-dx:Infinity,tmy=dy>0?(ty+1-y0)/dy:dy<0?(y0-ty)/-dy:Infinity,t=0,nx=0,ny=0;
  for(let k=0;k<64;k++){
    if(tmx<tmy){tx+=sx;t=tmx;tmx+=tdx;nx=-sx;ny=0;}else{ty+=sy;t=tmy;tmy+=tdy;nx=0;ny=-sy;}
    if(t>maxT)return null;
    if(tx<0||ty<0||tx>=N||ty>=N)return {t,tx,ty,nx,ny,out:true};
    if(M.tile[ty*N+tx]===T_BLD)return {t,tx,ty,nx,ny};
  }
  return null;
}
const addDecal=d=>{M.wallDecals.push(d);};
function wallHit(h,ex,ey,z,src,dmg){
  const bi=M.bldAt[h.ty*N+h.tx],b=bi>=0?M.blds[bi]:null;
  for(let k=0;k<3;k++)part(ex,ey,z*30,h.nx*2+(Math.random()-.5)*2,h.ny*2+(Math.random()-.5)*2,10+Math.random()*20,.3,'#ffd28c',1,3);
  part(ex+h.nx*.05,ey+h.ny*.05,z*30,h.nx*.7,h.ny*.7,4,.55,'#8a8a90',1,2);
  if(!b){if(Math.random()<.25)sfx('ric',ex,ey);return;}
  if(b.style==='cont'||b.style==='ware'){damageBld(b,dmg*.35,src);if(Math.random()<.3)sfx('ric',ex,ey);addDecal({kind:'hole',x:ex,y:ey,z,nx:h.nx,ny:h.ny,w:.08,h:.08});return;}
  const along=h.nx!==0?ey-h.ty:ex-h.tx,fl=Math.floor(z/FLOOR),vz=(z-fl*FLOOR)/FLOOR,col=along<.5?0:1;
  const inWin=!b.kiosk&&!b.favela&&fl<b.fl&&vz>.28&&vz<.75&&((along>.12&&along<.44)||(along>.56&&along<.88));
  if(!(inWin&&breakWindow(b,h.tx,h.ty,h.nx,h.ny,fl,col)))addDecal({kind:'hole',x:ex,y:ey,z,nx:h.nx,ny:h.ny,w:.07,h:.07});
  if(b.fl<=2&&!b.corp)damageBld(b,dmg*.25,src);
}
function breakWindow(b,tx,ty,nx,ny,fl,col){
  const key=tx+','+ty+','+nx+','+ny+','+fl+','+col;if(M.glass.has(key))return false;M.glass.add(key);
  const c=col?.72:.28,fx=nx!==0?tx+(nx>0?1:0):tx+c,fy=nx!==0?ty+c:ty+(ny>0?1:0),z=fl*FLOOR+FLOOR*.515;
  addDecal({kind:'glass',x:fx,y:fy,z,nx,ny,w:.33,h:.25});
  for(let k=0;k<7;k++)part(fx+nx*.08,fy+ny*.08,z*30,nx*(.5+Math.random()*1.5)+(Math.random()-.5),ny*(.5+Math.random()*1.5)+(Math.random()-.5),Math.random()*15,1.4,'#bfe8ff',1,3);
  sfx('glass',fx,fy);
  return true;
}
function damageBld(b,dmg,src){
  if(b.dead||!(b.style==='cont'||(b.fl<=2&&!b.corp&&!b.style)))return;
  if(b.hp===undefined)b.hp=b.style==='cont'?80*b.fl:150;
  b.hp-=dmg;if(b.hp<=0)destroyBld(b,src);
}
export function destroyBld(b,src){
  b.dead=true;
  for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++){const i=y*N+x;M.tile[i]=T_PLAZA;M.walk[i]=1;M.hgt[i]=0;M.bldAt[i]=-1;}
  const cx=b.x+b.w/2,cy=b.y+b.d/2,cont=b.style==='cont';
  spawnDebris(cx,cy,.3+b.fl*.25,8+b.w*b.d*3,cont?['#8a2e22','#1f4e7a','#6b6f78','#2f6b3e','#b8681e']:DIRT,4,[.1,.35],b.w,b.d);
  for(let i=0;i<22;i++){const a=Math.random()*TAU,s=Math.random()*1.5;part(cx+(Math.random()-.5)*b.w,cy+(Math.random()-.5)*b.d,10,Math.cos(a)*s,Math.sin(a)*s,15+Math.random()*25,2+Math.random()*1.5,'#4a4740',1,2);}
  sfx(cont?'crash':'collapse',cx,cy);if(!REDUCED)M.shake=Math.min(1,M.shake+.5);
  hooks.destroy('bld',b);noise(cx,cy,12,src);
}
export function spawnDebris(x,y,z,n,cols,spd,sz,w=0,d=0){
  for(let i=0;i<n;i++){const a=Math.random()*TAU,s=spd*(.3+Math.random()*.7);M.debris.push({x:x+(Math.random()-.5)*w,y:y+(Math.random()-.5)*d,z,vx:Math.cos(a)*s,vy:Math.sin(a)*s,vz:2+Math.random()*spd,rx:Math.random()*3,ry:Math.random()*3,rz:0,vr:(Math.random()-.5)*12,s:sz[0]+Math.random()*(sz[1]-sz[0]),col:pick(cols),life:20+Math.random()*12});}
  if(M.debris.length>420)M.debris.splice(0,M.debris.length-420);
}
function breakLamp(l){
  if(l.dead)return;l.dead=true;
  for(let k=0;k<10;k++)part(l.x+.3,l.y,(l.tall?3.9:2.2)*30,(Math.random()-.5)*2,(Math.random()-.5)*2,Math.random()*20,.9,'#fff0b0',1,3);
  sfx('glass',l.x,l.y);hooks.destroy('lamp',l);
}
function litAt(x,y){for(const l of M.lamps){if(l.dead)continue;const r=l.tall?5:3.2;if(Math.abs(l.x-x)<r&&Math.abs(l.y-y)<r&&Math.hypot(l.x-x,l.y-y)<r)return true;}return false;}
export function addFire(x,y,life){
  if(x<0||y<0||x>=N||y>=N)return;const t=M.tile[(y|0)*N+(x|0)];
  if(t===T_WATER||t===T_BLD||M.fires.length>40)return;M.fires.push({x,y,life,max:life,tick:0});
}
function burnTree(tr){
  if(tr.dead)return;tr.dead=true;const i=(tr.y|0)*N+(tr.x|0);
  if(M.tile[i]===T_TREE){M.tile[i]=T_GRASS;M.walk[i]=1;}
  hooks.destroy('tree',tr);addFire(tr.x,tr.y,9);
  spawnDebris(tr.x,tr.y,.8,5,['#24452f','#3a2a1e','#1a1a1a'],2.5,[.08,.22]);
}
function blast(x,y,r,dmg,src){
  const R=r+.6,x0=Math.max(0,Math.floor(x-R)),x1=Math.min(N-1,Math.floor(x+R)),y0=Math.max(0,Math.floor(y-R)),y1=Math.min(N-1,Math.floor(y+R));
  const hitB=new Set();
  for(let ty=y0;ty<=y1;ty++)for(let tx=x0;tx<=x1;tx++){
    const i=ty*N+tx,t=M.tile[i];if(Math.hypot(tx+.5-x,ty+.5-y)>R)continue;
    if(t===T_GLASS)shatterGlass(tx,ty);
    else if(t===T_FENCE){M.tile[i]=T_WALK;M.walk[i]=1;hooks.destroy('fence',{x:tx,y:ty});spawnDebris(tx+.5,ty+.5,.5,4,['#8a92a4','#5a6070'],3,[.05,.18]);}
    else if(t===T_TREE){const tr=M.trees.find(q=>!q.dead&&(q.x|0)===tx&&(q.y|0)===ty);if(tr)burnTree(tr);else{M.tile[i]=T_GRASS;M.walk[i]=1;}}
    else if(t===T_BLD){
      const bi=M.bldAt[i],b=bi>=0?M.blds[bi]:null;if(b)hitB.add(b);
      for(const [nx,ny] of [[1,0],[-1,0],[0,1],[0,-1]]){
        const ax=tx+nx,ay=ty+ny;if(ax<0||ay<0||ax>=N||ay>=N||M.tile[ay*N+ax]===T_BLD)continue;
        const fx=tx+.5+nx*.5,fy=ty+.5+ny*.5;if((x-fx)*nx+(y-fy)*ny<=0)continue;
        const fd=Math.hypot(x-fx,y-fy);if(fd>R)continue;
        if(b&&!b.style&&!b.kiosk)for(let fl=0;fl<Math.min(2,b.fl);fl++)for(let c=0;c<2;c++)if(Math.random()<1.2-fd/R)breakWindow(b,tx,ty,nx,ny,fl,c);
        addDecal({kind:'scorch',x:fx,y:fy,z:.5,nx,ny,w:1.15,h:1});
      }
    }
  }
  for(const b of hitB)damageBld(b,dmg*2.2,src);
  for(const l of M.lamps)if(!l.dead&&Math.hypot(l.x-x,l.y-y)<R)breakLamp(l);
  if(Math.random()<.8)addFire(x+(Math.random()-.5),y+(Math.random()-.5),6+Math.random()*4);
  spawnDebris(x,y,.2,8,DIRT,4,[.05,.16]);
}
function updDestruct(dt){
  for(let i=M.debris.length-1;i>=0;i--){
    const d=M.debris[i];d.life-=dt;if(d.life<=0){M.debris.splice(i,1);continue;}
    if(d.vz!==0||d.z>d.s*.3+.001){
      d.vz-=12*dt;d.x+=d.vx*dt;d.y+=d.vy*dt;d.z+=d.vz*dt;d.rx+=d.vr*dt;d.rz+=d.vr*.5*dt;
      if(d.z<d.s*.3){d.z=d.s*.3;if(Math.abs(d.vz)<1.2){d.vz=d.vx=d.vy=d.vr=0;d.rx=Math.round(d.rx/(Math.PI/2))*Math.PI/2;d.rz=0;}else{d.vz*=-.35;d.vx*=.55;d.vy*=.55;d.vr*=.5;}}
    }
  }
  for(let i=M.fires.length-1;i>=0;i--){
    const f=M.fires[i];f.life-=dt;if(f.life<=0){M.fires.splice(i,1);continue;}
    const k=Math.min(1,f.life/2);
    if(Math.random()<.65*k)part(f.x+(Math.random()-.5)*.6,f.y+(Math.random()-.5)*.6,2,(Math.random()-.5)*.3,(Math.random()-.5)*.3,25+Math.random()*25,.5+Math.random()*.4,Math.random()<.5?'#ff8c28':'#ffcf50',1,1);
    if(Math.random()<.15*k)part(f.x,f.y,20,(Math.random()-.5)*.3,(Math.random()-.5)*.3,25,2,'#26262c',1,2);
    f.tick-=dt;
    if(f.tick<=0){
      f.tick=.3;
      for(const u of M.units)if(!u.dead&&!u.inCar&&!u.mech&&Math.abs(u.x-f.x)<.6&&Math.abs(u.y-f.y)<.6)u.burn=Math.max(u.burn,1.5);
      for(const tr of M.trees)if(!tr.dead&&Math.abs(tr.x-f.x)<1.2&&Math.abs(tr.y-f.y)<1.2&&Math.random()<.07)burnTree(tr);
      for(const p of M.props)if(!p.dead&&Math.abs(p.x-f.x)<.7&&Math.abs(p.y-f.y)<.7&&Math.random()<.15)hurtProp(p,999,null);
    }
  }
}


/* ---------- drones de segurança ---------- */
function flyTo(u,x,y,dt,spd){
  const dx=x-u.x,dy=y-u.y,d=Math.hypot(dx,dy);if(d<.2){u.curSpd=0;return true;}
  const s=Math.min(d,spd*dt);u.x=clamp(u.x+dx/d*s,1,N-1);u.y=clamp(u.y+dy/d*s,1,N-1);u.curSpd=spd;
  if(!(u.aimT>0))u.face=Math.atan2(dy,dx);
  return false;
}
function orbit(u,p,R,dt){
  const dir=u.id%2?1:-1,a=Math.atan2(u.y-p.y,u.x-p.x)+.45*dir;
  for(const r of [R,R*.7,R*.45]){const tx=p.x+Math.cos(a)*r,ty=p.y+Math.sin(a)*r;if(canStand(tx,ty)){flyTo(u,tx,ty,dt,u.spd);return;}}
  flyTo(u,p.x,p.y,dt,u.spd*.5);
}
function updDrone(u,dt){
  u.path=null;
  u.sndT=(u.sndT??Math.random()*2)-dt;if(u.sndT<=0){u.sndT=2.2+Math.random()*.8;sfx('drone',u.x,u.y);}
  if(u.fac==='player'){
    const t=nearestHostile(u,7.5);if(t){const p=posOf(t);aimAt(u,p.x,p.y);fireWeapon(u,u.w,u,p.x,p.y);}
    const a=nearestAgent(u,999);
    if(a){const p=posOf(a);if(Math.hypot(p.x-u.x,p.y-u.y)>2.4)flyTo(u,p.x+Math.cos(u.id)*1.3,p.y+Math.sin(u.id)*1.3,dt,u.spd*1.2);else u.curSpd=0;}
    return;
  }
  if(!u.alerted){
    detect(u,dt,7.5,4.2);
    if(!u.alerted&&M.corpAlert&&nearestAgent(u,14))u.alerted=true;
    if(!u.alerted){
      const r=u.route;
      if(r&&r.length){const p=r[u.ri%r.length];if(flyTo(u,p.x,p.y,dt,u.spd*.55))u.ri++;}
      else{u.face+=dt*.8;u.curSpd=0;}
      return;
    }
  }
  let t=u.tgt;
  if(t&&(t.dead||!isEnemyOf(u,t)||(t.cloak&&Math.hypot(t.x-u.x,t.y-u.y)>1.5)))t=u.tgt=null;
  u.scanT-=dt;if(u.scanT<=0){u.scanT=.35;const nt=nearestHostile(u,9.5);if(nt)t=u.tgt=nt;}
  if(t){
    const p=posOf(t),d=Math.hypot(p.x-u.x,p.y-u.y);u.lkp={x:p.x,y:p.y};orbit(u,p,4.6,dt);
    if(d<8.5&&los(u.x,u.y,p.x,p.y)){aimAt(u,p.x,p.y);fireWeapon(u,u.w,u,p.x,p.y,u.supp>0?.6:1);}
    return;
  }
  let g=u.lkp;if(!g){const a=nearestAgent(u,22);if(a)g=posOf(a);}
  if(g){if(flyTo(u,g.x,g.y,dt,u.spd))u.lkp=null;}else u.curSpd=0;
}
/* ---------- saídas de vapor ---------- */
function updVents(dt){
  const over=(M.ventOver||0)>M.t;
  for(const v of M.vents){
    if(v.off){v.state=0;continue;}
    const ph=over?v.per:(M.t+v.ph)%v.per,b0=v.per-v.dur,warn=!over&&ph>b0-1.2&&ph<b0,burst=over||ph>=b0;
    v.state=burst?2:warn?1:0;
    if(warn&&Math.random()<.35)part(v.x+(Math.random()-.5)*.4,v.y+(Math.random()-.5)*.4,3,0,0,12,.6,'#b8c0c8',1,2);
    if(warn||burst){v.avT=(v.avT||0)-dt;if(v.avT<=0){v.avT=.3;for(const u of M.units){if(u.dead||u.inCar||u.mech||u.fac==='player'||u.alerted||u.panicT>0||u.fleeTo)continue;const dx=u.x-v.x,dy=u.y-v.y,l=Math.hypot(dx,dy);if(l>v.r+.7)continue;const p=randomNear(v.x+dx/(l||1)*2.6,v.y+dy/(l||1)*2.6,1.2);if(p){pathTo(u,p.x,p.y);u.idleT=2;}}}}
    if(!burst){v.was=false;continue;}
    if(!v.was){v.was=true;sfx('steam',v.x,v.y);}
    for(let k=0;k<3;k++)part(v.x+(Math.random()-.5)*.5,v.y+(Math.random()-.5)*.5,4,(Math.random()-.5)*.9,(Math.random()-.5)*.9,55+Math.random()*50,.9+Math.random()*.6,'#e8eef4',1,2);
    v.tick=(v.tick||0)-dt;
    if(v.tick<=0){v.tick=.25;for(const u of M.units)if(!u.dead&&!u.inCar&&!u.mech&&Math.hypot(u.x-v.x,u.y-v.y)<v.r){hurt(u,v.dmg*.25,over?M.ventSrc:null);if(u.kind==='civil'&&!u.follower)u.panicT=3;}}
  }
}
/* ---------- paredes de vidro ---------- */
function shatterGlass(tx,ty){
  const i=ty*N+tx;if(M.tile[i]!==T_GLASS)return;
  M.tile[i]=T_PLAZA;M.walk[i]=1;M.glassN--;
  for(let k=0;k<14;k++)part(tx+.5+(Math.random()-.5)*.8,ty+.5+(Math.random()-.5)*.8,10+Math.random()*35,(Math.random()-.5)*3,(Math.random()-.5)*3,Math.random()*20,1.6,'#bfe8ff',1,3);
  sfx('glass',tx+.5,ty+.5);hooks.destroy('glasswall',{x:tx,y:ty});hooks.decal('shards',tx+.5,ty+.5,.6);
  for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const x=tx+dx,y=ty+dy;if(x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_GLASS&&Math.random()<.35)(M.glassQ||(M.glassQ=[])).push({x,y,t:M.t+.08+Math.random()*.15});}
  noise(tx+.5,ty+.5,5,null);
}
function updGlass(){const q=M.glassQ;M.glassQ=[];for(const g of q){if(M.t>=g.t)shatterGlass(g.x,g.y);else M.glassQ.push(g);}}
function updDecorFx(dt){
  for(const d of M.decor){
    if(d.type==='chimney'&&!d.dead){if(Math.random()<dt*5)part(d.x+(Math.random()-.5)*.3,d.y+(Math.random()-.5)*.3,(d.h||7)*30,.4,.15,8+Math.random()*6,3+Math.random()*2,'#3a3a40',1,2);}
    else if(d.type==='fountain'&&!M.flags.fountainOff){if(Math.random()<dt*30)part(d.x+(Math.random()-.5)*.2,d.y+(Math.random()-.5)*.2,32,(Math.random()-.5)*1.4,(Math.random()-.5)*1.4,40+Math.random()*30,.9,'#bfe8ff',1,3);}
  }
}

/* ---------- feixes de alarme ---------- */
function updLasers(dt){
  for(const l of M.lasers){
    l.on=!l.off&&(!l.per||((M.t+l.ph)%l.per)<l.per*l.duty);
    if(l.tripT>0)l.tripT-=dt;
    if(!l.on)continue;
    if(l.sweep){const s=l.sweep,L=s.b-s.a,ph=(M.t*s.spd)%(2*L),p=s.a+(ph<L?ph:2*L-ph);if(s.ax==='y')l.y1=l.y2=p;else l.x1=l.x2=p;}
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
    const dx=l.x2-l.x1,dy=l.y2-l.y1,L2=dx*dx+dy*dy||1;
    for(const a of M.agents){
      if(a.dead||a.inCar||a.cloak)continue;
      const t=clamp(((a.x-l.x1)*dx+(a.y-l.y1)*dy)/L2,0,1),px=l.x1+dx*t-a.x,py=l.y1+dy*t-a.y;
      if(px*px+py*py>.09)continue;
      l.tripT=1.2;
      if(!l.tripped){l.tripped=true;log('Um feixe de alarme foi cortado!','red');sfx('alarm');}
      if(!M.corpAlert){let best=null,bd=1e9;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise&&!u.cand){const d=Math.hypot(u.x-a.x,u.y-a.y);if(d<bd){bd=d;best=u;}}if(best){hooks.vo('ctl:laser');alertCorp(best,a.x,a.y);}}
      break;
    }
  }
}

/* ---------- câmeras de segurança ---------- */
function updCams(dt){
  for(const c of M.cams){
    if(c.dead||c.off)continue;
    c.a=c.base+Math.sin(M.t*c.spd+c.ph)*c.sweep;
    c.chk=(c.chk||0)-dt;if(c.chk>0)continue;c.chk=.2;
    let seen=null;
    for(const a of M.agents){
      if(a.dead||a.inCar||a.cloak)continue;if(!c.strict&&!isArmed(a))continue;
      const dx=a.x-c.x,dy=a.y-c.y,d=Math.hypot(dx,dy);if(d>c.range)continue;
      let da=Math.abs(Math.atan2(dy,dx)-c.a);if(da>Math.PI)da=TAU-da;if(da>c.fov)continue;
      if(los(c.x,c.y,a.x,a.y)){seen=a;break;}
    }
    if(seen){c.see+=.2;if(c.see>=.8&&!c.fired){c.fired=true;camAlarm(c,seen);}}else c.see=Math.max(0,c.see-.1);
  }
}
function camAlarm(c,a){
  log('Uma câmera de segurança viu o esquadrão!','red');hooks.vo('ctl:m3_camspot');
  let best=null,bd=1e9;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise){const d=Math.hypot(u.x-c.x,u.y-c.y);if(d<bd){bd=d;best=u;}}
  if(best)alertCorp(best,a.x,a.y);
  for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.alerted&&Math.hypot(u.x-c.x,u.y-c.y)<14){u.alerted=true;u.lkp={x:a.x,y:a.y};}
}
function hurtCam(c){if(c.dead)return;c.dead=true;for(let k=0;k<10;k++)part(c.x,c.y,75,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*30,.6,'#ffdc96',1,3);sfx('glass',c.x,c.y);}
/* ---------- monotrilho ---------- */
function updTrain(dt){
  if(!M.rail)return;
  if(!M.train){M.trainT-=dt;if(M.trainT<=0){M.train={x:-14,dir:1};M.trainT=40;}}
  else{
    M.train.x+=M.train.dir*11*dt;M.train.snd=(M.train.snd||0)-dt;
    if(M.train.snd<=0){M.train.snd=1.2;sfx('train',clamp(M.train.x,0,N),M.rail.y);}
    if(M.train.x>N+16)M.train=null;
  }
  M.flags.trainNoise=!!(M.train&&M.train.x>-6&&M.train.x<N+6);
}
/* ---------- agentes disfarçados ---------- */
function reveal(u){
  if(!u.disguise)return;u.disguise=false;u.dance=false;Object.assign(u,u.trueLook);u.r3rebuild=true;
  u.alerted=false;say(u,'Ônix!','#ff4d5e');M.revealed=(M.revealed||0)+1;
  if(M.revealed===1)hooks.vo('ctl:m4_reveal');
  alertCorp(u,u.x,u.y);u.alerted=true;
}
function updDisguise(u,dt){
  if(u.alerted){reveal(u);return;}
  let near=false;for(const a of M.agents)if(!a.dead&&!a.inCar&&Math.hypot(a.x-u.x,a.y-u.y)<2.6){near=true;break;}
  u.revealP=near?(u.revealP||0)+dt:Math.max(0,(u.revealP||0)-dt*.5);
  if(u.revealP>=1.6){reveal(u);return;}
  if(u.dance){u.path=null;return;}
  wander(u,dt,u.home?u.home.x:u.x,u.home?u.home.y:u.y,5,.9,sideTile);
}

/* ---------- guindaste: contêiner em queda ---------- */
export function dropContainer(){
  if(!M.flags||!M.flags.crane||M.flags.dropped||!M.dropPoint)return;
  M.flags.dropped=true;M.falling.push({x:M.dropPoint.x,y:M.dropPoint.y,t:0,T:.8});sfx('door',M.dropPoint.x,M.dropPoint.y);flags.hud=true;
}
function updFalling(dt){
  for(const f of M.falling){
    if(f.landed)continue;f.t+=dt;if(f.t<f.T)continue;f.landed=true;
    const src=M.agents.find(a=>!a.dead)||null;
    sfx('boom',f.x,f.y);M.shake=Math.min(1,M.shake+.8);
    for(let i=0;i<30;i++){const a=Math.random()*TAU,s=1+Math.random()*3;part(f.x+Math.cos(a)*.8,f.y+Math.sin(a)*.4,6,Math.cos(a)*s,Math.sin(a)*s,10+Math.random()*25,1.4+Math.random(),'#5a5650',1,2);}
    for(let i=0;i<20;i++){const a=Math.random()*TAU,s=2+Math.random()*4;part(f.x,f.y,10,Math.cos(a)*s,Math.sin(a)*s,40+Math.random()*50,.7,'#ffdc96',1,3);}
    for(const c of M.cars)if(!c.dead&&Math.abs(c.x-f.x)<1.8&&Math.abs(c.y-f.y)<1.1){c.hp=1;hurtCar(c,999,src);}
    const vipAlive=M.vip&&!M.vip.dead;
    for(const u of M.units)if(!u.dead&&!u.inCar&&Math.abs(u.x-f.x)<1.7&&Math.abs(u.y-f.y)<1)hurt(u,999,src);
    if(vipAlive&&M.vip.dead)M.flags.accident=true;
    for(let x=Math.floor(f.x-1.4);x<=Math.floor(f.x+1.4);x++){const i=Math.floor(f.y)*N+x;M.tile[i]=T_BLD;M.walk[i]=0;M.road[i]=0;}
    hooks.decal('scorch',f.x,f.y,1.6);
  }
}

/* ---------- ordens do jogador ---------- */
export function setSel(list){M.agents.forEach(a=>a.sel=false);M.sel=list.filter(a=>!a.dead);M.sel.forEach(a=>a.sel=true);flags.hud=true;}
export function selectAgent(u,add){if(u.dead)return;if(add)setSel(M.sel.includes(u)?M.sel.filter(a=>a!==u):[...M.sel,u]);else{setSel([u]);hooks.vo('ag:sel',u);}sfx('ui');}
export function issueMove(p){
  const sel=M.sel.filter(u=>!u.dead);if(!sel.length)return;
  const cars=new Set(sel.filter(u=>u.inCar).map(u=>u.inCar));
  cars.forEach(c=>{c.path=findPath(c.x,c.y,p.x,p.y,M.road,.35);c.pi=0;if(c.path)sfx('engine',c.x,c.y);});
  const foot=sel.filter(u=>!u.inCar),offs=[[0,0],[.8,0],[0,.8],[.8,.8]];
  foot.forEach((u,k)=>{let tx=p.x+offs[k%4][0]-(foot.length>1?.4:0),ty=p.y+offs[k%4][1]-(foot.length>2?.4:0);if(!canStand(tx,ty)){tx=p.x;ty=p.y;}u.ord={k:'move'};pathTo(u,tx,ty);});
  M.marks.push({x:p.x,y:p.y,life:.6,col:'#4fd8ff'});sfx('ui');hooks.vo('ag:mov',sel[0]);
}
export function issueAttack(t){
  const sel=M.sel.filter(u=>!u.dead&&!u.inCar);if(!sel.length)return;
  sel.forEach(u=>{
    const it=u.eq>=0?u.inv[u.eq]:null,w=it&&WD[it.t];
    if(w&&w.hack&&t.mech&&t.fac==='corp')u.ord={k:'hack',t,p:0};
    else if(w&&w.throw)u.ord={k:'throw',x:t.x,y:t.y,wt:it.t};
    else{if(!w||!w.arma)equipFirstWeapon(u);if(u.eq>=0&&WD[u.inv[u.eq].t].arma)u.ord={k:'atk',t,rep:0};}
  });
  M.marks.push({x:t.x,y:t.y,life:.6,col:'#ff4d5e'});flags.hud=true;hooks.vo('ag:atk',sel[0]);
}
export function issueGround(p){
  M.sel.filter(u=>!u.dead&&!u.inCar).forEach(u=>{const it=u.eq>=0?u.inv[u.eq]:null,w=it&&WD[it.t];if(!w)return;if(w.throw)u.ord={k:'throw',x:p.x,y:p.y,wt:it.t};else if(w.arma)u.ord={k:'fire',x:p.x,y:p.y,time:.5};});
  M.marks.push({x:p.x,y:p.y,life:.6,col:'#ffa53d'});
}
export function issueEnter(c){
  const sel=M.sel.filter(u=>!u.dead&&!u.inCar);if(!sel.length||c.dead)return;
  sel.forEach(u=>{u.ord={k:'enter',c,rep:0};});c.held=2;
  M.marks.push({x:c.x,y:c.y,life:.6,col:'#4fd8ff'});sfx('ui');
}
export function exitSelected(){
  const cars=new Set(M.sel.filter(u=>u.inCar).map(u=>u.inCar));cars.forEach(c=>exitCar(c));
}
export function cycleWeapon(dir){
  M.sel.forEach(u=>{
    const opts=[-1,...u.inv.map((it,i)=>i).filter(i=>equipable(u.inv[i].t))];
    const p=opts.indexOf(u.eq);u.eq=opts[(p+dir+opts.length)%opts.length];u.ord=null;
  });
  flags.hud=true;sfx('ui');
}
export function holster(){M.sel.forEach(u=>{u.eq=-1;u.ord=null;});flags.hud=true;sfx('ui');}
export function setPreset(i){const p=PRESETS[i];M.sel.forEach(u=>{if(u.colapso>0)return;u.nr={r:p.r,p:p.p,c:p.c};});flags.hud=true;sfx('ui');if(i===2&&M.sel[0])hooks.vo('ag:over',M.sel[0]);}
export function setDial(k,v){M.sel.forEach(u=>{if(u.colapso>0)return;u.nr[k]=clamp(v,0,1);});flags.hud=true;}
export function useSlot(i){
  const L=M.sel[0];if(!L)return;
  if(i<0){holster();return;}
  const it=L.inv[i];if(!it)return;const w=WD[it.t];
  if(w.heal){
    if(L.hp>=L.maxHp){log(`${L.nome} já está com integridade máxima.`);return;}
    if(has('nanomed')){let n=0;for(const a of M.agents)if(!a.dead&&Math.hypot(a.x-L.x,a.y-L.y)<2.5){a.hp=a.maxHp;n++;}removeItem(L,i);log(`Nanomedkit: ${n} agente${n>1?'s':''} restaurado${n>1?'s':''}.`,'green');sfx('hack');return;}
    L.hp=L.maxHp;removeItem(L,i);log(`${L.nome} usou um kit médico.`,'green');sfx('hack');return;
  }
  M.sel.forEach(u=>{const idx=u===L?i:u.inv.findIndex(q=>q.t===it.t);if(idx>=0){u.eq=idx;u.ord=null;}});
  flags.hud=true;sfx('ui');
}
