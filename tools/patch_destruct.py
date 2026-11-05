"""Patch único: destruição de cenário (registro da mudança)."""
import os, sys
V2 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'v2')

def patch(fn, reps):
    p = os.path.join(V2, fn)
    s = open(p, encoding='utf-8').read()
    for a, b in reps:
        if a not in s:
            sys.exit(f'{fn}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('js/core.js', [
    ("export const hooks={log(){},end(){},decal(){},convert(){},vo(){}};",
     "export const hooks={log(){},end(){},decal(){},convert(){},vo(){},destroy(){}};"),
])

patch('js/world.js', [
    ("  setM(m);\n  const lampCols=", "  setM(m);initDestruct(m);\n  const lampCols="),
    ("  for(let i=0;i<NN;i++){m.walk[i]=isWalk(tile[i])?1:0;m.road[i]=tile[i]===T_ROAD?1:0;}",
     "  for(let i=0;i<NN;i++){m.walk[i]=isWalk(tile[i])?1:0;m.road[i]=tile[i]===T_ROAD?1:0;}\n  initDestruct(m);"),
    ("const MISSIONS={docas:DOCAS};",
     "const MISSIONS={docas:DOCAS};\nfunction initDestruct(m){m.bldAt=new Int16Array(N*N).fill(-1);m.blds.forEach((b,i)=>{for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++)m.bldAt[y*N+x]=i;});m.glass=new Set();m.wallDecals=[];m.debris=[];m.fires=[];}"),
])

