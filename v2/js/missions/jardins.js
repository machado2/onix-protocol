/* Missão feita à mão: "Labirinto" — Jardins Altos.
   Propriedade murada (x 6–54, y 1–47), mansão ao norte, labirinto de sebes no centro (x 14–41, y 14–41)
   com entradas nos quatro lados e uma praça com fonte no meio. Holofotes em torres enxergam qualquer agente.
   Ao alarme, o senador corre para o bunker a nordeste; dentro dele, a porta se fecha e começa a contagem do túnel. */
import {T_ROAD,T_WALK,T_GRASS,T_PLAZA,T_WATER,RNG,pick} from '../core.js';

const SPAWN={x:2.5,y:53.5},BUNKER={x:48.5,y:7.5};
const NOME='Senador Augusto Calvino';
const MX=14,MY=14,L=28;
function maze(B,r){
  const wall=[];for(let y=0;y<L;y++){wall.push([]);for(let x=0;x<L;x++)wall[y].push(x%3===0||y%3===0);}
  const seen=new Set(),st=[[4,4]];seen.add('4,4');
  const open=(i,j,di,dj)=>{if(di)for(const y of [3*j+1,3*j+2])wall[y][3*Math.max(i,i+di)]=false;else for(const x of [3*i+1,3*i+2])wall[3*Math.max(j,j+dj)][x]=false;};
  while(st.length){
    const [i,j]=st[st.length-1];
    const nb=[[1,0],[-1,0],[0,1],[0,-1]].filter(([a,b])=>{const ni=i+a,nj=j+b;return ni>=0&&nj>=0&&ni<9&&nj<9&&!seen.has(ni+','+nj);});
    if(!nb.length){st.pop();continue;}
    const [a,b]=nb[(r()*nb.length)|0];open(i,j,a,b);seen.add((i+a)+','+(j+b));st.push([i+a,j+b]);
  }
  for(let j=0;j<9;j++)for(let i=0;i<9;i++){if(i<8&&r()<.13)open(i,j,1,0);if(j<8&&r()<.13)open(i,j,0,1);}
  for(const k of [13,14]){wall[0][k]=wall[L-1][k]=wall[k][0]=wall[k][L-1]=false;}
  for(let y=10;y<=17;y++)for(let x=10;x<=17;x++)wall[y][x]=false;
  const hedge=(x,y,w,d)=>B.bld({x:MX+x,y:MY+y,w,d,fl:1,style:'hedge',kiosk:true});
  for(let y=0;y<L;y+=3){let x=0;while(x<L){if(!wall[y][x]){x++;continue;}let e=x;while(e<L&&wall[y][e])e++;hedge(x,y,e-x,1);x=e;}}
  for(let x=0;x<L;x+=3)for(let y=0;y<L;y++){if(y%3===0||!wall[y][x])continue;let e=y;while(e<L&&e%3!==0&&wall[e][x])e++;hedge(x,y,1,e-y);y=e-1;}
  return wall;
}
export const JARDINS={
  nome:'Labirinto',
  spawn:SPAWN,
  build(B){
    const r=RNG(6464);
    B.rect(T_GRASS,0,0,56,56);
    B.rect(T_ROAD,0,50,56,51);B.rect(T_WALK,0,52,56,56);B.rect(T_WALK,0,48,56,49);B.rect(T_WALK,2,2,3,47);
    // muro da propriedade
    const wall=(x,y,w,d)=>B.bld({x,y,w,d,fl:1,style:'wall',kiosk:true});
    wall(6,1,49,1);wall(6,47,20,1);wall(30,47,25,1);wall(6,2,1,28);wall(6,32,1,15);wall(54,2,1,45);
    B.rect(T_PLAZA,26,42,29,47);
    // mansão e terraço
    B.bld({x:20,y:2,w:17,d:6,fl:4,pal:3,v:2,roof:1,neon:-1,ou:3,ov:2});
    B.rect(T_PLAZA,14,8,42,12);
    // labirinto
    const mw=maze(B,r);B.m.inMaze=(x,y)=>{const lx=Math.floor(x)-MX,ly=Math.floor(y)-MY;return lx>0&&ly>0&&lx<L-1&&ly<L-1&&!mw[ly][lx];};
    B.rect(T_PLAZA,24,24,31,31);B.rect(T_WATER,27,27,28,28);B.decor({type:'fountain',x:28,y:28,x0:27,y0:27,x1:28,y1:28});
    // lago a oeste e jardins
    B.rect(T_WATER,8,18,11,24);
    for(let k=0;k<26;k++){const p=B.randTile((t,x,y)=>t===T_GRASS&&x>7&&x<53&&y>2&&y<46&&(x<13||x>42||y<13||y>42)&&!(x>=43&&x<=53&&y<=14)&&!(y>=26&&y<=29)&&!(x>=25&&x<=30));if(p)B.tree(p.x,p.y);}
    for(let k=0;k<30;k++){const p=B.randTile((t,x,y)=>t===T_GRASS&&(y>52||x<2||x>55));if(p)B.tree(p.x,p.y);}
    // bunker
    wall(45,4,8,1);wall(45,11,3,1);wall(50,11,3,1);wall(45,5,1,6);wall(52,5,1,6);
    B.rect(T_PLAZA,46,5,51,10);B.rect(T_PLAZA,46,12,51,14);
    B.decor({type:'blastdoor',x:49,y:11.5,w:2,flag:'shut'});
    B.m.escape=BUNKER;B.m.escapeLabel='BUNKER';
    B.term({x:43.6,y:13.4,prog:0,done:false,flag:'rel1',msg:'Relé oeste do bunker sobrecarregado.'});
    B.term({x:53.2,y:15.4,prog:0,done:false,flag:'rel2',msg:'Relé leste do bunker sobrecarregado.'});
    // holofotes e câmeras
    const spot=(x,y,a)=>B.cam(x,y,a,{strict:true,spot:true,range:10,fov:.26,sweep:1.05,spd:.33});
    spot(12.5,12.5,Math.PI/4);spot(43.5,43.5,-3*Math.PI/4);spot(12.5,43.5,-Math.PI/4);
    B.cam(19.6,8.4,Math.PI/4,{sweep:.6});B.cam(37.4,8.4,3*Math.PI/4,{sweep:.6});
    // luzes
    for(let x=15;x<42;x+=5)B.lamp(x+.5,12.6,'#ffd99a');
    for(const [x,y] of [[24.4,24.4],[31.6,24.4],[24.4,31.6],[31.6,31.6]])B.lamp(x,y,'#cfe8ff');
    for(const [x,y] of [[46.4,12.6],[51.6,12.6],[26,46.4],[29.6,46.4],[13,27.5],[42,27.5]])B.lamp(x,y,'#ffb35c',true);
    for(let x=4;x<56;x+=9)B.lamp(x+.5,49.4,'#ffcf7a');
    // o senador e a segurança
    const v=B.unit('vip',28,10);v.nome=NOME;v.hp=v.maxHp=90;v.armor=.2;v.coat='#2a2e3a';v.trim='#ffd36b';v.hair='#c9c0b0';
    v.safeRoom=true;v.fleeMsg='O senador está correndo para o bunker!';
    v.route=[{x:28,y:10},{x:25.5,y:25.5},{x:10,y:28},{x:30.5,y:30.5},{x:28,y:44},{x:30.5,y:25.5},{x:47,y:22},{x:28,y:10}];v.ri=0;v.idleT=4;
    B.m.vip=v;
    for(const k of [0,1]){const g=B.unit('guarda',28+(k?.8:-.8),10.6);B.arm(g,7);g.escort=v;}
    let n=0;for(let k=0;k<60&&n<4;k++){const x=MX+1+((r()*26)|0),y=MY+1+((r()*26)|0);if(!B.m.inMaze(x+.5,y+.5)||(x>=24&&x<=31&&y>=24&&y<=31))continue;const g=B.unit('guarda',x+.5,y+.5);B.arm(g,7);g.home={x:x+.5,y:y+.5};n++;}
    for(const [x,y] of [[24.5,48.6],[31.5,48.6],[46.5,20],[10,30],[47,6],[50.5,6]]){const g=B.unit('guarda',x,y);B.arm(g,7);g.home={x,y};}
    for(let k=0;k<6;k++){const p=B.randTile((t,x,y)=>t===T_GRASS&&x>7&&x<53&&y>13&&y<46&&!(x>13&&x<42&&y>13&&y<42));if(p){const c=B.unit('civil',p.x,p.y);c.coat='#3a5a2a';c.trim='#8ab04a';c.umb=null;c.home={x:p.x,y:p.y};}}
    for(let k=0;k<4;k++){const c=B.unit('civil',22+k*3.5,11.2);c.still=true;c.umb=null;c.coat='#e8e4dc';c.trim='#1c1c22';}
    for(let k=0;k<10;k++){const p=B.randTile((t,x,y)=>t===T_WALK&&y>=48);if(p)B.unit('civil',p.x,p.y);}
    for(const [x,y] of [[14,48.6],[44,48.6]])B.unit('policia',x,y);
    B.lanes([{y:50.5,dx:1,dy:0},{y:51.5,dx:-1,dy:0}],6);
    B.m.paint=(g,TS)=>{
      for(let y=8;y<=12;y++)for(let x=14;x<=42;x++){g.fillStyle=(x+y)%2?'rgba(220,210,190,.12)':'rgba(220,210,190,.05)';g.fillRect(x*TS,y*TS,TS,TS);}
      g.fillStyle='rgba(150,120,80,.35)';for(let y=MY;y<MY+L;y++)for(let x=MX;x<MX+L;x++)if(!mw[y-MY][x-MX])g.fillRect(x*TS+3,y*TS+3,TS-6,TS-6);
      g.fillStyle='rgba(255,177,61,.5)';for(let x=46;x<=51;x+=1)g.fillRect(x*TS,12*TS+2,TS*.5,4);
    };
  },
  *script(S,M){
    S.obj('kill',`Elimine o ${NOME}`,{primary:true});
    S.obj('quiet','Opcional: elimine o senador sem dar tempo ao alarme');
    S.obj('lights','Opcional: derrube os três holofotes');
    S.fork(watchKill(S,M));S.fork(watchQuiet(S,M));S.fork(watchLights(S,M));S.fork(watchBunker(S,M));S.fork(watchRival(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:mj_intro1');yield S.camTo({x:28,y:26},.8,3.2);yield S.talkDone();
    S.say('ctl:mj_intro2');yield S.camTo({x:14,y:15},1.1,2.4);yield S.talkDone();
    S.say('ctl:mj_intro3');yield S.camTo({x:48,y:10},1.1,2.4);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
  },
};
function* watchKill(S,M){
  yield S.until(()=>M.vip.dead&&!M.vip.vanished);
  yield S.wait(.1);
  S.setObj('kill',{state:'done'});if(S.objState('relay')==='active')S.setObj('relay',{state:'done'});S.clearTimer();
  S.say('ctl:mj_win');
  S.win(`O ${NOME} foi eliminado nos Jardins Altos.`);
}
function* watchQuiet(S,M){
  const v=M.vip;
  yield S.until(()=>M.corpAlert||v.dead);
  const byShot=v.lastHit!=null&&M.t-v.lastHit<.3;
  if(!byShot&&!v.dead){S.setObj('quiet',{state:'failed'});return;}
  const t0=M.t;yield S.until(()=>v.dead||v.safe||M.t-t0>4);
  if(v.dead&&!v.vanished){S.setObj('quiet',{state:'done'});S.bonus('Senador abatido antes do alarme',3000);}
  else S.setObj('quiet',{state:'failed'});
}
function* watchLights(S,M){
  const spots=M.cams.filter(c=>c.spot);
  yield S.until(()=>spots.every(c=>c.dead));
  S.setObj('lights',{state:'done'});S.bonus('Jardim no escuro',1000);
}
function* watchBunker(S,M){
  const v=M.vip;
  yield S.until(()=>v.dead||M.corpAlert);
  if(v.dead)return;
  S.say('ctl:mj_flee');
  yield S.until(()=>v.dead||v.safe);
  if(v.dead)return;
  for(const u of M.units)if(!u.dead&&u.x>=48&&u.x<50&&u.y>=11&&u.y<12){u.y=12.5;u.path=null;}
  M.flags.shut=true;S.block(48,11,49,11,true);
  S.say('ctl:mj_bunker');
  S.obj('relay','Sobrecarregue os dois relés do bunker (0/2)',{primary:true});
  S.timer('TÚNEL DE FUGA EM',75);
  let last=-1;
  for(;;){
    const n=(M.flags.rel1?1:0)+(M.flags.rel2?1:0);
    if(n!==last){last=n;S.setObj('relay',{text:`Sobrecarregue os dois relés do bunker (${n}/2)`});}
    if(n>=2||v.dead||S.timerDone())break;
    yield S.wait(.3);
  }
  if(v.dead)return;
  if(S.timerDone()&&!(M.flags.rel1&&M.flags.rel2)){S.clearTimer();v.vanished=true;v.dead=true;S.setObj('relay',{state:'failed'});S.say('ctl:mj_fail');S.fail('O senador fugiu pelo túnel do bunker.');return;}
  S.clearTimer();S.setObj('relay',{state:'done'});
  M.flags.shut=false;S.block(48,11,49,11,false);S.boom(49,12,1.2,30);
  S.say('ctl:mj_open');
  S.setObj('kill',{text:'O bunker está aberto: acabe com o senador'});
}
function* watchRival(S,M){
  yield S.until(()=>M.vip.safe||M.vip.dead);
  if(M.vip.dead)return;
  yield S.wait(3);
  let riv=null;for(const id of ['sibila','navalha','mariposa','ferro']){riv=S.rival(id,49,15,.6);if(riv)break;}
  if(!riv)return;
  riv.home={x:49,y:16};S.obj('riv',`Opcional: elimine ${riv.nome}`);
  yield S.until(()=>riv.dead);
  S.setObj('riv',{state:riv.vanished?'failed':'done'});
}
