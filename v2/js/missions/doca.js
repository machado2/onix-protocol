/* Missão feita à mão: "Doca dos Dirigíveis" — Cais Aéreo.
   Terminal aéreo em terra (oeste/sul), três píeres sobre a baía ligados por uma passarela (x 22–24).
   O dirigível de carga está amarrado no píer central (y 19–22); prancha de embarque em GANG.
   Oito agentes da célula (dois pesados). O dirigível parte em 4 minutos; no último minuto a célula corre para embarcar. */
import {T_ROAD,T_WALK,T_PLAZA,T_WATER,T_POST,RNG,pick} from '../core.js';

const SPAWN={x:2.5,y:53.5},GANG={x:45,y:19.5};
const DEPART=240;
const SIGNS=['HOTEL','CÂMBIO','BAR','PEÇAS','LOJA FRANCA'];
function fill(B,r,x0,y0,x1,y1){
  for(let y=y0;y<=y1;){
    const d=3+((r()*3)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      if(r()<.88)B.bld({x,y,w,d,fl:3+((r()*6)|0),pal:(r()*4)|0,v:(r()*4)|0,neon:r()<.4?((r()*4)|0):-1,sign:r()<.3?pick(SIGNS,r):null,signCol:pick(['#38e8ff','#ffb13d','#ff3d8b'],r),roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
export const DOCA={
  nome:'Doca dos Dirigíveis',
  spawn:SPAWN,
  build(B){
    const r=RNG(8181);
    B.rect(T_WATER,0,0,56,56);
    B.rect(T_WALK,0,0,21,56);B.rect(T_WALK,0,41,56,56);
    B.rect(T_ROAD,0,47,56,48);B.rect(T_ROAD,4,0,5,46);
    // terminal e saguão
    B.bld({x:8,y:5,w:12,d:11,fl:6,pal:2,v:1,neon:1,sign:'TERMINAL AÉREO',signCol:'#38e8ff'});
    B.rect(T_PLAZA,7,17,20,39);
    for(const [x,y] of [[10,22],[16,22],[10,30],[16,30]])B.bld({x,y,w:1,d:1,fl:1,pal:5,neon:(x+y)%4,kiosk:true});
    B.bld({x:24,y:41,w:10,d:5,fl:3,style:'ware',sign:'HANGAR 2',signCol:'#ffb13d'});
    B.bld({x:38,y:41,w:10,d:5,fl:3,style:'ware',sign:'CARGA AÉREA',signCol:'#38e8ff'});
    fill(B,r,8,50,56,56);fill(B,r,8,0,20,3);
    // píeres
    B.pier(22,6,24,40);B.pier(25,7,50,10);B.pier(25,19,54,22);B.pier(25,31,50,34);
    const CONT=[[28,8,3,1,2],[34,9,3,1,1],[42,8,3,1,2],[28,20,3,1,1],[34,21,2,1,2],[49,21,2,1,1],[28,32,3,1,2],[37,33,3,1,1],[44,32,2,1,3]];
    CONT.forEach(([x,y,w,d,fl],i)=>B.bld({x,y,w,d,fl,style:'cont',col:i%6}));
    // dirigível, mastro e prancha
    B.tile(54,20,T_POST);
    B.decor({type:'airship',x:43,y:14.5,h:6.5,len:15,text:'HÉLICE CARGA',col:'#ff3d5a',mx:54.5,my:20.5});
    B.decor({type:'pipe',x1:GANG.x,y1:19.2,x2:GANG.x,y2:15.6,h:3.6,r:.3,col:'#3a404e'});
    B.term({x:53.4,y:21.6,prog:0,done:false,flag:'amarras',msg:'Amarras travadas: o dirigível não pode partir.'});
    // torretas
    for(const [x,y] of [[52.5,19.5],[49.5,33.5]]){const t=B.unit('torre',x,y);t.acc=.4;}
    // luzes
    for(let x=26;x<52;x+=6){B.lamp(x+.5,7.3,'#cfe8ff');B.lamp(x+.5,19.3,'#cfe8ff');B.lamp(x+2.5,22.7,'#7fe3ff');B.lamp(x+.5,31.3,'#cfe8ff');}
    for(let y=8;y<40;y+=7)B.lamp(21.6,y+.5,'#ffcf7a',true);
    for(const [x,y] of [[8,18],[19,18],[8,38],[19,38],[13.5,27]])B.lamp(x,y,'#ffd99a');
    for(let x=2;x<56;x+=8)B.lamp(x+.5,46.4,'#ffcf7a');
    for(const [x,y] of [[26,9.5],[31,21.6],[40,31.6],[23,40]])B.prop(x,y);
    B.cam(21.4,12.4,0,{sweep:.7});B.cam(21.4,28.4,0,{sweep:.7});
    // a célula
    const cell=[];
    for(const [x,y] of [[30,21.6],[41,21.6],[23.5,14],[33,7.6]]){const e=B.unit('inimigo',x,y);B.arm(e,6);e.home={x,y};cell.push(e);}
    for(const [x,y] of [[39,21.6],[47,21.4]]){const h=B.heavy(x,y,6);h.home={x,y};h.acc=.3;h.hp=h.maxHp=340;cell.push(h);}
    for(const u of cell)u.cell=true;
    // segurança e polícia
    for(const [x,y] of [[19.5,21],[19.5,33],[30,33.6],[38,9.6]]){const g=B.unit('guarda',x,y);B.arm(g,6);g.home={x,y};}
    for(const [x,y] of [[12,45.6],[30,45.6],[5.5,30]])B.unit('policia',x,y);
    // passageiros e estivadores
    for(let k=0;k<26;k++){const p=B.randTile((t,x,y)=>t===T_PLAZA&&x>=7&&x<=20&&y>=17);if(p){const c=B.unit('civil',p.x,p.y);c.home={x:p.x,y:p.y};}}
    for(let k=0;k<8;k++){const p=B.randTile((t,x,y)=>t===T_PLAZA&&x>24);if(p){const u=B.unit('civil',p.x,p.y);u.worker=true;u.coat='#d0701c';u.trim='#f2d040';u.helmet=true;u.umb=null;u.home={x:p.x,y:p.y};}}
    for(let k=0;k<10;k++){const p=B.randTile((t,x,y)=>t===T_WALK&&y>=49);if(p)B.unit('civil',p.x,p.y);}
    B.lanes([{y:47.5,dx:1,dy:0},{y:48.5,dx:-1,dy:0}],7);
    B.m.paint=(g,TS)=>{
      g.fillStyle='rgba(216,176,32,.5)';
      for(let x=25;x<54;x+=1.5){g.fillRect(x*TS,19.1*TS,TS*.7,3);g.fillRect(x*TS,22.8*TS,TS*.7,3);}
      g.fillStyle='rgba(255,61,90,.35)';g.fillRect((GANG.x-.8)*TS,19*TS,1.6*TS,1.2*TS);
    };
  },
  *script(S,M){
    M.cell=M.units.filter(u=>u.cell);
    S.obj('kill','Elimine a célula do Consórcio (0/6)',{primary:true});
    S.obj('moor','Opcional: trave as amarras do dirigível (ponta do píer central)');
    S.fork(watchKills(S,M));S.fork(watchMoor(S,M));S.fork(watchHeavy(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m8_intro1');yield S.camTo({x:40,y:17},.9,3.2);yield S.talkDone();
    S.say('ctl:m8_intro2');yield S.camTo(GANG,1.2,2.4);yield S.talkDone();
    S.say('ctl:m8_intro3');yield S.camTo({x:52,y:20.5},1.15,2.2);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
    S.fork(watchDeparture(S,M));
  },
};
const alive=M=>M.cell.filter(u=>!u.dead&&!u.follower);
function* watchKills(S,M){
  let last=-1;
  for(;;){
    const dead=M.cell.filter(u=>(u.dead&&!u.vanished)||u.follower).length;
    if(dead!==last){last=dead;S.setObj('kill',{text:`Elimine a célula do Consórcio (${dead}/6)`});}
    if(M.flags.escaped){S.say('ctl:m8_fail');S.fail('Um agente da célula embarcou no dirigível.');return;}
    if(dead>=6)break;
    yield S.wait(.3);
  }
  S.setObj('kill',{state:'done'});S.clearTimer();
  S.say('ctl:m8_win');
  S.win('A célula do Consórcio no Cais Aéreo foi eliminada.');
}
function* watchDeparture(S,M){
  S.timer('DIRIGÍVEL PARTE EM',DEPART);
  yield S.until(()=>M.flags.amarras||M.ended||M.t>=M.timer.end-60);
  if(M.flags.amarras||M.ended)return;
  S.say('ctl:m8_board');S.log('A célula está correndo para a prancha de embarque!','red');
  for(const u of alive(M)){u.fleeTo={x:GANG.x+(Math.random()-.5)*.6,y:GANG.y+.4};u.path=null;u.alerted=true;}
  let riv=null;for(const id of ['navalha','mariposa','sibila']){riv=S.rival(id,23.5,20.5,.85);if(riv)break;}
  if(riv){S.obj('riv',`Opcional: elimine ${riv.nome}`);S.fork(watchRival(S,M,riv));}
  yield S.until(()=>M.flags.amarras||M.ended||S.timerDone());
  if(M.flags.amarras||M.ended)return;
  S.clearTimer();M.flags.airshipGo=true;if(S.objState('moor')==='active')S.setObj('moor',{state:'failed'});
  for(const u of M.cell)if(u.fleeTo){u.fleeTo=null;u.path=null;}
  S.say('ctl:m8_gone');S.log('O dirigível partiu sem a célula.','amber');
}
function* watchMoor(S,M){
  yield S.until(()=>M.flags.amarras);
  if(!M.flags.airshipGo){S.clearTimer();S.setObj('moor',{state:'done'});S.bonus('Dirigível retido no cais',1000);S.say('ctl:m8_moor');for(const u of M.cell)if(u.fleeTo){u.fleeTo=null;u.path=null;}}
}
function* watchHeavy(S,M){
  yield S.until(()=>M.cell.some(u=>u.heavy&&u.contact));
  S.say('ctl:m8_heavy');
}
function* watchRival(S,M,riv){
  yield S.until(()=>riv.dead);
  S.setObj('riv',{state:riv.vanished?'failed':'done'});
}