SIM_DESTRUCT = r"""
/* ---------- destruição de cenário ---------- */
const DIRT=['#5a5f6a','#3a3f4a','#6b6f78','#4a4238'];
export function rayWall(x0,y0,dx,dy,maxT){
  let tx=Math.floor(x0),ty=Math.floor(y0);
  const sx=dx>0?1:-1,sy=dy>0?1:-1,tdx=dx?Math.abs(1/dx):Infinity,tdy=dy?Math.abs(1/dy):Infinity;
  let tmx=dx>0?(tx+1-x0)/dx:dx<0?(x0-tx)/-dx:Infinity,tmy=dy>0?(ty+1-y0)/dy:dy<0?(y0-ty)/-dy:Infinity,t=0,nx=0,ny=0;
  for(let k=0;k<64;k++){
    if(tmx<tmy){tx+=sx;t=tmx;tmx+=tdx;nx=-sx;ny=0;}else{ty+=sy;t=tmy;tmy+=tdy;nx=0;ny=-sy;}
    if(t>maxT)return null;
    if(tx<0||ty<0||tx>=N||ty>=N)return {t,tx,ty,nx,ny,out:true};
    if(M.tile[ty*N+tx]===T_BLD)return {t,tx,ty,nx,ny};
  }
  return null;
}
const addDecal=d=>{M.wallDecals.push(d);};
function wallHit(h,ex,ey,z,src,dmg){
  const bi=M.bldAt[h.ty*N+h.tx],b=bi>=0?M.blds[bi]:null;
  for(let k=0;k<3;k++)part(ex,ey,z*30,h.nx*2+(Math.random()-.5)*2,h.ny*2+(Math.random()-.5)*2,10+Math.random()*20,.3,'#ffd28c',1,3);
  if(!b){if(Math.random()<.25)sfx('ric',ex,ey);return;}
  if(b.style==='cont'||b.style==='ware'){damageBld(b,dmg*.35,src);if(Math.random()<.3)sfx('ric',ex,ey);addDecal({kind:'hole',x:ex,y:ey,z,nx:h.nx,ny:h.ny,w:.08,h:.08});return;}
  const along=h.nx!==0?ey-h.ty:ex-h.tx,fl=Math.floor(z/FLOOR),vz=(z-fl*FLOOR)/FLOOR,col=along<.5?0:1;
  const inWin=!b.kiosk&&fl<b.fl&&vz>.28&&vz<.75&&((along>.12&&along<.44)||(along>.56&&along<.88));
  if(!(inWin&&breakWindow(b,h.tx,h.ty,h.nx,h.ny,fl,col)))addDecal({kind:'hole',x:ex,y:ey,z,nx:h.nx,ny:h.ny,w:.07,h:.07});
  if(b.fl<=2&&!b.corp)damageBld(b,dmg*.25,src);
}
function breakWindow(b,tx,ty,nx,ny,fl,col){
  const key=tx+','+ty+','+nx+','+ny+','+fl+','+col;if(M.glass.has(key))return false;M.glass.add(key);
  const c=col?.72:.28,fx=nx!==0?tx+(nx>0?1:0):tx+c,fy=nx!==0?ty+c:ty+(ny>0?1:0),z=fl*FLOOR+FLOOR*.515;
  addDecal({kind:'glass',x:fx,y:fy,z,nx,ny,w:.33,h:.25});
  for(let k=0;k<7;k++)part(fx+nx*.08,fy+ny*.08,z*30,nx*(.5+Math.random()*1.5)+(Math.random()-.5),ny*(.5+Math.random()*1.5)+(Math.random()-.5),Math.random()*15,1.4,'#bfe8ff',1,3);
  sfx('glass',fx,fy);
  return true;
}
function damageBld(b,dmg,src){
  if(b.dead||!(b.style==='cont'||(b.fl<=2&&!b.corp&&!b.style)))return;
  if(b.hp===undefined)b.hp=b.style==='cont'?80*b.fl:150;
  b.hp-=dmg;if(b.hp<=0)destroyBld(b,src);
}
function destroyBld(b,src){
  b.dead=true;
  for(let y=b.y;y<b.y+b.d;y++)for(let x=b.x;x<b.x+b.w;x++){const i=y*N+x;M.tile[i]=T_PLAZA;M.walk[i]=1;M.hgt[i]=0;M.bldAt[i]=-1;}
  const cx=b.x+b.w/2,cy=b.y+b.d/2,cont=b.style==='cont';
  spawnDebris(cx,cy,.3+b.fl*.25,8+b.w*b.d*3,cont?['#8a2e22','#1f4e7a','#6b6f78','#2f6b3e','#b8681e']:DIRT,4,[.1,.35],b.w,b.d);
  for(let i=0;i<22;i++){const a=Math.random()*TAU,s=Math.random()*1.5;part(cx+(Math.random()-.5)*b.w,cy+(Math.random()-.5)*b.d,10,Math.cos(a)*s,Math.sin(a)*s,15+Math.random()*25,2+Math.random()*1.5,'#4a4740',1,2);}
  sfx(cont?'crash':'collapse',cx,cy);if(!REDUCED)M.shake=Math.min(1,M.shake+.5);
  hooks.destroy('bld',b);noise(cx,cy,12,src);
}
export function spawnDebris(x,y,z,n,cols,spd,sz,w=0,d=0){
  for(let i=0;i<n;i++){const a=Math.random()*TAU,s=spd*(.3+Math.random()*.7);M.debris.push({x:x+(Math.random()-.5)*w,y:y+(Math.random()-.5)*d,z,vx:Math.cos(a)*s,vy:Math.sin(a)*s,vz:2+Math.random()*spd,rx:Math.random()*3,ry:Math.random()*3,rz:0,vr:(Math.random()-.5)*12,s:sz[0]+Math.random()*(sz[1]-sz[0]),col:pick(cols),life:20+Math.random()*12});}
  if(M.debris.length>420)M.debris.splice(0,M.debris.length-420);
}
function breakLamp(l){
  if(l.dead)return;l.dead=true;
  for(let k=0;k<10;k++)part(l.x+.3,l.y,(l.tall?3.9:2.2)*30,(Math.random()-.5)*2,(Math.random()-.5)*2,Math.random()*20,.9,'#fff0b0',1,3);
  sfx('glass',l.x,l.y);hooks.destroy('lamp',l);
}
function litAt(x,y){for(const l of M.lamps){if(l.dead)continue;const r=l.tall?5:3.2;if(Math.abs(l.x-x)<r&&Math.abs(l.y-y)<r&&Math.hypot(l.x-x,l.y-y)<r)return true;}return false;}
export function addFire(x,y,life){
  if(x<0||y<0||x>=N||y>=N)return;const t=M.tile[(y|0)*N+(x|0)];
  if(t===T_WATER||t===T_BLD||M.fires.length>40)return;M.fires.push({x,y,life,max:life,tick:0});
}
function burnTree(tr){
  if(tr.dead)return;tr.dead=true;const i=(tr.y|0)*N+(tr.x|0);
  if(M.tile[i]===T_TREE){M.tile[i]=T_GRASS;M.walk[i]=1;}
  hooks.destroy('tree',tr);addFire(tr.x,tr.y,9);
  spawnDebris(tr.x,tr.y,.8,5,['#24452f','#3a2a1e','#1a1a1a'],2.5,[.08,.22]);
}
function blast(x,y,r,dmg,src){
  const R=r+.6,x0=Math.max(0,Math.floor(x-R)),x1=Math.min(N-1,Math.floor(x+R)),y0=Math.max(0,Math.floor(y-R)),y1=Math.min(N-1,Math.floor(y+R));
  const hitB=new Set();
  for(let ty=y0;ty<=y1;ty++)for(let tx=x0;tx<=x1;tx++){
    const i=ty*N+tx,t=M.tile[i];if(Math.hypot(tx+.5-x,ty+.5-y)>R)continue;
    if(t===T_FENCE){M.tile[i]=T_WALK;M.walk[i]=1;hooks.destroy('fence',{x:tx,y:ty});spawnDebris(tx+.5,ty+.5,.5,4,['#8a92a4','#5a6070'],3,[.05,.18]);}
    else if(t===T_TREE){const tr=M.trees.find(q=>!q.dead&&(q.x|0)===tx&&(q.y|0)===ty);if(tr)burnTree(tr);else{M.tile[i]=T_GRASS;M.walk[i]=1;}}
    else if(t===T_BLD){
      const bi=M.bldAt[i],b=bi>=0?M.blds[bi]:null;if(b)hitB.add(b);
      for(const [nx,ny] of [[1,0],[-1,0],[0,1],[0,-1]]){
        const ax=tx+nx,ay=ty+ny;if(ax<0||ay<0||ax>=N||ay>=N||M.tile[ay*N+ax]===T_BLD)continue;
        const fx=tx+.5+nx*.5,fy=ty+.5+ny*.5;if((x-fx)*nx+(y-fy)*ny<=0)continue;
        const fd=Math.hypot(x-fx,y-fy);if(fd>R)continue;
        if(b&&!b.style&&!b.kiosk)for(let fl=0;fl<Math.min(2,b.fl);fl++)for(let c=0;c<2;c++)if(Math.random()<1.2-fd/R)breakWindow(b,tx,ty,nx,ny,fl,c);
        addDecal({kind:'scorch',x:fx,y:fy,z:.5,nx,ny,w:1.15,h:1});
      }
    }
  }
  for(const b of hitB)damageBld(b,dmg*2.2,src);
  for(const l of M.lamps)if(!l.dead&&Math.hypot(l.x-x,l.y-y)<R)breakLamp(l);
  if(Math.random()<.8)addFire(x+(Math.random()-.5),y+(Math.random()-.5),6+Math.random()*4);
  spawnDebris(x,y,.2,8,DIRT,4,[.05,.16]);
}
function updDestruct(dt){
  for(let i=M.debris.length-1;i>=0;i--){
    const d=M.debris[i];d.life-=dt;if(d.life<=0){M.debris.splice(i,1);continue;}
    if(d.vz!==0||d.z>d.s*.3+.001){
      d.vz-=12*dt;d.x+=d.vx*dt;d.y+=d.vy*dt;d.z+=d.vz*dt;d.rx+=d.vr*dt;d.rz+=d.vr*.5*dt;
      if(d.z<d.s*.3){d.z=d.s*.3;if(Math.abs(d.vz)<1.2){d.vz=d.vx=d.vy=d.vr=0;d.rx=Math.round(d.rx/(Math.PI/2))*Math.PI/2;d.rz=0;}else{d.vz*=-.35;d.vx*=.55;d.vy*=.55;d.vr*=.5;}}
    }
  }
  for(let i=M.fires.length-1;i>=0;i--){
    const f=M.fires[i];f.life-=dt;if(f.life<=0){M.fires.splice(i,1);continue;}
    const k=Math.min(1,f.life/2);
    if(Math.random()<.65*k)part(f.x+(Math.random()-.5)*.6,f.y+(Math.random()-.5)*.6,2,(Math.random()-.5)*.3,(Math.random()-.5)*.3,25+Math.random()*25,.5+Math.random()*.4,Math.random()<.5?'#ff8c28':'#ffcf50',1,1);
    if(Math.random()<.15*k)part(f.x,f.y,20,(Math.random()-.5)*.3,(Math.random()-.5)*.3,25,2,'#26262c',1,2);
    f.tick-=dt;
    if(f.tick<=0){
      f.tick=.3;
      for(const u of M.units)if(!u.dead&&!u.inCar&&u.kind!=='torre'&&Math.abs(u.x-f.x)<.6&&Math.abs(u.y-f.y)<.6)u.burn=Math.max(u.burn,1.5);
      for(const tr of M.trees)if(!tr.dead&&Math.abs(tr.x-f.x)<1.2&&Math.abs(tr.y-f.y)<1.2&&Math.random()<.07)burnTree(tr);
      for(const p of M.props)if(!p.dead&&Math.abs(p.x-f.x)<.7&&Math.abs(p.y-f.y)<.7&&Math.random()<.15)hurtProp(p,999,null);
    }
  }
}
"""

