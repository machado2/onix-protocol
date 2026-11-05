/* Missão feita à mão: "Gala Lúmen" — Distrito Lúmen.
   Praça Lúmen (x 14–44, y 14–40) cercada de torres, pavilhão de vidro no centro (x 20–36, y 20–32),
   guarita de segurança a nordeste da praça, heliporto a leste (x 49–56, y 26–38).
   O alvo e dois sósias idênticos circulam no pavilhão; o scanner (de perto) ou a guarita revelam quem é quem. */
import {T_ROAD,T_WALK,T_PLAZA,T_WATER,T_GRASS,RNG,pick} from '../core.js';
import {los} from '../world.js';

const SPAWN={x:2.5,y:53.5},HELI={x:53.5,y:32},ESC={x:51.2,y:32.5};
const NOME='Otávio Brandt';
const ROUTE=[{x:22.5,y:22.5},{x:28,y:22.4},{x:33.5,y:22.5},{x:33.6,y:26},{x:33.5,y:29.6},{x:28,y:29.7},{x:22.5,y:29.6},{x:22.4,y:26}];
const SIGNS=['GALERIA','JOIAS','BISTRÔ','HOTEL LÚMEN','CLÍNICA','ADEGA'];
function fill(B,r,x0,y0,x1,y1,lo=6,hi=14){
  for(let y=y0;y<=y1;){
    const d=3+((r()*3)|0);if(y+d-1>y1)break;
    for(let x=x0;x<=x1;){
      const w=3+((r()*4)|0);if(x+w-1>x1)break;
      if(r()<.92)B.bld({x,y,w,d,fl:lo+((r()*(hi-lo))|0),pal:pick([1,3,4,2],r),v:(r()*4)|0,neon:r()<.35?1:-1,sign:r()<.3?pick(SIGNS,r):null,signCol:pick(['#38e8ff','#ffd36b','#cfe8ff'],r),roof:(r()*3)|0,ant:r()<.4,ou:(r()*8)|0,ov:(r()*8)|0});
      x+=w+1;
    }
    y+=d+1;
  }
}
export const LUMEN={
  nome:'Gala Lúmen',
  spawn:SPAWN,
  build(B){
    const r=RNG(4242);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_ROAD,0,4,56,5);B.rect(T_ROAD,0,48,56,49);B.rect(T_ROAD,4,0,5,56);B.rect(T_ROAD,46,0,47,56);
    // praça e pavilhão
    B.rect(T_PLAZA,14,14,44,40);
    B.glass(20,20,36,20);B.glass(20,32,36,32);B.glass(20,20,20,32);B.glass(36,20,36,32);
    B.rect(T_PLAZA,27,20,29,20);B.rect(T_PLAZA,27,32,29,32);B.rect(T_PLAZA,20,25,20,27);B.rect(T_PLAZA,36,25,36,27);
    for(const [x,y] of [[24,24],[32,24],[24,28],[32,28]])B.bld({x,y,w:1,d:1,fl:1,pal:5,neon:3,kiosk:true});
    B.decor({type:'disco',x0:25,y0:24,x1:31,y1:28});
    // fonte
    B.rect(T_WATER,26,36,30,38);B.decor({type:'fountain',x:28.5,y:37.5,x0:26,y0:36,x1:30,y1:38});
    // canteiros
    for(const [x0,y0] of [[15,15],[40,36],[15,36]]){B.rect(T_GRASS,x0,y0,x0+3,y0+3);B.tree(x0+1.5,y0+1.5);}
    for(const [x,y] of [[18.5,18.5],[38.5,18.5],[18.5,34.5],[38.5,34.5]])B.tree(x,y);
    // guarita
    B.bld({x:40,y:14,w:4,d:3,fl:2,pal:4,v:1,neon:1,sign:'SEGURANÇA',signCol:'#ff3d5a',corp:true});
    B.term({x:41.5,y:17.8,prog:0,done:false,flag:'booth',msg:'Guarita invadida: registros biométricos da festa.'});
    // heliporto
    B.rect(T_PLAZA,49,26,56,38);B.decor({type:'heli',x:HELI.x,y:HELI.y,ang:0});B.m.escape=ESC;
    // torres
    fill(B,r,7,7,44,12);fill(B,r,7,14,12,46);fill(B,r,14,42,44,46,5,10);
    fill(B,r,49,7,56,24);fill(B,r,49,40,56,46);fill(B,r,8,51,44,56,3,7);fill(B,r,49,51,56,56,3,7);fill(B,r,7,0,44,2,4,8);fill(B,r,49,0,56,2,4,8);
    B.decor({type:'billboard',x:29,y:13.2,w:5,h:4,text:'LÚMEN',sub:'O FUTURO TEM ENDEREÇO',col:'#ffd36b'});
    // luzes
    for(let x=15;x<44;x+=5){B.lamp(x+.5,14.4,'#cfe8ff');B.lamp(x+.5,40.6,'#cfe8ff');}
    for(let y=18;y<40;y+=6){B.lamp(14.4,y+.5,'#ffd99a');B.lamp(44.6,y+.5,'#ffd99a');}
    for(const [x,y] of [[50,27],[56,27],[50,37.6],[56,37.6]])B.lamp(x,y,'#ff3d5a');
    for(let x=2;x<56;x+=8){B.lamp(x+.5,3.4,'#ffcf7a');B.lamp(x+.5,47.4,'#ffcf7a');}
    // câmeras
    B.cam(14.6,14.6,Math.PI/4,{sweep:.8});B.cam(43.4,40.4,-3*Math.PI/4,{sweep:.8});B.cam(43.4,19.4,3*Math.PI/4,{sweep:.6});B.cam(49.4,26.6,Math.PI/4,{strict:true,sweep:.5});
    // o alvo e os sósias
    const real=Math.floor(Math.random()*3);B.m.cands=[];
    for(let k=0;k<3;k++){
      const p=ROUTE[k*3%ROUTE.length],v=B.unit('vip',p.x,p.y);
      v.nome=NOME;v.cand=true;v.double=k!==real;v.route=ROUTE.slice(k*3).concat(ROUTE.slice(0,k*3));v.ri=0;v.idleT=1+k*2;v.coat='#1c1c22';v.trim='#ffd36b';v.legs='#101014';v.hair='#c9c0b0';v.skin='#e0b48c';
      B.m.cands.push(v);
    }
    // convidados
    for(let k=0;k<16;k++){const p=B.randTile((t,x,y)=>t===T_PLAZA&&x>20&&x<36&&y>20&&y<32);if(!p)continue;const c=B.unit('civil',p.x,p.y);c.still=true;c.umb=null;c.coat=pick(['#1c1c22','#5a1a2a','#e6e0d0','#2a2a40','#8a6a2a'],Math.random);c.trim=pick(['#ffd36b','#cfe8ff','#ff8ad8'],Math.random);}
    for(let k=0;k<10;k++){const p=B.randTile((t,x,y)=>t===T_PLAZA&&x>20&&x<36&&y>20&&y<32);if(!p)continue;const c=B.unit('civil',p.x,p.y);c.umb=null;c.home={x:28,y:26};c.coat=pick(['#1c1c22','#5a1a2a','#e6e0d0','#2a2a40'],Math.random);}
    for(let k=0;k<18;k++){const p=B.randTile((t,x,y)=>t===T_PLAZA&&(x<19||x>37||y<19||y>33)&&x<45);if(p){const c=B.unit('civil',p.x,p.y);c.home={x:p.x,y:p.y};}}
    for(let k=0;k<16;k++){const p=B.randTile((t,x,y)=>t===T_WALK);if(p)B.unit('civil',p.x,p.y);}
    // segurança
    for(const [x,y] of [[26.5,26.5],[30.5,25.5],[28.5,18.6],[28.5,33.6],[18.6,26],[37.4,26],[38.5,15.5],[44.5,20.5],[50.5,30],[50.5,35],[16,24],[42,32]]){const g=B.unit('guarda',x,y);B.arm(g,5);g.home={x,y};}
    for(const [x,y] of [[10,47.4],[30,47.4],[45,24],[24,13.4],[52,6.4]])B.unit('policia',x,y);
    B.lanes([{y:4.5,dx:1,dy:0},{y:5.5,dx:-1,dy:0},{y:48.5,dx:1,dy:0},{y:49.5,dx:-1,dy:0}],10);
    B.m.paint=(g,TS)=>{
      for(let y=14;y<=40;y++)for(let x=14;x<=44;x++){g.fillStyle=(x+y)%2?'#5a5868':'#4c4a5a';g.fillRect(x*TS+1,y*TS+1,TS-2,TS-2);}
      for(let y=21;y<=31;y++)for(let x=21;x<=35;x++){g.fillStyle=(x%2)?'#4a3426':'#3e2c20';g.fillRect(x*TS,y*TS,TS,TS);g.fillStyle='rgba(255,220,160,.06)';g.fillRect(x*TS,y*TS,TS,2);}
      g.fillStyle='#2a2c34';g.fillRect(49*TS,26*TS,8*TS,13*TS);
      g.strokeStyle='#ffd36b';g.lineWidth=4;g.beginPath();g.arc(HELI.x*TS,HELI.y*TS,2.6*TS,0,Math.PI*2);g.stroke();
      g.fillStyle='#ffd36b';const X=HELI.x*TS,Y=HELI.y*TS,u=TS*.5;g.fillRect(X-2*u,Y-2*u,u*.8,4*u);g.fillRect(X+1.2*u,Y-2*u,u*.8,4*u);g.fillRect(X-2*u,Y-u*.4,4*u,u*.8);
    };
  },
  *script(S,M){
    S.obj('kill',`Elimine ${NOME} (alvo verdadeiro não identificado)`,{primary:true});
    S.obj('clean','Opcional: não mate nenhum sósia');
    S.obj('booth','Opcional: invada o terminal da guarita de segurança');
    S.fork(watchKill(S,M));S.fork(watchScan(S,M));S.fork(watchBooth(S,M));S.fork(watchDoubles(S,M));S.fork(watchSibila(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m6_intro1');yield S.camTo({x:28,y:26},.95,3.2);yield S.talkDone();
    S.say('ctl:m6_intro2');yield S.camTo({x:41,y:17},1.15,2.4);yield S.talkDone();
    S.say('ctl:m6_intro3');yield S.camTo({x:51,y:32},1.1,2.4);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
  },
};
const real=M=>M.cands.find(v=>!v.double);
function identify(S,M,silent){
  const v=real(M);if(M.vip===v)return;M.vip=v;v.scanned=true;
  S.setObj('kill',{text:`Elimine ${NOME} (identificado)`});
  if(!silent)S.say('ctl:m6_real');
}
function* watchScan(S,M){
  for(;;){
    if(M.vip)return;
    for(const v of M.cands){
      if(v.dead||v.scanned)continue;
      let near=false;for(const a of M.agents)if(!a.dead&&!a.inCar&&Math.hypot(a.x-v.x,a.y-v.y)<3.2&&los(a.x,a.y,v.x,v.y)){near=true;break;}
      v.scanP=near?(v.scanP||0)+.2:Math.max(0,(v.scanP||0)-.1);
      if(v.scanP>=1.6){
        v.scanned=true;
        if(v.double){S.say('ctl:m6_double');S.log('Scanner: implante genérico. É um sósia.','amber');}
        else{identify(S,M);S.log(`Scanner: implantes de executivo. É ${NOME}.`,'green');}
      }
    }
    const left=M.cands.filter(v=>!v.scanned&&!v.dead);
    if(!M.vip&&left.length===1&&!left[0].double){identify(S,M);S.log('Os outros dois são sósias: só sobrou o verdadeiro.','green');}
    yield S.wait(.2);
  }
}
function* watchBooth(S,M){
  yield S.until(()=>M.flags.booth);
  S.setObj('booth',{state:'done'});S.bonus('Guarita invadida',800);
  for(const v of M.cands)v.scanned=true;
  if(!real(M).dead){identify(S,M,true);S.say('ctl:m6_booth');}
}
function* watchDoubles(S,M){
  yield S.until(()=>M.cands.some(v=>v.double&&v.dead&&!v.vanished));
  S.setObj('clean',{state:'failed'});
  if(!real(M).dead)S.say('ctl:m6_wrong');
}
function* watchKill(S,M){
  const v=real(M);
  yield S.until(()=>v.dead);
  if(!M.vip)M.vip=v;
  S.setObj('kill',{state:'done'});
  if(S.objState('clean')==='active'){S.setObj('clean',{state:'done'});S.bonus('Nenhum sósia morto',2000);}
  S.say('ctl:m6_win');
  S.win(`${NOME} foi eliminado na Gala Lúmen.`);
}
function* watchSibila(S,M){
  yield S.until(()=>M.corpAlert);
  yield S.wait(4);
  const s=S.rival('sibila',54.5,28.5,.9);
  if(s){s.home={x:52,y:30};S.obj('sib','Opcional: elimine a Sibila');S.say('ctl:m6_sibila');
    yield S.until(()=>s.dead);
    S.setObj('sib',{state:s.vanished?'failed':'done'});}
}
