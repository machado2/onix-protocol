/* Missão feita à mão: "Maré Baixa" — Docas Velhas.
   Halvard Reis chega em comboio ao porto para encontrar um contrabandista.
   Mapa: mar ao norte (y<11), pátio de contêineres cercado (y 11–31), cidade ao sul (y>32). */
import {T_ROAD,T_WALK,T_PLAZA,T_WATER,T_FENCE,T_POST,RNG} from '../core.js';

const SPAWN={x:6.5,y:40.5};
const DROP={x:28.5,y:16.25};
const CONTAINERS=[
  // pátio oeste
  [2,13,1,3,2],[4,13,3,1,3],[4,15,3,1,1],[8,13,1,3,2],[13,14,3,1,2],[18,13,1,3,2],[20,13,3,1,1],[20,15,3,1,2],[24,14,1,3,1],
  [17,20,1,3,2],[19,19,3,1,1],[19,22,3,1,2],[23,20,1,3,1],[2,19,1,3,1],
  [2,27,3,1,2],[7,28,3,1,2],[7,30,3,1,1],[11,29,1,3,3],[13,28,3,1,1],[17,27,1,3,2],[19,29,3,1,2],[23,27,3,1,1],[23,30,3,1,3],
  // pátio leste
  [34,13,3,1,2],[34,15,3,1,1],[38,13,1,3,3],[40,13,3,1,1],[40,15,3,1,2],[46,13,3,1,2],[46,15,1,3,1],[50,13,3,1,3],[50,16,3,1,1],
  [34,20,1,3,2],[35,24,3,1,1],[34,28,3,1,2],[38,28,1,3,1],[41,29,3,1,2],[46,28,1,3,3],[49,28,3,1,1],[49,30,3,1,2],[52,20,1,3,2],[50,23,3,1,1],
];
const CITY=[
  {x:1,y:34,w:4,d:8,fl:5,pal:0},
  {x:8,y:34,w:7,d:4,fl:7,pal:1,neon:1},
  {x:8,y:39,w:7,d:3,fl:3,pal:3,neon:2,sign:'BAR DO PORTO',signCol:'#ffb13d'},
  {x:16,y:34,w:5,d:8,fl:4,pal:2,sign:'PENHORES',signCol:'#38e8ff'},
  {x:22,y:35,w:4,d:6,fl:9,pal:0,ant:true},
  {x:33,y:34,w:6,d:8,fl:6,pal:1,sign:'HOTEL MARÉ',signCol:'#ff3d8b'},
  {x:40,y:35,w:6,d:6,fl:10,pal:2,neon:0,ant:true},
  {x:47,y:34,w:8,d:4,fl:3,pal:3,sign:'PEIXARIA',signCol:'#38e8ff'},
  {x:47,y:39,w:8,d:3,fl:5,pal:0},
  {x:1,y:47,w:6,d:8,fl:8,pal:2,neon:3},
  {x:9,y:48,w:8,d:6,fl:5,pal:0,sign:'FARMÁCIA 24H',signCol:'#5dffa0'},
  {x:19,y:47,w:7,d:4,fl:11,pal:1,neon:1,ant:true},
  {x:32,y:47,w:9,d:5,fl:6,pal:3,sign:'KARAOKÊ',signCol:'#ff3d8b'},
  {x:43,y:48,w:6,d:7,fl:9,pal:0,neon:0},
  {x:51,y:47,w:5,d:9,fl:4,pal:2},
];