patch('js/sim.js', [
    ("import {N,TAU,T_BLD,T_WALK,clamp,gauss,pick,M,flags,hooks,WD,MAXINV,RESIST,PRESETS,REDUCED,equipable} from './core.js';",
     "import {N,TAU,FLOOR,T_BLD,T_WALK,T_PLAZA,T_GRASS,T_TREE,T_WATER,T_FENCE,clamp,gauss,pick,M,flags,hooks,WD,MAXINV,RESIST,PRESETS,REDUCED,equipable} from './core.js';"),
    ("    const dx=Math.cos(ang),dy=Math.sin(ang);let wt=range;\n    for(let s=.3;s<wt;s+=.12){const px=u.x+dx*s,py=u.y+dy*s;if(px<0||py<0||px>=N||py>=N||M.tile[(py|0)*N+(px|0)]===T_BLD){wt=s;break;}}",
     "    const dx=Math.cos(ang),dy=Math.sin(ang),hw=rayWall(u.x,u.y,dx,dy,range);let wt=hw?hw.t:range;\n    if(hw&&!hw.out){wallHit(hw,u.x+dx*wt,u.y+dy*wt,.62,u,w.dano);const ex=u.x+dx*wt,ey=u.y+dy*wt;addDecal({kind:'scorch',x:ex,y:ey,z:.62,nx:hw.nx,ny:hw.ny,w:.35,h:.35});}\n    for(const l of M.lamps){if(l.dead)continue;const rx=l.x-u.x,ry=l.y-u.y,t=rx*dx+ry*dy;if(t>.3&&t<wt&&Math.abs(rx*dy-ry*dx)<.15)breakLamp(l);}"),
    ("    for(const p of M.props){if(!p.dead&&Math.hypot(p.x-u.x,p.y-u.y)<range)hurtProp(p,w.dano*.5,u);}",
     "    for(const p of M.props){if(!p.dead&&Math.hypot(p.x-u.x,p.y-u.y)<range)hurtProp(p,w.dano*.5,u);}\n    if(Math.random()<.05){const d=range*(.6+Math.random()*.4);addFire(u.x+Math.cos(ang)*d,u.y+Math.sin(ang)*d,5);}\n    for(const tr of M.trees){if(tr.dead)continue;const d=Math.hypot(tr.x-u.x,tr.y-u.y);if(d<range+.5&&Math.random()<.03){let da=Math.abs(Math.atan2(tr.y-u.y,tr.x-u.x)-ang);if(da>Math.PI)da=TAU-da;if(da<.4)burnTree(tr);}}"),
    ("  const dx=Math.cos(a),dy=Math.sin(a);let wt=range;\n  for(let s=.3;s<range;s+=.12){const px=u.x+dx*s,py=u.y+dy*s;if(px<0||py<0||px>=N||py>=N||M.tile[(py|0)*N+(px|0)]===T_BLD){wt=s;break;}}\n  let best=null,bt=wt,car=null,prop=null;",
     "  const dx=Math.cos(a),dy=Math.sin(a),hw=rayWall(u.x,u.y,dx,dy,range);let wt=hw?hw.t:range;\n  let best=null,bt=wt,car=null,prop=null;"),
    ("  const ex=u.x+dx*bt,ey=u.y+dy*bt;\n  M.tracers.push({x1:mx,y1:my,x2:ex,y2:ey,life:.07",
     "  for(const l of M.lamps){if(l.dead)continue;const rx=l.x-u.x,ry=l.y-u.y,t=rx*dx+ry*dy;if(t<.3||t>bt)continue;if(Math.abs(rx*dy-ry*dx)<.1&&Math.random()<.4)breakLamp(l);}\n  const ex=u.x+dx*bt,ey=u.y+dy*bt;\n  M.tracers.push({x1:mx,y1:my,x2:ex,y2:ey,life:.07"),
    ("  else{if(car)hurtCar(car,dmg,u);else if(bt<range-.2&&Math.random()<.25)sfx('ric',ex,ey);for(let k=0;k<3;k++)part(ex,ey,car?12:8,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*20,.25,'#ffd28c',1,3);}",
     "  else if(car){hurtCar(car,dmg,u);for(let k=0;k<3;k++)part(ex,ey,12,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*20,.25,'#ffd28c',1,3);}\n  else if(hw&&!hw.out&&bt>=hw.t-.001)wallHit(hw,ex,ey,.6+gauss()*.12,u,dmg);\n  else for(let k=0;k<2;k++)part(ex,ey,8,(Math.random()-.5)*3,(Math.random()-.5)*3,20+Math.random()*20,.25,'#ffd28c',1,3);"),
    ("  for(const p of M.props){if(!p.dead&&Math.hypot(p.x-x,p.y-y)<r+.3)hurtProp(p,999,src);}\n  noise(x,y,16,src);",
     "  for(const p of M.props){if(!p.dead&&Math.hypot(p.x-x,p.y-y)<r+.3)hurtProp(p,999,src);}\n  blast(x,y,r,dmg,src);\n  noise(x,y,16,src);"),
    ("    explode(c.x,c.y,2,60,src);",
     "    explode(c.x,c.y,2,60,src);spawnDebris(c.x,c.y,.5,10,[c.col,'#111318','#2a2a2a','#0a0a0a'],5,[.12,.3]);addFire(c.x,c.y,14);"),
    ("    let r=isArmed(a)?dr:hr;r*=1.2-.5*a.nr.c;",
     "    let r=isArmed(a)?dr:hr;r*=1.2-.5*a.nr.c;if(!litAt(a.x,a.y))r*=.72;"),
    ("if(M.falling)updFalling(dt);", "if(M.falling)updFalling(dt);updDestruct(dt);"),
    ("/* ---------- guindaste: contêiner em queda ---------- */", SIM_DESTRUCT + "\n/* ---------- guindaste: contêiner em queda ---------- */"),
])

