/* Áudio: efeitos sintetizados com posição estéreo, vozes com filtro de rádio/megafone, trilha dinâmica e ambiente. */
import {settings} from './core.js';
import {VO as VO_PT} from './vo.js';
import {VO_EN} from './vo_en.js';
import {LANG} from './i18n.js';
const VO=LANG==='en'?VO_EN:VO_PT,VODIR=LANG==='en'?'audio/vo_en/':'audio/vo/';

export const SND={on:true,ac:null,master:null,noise:null,last:{},verb:null,bus:{}};
export const listener={x:0,y:0,rx:1,ry:0};
const clamp=(v,a,b)=>v<a?a:v>b?b:v;

export function audioInit(){
  if(SND.ac){if(SND.ac.state==='suspended')SND.ac.resume();return;}
  try{
    const ac=new (window.AudioContext||window.webkitAudioContext)();SND.ac=ac;
    const comp=ac.createDynamicsCompressor();comp.threshold.value=-14;comp.ratio.value=4;comp.attack.value=.003;comp.release.value=.25;comp.connect(ac.destination);
    SND.master=ac.createGain();SND.master.gain.value=SND.on?.8:0;SND.master.connect(comp);
    for(const b of ['sfx','vo','mus','amb']){const g=ac.createGain();g.connect(SND.master);SND.bus[b]=g;}
    SND.duck=ac.createGain();SND.duck.connect(SND.bus.mus);
    applyVolumes();
    const len=ac.sampleRate*2,b=ac.createBuffer(1,len,ac.sampleRate),d=b.getChannelData(0);
    for(let i=0;i<len;i++)d[i]=Math.random()*2-1;SND.noise=b;
    const bl=ac.createBuffer(1,len,ac.sampleRate),bd=bl.getChannelData(0);let last=0;
    for(let i=0;i<len;i++){last=(last+.02*(Math.random()*2-1))/1.02;bd[i]=last*3.5;}SND.brown=bl;
    const il=ac.sampleRate*1.6,ib=ac.createBuffer(2,il,ac.sampleRate);
    for(let c=0;c<2;c++){const ch=ib.getChannelData(c);for(let i=0;i<il;i++)ch[i]=(Math.random()*2-1)*Math.pow(1-i/il,3);}
    const conv=ac.createConvolver();conv.buffer=ib;const vg=ac.createGain();vg.gain.value=.32;conv.connect(vg);vg.connect(SND.master);SND.verb=conv;
    startAmbience();startMusic();loadVO();startEngine();
  }catch(e){console.warn('áudio indisponível',e);SND.ac=null;}
}
export function applyVolumes(){
  if(!SND.ac)return;const t=SND.ac.currentTime;
  SND.bus.sfx.gain.setTargetAtTime(settings.sfx??1,t,.05);SND.bus.vo.gain.setTargetAtTime(settings.vo??1,t,.05);
  SND.bus.mus.gain.setTargetAtTime((settings.mus??.6)*.55,t,.05);SND.bus.amb.gain.setTargetAtTime((settings.sfx??1)*.9,t,.05);
}
export function setMute(m){SND.on=!m;if(SND.master)SND.master.gain.setTargetAtTime(SND.on?.8:0,SND.ac.currentTime,.05);}