export const DOCAS={
  nome:'Maré Baixa',
  spawn:SPAWN,
  build(B){
    const r=RNG(4242);
    B.rect(T_WALK,0,33,56,56);
    B.rect(T_WATER,0,0,56,10);
    B.rect(T_PLAZA,0,11,56,31);
    B.pier(8,4,10,10);B.pier(41,2,44,10);
    for(let x=0;x<=56;x++)if(x!==5&&x!==28&&x!==29)B.tile(x,32,T_FENCE);
    B.rect(T_ROAD,28,12,29,56);B.rect(T_ROAD,0,44,56,45);
    // prédios
    CITY.forEach(b=>B.bld(Object.assign({v:(r()*4)|0,ou:(r()*8)|0,ov:(r()*8)|0,roof:(r()*3)|0},b)));
    B.bld({x:30,y:33,w:1,d:1,fl:2,pal:4,v:1,neon:0});
    B.bld({x:6,y:19,w:10,d:6,fl:3,style:'ware',sign:'ARMAZÉM 7',signCol:'#ffb13d'});
    B.bld({x:40,y:21,w:8,d:6,fl:6,pal:4,v:2,neon:0,sign:'HÉLICE',signCol:'#ff3d5a',corp:true,ant:true});
    CONTAINERS.forEach(([x,y,w,d,fl],i)=>B.bld({x,y,w,d,fl,style:'cont',col:i%6}));
    // guindastes (pernas bloqueiam a passagem, não a visão)
    for(const [x,y] of [[12,12],[16,12],[12,17],[16,17],[26,13],[31,13],[26,18],[31,18]])B.tile(x,y,T_POST);
    B.decor({type:'crane',x0:12,y0:12,x1:16,y1:17,col:'#c8501e',hang:{x:14.5,y:7}});
    B.decor({type:'crane',x0:26,y0:13,x1:31,y1:18,col:'#d8a020',hang:{x:DROP.x,y:DROP.y},main:true});
    B.decor({type:'boat',x:46.6,y:4.6});
    B.decor({type:'barrier',x:30.2,y:32.5});
    B.decor({type:'van',x:6.5,y:36.6,ang:Math.PI/2});
    B.term({x:32.6,y:18.7,prog:0,done:false,crane:true});
    // luzes
    for(const [x,y,c] of [[10,18.5,'#ffd27a'],[22,18,'#ffd27a'],[33,19.5,'#cfe8ff'],[48,18,'#ffd27a'],[20,26,'#cfe8ff'],[36,27,'#ffd27a'],[10,30.5,'#ffd27a'],[45,30.5,'#cfe8ff'],[24,11.5,'#cfe8ff'],[38,11.5,'#ffd27a'],[9,10,'#ffd27a'],[42,9,'#ffd27a']])B.lamp(x,y,c,true);
    for(const x of [4,12,20,34,42,50])B.lamp(x+.5,43.5,'#ffb35c');
    for(const x of [8,16,24,38,46,54])B.lamp(x+.5,46.5,r()<.3?'#7fe3ff':'#ffb35c');
    for(const y of [36,40,50,54])B.lamp(27.5,y+.5,'#ffb35c');
    for(const y of [38,52])B.lamp(30.5,y+.5,'#ff6ad5');
    for(const [x,y] of [[3,43],[13,43],[37,43],[52,43]])B.tree(x+.5,y+.5);
    for(const [x,y] of [[25,16],[32.5,15.2],[39,20],[21,24.5],[36.5,26],[3,25],[51,26]])B.prop(x,y);
    // gente
    const workers=[[12,26],[20,24.5],[4,24],[36,17],[44,17.5],[18,30.5]];
    workers.forEach(([x,y])=>{const u=B.unit('civil',x+.5,y+.5);u.worker=true;u.coat='#d0701c';u.trim='#f2d040';u.helmet=true;u.umb=null;u.home={x:x+.5,y:y+.5};});
    const sm=B.unit('civil',11.5,26.4);sm.coat='#2a2420';sm.trim='#8a7a60';sm.long=true;sm.umb=null;sm.still=true;sm.face=-Math.PI/2;sm.nome='Contrabandista';B.m.smuggler=sm;
    for(const [x,y,h] of [[27.2,31.2,1],[30.8,31.2,1],[20,20.5,0],[33.5,23.5,0],[45,19.5,0],[14,27.5,0],[39,27.5,0]]){
      const g=B.unit('guarda',x,y);B.arm(g,1);g.home={x,y};
    }
    B.unit('torre',39.5,24.5);
    B.unit('policia',14.5,43.5);B.unit('policia',40.5,46.5);
    for(let k=0;k<24;k++){const p=B.randTile((t,x,y)=>t===T_WALK&&y>=42);if(p)B.unit('civil',p.x,p.y);}
    B.lanes([{y:44.5,dx:1,dy:0},{y:45.5,dx:-1,dy:0}],6);
    B.m.escape={x:43,y:3};
    B.m.dropPoint=DROP;
  },
  *script(S,M){
    S.obj('kill','Elimine Halvard Reis',{primary:true});
    S.obj('crane','Opcional: invada a cabine do guindaste 2 e solte o contêiner sobre o alvo');
    S.obj('union','Opcional: recrute 4 estivadores com a Sonda (0/4)');
    S.fork(watchUnion(S,M));S.fork(watchAlarm(S,M));S.fork(watchKill(S,M));
    // abertura
    S.cine(true);
    yield S.camTo(SPAWN,1.25,.01);
    yield S.wait(.7);
    S.say('ctl:m1_intro1');yield S.camTo({x:29,y:37},1.0,3);yield S.talkDone();
    S.say('ctl:m1_intro2');yield S.camTo({x:DROP.x,y:DROP.y},1.15,3);yield S.talkDone();
    S.say('ctl:m1_intro3');yield S.camTo({x:6,y:31},1.15,2.4);yield S.talkDone();
    yield S.camTo(SPAWN,1.25,1.6);
    S.cine(false);
    S.timer('Comboio chega em',70);
    yield S.until(()=>S.timerDone());
    S.clearTimer();
    // comboio
    S.say('ctl:m1_convoy');
    const cols=['#121318','#1c1c24','#121318'],stops=[14,DROP.y,18.8],cars=[];
    for(let i=0;i<3;i++){const c=S.car(28.5,56.3,-Math.PI/2,cols[i],i===1?170:120);c.limo=i===1;S.drive(c,[{x:28.5,y:stops[i]}]);cars.push(c);yield S.wait(1.1);}
    M.convoy=cars;
    yield S.until(()=>cars.every(c=>c.dead||(!c.path&&c.cur<.4)));
    for(const c of [cars[0],cars[2]])if(!c.dead)for(let k=0;k<1;k++){const g=S.spawn('guarda',c.x+(k?.95:-.95),c.y+.2,2);g.home={x:c.x+(k?1.6:-1.6),y:c.y};}
    yield S.wait(1.4);
    const limo=cars[1];
    const vip=S.spawn('vip',limo.x+.95,limo.y);vip.nome='Diretor Halvard Reis';vip.scripted=true;M.vip=vip;
    for(let k=0;k<2;k++){const g=S.spawn('guarda',limo.x+.95,limo.y+(k?.8:-.8),2);g.escort=vip;}
    if(limo.dead){vip.hp=0;vip.dead=true;return;}
    S.say('ctl:m1_arrive');
    vip.face=Math.PI;yield S.wait(2.2);
    if(vip.dead)return;
    if(!M.corpAlert)S.walk(vip,11.5,25.5);
    yield S.until(()=>vip.dead||M.corpAlert||!vip.path);
    if(vip.dead||M.corpAlert)return;
    vip.face=Math.PI/2;S.say('vip:meet',vip);yield S.wait(3);S.say('civ:smug',M.smuggler);
  },
};