patch('js/audio.js', [
    ("    case 'ric':",
     "    case 'glass':{const o=chain(sp,.35);noise(o,.25,5200,.6,.35*v,'highpass');for(let i=0;i<4;i++)tone(o,2800+Math.random()*3500,2600+Math.random()*3000,.12+Math.random()*.2,.03*v,'sine',.03+i*.05);break;}\n    case 'crash':{const o=chain(sp,.5);noise(o,.6,700,.5,.8*v,'lowpass');tone(o,180,90,.5,.15*v,'sawtooth');tone(o,420,300,.35,.08*v,'square',.05);noise(o,.4,2500,1.5,.12*v,'bandpass',.1);break;}\n    case 'collapse':{const o=chain(sp,.7);noise(o,1.8,180,.4,1*v,'lowpass',0,SND.brown);noise(o,1.2,900,.5,.25*v,'lowpass',.15);for(let i=0;i<6;i++)noise(o,.06,1500+Math.random()*2000,1,.12*v,'bandpass',.1+i*.17);break;}\n    case 'ric':"),
])

RENDER_DESTRUCT = r"""
/* ---------- destruição: marcas nas paredes, destroços, escombros ---------- */
let decalMeshes=null,decalCount={},decalDone=0,debrisMesh=null,lampRefs=null,treeRefs=null,fenceRefs=null;
const MAXD={glass:500,hole:700,scorch:140},MAXDEB=420;
const o3=new THREE.Object3D(),c3=new THREE.Color();
const decalTexCache={};
function decalTex(kind){
  if(decalTexCache[kind])return decalTexCache[kind];
  const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');
  if(kind==='glass'){
    g.fillStyle='rgba(4,6,10,.96)';g.beginPath();g.moveTo(4,6);g.lineTo(20,2);g.lineTo(34,10);g.lineTo(50,3);g.lineTo(61,9);g.lineTo(57,30);g.lineTo(62,52);g.lineTo(44,60);g.lineTo(28,54);g.lineTo(10,61);g.lineTo(3,44);g.lineTo(8,26);g.closePath();g.fill();
    g.strokeStyle='rgba(190,230,255,.75)';g.lineWidth=1.5;for(let k=0;k<7;k++){g.beginPath();g.moveTo(0,Math.random()*64);g.lineTo(10+Math.random()*12,Math.random()*64);g.stroke();g.beginPath();g.moveTo(64,Math.random()*64);g.lineTo(52-Math.random()*12,Math.random()*64);g.stroke();}
  }else if(kind==='hole'){
    const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(0,0,0,1)');gr.addColorStop(.35,'rgba(10,10,12,.95)');gr.addColorStop(.5,'rgba(140,140,150,.5)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);
  }else{
    const gr=g.createRadialGradient(32,40,0,32,36,34);gr.addColorStop(0,'rgba(0,0,0,.85)');gr.addColorStop(.6,'rgba(10,8,6,.5)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);
  }
  const t=new THREE.CanvasTexture(c);decalTexCache[kind]=t;return t;
}
function buildDestruct(){
  decalMeshes={};decalCount={glass:0,hole:0,scorch:0};decalDone=0;
  for(const k of ['scorch','glass','hole']){
    const m=new THREE.InstancedMesh(new THREE.PlaneGeometry(1,1),new THREE.MeshBasicMaterial({map:decalTex(k),transparent:true,depthWrite:false,toneMapped:false,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2}),MAXD[k]);
    m.count=0;m.frustumCulled=false;world.add(m);decalMeshes[k]=m;
  }
  debrisMesh=new THREE.InstancedMesh(new THREE.BoxGeometry(1,1,1),new THREE.MeshLambertMaterial({color:'#ffffff'}),MAXDEB);
  debrisMesh.count=0;debrisMesh.castShadow=true;debrisMesh.frustumCulled=false;debrisMesh.setColorAt(0,c3.set('#ffffff'));world.add(debrisMesh);
}
function syncDestruct(){
  if(!decalMeshes||!M.wallDecals)return;
  const touched=new Set();
  while(decalDone<M.wallDecals.length){
    const d=M.wallDecals[decalDone++],m=decalMeshes[d.kind];if(!m)continue;
    const i=decalCount[d.kind]%MAXD[d.kind];decalCount[d.kind]++;
    o3.position.set(d.x+d.nx*.012,d.z,d.y+d.ny*.012);o3.rotation.set(0,Math.atan2(d.nx,d.ny),d.kind==='glass'?0:Math.random()*TAU);o3.scale.set(d.w,d.h,1);o3.updateMatrix();
    m.setMatrixAt(i,o3.matrix);m.count=Math.min(decalCount[d.kind],MAXD[d.kind]);touched.add(m);
  }
  touched.forEach(m=>m.instanceMatrix.needsUpdate=true);
  const n=Math.min(M.debris.length,MAXDEB);
  for(let i=0;i<n;i++){
    const d=M.debris[i];o3.position.set(d.x,d.z,d.y);o3.rotation.set(d.rx,d.ry,d.rz);o3.scale.set(d.s*1.3,d.s*.6,d.s);o3.updateMatrix();
    debrisMesh.setMatrixAt(i,o3.matrix);if(!d.cc)d.cc=new THREE.Color(d.col);debrisMesh.setColorAt(i,d.cc);
  }
  debrisMesh.count=n;debrisMesh.instanceMatrix.needsUpdate=true;if(debrisMesh.instanceColor)debrisMesh.instanceColor.needsUpdate=true;
}
hooks.destroy=(type,o)=>{
  if(!world)return;
  if(type==='bld'){
    const parts=(o.parts||[]).slice();
    if(o.r3){parts.push(o.r3,...(o.r3.userData.extra||[]));const i=bldMeshes.indexOf(o.r3);if(i>=0)bldMeshes.splice(i,1);}
    parts.forEach(p=>{p.visible=false;});
    const cols=o.style==='cont'?[CONT_COLS[o.col%CONT_COLS.length],'#3a3f4a']:[BPAL[o.pal||0][1],BPAL[o.pal||0][0],'#3a3f4a'];
    const n=Math.max(5,Math.round(o.w*o.d*2.5));
    for(let k=0;k<n;k++){
      const s=.2+Math.random()*.4,m=new THREE.Mesh(new THREE.BoxGeometry(s*1.7,s*.55,s),o.style==='cont'?corrMat(cols[k%cols.length]):lam(cols[k%cols.length]));
      m.position.set(o.x+.15+Math.random()*(o.w-.3),s*.25+Math.random()*.08,o.y+.15+Math.random()*(o.d-.3));m.rotation.set((Math.random()-.5)*.6,Math.random()*3,(Math.random()-.5)*.6);m.castShadow=m.receiveShadow=true;world.add(m);
    }
  }else if(type==='fence'&&fenceRefs){
    const i=fenceRefs.idx.get(o.y*N+o.x);if(i===undefined)return;
    o3.position.set(o.x+.5,.04,o.y+.5);o3.rotation.set(-Math.PI/2+.08,0,Math.random()*3);o3.scale.set(1,1,1);o3.updateMatrix();fenceRefs.panel.setMatrixAt(i,o3.matrix);fenceRefs.panel.instanceMatrix.needsUpdate=true;
    o3.scale.set(0,0,0);o3.updateMatrix();fenceRefs.post.setMatrixAt(i,o3.matrix);fenceRefs.post.instanceMatrix.needsUpdate=true;
  }else if(type==='lamp'&&lampRefs){
    const i=M.lamps.indexOf(o);if(i<0)return;const hs=o.tall?1.75:1;
    o3.position.set(o.x+.25,1.05*hs*.9,o.y);o3.rotation.set(.35,0,-.45);o3.scale.set(1,hs,1);o3.updateMatrix();lampRefs.pole.setMatrixAt(i,o3.matrix);lampRefs.pole.instanceMatrix.needsUpdate=true;
    o3.scale.set(0,0,0);o3.updateMatrix();lampRefs.arm.setMatrixAt(i,o3.matrix);lampRefs.head.setMatrixAt(i,o3.matrix);lampRefs.arm.instanceMatrix.needsUpdate=true;lampRefs.head.instanceMatrix.needsUpdate=true;
    lampT=0;
  }else if(type==='tree'&&treeRefs){
    const i=M.trees.indexOf(o);if(i<0)return;
    o3.position.set(o.x,.12,o.y);o3.rotation.set(0,0,0);o3.scale.set(1.3,.3,1.3);o3.updateMatrix();treeRefs.trunk.setMatrixAt(i,o3.matrix);treeRefs.trunk.instanceMatrix.needsUpdate=true;
    o3.scale.set(0,0,0);o3.updateMatrix();treeRefs.crown.setMatrixAt(i,o3.matrix);treeRefs.crown.instanceMatrix.needsUpdate=true;
  }
};
"""

