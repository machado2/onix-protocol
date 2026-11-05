/* Mundo: geração procedural de distritos, unidades, grade, caminhos e linha de visão. */
import {DOCAS} from './missions/docas.js';
import {FAVELA} from './missions/favela.js';
import {MERCADO} from './missions/mercado.js';
import {NEON as MIS_NEON} from './missions/neon.js';
import {FUNDICAO} from './missions/fundicao.js';
import {LUMEN} from './missions/lumen.js';
import {RETIRO} from './missions/retiro.js';
import {DOCA} from './missions/doca.js';
import {TORRE} from './missions/torre.js';
import {JARDINS} from './missions/jardins.js';
import {RIVALS} from './story.js';
import {N,P,NB,TAU,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,T_WATER,T_FENCE,T_POST,T_GLASS,DX8,DY8,clamp,RNG,pick,shade,
  M,G,setM,DIST,KIND,SKIN,HAIR,WD,VIPS,CIENT,SIGNS,NEON,has,penteOf} from './core.js';

let uid=0;
export function mkUnit(kind,x,y){
  const K=KIND[kind];
  const u={id:++uid,kind,x,y,fac:K.fac,hp:K.hp,maxHp:K.hp,armor:K.armor||0,spd:K.spd,acc:K.acc||.5,w:K.w||null,mun:K.w?WD[K.w].pente:0,
    face:Math.random()*TAU,path:null,pi:0,walkT:Math.random()*9,cool:0,rel:0,relSt:null,relW:null,tgt:null,alerted:false,dead:false,deathT:0,
    panicT:0,idleT:Math.random()*3,repT:0,percT:Math.random()*.3,scanT:Math.random()*.3,burn:0,flash:0,hitT:0,barT:0,aimT:0,lostT:0,huntT:Math.random()*2,
    hj:0,hjT:0,follower:false,owner:null,inCar:null,runT:0,
    skin:pick(SKIN),hair:pick(HAIR),coat:'#333333',trim:'#555555',legs:'#0d0f14',long:false,visor:false,umb:null};
  if(kind==='civil'){u.coat=pick(['#6b4a3a','#3a5a6b','#7a6a50','#5a3a5a','#4a6a4a','#8a3a3a','#3a3a4a','#a07a4a','#5c6470','#2f5f5a']);u.trim=shade(u.coat,.25);if(Math.random()<.32)u.umb=pick(['#c23a5a','#2a7a9a','#d0a040','#5a3a8a','#1d1f24','#2e8a6a']);u.spd=.9+Math.random()*.4;u.hp=u.maxHp=25+Math.random()*10;}
  if(kind==='policia'){u.coat='#22407a';u.trim='#d8e4ff';u.legs='#141b2c';u.cap=true;}
  if(kind==='guarda'){u.coat='#4a1a22';u.trim='#ff4d5e';u.legs='#1a0d10';u.visor=true;}
  if(kind==='inimigo'){u.coat='#15161c';u.trim='#ff2e4d';u.long=true;u.visor=true;u.hair='#0a0a0c';}
  if(kind==='vip'){u.coat='#d6cfbc';u.trim='#ffd36b';u.legs='#2a2620';}
  if(kind==='cientista'){u.coat='#e6edf4';u.trim='#5dffa0';u.legs='#2b3240';u.long=true;}
  if(kind==='torre'||kind==='drone')u.mech=true;
  if(kind==='drone')u.fly=true;
  M.units.push(u);return u;
}
export function armAI(u,dif,r){
  if(u.kind==='guarda'){u.w=dif<=2?'pistola':(r()<.5?'smg':(dif>=5&&r()<.4?'escopeta':'pistola'));u.hp=u.maxHp=60+dif*6;u.acc=.38+dif*.025;}
  if(u.kind==='inimigo'){u.w=dif>=7&&r()<.35?'feixe':(dif>=8&&r()<.35?'serra':(dif>=4&&r()<.25?'escopeta':'smg'));u.hp=u.maxHp=100+dif*12;u.acc=.5+dif*.028;u.nades=dif>=7?2:dif>=4?1:0;}
  if(u.kind==='guarda')u.nades=dif>=6?1:0;
  u.mun=WD[u.w].pente;
}
export function mkAgent(a,x,y,k){
  const u=mkUnit('agente',x,y);
  u.ag=a;u.nome=a.nome;u.num=k+1;u.voz=a.voz||(a.id%2?'m':'f');u.vozRate=.95+((a.id*37)%10)/100;u.coat='#1b1f2a';u.trim='#4fd8ff';u.long=true;u.visor=true;u.hair='#0b0b0e';
  const im=a.imp;
  u.hp=u.maxHp=150+45*im.chassi;u.armor=.08+.07*im.chassi+(has('blindagem')?.1:0);u.spd=2.4*(1+.12*im.motor);u.acc=.75+.08*im.otica;u.rngMul=1+.08*im.otica;
  u.inv=a.inv.map(it=>({t:it.t,mun:WD[it.t].pente?penteOf(u,it.t):0}));u.eq=-1;
  u.nr={r:.5,p:.5,c:.5};u.maxEstab=Math.max(40,100-(a.dep||0));u.estab=u.maxEstab;u.colapso=0;u.over=0;
  u.ord=null;u.autoT=null;u.kills=0;u.face=Math.PI*.25;
  M.agents.push(u);return u;
}
export function missionNames(di){const r=RNG(di*131+((G&&G.dia)||1)*17);return {vip:pick(VIPS,r),sci:pick(CIENT,r)};}