/* ---------- espacialização ---------- */
function spatial(x,y){
  if(x===undefined)return {v:1,pan:0,cut:20000};
  const dx=x-listener.x,dy=y-listener.y,d=Math.hypot(dx,dy),v=1-d/28;
  if(v<=.02)return null;
  return {v,pan:clamp((dx*listener.rx+dy*listener.ry)/12,-.9,.9),cut:500+17000*v*v};
}
function chain(sp,wet=.0,bus='sfx'){
  const ac=SND.ac,g=ac.createGain(),lp=ac.createBiquadFilter(),pn=ac.createStereoPanner();
  lp.type='lowpass';lp.frequency.value=sp.cut;pn.pan.value=sp.pan;
  g.connect(lp);lp.connect(pn);pn.connect(SND.bus[bus]);
  if(wet>0&&SND.verb){const s=ac.createGain();s.gain.value=wet*(1.3-sp.v*.6);pn.connect(s);s.connect(SND.verb);}
  return g;
}
function noise(out,dur,freq,q,vol,type='bandpass',delay=0,buf){
  const ac=SND.ac,t=ac.currentTime+delay,src=ac.createBufferSource();src.buffer=buf||SND.noise;
  const f=ac.createBiquadFilter();f.type=type;f.frequency.value=freq;f.Q.value=q;
  const g=ac.createGain();g.gain.setValueAtTime(vol,t);g.gain.exponentialRampToValueAtTime(.0008,t+dur);
  src.connect(f);f.connect(g);g.connect(out);src.start(t,Math.random()*1.5);src.stop(t+dur+.05);
}
function tone(out,f0,f1,dur,vol,type='square',delay=0,att=0){
  const ac=SND.ac,t=ac.currentTime+delay,o=ac.createOscillator(),g=ac.createGain();o.type=type;
  o.frequency.setValueAtTime(f0,t);o.frequency.exponentialRampToValueAtTime(Math.max(20,f1),t+dur);
  if(att){g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(vol,t+att);}else g.gain.setValueAtTime(vol,t);
  g.gain.exponentialRampToValueAtTime(.0008,t+dur);
  o.connect(g);g.connect(out);o.start(t);o.stop(t+dur+.05);
}

/* ---------- efeitos ---------- */
export function sfx(type,x,y){
  if(!SND.ac||!SND.on)return;
  const now=SND.ac.currentTime,gap=type==='smg'?.035:type==='hit'?.06:.03;
  if(SND.last[type]&&now-SND.last[type]<gap)return;SND.last[type]=now;
  const sp=spatial(x,y);if(!sp)return;const v=sp.v;
  const vary=.9+Math.random()*.2;
  switch(type){
    case 'pist':{const o=chain(sp,.35);tone(o,2200*vary,900,.012,.25*v);noise(o,.14,1500*vary,.7,.6*v);tone(o,130*vary,48,.11,.45*v,'sine');break;}
    case 'smg':{const o=chain(sp,.25);tone(o,2600*vary,1200,.008,.18*v);noise(o,.075,2100*vary,.9,.42*v);tone(o,110,50,.06,.25*v,'sine');break;}
    case 'shot':{const o=chain(sp,.45);noise(o,.05,4000,.5,.5*v,'highpass');noise(o,.4,800*vary,.5,.9*v,'lowpass');tone(o,95,28,.3,.65*v,'sine');break;}
    case 'laser':{const o=chain(sp,.4);tone(o,3200*vary,140,.35,.2*v,'sawtooth');tone(o,1600,70,.3,.14*v,'square');tone(o,90,40,.4,.35*v,'sine');break;}
    case 'flame':{const o=chain(sp,.1);noise(o,.16,420,.4,.38*v,'lowpass');noise(o,.08,2400,.6,.06*v);break;}
    case 'boom':{const o=chain(sp,.7);noise(o,.06,3500,.4,.7*v,'highpass');noise(o,1.4,300,.3,1.2*v,'lowpass');tone(o,70,22,1,.9*v,'sine');noise(o,.9,1200,.6,.15*v,'bandpass',.12);break;}
    case 'glass':{const o=chain(sp,.35);noise(o,.25,5200,.6,.35*v,'highpass');for(let i=0;i<4;i++)tone(o,2800+Math.random()*3500,2600+Math.random()*3000,.12+Math.random()*.2,.03*v,'sine',.03+i*.05);break;}
    case 'crash':{const o=chain(sp,.5);noise(o,.6,700,.5,.8*v,'lowpass');tone(o,180,90,.5,.15*v,'sawtooth');tone(o,420,300,.35,.08*v,'square',.05);noise(o,.4,2500,1.5,.12*v,'bandpass',.1);break;}
    case 'collapse':{const o=chain(sp,.7);noise(o,1.8,180,.4,1*v,'lowpass',0,SND.brown);noise(o,1.2,900,.5,.25*v,'lowpass',.15);for(let i=0;i<6;i++)noise(o,.06,1500+Math.random()*2000,1,.12*v,'bandpass',.1+i*.17);break;}
    case 'drone':{const o=chain(sp,.1);tone(o,118*vary,124*vary,.5,.03*v,'sawtooth');tone(o,236*vary,230*vary,.5,.012*v,'square');break;}
    case 'steam':{const o=chain(sp,.15);noise(o,.9,3400,.5,.2*v,'highpass');noise(o,.7,1100,.7,.1*v);break;}
    case 'train':{const o=chain(sp,.3);noise(o,1.5,140,.4,.55*v,'lowpass',0,SND.brown);for(let i=0;i<3;i++)noise(o,.05,900,2,.12*v,'bandpass',.2+i*.38);break;}
    case 'ric':{const o=chain(sp,.4);tone(o,3400*vary,1300,.18,.07*v,'sine');break;}
    case 'hit':{const o=chain(sp,.05);noise(o,.07,600,1,.3*v,'lowpass');break;}
    case 'die':{const o=chain(sp,.1);noise(o,.2,280,1,.3*v,'lowpass');break;}
    case 'alarm':{const o=chain({v:.7,pan:0,cut:20000},.5);for(let i=0;i<3;i++){tone(o,880,880,.14,.1,'square',i*.32);tone(o,620,620,.14,.1,'square',i*.32+.16);}break;}
    case 'siren':{const o=chain(sp||{v:.6,pan:0,cut:9000},.5);for(let i=0;i<2;i++){tone(o,650,1150,.4,.08,'triangle',i*.8);tone(o,1150,650,.4,.08,'triangle',i*.8+.4);}break;}
    case 'ui':{const o=chain({v:1,pan:0,cut:20000});tone(o,1300,1700,.05,.05);break;}
    case 'hack':{const o=chain({v:1,pan:0,cut:20000},.2);tone(o,300,1800,.45,.08);tone(o,1800,2400,.15,.06,'square',.45);break;}
    case 'convert':{const o=chain(sp,.6);tone(o,220,880,.6,.08*v,'sine',0,.1);tone(o,330,1320,.6,.05*v,'triangle',.05,.1);break;}
    case 'pickup':{const o=chain({v:1,pan:0,cut:20000});tone(o,900,1400,.07,.06,'square');tone(o,1400,1900,.07,.05,'square',.08);break;}
    case 'door':{const o=chain(sp,.1);noise(o,.12,240,1.2,.4*v,'lowpass');tone(o,110,70,.1,.2*v,'sine');break;}
    case 'honk':{const o=chain(sp,.4);tone(o,400,392,.25,.07*v,'square');tone(o,500,492,.25,.05*v,'square');break;}
    case 'win':{const o=chain({v:1,pan:0,cut:20000},.5);[523,659,784,1046].forEach((f,i)=>tone(o,f,f,.5,.08,'triangle',i*.14,.02));break;}
    case 'lose':{const o=chain({v:1,pan:0,cut:20000},.5);[392,330,262,196].forEach((f,i)=>tone(o,f,f*.98,.5,.08,'triangle',i*.18,.02));break;}
  }
}

