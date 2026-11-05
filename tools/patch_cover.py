"""Patch único: Fase 2 — IA de cobertura, supressão e granadas inimigas (registro da mudança)."""
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

OLD_AI = """function aiCombat(u,dt,range){
  let t=u.tgt;
  if(t&&(t.dead||!isEnemyOf(u,t)||(t.cloak&&Math.hypot(t.x-u.x,t.y-u.y)>1.5)))t=u.tgt=null;
  u.scanT-=dt;
  if(u.scanT<=0){u.scanT=.35+Math.random()*.2;const nt=nearestHostile(u,range*1.3);if(nt)t=u.tgt=nt;}
  if(!t)return false;
  const tp=posOf(t),d=Math.hypot(tp.x-u.x,tp.y-u.y),vis=d<=range*1.35&&los(u.x,u.y,tp.x,tp.y);
  if(vis){
    u.lostT=0;u.lkp={x:tp.x,y:tp.y};
    if(u.kind==='policia'&&!u.follower){M.policeAggro=Math.max(M.policeAggro,30);M.lastSeen={x:tp.x,y:tp.y};}
    if(!u.contact&&!u.follower){u.contact=true;if(u.kind==='guarda')hooks.vo('grd:contact',u);else if(u.kind==='inimigo')hooks.vo('ene:alert',u);}
    if(d<=range){u.path=null;aimAt(u,tp.x,tp.y);fireWeapon(u,u.w,u,tp.x,tp.y);return true;}
  }else{u.lostT+=dt;if(u.lostT>4){u.tgt=null;return false;}}
  if(u.spd>0){u.repT-=dt;if(u.repT<=0||!u.path){u.repT=.8+Math.random()*.5;pathTo(u,tp.x,tp.y);}moveAlong(u,dt,u.spd*1.15);}
  return true;
}"""

NEW_AI = """/* ---------- cobertura ---------- */
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
  if(u.scanT<=0){u.scanT=.35+Math.random()*.2;const nt=nearestHostile(u,range*1.3);if(nt)t=u.tgt=nt;}
  if(!t)return false;
  const tp=posOf(t),d=Math.hypot(tp.x-u.x,tp.y-u.y),vis=d<=range*1.35&&los(u.x,u.y,tp.x,tp.y);
  const smart=smartAI(u),acc=u.supp>0?.6:1;
  if(vis){
    u.lostT=0;u.lkp={x:tp.x,y:tp.y};
    if(u.kind==='policia'&&!u.follower){M.policeAggro=Math.max(M.policeAggro,30);M.lastSeen={x:tp.x,y:tp.y};}
    if(!u.contact&&!u.follower){u.contact=true;if(u.kind==='guarda')hooks.vo('grd:contact',u);else if(u.kind==='inimigo')hooks.vo('ene:alert',u);}
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
}"""

patch('js/sim.js', [
    (OLD_AI, NEW_AI),
    # cobertura absorve tiros e supressão de quem está perto da linha de fogo
    ("  const ex=u.x+dx*bt,ey=u.y+dy*bt;\n  M.tracers.push({x1:mx,y1:my,x2:ex,y2:ey,life:.07",
     """  if(best&&Math.hypot(best.x-u.x,best.y-u.y)>1.6&&coverAt(best.x,best.y,u)&&Math.random()<.5){const q=Math.max(.2,bt-.45);bt=q;best=null;sfx('ric',u.x+dx*q,u.y+dy*q);}
  for(const v of M.units){
    if(v===best||v.dead||v.inCar||v.fac===u.fac||v.fac==='civ'||v.fac==='neutral')continue;
    const rx=v.x-u.x,ry=v.y-u.y,t=rx*dx+ry*dy;if(t<.2||t>bt+.6)continue;
    if(Math.abs(rx*dy-ry*dx)<.9){if(!(v.supp>0))v.coverT=Math.min(v.coverT??1,.15);v.supp=1.4;}
  }
  const ex=u.x+dx*bt,ey=u.y+dy*bt;
  M.tracers.push({x1:mx,y1:my,x2:ex,y2:ey,life:.07"""),
    ("    if(u.cool>0)u.cool-=dt;", "    if(u.cool>0)u.cool-=dt;if(u.supp>0)u.supp-=dt;"),
    # agentes: supressão, indicador de cobertura e esquiva de granadas inimigas
    ("  const m=u.neuro=neuroMods(u);",
     """  const m=u.neuro=neuroMods(u);if(u.supp>0)m.acc*=.65;
  u.covT=(u.covT||0)-dt;
  if(u.covT<=0&&!u.inCar){
    u.covT=.3;const h=nearestHostile(u,9);u.covered=!!(h&&coverAt(u.x,u.y,posOf(h)));
    if(!u.ord||u.ord.k!=='move')for(const q of M.nades){if(!q.src||q.src.fac==='player'||Math.hypot(q.tx-u.x,q.ty-u.y)>2.6)continue;const ax=u.x-q.tx,ay=u.y-q.ty,l=Math.hypot(ax,ay)||1,p=randomNear(u.x+ax/l*3.2,u.y+ay/l*3.2,1.2);if(p){pathTo(u,p.x,p.y);u.ord={k:'move'};}break;}
  }"""),
])

patch('js/world.js', [
    ("u.hp=u.maxHp=100+dif*12;u.acc=.55+dif*.025;}",
     "u.hp=u.maxHp=100+dif*12;u.acc=.55+dif*.025;u.nades=dif>=7?2:dif>=4?1:0;}\n  if(u.kind==='guarda')u.nades=dif>=6?1:0;"),
])

patch('js/render.js', [
    ("    if(a.colapso>0){c.fillStyle='#ff4d5e';c.font='600 9px \"JetBrains Mono\",monospace';c.fillText('COLAPSO',X,Y-12);}",
     """    if(a.colapso>0){c.fillStyle='#ff4d5e';c.font='600 9px "JetBrains Mono",monospace';c.fillText('COLAPSO',X,Y-12);}
    else if(a.supp>0){c.fillStyle='#ffa53d';c.font='600 9px "JetBrains Mono",monospace';c.fillText('SUPRIMIDO',X,Y-12);}
    if(a.covered&&!a.inCar){c.fillStyle='rgba(79,216,255,.9)';c.beginPath();c.moveTo(X-16,Y-6);c.lineTo(X-10,Y-6);c.lineTo(X-10,Y+1);c.lineTo(X-13,Y+5);c.lineTo(X-16,Y+1);c.closePath();c.fill();}"""),
    ("  for(const t of M.terms){if(t.done||t.prog<=0)continue;",
     "  for(const q of M.nades){if(!q.src||q.src.fac==='player')continue;const p=toScreen(q.tx,q.ty),R=SCALE*camS.zoom*WD.granada.raio*.75,k=.6+.4*Math.sin(M.t*18);c.strokeStyle=`rgba(255,77,94,${k})`;c.lineWidth=2;c.setLineDash([6,4]);c.beginPath();c.ellipse(p.x,p.y,R,R*.58,0,0,TAU);c.stroke();c.setLineDash([]);}\n  for(const t of M.terms){if(t.done||t.prog<=0)continue;"),
])

patch('js/ui.js', [
    ("`${u.colapso>0?'COLAPSO':u.inCar?'NO VEÍCULO':'OK'} · ",
     "`${u.colapso>0?'COLAPSO':u.inCar?'NO VEÍCULO':u.supp>0?'SUPRIMIDO':u.covered?'EM COBERTURA':'OK'} · "),
])
print('ok')