function split(x,y,w,h,dep,out,r){
  if(dep<3&&(w>=4||h>=4)&&r()<.85){
    if((w>=h&&w>=4)||h<4){const s=2+((r()*(w-3))|0);split(x,y,s,h,dep+1,out,r);split(x+s,y,w-s,h,dep+1,out,r);}
    else{const s=2+((r()*(h-3))|0);split(x,y,w,s,dep+1,out,r);split(x,y+s,w,h-s,dep+1,out,r);}
  }else out.push({x,y,w,h});
}

const MISSIONS={docas:DOCAS,favela:FAVELA,mercado:MERCADO,neon:MIS_NEON,fundicao:FUNDICAO,lumen:LUMEN,retiro:RETIRO,doca:DOCA,torre:TORRE,jardins:JARDINS};
export function spawnRival(id,x,y){
  const R=RIVALS.find(r=>r.id===id);if(!R)return null;
  const u=mkUnit('inimigo',x,y);
  Object.assign(u,{rival:id,nome:R.nome,w:R.w,mun:WD[R.w].pente,hp:R.hp,maxHp:R.hp,armor:R.armor,spd:R.spd,acc:R.acc,coat:R.coat,trim:R.trim,long:true,visor:true,nades:2,home:{x,y}});
  return u;
}
function initDestruct(m){m.bldAt=new Int16Array(N*N).fill(-1);m.blds.forEach((b,i)=>{for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++)m.bldAt[y*N+x]=i;});m.glass=new Set();m.wallDecals=[];m.debris=[];m.fires=[];}
const isWalk=t=>t!==T_BLD&&t!==T_TREE&&t!==T_WATER&&t!==T_FENCE&&t!==T_POST&&t!==T_GLASS;
function genHandcrafted(di,def,squad){
  const D=DIST[di],n=N,NN=n*n,idx=(x,y)=>y*n+x;
  const tile=new Uint8Array(NN).fill(T_WALK),hgt=new Uint8Array(NN),blds=[];
  const m={di,D,demo:false,hand:true,tipo:D.tipo,tile,hgt,walk:new Uint8Array(NN),road:new Uint8Array(NN),blds,units:[],agents:[],cars:[],terms:[],lamps:[],trees:[],props:[],drops:[],
    parts:[],tracers:[],texts:[],nades:[],flashes:[],marks:[],sel:[],spawn:{x:def.spawn.x,y:def.spawn.y},evac:null,escape:null,vip:null,sci:null,followers:0,
    policeAggro:0,lastSeen:null,corpAlert:false,reinfT:20,t:0,shake:0,paused:false,ended:false,endT:0,win:false,reason:'',
    stats:{abates:0,civis:0,policiais:0,seguidores:0},hover:null,decalsDirty:false,
    objs:[],flags:{},bonus:[],decor:[],piers:[],falling:[],co:[],cams:[],rail:null,train:null,trainT:12,vents:[],glassN:0,lasers:[],camGoal:null,cine:false,timer:null,scriptDef:def};
  setM(m);
  const B={m,
    tile(x,y,t){tile[idx(x,y)]=t;},
    rect(t,x0,y0,x1,y1){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++)tile[idx(x,y)]=t;},
    pier(x0,y0,x1,y1){B.rect(T_PLAZA,x0,y0,x1,y1);m.piers.push({x0,y0,x1,y1});},
    bld(o){const b=Object.assign({pal:0,v:0,neon:-1,sign:null,roof:0,ou:0,ov:0},o);blds.push(b);for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++){tile[idx(x,y)]=T_BLD;hgt[idx(x,y)]=b.fl;}return b;},
    lamp(x,y,col='#ffb35c',tall=false,extra){m.lamps.push(Object.assign({x,y,col,tall},extra||{}));},
    tree(x,y){m.trees.push({x,y,s:1,r:x*7+y});tile[idx(x|0,y|0)]=T_TREE;},
    prop(x,y){m.props.push({x,y,hp:20,dead:false});},
    decor(o){m.decor.push(o);},
    term(o){m.terms.push(o);},
    unit(kind,x,y){return mkUnit(kind,x,y);},
    arm(u,dif){armAI(u,dif,Math.random);},
    randTile(pred){for(let k=0;k<400;k++){const x=(Math.random()*n)|0,y=(Math.random()*n)|0;if(pred(tile[idx(x,y)],x,y))return {x:x+.5,y:y+.5};}return null;},
    cam(x,y,ang,o){m.cams.push(Object.assign({x,y,base:ang,a:ang,sweep:.6,spd:.5,ph:Math.random()*6,fov:.42,range:7,see:0,dead:false,off:false},o||{}));},
    laser(x1,y1,x2,y2,o){const l=Object.assign({x1,y1,x2,y2,off:false,on:true,per:0,ph:0,duty:.5,tripT:0},o||{});m.lasers.push(l);return l;},
    heavy(x,y,dif){const u=mkUnit('inimigo',x,y);armAI(u,dif||6,Math.random);Object.assign(u,{heavy:true,w:'serra',mun:WD.serra.pente,hp:380,maxHp:380,armor:.5,spd:1.35,nades:0,coat:'#2a2c34',trim:'#ffb13d'});return u;},
    vent(x,y,o){m.vents.push(Object.assign({x,y,per:7,dur:2.2,ph:Math.random()*7,r:1.15,dmg:60,state:0},o||{}));},
    drone(x,y,route,dif){const u=mkUnit('drone',x,y);u.route=route||null;u.ri=0;if(dif){u.acc=.42+dif*.03;u.hp=u.maxHp=50+dif*5;}return u;},
    glass(x0,y0,x1,y1){for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){if(tile[idx(x,y)]!==T_GLASS)m.glassN++;tile[idx(x,y)]=T_GLASS;}},
    monorail(y,xs){m.rail={y,xs};for(const x of xs)tile[idx(x,y)]=T_POST;},
    disguise(u,dance){u.disguise=true;u.dance=!!dance;u.trueLook={coat:u.coat,trim:u.trim,long:u.long,visor:u.visor,hair:u.hair};u.coat=pick(['#6b4a3a','#3a5a6b','#7a6a50','#5a3a5a','#8a3a3a','#a07a4a','#5c6470']);u.trim=shade(u.coat,.25);u.long=false;u.visor=false;u.hair=pick(HAIR);u.cell=true;},
    lanes(list,count){const cols=['#8a1f2e','#1f4f8a','#c9c2b0','#2c2f36','#e0a020','#3c6e5a','#d8d8dc'];for(let k=0;k<count;k++){const L=list[k%list.length],pos=Math.random()*n;const c={x:L.x!==undefined?L.x:pos,y:L.y!==undefined?L.y:pos,dx:L.dx,dy:L.dy,v:3.2+Math.random()*2,cur:3,hp:70,dead:false,col:pick(cols),stopT:0,smokeT:0,occ:[],player:false,held:0,path:null,pi:0};c.ang=Math.atan2(c.dy,c.dx);m.cars.push(c);}},
  };
  def.build(B);
  for(let i=0;i<NN;i++){m.walk[i]=isWalk(tile[i])?1:0;m.road[i]=tile[i]===T_ROAD?1:0;}
  initDestruct(m);
  if(squad){const offs=[[-.5,-.5],[.5,-.5],[-.5,.5],[.5,.5]];squad.forEach((a,k)=>mkAgent(a,m.spawn.x+offs[k][0],m.spawn.y+offs[k][1],k));}
  return m;
}