/* ---------- motor do carro do esquadrão ---------- */
let eng=null;
function startEngine(){
  const ac=SND.ac,o=ac.createOscillator(),o2=ac.createOscillator(),lp=ac.createBiquadFilter(),g=ac.createGain(),pn=ac.createStereoPanner();
  o.type='sawtooth';o2.type='square';o.frequency.value=40;o2.frequency.value=40.5;lp.type='lowpass';lp.frequency.value=300;g.gain.value=0;
  o.connect(lp);o2.connect(lp);lp.connect(g);g.connect(pn);pn.connect(SND.bus.sfx);o.start();o2.start();eng={o,o2,lp,g,pn};
}
export function engine(speed,x,y){
  if(!eng)return;const t=SND.ac.currentTime,sp=speed>0?spatial(x,y):null;
  const vol=sp?(.05+speed*.012)*sp.v:0;
  eng.g.gain.setTargetAtTime(vol,t,.15);
  eng.o.frequency.setTargetAtTime(38+speed*9,t,.2);eng.o2.frequency.setTargetAtTime(38.5+speed*9,t,.2);
  eng.lp.frequency.setTargetAtTime(220+speed*90,t,.2);if(sp)eng.pn.pan.setTargetAtTime(sp.pan,t,.1);
}

/* ---------- ambiente: tráfego, zumbido elétrico, trovões, sirenes distantes (sem ruído de chuva) ---------- */
function startAmbience(){
  const ac=SND.ac,A=SND.bus.amb;
  const traf=ac.createBufferSource();traf.buffer=SND.brown;traf.loop=true;const tl=ac.createBiquadFilter();tl.type='lowpass';tl.frequency.value=160;const tg=ac.createGain();tg.gain.value=.22;
  traf.connect(tl);tl.connect(tg);tg.connect(A);traf.start();
  const hum=ac.createOscillator();hum.type='sawtooth';hum.frequency.value=55;const hl=ac.createBiquadFilter();hl.type='lowpass';hl.frequency.value=140;const hg=ac.createGain();hg.gain.value=.018;
  hum.connect(hl);hl.connect(hg);hg.connect(A);hum.start();
  const events=()=>{
    if(SND.on&&SND.ac.state==='running'){
      const r=Math.random(),o=chain({v:.5,pan:Math.random()*1.6-.8,cut:2500},.8,'amb');
      if(r<.35){noise(o,4+Math.random()*2,90,.5,1.1,'lowpass',0,SND.brown);noise(o,.3,500,.5,.25,'lowpass');}
      else if(r<.7){for(let i=0;i<3;i++){tone(o,600,900,.6,.025,'triangle',i*1.2,.2);tone(o,900,600,.6,.025,'triangle',i*1.2+.6,.2);}}
      else tone(o,90,70,2.5,.05,'sawtooth',0,.8);
    }
    setTimeout(events,25000+Math.random()*40000);
  };
  setTimeout(events,12000);
}

