/* Missão final feita à mão: "Torre Central".
   Praça fortificada (x 6–50, y 30–48) diante da torre; portão blindado (x 26–30, y 27–29).
   Átrio (x 16–40, y 11–26) entre as alas da torre, com o Juiz e dois pilares de escudo.
   Sala dos servidores do andar 90 (x 16–40, y 4–9) atrás de uma segunda porta (y 10). */
import {T_ROAD,T_WALK,T_PLAZA,RNG,pick,G} from '../core.js';

const SPAWN={x:28,y:54};
const RIVAL_POS={navalha:[18.5,24],sibila:[38,24.5],ferro:[22,13],mariposa:[34,13]};
function fill(B,r,x0,y0,x1,y1,skip){
  for(let y=y0;y<=y1;){
    const d=3+((r()*2)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      let ok=true;for(let yy=y;yy<y+d;yy++)for(let xx=x;xx<x+w;xx++)if(skip&&skip(xx,yy))ok=false;
      if(ok&&r()<.9)B.bld({x,y,w,d,fl:4+((r()*8)|0),pal:(r()*4)|0,v:(r()*4)|0,neon:r()<.5?((r()*4)|0):-1,sign:r()<.25?pick(['HOTEL','BANCO','CLÍNICA','BAR'],r):null,signCol:pick(['#38e8ff','#ffb13d','#ff3d8b'],r),roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
export const TORRE={
  nome:'Torre Central',
  spawn:SPAWN,
  build(B){
    const r=RNG(9999);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_ROAD,0,50,56,51);B.rect(T_ROAD,2,0,3,49);B.rect(T_ROAD,53,0,54,49);
    B.rect(T_PLAZA,6,30,50,48);
    // a torre
    const corp={pal:4,corp:true,ant:true,neon:0};
    B.bld(Object.assign({x:6,y:1,w:45,d:3,fl:22,v:1,sign:'HÉLICE',signCol:'#ff3d5a'},corp));
    B.bld(Object.assign({x:6,y:4,w:10,d:23,fl:18,v:2,sign:'TORRE CENTRAL',signCol:'#ff3d5a'},corp));
    B.bld(Object.assign({x:41,y:4,w:10,d:23,fl:18,v:3},corp));
    B.bld(Object.assign({x:6,y:27,w:20,d:3,fl:7,v:1,sign:'CONSÓRCIO HÉLICE',signCol:'#ff3d5a'},corp));
    B.bld(Object.assign({x:31,y:27,w:20,d:3,fl:7,v:2},corp));
    const wall=(x,y,w,d)=>B.bld({x,y,w,d,fl:1,style:'wall',kiosk:true});
    B.m.door=wall(26,27,5,3);
    // átrio e sala dos servidores
    B.rect(T_PLAZA,16,4,40,26);
    wall(16,10,10,1);wall(31,10,10,1);B.m.srvDoor=wall(26,10,5,1);
    for(const [x,y] of [[20,21],[36,21],[24,16],[32,16]])B.bld(Object.assign({x,y,w:1,d:1,fl:9,v:0},corp));
    for(const y of [5,8])for(const x of [18,20,22,24,32,34,36,38])B.bld({x,y,w:1,d:1,fl:1,pal:5,kiosk:true,neon:1});
    B.term({x:28.5,y:6.5,prog:0,done:false,flag:'srv',msg:'Servidores do andar 90 sob controle da Ônix.'});
    for(const [x,y] of [[19.5,13.5],[36.5,13.5]]){const p=B.unit('torre',x,y);p.pylon=true;p.hp=p.maxHp=150;p.armor=.35;p.acc=.45;}
    B.m.sweep=B.laser(16.1,12,39.9,12,{off:true,dmg:45,sweep:{ax:'y',a:11.6,b:25.4,spd:2.6}});
    // praça fortificada
    for(const [x,y,w,d] of [[14,40,3,1],[22,37,3,1],[31,37,3,1],[39,40,3,1],[18,44,2,1],[36,44,2,1],[26,42,4,1],[12,34,2,1],[42,34,2,1]])wall(x,y,w,d);
    B.term({x:7.6,y:31.4,prog:0,done:false,flag:'sec1',msg:'Terminal de segurança oeste invadido.'});
    B.term({x:49.4,y:31.4,prog:0,done:false,flag:'sec2',msg:'Terminal de segurança leste invadido.'});
    for(const [x,y] of [[44,31.5],[23.5,31.4],[33.5,31.4]]){const t=B.unit('torre',x,y);t.acc=.5;}
    for(const [x,y] of [[26.5,32.5],[30.5,32.5]]){const h=B.heavy(x,y,9);h.acc=.3;h.hp=h.maxHp=340;h.home={x,y};}
    for(const [x,y] of [[10,38],[46,38],[20,34],[36,34],[28,39.5],[16,46.5],[40,46.5]]){const g=B.unit('guarda',x,y);B.arm(g,9);g.home={x,y};}
    for(const [x,y] of [[20,6.5],[36,6.5]]){const g=B.unit('guarda',x,y);B.arm(g,9);g.home={x,y};}
    B.drone(8,32.5,[{x:8,y:32.5},{x:48,y:32.5}],9);B.drone(46,45,[{x:46,y:45},{x:10,y:45}],9);
    B.cam(6.6,47.4,-Math.PI/4,{sweep:.7});B.cam(49.4,47.4,-3*Math.PI/4,{sweep:.7});
    // cidade ao sul
    fill(B,r,5,52,51,56,(x,y)=>x>=24&&x<=32);
    // luzes
    for(let x=8;x<50;x+=7){B.lamp(x+.5,30.6,'#ff3d5a',true);B.lamp(x+.5,48.4,'#cfe8ff',true);}
    for(const [x,y] of [[16.6,12],[39.4,12],[16.6,25.4],[39.4,25.4],[28,20]])B.lamp(x,y,'#ff3d5a',true);
    for(const [x,y] of [[17,4.6],[39.4,4.6],[28,9.4]])B.lamp(x,y,'#38e8ff');
    for(const [x,y] of [[20,40],[36,40],[28,46]])B.prop(x,y);
    for(let k=0;k<12;k++){const p=B.randTile((t,x,y)=>t===T_WALK&&y>=49);if(p)B.unit('civil',p.x,p.y);}
    B.lanes([{y:50.5,dx:1,dy:0},{y:51.5,dx:-1,dy:0}],6);
    B.m.paint=(g,TS)=>{
      g.fillStyle='rgba(255,61,90,.18)';for(let x=6;x<=50;x+=2)g.fillRect(x*TS,30*TS,TS,TS*.25);
      for(let y=11;y<=26;y++)for(let x=16;x<=40;x++){g.fillStyle=(x+y)%2?'#22232c':'#1a1b22';g.fillRect(x*TS+1,y*TS+1,TS-2,TS-2);}
      g.strokeStyle='rgba(255,61,90,.55)';g.lineWidth=3;g.beginPath();g.arc(28.5*TS,18.5*TS,4.5*TS,0,Math.PI*2);g.stroke();
      for(let y=4;y<=9;y++)for(let x=16;x<=40;x++){g.fillStyle='rgba(56,232,255,.06)';g.fillRect(x*TS+2,y*TS+2,TS-4,TS-4);}
    };
  },
  *script(S,M){
    S.obj('gate','Invada os dois terminais de segurança da praça (0/2)',{primary:true});
    S.fork(watchGate(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m9_intro1');yield S.camTo({x:28,y:38},.8,3.2);yield S.talkDone();
    S.say('ctl:m9_intro2');yield S.camTo({x:28,y:28},1.0,2.4);yield S.talkDone();
    S.say('ctl:m9_intro3');yield S.camTo({x:28,y:15},.85,2.6);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
  },
};
function* watchGate(S,M){
  let last=-1;
  for(;;){
    const n=(M.flags.sec1?1:0)+(M.flags.sec2?1:0);
    if(n!==last){last=n;S.setObj('gate',{text:`Invada os dois terminais de segurança da praça (${n}/2)`});if(n===1)S.say('ctl:m9_term');}
    if(n>=2)break;
    yield S.wait(.3);
  }
  S.setObj('gate',{state:'done'});
  S.say('ctl:m9_breach');
  S.breach(M.door);
  yield S.wait(.4);
  S.fork(boss(S,M));
}
function* boss(S,M){
  const j=S.rival('juiz',28.5,16)||{dead:true,hp:0,maxHp:1};
  if(!j.dead){j.hp=j.maxHp=520;j.acc=.75;}
  j.boss=true;j.shield=true;j.home={x:28.5,y:18.5};M.boss=j;
  const others=Object.keys(RIVAL_POS).filter(id=>!(G&&G.rivais&&G.rivais[id]&&G.rivais[id].morto)).length;
  S.fork(rivalWaves(S,M,j));
  S.obj('juiz','Elimine o Juiz',{primary:true});
  S.obj('pyl','Derrube ou invada os pilares de escudo do átrio (0/2)');
  S.say('ctl:m9_juiz');
  S.fork(watchPylons(S,M,j));
  if(others)S.fork((function*(){yield S.wait(3);S.say('ctl:m9_rivals');})());
  yield S.until(()=>j.dead||j.hp<=j.maxHp*.66);
  if(!j.dead){S.say('ctl:m9_reinf');for(const [x,y] of [[Math.random()<.5?17:39.5,12]]){const h=S.spawn('inimigo',x,y,9);h.heavy=true;h.w='serra';h.mun=220;h.hp=h.maxHp=340;h.armor=.5;h.spd=1.35;h.nades=0;h.acc=.3;h.coat='#2a2c34';h.trim='#ffb13d';h.alerted=true;h.r3rebuild=true;}}
  yield S.until(()=>j.dead||j.hp<=j.maxHp*.4);
  if(!j.dead){M.sweep.off=false;S.say('ctl:m9_laser');S.log('Um feixe de contenção varre o átrio: ele queima quem tocar.','red');}
  yield S.until(()=>j.dead);
  M.sweep.off=true;
  S.setObj('juiz',{state:'done'});if(S.objState('pyl')==='active')S.setObj('pyl',{state:'failed'});
  yield S.wait(1.5);
  S.say('ctl:m9_servers');
  S.breach(M.srvDoor);
  S.obj('srv','Cheguem ao terminal dos servidores do andar 90 antes que sejam apagados',{primary:true});
  S.timer('VARGA APAGA OS SERVIDORES EM',60);
  for(const g of M.units)if(g.kind==='guarda'&&!g.dead&&g.y<10){g.alerted=true;}
  yield S.until(()=>M.flags.srv||S.timerDone());
  S.clearTimer();
  if(M.flags.srv){S.setObj('srv',{state:'done'});S.say('ctl:m9_win');S.win('A Torre Central caiu. Os servidores do andar 90 estão nas mãos da Ônix.');}
  else{M.flags.wiped=true;S.setObj('srv',{state:'failed'});S.say('ctl:m9_wiped');S.win('A Torre Central caiu, mas Ilse Varga apagou os servidores do andar 90.');}
}
function* rivalWaves(S,M,j){
  for(const id of Object.keys(RIVAL_POS)){
    if(j.dead)return;
    const p=RIVAL_POS[id],u=S.rival(id,p[0],p[1],.5);
    if(!u)continue;u.home={x:p[0],y:p[1]};
    yield S.wait(20);
  }
}
function* watchPylons(S,M,j){
  const pyl=M.units.filter(u=>u.pylon);let last=-1;
  for(;;){
    const n=pyl.filter(p=>p.dead||p.fac==='player').length;
    if(n!==last){last=n;S.setObj('pyl',{text:`Derrube ou invada os pilares de escudo do átrio (${n}/2)`});}
    if(n>=2||j.dead)break;
    yield S.wait(.3);
  }
  if(j.dead)return;
  j.shield=false;S.setObj('pyl',{state:'done'});S.say('ctl:m9_shield');S.log('O escudo do Juiz caiu.','green');
}