export function genMission(di,demo,squad,opts){
  const revolta=!!(opts&&opts.revolta);
  if(!demo&&!revolta&&DIST[di].mission&&MISSIONS[DIST[di].mission])return genHandcrafted(di,MISSIONS[DIST[di].mission],squad);
  const D=DIST[di],tipo=revolta?'eliminacao':D.tipo,rng=RNG(di*7919+((G&&G.dia)||1)*31337+(demo?99:0));
  const n=N,NN=n*n,idx=(x,y)=>y*n+x;
  const tile=new Uint8Array(NN),hgt=new Uint8Array(NN);
  for(let y=0;y<n;y++)for(let x=0;x<n;x++)tile[idx(x,y)]=(x%P<2||y%P<2)?T_ROAD:T_WALK;
  const corner=1+((rng()*3)|0),kx=(corner&1)?NB:0,ky=(corner&2)?NB:0;
  const spawn={x:kx*P+1,y:ky*P+1};
  const sbx=kx?NB-1:0,sby=ky?NB-1:0;
  const blocks=[];
  for(let by=0;by<NB;by++)for(let bx=0;bx<NB;bx++)blocks.push({bx,by,ox:bx*P+2,oy:by*P+2,d:Math.abs(bx-sbx)+Math.abs(by-sby),type:null});
  const comps=[];
  if(!demo){
    const far=blocks.filter(b=>b.d>=5),c1=pick(far,rng);c1.type='comp';comps.push(c1);
    if(tipo==='sabotagem'||D.hq){
      const mid=blocks.filter(b=>!b.type&&b.d>=3&&Math.abs(b.bx-c1.bx)+Math.abs(b.by-c1.by)>=2);
      if(mid.length){const c2=pick(mid,rng);c2.type='comp';comps.push(c2);}
    }
  }
  const blds=[];
  const fill=(R,h)=>{for(let y=R.y;y<R.y+R.d;y++)for(let x=R.x;x<R.x+R.w;x++){tile[idx(x,y)]=T_BLD;hgt[idx(x,y)]=h;}};
  for(const b of blocks){
    const x0=b.ox+1,y0=b.oy+1;
    if(!b.type){const r=rng();b.type=b.d===0?(r<.7?'bld':'plaza'):r<.6?'bld':r<.8?'park':'plaza';}
    if(b.type==='bld'){
      const rects=[];split(x0,y0,7,7,0,rects,rng);
      for(const R of rects){
        if(rng()<.12){for(let y=R.y;y<R.y+R.h;y++)for(let x=R.x;x<R.x+R.w;x++)tile[idx(x,y)]=T_PLAZA;continue;}
        const fl=Math.min(11,2+((rng()*(3+D.riq*6))|0));
        const B={x:R.x,y:R.y,w:R.w,d:R.h,fl,pal:(rng()*4)|0,v:(rng()*4)|0,neon:rng()<.45?((rng()*4)|0):-1,
          sign:fl>=3&&rng()<.4?pick(SIGNS,rng):null,signCol:pick(NEON,rng),roof:(rng()*3)|0,ant:fl>=8&&rng()<.6,ou:(rng()*8)|0,ov:(rng()*8)|0};
        blds.push(B);fill(B,fl);
      }
    }else if(b.type==='park'){
      for(let y=y0;y<y0+7;y++)for(let x=x0;x<x0+7;x++)tile[idx(x,y)]=(x===x0+3||y===y0+3)?T_PLAZA:(rng()<.28?T_TREE:T_GRASS);
    }else if(b.type==='plaza'){
      for(let y=y0;y<y0+7;y++)for(let x=x0;x<x0+7;x++)tile[idx(x,y)]=T_PLAZA;
      const B={x:x0+3,y:y0+3,w:1,d:1,fl:1,pal:5,v:0,neon:(rng()*4)|0,sign:null,roof:0,kiosk:true,ou:0,ov:0};blds.push(B);fill(B,1);
    }else if(b.type==='comp'){
      const fl=8+((rng()*3)|0)+(D.hq?3:0);
      for(let y=y0;y<y0+7;y++)for(let x=x0;x<x0+7;x++)if(y>=y0+3)tile[idx(x,y)]=T_PLAZA;
      const B={x:x0,y:y0,w:7,d:3,fl,pal:4,v:(rng()*4)|0,neon:0,sign:'HÉLICE',signCol:'#ff3d5a',roof:1,ant:true,corp:true,ou:(rng()*8)|0,ov:0};
      blds.push(B);fill(B,fl);
      b.court={x:x0+3.5,y:y0+5,x0,y0};
    }
  }
  const walk=new Uint8Array(NN),road=new Uint8Array(NN);
  for(let i=0;i<NN;i++){walk[i]=(tile[i]!==T_BLD&&tile[i]!==T_TREE)?1:0;road[i]=tile[i]===T_ROAD?1:0;}
  const m={di,D,demo:!!demo,revolta,tipo,tile,hgt,walk,road,blds,units:[],agents:[],cars:[],terms:[],lamps:[],trees:[],props:[],drops:[],
     parts:[],tracers:[],texts:[],nades:[],flashes:[],marks:[],sel:[],spawn,evac:null,escape:null,vip:null,sci:null,followers:0,
     policeAggro:0,lastSeen:null,corpAlert:false,reinfT:20,t:0,shake:0,paused:false,ended:false,endT:0,win:false,reason:'',
     stats:{abates:0,civis:0,policiais:0,seguidores:0},hover:null,decalsDirty:false};
  setM(m);initDestruct(m);
  const lampCols=['#ffb35c','#ffb35c','#ffb35c','#7fe3ff','#ff6ad5'];
  for(const b of blocks){
    [[0,0],[8,0],[0,8],[8,8],[4,0],[4,8],[0,4],[8,4]].forEach(([dx,dy],k)=>{if(k<4||rng()<.55){const x=b.ox+dx,y=b.oy+dy;if(tile[idx(x,y)]===T_WALK)m.lamps.push({x:x+.5,y:y+.5,col:pick(lampCols,rng)});}});
  }
  for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(tile[idx(x,y)]===T_TREE)m.trees.push({x:x+.5,y:y+.5,s:.8+rng()*.5,r:rng()*TAU});
  const isSide=t=>t===T_WALK||t===T_PLAZA||t===T_GRASS;
  const randTile=(pred,cx,cy,r,tries=300)=>{for(let k=0;k<tries;k++){let x,y;if(cx===undefined){x=(rng()*n)|0;y=(rng()*n)|0;}else{x=Math.floor(cx+(rng()*2-1)*r);y=Math.floor(cy+(rng()*2-1)*r);}if(x<0||y<0||x>=n||y>=n)continue;const t=tile[idx(x,y)];if(pred(t,x,y))return {x:x+.5,y:y+.5};}return null;};
  const farFromSpawn=(t,x,y)=>isSide(t)&&Math.hypot(x-spawn.x,y-spawn.y)>16;
  // barris explosivos
  comps.forEach(cp=>{const c=cp.court;for(let k=0;k<3;k++){const p=randTile(t=>t===T_PLAZA,c.x,c.y,3.5);if(p)m.props.push({x:p.x+(rng()-.5)*.4,y:p.y+(rng()-.5)*.4,hp:20,dead:false});}});
  for(let k=0;k<7;k++){const p=randTile((t,x,y)=>t===T_WALK&&Math.hypot(x-spawn.x,y-spawn.y)>6);if(p)m.props.push({x:p.x,y:p.y,hp:20,dead:false});}
  const names=missionNames(di),dif=D.dif;
  if(!demo){
    const c1=comps[0].court;
    if(tipo==='assassinato'){
      const v=mkUnit('vip',c1.x,c1.y);v.nome=names.vip;
      v.route=[{x:c1.x,y:c1.y}];for(let k=0;k<2;k++){const p=randTile((t,x,y)=>isSide(t)&&Math.hypot(x-c1.x,y-c1.y)>7,c1.x,c1.y,15);if(p)v.route.push(p);}
      v.ri=0;m.vip=v;
      const cs=[[1,1],[NB*P+1,1],[1,NB*P+1],[NB*P+1,NB*P+1]].filter(c=>!(c[0]===spawn.x&&c[1]===spawn.y));
      cs.sort((a,b)=>Math.hypot(b[0]-c1.x,b[1]-c1.y)-Math.hypot(a[0]-c1.x,a[1]-c1.y));
      m.escape={x:cs[0][0],y:cs[0][1]};
      for(let k=0;k<2;k++){const g=mkUnit('guarda',c1.x+(k?.8:-.8),c1.y+.6);g.escort=v;armAI(g,dif,rng);}
    }else if(tipo==='extracao'){
      const s=mkUnit('cientista',c1.x,c1.y+1);s.nome=names.sci;m.sci=s;m.evac={x:spawn.x,y:spawn.y};
    }else if(tipo==='sabotagem'){
      const cA=comps[0].court,cB=(comps[1]||comps[0]).court;
      m.terms.push({x:cA.x0+1.5,y:cA.y0+4.5,prog:0,done:false},{x:cA.x0+5.5,y:cA.y0+4.5,prog:0,done:false},{x:cB.x0+3.5,y:cB.y0+5.8,prog:0,done:false});
    }
    const nG=3+dif;
    for(let k=0;k<nG;k++){const c=comps[k%comps.length].court;const p=randTile(t=>t===T_PLAZA||t===T_WALK,c.x,c.y,4)||{x:c.x,y:c.y};const g=mkUnit('guarda',p.x,p.y);g.home={x:p.x,y:p.y};armAI(g,dif,rng);}
    const nT=Math.floor(dif/2)+(D.hq?2:0);
    const tps=[];comps.forEach(cp=>{const c=cp.court;tps.push([c.x0,c.y0+6],[c.x0+6,c.y0+6],[c.x0,c.y0+3],[c.x0+6,c.y0+3]);});
    for(let k=0;k<Math.min(nT,tps.length);k++)mkUnit('torre',tps[k][0]+.5,tps[k][1]+.5);
    const nE=tipo==='eliminacao'?(revolta?2+Math.ceil(dif/3):D.hq?9:2+Math.ceil(dif/2)):Math.max(0,Math.floor((dif-1)/2));
    for(let k=0;k<nE;k++){const p=randTile(farFromSpawn);if(!p)continue;const e=mkUnit('inimigo',p.x,p.y);e.home={x:p.x,y:p.y};armAI(e,dif,rng);}
    if(G&&!revolta){
      const R=G.rivais||{},alive=RIVALS.filter(r=>!(R[r.id]&&R[r.id].morto));
      let list=[];
      if(D.hq)list=alive;
      else if(dif>=4&&rng()<.45){const c=alive.filter(r=>!r.hqOnly);if(c.length)list=[c[(G.dia+di)%c.length]];}
      for(const r of list){const p=randTile(farFromSpawn);if(p)spawnRival(r.id,p.x,p.y);}
    }
  }
  const nP=demo?4:2+Math.floor(dif/2);
  for(let k=0;k<nP;k++){const p=randTile(t=>t===T_WALK);if(p)mkUnit('policia',p.x,p.y);}
  const nC=30+Math.round(D.riq*16)+(revolta?22:0);
  for(let k=0;k<nC;k++){const p=randTile(isSide);if(p)mkUnit('civil',p.x,p.y);}
  const lanes=[];
  for(let k=0;k<=NB;k++){lanes.push({x:k*P+.5,dx:0,dy:-1},{x:k*P+1.5,dx:0,dy:1},{y:k*P+.5,dx:1,dy:0},{y:k*P+1.5,dx:-1,dy:0});}
  const nCar=12+Math.round(D.riq*8);
  const carCols=['#8a1f2e','#1f4f8a','#c9c2b0','#2c2f36','#e0a020','#3c6e5a','#5e3a7a','#d8d8dc','#e0a020'];
  for(let k=0;k<nCar;k++){
    const L=pick(lanes,rng),pos=rng()*n;
    const c={x:L.x!==undefined?L.x:pos,y:L.y!==undefined?L.y:pos,dx:L.dx,dy:L.dy,v:3.2+rng()*2,cur:0,hp:70,dead:false,col:pick(carCols,rng),stopT:0,smokeT:0,occ:[],player:false,held:0,path:null,pi:0};
    c.ang=Math.atan2(c.dy,c.dx);c.cur=c.v;m.cars.push(c);
  }
  if(!demo&&squad){
    const offs=[[-.5,-.5],[.5,-.5],[-.5,.5],[.5,.5]];
    squad.forEach((a,k)=>mkAgent(a,spawn.x+offs[k][0],spawn.y+offs[k][1],k));
  }
  return m;
}