/* ---------- trilha dinâmica ---------- */
const mtof=m=>440*Math.pow(2,(m-69)/12);
const CHORDS=[[57,60,64],[53,57,60],[50,53,57],[52,56,59],[57,60,64],[53,57,60],[55,59,62],[52,56,59]];
const LAYERS={pad:[.5,.45,.38,.3],bass:[0,.55,.75,.9],arp:[.28,.22,.45,.6],hat:[0,0,.45,.75],kick:[0,0,.5,.9],snare:[0,0,0,.7]};
const MUS={step:0,next:0,bpm:94,int:-1,lv:{},timer:null};
function startMusic(){
  const ac=SND.ac;
  for(const k in LAYERS){const g=ac.createGain();g.gain.value=0;g.connect(SND.duck);MUS.lv[k]=g;}
  const dl=ac.createDelay();dl.delayTime.value=60/MUS.bpm*.75;const fb=ac.createGain();fb.gain.value=.35;const dlp=ac.createBiquadFilter();dlp.type='lowpass';dlp.frequency.value=2200;
  MUS.lv.arp.connect(dl);dl.connect(dlp);dlp.connect(fb);fb.connect(dl);dlp.connect(SND.duck);
  MUS.next=ac.currentTime+.2;setIntensity(0);
  MUS.timer=setInterval(schedule,30);
}
export function setIntensity(i){
  if(!SND.ac||i===MUS.int)return;MUS.int=i;const t=SND.ac.currentTime;
  for(const k in LAYERS)MUS.lv[k].gain.setTargetAtTime(LAYERS[k][i],t,i>MUS.prev?.4:1.6);MUS.prev=i;
}
function schedule(){
  const ac=SND.ac;if(!ac||ac.state!=='running')return;
  const sd=60/MUS.bpm/4;
  while(MUS.next<ac.currentTime+.15){
    const s=MUS.step%16,bar=(MUS.step>>4)%8,ch=CHORDS[bar],t=MUS.next;
    if(s===0)for(const n of ch)for(const det of [-6,6]){
      const o=ac.createOscillator(),f=ac.createBiquadFilter(),g=ac.createGain();o.type='sawtooth';o.frequency.value=mtof(n);o.detune.value=det;
      f.type='lowpass';f.frequency.value=700;g.gain.setValueAtTime(.0001,t);g.gain.linearRampToValueAtTime(.03,t+.9);g.gain.setValueAtTime(.03,t+sd*14);g.gain.linearRampToValueAtTime(.0001,t+sd*17);
      o.connect(f);f.connect(g);g.connect(MUS.lv.pad);o.start(t);o.stop(t+sd*17.2);
    }
    if([0,3,6,8,11,14].includes(s)){
      const n=ch[0]-12+(s===14?7:0),o=ac.createOscillator(),f=ac.createBiquadFilter(),g=ac.createGain();o.type='sawtooth';o.frequency.value=mtof(n);
      f.type='lowpass';f.frequency.setValueAtTime(1100,t);f.frequency.exponentialRampToValueAtTime(160,t+sd*1.6);f.Q.value=6;
      g.gain.setValueAtTime(.16,t);g.gain.exponentialRampToValueAtTime(.001,t+sd*1.8);o.connect(f);f.connect(g);g.connect(MUS.lv.bass);o.start(t);o.stop(t+sd*2);
    }
    if(Math.random()<(s%2?.35:.7)){
      const n=ch[(Math.random()*3)|0]+12*(1+((Math.random()*2)|0)),o=ac.createOscillator(),g=ac.createGain();o.type='triangle';o.frequency.value=mtof(n);
      g.gain.setValueAtTime(.06,t);g.gain.exponentialRampToValueAtTime(.001,t+sd*1.5);o.connect(g);g.connect(MUS.lv.arp);o.start(t);o.stop(t+sd*1.6);
    }
    if(s%2===0)noise(MUS.lv.hat,s%4===2?.07:.035,8000,.7,.12,'highpass',t-ac.currentTime);
    if(s===0||s===8||(s===10&&bar%2)){const o=ac.createOscillator(),g=ac.createGain();o.frequency.setValueAtTime(150,t);o.frequency.exponentialRampToValueAtTime(42,t+.22);g.gain.setValueAtTime(.55,t);g.gain.exponentialRampToValueAtTime(.001,t+.3);o.connect(g);g.connect(MUS.lv.kick);o.start(t);o.stop(t+.32);}
    if(s===4||s===12){noise(MUS.lv.snare,.16,1800,.8,.32,'bandpass',t-ac.currentTime);const o=ac.createOscillator(),g=ac.createGain();o.type='triangle';o.frequency.setValueAtTime(220,t);o.frequency.exponentialRampToValueAtTime(140,t+.08);g.gain.setValueAtTime(.12,t);g.gain.exponentialRampToValueAtTime(.001,t+.1);o.connect(g);g.connect(MUS.lv.snare);o.start(t);o.stop(t+.12);}
    MUS.next+=sd;MUS.step++;
  }
}

