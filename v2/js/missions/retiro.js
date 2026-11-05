/* Missão feita à mão: "Retiro" — Colinas de Vidro.
   Mansão murada (x 22–54, y 3–27) com portão ao sul (x 38–41) e saída de serviço a oeste (y 6–7).
   Uma linha de feixes em x 38,5 separa a ala da mansão da estufa de vidro (x 42–51, y 13–21).
   Gerador fora do muro (sudoeste) apaga feixes, câmeras e luzes. Zona de pouso no topo do morro (noroeste). */
import {T_ROAD,T_WALK,T_GRASS,T_PLAZA,T_WATER,RNG,pick} from '../core.js';

const SPAWN={x:2.5,y:53.5},LZ={x:6,y:5.5};
const NOME='Dr. Caio Ventura';
const inCompound=(x,y)=>x>=21&&x<=55&&y>=2&&y<=28;
export const RETIRO={
  nome:'Retiro',
  spawn:SPAWN,
  build(B){
    const r=RNG(7707);
    B.rect(T_GRASS,0,0,56,56);
    // estradas e trilhas
    B.rect(T_ROAD,0,50,56,51);B.rect(T_ROAD,39,28,40,49);
    B.rect(T_WALK,2,10,3,49);B.rect(T_WALK,2,30,38,31);B.rect(T_WALK,18,8,19,30);B.rect(T_WALK,11,6,21,7);
    B.rect(T_PLAZA,2,2,10,9);
    B.bld({x:2,y:7,w:4,d:1,fl:1,style:'wall',kiosk:true});B.bld({x:7,y:2,w:1,d:4,fl:1,style:'wall',kiosk:true});
    // muro do Retiro
    const wall=(x,y,w,d)=>B.bld({x,y,w,d,fl:1,style:'wall',kiosk:true});
    wall(22,3,33,1);wall(22,27,16,1);wall(42,27,13,1);wall(22,4,1,2);wall(22,8,1,19);wall(54,4,1,23);
    // interior
    B.rect(T_PLAZA,23,4,37,26);B.rect(T_GRASS,38,4,53,12);B.rect(T_PLAZA,38,13,53,26);
    B.bld({x:26,y:6,w:10,d:6,fl:3,pal:3,v:2,roof:1,neon:-1,ou:2,ov:1});
    B.rect(T_WATER,27,16,34,19);
    B.bld({x:44,y:23,w:3,d:3,fl:2,pal:4,v:1,neon:1,sign:'SEGURANÇA',signCol:'#ff3d5a',corp:true});
    // estufa de vidro
    B.glass(42,13,51,13);B.glass(42,21,51,21);B.glass(42,13,42,21);B.glass(51,13,51,21);
    B.rect(T_PLAZA,46,21,47,21);B.rect(T_PLAZA,42,16,42,17);
    for(const [x,y] of [[39.5,6.5],[44.5,5.5],[49.5,7.5],[52.5,10.5],[41.5,10.5],[46.5,10.5]])B.tree(x,y);
    for(const [x,y] of [[44,15],[49,19]])B.tree(x+.5,y+.5);
    // feixes de alarme
    B.laser(37.9,26.4,42.1,26.4);
    B.laser(23.4,5.7,23.4,8.3,{per:4,duty:.55});
    B.laser(38.5,4.1,38.5,12.9);
    B.laser(38.5,13.1,38.5,21.9,{per:5,duty:.5,ph:1});
    B.laser(38.5,22.1,38.5,25.9);
    B.laser(41.5,15.6,41.5,18.4);
    B.laser(45.6,22.4,48.4,22.4,{per:4.5,duty:.5,ph:2});
    // gerador
    B.decor({type:'generator',x:19.6,y:20.4});
    B.term({x:19.6,y:21.8,prog:0,done:false,flag:'blackout',msg:'Gerador do Retiro desligado.'});
    // zona de pouso e VTOL
    B.m.evac=LZ;
    const vtol={type:'heli',x:LZ.x,y:LZ.y,ang:.4,alt:16,vis:false};B.decor(vtol);B.m.vtol=vtol;
    // casas na encosta
    for(const [x,y,w,d,fl] of [[7,34,6,4,3],[14,35,5,4,2],[26,34,7,5,3],[44,33,6,5,3],[47,41,6,5,2],[8,42,6,5,2],[27,41,5,5,3],[11,13,5,4,2],[6,22,6,4,3]])
      B.bld({x,y,w,d,fl,pal:pick([1,3,2],r),v:(r()*4)|0,roof:(r()*3)|0,ou:(r()*8)|0,ov:(r()*8)|0,neon:-1});
    for(let k=0;k<55;k++){const p=B.randTile((t,x,y)=>t===T_GRASS&&!inCompound(x,y)&&!(x<=11&&y<=10)&&y<49);if(p)B.tree(p.x,p.y);}
    // luzes
    const villa=(x,y)=>B.lamp(x,y,'#cfe8ff',true,{villa:true});
    for(const [x,y] of [[24,4.6],[37,4.6],[53,4.6],[24,25.6],[37,22.6],[53,25.6],[41,13.6],[52.4,13.6]])villa(x,y);
    for(const [x,y] of [[26,15],[35.5,20.5]])B.lamp(x,y,'#7fe3ff',false,{villa:true});
    for(const [x,y] of [[2,2],[10.6,2],[2,9.6],[10.6,9.6]])B.lamp(x,y,'#5dffa0');
    for(let y=30;y<49;y+=6)B.lamp(41.4,y+.5,'#ffcf7a');
    for(let x=4;x<56;x+=9)B.lamp(x+.5,49.4,'#ffcf7a');
    B.prop(20.8,19.4);B.prop(36.5,25.5);
    // câmeras
    B.cam(23.6,26.4,-Math.PI/4,{sweep:.7});B.cam(53.4,4.6,3*Math.PI/4,{sweep:.6});B.cam(39.5,28.6,Math.PI/2,{sweep:.8});
    // gente
    const sci=B.unit('cientista',46.5,17.5);sci.nome=NOME;sci.hp=sci.maxHp=160;sci.armor=.35;B.m.sci=sci;
    for(const [x,y] of [[25,13.5],[36,13.2],[30,23.5],[45,8],[52.5,16],[49.5,24.5],[49.5,14.5],[37,29.2],[43,29.2]]){const g=B.unit('guarda',x,y);B.arm(g,5);g.home={x,y};}
    B.drone(21,2,[{x:21,y:1.5},{x:55,y:1.5},{x:55,y:28.5},{x:21,y:28.5}],5);
    for(let k=0;k<5;k++){const c=B.unit('civil',24+Math.random()*12,13.5+Math.random()*1.2);c.still=true;c.umb=null;c.coat='#e8e4dc';c.trim='#1c1c22';}
    for(let k=0;k<8;k++){const p=B.randTile((t,x,y)=>t===T_WALK);if(p){const c=B.unit('civil',p.x,p.y);c.home={x:p.x,y:p.y};}}
    for(const [x,y] of [[20,50.5],[45,51.3]])B.unit('policia',x,y-2);
    B.lanes([{y:50.5,dx:1,dy:0},{y:51.5,dx:-1,dy:0}],5);
    B.m.paint=(g,TS)=>{
      g.strokeStyle='#5dffa0';g.lineWidth=4;g.beginPath();g.arc(LZ.x*TS,LZ.y*TS,2.4*TS,0,Math.PI*2);g.stroke();
      g.fillStyle='rgba(93,255,160,.8)';const X=LZ.x*TS,Y=LZ.y*TS,u=TS*.45;g.fillRect(X-2*u,Y-2*u,u*.8,4*u);g.fillRect(X+1.2*u,Y-2*u,u*.8,4*u);g.fillRect(X-2*u,Y-u*.4,4*u,u*.8);
      for(let y=4;y<=26;y++)for(let x=23;x<=37;x++){if(x>=27&&x<=34&&y>=16&&y<=19)continue;g.fillStyle=(x+y)%2?'rgba(220,210,190,.10)':'rgba(220,210,190,.04)';g.fillRect(x*TS,y*TS,TS,TS);}
    };
  },
  *script(S,M){
    S.obj('reach',`Encontre o ${NOME} na estufa de vidro`,{primary:true});
    S.obj('ghost','Opcional: alcance o doutor sem disparar o alarme');
    S.fork(watchBlackout(S,M));S.fork(watchGhost(S,M));S.fork(watchSciDead(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m7_intro1');yield S.camTo({x:44,y:16},1.0,3.2);yield S.talkDone();
    S.say('ctl:m7_intro2');yield S.camTo({x:36,y:14},1.15,2.4);yield S.talkDone();
    S.say('ctl:m7_intro3');yield S.camTo(LZ,1.0,2.6);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
    S.log('O gerador fora do muro, a sudoeste, apaga os feixes de alarme.','amber');
    yield S.until(()=>M.sci.follow||M.sci.dead);
    if(M.sci.dead)return;
    S.setObj('reach',{state:'done'});
    if(S.objState('ghost')==='active'){S.setObj('ghost',{state:'done'});S.bonus('Retiro sem alarme',3000);}
    S.say('sci:m7',M.sci);
    S.obj('lz','Leve o doutor à zona de pouso no topo do morro (noroeste)',{primary:true});
    yield S.until(()=>M.sci.dead||Math.hypot(M.sci.x-LZ.x,M.sci.y-LZ.y)<3.6);
    if(M.sci.dead)return;
    S.setObj('lz',{state:'done'});
    S.obj('hold','Defenda a zona de pouso até o VTOL descer',{primary:true});
    const HOLD=30;S.timer('VTOL CHEGA EM',HOLD);S.say('ctl:m7_hold');
    M.sci.hold=true;M.sci.follow=false;S.walk(M.sci,3.6,3.6);S.log('O doutor se abrigou atrás do muro da zona de pouso.','cyan');
    const v=M.vtol;v.vis=true;v.alt=14;
    S.fork(waves(S,M));
    while(!S.timerDone()){v.alt=Math.max(0,14*(M.timer.end-M.t)/HOLD);yield S.wait(.5);}
    S.clearTimer();v.alt=0;S.say('ctl:m7_vtol');
    yield S.wait(2.5);
    S.walk(M.sci,LZ.x-.8,LZ.y);
    yield S.until(()=>M.sci.dead||Math.hypot(M.sci.x-LZ.x,M.sci.y-LZ.y)<3.6);
    if(M.sci.dead)return;
    S.setObj('hold',{state:'done'});
    M.sci.vanished=true;M.flags.heliGo=true;
    S.say('ctl:m7_win');
    S.win(`O ${NOME} foi tirado do Retiro.`);
  },
};
function* waves(S,M){
  const go=(kind,x,y)=>{const u=S.spawn(kind,x,y,5);u.alerted=true;u.lkp={x:LZ.x,y:LZ.y};u.home={x:LZ.x+3,y:LZ.y+3};return u;};
  yield S.wait(2);
  for(const [x,y] of [[24,6.5],[25,7.5]])go('guarda',x,y);go('drone',30,1.5);
  yield S.wait(10);
  S.say('ctl:m7_wave');
  let riv=null;for(const id of ['navalha','mariposa','sibila','ferro']){riv=S.rival(id,12,29,.8);if(riv)break;}
  if(riv)riv.lkp={x:LZ.x,y:LZ.y};
  for(const [x,y] of [[10,29],[14,29.5]])go('inimigo',x,y);
  yield S.wait(10);
  for(const [x,y] of [[40,1.5],[50,1.5]])go('drone',x,y);
  for(const [x,y] of [[18.5,26],[19,27]])go('guarda',x,y);
}
function* watchBlackout(S,M){
  yield S.until(()=>M.flags.blackout);
  for(const l of M.lasers)l.off=true;
  for(const c of M.cams)c.off=true;
  for(const l of M.lamps)if(l.villa&&!l.dead){l.dead=true;S.lampOff(l);}
  S.say('ctl:m7_dark');
  const gs=M.units.filter(u=>u.kind==='guarda'&&!u.dead&&!u.alerted).sort((a,b)=>Math.hypot(a.x-19.6,a.y-20.4)-Math.hypot(b.x-19.6,b.y-20.4)).slice(0,2);
  for(const g of gs)S.walk(g,19.6+Math.random(),22.5+Math.random());
}
function* watchGhost(S,M){
  yield S.until(()=>M.corpAlert);
  if(S.objState('ghost')==='active')S.setObj('ghost',{state:'failed'});
}
function* watchSciDead(S,M){
  yield S.until(()=>M.sci.dead&&!M.sci.vanished);
  S.say('ctl:m7_fail');S.fail(`O ${NOME} morreu.`);
}