/* ---------- grade, visão e caminhos ---------- */
export function walkAt(x,y,grid){if(x<0||y<0||x>=N||y>=N)return false;return (grid||M.walk)[(y|0)*N+(x|0)]===1;}
export function canStand(x,y,grid,r=.2){return walkAt(x-r,y-r,grid)&&walkAt(x+r,y-r,grid)&&walkAt(x-r,y+r,grid)&&walkAt(x+r,y+r,grid);}
export function los(ax,ay,bx,by){
  const dx=bx-ax,dy=by-ay,d=Math.hypot(dx,dy),n=Math.ceil(d/.2);
  for(let k=1;k<n;k++){const t=k/n,x=(ax+dx*t)|0,y=(ay+dy*t)|0;if(x<0||y<0||x>=N||y>=N)return false;if(M.tile[y*N+x]===T_BLD)return false;}
  return true;
}
function lineOK(a,b,grid,r){const dx=b.x-a.x,dy=b.y-a.y,d=Math.hypot(dx,dy),n=Math.ceil(d/.25);for(let k=1;k<=n;k++){const t=k/n;if(!canStand(a.x+dx*t,a.y+dy*t,grid,r))return false;}return true;}
const AS={g:new Float32Array(N*N),f:new Float32Array(N*N),came:new Int32Array(N*N),seen:new Uint32Array(N*N),closed:new Uint32Array(N*N),gen:0,heap:new Int32Array(N*N*8)};
export function nearestWalk(x,y,grid){const W=grid||M.walk;for(let r=0;r<10;r++)for(let dy=-r;dy<=r;dy++)for(let dx=-r;dx<=r;dx++){if(Math.max(Math.abs(dx),Math.abs(dy))!==r)continue;const X=x+dx,Y=y+dy;if(X>=0&&Y>=0&&X<N&&Y<N&&W[Y*N+X])return Y*N+X;}return -1;}
export function findPath(sx,sy,tx,ty,grid,rad=.2){
  const W=grid||M.walk,txi=clamp(tx|0,0,N-1),tyi=clamp(ty|0,0,N-1);
  let t=tyi*N+txi,exact=true;
  if(!W[t]){t=nearestWalk(txi,tyi,W);exact=false;if(t<0)return null;}
  let s=clamp(sy|0,0,N-1)*N+clamp(sx|0,0,N-1);
  if(!W[s]){s=nearestWalk(clamp(sx|0,0,N-1),clamp(sy|0,0,N-1),W);if(s<0)return null;}
  const endPt=exact&&canStand(tx,ty,W,rad)?{x:tx,y:ty}:{x:t%N+.5,y:(t/N|0)+.5};
  if(s===t)return [endPt];
  const gen=++AS.gen,g=AS.g,f=AS.f,came=AS.came,seen=AS.seen,closed=AS.closed,heap=AS.heap;let hn=0;
  const tx0=t%N,ty0=t/N|0;
  const H=i=>{const dx=Math.abs(i%N-tx0),dy=Math.abs((i/N|0)-ty0);return dx+dy-.59*Math.min(dx,dy);};
  const push=i=>{let k=hn++;heap[k]=i;while(k>0){const p=(k-1)>>1;if(f[heap[p]]<=f[heap[k]])break;const q=heap[p];heap[p]=heap[k];heap[k]=q;k=p;}};
  const pop=()=>{const top=heap[0];heap[0]=heap[--hn];let k=0;for(;;){const l=2*k+1,r=l+1;let m=k;if(l<hn&&f[heap[l]]<f[heap[m]])m=l;if(r<hn&&f[heap[r]]<f[heap[m]])m=r;if(m===k)break;const q=heap[m];heap[m]=heap[k];heap[k]=q;k=m;}return top;};
  g[s]=0;f[s]=H(s);seen[s]=gen;came[s]=-1;push(s);
  let it=0,found=false;
  while(hn>0&&it++<9000){
    const c=pop();if(c===t){found=true;break;}if(closed[c]===gen)continue;closed[c]=gen;
    const cx=c%N,cy=c/N|0;
    for(let k=0;k<8;k++){
      const dx=DX8[k],dy=DY8[k],nx=cx+dx,ny=cy+dy;if(nx<0||ny<0||nx>=N||ny>=N)continue;
      const ni=ny*N+nx;if(!W[ni]||closed[ni]===gen)continue;
      if(dx&&dy&&(!W[cy*N+nx]||!W[ny*N+cx]))continue;
      const ng=g[c]+(dx&&dy?1.414:1);
      if(seen[ni]!==gen||ng<g[ni]){seen[ni]=gen;g[ni]=ng;f[ni]=ng+H(ni);came[ni]=c;if(hn<heap.length-1)push(ni);}
    }
  }
  if(!found)return null;
  const tiles=[];for(let c=t;c!==-1&&c!==s;c=came[c])tiles.push(c);tiles.reverse();
  const pts=tiles.map(i=>({x:i%N+.5,y:(i/N|0)+.5}));pts[pts.length-1]=endPt;
  const out=[];let cur={x:sx,y:sy},i=0;
  while(i<pts.length){let j=Math.min(pts.length-1,i+10);while(j>i&&!lineOK(cur,pts[j],W,rad))j--;out.push(pts[j]);cur=pts[j];i=j+1;}
  return out;
}
export function pathTo(u,x,y){u.path=findPath(u.x,u.y,x,y);u.pi=0;return !!u.path;}
export function moveAlong(u,dt,spd){
  if(!u.path)return false;
  const p=u.path[u.pi];if(!p){u.path=null;return false;}
  const dx=p.x-u.x,dy=p.y-u.y,dd=Math.hypot(dx,dy),step=spd*dt;
  if(u.aimT<=0&&dd>.01)u.face=Math.atan2(dy,dx);
  u.walkT+=dt*spd*4.2;u.curSpd=spd;
  if(dd<=step){u.x=p.x;u.y=p.y;u.pi++;if(u.pi>=u.path.length)u.path=null;}
  else{
    const nx=u.x+dx/dd*step,ny=u.y+dy/dd*step;
    if(canStand(nx,ny)){u.x=nx;u.y=ny;}else if(canStand(nx,u.y))u.x=nx;else if(canStand(u.x,ny))u.y=ny;else{u.x=nx;u.y=ny;if(!walkAt(u.x,u.y)){u.x-=dx/dd*step;u.y-=dy/dd*step;u.path=null;}}
  }
  return true;
}
export const sideTile=t=>t===T_WALK||t===T_PLAZA||t===T_GRASS;
export function randomNear(x,y,r,pred){
  for(let k=0;k<20;k++){const X=Math.floor(x+(Math.random()*2-1)*r),Y=Math.floor(y+(Math.random()*2-1)*r);if(X<0||Y<0||X>=N||Y>=N)continue;const t=M.tile[Y*N+X];if(M.walk[Y*N+X]&&(!pred||pred(t)))return {x:X+.5,y:Y+.5};}
  return null;
}