/* ---------- vozes ---------- */
const voBuf=new Map();
function loadVO(){
  const files=new Set();for(const k in VO)for(const [f] of VO[k])files.add(f);
  for(const f of files)fetch(`${VODIR}${f}.mp3`).then(r=>r.ok?r.arrayBuffer():Promise.reject()).then(b=>SND.ac.decodeAudioData(b)).then(buf=>voBuf.set(f,buf)).catch(()=>{});
}
const curves=new Map();
function shaper(k){let c=curves.get(k);if(!c){c=new Float32Array(1024);for(let i=0;i<1024;i++){const x=i/512-1;c[i]=Math.tanh(x*k)/Math.tanh(k);}curves.set(k,c);}const w=SND.ac.createWaveShaper();w.curve=c;return w;}
/* papel de cada chave: canal (rádio do esquadrão ou mundo), filtro e cor da legenda */
const ROLE={riv:{fx:'helmet',col:'#ff8a5a'},ag:{comm:1,fx:'radio',col:'#4fd8ff'},ctl:{comm:1,fx:'radio',col:'#ffa53d',who:'CONTROLE'},pol:{fx:'mega',col:'#9fc3ff'},grd:{fx:'helmet',col:'#ff8a96'},ene:{fx:'robot',col:'#ff6a7a'},civ:{fx:'none',col:'#d3dcea'},vip:{fx:'none',col:'#ffd36b'},sci:{fx:'none',col:'#c9ffe0'}};
const COOL={'ag:sel':1.2,'ag:mov':1.4,'ag:atk':2.5,'ag:kill':3,'ag:hurt':6,'ag:rel':5,'civ':4,'pol:warn':4,'grd:contact':3.5,'grd:alert':3,'ene:alert':4};
const lastKey={},lastFile={};let commBusyUntil=0,commQueue=[],worldActive=0;
function pickLine(key){const L=VO[key];if(!L||!L.length)return null;let i=(Math.random()*L.length)|0;if(L.length>1&&L[i][0]===lastFile[key])i=(i+1)%L.length;lastFile[key]=L[i][0];return L[i];}
export function vo(key,u){
  let k=key;
  if(key.startsWith('ag:'))k=`${key}:${(u&&u.voz)||'m'}`;
  if(key==='civ')k=Math.random()<.5?'civ:f':'civ:m';
  const role=ROLE[k.split(':')[0]];if(!role)return null;
  const now=performance.now()/1000,cd=COOL[key]??2.5;
  if(lastKey[key]&&now-lastKey[key]<cd)return null;
  let sp=null;
  if(!role.comm){sp=u?spatial(u.x,u.y):{v:1,pan:0,cut:20000};if(!sp||sp.v<.15||worldActive>=2)return null;}
  else if(now<commBusyUntil){
    if(key.startsWith('ctl:')&&commQueue.length<3)commQueue.push({key,u,t:now});
    return null;
  }
  const line=pickLine(k);if(!line)return null;lastKey[key]=now;
  const [file,text]=line,buf=voBuf.get(file);
  const dur=buf?buf.duration:Math.max(.8,text.length*.06);
  if(role.comm){commBusyUntil=now+dur+.25;setTimeout(flushComm,(dur+.3)*1000);}
  if(buf&&SND.ac&&SND.on)playVoice(buf,role,sp,u);
  return {text,comm:!!role.comm,col:role.col,who:role.who||(u&&u.nome?u.nome.toUpperCase():'')};
}
let onComm=null;export function setCommHandler(f){onComm=f;}
export function commFree(){return performance.now()/1000>=commBusyUntil&&!commQueue.length;}
function flushComm(){const now=performance.now()/1000;while(commQueue.length){const q=commQueue.shift();if(now-q.t>5)continue;const r=vo(q.key,q.u);if(r&&onComm)onComm(r,q.u);break;}}
function playVoice(buf,role,sp,u){
  const ac=SND.ac,t=ac.currentTime,src=ac.createBufferSource();src.buffer=buf;
  src.playbackRate.value=role===ROLE.ag?(u&&u.vozRate)||1:.97+Math.random()*.06;
  const out=ac.createGain(),pn=ac.createStereoPanner();pn.pan.value=sp?sp.pan:0;out.gain.value=sp?sp.v*1.1:1;
  out.connect(pn);pn.connect(SND.bus.vo);
  let head=src;
  const filt=(type,f,q)=>{const b=ac.createBiquadFilter();b.type=type;b.frequency.value=f;b.Q.value=q||.7;head.connect(b);head=b;};
  if(role.fx==='radio'){filt('highpass',380);filt('lowpass',3400);const w=shaper(2.2);head.connect(w);head=w;}
  else if(role.fx==='mega'){filt('bandpass',1500,.9);const w=shaper(5);head.connect(w);head=w;filt('lowpass',3800);}
  else if(role.fx==='helmet'){filt('highpass',300);filt('lowpass',2500);const w=shaper(3);head.connect(w);head=w;}
  else if(role.fx==='robot'){const rm=ac.createGain();rm.gain.value=0;const lfo=ac.createOscillator();lfo.frequency.value=58;lfo.connect(rm.gain);lfo.start(t);lfo.stop(t+buf.duration+.2);head.connect(rm);head=rm;filt('lowpass',3200);}
  if(sp&&sp.cut<20000)filt('lowpass',sp.cut);
  head.connect(out);
  if(!role.comm&&SND.verb){const s=ac.createGain();s.gain.value=.35;out.connect(s);s.connect(SND.verb);}
  const dur=buf.duration/src.playbackRate.value;
  if(role.comm){
    const sq=chain({v:1,pan:pn.pan.value,cut:20000},0,'vo');noise(sq,.05,2600,2,.12);noise(sq,.07,2600,2,.1,'bandpass',dur+.02);
    SND.duck.gain.setTargetAtTime(.4,t,.05);SND.duck.gain.setTargetAtTime(1,t+dur+.1,.4);
  }else worldActive++;
  src.onended=()=>{if(!role.comm)worldActive=Math.max(0,worldActive-1);};
  src.start(t+(role.comm?.05:0));
}