patch('js/render.js', [
    ("buildWater();buildFence();buildDecor();", "buildWater();buildFence();buildDecor();buildDestruct();"),
    ("m.userData={mats,fade:false};world.add(m);bldMeshes.push(m);", "m.userData={mats,fade:false};world.add(m);bldMeshes.push(m);b.r3=m;"),
    ("      const m=new THREE.Mesh(geo,corrMat(c));m.position.set(b.x+b.w/2,.25+k*.52,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);",
     "      const m=new THREE.Mesh(geo,corrMat(c));m.position.set(b.x+b.w/2,.25+k*.52,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);(b.parts||(b.parts=[])).push(m);"),
    ("    bldMeshes.push(m);\n    const door=", "    bldMeshes.push(m);b.r3=m;\n    const door="),
    ("function buildFence(){", "function buildFence(){fenceRefs=null;"),
    ("  world.add(panel,post);\n}", "  fenceRefs={panel,post,idx:new Map(tiles.map(([x,y],i)=>[y*N+x,i]))};\n  world.add(panel,post);\n}"),
    ("function buildLamps(){", "function buildLamps(){lampRefs=null;"),
    ("  pole.castShadow=true;world.add(pole,arm,head);", "  pole.castShadow=true;world.add(pole,arm,head);lampRefs={pole,arm,head};"),
    ("function buildTrees(){", "function buildTrees(){treeRefs=null;"),
    ("  trunk.castShadow=crown.castShadow=true;crown.receiveShadow=true;world.add(trunk,crown);", "  trunk.castShadow=crown.castShadow=true;crown.receiveShadow=true;world.add(trunk,crown);treeRefs={trunk,crown};"),
    ("const sorted=M.lamps.slice().sort(", "const sorted=M.lamps.filter(l=>!l.dead).sort("),
    ("  for(const u of M.units)if(u.burn>0&&!u.dead)cands.push(", "  for(const f of M.fires||[])cands.push({x:f.x,y:f.y,h:.5,i:(4+Math.random()*1.5)*Math.min(1,f.life/2),c:'#ff7a28'});\n  for(const u of M.units)if(u.burn>0&&!u.dead)cands.push("),
    ("  syncFx();syncDecor(dt);", "  syncFx();syncDecor(dt);syncDestruct();"),
    ("/* ---------- personagens ---------- */", RENDER_DESTRUCT + "\n/* ---------- personagens ---------- */"),
])
print('ok')
