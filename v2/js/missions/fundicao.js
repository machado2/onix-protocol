/* Missão feita à mão: "Fundição" — Setor Industrial 9.
   Planta cercada (x 6–56, y 2–47) com portões a oeste (y 30–31) e ao sul (x 21–22).
   Três reatores (NO, centro, NE), tubulação com saídas de vapor, hangar de drones ao norte.
   Depois da terceira carga: 45 s para voltar ao portão de inserção antes da reação em cadeia. */
import {T_ROAD,T_WALK,T_BLD,T_FENCE,T_POST,RNG,pick} from '../core.js';

const SPAWN={x:3.5,y:53.5};
const REACT=[{x:13.5,y:10.5,f:'r1'},{x:37.5,y:20.5,f:'r2'},{x:50.5,y:8.5,f:'r3'}];
const SIGNS=['OFICINA','BAR','PENSÃO','PEÇAS','MERCEARIA'];
function fill(B,r,x0,y0,x1,y1){
  for(let y=y0;y<=y1;){
    const d=3+((r()*2)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      if(r()<.85)B.bld({x,y,w,d,fl:2+((r()*3)|0),pal:(r()*4)|0,v:(r()*4)|0,neon:r()<.3?((r()*4)|0):-1,sign:r()<.3?pick(SIGNS,r):null,signCol:pick(['#ffb13d','#38e8ff'],r),roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
export const FUNDICAO={
  nome:'Fundição',
  spawn:SPAWN,
  build(B){
    const r=RNG(9091);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_ROAD,0,50,56,51);B.rect(T_ROAD,0,30,56,31);B.rect(T_ROAD,21,0,22,51);
    // cerca da planta
    for(let y=2;y<=47;y++)if(y<30||y>31)B.tile(6,y,T_FENCE);
    for(let x=6;x<=56;x++)if(x<21||x>22)B.tile(x,47,T_FENCE);
    // reatores
    B.m.reactors=REACT.map(R=>{
      B.rect(T_BLD,Math.floor(R.x)-1,Math.floor(R.y)-1,Math.floor(R.x)+1,Math.floor(R.y)+1);
      const d={type:'reactor',x:R.x,y:R.y,r:1.35};B.decor(d);
      B.term({x:R.x,y:R.y+2.4,prog:0,done:false,flag:R.f,msg:'Carga instalada no reator.'});
      return Object.assign({d},R);
    });
    // galpões
    B.bld({x:8,y:20,w:7,d:5,fl:3,style:'ware',sign:'LAMINAÇÃO',signCol:'#ffb13d'});
    B.bld({x:25,y:3,w:8,d:4,fl:3,style:'ware',sign:'HANGAR DE DRONES',signCol:'#ff3d5a'});
    B.bld({x:47,y:15,w:8,d:6,fl:4,style:'ware',sign:'FORNO 3',signCol:'#ffb13d'});
    B.bld({x:8,y:34,w:11,d:7,fl:4,style:'ware',sign:'FUNDIÇÃO 9',signCol:'#ff8a3c'});
    B.bld({x:26,y:35,w:10,d:6,fl:3,style:'ware',sign:'LINGOTES',signCol:'#ffb13d'});
    B.bld({x:46,y:34,w:9,d:6,fl:3,style:'ware',sign:'EXPEDIÇÃO',signCol:'#38e8ff'});
    B.bld({x:40,y:33,w:3,d:2,fl:2,pal:1,v:2,neon:1,sign:'PRESSÃO',signCol:'#ff3d5a'});
    const CONT=[[16,20,3,1,2],[17,23,3,1,1],[8,4,3,1,2],[16,4,3,1,3],[25,12,3,1,2],[25,14,3,1,1],[29,24,1,3,2],[52,23,3,1,2],[10,43,3,1,2],[14,43,3,1,1],[38,42,3,1,2],[48,42,3,1,3],[30,43,3,1,1]];
    CONT.forEach(([x,y,w,d,fl],i)=>B.bld({x,y,w,d,fl,style:'cont',col:i%6}));
    // chaminés, tubulação e vapor
    for(const [x,y,h] of [[10.5,6.5,7.5],[35.5,5.5,8.5],[38.5,5.5,7]]){B.tile(Math.floor(x),Math.floor(y),T_POST);B.decor({type:'chimney',x,y,h});}
    B.decor({type:'pipe',x1:7,y1:17.5,x2:34,y2:17.5,h:2.4,r:.22,col:'#7a5a40'});
    B.decor({type:'pipe',x1:44.5,y1:3,x2:44.5,y2:28,h:2.6,r:.2,col:'#6a6a58'});
    B.decor({type:'pipe',x1:23,y1:28.5,x2:56,y2:28.5,h:2.2,r:.18,col:'#7a5a40'});
    let k=0;
    for(const [x,y] of [[9.5,17.5],[16.5,17.5],[25.5,17.5],[31.5,17.5],[44.5,7.5],[44.5,15.5],[44.5,24.5],[28.5,28.5],[40.5,28.5],[52.5,28.5]])B.vent(x,y,{per:7,ph:(k++)*1.7,dmg:45});
    B.term({x:41.5,y:35.8,prog:0,done:false,flag:'vapor',msg:'Controle de pressão invadido: todas as saídas de vapor vão disparar.'});
    // vizinhança fora da cerca
    fill(B,r,8,53,56,56);
    // luzes
    for(const [x,y] of [[8,15],[19.5,14],[24,10],[33,15],[42,10],[55,12.5],[24,26],[42,26],[55,26],[8,27],[19.5,33],[24,42],[38,32.5],[55,42],[12,45.5],[33,45.5]])B.lamp(x,y,'#ffb35c',true);
    for(let x=2;x<56;x+=7)B.lamp(x+.5,49.4,'#ffcf7a');
    for(const [x,y] of [[23.5,8],[34,26],[19.5,26],[45.5,45]])B.prop(x,y);
    B.decor({type:'van',x:26,y:44.6,ang:0});B.decor({type:'van',x:43,y:44.6,ang:Math.PI});
    // câmeras
    B.cam(10.6,8.6,Math.PI/4,{sweep:.7});B.cam(34.6,17.6,Math.PI/4,{sweep:.7});B.cam(53.4,11.4,-3*Math.PI/4,{sweep:.6});
    // segurança
    for(const [x,y] of [[11,13.5],[16.5,8],[48,11.5],[53.5,6],[34.5,18],[40.5,22.5],[8.5,28.5],[19.5,45],[24.5,45],[30.5,33.5],[44.5,41],[28.5,8.5]]){const g=B.unit('guarda',x,y);B.arm(g,4);g.home={x,y};}
    B.drone(13.5,6.5,[{x:9,y:6.5},{x:18.5,y:6.5},{x:18.5,y:15},{x:9,y:15}],4);
    B.drone(50.5,5,[{x:46.5,y:4.5},{x:55,y:4.5},{x:55,y:13},{x:46.5,y:13}],4);
    B.drone(30,30.5,[{x:24,y:30.5},{x:55,y:30.5}],4);
    // operários
    for(let n=0;n<14;n++){const p=B.randTile((t,x,y)=>t===T_WALK&&x>7&&y>3&&y<46);if(!p)continue;const u=B.unit('civil',p.x,p.y);u.worker=true;u.coat='#d0701c';u.trim='#f2d040';u.helmet=true;u.umb=null;u.home={x:p.x,y:p.y};}
    for(let n=0;n<10;n++){const p=B.randTile((t,x,y)=>t===T_WALK&&y>=52);if(p)B.unit('civil',p.x,p.y);}
    for(const [x,y] of [[10,52.4],[40,52.4]])B.unit('policia',x,y);
    B.lanes([{y:50.5,dx:1,dy:0},{y:51.5,dx:-1,dy:0}],6);
    B.m.paint=(g,TS)=>{
      g.fillStyle='rgba(30,22,12,.28)';g.fillRect(7*TS,3*TS,50*TS,44*TS);
      for(let i=0;i<60;i++){const x=7+Math.random()*49,y=3+Math.random()*43;g.fillStyle='rgba(8,8,10,.25)';g.beginPath();g.ellipse(x*TS,y*TS,6+Math.random()*16,3+Math.random()*9,Math.random()*3,0,Math.PI*2);g.fill();}
      for(const R of REACT){
        const x0=(Math.floor(R.x)-2)*TS,y0=(Math.floor(R.y)-2)*TS,S=5*TS;
        for(let s=0;s<S;s+=8){g.fillStyle=(s/8)%2?'#15161a':'#d8b020';g.fillRect(x0+s,y0,8,4);g.fillRect(x0+s,y0+S-4,8,4);g.fillRect(x0,y0+s,4,8);g.fillRect(x0+S-4,y0+s,4,8);}
      }
      g.fillStyle='rgba(216,176,32,.45)';
      for(let x=7;x<56;x+=1.2)g.fillRect(x*TS,16.6*TS,TS*.6,3);
      for(let y=3;y<47;y+=1.2)g.fillRect(43.6*TS,y*TS,3,TS*.6);
    };
  },
  *script(S,M){
    S.obj('r','Instale cargas nos três reatores (0/3)',{primary:true});
    S.obj('quiet','Opcional: instale as três cargas sem disparar o alarme');
    const f=S.rival('ferro',37.5,24.4);
    if(f){f.alerted=false;f.home={x:37.5,y:24};M.ferro=f;S.obj('ferro','Opcional: elimine o Ferro-Velho');S.fork(watchFerro(S,M,f));}
    S.fork(watchCharges(S,M));S.fork(watchQuiet(S,M));S.fork(watchVapor(S,M));S.fork(watchAlarm(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m5_intro1');yield S.camTo({x:22,y:24},.8,3.2);yield S.talkDone();
    M.ventOver=M.t+2.4;
    S.say('ctl:m5_intro2');yield S.camTo({x:16,y:17},1.15,2.4);yield S.talkDone();
    S.say('ctl:m5_intro3');yield S.camTo({x:37,y:22},1.05,2.6);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
    S.log('O terminal de pressão, ao sul, faz todas as saídas de vapor dispararem juntas.','amber');
  },
};
function* watchCharges(S,M){
  let last=-1;
  for(;;){
    const n=M.reactors.filter(R=>M.flags[R.f]).length;
    for(const R of M.reactors)if(M.flags[R.f]&&!R.d.armed){R.d.armed=true;if(n<3)S.say('ctl:m5_charge');}
    if(n!==last){last=n;S.setObj('r',{text:`Instale cargas nos três reatores (${n}/3)`});}
    if(n>=3)break;
    yield S.wait(.3);
  }
  S.setObj('r',{state:'done'});
  const quiet=S.objState('quiet')==='active';
  if(quiet)S.setObj('quiet',{state:'done'});
  S.obj('exfil','Volte ao portão de inserção antes da explosão',{primary:true});
  S.timer('REAÇÃO EM CADEIA',45);S.say('ctl:m5_last');
  S.alarm();
  yield S.until(()=>{if(S.timerDone())return true;const al=M.agents.filter(a=>!a.dead);return al.length>0&&al.every(a=>{const p=a.inCar||a;return Math.hypot(p.x-SPAWN.x,p.y-SPAWN.y)<3.8;});});
  const made=!S.timerDone();
  S.clearTimer();
  if(made){S.setObj('exfil',{state:'done'});if(quiet)S.bonus('Cargas instaladas em silêncio',3000);}
  else S.setObj('exfil',{state:'failed'});
  S.cine(true);
  yield S.camTo({x:32,y:18},.75,1.4);
  for(const R of M.reactors){
    S.boom(R.x,R.y,3.4,240);R.d.dead=true;
    for(let k=0;k<3;k++)S.boom(R.x+(Math.random()-.5)*6,R.y+(Math.random()-.5)*6,1.8,90);
    yield S.wait(.55);
  }
  for(const d of M.decor)if(d.type==='chimney')d.dead=true;
  for(const v of M.vents)v.off=true;
  yield S.wait(1.4);
  if(made){S.say('ctl:m5_win');S.win('A Fundição Hélice do Setor Industrial 9 foi pelos ares.');}
  else{S.say('ctl:m5_fail');S.fail('O esquadrão ainda estava na planta quando os reatores explodiram.');}
}
function* watchQuiet(S,M){
  yield S.until(()=>M.corpAlert);
  if(S.objState('quiet')==='active')S.setObj('quiet',{state:'failed'});
}
function* watchVapor(S,M){
  yield S.until(()=>M.flags.vapor);
  M.ventOver=M.t+10;M.ventSrc=M.agents.find(a=>!a.dead)||null;S.say('ctl:m5_vapor');
}
function* watchAlarm(S,M){
  yield S.until(()=>M.corpAlert);
  yield S.wait(3);
  S.say('ctl:m5_drones');
  for(const x of [27.5,30.5]){const d=S.spawn('drone',x,7.8);d.alerted=true;d.acc=.54;}
}
function* watchFerro(S,M,f){
  yield S.until(()=>f.dead);
  S.setObj('ferro',{state:f.vanished?'failed':'done'});
}
