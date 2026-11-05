/* Roteiro de missões feitas à mão: corrotinas (geradores) que esperam condições e disparam eventos. */
import {M,G,flags,hooks} from './core.js';
import {mkUnit,armAI,pathTo,spawnRival} from './world.js';
import {endMission,explode,alertCorp,destroyBld} from './sim.js';
import {commFree} from './audio.js';

export function startScript(){
  M.co=[];
  if(M.scriptDef)M.co.push({gen:M.scriptDef.script(api(),M)});
}
export function runScript(){
  if(!M||!M.co)return;
  for(let i=0;i<M.co.length;i++){
    const c=M.co[i];if(c.done)continue;
    if(c.wait&&!c.wait())continue;
    let r;try{r=c.gen.next();}catch(e){console.error('roteiro',e);c.done=true;continue;}
    if(r.done){c.done=true;continue;}
    c.wait=typeof r.value==='function'?r.value:null;
  }
}
function api(){
  const skipping=()=>M.cine&&M.cineSkip;
  const S={
    wait(s){const t0=M.t,c=M.cine;return ()=>M.t-t0>=s||(c&&M.cineSkip);},
    until(f){return f;},
    say(key,u){if(!skipping())hooks.vo(key,u);},
    talkDone(){const c=M.cine;return ()=>commFree()||(c&&M.cineSkip);},
    cine(on){M.cine=on;M.cineSkip=false;flags.hud=true;if(!on)M.camGoal=null;},
    camTo(p,z,dur){M.camGoal={x:p.x,y:p.y,z,dur,t:0,from:null};const c=M.cine;return ()=>!M.camGoal||M.camGoal.t>=dur||(c&&M.cineSkip);},
    obj(id,text,o={}){M.objs.push({id,text,primary:!!o.primary,state:'active'});flags.hud=true;},
    setObj(id,patch){const o=M.objs.find(x=>x.id===id);if(o)Object.assign(o,patch);flags.hud=true;},
    objState(id){const o=M.objs.find(x=>x.id===id);return o&&o.state;},
    timer(label,s){M.timer={label,end:M.t+s};flags.hud=true;},
    clearTimer(){M.timer=null;flags.hud=true;},
    timerDone(){return !M.timer||M.t>=M.timer.end;},
    spawn(kind,x,y,dif){const u=mkUnit(kind,x,y);if(dif&&u.w)armAI(u,dif,Math.random);return u;},
    car(x,y,ang,col,hp=120){const c={x,y,dx:Math.cos(ang),dy:Math.sin(ang),ang,v:0,cur:0,hp,dead:false,col,stopT:0,smokeT:0,occ:[],player:false,held:0,path:null,pi:0,scripted:true};M.cars.push(c);return c;},
    drive(c,pts){c.path=pts.map(p=>({x:p.x,y:p.y}));c.pi=0;},
    arrived(c){return ()=>c.dead||(!c.path&&c.cur<.4);},
    walk(u,x,y){pathTo(u,x,y);},
    win(reason){endMission(true,reason);},
    fail(reason){endMission(false,reason);},
    bonus(text,val){M.bonus.push({text,val});},
    log(m,c){hooks.log(m,c);},
    fork(gen){M.co.push({gen});},
    rival(id,x,y,hpMul=1){if(G&&G.rivais&&G.rivais[id]&&G.rivais[id].morto)return null;const u=spawnRival(id,x,y);if(u){u.alerted=true;u.hp=u.maxHp=Math.round(u.maxHp*hpMul);}return u;},
    lampOff(l){hooks.destroy('lampoff',l);},
    block(x0,y0,x1,y1,on){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){const i=y*57+x;M.tile[i]=on?2:4;M.walk[i]=on?0:1;}},
    boom(x,y,r,dmg){explode(x,y,r,dmg,null);},
    breach(b){if(!b.dead){explode(b.x+b.w/2,b.y+b.d/2,1.6,40,null);destroyBld(b,null);}},
    alarm(){const a=M.agents.find(q=>!q.dead),v=M.units.find(u=>!u.dead&&u.fac==='corp'&&!u.alerted&&!u.disguise&&!u.cand);if(a&&v)alertCorp(v,a.x,a.y);M.corpAlert=true;for(const u of M.units)if(!u.dead&&u.fac==='corp'&&!u.disguise&&!u.cand){u.alerted=true;if(a)u.lkp={x:a.x,y:a.y};}},
  };
  return S;
}
