/* Missão feita à mão: "Clube Cobalto" — Baixa Neon.
   Avenida de neon (y 28–29), Clube Cobalto com pista a céu aberto (x 34–44, y 11–19),
   beco de serviço ao norte com o carro de fuga. Cinco agentes disfarçados entre os civis. */
import {T_ROAD,T_WALK,T_PLAZA,RNG,pick} from '../core.js';

const SPAWN={x:2.5,y:31.5},ESC={x:54.5,y:5.5};
const SIGNS=['BAR','KARAOKÊ','MOTEL','SUSHI','CYBER','HOTEL','BOTECO'];
function fill(B,r,x0,y0,x1,y1,skip){
  for(let y=y0;y<=y1;){
    const d=3+((r()*3)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      let ok=true;for(let yy=y;yy<y+d;yy++)for(let xx=x;xx<x+w;xx++)if(skip&&skip(xx,yy))ok=false;
      if(ok&&r()<.9)B.bld({x,y,w,d,fl:3+((r()*8)|0),pal:(r()*4)|0,v:(r()*4)|0,neon:r()<.7?((r()*4)|0):-1,sign:r()<.45?pick(SIGNS,r):null,signCol:pick(['#ff3d8b','#38e8ff','#ffb13d','#a66bff'],r),roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
const CELL_CLUB=[[36,14],[41.5,16],[39,18.2]],CELL_AVE=[[22,27],[44,31]];
export const NEON={
  nome:'Clube Cobalto',
  spawn:SPAWN,
  build(B){
    const r=RNG(5577);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_ROAD,0,28,56,29);B.rect(T_ROAD,10,0,11,56);B.rect(T_ROAD,12,5,56,6);
    // Clube Cobalto
    B.bld({x:30,y:8,w:14,d:3,fl:3,pal:4,v:2,neon:1,corp:false});
    B.bld({x:45,y:8,w:4,d:3,fl:3,pal:4,v:3,neon:1});
    B.bld({x:30,y:11,w:4,d:9,fl:2,pal:2,v:1,neon:0});
    B.bld({x:45,y:11,w:4,d:9,fl:2,pal:2,v:2,neon:3});
    B.bld({x:30,y:20,w:8,d:2,fl:2,pal:2,v:0,neon:1,sign:'CLUBE COBALTO',signCol:'#38e8ff'});
    B.bld({x:41,y:20,w:8,d:2,fl:2,pal:2,v:3,neon:1});
    B.rect(T_PLAZA,34,11,44,19);B.rect(T_PLAZA,44,8,44,10);
    B.bld({x:38,y:11,w:3,d:1,fl:1,pal:5,neon:1,kiosk:true});
    B.decor({type:'disco',x0:34,y0:11,x1:44,y1:19});
    // vizinhança
    fill(B,r,12,8,28,25,(x,y)=>x>=19&&x<=25&&y>=24);
    fill(B,r,12,0,56,3);
    fill(B,r,50,8,55,26);
    fill(B,r,0,32,9,54,(x,y)=>y<=34);fill(B,r,12,32,56,54,(x,y)=>y<=33);
    fill(B,r,0,0,9,26,(x,y)=>y>=24);
    B.decor({type:'billboard',x:22,y:26.4,w:5,h:3.4,text:'HÉLICE',sub:'VIVA MAIS. PENSE MENOS.',col:'#ff3d5a'});
    B.decor({type:'billboard',x:46,y:30.6,w:4.4,h:3,text:'NEURO+',sub:'IMPLANTES EM 12X',col:'#38e8ff'});
    B.decor({type:'billboard',x:16,y:30.6,w:4.4,h:3,text:'KARAOKÊ',sub:'ABERTO 24 HORAS',col:'#ffb13d'});
    // luzes
    for(let x=2;x<56;x+=5){B.lamp(x+.5,27.4,pick(['#ff6ad5','#7fe3ff','#ffb35c','#a66bff'],r));B.lamp(x+2.5,30.6,pick(['#ff6ad5','#7fe3ff','#ffb35c'],r));}
    B.lamp(39.5,22.5,'#38e8ff');B.lamp(44.5,7,'#ff6ad5');B.lamp(52,7,'#ffb35c');
    for(const [x,y] of [[33,23],[46,23],[47,4.5]])B.prop(x,y);
    // gente
    for(let k=0;k<26;k++){const c=B.unit('civil',34.6+Math.random()*9.8,11.8+Math.random()*7);c.dance=true;c.umb=null;}
    for(let k=0;k<34;k++){const c=B.unit('civil',1+Math.random()*54,Math.random()<.5?26.5+Math.random()*1.2:30.2+Math.random()*1.2);c.home={x:c.x,y:c.y};}
    for(let k=0;k<8;k++){const c=B.unit('civil',36+Math.random()*7,22.5+Math.random()*3);c.still=true;c.umb=null;}
    for(const [x,y] of [[14,27],[34,30.8],[50,27],[24,31]])B.unit('policia',x,y);
    for(const [x,y] of CELL_CLUB){const e=B.unit('inimigo',x,y);B.arm(e,3);B.disguise(e,true);e.home={x,y};}
    for(const [x,y] of CELL_AVE){const e=B.unit('inimigo',x,y);B.arm(e,3);B.disguise(e,false);e.home={x,y};}
    B.lanes([{y:28.5,dx:1,dy:0},{y:29.5,dx:-1,dy:0}],8);
    B.m.paint=(g,TS)=>{
      const cols=['#3a1046','#10304a','#4a1030','#123a2a'];
      for(let y=11;y<=19;y++)for(let x=34;x<=44;x++){g.fillStyle=cols[(x+y*2)%4];g.fillRect(x*TS+1,y*TS+1,TS-2,TS-2);g.fillStyle='rgba(255,255,255,.06)';g.fillRect(x*TS+3,y*TS+3,TS-6,3);}
    };
  },
  *script(S,M){
    S.obj('kill','Elimine os agentes infiltrados (0/5)',{primary:true});
    S.obj('civ','Opcional: no máximo 2 civis feridos');
    S.fork(watchKills(S,M));S.fork(watchCiv(S,M));S.fork(watchMariposa(S,M));S.fork(watchFlee(S,M));
    const car=S.car(ESC.x,ESC.y,Math.PI,'#121318',140);M.escCar=car;
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m4_intro1');yield S.camTo({x:26,y:28},1.0,3);yield S.talkDone();
    S.say('ctl:m4_intro2');yield S.camTo({x:39,y:15},1.2,2.8);yield S.talkDone();
    S.say('ctl:m4_intro3');yield S.camTo({x:50,y:6},1.15,2.4);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
  },
};
const cell=M=>M.units.filter(u=>u.cell);
function* watchKills(S,M){
  let last=-1;
  for(;;){
    const dead=cell(M).filter(u=>u.dead&&!u.vanished).length;
    if(dead!==last){last=dead;S.setObj('kill',{text:`Elimine os agentes infiltrados (${dead}/5)`});}
    if(M.flags.escaped){S.say('ctl:m4_fail');S.fail('Um agente da célula fugiu no carro do beco.');return;}
    if(dead>=5)break;
    yield S.wait(.3);
  }
  S.setObj('kill',{state:'done'});
  if(S.objState('civ')==='active'){S.setObj('civ',{state:'done'});S.bonus('Multidão preservada',2500);}
  S.say('ctl:m4_win');
  S.win('A célula do Consórcio na Baixa Neon foi eliminada.');
}
function* watchCiv(S,M){
  yield S.until(()=>M.stats.civis>2);
  S.setObj('civ',{state:'failed'});
}
function* watchMariposa(S,M){
  yield S.until(()=>(M.revealed||0)>=1||M.corpAlert);
  yield S.wait(8);
  const m=S.rival('mariposa',44.5,6,.85);
  if(m){m.home={x:39,y:15};S.obj('mari','Opcional: elimine a Mariposa');S.say('ctl:m4_mari');
    yield S.until(()=>m.dead);
    if(!m.vanished){S.setObj('mari',{state:'done'});}else S.setObj('mari',{state:'failed'});}
}
function* watchFlee(S,M){
  yield S.until(()=>{const alive=cell(M).filter(u=>!u.dead&&!u.follower);return M.corpAlert&&alive.length>0&&alive.length<=2&&cell(M).some(u=>u.dead);});
  S.say('ctl:m4_flee');S.log('Destruir o carro de fuga no beco impede a fuga.','amber');
  for(const u of cell(M))if(!u.dead&&!u.follower){if(u.disguise){u.disguise=false;u.dance=false;Object.assign(u,u.trueLook);u.r3rebuild=true;u.alerted=true;}u.fleeTo={x:ESC.x-1.2,y:ESC.y};u.path=null;}
}
