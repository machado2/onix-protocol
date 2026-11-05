/* Missão feita à mão: "Linha de Fuga" — Vila Ferrugem.
   Clínica clandestina do Consórcio no alto do morro (norte), favela densa no meio,
   estrada ao sul (van) e estação do teleférico a leste. Primeira aparição do Navalha. */
import {T_ROAD,T_WALK,T_PLAZA,T_GRASS,T_FENCE,RNG} from '../core.js';

const SPAWN={x:8.5,y:48.5};
const VAN={x:22.5,y:48.2},CABLE={x:52.5,y:24.5};
const blocked=(x,y)=>(x>=26&&x<=30)||(x>=31&&x<=52&&y>=28&&y<=32)||(x>=4&&x<=18&&y>=29&&y<=39)||(x>=49&&y>=19&&y<=28)||(x>=18&&x<=27&&y>=45);

export const FAVELA={
  nome:'Linha de Fuga',
  spawn:SPAWN,
  build(B){
    const r=RNG(9091);
    B.rect(T_WALK,0,0,56,56);
    B.rect(T_PLAZA,0,0,56,2);
    // clínica cercada
    B.rect(T_PLAZA,19,3,37,13);
    for(let x=18;x<=38;x++){B.tile(x,2,T_FENCE);if(x<27||x>29)B.tile(x,14,T_FENCE);}
    for(let y=2;y<=14;y++){B.tile(18,y,T_FENCE);B.tile(38,y,T_FENCE);}
    B.bld({x:21,y:4,w:15,d:4,fl:4,pal:4,v:3,neon:1,sign:'HÉLICE BIOMÉDICA',signCol:'#5dffa0',corp:true,ant:true});
    B.decor({type:'generator',x:20.6,y:11.2});
    B.term({x:20.6,y:12.5,prog:0,done:false,flag:'power',vo:'ctl:m2_power',msg:'Gerador da clínica desligado: torretas e holofotes apagados.'});
    // escadaria, feira, campo e teleférico
    B.rect(T_PLAZA,27,15,29,49);
    B.rect(T_PLAZA,32,29,51,31);
    for(const x of [33,36,39,42,45,48])B.bld({x,y:29,w:2,d:1,fl:1,pal:5,neon:(x/3)%4|0,kiosk:true});
    B.rect(T_GRASS,5,30,17,38);
    B.rect(T_PLAZA,50,20,56,27);
    B.decor({type:'cable',x:54.2,y:23.2});
    B.rect(T_ROAD,0,50,56,51);
    B.rect(T_WALK,18,45,27,49);
    B.decor({type:'van',x:VAN.x,y:VAN.y-1.2,ang:0});
    // favela: faixas de casas com becos entre elas
    for(const ry of [16,20,24,28,32,36,40,44]){
      let x=1,sinceGap=0;
      while(x<55){
        if(blocked(x,ry)&&blocked(x,ry+2)){x++;sinceGap=0;continue;}
        if(sinceGap>=5||r()<.22){x++;sinceGap=0;continue;}
        const w=2+((r()*3)|0),d=r()<.25?2:3;
        let ok=true;for(let yy=ry;yy<ry+d;yy++)for(let xx=x;xx<x+w;xx++)if(xx>55||blocked(xx,yy))ok=false;
        if(!ok){x++;sinceGap=0;continue;}
        B.bld({x,y:ry,w,d,fl:2+((r()*3)|0)+(r()<.15?1:0),pal:6+((r()*5)|0),v:(r()*4)|0,roof:r()<.55?2:r()<.3?1:0,ou:(r()*8)|0,ov:(r()*8)|0,neon:r()<.08?((r()*4)|0):-1,favela:true});
        x+=w;sinceGap+=w;
      }
      for(let k=0;k<3;k++){const lx=2+((r()*48)|0);B.decor({type:'laundry',x1:lx,y1:ry+3.5,x2:lx+3+((r()*3)|0),y2:ry+3.5,h:1.75});}
    }
    // cidade ao sul da estrada
    for(const [x,w,fl,pal] of [[2,6,5,0],[10,5,7,2],[17,7,4,1],[31,6,6,3],[39,8,8,0],[49,6,5,2]])B.bld({x,y:53,w,d:4,fl,pal,v:(r()*4)|0,neon:r()<.5?((r()*4)|0):-1});
    // luzes
    for(const [x,y] of [[20,3.5],[36.5,3.5],[20,13],[36.5,13]])B.lamp(x,y,'#cfe8ff',true,{clinic:true});
    for(let y=17;y<=47;y+=6)B.lamp(27.3,y+.5,r()<.5?'#ffb35c':'#ff6ad5');
    for(const x of [34,40,46])B.lamp(x+.5,31.6,'#ffd27a');
    B.lamp(51.5,21.5,'#7fe3ff');B.lamp(17.5,30.5,'#ffd27a',true);
    for(const x of [5,15,35,45])B.lamp(x+.5,49.5,'#ffb35c');
    for(const [x,y] of [[24,47],[45,31],[19,13],[33,12]])B.prop(x,y);
    // gente
    const sci=B.unit('cientista',28.5,10.5);sci.nome='Dra. Sofia Tanaka';B.m.sci=sci;B.m.evacs=[VAN,CABLE];B.m.evac=VAN;
    for(const [x,y] of [[24,10],[33,10],[28,12.5],[35,12],[25.5,8.6]]){const g=B.unit('guarda',x,y);B.arm(g,2);g.home={x,y};}
    for(const [x,y] of [[28.5,36]]){const g=B.unit('guarda',x,y);B.arm(g,2);g.home={x,y};}
    for(const [x,y] of [[19.5,12.5],[37.5,12.5]]){const t=B.unit('torre',x,y);t.clinic=true;t.hp=t.maxHp=100;t.acc=.45;}
    for(let k=0;k<46;k++){const p=B.randTile((t,x,y)=>(t===T_WALK||t===T_PLAZA)&&y>=15&&y<=49);if(p){const c=B.unit('civil',p.x,p.y);c.morador=true;}}
    for(let k=0;k<12;k++){const c=B.unit('civil',33+Math.random()*17,30+Math.random()*1.6);c.morador=true;c.home={x:c.x,y:c.y};}
    B.lanes([{y:50.5,dx:1,dy:0},{y:51.5,dx:-1,dy:0}],5);
    B.m.paint=(g,TS)=>{
      g.strokeStyle='rgba(235,240,230,.55)';g.lineWidth=3;
      g.strokeRect(5.3*TS,30.3*TS,12.4*TS,8.4*TS);
      g.beginPath();g.moveTo(11.5*TS,30.3*TS);g.lineTo(11.5*TS,38.7*TS);g.stroke();
      g.beginPath();g.arc(11.5*TS,34.5*TS,1.4*TS,0,Math.PI*2);g.stroke();
      g.fillStyle='rgba(60,40,30,.35)';for(let k=0;k<30;k++)g.fillRect((5.5+Math.random()*12)*TS,(30.5+Math.random()*8)*TS,10,6);
    };
  },
  *script(S,M){
    S.obj('reach','Encontre a Dra. Sofia Tanaka na clínica do Consórcio',{primary:true});
    S.obj('power','Opcional: desligue o gerador da clínica');
    S.obj('noharm','Opcional: não fira nenhum morador');
    S.fork(watchHarm(S,M));S.fork(watchPower(S,M));S.fork(watchSci(S,M));
    S.cine(true);
    yield S.camTo(SPAWN,1.2,.01);yield S.wait(.6);
    S.say('ctl:m2_intro1');yield S.camTo({x:28.5,y:9},1.0,3.2);yield S.talkDone();
    S.say('ctl:m2_intro2');yield S.camTo({x:21,y:11.5},1.25,2);yield S.talkDone();
    S.say('ctl:m2_intro3');yield S.camTo({x:40,y:30.5},1.05,3);yield S.talkDone();
    yield S.camTo(SPAWN,1.2,1.8);
    S.cine(false);
    yield S.until(()=>M.sci.follow||M.sci.dead);
    if(M.sci.dead)return;
    S.setObj('reach',{state:'done'});
    S.say('sci:m2',M.sci);
    S.obj('exfil','Leve a doutora à van (sul) ou ao teleférico (leste)',{primary:true});
    yield S.wait(4);
    // emboscada do Navalha na estrada sul
    const van=S.car(56.4,50.5,Math.PI,'#2a2d34',160);S.drive(van,[{x:VAN.x+3.5,y:50.5}]);
    yield S.until(S.arrived(van));
    if(!van.dead){
      S.rival('navalha',van.x,van.y-1.2,.7);
      for(let k=0;k<1;k++){const e=S.spawn('inimigo',van.x+(k?1:-1),van.y-1,3);e.alerted=true;e.home={x:VAN.x,y:VAN.y};}
    }
    S.say('ctl:m2_navalha');yield S.talkDone();S.say('ctl:m2_cable');
    yield S.wait(6);
    if(!M.flags.harm){
      for(let k=0;k<4;k++){const c=S.spawn('civil',40+k*1.5,30.5);c.morador=true;c.w=k%2?'smg':'pistola';c.mun=30;c.fac='player';c.follower=true;c.coat=['#3a6a3a','#6a3a3a','#3a3a6a','#6a6a3a'][k];M.followers++;}
      S.say('ctl:m2_help');yield S.wait(1.5);S.say('civ:m2help',M.units.find(u=>u.morador&&u.follower));
    }
  },
};
function* watchHarm(S,M){
  yield S.until(()=>M.stats.civis>0);
  M.flags.harm=true;S.setObj('noharm',{state:'failed'});S.say('ctl:m2_noh');
}
function* watchPower(S,M){
  yield S.until(()=>M.flags.power);
  for(const u of M.units)if(u.clinic)u.off=true;
  for(const l of M.lamps)if(l.clinic&&!l.dead){l.dead=true;S.lampOff(l);}
  S.setObj('power',{state:'done'});S.bonus('Clínica no escuro',1500);
}
function* watchSci(S,M){
  yield S.until(()=>M.sci.dead||(M.sci.follow&&M.evacs.some(e=>Math.hypot(M.sci.x-e.x,M.sci.y-e.y)<2.3)));
  if(M.sci.dead){S.fail('A Dra. Tanaka morreu durante a fuga.');return;}
  S.setObj('exfil',{state:'done'});
  if(!M.flags.harm){S.setObj('noharm',{state:'done'});S.bonus('Nenhum morador ferido',2000);}
  S.say('ctl:m2_win');
  S.win('A Dra. Sofia Tanaka foi tirada da Vila Ferrugem.');
}