function* watchKill(S,M){
  // fim do encontro: se nada acontecer em 30 s, Reis vai embora
  yield S.until(()=>M.vip);
  const vip=M.vip,limo=M.convoy[1];
  S.fork(leave(S,M,vip,limo));
  yield S.until(()=>vip.dead);
  S.setObj('kill',{state:'done'});
  if(M.flags.accident){S.setObj('crane',{state:'done'});S.bonus('Acidente de trabalho',4000);S.say('ctl:m1_accident');yield S.talkDone();}
  else if(S.objState('crane')==='active')S.setObj('crane',{state:'failed'});
  S.obj('exfil','Volte à van de extração com todo o esquadrão',{primary:true});
  S.say('ctl:m1_exfil');
  if(!M.flags.reinf)S.fork(reinforce(S,M));
  yield S.until(()=>{const al=M.agents.filter(a=>!a.dead);return al.length>0&&al.every(a=>{const p=a.inCar||a;return Math.hypot(p.x-SPAWN.x,p.y-SPAWN.y)<3.4;});});
  S.setObj('exfil',{state:'done'});
  S.win('Halvard Reis foi eliminado nas Docas Velhas e o esquadrão saiu do porto.');
}
function* leave(S,M,vip,limo){
  yield S.until(()=>vip.dead||M.corpAlert||(!vip.path&&Math.hypot(vip.x-11.5,vip.y-25.5)<1.5));
  if(vip.dead||M.corpAlert)return;
  yield S.wait(30);
  if(vip.dead||M.corpAlert)return;
  S.say('ctl:m1_leaving');
  if(limo.dead)return;
  S.walk(vip,limo.x+.95,limo.y);
  yield S.until(()=>vip.dead||M.corpAlert||!vip.path);
  if(vip.dead||M.corpAlert||limo.dead)return;
  vip.inCar=limo;limo.occ.push(vip);
  yield S.wait(1.5);
  const cars=M.convoy;
  for(const c of [cars[2],cars[1],cars[0]]){if(!c.dead)S.drive(c,[{x:28.5,y:56.6}]);yield S.wait(.9);}
  yield S.until(()=>vip.dead||limo.dead||limo.y>55.6);
  if(vip.dead||limo.dead)return;
  S.say('ctl:m1_gone');
  S.fail('O comboio deixou o porto levando Halvard Reis.');
}
function* watchAlarm(S,M){
  yield S.until(()=>M.corpAlert);
  if(M.vip&&!M.vip.dead)S.say('ctl:m1_boat');
  yield S.wait(22);
  if(!M.flags.reinf)yield* reinforce(S,M);
}
function* reinforce(S,M){
  M.flags.reinf=true;
  S.say('ctl:m1_reinf');
  const van=S.car(28.5,56.3,-Math.PI/2,'#2a2d34',140);S.drive(van,[{x:28.5,y:34.6}]);
  yield S.until(S.arrived(van));
  if(van.dead)return;
  for(let k=0;k<3;k++){const e=S.spawn('inimigo',van.x+(k-1)*.9,van.y-1,3);e.alerted=true;e.home={x:28.5,y:28};}
}
function* watchUnion(S,M){
  let last=-1;
  for(;;){
    const n=M.units.filter(u=>u.worker&&u.follower&&!u.dead).length;
    if(n!==last){last=n;S.setObj('union',{text:`Opcional: recrute 4 estivadores com a Sonda (${Math.min(n,4)}/4)`});}
    if(n>=4){S.setObj('union',{state:'done'});S.bonus('Estivadores recrutados',2000);S.say('ctl:m1_union');return;}
    yield S.wait(.5);
  }
}
