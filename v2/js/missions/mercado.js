/* Missão feita à mão: "Pregão" — Mercado Suspenso.
   Feira sob o monotrilho (y 18–26), Central de Vigilância cercada ao norte, galeria e beco ao sul.
   Câmeras de segurança veem armas à mostra; o trem a cada 40 s abafa os tiros. */
import {T_ROAD,T_WALK,T_PLAZA,T_FENCE,RNG,pick} from '../core.js';

const SPAWN={x:3.5,y:52.5};
const SIGNS=['PASTEL','AÇAÍ','CYBER','LOTERIA','PENHORES','BAR','RAMEN','CLÍNICA'];
function fill(B,r,x0,y0,x1,y1,skip){
  for(let y=y0;y<=y1;){
    const d=3+((r()*3)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      let ok=true;for(let yy=y;yy<y+d;yy++)for(let xx=x;xx<x+w;xx++)if(skip&&skip(xx,yy))ok=false;
      if(ok&&r()<.88)B.bld({x,y,w,d,fl:3+((r()*7)|0),pal:(r()*4)|0,v:(r()*4)|0,neon:r()<.45?((r()*4)|0):-1,sign:r()<.3?pick(SIGNS,r):null,signCol:pick(['#ff3d8b','#38e8ff','#ffb13d'],r),roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
export const MERCADO={
  nome:'Pregão',
  spawn:SPAWN,
  build(B){
    const r=RNG(3131);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_ROAD,0,16,56,17);B.rect(T_ROAD,0,27,56,28);
    B.rect(T_ROAD,28,0,29,15);B.rect(T_ROAD,28,29,29,56);
    B.rect(T_PLAZA,0,18,56,26);
    B.monorail(22,[2,8,14,20,26,32,38,44,50,55]);
    for(let x=2;x<54;x+=3){if(x>=25&&x<=31)continue;if(r()<.85)B.bld({x,y:19,w:2,d:1,fl:1,pal:5,kiosk:true,neon:(r()*4)|0});if(r()<.85)B.bld({x,y:25,w:2,d:1,fl:1,pal:5,kiosk:true,neon:(r()*4)|0});}
    // Central de Vigilância (cercada)
    B.rect(T_PLAZA,39,3,53,13);
    for(let y=2;y<=14;y++){B.tile(38,y,T_FENCE);B.tile(54,y,T_FENCE);}
    for(let x=38;x<=54;x++){B.tile(x,2,T_FENCE);if(x<45||x>47)B.tile(x,14,T_FENCE);}
    B.bld({x:41,y:4,w:11,d:4,fl:5,pal:4,v:1,neon:0,sign:'VIGILÂNCIA',signCol:'#ff3d5a',corp:true,ant:true});
    // quarteirões
    fill(B,r,2,2,26,14);fill(B,r,31,2,36,14);
    B.bld({x:32,y:31,w:11,d:5,fl:4,pal:2,v:2,neon:2,sign:'GALERIA AURORA',signCol:'#ffb13d'});
    fill(B,r,2,30,26,54,(x,y)=>x<=9&&y>=47);
    fill(B,r,31,37,54,54,(x,y)=>x>=44&&x<=49&&y>=36&&y<=46);
    fill(B,r,49,30,54,35);
    B.rect(T_PLAZA,44,37,49,45);
    // terminais
    B.term({x:46.5,y:10.5,prog:0,done:false,flag:'cams',vo:'ctl:m3_cams',msg:'Central de Vigilância invadida: câmeras desligadas.'});
    B.term({x:15.5,y:23.4,prog:0,done:false,flag:'t2',msg:'Terminal da feira invadido.'});
    B.term({x:46.5,y:41.5,prog:0,done:false,flag:'t3',msg:'Terminal do beco invadido.'});
    // câmeras
    B.cam(8.6,22.5,0,{sweep:.9});B.cam(32.6,22.5,Math.PI,{sweep:.9});B.cam(44.6,22.5,0,{sweep:.9});
    B.cam(39.6,13.3,-Math.PI/4,{strict:true,sweep:.5});B.cam(53.4,13.3,-3*Math.PI/4,{strict:true,sweep:.5});
    B.cam(46.5,36.6,Math.PI/2,{sweep:.7});
    // luzes e barris
    for(let x=4;x<54;x+=6){B.lamp(x+.5,18.4,r()<.5?'#ff6ad5':'#7fe3ff');B.lamp(x+3.5,26.6,r()<.5?'#ffb35c':'#ff6ad5');}
    for(const [x,y] of [[40.5,3.5],[52.5,3.5],[40.5,12.5],[52.5,12.5]])B.lamp(x,y,'#cfe8ff',true);
    for(const x of [6,18,36,48])B.lamp(x+.5,15.5,'#ffb35c');for(const x of [6,18,36,48])B.lamp(x+.5,29.5,'#ffb35c');
    B.lamp(44.5,38,'#ff6ad5');B.lamp(49,44,'#7fe3ff');
    for(const [x,y] of [[24,20.5],[34,24],[45,44.5],[40,12.5]])B.prop(x,y);
    // gente
    for(const [x,y] of [[42,9.5],[50,10],[46,12.6]]){const g=B.unit('guarda',x,y);B.arm(g,2);g.home={x,y};}
    for(const [x,y] of [[20,24],[38,20.5]]){const g=B.unit('guarda',x,y);B.arm(g,2);g.home={x,y};}
    for(const [x,y] of [[46.5,43.5],[45,39.5]]){const g=B.unit('guarda',x,y);B.arm(g,2);g.home={x,y};}
    for(const [x,y] of [[12,18.5],[40,26.5],[31,40]])B.unit('policia',x,y);
    for(let k=0;k<32;k++){const c=B.unit('civil',2+Math.random()*52,20+Math.random()*4.6);c.home={x:c.x,y:c.y};}
    for(let k=0;k<16;k++){const p=B.randTile((t,x,y)=>t===T_WALK&&(y<16||y>28));if(p)B.unit('civil',p.x,p.y);}
    B.lanes([{y:16.5,dx:1,dy:0},{y:17.5,dx:-1,dy:0},{y:27.5,dx:1,dy:0},{y:28.5,dx:-1,dy:0}],7);
    B.m.trainT=14;
  },
  *script(S,M){
    S.obj('t','Invada os terminais de vigilância (0/3)',{primary:true});
    S.obj('cams','Opcional: desligue as câmeras pelo terminal da Central de Vigilância');
    S.obj('quiet','Opcional: derrube a rede sem disparar o alarme');
    S.fork(watchTerms(S,M));S.fork(watchCams(S,M));S.fork(watchQuiet(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m3_intro1');yield S.camTo({x:20,y:22},1.05,3);yield S.talkDone();
    S.say('ctl:m3_intro2');yield S.camTo({x:46,y:9},1.1,2.6);yield S.talkDone();
    M.trainT=1;
    S.say('ctl:m3_intro3');yield S.camTo({x:26,y:22},.95,2.4);yield S.talkDone();
    yield S.wait(1.5);
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
  },
};
function* watchTerms(S,M){
  let last=-1;
  for(;;){
    const n=M.terms.filter(t=>t.done).length;
    if(n!==last){last=n;S.setObj('t',{text:`Invada os terminais de vigilância (${n}/3)`});
      if(n===2&&!M.flags.lockdown){M.flags.lockdown=true;S.say('ctl:m3_lock');
        for(const [x,y] of [[28.5,1],[29.5,1.5],[28.5,55],[29.5,54.5],[55,16.5]]){S.spawn('policia',x,y);}
        M.policeAggro=60;const a=M.agents.find(q=>!q.dead);if(a)M.lastSeen={x:a.x,y:a.y};}
    }
    if(n>=3)break;
    yield S.wait(.4);
  }
  S.setObj('t',{state:'done'});
  S.obj('exfil','Volte ao ponto de inserção',{primary:true});S.say('ctl:m3_exfil');
  yield S.until(()=>{const al=M.agents.filter(a=>!a.dead);return al.length>0&&al.every(a=>{const p=a.inCar||a;return Math.hypot(p.x-SPAWN.x,p.y-SPAWN.y)<3.4;});});
  S.setObj('exfil',{state:'done'});
  if(S.objState('quiet')==='active'){S.setObj('quiet',{state:'done'});S.bonus('Rede derrubada em silêncio',3000);}
  S.say('ctl:m3_win');
  S.win('A rede de vigilância do Mercado Suspenso caiu.');
}
function* watchCams(S,M){
  yield S.until(()=>M.flags.cams);
  for(const c of M.cams)c.off=true;
  S.setObj('cams',{state:'done'});S.bonus('Câmeras desligadas',1000);
}
function* watchQuiet(S,M){
  yield S.until(()=>M.corpAlert);
  S.setObj('quiet',{state:'failed'});
}
