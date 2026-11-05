/* Renderização 3D (Three.js): cidade low-poly, câmera isométrica giratória, luz dinâmica, pixelização e bloom. */
import * as THREE from 'three';
import {EffectComposer} from 'three/addons/postprocessing/EffectComposer.js';
import {RenderPass} from 'three/addons/postprocessing/RenderPass.js';
import {UnrealBloomPass} from 'three/addons/postprocessing/UnrealBloomPass.js';
import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';
import {GTAOPass} from 'three/addons/postprocessing/GTAOPass.js';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {N,P,NB,TAU,FLOOR,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,T_WATER,T_FENCE,T_POST,T_GLASS,M,settings,hooks,WD,BPAL,NEON,WINLIT,REDUCED,RNG,pick,clamp} from './core.js';
import {listener} from './audio.js';
import {curW,isArmed} from './sim.js';
import {props,propMesh,propInstances,propDef} from './props.js';
import {pbrGround,pbrWall,groundTypeTex,LAYER} from './pbr.js';
import {assets,makeChar,attach,play,cloakChar,makeCarModel,cullBegin,onScreen} from './chars.js';

const cv=document.getElementById('cv');
const ov=document.getElementById('ov'),octx=ov.getContext('2d');
export const renderer=new THREE.WebGLRenderer({canvas:cv,antialias:false,powerPreference:'high-performance'});
renderer.shadowMap.enabled=settings.shadows;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.8;
const scene=new THREE.Scene();scene.background=new THREE.Color('#05060b');scene.fog=new THREE.Fog('#080b16',95,150);
const camera=new THREE.OrthographicCamera(-10,10,10,-10,.1,400);
export const camS={x:28,y:28,yaw:0,yawA:0,zoom:1.1};
const PITCH=Math.atan(1/Math.SQRT2),CAMD=110,SCALE=46;
let VW=innerWidth,VH=innerHeight,ODPR=1;
const hemi=new THREE.HemisphereLight('#6f84c0','#2a1a24',1.15);scene.add(hemi);
const moon=new THREE.DirectionalLight('#a7bcf0',1.1);moon.castShadow=true;moon.shadow.mapSize.set(4096,4096);moon.shadow.radius=3;
{const s=moon.shadow.camera;s.left=-30;s.right=30;s.top=30;s.bottom=-30;s.near=1;s.far=160;}moon.shadow.bias=-.0006;moon.shadow.normalBias=.02;
scene.add(moon,moon.target);
/* ambiente para reflexos: noite urbana com placas de neon */
function buildEnv(){
  const es=new THREE.Scene();es.background=new THREE.Color('#05070d');
  const add=(col,int,x,y,z,w,h)=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({color:new THREE.Color(col).multiplyScalar(int),side:THREE.DoubleSide}));m.position.set(x,y,z);m.lookAt(0,0,0);es.add(m);};
  add('#3a4a78',1,0,30,0,60,60);add('#ff6ad5',2.2,22,6,-10,8,3);add('#4fd8ff',2.2,-20,5,14,10,3);add('#ffb35c',2.5,10,4,22,12,2);add('#a66bff',1.6,-18,8,-18,6,6);add('#1a2236',1,0,-10,0,80,80);
  const pm=new THREE.PMREMGenerator(renderer);const rt=pm.fromScene(es,.04);pm.dispose();return rt.texture;
}
scene.environment=buildEnv();

const lampLights=[],fxLights=[];
for(let i=0;i<12;i++){const l=new THREE.PointLight('#ffb35c',0,9,1.4);scene.add(l);lampLights.push(l);}
for(let i=0;i<6;i++){const l=new THREE.PointLight('#ffaa55',0,9,1.4);scene.add(l);fxLights.push(l);}
const composer=new EffectComposer(renderer,new THREE.WebGLRenderTarget(1,1,{type:THREE.HalfFloatType,samples:4}));
composer.addPass(new RenderPass(scene,camera));
const gtao=new GTAOPass(scene,camera,256,256);gtao.blendIntensity=.85;gtao.updateGtaoMaterial({radius:.9,distanceExponent:1.4,thickness:1.2,scale:1,samples:12});composer.addPass(gtao);
export let PR=1;let dynScale=1,dynT=0,dynAvg=16;
const bloom=new UnrealBloomPass(new THREE.Vector2(256,256),.75,.45,.72);composer.addPass(bloom);
composer.addPass(new OutputPass());

export function resize(){
  VW=innerWidth;VH=innerHeight;const pr=PR=Math.min(window.devicePixelRatio||1,2)*(settings.q||1)*dynScale;gtao.enabled=!!settings.ao;
  renderer.setPixelRatio(pr);renderer.setSize(VW,VH,false);
  composer.setPixelRatio(pr);composer.setSize(VW,VH);gtao.setSize(Math.round(VW*pr),Math.round(VH*pr));
  ODPR=Math.min(window.devicePixelRatio||1,2);ov.width=Math.round(VW*ODPR);ov.height=Math.round(VH*ODPR);
  makeVignette();
}
/* luzes dinâmicas custam caro por pixel: Ultra acende todas; Alta, as 6 lâmpadas mais próximas e 3 efeitos; Média e Baixa, 3 e 2 */
function lightBudget(){const u=!!settings.ao,nl=(settings.q||1)<1?3:6,nf=(settings.q||1)<1?2:3;lampLights.forEach((l,i)=>{l.visible=u||i<nl;});fxLights.forEach((l,i)=>{l.visible=u||i<nf;});}
lightBudget();
export function applyGfx(){
  lightBudget();
  renderer.shadowMap.enabled=settings.shadows;moon.castShadow=settings.shadows;
  scene.traverse(o=>{if(o.material)(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>m.needsUpdate=true);});
  resize();
}
addEventListener('resize',resize);

/* ---------- câmera ---------- */
const ray=new THREE.Raycaster(),ndc=new THREE.Vector2(),plane=new THREE.Plane(new THREE.Vector3(0,1,0),0),tmp=new THREE.Vector3();
function updCam(){
  const a=Math.PI/4+camS.yawA,h=CAMD*Math.cos(PITCH);
  camera.position.set(camS.x+Math.cos(a)*h,CAMD*Math.sin(PITCH),camS.y+Math.sin(a)*h);
  camera.lookAt(camS.x,0,camS.y);
  const s=SCALE*camS.zoom;camera.left=-VW/2/s;camera.right=VW/2/s;camera.top=VH/2/s;camera.bottom=-VH/2/s;
  camera.updateProjectionMatrix();camera.updateMatrixWorld();
  moon.position.set(camS.x-22,48,camS.y-6);moon.target.position.set(camS.x,0,camS.y);moon.target.updateMatrixWorld();
}
export function camAxes(){const a=Math.PI/4+camS.yawA;return {fx:-Math.cos(a),fy:-Math.sin(a),rx:Math.sin(a),ry:-Math.cos(a)};}
export function toWorld(sx,sy){updCam();ndc.set(sx/VW*2-1,-(sy/VH)*2+1);ray.setFromCamera(ndc,camera);const hit=ray.ray.intersectPlane(plane,tmp);return hit?{x:tmp.x,y:tmp.z}:{x:camS.x,y:camS.y};}
export function toScreen(x,y,h=0){tmp.set(x,h,y).project(camera);return {x:(tmp.x+1)/2*VW,y:(1-tmp.y)/2*VH,z:tmp.z};}
export function centerOn(x,y){camS.x=clamp(x,0,N);camS.y=clamp(y,0,N);}
export function rotateCam(d){camS.yaw+=d;}
export function zoomCam(f){camS.zoomT=clamp((camS.zoomT??camS.zoom)*f,.55,2.2);}

/* ---------- materiais e texturas compartilhados ---------- */
const matCache=new Map();
function lam(col){let m=matCache.get('l'+col);if(!m){m=new THREE.MeshStandardMaterial({color:col,roughness:.78,metalness:.06});m.userData.shared=true;matCache.set('l'+col,m);}return m;}
function basic(col,extra){const k='b'+col+(extra?JSON.stringify(extra):'');let m=matCache.get(k);if(!m){m=new THREE.MeshBasicMaterial(Object.assign({color:col,toneMapped:false},extra||{}));m.userData.shared=true;matCache.set(k,m);}return m;}
const vcMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.62,metalness:.12});vcMat.userData.shared=true;
const cloakMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.3,metalness:.5,transparent:true,opacity:.18,depthWrite:false,emissive:'#1a6f88'});cloakMat.userData.shared=true;
const wreckMat=new THREE.MeshStandardMaterial({vertexColors:true,color:'#2a2a2a',roughness:.9});wreckMat.userData.shared=true;
function canvasTex(c){const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=8;return t;}
function colGeo(geo,hex){const c=new THREE.Color(hex),n=geo.attributes.position.count,a=new Float32Array(n*3);for(let i=0;i<n;i++){a[i*3]=c.r;a[i*3+1]=c.g;a[i*3+2]=c.b;}geo.setAttribute('color',new THREE.BufferAttribute(a,3));return geo;}
const box=(w,h,d,x,y,z,col)=>colGeo(new THREE.BoxGeometry(w,h,d).translate(x,y,z),col);
const cyl=(rt,rb,h,s,x,y,z,col)=>colGeo(new THREE.CylinderGeometry(rt,rb,h,s).translate(x,y,z),col);
const softTex=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.4,'rgba(255,255,255,.55)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);return new THREE.CanvasTexture(c);})();

const winCache=new Map();
function winMats(pal,v,corp){
  const key=pal*16+v+(corp?1000:0);let r=winCache.get(key);if(r)return r;
  const S=32,c=document.createElement('canvas'),e=document.createElement('canvas');c.width=e.width=c.height=e.height=S*16;
  const g=c.getContext('2d',{willReadFrequently:true}),ge=e.getContext('2d');g.scale(2,2);ge.scale(2,2);const rng=RNG(key*991+3),[ct,cl,cr]=BPAL[pal],wins=[];
  g.fillStyle=cl;g.fillRect(0,0,S*8,S*8);ge.fillStyle='#000';ge.fillRect(0,0,S*8,S*8);
  for(let j=0;j<8;j++)for(let i=0;i<8;i++){
    const x=i*S,y=j*S;
    if(pal>=6){
      if(rng()<.35){g.fillStyle=rng()<.5?'rgba(0,0,0,.1)':'rgba(255,255,255,.07)';g.fillRect(x,y,S,S);}
      g.fillStyle='rgba(0,0,0,.3)';g.fillRect(x,y+S-2,S,2);
      const lit=rng()<.35,col=lit?pick(['#ffcf7a','#ffd99a','#9fe8ff','#ff9ad8'],rng):(rng()<.5?'#14181f':'#3a2e28');
      g.fillStyle=col;g.fillRect(x+10,y+9,12,12);wins.push([x+10,y+9,12,12]);if(lit){ge.fillStyle=col;ge.fillRect(x+10,y+9,12,12);}
      g.fillStyle='rgba(0,0,0,.35)';g.fillRect(x+9,y+21,14,2);
      if(rng()<.12){g.fillStyle=pick(['#e0e0e0','#ff5a8a','#5ad0ff','#ffd040'],rng);g.globalAlpha=.5;g.fillRect(x+2,y+24,S-4,3);g.globalAlpha=1;}
      continue;
    }
    g.fillStyle='rgba(255,255,255,.035)';g.fillRect(x,y,S,2);g.fillStyle='rgba(0,0,0,.25)';g.fillRect(x,y+S-3,S,3);
    const lit=rng()<(corp?.5:.32);
    for(const wx of corp?[3]:[4,18]){
      const ww=corp?26:10;wins.push([x+wx,y+8,ww,15]);
      if(lit||rng()<.08){const col=corp?(rng()<.5?'#9fe8ff':'#ffd6d6'):pick(WINLIT,rng);g.fillStyle=col;g.fillRect(x+wx,y+8,ww,15);ge.fillStyle=col;ge.globalAlpha=.55+rng()*.45;ge.fillRect(x+wx,y+8,ww,15);ge.globalAlpha=1;
        if(rng()<.4){g.fillStyle='rgba(0,0,0,.35)';g.fillRect(x+wx,y+8,ww,6);}}
      else{g.fillStyle=corp?'#0c1420':'#11161f';g.fillRect(x+wx,y+8,ww,15);g.fillStyle='rgba(120,150,200,.08)';g.fillRect(x+wx,y+8,ww,3);}
    }
  }
  // alfa do mapa: 1 na parede, 0,5 nas janelas (o shader PBR usa como máscara)
  const id=g.getImageData(0,0,c.width,c.height),px=id.data,W=c.width;
  for(const [wx,wy,ww,wh] of wins)for(let yy=wy*2;yy<(wy+wh)*2;yy++)for(let xx=wx*2;xx<(wx+ww)*2;xx++)px[(yy*W+xx)*4+3]=128;
  g.putImageData(id,0,0);
  const map=canvasTex(c,true),emi=canvasTex(e,true);map.wrapS=map.wrapT=emi.wrapS=emi.wrapT=THREE.RepeatWrapping;
  const side=new THREE.MeshStandardMaterial({map,emissiveMap:emi,emissive:'#ffffff',emissiveIntensity:1.6,roughness:.7,metalness:.06});
  const roof=new THREE.MeshStandardMaterial({color:ct,roughness:.85,metalness:.05});
  const fs=side.clone();fs.transparent=true;fs.opacity=.13;fs.depthWrite=false;
  const fr=roof.clone();fr.transparent=true;fr.opacity=.13;fr.depthWrite=false;
  const wl=corp?LAYER.panels:pal>=6?[LAYER.plaster,LAYER.bricks,LAYER.corrugated,LAYER.plaster][v%4]:[LAYER.concrete,LAYER.plaster,LAYER.panels,LAYER.bricks,LAYER.panels,LAYER.plaster][pal];
  const rl=pal>=6?LAYER.corrugated:LAYER.concrete;
  pbrWall(side,wl);pbrWall(fs,wl);pbrWall(roof,rl,.7,1);pbrWall(fr,rl,.7,1);
  [side,roof,fs,fr].forEach(m=>m.userData.shared=true);
  r={norm:[side,side,roof,roof,side,side],fade:[fs,fs,fr,fr,fs,fs]};winCache.set(key,r);return r;
}
const signCache=new Map();
function signMat(text,col){
  const k=text+col;let m=signCache.get(k);if(m)return m;
  const c=document.createElement('canvas');c.width=256;c.height=64;const g=c.getContext('2d');
  g.fillStyle='rgba(5,6,12,.92)';g.fillRect(0,0,256,64);g.strokeStyle=col;g.lineWidth=4;g.strokeRect(4,4,248,56);
  g.font='700 34px "Chakra Petch", sans-serif';g.textAlign='center';g.textBaseline='middle';g.fillStyle=col;g.shadowColor=col;g.shadowBlur=12;g.fillText(text,128,34);
  m=new THREE.MeshBasicMaterial({map:canvasTex(c),toneMapped:false});m.userData.shared=true;signCache.set(k,m);return m;
}

/* ---------- construção da cena ---------- */
let groundType=null,world=null,ground=null,groundCan=null,gctx=null,groundTex=null,bldMeshes=[],blinkMat=null,termObjs=[],propObjs=[],evacRing=null,escRing=null;
const TS=48;
function disposeWorld(){
  if(!world)return;scene.remove(world);
  world.traverse(o=>{if(o.geometry&&!o.geometry.userData.shared)o.geometry.dispose();if(o.material){(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>{if(!m.userData.shared)m.dispose();});}});
  if(groundTex)groundTex.dispose();if(groundType)groundType.dispose();groundType=null;world=null;
}
export function buildScene(){
  disposeWorld();
  world=new THREE.Group();scene.add(world);bldMeshes=[];termObjs=[];propObjs=[];dropMeshes.clear();
  acList=[];buildGround();buildBuildings();buildTrees();buildLamps();buildStreetProps();buildObjectives();buildFx();buildMini();buildWater();buildFence();buildDecor();buildDestruct();buildSecurity();
  lampT=0;
}
function buildGround(){
  const S=N*TS;groundCan=document.createElement('canvas');groundCan.width=groundCan.height=S;gctx=groundCan.getContext('2d');
  const spec=document.createElement('canvas');spec.width=spec.height=S/4;const sg=spec.getContext('2d');
  const rng=RNG(M.di*77+5),g=gctx;
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){
    const t=M.tile[y*N+x],j=Math.floor(rng()*10-5);
    const X=x*TS,Y=y*TS;
    if(t===T_ROAD){g.fillStyle=`rgb(${24+j},${27+j},${36+j})`;g.fillRect(X,Y,TS,TS);sg.fillStyle='#777';}
    else if(t===T_WALK){g.fillStyle=`rgb(${48+j},${53+j},${66+j})`;g.fillRect(X,Y,TS,TS);g.fillStyle='rgba(0,0,0,.25)';g.fillRect(X,Y,TS,1);g.fillRect(X,Y,1,TS);g.fillRect(X+TS/2,Y,1,TS);sg.fillStyle='#3a3a3a';}
    else if(t===T_PLAZA||t===T_GLASS){g.fillStyle=((x+y)&1)?`rgb(${58+j},${50+j},${72+j})`:`rgb(${52+j},${45+j},${65+j})`;g.fillRect(X,Y,TS,TS);g.fillStyle='rgba(255,255,255,.04)';g.fillRect(X+2,Y+2,TS-4,TS-4);sg.fillStyle='#444';}
    else if(t===T_WATER){g.fillStyle=`rgb(${6+j/2},${16+j},${28+j})`;g.fillRect(X,Y,TS,TS);for(let k=0;k<3;k++){g.fillStyle='rgba(90,150,200,.12)';g.fillRect(X+rng()*TS,Y+rng()*TS,8+rng()*10,1);}sg.fillStyle='#ddd';}
    else if(t===T_FENCE||t===T_POST){g.fillStyle=`rgb(${44+j},${46+j},${54+j})`;g.fillRect(X,Y,TS,TS);sg.fillStyle='#333';}
    else if(t===T_GRASS||t===T_TREE){g.fillStyle=`rgb(${22+j},${40+j},${30+j})`;g.fillRect(X,Y,TS,TS);for(let k=0;k<6;k++){g.fillStyle='rgba(60,110,70,.25)';g.fillRect(X+rng()*TS,Y+rng()*TS,2,3);}sg.fillStyle='#000';}
    else{g.fillStyle='#0b0d12';g.fillRect(X,Y,TS,TS);sg.fillStyle='#000';}
    sg.fillRect(x*TS/4,y*TS/4,TS/4,TS/4);
  }
  // meio-fio
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){
    if(M.tile[y*N+x]!==T_ROAD)continue;
    const nb=(dx,dy)=>{const X=x+dx,Y=y+dy;return X>=0&&Y>=0&&X<N&&Y<N&&M.tile[Y*N+X]!==T_ROAD;};
    g.fillStyle='#5a6070';
    if(nb(1,0))g.fillRect((x+1)*TS-3,y*TS,3,TS);if(nb(-1,0))g.fillRect(x*TS,y*TS,3,TS);
    if(nb(0,1))g.fillRect(x*TS,(y+1)*TS-3,TS,3);if(nb(0,-1))g.fillRect(x*TS,y*TS,TS,3);
  }
  // faixas e faixas de pedestre
  g.fillStyle='rgba(214,170,70,.6)';
  for(let k=0;k<=NB;k++){
    const c=(k*P+1)*TS;
    for(let t=0;t<N;t++){if(t%P>=2){g.fillRect(c-1.5,t*TS+6,3,14);g.fillRect(t*TS+6,c-1.5,14,3);}}
  }
  g.fillStyle='rgba(210,215,230,.28)';
  for(let k=0;k<=NB;k++)for(let k2=0;k2<=NB;k2++){
    const rx=k*P*TS,ry=k2*P*TS;
    for(let s=0;s<6;s++){
      g.fillRect(rx+4+s*10,ry+2*TS+2,5,22);g.fillRect(rx+4+s*10,ry-TS+8,5,22);
      g.fillRect(rx+2*TS+2,ry+4+s*10,22,5);g.fillRect(rx-TS+8,ry+4+s*10,22,5);
    }
  }
  // cais de madeira e borda do porto
  for(const p of (M.piers||[])){for(let y=p.y0;y<=p.y1;y++)for(let x=p.x0;x<=p.x1;x++){g.fillStyle='#3e2e22';g.fillRect(x*TS,y*TS,TS,TS);for(let k=0;k<4;k++){g.fillStyle=k%2?'#4a3828':'#35271c';g.fillRect(x*TS,y*TS+k*8,TS,7);}sg.fillStyle='#222';sg.fillRect(x*TS/4,y*TS/4,TS/4,TS/4);}}
  for(let y=1;y<N;y++)for(let x=0;x<N;x++){if(M.tile[y*N+x]!==T_WATER&&M.tile[(y-1)*N+x]===T_WATER&&!(M.piers||[]).some(p=>x>=p.x0&&x<=p.x1&&y-1>=p.y0&&y-1<=p.y1)){for(let s=0;s<4;s++){g.fillStyle=s%2?'#d8b020':'#1a1a1a';g.fillRect(x*TS+s*8,y*TS,8,4);}}}
  if(M.paint)M.paint(g,TS);
  // poças (reflexo)
  for(let k=0;k<80;k++){
    const x=rng()*N,y=rng()*N;if(M.tile[(y|0)*N+(x|0)]!==T_ROAD&&M.tile[(y|0)*N+(x|0)]!==T_PLAZA)continue;
    const r=6+rng()*22;g.fillStyle='rgba(40,55,90,.35)';g.beginPath();g.ellipse(x*TS,y*TS,r,r*.6,rng()*3,0,TAU);g.fill();
    sg.fillStyle='#fff';sg.beginPath();sg.ellipse(x*TS/4,y*TS/4,r/4,r*.6/4,0,0,TAU);sg.fill();
  }
  // poças de luz fracas sob postes
  g.globalCompositeOperation='lighter';
  M.lamps.forEach(l=>{const gr=g.createRadialGradient(l.x*TS,l.y*TS,0,l.x*TS,l.y*TS,TS*3);gr.addColorStop(0,l.col+'2a');gr.addColorStop(1,l.col+'00');g.fillStyle=gr;g.fillRect(l.x*TS-TS*3,l.y*TS-TS*3,TS*6,TS*6);});
  g.globalCompositeOperation='source-over';
  groundTex=canvasTex(groundCan);groundTex.anisotropy=8;
  const specTex=new THREE.CanvasTexture(spec);
  const rc=document.createElement('canvas');rc.width=spec.width;rc.height=spec.height;const rg=rc.getContext('2d');rg.fillStyle='#fff';rg.fillRect(0,0,rc.width,rc.height);rg.globalCompositeOperation='difference';rg.drawImage(spec,0,0);
  const roughTex=new THREE.CanvasTexture(rc);
  const mat=new THREE.MeshStandardMaterial({map:groundTex,roughnessMap:roughTex,roughness:1,metalness:.15,envMapIntensity:1.4});
  const onPier=(x,y)=>(M.piers||[]).some(p=>x>=p.x0&&x<=p.x1&&y>=p.y0&&y<=p.y1);
  groundType=groundTypeTex(N,(x,y)=>{const t=M.tile[y*N+x];if(onPier(x,y))return LAYER.planks+1;
    return t===T_ROAD?LAYER.asphalt+1:t===T_WALK||t===T_FENCE||t===T_POST?LAYER.pavers+1:t===T_PLAZA||t===T_GLASS?LAYER.granite+1:t===T_GRASS||t===T_TREE?LAYER.grass+1:0;});
  pbrGround(mat,groundType,N);
  ground=new THREE.Mesh(new THREE.PlaneGeometry(N,N),mat);ground.rotation.x=-Math.PI/2;ground.position.set(N/2,0,N/2);ground.receiveShadow=true;
  world.add(ground);
  const under=new THREE.Mesh(new THREE.PlaneGeometry(N+80,N+80),lam('#07080d'));under.rotation.x=-Math.PI/2;under.position.set(N/2,-.02,N/2);world.add(under);
}
let decalT=0;
hooks.decal=(type,x,y,r)=>{
  if(!gctx)return;const g=gctx;
  if(type==='blood'){for(let k=0;k<6;k++){g.fillStyle=`rgba(${70+Math.random()*40},4,12,.6)`;g.beginPath();g.ellipse(x*TS+(Math.random()-.5)*20,y*TS+(Math.random()-.5)*20,3+Math.random()*9,2+Math.random()*6,Math.random()*3,0,TAU);g.fill();}}
  else if(type==='shards'){for(let k=0;k<14;k++){g.fillStyle=`rgba(${170+Math.random()*60},${220+Math.random()*30},255,.55)`;g.fillRect(x*TS+(Math.random()-.5)*TS*1.4,y*TS+(Math.random()-.5)*TS*1.4,1+Math.random()*3,1+Math.random()*2);}}
  else{const R=r*TS*.9,gr=g.createRadialGradient(x*TS,y*TS,0,x*TS,y*TS,R);gr.addColorStop(0,'rgba(0,0,0,.75)');gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.fillRect(x*TS-R,y*TS-R,R*2,R*2);}
  M.decalsDirty=true;
};
function uvScale(geo,w,d,fl,ou,ov){
  const uv=geo.attributes.uv;
  for(let f=0;f<6;f++){
    let su=1,sv=1;if(f<2){su=d/8;sv=fl/8;}else if(f>3){su=w/8;sv=fl/8;}else continue;
    for(let k=0;k<4;k++){const i=f*4+k;uv.setXY(i,uv.getX(i)*su+ou/8,uv.getY(i)*sv+ov/8);}
  }
  uv.needsUpdate=true;
}
const roofGeoAC=box(.55,.32,.45,0,.16,0,'#3a4152');roofGeoAC.userData.shared=true;
const roofGeoTank=cyl(.3,.3,.55,8,0,.28,0,'#4a3f36');roofGeoTank.userData.shared=true;
const roofGeoTankBlue=cyl(.3,.3,.5,8,0,.25,0,'#2a6ab0');roofGeoTankBlue.userData.shared=true;
function buildBuildings(){
  blinkMat=basic('#ff2030');
  const rng=RNG(M.di*313+11);
  for(const b of M.blds){
    if(b.style){buildSpecial(b);continue;}
    const H=b.fl*FLOOR+(b.kiosk?.2:0),mats=winMats(b.pal,b.v,!!b.corp);
    const geo=new THREE.BoxGeometry(b.w,H,b.d);uvScale(geo,b.w,b.d,b.kiosk?1:b.fl,b.ou,b.ov);
    const m=new THREE.Mesh(geo,mats.norm);m.position.set(b.x+b.w/2,H/2,b.y+b.d/2);m.castShadow=m.receiveShadow=true;
    m.userData={mats,fade:false};world.add(m);bldMeshes.push(m);b.r3=m;
    // parapeito
    const par=new THREE.Mesh(new THREE.BoxGeometry(b.w+.04,.12,b.d+.04),mats.norm[2]);par.receiveShadow=true;par.position.set(b.x+b.w/2,H+.02,b.y+b.d/2);world.add(par);m.userData.extra=[par];
    if(b.neon>=0){
      const col=NEON[b.neon];
      const band=new THREE.Mesh(new THREE.BoxGeometry(b.w+.05,.08,b.d+.05),basic(col));band.position.set(b.x+b.w/2,Math.max(.35,H-.32),b.y+b.d/2);world.add(band);m.userData.extra.push(band);
      if(!b.kiosk&&rng()<.6){const s=new THREE.Mesh(new THREE.BoxGeometry(b.w+.05,.05,b.d+.05),basic(col));s.position.set(b.x+b.w/2,.62,b.y+b.d/2);world.add(s);m.userData.extra.push(s);}
    }
    if(b.sign){
      const sw=Math.min(b.corp?4.5:2.2,b.w-.2),sh=sw/4;
      const sg=new THREE.Mesh(new THREE.PlaneGeometry(sw,sh),signMat(b.sign,b.signCol||'#ff3d8b'));
      const face=rng()<.5;const hy=b.corp?H-1:clamp(FLOOR*1.6+rng()*(H-1.5),FLOOR*1.4,H-.4);
      if(face||b.corp){sg.position.set(b.x+b.w/2,hy,b.y+b.d+.03);}
      else{const sw2=Math.min(2.2,b.d-.2);sg.scale.set(sw2/sw,1,1);sg.rotation.y=Math.PI/2;sg.position.set(b.x+b.w+.03,hy,b.y+b.d/2);}
      world.add(sg);m.userData.extra.push(sg);
    }
    if(!b.kiosk&&b.fl>=(b.favela?2:3)&&b.roof>0){
      if(props.ready&&b.roof===1){const r=propMesh(rng()<.5?'ac':'ac_stack');r.position.set(b.x+.5+rng()*(b.w-1),H+.08,b.y+.5+rng()*(b.d-1));r.rotation.y=((rng()*4)|0)*Math.PI/2;world.add(r);m.userData.extra.push(r);}
      else{const r=new THREE.Mesh(b.roof===1?roofGeoAC:b.favela?roofGeoTankBlue:roofGeoTank,vcMat);r.position.set(b.x+.4+rng()*(b.w-.8),H+.05,b.y+.4+rng()*(b.d-.8));r.castShadow=true;world.add(r);m.userData.extra.push(r);}
    }
    if(props.ready&&!b.kiosk&&b.fl>=4&&!b.ant&&rng()<.3){const d=propMesh('antenna_b');d.position.set(b.x+.4+rng()*(b.w-.8),H+.08,b.y+.4+rng()*(b.d-.8));d.rotation.y=rng()*6.28;world.add(d);m.userData.extra.push(d);}
    // aparelhos de ar-condicionado nas fachadas (instanciados no fim)
    if(props.ready&&!b.kiosk&&!b.corp&&b.fl>=2){
      const k=1+((rng()*3)|0);m.userData.acs=[];
      for(let q=0;q<k;q++){
        const face=(rng()*4)|0,len=face%2?b.d:b.w,t=((rng()*len)|0)+.5,f=(rng()*Math.min(b.fl,6))|0,y=f*FLOOR+.03;
        const P=face===0?[b.x+t,b.y+b.d]:face===1?[b.x+b.w,b.y+t]:face===2?[b.x+t,b.y]:[b.x,b.y+t];
        const ang=[-Math.PI/2,0,Math.PI/2,Math.PI][face];
        acList.push({m,ang,x:P[0],y,z:P[1]});
      }
    }
    if(b.ant&&props.ready){
      const a=propMesh('antenna_a');a.position.set(b.x+b.w-.4,H,b.y+.4);world.add(a);
      const l=new THREE.Mesh(new THREE.SphereGeometry(.06,6,4),blinkMat);l.position.set(b.x+b.w-.4,H+1.52,b.y+.4);world.add(l);m.userData.extra.push(a,l);
    }else
    if(b.ant){
      const a=new THREE.Mesh(new THREE.CylinderGeometry(.02,.03,1.4,4),lam('#333a48'));a.position.set(b.x+b.w-.4,H+.7,b.y+.4);world.add(a);
      const l=new THREE.Mesh(new THREE.SphereGeometry(.06,6,4),blinkMat);l.position.set(b.x+b.w-.4,H+1.42,b.y+.4);world.add(l);m.userData.extra.push(a,l);
    }
  }
}
function buildTrees(){treeRefs=null;
  if(!M.trees.length)return;
  if(props.ready){
    const kinds=['tree_a','tree_b','tree_c','tree_d'],lists={tree_a:[],tree_b:[],tree_c:[],tree_d:[]},where=[],o=new THREE.Object3D();
    M.trees.forEach(t=>{const h=Math.abs(Math.floor(t.r*7.3)),k=kinds[h%4];o.position.set(t.x,0,t.y);o.rotation.set(0,t.r,0);o.scale.setScalar(t.s*(.88+(h%5)*.06));o.updateMatrix();where.push([k,lists[k].length]);lists[k].push(o.matrix.clone());});
    const ims={};for(const k of kinds){ims[k]=propInstances(k,lists[k]);ims[k].forEach(m=>world.add(m));}
    treeRefs={glb:true,at:where.map(([k,i])=>({ims:ims[k],i}))};return;
  }
  const trunk=new THREE.InstancedMesh(new THREE.CylinderGeometry(.05,.08,.7,5),lam('#3a2a1e'),M.trees.length);
  const crown=new THREE.InstancedMesh(new THREE.IcosahedronGeometry(.48,0),new THREE.MeshLambertMaterial({color:'#24452f',flatShading:true}),M.trees.length);
  const o=new THREE.Object3D();
  M.trees.forEach((t,i)=>{
    o.position.set(t.x,.35,t.y);o.rotation.set(0,t.r,0);o.scale.set(1,t.s,1);o.updateMatrix();trunk.setMatrixAt(i,o.matrix);
    o.position.set(t.x,.7+.42*t.s,t.y);o.scale.set(t.s,t.s*1.15,t.s);o.updateMatrix();crown.setMatrixAt(i,o.matrix);
  });
  trunk.castShadow=crown.castShadow=true;crown.receiveShadow=true;world.add(trunk,crown);treeRefs={trunk,crown};
}
function buildLamps(){lampRefs=null;
  const n=M.lamps.length;if(!n)return;
  if(props.ready&&propDef('lamp_c')){
    const L=propDef('lamp_c').light||new THREE.Vector3(.4,2.25,0),o=new THREE.Object3D(),c=new THREE.Color(),mats=[];
    const head=new THREE.InstancedMesh(new THREE.BoxGeometry(.2,.05,.14),new THREE.MeshBasicMaterial({toneMapped:false}),n);
    M.lamps.forEach((l,i)=>{
      const s=l.tall?1.5:1;o.position.set(l.x,0,l.y);o.rotation.set(0,0,0);o.scale.setScalar(s);o.updateMatrix();mats.push(o.matrix.clone());
      o.position.set(l.x+L.x*s,L.y*s-.04,l.y+L.z*s);o.scale.set(l.tall?1.6:1,1,l.tall?1.6:1);o.updateMatrix();head.setMatrixAt(i,o.matrix);
      head.setColorAt(i,c.set(l.col).multiplyScalar(1.6));
    });
    const ims=propInstances('lamp_c',mats);ims.forEach(m=>world.add(m));world.add(head);
    lampRefs={glb:true,ims,head,mats};return;
  }
  const pole=new THREE.InstancedMesh(new THREE.CylinderGeometry(.03,.045,2.3,5),lam('#272c38'),n);
  const arm=new THREE.InstancedMesh(new THREE.BoxGeometry(.4,.04,.04),lam('#272c38'),n);
  const head=new THREE.InstancedMesh(new THREE.BoxGeometry(.24,.05,.12),new THREE.MeshBasicMaterial({toneMapped:false}),n);
  const o=new THREE.Object3D(),c=new THREE.Color();
  M.lamps.forEach((l,i)=>{
    const hs=l.tall?1.75:1;
    o.position.set(l.x,1.15*hs,l.y);o.rotation.set(0,0,0);o.scale.set(1,hs,1);o.updateMatrix();pole.setMatrixAt(i,o.matrix);o.scale.set(1,1,1);
    o.position.set(l.x+.18,2.28*hs,l.y);o.updateMatrix();arm.setMatrixAt(i,o.matrix);
    o.position.set(l.x+.34,2.24*hs,l.y);o.scale.set(l.tall?1.8:1,l.tall?1.5:1,l.tall?1.8:1);o.updateMatrix();head.setMatrixAt(i,o.matrix);o.scale.set(1,1,1);
    head.setColorAt(i,c.set(l.col).multiplyScalar(1.6));
  });
  pole.castShadow=true;world.add(pole,arm,head);lampRefs={pole,arm,head};
}
/* semáforos e placas nas esquinas e aparelhos de ar nas fachadas */
let acList=[];
function buildStreetProps(){
  if(!props.ready)return;
  if(acList.length&&propDef('ac_side')){
    const D=propDef('ac_side'),dep=(D.box.max.x-D.box.min.x)/2,o=new THREE.Object3D(),mats=acList.map(a=>{o.position.set(a.x+Math.cos(a.ang)*dep,a.y,a.z-Math.sin(a.ang)*dep);o.rotation.set(0,a.ang,0);o.scale.setScalar(1);o.updateMatrix();return o.matrix.clone();});
    const ims=propInstances('ac_side',mats);ims.forEach(im=>world.add(im));
    acList.forEach((a,i)=>a.m.userData.acs.push({ims,i,mtx:mats[i]}));
  }
  acList=[];
  const road=(x,y)=>x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_ROAD,near=(x,y)=>M.lamps.some(l=>Math.hypot(l.x-x,l.y-y)<.9)||M.trees.some(t=>Math.hypot(t.x-x,t.y-y)<.9)||M.terms.some(t=>Math.hypot(t.x-x,t.y-y)<1);
  const rng=RNG(M.di*97+31),lists={traffic:[],sign_stop:[],sign_warn:[]},o=new THREE.Object3D();
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){
    if(M.tile[y*N+x]!==T_WALK&&M.tile[y*N+x]!==T_PLAZA)continue;
    for(const [dx,dy] of [[1,1],[1,-1],[-1,1],[-1,-1]]){
      if(!road(x+dx,y)||!road(x,y+dy)||!road(x+dx,y+dy))continue;
      const px=x+.5+dx*.32,py=y+.5+dy*.32;if(near(px,py)||rng()<.3)continue;
      const k=rng()<.72?'traffic':rng()<.5?'sign_stop':'sign_warn';
      o.position.set(px,0,py);o.rotation.set(0,Math.atan2(-dy,dx)+(k==='traffic'?0:Math.PI/2),0);o.scale.setScalar(1);o.updateMatrix();lists[k].push(o.matrix.clone());
    }
  }
  for(const k in lists)propInstances(k,lists[k]).forEach(im=>world.add(im));
}
const ZERO=new THREE.Matrix4().makeScale(0,0,0);
function buildObjectives(){
  for(const t of M.terms){
    const g=new THREE.Group();
    const b=new THREE.Mesh(new THREE.BoxGeometry(.4,.95,.3),lam('#2a3040'));b.position.y=.475;b.castShadow=true;
    const scr=new THREE.Mesh(new THREE.PlaneGeometry(.3,.22),new THREE.MeshBasicMaterial({color:'#4fd8ff',toneMapped:false}));scr.position.set(0,.72,.16);
    const scr2=scr.clone();scr2.material=scr.material;scr2.rotation.y=Math.PI/2;scr2.position.set(.21,.72,0);
    g.add(b,scr,scr2);g.position.set(t.x,0,t.y);world.add(g);termObjs.push({t,g,scr:scr.material});
  }
  for(const p of M.props){
    const g=new THREE.Group();
    if(props.ready&&propDef('barrel')){
      const b=propMesh('barrel','#e05038');
      const s=new THREE.Mesh(new THREE.CylinderGeometry(.182,.182,.06,14),basic('#ffb13d'));s.position.y=.33;
      g.add(b,s);g.position.set(p.x,0,p.y);world.add(g);propObjs.push({p,g});continue;
    }
    const b=new THREE.Mesh(new THREE.CylinderGeometry(.17,.17,.48,10),lam('#9a2a1e'));b.position.y=.24;b.castShadow=true;
    const s=new THREE.Mesh(new THREE.CylinderGeometry(.175,.175,.08,10),basic('#ffb13d'));s.position.y=.3;
    g.add(b,s);g.position.set(p.x,0,p.y);world.add(g);propObjs.push({p,g});
  }
  const ringMat=c=>new THREE.MeshBasicMaterial({color:c,transparent:true,opacity:.7,toneMapped:false,side:THREE.DoubleSide,depthWrite:false});
  evacRing=(M.evacs||(M.evac?[M.evac]:[])).map(e=>{const r=new THREE.Mesh(new THREE.RingGeometry(1.9,2.15,48),ringMat('#5dffa0'));r.rotation.x=-Math.PI/2;r.position.set(e.x,.03,e.y);world.add(r);return r;});
  if(M.escape){escRing=new THREE.Mesh(new THREE.RingGeometry(1.2,1.4,40),ringMat('#ff4d5e'));escRing.rotation.x=-Math.PI/2;escRing.position.set(M.escape.x,.03,M.escape.y);escRing.visible=false;world.add(escRing);}else escRing=null;
}


/* ---------- porto: água, cais, cerca, contêineres, guindastes, barco ---------- */
let waterMesh=null,decorObjs=[],fallMeshes=[];
const CONT_COLS=['#8a2e22','#1f4e7a','#2f6b3e','#b8681e','#6b6f78','#7a1f3a'];
const corrCache=new Map();
function corrMat(col){
  let m=corrCache.get(col);if(m)return m;
  const c=document.createElement('canvas');c.width=64;c.height=64;const g=c.getContext('2d');
  g.fillStyle=col;g.fillRect(0,0,64,64);
  for(let x=0;x<64;x+=6){g.fillStyle='rgba(0,0,0,.22)';g.fillRect(x,0,2,64);g.fillStyle='rgba(255,255,255,.07)';g.fillRect(x+3,0,1,64);}
  g.fillStyle='rgba(0,0,0,.3)';g.fillRect(0,0,64,3);g.fillRect(0,61,64,3);
  const t=canvasTex(c,true);t.wrapS=t.wrapT=THREE.RepeatWrapping;
  m=new THREE.MeshLambertMaterial({map:t});m.userData.shared=true;corrCache.set(col,m);return m;
}
function scaleUV(geo,w,h,d){
  const uv=geo.attributes.uv;
  for(let f=0;f<6;f++){const su=f<2?d:f<4?w:w,sv=f<2||f>3?h:d;for(let k=0;k<4;k++){const i=f*4+k;uv.setXY(i,uv.getX(i)*su*1.5,uv.getY(i)*sv*1.2);}}
  uv.needsUpdate=true;
}
function buildSpecial(b){
  if(b.style==='hedge')return;
  if(b.style==='wall'){
    const H=1.6,m=new THREE.Mesh(new THREE.BoxGeometry(b.w,H,b.d),lam('#8a8478'));m.position.set(b.x+b.w/2,H/2,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);
    const cap=new THREE.Mesh(new THREE.BoxGeometry(b.w+.1,.1,b.d+.1),lam('#c8c0b0'));cap.position.set(b.x+b.w/2,H+.05,b.y+b.d/2);world.add(cap);
    b.parts=[m,cap];return;
  }
  if(b.style==='cont'){
    const col=CONT_COLS[b.col%CONT_COLS.length],H=b.fl*.52;
    for(let k=0;k<b.fl;k++){
      const c=k===0?col:CONT_COLS[(b.col+k*2)%CONT_COLS.length];
      const geo=new THREE.BoxGeometry(b.w-.08,.5,b.d-.08);scaleUV(geo,b.w,.5,b.d);
      const m=new THREE.Mesh(geo,corrMat(c));m.position.set(b.x+b.w/2,.25+k*.52,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);(b.parts||(b.parts=[])).push(m);
    }
    return;
  }
  if(b.style==='ware'){
    const H=b.fl*FLOOR,geo=new THREE.BoxGeometry(b.w,H,b.d);scaleUV(geo,b.w,H,b.d);
    const wall=corrMat('#4a5058'),roof=lam('#2c3036');
    const m=new THREE.Mesh(geo,[wall,wall,roof,roof,wall,wall]);m.position.set(b.x+b.w/2,H/2,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);
    m.userData={mats:{norm:m.material,fade:[wall,wall,roof,roof,wall,wall].map(x=>{const f=x.clone();f.transparent=true;f.opacity=.13;f.depthWrite=false;return f;})},fade:false,extra:[]};
    bldMeshes.push(m);b.r3=m;
    const door=new THREE.Mesh(new THREE.PlaneGeometry(b.w*.35,1.1),lam('#0d0f13'));door.position.set(b.x+b.w/2,.55,b.y+b.d+.02);world.add(door);
    const strip=new THREE.Mesh(new THREE.BoxGeometry(b.w*.4,.06,.06),basic('#ffb13d'));strip.position.set(b.x+b.w/2,1.2,b.y+b.d+.04);world.add(strip);
    m.userData.extra.push(door,strip);
    if(b.sign){const sg=new THREE.Mesh(new THREE.PlaneGeometry(2.4,.6),signMat(b.sign,b.signCol));sg.position.set(b.x+b.w/2,H-.4,b.y+b.d+.03);world.add(sg);m.userData.extra.push(sg);}
  }
}
function buildWater(){
  const geos=[];
  for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(M.tile[y*N+x]===T_WATER)geos.push(new THREE.PlaneGeometry(1,1).rotateX(-Math.PI/2).translate(x+.5,.02,y+.5));
  if(!geos.length){waterMesh=null;return;}
  const geo=mergeGeometries(geos);
  const uv=geo.attributes.uv,pos=geo.attributes.position;for(let i=0;i<uv.count;i++)uv.setXY(i,pos.getX(i)/7,pos.getZ(i)/7);
  /* superfície refletiva com ondulação procedural (mapa de relevo que se repete sem emenda) */
  const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d'),img=g.createImageData(256,256),T=Math.PI*2/256;
  for(let y=0;y<256;y++)for(let x=0;x<256;x++){
    const v=128+34*Math.sin(T*(3*x+2*y))+26*Math.sin(T*(-5*x+7*y)+1.3)+18*Math.sin(T*(11*x+4*y)+2.1)+10*Math.sin(T*(-9*x-13*y)+.7);
    const i=(y*256+x)*4;img.data[i]=img.data[i+1]=img.data[i+2]=v;img.data[i+3]=255;}
  g.putImageData(img,0,0);
  const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;
  waterMesh=new THREE.Mesh(geo,new THREE.MeshStandardMaterial({color:'#06111f',roughness:.14,metalness:.8,bumpMap:t,bumpScale:1.6,envMapIntensity:1.8}));
  waterMesh.receiveShadow=true;
  world.add(waterMesh);
  for(const p of M.piers){
    const w=p.x1-p.x0+1,d=p.y1-p.y0+1;
    for(let k=0;k<4;k++){const post=new THREE.Mesh(new THREE.CylinderGeometry(.09,.09,.7,6),lam('#2a1e16'));post.position.set(k<2?p.x0+.1:p.x1+.9,-.2,p.y0+.2+(k%2)*(d-.4));world.add(post);}
    const edge=new THREE.Mesh(new THREE.BoxGeometry(w,.08,d),lam('#3c2c20'));edge.position.set(p.x0+w/2,-.03,p.y0+d/2);world.add(edge);
  }
}
const chainTex=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');g.strokeStyle='rgba(170,180,195,.9)';g.lineWidth=1.4;for(let i=-64;i<128;i+=8){g.beginPath();g.moveTo(i,0);g.lineTo(i+64,64);g.stroke();g.beginPath();g.moveTo(i+64,0);g.lineTo(i,64);g.stroke();}g.fillStyle='rgba(170,180,195,1)';g.fillRect(0,0,64,3);const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(1,1);return t;})();
function buildFence(){fenceRefs=null;
  const tiles=[];for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(M.tile[y*N+x]===T_FENCE)tiles.push([x,y]);
  if(!tiles.length)return;
  const panel=new THREE.InstancedMesh(new THREE.PlaneGeometry(1,1.1),new THREE.MeshLambertMaterial({map:chainTex,transparent:true,alphaTest:.25,side:THREE.DoubleSide}),tiles.length);
  const post=new THREE.InstancedMesh(new THREE.CylinderGeometry(.035,.035,1.2,5),lam('#5a6070'),tiles.length);
  const o=new THREE.Object3D(),isF=(x,y)=>x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_FENCE;
  tiles.forEach(([x,y],i)=>{
    const alongX=isF(x-1,y)||isF(x+1,y);
    o.position.set(x+.5,.55,y+.5);o.rotation.set(0,alongX?0:Math.PI/2,0);o.updateMatrix();panel.setMatrixAt(i,o.matrix);
    o.position.set(x,.6,y+.5);o.rotation.set(0,0,0);o.updateMatrix();post.setMatrixAt(i,o.matrix);
  });
  fenceRefs={panel,post,idx:new Map(tiles.map(([x,y],i)=>[y*N+x,i]))};
  world.add(panel,post);
}
function boxM(w,h,d,x,y,z,mat){const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat);m.position.set(x,y,z);m.castShadow=true;return m;}
function buildDecor(){
  decorObjs=[];fallMeshes=[];
  for(const d of M.decor||[]){
    const g=new THREE.Group();world.add(g);const o={d,g};
    if(d.type==='crane'){
      const H=7.2,mat=lam(d.col),dark=lam('#22252c'),cx=(d.x0+d.x1+1)/2;
      for(const [x,y] of [[d.x0,d.y0],[d.x1,d.y0],[d.x0,d.y1],[d.x1,d.y1]])g.add(boxM(.32,H,.32,x+.5,H/2,y+.5,mat));
      g.add(boxM(d.x1-d.x0+1,.35,.35,cx,H,d.y0+.5,mat),boxM(d.x1-d.x0+1,.35,.35,cx,H,d.y1+.5,mat));
      g.add(boxM(.3,.3,d.y1-d.y0,d.x0+.5,1.2,(d.y0+d.y1+1)/2,mat),boxM(.3,.3,d.y1-d.y0,d.x1+.5,1.2,(d.y0+d.y1+1)/2,mat));
      const armLen=d.y1-d.y0+12,armZ=d.y1+1-armLen/2+1.5;
      g.add(boxM(.6,.5,armLen,cx,H+.55,armZ,mat));
      g.add(boxM(1.4,.9,1.2,cx,H+.6,d.y1+2.2,dark));
      const cab=boxM(.9,.7,.8,cx+.9,H-.4,d.y1+.3,lam('#2a3040'));g.add(cab);
      const win=new THREE.Mesh(new THREE.PlaneGeometry(.7,.35),basic('#9fe8ff'));win.position.set(cx+.9,H-.35,d.y1+.71);g.add(win);
      const lamp=new THREE.Mesh(new THREE.SphereGeometry(.08,6,4),blinkMat);lamp.position.set(cx,H+.9,armZ-armLen/2);g.add(lamp);
      const hy=4.6;
      const cable=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,H+.3-hy,4),dark);cable.position.set(d.hang.x,(H+.3+hy)/2+.25,d.hang.y);g.add(cable);
      const trol=boxM(.7,.25,.7,d.hang.x,H+.25,d.hang.y,dark);g.add(trol);
      const hang=new THREE.Mesh(new THREE.BoxGeometry(2.8,.5,.95),corrMat('#8a2e22'));hang.position.set(d.hang.x,hy,d.hang.y);hang.castShadow=true;g.add(hang);
      o.cable=cable;o.hang=hang;o.hy=hy;
    }else if(d.type==='boat'){
      const hull=new THREE.Mesh(mergeGeometries([box(.9,.45,2.6,0,.1,0,'#e6e8ec'),box(.92,.12,2.62,0,.32,0,'#1d4f8a'),box(.7,.45,1,0,.55,-.2,'#f2f2f2'),box(.72,.18,.5,0,.62,.4,'#1a2433')]),vcMat);
      hull.castShadow=true;g.add(hull);g.position.set(d.x,0,d.y);
      const nav=new THREE.Mesh(new THREE.SphereGeometry(.05,6,4),basic('#5dffa0'));nav.position.set(.4,.6,-1.2);g.add(nav);
      o.bob=true;
    }else if(d.type==='barrier'){
      g.add(boxM(.25,1,.25,d.x,.5,d.y,lam('#3a404e')));
      const arm=new THREE.Group();arm.position.set(d.x,.9,d.y);
      const bar=new THREE.Mesh(mergeGeometries([box(2.3,.08,.08,-1.15,0,0,'#e8e8e8'),box(.4,.085,.085,-.4,0,0,'#d02030'),box(.4,.085,.085,-1.2,0,0,'#d02030'),box(.4,.085,.085,-2,0,0,'#d02030')]),vcMat);
      arm.add(bar);g.add(arm);o.arm=arm;
    }else if(d.type==='generator'){
      g.add(boxM(.9,.75,.6,d.x,.38,d.y,lam('#5a5a40')),boxM(.12,.5,.12,d.x+.3,1,d.y,lam('#2a2a2a')));
      const led=new THREE.Mesh(new THREE.BoxGeometry(.1,.06,.02),basic('#5dffa0'));led.position.set(d.x-.2,.6,d.y+.31);g.add(led);o.led=led;
    }else if(d.type==='laundry'){
      const L=Math.hypot(d.x2-d.x1,d.y2-d.y1),a=Math.atan2(d.y2-d.y1,d.x2-d.x1);
      const line=new THREE.Mesh(new THREE.CylinderGeometry(.01,.01,L,3).rotateZ(Math.PI/2),lam('#202020'));line.position.set((d.x1+d.x2)/2,d.h,(d.y1+d.y2)/2);line.rotation.y=-a;g.add(line);
      const n=Math.max(2,Math.floor(L*1.6));
      for(let k=0;k<n;k++){const t=(k+.5)/n,cl=new THREE.Mesh(new THREE.PlaneGeometry(.26,.34),new THREE.MeshLambertMaterial({color:pick(['#e8e4dc','#c23a5a','#2a7a9a','#d0a040','#5a3a8a','#2e8a6a','#f0f0f0'],Math.random),side:THREE.DoubleSide}));cl.position.set(d.x1+(d.x2-d.x1)*t,d.h-.19,d.y1+(d.y2-d.y1)*t);cl.rotation.y=-a;g.add(cl);}
    }else if(d.type==='cable'){
      const steel=lam('#3a404e');
      g.add(boxM(.45,5.8,.45,d.x,2.9,d.y,steel),boxM(3,.15,2.4,d.x-.6,3.2,d.y,lam('#2a3040')));
      for(const [x,z] of [[-1.9,-1],[-1.9,1],[.7,-1],[.7,1]])g.add(boxM(.12,3.2,.12,d.x+x,1.6,d.y+z,steel));
      const cab=new THREE.Mesh(mergeGeometries([box(1.1,.8,.8,0,0,0,'#c8301e'),box(.9,.3,.82,0,.12,0,'#1a2433'),box(.06,.6,.06,0,.7,0,'#2a2a2a')]),vcMat);cab.position.set(d.x+3.2,4.6,d.y);cab.castShadow=true;g.add(cab);
      const c1=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,26,3).rotateZ(Math.PI/2),lam('#151515'));c1.position.set(d.x+13,5.6,d.y);g.add(c1);
      o.cab=cab;
    }else if(d.type==='van'){
      const body=new THREE.Mesh(mergeGeometries([box(1.9,.85,.9,0,.55,0,'#22262e'),box(1.92,.12,.92,0,.12,0,'#111318'),box(.5,.4,.8,.72,.7,0,'#1a2433'),box(1.2,.05,.02,-.2,.6,.46,'#4fd8ff')]),vcMat);
      body.castShadow=true;g.add(body);g.position.set(d.x,0,d.y);g.rotation.y=-(d.ang||0);
    }else if(d.type==='airship'){
      const L=d.len||14,ship=new THREE.Group();
      const env=new THREE.Mesh(new THREE.SphereGeometry(1,24,14),lam('#b8bcc4'));env.scale.set(L/2,2.3,2.3);env.castShadow=true;ship.add(env);
      const band=new THREE.Mesh(new THREE.CylinderGeometry(2.33,2.33,.25,24,1,true).rotateZ(Math.PI/2),lam('#c8301e'));band.position.x=L*.18;ship.add(band);
      const gon=new THREE.Mesh(mergeGeometries([box(4,.9,1.2,0,0,0,'#2a2f3a'),box(3.6,.3,1.22,0,.1,0,'#ffe6b0')]),vcMat);gon.position.y=-2.6;gon.castShadow=true;ship.add(gon);
      for(const s of [1,-1]){const f=new THREE.Mesh(new THREE.BoxGeometry(2,.08,1.6),lam('#8a8e98'));f.position.set(-L*.42,0,s*1.6);ship.add(f);}
      const fv=new THREE.Mesh(new THREE.BoxGeometry(2,1.6,.08),lam('#8a8e98'));fv.position.set(-L*.42,1.6,0);ship.add(fv);
      const sg=new THREE.Mesh(new THREE.PlaneGeometry(5,1.1),signMat(d.text||'HÉLICE',d.col||'#ff3d5a'));sg.position.set(L*.05,.4,2.32);ship.add(sg);
      const nav=new THREE.Mesh(new THREE.SphereGeometry(.12,6,4),blinkMat);nav.position.set(L/2,0,0);ship.add(nav);
      ship.position.set(d.x,d.h||6.5,d.y);g.add(ship);o.ship=ship;o.lift=0;o.base=d.h||6.5;
      if(d.mx!==undefined){g.add(boxM(.4,d.h||6.5,.4,d.mx,(d.h||6.5)/2,d.my,lam('#3a404e')));const ln=new THREE.Mesh(new THREE.CylinderGeometry(.02,.02,Math.hypot(d.mx-d.x-L/2,d.my-d.y),3).rotateZ(Math.PI/2),lam('#151515'));ln.position.set((d.mx+d.x+L/2)/2,(d.h||6.5),(d.my+d.y)/2);ln.rotation.y=-Math.atan2(d.my-d.y,d.mx-d.x-L/2);g.add(ln);o.line=ln;}
    }else if(d.type==='blastdoor'){
      const m=new THREE.Mesh(mergeGeometries([box(d.w||1,1.6,.3,0,.8,0,'#5a5f6a'),box((d.w||1)*.9,.12,.32,0,1.1,0,'#ffb13d'),box((d.w||1)*.9,.12,.32,0,.5,0,'#ffb13d')]),vcMat);m.castShadow=true;m.position.set(d.x,0,d.y);g.add(m);o.bdoor=m;m.visible=false;
    }else if(d.type==='pipe'){
      const L=Math.hypot(d.x2-d.x1,d.y2-d.y1),a=Math.atan2(d.y2-d.y1,d.x2-d.x1),R=d.r||.18,H=d.h||2.2;
      const p=new THREE.Mesh(new THREE.CylinderGeometry(R,R,L,8).rotateZ(Math.PI/2),lam(d.col||'#6a5a48'));p.position.set((d.x1+d.x2)/2,H,(d.y1+d.y2)/2);p.rotation.y=-a;p.castShadow=true;g.add(p);
      const n=Math.max(1,Math.round(L/4));for(let k=0;k<=n;k++){const t=k/n;g.add(boxM(.12,H,.12,d.x1+(d.x2-d.x1)*t,H/2,d.y1+(d.y2-d.y1)*t,lam('#2a2f3a')));}
    }else if(d.type==='chimney'){
      const H=d.h||7,m=new THREE.Mesh(mergeGeometries([cyl(.45,.6,H,10,0,H/2,0,'#5a4a42'),cyl(.47,.47,.35,10,0,H*.8,0,'#c8301e'),cyl(.47,.47,.35,10,0,H*.6,0,'#e8e4dc'),cyl(.5,.5,.2,10,0,H,0,'#2a2a2a')]),vcMat);m.castShadow=true;g.add(m);
      const l=new THREE.Mesh(new THREE.SphereGeometry(.07,6,4),blinkMat);l.position.set(0,H+.15,0);g.add(l);g.position.set(d.x,0,d.y);
    }else if(d.type==='reactor'){
      const R=d.r||1.3,body=new THREE.Mesh(mergeGeometries([cyl(R,R*1.05,2.4,16,0,1.2,0,'#4a505c'),cyl(R*1.08,R*1.08,.25,16,0,.4,0,'#2a2f3a'),cyl(R*1.08,R*1.08,.25,16,0,2.1,0,'#2a2f3a'),cyl(R*.6,R*.8,.6,12,0,2.7,0,'#3a404e')]),vcMat);body.castShadow=true;g.add(body);
      const core=new THREE.Mesh(new THREE.CylinderGeometry(R*1.01,R*1.01,.18,16,1,true),new THREE.MeshBasicMaterial({color:'#38e8ff',toneMapped:false}));core.position.y=1.3;g.add(core);
      const pl=new THREE.PointLight('#38e8ff',3,6,1.6);pl.position.y=1.6;g.add(pl);
      g.position.set(d.x,0,d.y);o.core=core;o.light=pl;
    }else if(d.type==='heli'){
      const body=new THREE.Mesh(mergeGeometries([box(1.5,.7,.8,0,.6,0,'#d8dce4'),box(.6,.45,.7,.85,.55,0,'#1a2433'),box(1.6,.18,.18,-1.4,.75,0,'#d8dce4'),box(.08,.5,.3,-2.15,.95,0,'#c8301e'),box(1.4,.06,.06,0,.15,.4,'#2a2a2a'),box(1.4,.06,.06,0,.15,-.4,'#2a2a2a')]),vcMat);body.castShadow=true;
      const rotor=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(3.6,.03,.14),new THREE.BoxGeometry(.14,.03,3.6)]),lam('#15181f'));rotor.position.y=1.05;
      const hg=new THREE.Group();hg.add(body,rotor);g.add(hg);g.position.set(d.x,0,d.y);g.rotation.y=-(d.ang||0);o.heli=hg;o.rotor=rotor;o.lift=0;if(d.alt!==undefined)hg.position.y=d.alt;
    }else if(d.type==='fountain'){
      const st=lam('#c8ccd4');
      g.add(new THREE.Mesh(mergeGeometries([cyl(.2,.3,1,10,d.x,.5,d.y,'#c8ccd4'),cyl(.6,.5,.12,12,d.x,1,d.y,'#c8ccd4')]),vcMat));
      const w=d.x1-d.x0+1,h=d.y1-d.y0+1,cx=(d.x0+d.x1+1)/2,cy=(d.y0+d.y1+1)/2;
      g.add(boxM(w+.3,.3,.15,cx,.15,d.y0-.05,st),boxM(w+.3,.3,.15,cx,.15,d.y1+1.05,st),boxM(.15,.3,h,d.x0-.05,.15,cy,st),boxM(.15,.3,h,d.x1+1.05,.15,cy,st));
    }
    decorObjs.push(o);
  }
}
function syncDecor(dt){
  if(waterMesh){const t=waterMesh.material.bumpMap;t.offset.x+=dt*.012;t.offset.y+=dt*.005;}
  for(const o of decorObjs){
    if(o.bob){o.g.position.y=Math.sin(M.t*1.3)*.05-.05;o.g.rotation.z=Math.sin(M.t*.9)*.03;}
    if(o.arm){const tgt=M.flags&&M.flags.gate?1.35:0;o.arm.rotation.z+=(tgt-o.arm.rotation.z)*Math.min(1,dt*3);}
    if(o.hang){o.hang.visible=o.cable.visible=!(M.flags&&M.flags.dropped);if(o.hang.visible)o.hang.rotation.y=Math.sin(M.t*.7)*.04;}
    if(o.core){if(o.d.dead){if(!o.wreck){o.wreck=true;o.g.scale.y=.3;o.core.visible=false;o.light.intensity=0;}}else{const a=o.d.armed,col=a?(Math.sin(M.t*(M.timer?14:5))>0?'#ff3040':'#400408'):'#38e8ff';o.core.material.color.set(col);o.light.color.set(a?'#ff3040':'#38e8ff');}}
    if(o.bdoor)o.bdoor.visible=!!M.flags[o.d.flag];
    if(o.heli&&o.d.alt!==undefined){o.g.visible=o.d.vis!==false;if(!M.flags.heliGo)o.heli.position.y+=(o.d.alt-o.heli.position.y)*Math.min(1,dt*.7);}
    if(o.ship){o.ship.position.y=o.base+Math.sin(M.t*.5)*.15;o.ship.rotation.x=Math.sin(M.t*.4)*.02;if(M.flags.airshipGo){o.lift+=dt;o.ship.position.y+=o.lift*o.lift*.35;o.ship.position.x=o.d.x+o.lift*o.lift*.9;if(o.line)o.line.visible=false;}}
    if(o.heli){const busy=M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead)||(o.d.alt!==undefined&&o.d.vis!==false);o.rotor.rotation.y+=dt*(M.flags.heliGo?40:busy?28:2.5);if(M.flags.heliGo){o.lift+=dt;o.heli.position.y=Math.min(16,o.lift*o.lift*1.4);o.heli.position.x=o.lift*o.lift*.7;}}
  }
  if(M.falling)M.falling.forEach((f,i)=>{
    let m=fallMeshes[i];
    if(!m){m=new THREE.Mesh(new THREE.BoxGeometry(2.8,.5,.95),corrMat('#8a2e22'));m.castShadow=true;world.add(m);fallMeshes[i]=m;}
    const k=Math.min(1,f.t/f.T),y=4.6-(4.6-.25)*k*k;m.position.set(f.x,y,f.y);m.rotation.z=f.landed?.05:k*.08;
  });
  if(M.convoy&&M.convoy[0]&&!M.flags.gate&&M.convoy.some(c=>!c.dead&&c.y<36.5))M.flags.gate=true;
  if(M.flags&&!M.flags.gate&&M.cars.some(c=>c.scripted&&!c.dead&&c.y<36.5))M.flags.gate=true;
}


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
  }else if(type==='glasswall'&&glassRefs){
    const i=glassRefs.idx.get(o.y*N+o.x);if(i===undefined)return;
    o3.position.set(0,-50,0);o3.rotation.set(0,0,0);o3.scale.set(0,0,0);o3.updateMatrix();glassRefs.pane.setMatrixAt(i,o3.matrix);glassRefs.pane.instanceMatrix.needsUpdate=true;
    o3.position.set(o.x+.5,.05,o.y+.5);o3.rotation.set(0,Math.random()*3,0);o3.scale.set(1,1,1);o3.updateMatrix();glassRefs.frame.setMatrixAt(i,o3.matrix);glassRefs.frame.instanceMatrix.needsUpdate=true;
  }else if(type==='lamp'&&lampRefs&&lampRefs.glb){
    const i=M.lamps.indexOf(o);if(i<0)return;const s=o.tall?1.5:1;
    o3.position.set(o.x+.08,.06,o.y);o3.rotation.set(0,0,-1.45);o3.scale.setScalar(s);o3.updateMatrix();
    for(const im of lampRefs.ims){im.setMatrixAt(i,o3.matrix);im.instanceMatrix.needsUpdate=true;}
    lampRefs.head.setMatrixAt(i,ZERO);lampRefs.head.instanceMatrix.needsUpdate=true;lampT=0;
  }else if(type==='tree'&&treeRefs&&treeRefs.glb){
    const a=treeRefs.at[M.trees.indexOf(o)];if(!a)return;
    for(const im of a.ims){im.setMatrixAt(a.i,ZERO);im.instanceMatrix.needsUpdate=true;}
  }else if(type==='lamp'&&lampRefs){
    const i=M.lamps.indexOf(o);if(i<0)return;const hs=o.tall?1.75:1;
    o3.position.set(o.x+.25,1.05*hs*.9,o.y);o3.rotation.set(.35,0,-.45);o3.scale.set(1,hs,1);o3.updateMatrix();lampRefs.pole.setMatrixAt(i,o3.matrix);lampRefs.pole.instanceMatrix.needsUpdate=true;
    o3.scale.set(0,0,0);o3.updateMatrix();lampRefs.arm.setMatrixAt(i,o3.matrix);lampRefs.head.setMatrixAt(i,o3.matrix);lampRefs.arm.instanceMatrix.needsUpdate=true;lampRefs.head.instanceMatrix.needsUpdate=true;
    lampT=0;
  }else if(type==='lampoff'&&lampRefs){
    const i=M.lamps.indexOf(o);if(i<0)return;lampRefs.head.setColorAt(i,c3.set('#050505'));lampRefs.head.instanceColor.needsUpdate=true;lampT=0;
  }else if(type==='tree'&&treeRefs){
    const i=M.trees.indexOf(o);if(i<0)return;
    o3.position.set(o.x,.12,o.y);o3.rotation.set(0,0,0);o3.scale.set(1.3,.3,1.3);o3.updateMatrix();treeRefs.trunk.setMatrixAt(i,o3.matrix);treeRefs.trunk.instanceMatrix.needsUpdate=true;
    o3.scale.set(0,0,0);o3.updateMatrix();treeRefs.crown.setMatrixAt(i,o3.matrix);treeRefs.crown.instanceMatrix.needsUpdate=true;
  }
};


/* ---------- efeitos rápidos: clarão do cano, bola de fogo, ondas no chão ---------- */
const flareTex=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');const gr=g.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,'rgba(255,255,255,1)');gr.addColorStop(.25,'rgba(255,255,255,.7)');gr.addColorStop(1,'rgba(255,255,255,0)');g.fillStyle=gr;g.fillRect(0,0,64,64);g.globalCompositeOperation='lighter';g.strokeStyle='rgba(255,255,255,.6)';g.lineWidth=3;for(let k=0;k<4;k++){const a=k*Math.PI/4;g.beginPath();g.moveTo(32-Math.cos(a)*30,32-Math.sin(a)*30);g.lineTo(32+Math.cos(a)*30,32+Math.sin(a)*30);g.stroke();}return new THREE.CanvasTexture(c);})();
let vfxRings=[],vfxSprites=[];
function vfxRing(i){let m=vfxRings[i];if(!m){m=new THREE.Mesh(new THREE.RingGeometry(.86,1,40).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));world.add(m);vfxRings[i]=m;}return m;}
function vfxSprite(i){let s=vfxSprites[i];if(!s){s=new THREE.Sprite(new THREE.SpriteMaterial({map:flareTex,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));world.add(s);vfxSprites[i]=s;}return s;}
function syncVfx(){
  let ri=0,si=0;
  for(const v of (M.vfx||[])){
    const a=Math.max(0,v.life/v.max),t=1-a;
    if(v.k==='ring'){const m=vfxRing(ri++);m.visible=true;m.position.set(v.x,.05,v.y);m.scale.setScalar(.2+v.size*(1-Math.pow(a,2)));m.material.color.set(v.col);m.material.opacity=a*.9;}
    else{const s=vfxSprite(si++);s.visible=true;s.position.set(v.x,v.z||.6,v.y);const sc=v.k==='ball'?v.size*(.5+t*1.1):v.size*(.8+Math.random()*.4);s.scale.set(sc,sc,1);s.material.color.set(v.col);s.material.opacity=v.k==='ball'?a:1;s.material.rotation=Math.random()*TAU;}
  }
  for(;ri<vfxRings.length;ri++)vfxRings[ri].visible=false;
  for(;si<vfxSprites.length;si++)vfxSprites[si].visible=false;
}


/* ---------- câmeras, monotrilho, pista de dança e outdoors ---------- */
let ventObjs=[],glassRefs=null;
const grateTex=(()=>{const c=document.createElement('canvas');c.width=c.height=32;const g=c.getContext('2d');g.fillStyle='#1a1c22';g.fillRect(0,0,32,32);g.fillStyle='#c8ccd4';for(let i=3;i<32;i+=5)g.fillRect(2,i,28,2);g.strokeStyle='#c8ccd4';g.lineWidth=2;g.strokeRect(1,1,30,30);const t=new THREE.CanvasTexture(c);t.magFilter=THREE.NearestFilter;return t;})();
function buildGlassVents(){
  ventObjs=[];glassRefs=null;
  for(const l of M.lasers||[]){
    const dx=l.x2-l.x1,dy=l.y2-l.y1,L=Math.hypot(dx,dy),a=-Math.atan2(dy,dx);
    const mat=new THREE.MeshBasicMaterial({color:'#ff2030',transparent:true,opacity:.85,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false});
    const g=new THREE.Group();g.position.set((l.x1+l.x2)/2,0,(l.y1+l.y2)/2);g.rotation.y=a;world.add(g);
    const beams=[.35,.75].map(h=>{const m=new THREE.Mesh(new THREE.BoxGeometry(L,.025,.025),mat);m.position.y=h;g.add(m);return m;});
    for(const s of [-1,1])g.add(boxM(.1,.95,.1,s*L/2,.475,0,lam('#2a2f3a')));
    ventObjs.push({l,g,beams,mat});
  }
  for(const v of M.vents||[]){
    const m=new THREE.Mesh(new THREE.PlaneGeometry(.9,.9).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({map:grateTex,color:'#55606e',toneMapped:false}));m.position.set(v.x,.025,v.y);world.add(m);
    ventObjs.push({v,m});
  }
  const gt=[];for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(M.tile[y*N+x]===T_GLASS)gt.push([x,y]);
  if(!gt.length)return;
  const isG=(x,y)=>x>=0&&y>=0&&x<N&&y<N&&M.tile[y*N+x]===T_GLASS;
  const pane=new THREE.InstancedMesh(new THREE.BoxGeometry(1,1.6,.06),new THREE.MeshLambertMaterial({color:'#9fe8ff',transparent:true,opacity:.24,depthWrite:false,emissive:'#0c2430'}),gt.length);
  const frame=new THREE.InstancedMesh(new THREE.BoxGeometry(1.02,.08,.1),lam('#c8ccd4'),gt.length);
  const o=new THREE.Object3D();
  gt.forEach(([x,y],i)=>{const ax=isG(x-1,y)||isG(x+1,y);o.position.set(x+.5,.8,y+.5);o.rotation.set(0,ax?0:Math.PI/2,0);o.updateMatrix();pane.setMatrixAt(i,o.matrix);o.position.y=1.62;o.updateMatrix();frame.setMatrixAt(i,o.matrix);});
  glassRefs={pane,frame,idx:new Map(gt.map(([x,y],i)=>[y*N+x,i]))};world.add(pane,frame);
}
function syncVents(){
  for(const o of ventObjs){if(!o.l)continue;o.g.position.set((o.l.x1+o.l.x2)/2,0,(o.l.y1+o.l.y2)/2);o.g.visible=o.l.on||o.l.tripT>0;o.mat.color.set(o.l.tripT>0&&Math.sin(M.t*30)>0?'#ffffff':'#ff2030');o.mat.opacity=.6+.3*Math.sin(M.t*9);}
  for(const o of ventObjs){if(!o.v)continue;const s=o.v.state;o.m.material.color.set(s===2?'#ffe2c0':s===1?(Math.sin(M.t*20)>0?'#ff8a3c':'#7a3a20'):'#55606e');}
}
let camObjs=[],railObj=null,discoObjs=[];
const coneMatC=()=>new THREE.MeshBasicMaterial({color:'#ff3040',transparent:true,opacity:.13,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false,side:THREE.DoubleSide});
function buildSecurity(){
  buildGlassVents();
  {const hs=(M.blds||[]).filter(b=>b.style==='hedge');
   if(hs.length){const geos=[];for(const b of hs){const H=1.45+((b.x*7+b.y*13)%5)*.03;geos.push(box(b.w,H,b.d,b.x+b.w/2,H/2,b.y+b.d/2,'#1f4a2c'),box(b.w+.06,.08,b.d+.06,b.x+b.w/2,H,b.y+b.d/2,'#2e6a3c'));}
     const m=new THREE.Mesh(mergeGeometries(geos),vcMat);m.castShadow=m.receiveShadow=true;world.add(m);}}
  camObjs=[];railObj=null;discoObjs=[];
  for(const c of M.cams||[]){
    const g=new THREE.Group();g.position.set(c.x,0,c.y);world.add(g);
    g.add(boxM(.08,2.4,.08,0,1.2,0,lam('#2a2f3a')));
    const head=new THREE.Group();head.position.y=2.35;g.add(head);
    const body=new THREE.Mesh(mergeGeometries([box(.32,.16,.18,.12,0,0,'#d8dce4'),box(.06,.1,.12,.29,0,0,'#1a1a1a')]),vcMat);head.add(body);
    const led=new THREE.Mesh(new THREE.SphereGeometry(.035,6,4),basic('#ff2030'));led.position.set(.2,.09,0);head.add(led);
    const cone=new THREE.Mesh(new THREE.CircleGeometry(c.range,16,-c.fov,c.fov*2).rotateX(-Math.PI/2),coneMatC());cone.position.y=.04;g.add(cone);
    let spot=null;if(c.spot){spot=new THREE.Mesh(new THREE.CircleGeometry(1.5,20).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:'#fff2c0',transparent:true,opacity:.32,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));g.add(spot);g.children[0].scale.y=1.7;g.children[0].position.y=2.04;head.position.y=4;}
    camObjs.push({c,g,head,cone,led,spot});
  }
  if(M.rail){
    const R=M.rail,y=R.y+.5,steel=lam('#3a404e');
    const g=new THREE.Group();world.add(g);
    g.add(boxM(N+30,.35,1.1,N/2,3.3,y,lam('#2c313d')));
    const edge=new THREE.Mesh(new THREE.BoxGeometry(N+30,.06,.06),basic('#38e8ff'));edge.position.set(N/2,3.1,y+.56);g.add(edge);
    const edge2=edge.clone();edge2.position.z=y-.56;g.add(edge2);
    for(const x of R.xs)g.add(boxM(.5,3.2,.5,x+.5,1.6,y,steel));
    const train=new THREE.Group();
    for(let k=0;k<3;k++){
      const car=new THREE.Mesh(mergeGeometries([box(4.6,1.05,.95,0,0,0,'#c9ccd4'),box(4.5,.3,.97,0,.18,0,'#16202e'),box(4.62,.08,.98,0,-.3,0,'#ff3d8b')]),vcMat);car.position.set(-k*4.9,4.05,0);car.castShadow=true;train.add(car);
      const win=new THREE.Mesh(new THREE.BoxGeometry(4.3,.22,1),basic('#ffe6b0'));win.position.set(-k*4.9,4.23,0);train.add(win);
    }
    const hl=new THREE.Mesh(new THREE.SphereGeometry(.12,8,6),basic('#ffffff'));hl.position.set(2.35,4,0);train.add(hl);
    train.position.z=y;train.visible=false;g.add(train);
    railObj={g,train};
  }
  for(const d of M.decor||[]){
    if(d.type==='disco'){
      const cols=['#ff3d8b','#38e8ff','#ffb13d','#a66bff','#5dffa0','#ff5a2a'];
      const spots=cols.map((col,i)=>{const m=new THREE.Mesh(new THREE.CircleGeometry(1.1,24).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:col,transparent:true,opacity:.35,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));m.position.y=.03;world.add(m);return m;});
      const lights=[0,1].map(i=>{const l=new THREE.PointLight(cols[i],6,10,1.4);l.position.set((d.x0+d.x1)/2,2.5,(d.y0+d.y1)/2);world.add(l);return l;});
      discoObjs.push({d,spots,lights,cols});
    }else if(d.type==='billboard'){
      const c=document.createElement('canvas');c.width=512;c.height=192;const g2=c.getContext('2d');
      const gr=g2.createLinearGradient(0,0,512,192);gr.addColorStop(0,'#0a0614');gr.addColorStop(1,'#140a20');g2.fillStyle=gr;g2.fillRect(0,0,512,192);
      g2.strokeStyle=d.col;g2.lineWidth=6;g2.strokeRect(6,6,500,180);
      g2.font='700 64px "Chakra Petch", sans-serif';g2.textAlign='center';g2.textBaseline='middle';g2.fillStyle=d.col;g2.shadowColor=d.col;g2.shadowBlur=18;g2.fillText(d.text,256,84);
      g2.font='600 26px "JetBrains Mono", monospace';g2.shadowBlur=0;g2.fillStyle='#d3dcea';g2.fillText(d.sub||'',256,150);
      const mat=new THREE.MeshBasicMaterial({map:canvasTex(c),toneMapped:false});mat.userData.shared=false;
      const grp=new THREE.Group();grp.position.set(d.x,0,d.y);grp.rotation.y=d.ang||0;world.add(grp);
      const pl=new THREE.Mesh(new THREE.PlaneGeometry(d.w,d.w*192/512),mat);pl.position.y=d.h;grp.add(pl);
      for(const sx of [-d.w*.35,d.w*.35])grp.add(boxM(.12,d.h,.12,sx,d.h/2,-.06,lam('#22262e')));
      discoObjs.push({bb:true,mat,ph:Math.random()*9});
    }
  }
}
function syncSecurity(dt){
  syncVents();
  for(const o of camObjs){
    const c=o.c;o.head.rotation.y=-c.a;o.cone.rotation.y=-c.a;
    o.cone.visible=!c.dead&&!c.off;o.cone.material.opacity=.1+(c.see||0)*.25;o.cone.material.color.set(c.see>0?'#ff6a20':'#ff3040');
    o.led.material=basic(c.dead||c.off?'#202020':(Math.sin(M.t*6)>0?'#ff2030':'#400408'));
    if(c.dead){o.head.rotation.z=.6;o.head.position.y=c.spot?3.8:2.2;}
    if(o.spot){o.spot.visible=!c.dead&&!c.off;const d=c.range*.62;o.spot.position.set(Math.cos(c.a)*d,.05,Math.sin(c.a)*d);o.spot.material.opacity=c.see>0?.5:.3;}
  }
  if(railObj){const t=M.train;railObj.train.visible=!!t;if(t)railObj.train.position.x=t.x;}
  for(const o of discoObjs){
    if(o.bb){o.mat.color.setScalar(Math.sin(M.t*13+o.ph)>.97?.35:1);continue;}
    const d=o.d,cx=(d.x0+d.x1+1)/2,cy=(d.y0+d.y1+1)/2,rx=(d.x1-d.x0)/2,ry=(d.y1-d.y0)/2;
    o.spots.forEach((m,i)=>{const a=M.t*(.6+i*.13)+i*1.7;m.position.x=cx+Math.cos(a)*rx*.8;m.position.z=cy+Math.sin(a*1.3)*ry*.8;});
    o.lights.forEach((l,i)=>{l.color.set(o.cols[(Math.floor(M.t*2)+i*3)%o.cols.length]);l.intensity=M.flags&&M.flags.blackout?0:5+Math.sin(M.t*8+i)*2;});
  }
}

/* ---------- personagens ---------- */
const gunGeo={};
function getGun(w){if(!gunGeo[w]){const L=WD[w].len||.2;const g=mergeGeometries([box(.05,L,.07,0,-.38-L/2+.06,.03,w==='feixe'?'#3a2a40':'#23262e'),box(.03,.06,.03,0,-.38-L+.06,.03,w==='feixe'?'#ff3c78':'#111111')]);g.userData.shared=true;gunGeo[w]=g;}return gunGeo[w];}
const shadowGeo=new THREE.CircleGeometry(.27,14).rotateX(-Math.PI/2);shadowGeo.userData.shared=true;
const shadowMat=new THREE.MeshBasicMaterial({color:'#000',transparent:true,opacity:.42,depthWrite:false});shadowMat.userData.shared=true;
const rotorGeo=new THREE.CircleGeometry(.12,10).rotateX(-Math.PI/2);rotorGeo.userData.shared=true;
const rotorMat=new THREE.MeshBasicMaterial({color:'#9aa4b4',transparent:true,opacity:.4,depthWrite:false,side:THREE.DoubleSide});rotorMat.userData.shared=true;
const shieldGeo=new THREE.SphereGeometry(.62,16,10);shieldGeo.userData.shared=true;
const ringGeo=new THREE.RingGeometry(.3,.37,28).rotateX(-Math.PI/2);ringGeo.userData.shared=true;
function getGun2(w){const k='g2'+w;if(!gunGeo[k]){const L=WD[w].len||.2,f=w==='feixe';const g=mergeGeometries([box(.045,.06,L,0,.02,L/2-.03,f?'#3a2a40':'#23262e'),box(.03,.03,.05,0,.02,L-.01,f?'#ff3c78':'#111111'),box(.035,.08,.045,0,-.03,0,'#15161a')]);g.userData.shared=true;gunGeo[k]=g;}return gunGeo[k];}
const visorGeo=new THREE.BoxGeometry(.12,.016,.02);visorGeo.userData.shared=true;
function makeFigure(u){
  const g=new THREE.Group(),fig=new THREE.Group();g.add(fig);
  if(u.kind==='drone'){
    const body=new THREE.Mesh(mergeGeometries([box(.34,.1,.34,0,0,0,'#2a2f3a'),box(.56,.03,.05,0,.02,0,'#15181f'),box(.05,.03,.56,0,.02,0,'#15181f'),box(.1,.08,.12,0,-.08,.15,'#111318'),box(.3,.02,.3,0,.06,0,'#c8301e')]),vcMat);body.castShadow=true;
    const rot=[];for(const [x,z] of [[.27,.27],[-.27,.27],[.27,-.27],[-.27,-.27]]){const m=new THREE.Mesh(rotorGeo,rotorMat);m.position.set(x,.06,z);fig.add(m);rot.push(m);}
    const eye=new THREE.Mesh(new THREE.BoxGeometry(.12,.04,.02),basic('#ffaa3c'));eye.position.set(0,-.07,.22);
    fig.add(body,eye);fig.position.y=1.45;
    const sh=new THREE.Mesh(shadowGeo,shadowMat);sh.position.y=.012;sh.scale.setScalar(.8);g.add(sh);
    return {g,fig,eye,rot,sh,ring:null};
  }
  if(u.kind==='torre'){
    const base=new THREE.Mesh(mergeGeometries([cyl(.24,.3,.42,8,0,.21,0,'#2c313d'),cyl(.3,.3,.05,8,0,.02,0,'#1b1e26')]),vcMat);base.castShadow=true;
    const head=new THREE.Group();head.position.y=.52;
    const hm=new THREE.Mesh(mergeGeometries([box(.32,.2,.38,0,0,0,'#3a404e'),box(.07,.07,.42,0,0,.36,'#15181f')]),vcMat);hm.castShadow=true;
    const eye=new THREE.Mesh(new THREE.BoxGeometry(.2,.05,.02),basic('#ffaa3c'));eye.position.set(0,.04,.2);
    head.add(hm,eye);fig.add(base,head);
    const sh=new THREE.Mesh(shadowGeo,shadowMat);g.add(sh);
    return {g,fig,head,eye,ring:null};
  }
  const tall=u.heavy?1.32:u.rival?1.15:(u.kind==='agente'||u.kind==='inimigo')?1.07:1;
  const C=assets.ready?makeChar(u,tall):null;
  if(C){
    fig.add(C.root);
    const gun=new THREE.Mesh(getGun2('pistola'),vcMat);gun.visible=false;gun.castShadow=true;attach(C,'gun',gun);
    let visor=null;
    if(u.visor&&C.key!=='m_space'&&C.key!=='m_swat'){visor=new THREE.Mesh(visorGeo,basic(u.trim));attach(C,'visor',visor);}
    if(u.umb){const um=new THREE.Mesh(mergeGeometries([cyl(.012,.012,.55,4,.16,1.05,.08,'#15161a'),colGeo(new THREE.ConeGeometry(.46,.18,8).translate(.16,1.35,.08),u.umb)]),vcMat);um.castShadow=true;fig.add(um);}
    const sh=new THREE.Mesh(shadowGeo,shadowMat);sh.position.y=.012;g.add(sh);
    const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.9,toneMapped:false,depthWrite:false}));ring.position.y=.02;ring.visible=false;g.add(ring);
    let bubble=null;if(u.shield!==undefined){bubble=new THREE.Mesh(shieldGeo,new THREE.MeshBasicMaterial({color:'#6fe4ff',transparent:true,opacity:.22,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));bubble.position.y=.6;g.add(bubble);}
    play(C,'Idle',1,0);C.mixer.update(Math.random()*1.5);
    return {g,fig,C,gun,gunW:null,visor,ring,sh,bubble,lag:0};
  }
  fig.scale.setScalar(tall);
  const parts=[];
  parts.push(cyl(.15,.13,.36,7,0,.58,0,u.coat));
  if(u.long)parts.push(cyl(.14,.23,.44,7,0,.35,0,u.coat));else parts.push(cyl(.14,.16,.12,7,0,.42,0,u.legs));
  parts.push(cyl(.155,.155,.04,7,0,.755,0,u.trim));
  parts.push(box(.16,.17,.16,0,.87,0,u.skin));
  parts.push(box(.17,.06,.17,0,.97,0,u.hair),box(.17,.11,.04,0,.91,-.075,u.hair));
  if(u.cap)parts.push(box(.2,.05,.23,0,.985,.015,'#d8e4ff'),box(.18,.05,.18,0,1.02,0,'#22407a'));
  if(u.helmet)parts.push(box(.2,.08,.2,0,1.0,0,'#e8c020'),box(.24,.03,.24,0,.965,0,'#e8c020'),box(.3,.05,.06,0,.66,.13,'#f2f2a0'));
  if(u.kind==='vip')parts.push(box(.05,.2,.02,0,.62,.135,'#8a1a22'));
  if(u.heavy)parts.push(box(.44,.14,.26,0,.74,0,'#3a3e48'),box(.12,.12,.28,-.2,.8,0,u.trim),box(.12,.12,.28,.2,.8,0,u.trim),box(.3,.3,.08,0,.6,.15,'#3a3e48'),box(.2,.06,.04,0,.89,.09,u.trim));
  if(u.umb)parts.push(cyl(.012,.012,.55,4,.13,1.0,.05,'#15161a'),colGeo(new THREE.ConeGeometry(.46,.18,8).translate(.13,1.3,.05),u.umb));
  const body=new THREE.Mesh(mergeGeometries(parts),vcMat);body.castShadow=true;fig.add(body);
  const mkLimb=(geo,x,y)=>{const p=new THREE.Group();p.position.set(x,y,0);const m=new THREE.Mesh(geo,vcMat);m.castShadow=true;p.add(m);fig.add(p);return p;};
  const legGeo=box(.085,.4,.1,0,-.2,0,u.legs);
  const legL=mkLimb(legGeo,-.065,.4),legR=mkLimb(legGeo,.065,.4);
  const armGeo=mergeGeometries([box(.07,.33,.08,0,-.165,0,u.coat),box(.065,.06,.075,0,-.36,0,u.skin)]);
  const armL=mkLimb(armGeo,-.19,.74),armR=mkLimb(armGeo,.19,.74);
  const gun=new THREE.Mesh(getGun('pistola'),vcMat);gun.visible=false;armR.add(gun);
  let visor=null;
  if(u.visor){visor=new THREE.Mesh(new THREE.BoxGeometry(.15,.035,.02),basic(u.trim));visor.position.set(0,.885,.085);fig.add(visor);}
  const sh=new THREE.Mesh(shadowGeo,shadowMat);sh.position.y=.012;g.add(sh);
  const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.9,toneMapped:false,depthWrite:false}));ring.position.y=.02;ring.visible=false;g.add(ring);
  let bubble=null;if(u.shield!==undefined){bubble=new THREE.Mesh(shieldGeo,new THREE.MeshBasicMaterial({color:'#6fe4ff',transparent:true,opacity:.22,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));bubble.position.y=.6;g.add(bubble);}
  return {g,fig,body,legL,legR,armL,armR,gun,gunW:null,visor,ring,sh,bubble};
}
hooks.convert=u=>{
  const r=u.r3;if(!r)return;
  if(u.kind==='torre'||u.kind==='drone'){r.eye.material=basic('#4fd8ff');return;}
  if(r.visor)r.visor.material=basic('#4fd8ff');
  else if(r.C){r.visor=new THREE.Mesh(visorGeo,basic('#4fd8ff'));attach(r.C,'visor',r.visor);}
  else{r.visor=new THREE.Mesh(new THREE.BoxGeometry(.15,.035,.02),basic('#4fd8ff'));r.visor.position.set(0,.885,.085);r.fig.add(r.visor);}
};
/* personagem com modelo 3D: escolhe a animação pelo estado da unidade */
function syncGlb(u,r,dt){
  const C=r.C;
  const tick=()=>{if(onScreen(u.x,u.y)){C.mixer.update(dt+r.lag);r.lag=0;}else r.lag=Math.min(1,r.lag+dt);};
  if(u.dead){
    if(C.cur!=='Death')play(C,'Death',u.kbFrom?1.4:1,.08);
    if(u.kbFrom&&!r.kbDone){r.kbT=(r.kbT||0)+dt;const t=Math.min(1,r.kbT/.55),q=1-Math.pow(1-t,2);r.g.position.set(u.kbFrom.x+(u.x-u.kbFrom.x)*q,Math.sin(Math.PI*t)*.85*(u.kb?u.kb.p+.3:.6),u.kbFrom.y+(u.y-u.kbFrom.y)*q);r.fig.rotation.y=t*Math.PI*1.4;if(t>=1)r.kbDone=true;}
    r.ring.visible=false;r.sh.visible=false;r.gun.visible=false;if(r.bubble)r.bubble.visible=false;
    if(C.act&&C.act.time<C.act.getClip().duration||u.kbFrom&&!r.kbDone)tick();
    return;
  }
  const spd=u.path?(u.curSpd||1.5):0,moving=spd>0;
  const wk=curW(u),showGun=isArmed(u)&&(u.kind!=='policia'||u.follower||M.policeAggro>0||u.warned)&&(u.kind!=='guarda'||u.alerted||u.follower);
  if(showGun&&r.gunW!==wk){r.gun.geometry=getGun2(wk);r.gunW=wk;}
  r.gun.visible=showGun;
  const dancing=u.dance&&!(u.panicT>0),panic=(u.kind==='civil'&&u.panicT>0&&!u.follower)||u.burn>0;
  let a,ts=1;
  if(u.hjT>0||(u.kind==='agente'&&u.probing)||(showGun&&u.rel>0&&!moving))a='Interact';
  else if(moving){
    const run=spd>=1.9||panic;
    if(showGun&&u.aimT>0){a='Run_Shoot';ts=clamp(spd*.4,.7,1.5);}
    else if(run){a='Run';ts=clamp(spd*.38,.75,1.5);}
    else{a='Walk';ts=clamp(spd*1.05,.6,1.7);}
  }
  else if(dancing){a='Wave';ts=1.4;}
  else if(showGun&&u.aimT>0)a=u.flash>0?'Idle_Gun_Shoot':'Idle_Gun_Pointing';
  else if(showGun)a='Idle_Gun';
  else if(u.hitT>0)a='HitRecieve';
  else a=u.kind==='civil'||u.disguise?'Idle_Neutral':'Idle';
  play(C,a,ts);
  r.fig.position.y=0;r.fig.rotation.set(0,0,0);
  tick();
  const cl=!!u.cloak;if(r.cl!==cl){r.cl=cl;cloakChar(C,cl);}
  const hov=M.hover===u;
  r.ring.scale.setScalar(u.sel?1+.07*Math.sin(M.t*6):1);
  if(u.sel){r.ring.visible=true;r.ring.material.color.set('#4fd8ff');}
  else if(hov){r.ring.visible=true;r.ring.material.color.set(u.fac==='corp'?'#ff4d5e':u.fac==='police'?'#7fb0ff':'#ffa53d');}
  else if(u.follower){r.ring.visible=true;r.ring.material.color.set('#1d5f78');}
  else r.ring.visible=false;
}
function syncUnit(u,dt){
  if(u.r3&&!u.r3.C&&!u.r3.tried&&!u.mech&&assets.ready)u.r3rebuild=true;
  if(u.r3&&u.r3rebuild){world.remove(u.r3.g);if(u.r3.C){u.r3.C.mat.dispose();if(u.r3.C.cmat)u.r3.C.cmat.dispose();}u.r3=null;u.r3rebuild=false;}
  let r=u.r3;if(!r){r=u.r3=makeFigure(u);world.add(r.g);if(u.follower)hooks.convert(u);}
  r.g.visible=!u.inCar&&!u.vanished;if(u.inCar||u.vanished)return;
  r.g.position.set(u.x,0,u.y);
  if(u.kind==='drone'){
    r.g.rotation.y=Math.PI/2-u.face;
    if(u.dead){r.fall=Math.min(1,(r.fall||0)+dt*2.5);r.fig.position.y=1.37*(1-r.fall*r.fall)+.08;r.fig.rotation.z=r.fall*.9;r.sh.visible=false;return;}
    r.fig.position.y=1.42+Math.sin(M.t*3+u.id)*.06;r.fig.rotation.z=Math.sin(M.t*2+u.id)*.05;r.fig.rotation.x=Math.min(.25,(u.curSpd||0)*.06);
    for(const m of r.rot)m.rotation.y+=dt*40;
    r.eye.material=basic(u.fac==='player'?'#4fd8ff':u.alerted?'#ff3040':'#ffaa3c');
    return;
  }
  if(u.kind==='torre'){
    r.head.rotation.y=Math.PI/2-u.face;
    if(u.dead){r.fig.rotation.z=.5;r.fig.position.y=-.15;}
    else if(u.off)r.eye.material=basic('#202020');
    else if(u.fac==='corp')r.eye.material=basic(u.alerted?'#ff3040':'#ffaa3c');
    return;
  }
  r.g.rotation.y=Math.PI/2-u.face;
  if(r.C){if(r.bubble){r.bubble.visible=!!u.shield&&!u.dead;if(r.bubble.visible){r.bubble.material.opacity=.16+.1*Math.sin(M.t*7);r.bubble.scale.setScalar(1.25+.04*Math.sin(M.t*11));}}syncGlb(u,r,dt);return;}
  if(r.bubble){r.bubble.visible=!!u.shield&&!u.dead;if(r.bubble.visible){r.bubble.material.opacity=.16+.1*Math.sin(M.t*7);r.bubble.scale.setScalar(1.25+.04*Math.sin(M.t*11));}}
  if(u.dead){
    if(r.fdir===undefined){r.fdir=u.kbFrom?-1:(Math.random()<.55?-1:1);r.froll=(Math.random()-.5)*.7;}
    r.fall=Math.min(1,(r.fall||0)+dt*(u.kbFrom?2.2:3.2));const e=1-Math.pow(1-r.fall,3);
    r.fig.rotation.x=r.fdir*e*Math.PI/2;r.fig.rotation.z=e*r.froll;r.fig.position.y=e*.09;r.fig.position.z=0;
    r.legL.rotation.x=r.legR.rotation.x=e*.25*r.fdir;r.armL.rotation.x=-e*2.6;r.armR.rotation.x=-e*2.2;
    if(u.kbFrom&&!r.kbDone){r.kbT=(r.kbT||0)+dt;const t=Math.min(1,r.kbT/.55),q=1-Math.pow(1-t,2);r.g.position.set(u.kbFrom.x+(u.x-u.kbFrom.x)*q,Math.sin(Math.PI*t)*.85*(u.kb?u.kb.p+.3:.6),u.kbFrom.y+(u.y-u.kbFrom.y)*q);r.fig.rotation.y=t*Math.PI*1.4;if(t>=1)r.kbDone=true;}
    r.ring.visible=false;r.sh.visible=false;r.gun.visible=false;return;
  }
  const spd=u.path?(u.curSpd||1.5):0,moving=spd>0,amp=moving?Math.min(.95,.38+spd*.15):0,ph=u.walkT,sw=Math.sin(ph)*amp;
  const k=Math.min(1,dt*16),L=(o,p,v)=>{o[p]+=(v-o[p])*k;};
  const wk=curW(u),showGun=isArmed(u)&&(u.kind!=='policia'||u.follower||M.policeAggro>0||u.warned)&&(u.kind!=='guarda'||u.alerted||u.follower);
  if(showGun&&r.gunW!==wk){r.gun.geometry=getGun(wk);r.gunW=wk;}
  r.gun.visible=showGun;
  const rec=u.flash>0?(wk==='escopeta'?.6:wk==='feixe'?.45:wk==='serra'?.18:.28):0;
  let aL=-sw*.7,aR=sw*.7,aLz=0,lean=moving?Math.min(.22,spd*.05):0,back=0;
  if(u.hjT>0){aL=-.2+Math.sin(M.t*30)*.15;aR=-.2-Math.sin(M.t*30)*.15;}
  else if((u.kind==='civil'&&u.panicT>0&&!u.follower)||u.burn>0){const f=u.burn>0?22:9;aL=-2.7+Math.sin(M.t*f)*.4;aR=-2.7-Math.sin(M.t*f)*.4;}
  else if(showGun&&u.rel>0){aR=-.55;aL=-1.15;aLz=-.55;}
  else if(showGun&&u.aimT>0){aR=-Math.PI/2+rec;aL=-1.35+rec;aLz=-.35;lean=Math.max(lean*.5,.05);back=-rec*.12;}
  else if(showGun){aR=-.45;aL=-sw*.5;}
  if(u.kind==='agente'&&u.probing){aL=-1.9+Math.sin(M.t*12)*.08;aLz=-.2;}
  const dancing=u.dance&&!(u.panicT>0);if(dancing){const s=Math.sin(M.t*7+u.id);aL=-2.3+s*.5;aR=-2.3-s*.5;}
  if(u.hitT>0)lean-=.3;
  L(r.legL.rotation,'x',sw);L(r.legR.rotation,'x',-sw);
  L(r.armL.rotation,'x',aL);L(r.armR.rotation,'x',aR);L(r.armL.rotation,'z',aLz);
  L(r.fig.rotation,'x',lean);r.fig.rotation.z=u.hjT>0?Math.sin(M.t*17)*.05:0;
  r.fig.position.y=dancing?Math.abs(Math.sin(M.t*7+u.id))*.07:moving?Math.abs(Math.sin(ph))*.04*amp:Math.sin(M.t*2+u.id)*.004;
  r.fig.position.z=back;

  const cl=!!u.cloak;if(r.cl!==cl){r.cl=cl;r.fig.traverse(o=>{if(o.isMesh&&o.material===(cl?vcMat:cloakMat))o.material=cl?cloakMat:vcMat;});}
  const hov=M.hover===u;
  r.ring.scale.setScalar(u.sel?1+.07*Math.sin(M.t*6):1);
  if(u.sel){r.ring.visible=true;r.ring.material.color.set('#4fd8ff');}
  else if(hov){r.ring.visible=true;r.ring.material.color.set(u.fac==='corp'?'#ff4d5e':u.fac==='police'?'#7fb0ff':'#ffa53d');}
  else if(u.follower){r.ring.visible=true;r.ring.material.color.set('#1d5f78');}
  else r.ring.visible=false;
}

/* ---------- veículos ---------- */
const lightConeTex=(()=>{const c=document.createElement('canvas');c.width=128;c.height=64;const g=c.getContext('2d');const gr=g.createRadialGradient(0,32,0,0,32,128);gr.addColorStop(0,'rgba(255,240,200,.55)');gr.addColorStop(1,'rgba(255,240,200,0)');g.fillStyle=gr;g.beginPath();g.moveTo(0,26);g.lineTo(128,0);g.lineTo(128,64);g.lineTo(0,38);g.fill();return new THREE.CanvasTexture(c);})();
const coneMat=new THREE.MeshBasicMaterial({map:lightConeTex,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false});coneMat.userData.shared=true;
const coneGeo=new THREE.PlaneGeometry(2.6,1.3).rotateX(-Math.PI/2).translate(2.1,.03,0);coneGeo.userData.shared=true;
function makeCar(c){
  const M3=makeCarModel(c);
  if(M3){
    const g=new THREE.Group(),L=M3.len/2,W=M3.wid/2,H=M3.ht;
    M3.holder.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
    const hl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.03,.05,.13).translate(L,H*.42,W*.62),new THREE.BoxGeometry(.03,.05,.13).translate(L,H*.42,-W*.62)]),basic('#fff3c8'));
    const tl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.03,.05,.14).translate(-L,H*.45,W*.62),new THREE.BoxGeometry(.03,.05,.14).translate(-L,H*.45,-W*.62)]),basic('#ff2030'));
    const cone=new THREE.Mesh(coneGeo,coneMat);cone.position.x=L-.8;
    const ring=new THREE.Mesh(new THREE.RingGeometry(L*1.12,L*1.12+.1,32).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.85,toneMapped:false,depthWrite:false}));ring.position.y=.03;ring.visible=false;
    g.add(M3.holder,hl,tl,cone,ring);world.add(g);
    return {g,body:null,glb:M3,hl,tl,cone,ring,dead:false};
  }
  const g=new THREE.Group();
  const taxi=c.col==='#e0a020';
  const parts=[box(1.6,.3,.74,0,.27,0,c.col),box(1.62,.1,.76,0,.11,0,'#111318'),box(.86,.26,.66,-.1,.55,0,'#1a2433'),box(.8,.04,.62,-.1,.69,0,c.col)];
  for(const [x,z] of [[.5,.37],[.5,-.37],[-.5,.37],[-.5,-.37]])parts.push(colGeo(new THREE.CylinderGeometry(.13,.13,.08,10).rotateX(Math.PI/2).translate(x,.13,z),'#0a0a0a'));
  if(taxi)parts.push(box(.24,.08,.12,-.1,.75,0,'#ffd060'));
  const body=new THREE.Mesh(mergeGeometries(parts),vcMat);body.castShadow=true;body.receiveShadow=true;
  const hl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.04,.07,.16).translate(.8,.3,.24),new THREE.BoxGeometry(.04,.07,.16).translate(.8,.3,-.24)]),basic('#fff3c8'));
  const tl=new THREE.Mesh(mergeGeometries([new THREE.BoxGeometry(.04,.06,.18).translate(-.81,.32,.25),new THREE.BoxGeometry(.04,.06,.18).translate(-.81,.32,-.25)]),basic('#ff2030'));
  const cone=new THREE.Mesh(coneGeo,coneMat);
  const ring=new THREE.Mesh(new THREE.RingGeometry(.95,1.05,32).rotateX(-Math.PI/2),new THREE.MeshBasicMaterial({color:'#4fd8ff',transparent:true,opacity:.85,toneMapped:false,depthWrite:false}));ring.position.y=.03;ring.visible=false;
  g.add(body,hl,tl,cone,ring);world.add(g);
  return {g,body,hl,tl,cone,ring,dead:false};
}
function syncCar(c,dt){
  if(c.r3&&!c.r3.glb&&assets.ready){world.remove(c.r3.g);c.r3=null;}
  let r=c.r3;if(!r)r=c.r3=makeCar(c);
  if(r.glb&&!c.dead){const sp=c.player?(c.spd||c.cur||0):(c.stopT>0?0:(c.cur||c.v||0));for(const w of r.glb.wheels)w.rotation.x+=sp*dt*2.2;}
  r.g.position.set(c.x,0,c.y);r.g.rotation.y=-c.ang;
  if(!c.player&&!c.dead)c.ang=Math.atan2(c.dy,c.dx);
  if(c.dead&&!r.dead&&r.glb){r.dead=true;r.glb.holder.traverse(o=>{if(o.isMesh)o.material=lam('#24221f');});r.hl.visible=r.tl.visible=r.cone.visible=false;r.g.position.y=-.03;}
  if(c.dead&&!r.dead){r.dead=true;r.body.material=wreckMat;r.hl.visible=r.tl.visible=r.cone.visible=false;r.g.position.y=-.03;}
  const sel=c.occ.some(o=>o.sel);r.ring.visible=sel||M.hoverCar===c;r.ring.material.color.set(sel?'#4fd8ff':'#ffa53d');
}

/* ---------- efeitos ---------- */
let tracerLines,tracerPos,tracerCol,psys={},beamMeshes=[],nadeMeshes=[],dropMeshes=new Map();
const MAXT=500,MAXP=1600;
const colCache=new Map();function rgb(hex){let c=colCache.get(hex);if(!c){c=new THREE.Color(hex);colCache.set(hex,c);}return c;}
function buildFx(){
  const tg=new THREE.BufferGeometry();tracerPos=new Float32Array(MAXT*6);tracerCol=new Float32Array(MAXT*8);
  tg.setAttribute('position',new THREE.BufferAttribute(tracerPos,3));tg.setAttribute('color',new THREE.BufferAttribute(tracerCol,4));
  vfxRings=[];vfxSprites=[];
  tracerLines=new THREE.LineSegments(tg,new THREE.LineBasicMaterial({vertexColors:true,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));tracerLines.frustumCulled=false;world.add(tracerLines);
  const mk=(name,blend,size)=>{const g=new THREE.BufferGeometry();const pos=new Float32Array(MAXP*3),col=new Float32Array(MAXP*4);g.setAttribute('position',new THREE.BufferAttribute(pos,3));g.setAttribute('color',new THREE.BufferAttribute(col,4));
    const m=new THREE.PointsMaterial({size:4,map:softTex,vertexColors:true,transparent:true,depthWrite:false,blending:blend,sizeAttenuation:false,toneMapped:false});
    const p=new THREE.Points(g,m);p.frustumCulled=false;world.add(p);psys[name]={p,pos,col,size};};
  mk('fire',THREE.AdditiveBlending,.62);mk('smoke',THREE.NormalBlending,.9);mk('spark',THREE.AdditiveBlending,.11);mk('blood',THREE.NormalBlending,.12);
  for(let i=0;i<8;i++){const b=new THREE.Mesh(new THREE.CylinderGeometry(.035,.035,1,6).rotateZ(Math.PI/2),new THREE.MeshBasicMaterial({color:'#ff3c78',transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));b.visible=false;world.add(b);beamMeshes.push(b);}
}
const nadeGeo=new THREE.SphereGeometry(.08,8,6);nadeGeo.userData.shared=true;
const dropGeo=mergeGeometries([box(.42,.07,.12,0,.08,0,'#2b2f3a'),box(.12,.12,.06,-.1,.04,0,'#1b1d24')]);dropGeo.userData.shared=true;
const dropRingGeo=new THREE.RingGeometry(.24,.3,20).rotateX(-Math.PI/2);dropRingGeo.userData.shared=true;
function syncFx(){
  let n=0;
  for(const t of M.tracers){
    if(t.beam)continue;if(n>=MAXT)break;
    const a=t.life/t.max,c=rgb(t.col);
    tracerPos.set([t.x1,.68,t.y1,t.x2,.6,t.y2],n*6);tracerCol.set([c.r*a,c.g*a,c.b*a,a,c.r*a*.5,c.g*a*.5,c.b*a*.5,a*.5],n*8);n++;
  }
  tracerLines.geometry.setDrawRange(0,n*2);tracerLines.geometry.attributes.position.needsUpdate=true;tracerLines.geometry.attributes.color.needsUpdate=true;
  let bi=0;
  for(const t of M.tracers){if(!t.beam||bi>=beamMeshes.length)continue;const b=beamMeshes[bi++],dx=t.x2-t.x1,dy=t.y2-t.y1,L=Math.hypot(dx,dy);b.visible=true;b.position.set((t.x1+t.x2)/2,.66,(t.y1+t.y2)/2);b.scale.set(L,1+2*(1-t.life/t.max),1+2*(1-t.life/t.max));b.rotation.set(0,-Math.atan2(dy,dx),0);b.material.opacity=t.life/t.max;}
  for(;bi<beamMeshes.length;bi++)beamMeshes[bi].visible=false;
  const cnt={fire:0,smoke:0,spark:0,blood:0},names=['blood','fire','smoke','spark'];
  for(const p of M.parts){
    const nm=names[p.type],s=psys[nm],i=cnt[nm];if(i>=MAXP)continue;cnt[nm]++;
    const a=p.life/p.max,c=rgb(p.col);
    s.pos[i*3]=p.x;s.pos[i*3+1]=p.z/30;s.pos[i*3+2]=p.y;
    s.col[i*4]=c.r;s.col[i*4+1]=c.g;s.col[i*4+2]=c.b;s.col[i*4+3]=nm==='smoke'?a*.6:a;
  }
  const px=SCALE*camS.zoom*PR;
  for(const nm in psys){const s=psys[nm],g=s.p.geometry;g.setDrawRange(0,cnt[nm]);g.attributes.position.needsUpdate=true;g.attributes.color.needsUpdate=true;s.p.material.size=Math.max(1.5,s.size*px);}
  while(nadeMeshes.length<M.nades.length){const m=new THREE.Mesh(nadeGeo,lam('#2a2f3a'));world.add(m);nadeMeshes.push(m);}
  nadeMeshes.forEach((m,i)=>{const q=M.nades[i];m.visible=!!q;if(!q)return;const k=q.t/q.T;m.position.set(q.sx+(q.tx-q.sx)*k,.5+Math.sin(Math.PI*k)*1.8,q.sy+(q.ty-q.sy)*k);});
  const live=new Set(M.drops);
  for(const [d,m] of dropMeshes)if(!live.has(d)){world.remove(m);dropMeshes.delete(d);}
  for(const d of M.drops){let m=dropMeshes.get(d);if(!m){m=new THREE.Group();m.add(new THREE.Mesh(dropGeo,vcMat));const rg=new THREE.Mesh(dropRingGeo,basic('#ffa53d',{transparent:true,opacity:.8}));rg.position.y=.02;m.add(rg);m.position.set(d.x,0,d.y);world.add(m);dropMeshes.set(d,m);}m.children[0].rotation.y=M.t*2;m.children[0].position.y=.05+Math.sin(M.t*4)*.04;}
  for(const o of propObjs)if(o.p.dead&&o.g.visible)o.g.visible=false;
  for(const o of termObjs)o.scr.color.set(o.t.done?'#5dffa0':o.t.touch>0?'#ffa53d':'#4fd8ff');
  if(evacRing)for(const r of evacRing)r.material.opacity=.45+.35*Math.sin(M.t*4);
  if(escRing)escRing.visible=!!(M.vip&&M.vip.fleeing&&!M.vip.dead);
  blinkMat.color.set(Math.sin(M.t*4)>0?'#ff2030':'#300408');
}

/* ---------- luzes dinâmicas ---------- */
let lampT=0;
function syncLights(dt){
  lampT-=dt;
  if(lampT<=0){
    lampT=.4;
    const sorted=M.lamps.filter(l=>!l.dead).sort((a,b)=>Math.hypot(a.x-camS.x,a.y-camS.y)-Math.hypot(b.x-camS.x,b.y-camS.y));
    lampLights.forEach((l,i)=>{const s=sorted[i];if(!s){l.intensity=0;return;}l.position.set(s.x+.34,s.tall?3.8:2.1,s.y);l.color.set(s.col);l.intensity=s.tall?16:7;l.distance=s.tall?14:9;});
  }
  const cands=[];
  for(const f of M.flashes)cands.push({x:f.x,y:f.y,h:f.i>5?1.2:.7,i:f.i*(f.life/f.max),c:f.col});
  for(const f of M.fires||[])cands.push({x:f.x,y:f.y,h:.5,i:(4+Math.random()*1.5)*Math.min(1,f.life/2),c:'#ff7a28'});
  for(const u of M.units)if(u.burn>0&&!u.dead)cands.push({x:u.x,y:u.y,h:.6,i:3,c:'#ff7a28'});
  for(const c of M.cars)if(c.dead&&c.smokeT!==undefined)cands.push({x:c.x,y:c.y,h:.8,i:2.2+Math.random(),c:'#ff6a20'});
  cands.sort((a,b)=>b.i-a.i);
  fxLights.forEach((l,i)=>{const c=cands[i];if(!c){l.intensity=0;return;}l.position.set(c.x,c.h,c.y);l.color.set(c.c);l.intensity=c.i;l.distance=c.i>10?14:7;});
}

/* ---------- prédios transparentes na frente do esquadrão ---------- */
const camDir=new THREE.Vector3(),orig=new THREE.Vector3();
function cutaway(){
  camera.getWorldDirection(camDir);camDir.negate();
  const hit=new Set();
  const subjects=M.agents.filter(a=>!a.dead).map(a=>a.inCar||a);
  if(M.vip&&!M.vip.dead)subjects.push(M.vip);if(M.sci&&!M.sci.dead)subjects.push(M.sci);
  for(const s of subjects){
    orig.set(s.x,.45,s.y);ray.set(orig,camDir);ray.far=200;
    for(const h of ray.intersectObjects(bldMeshes,false))hit.add(h.object);
  }
  for(const m of bldMeshes){
    const f=hit.has(m);if(f===m.userData.fade)continue;m.userData.fade=f;
    m.material=f?m.userData.mats.fade:m.userData.mats.norm;m.castShadow=!f;
    for(const e of m.userData.extra)e.visible=!f;
    if(m.userData.acs)for(const a of m.userData.acs)for(const im of a.ims){im.setMatrixAt(a.i,f?ZERO:a.mtx);im.instanceMatrix.needsUpdate=true;}
  }
}

/* ---------- quadro ---------- */
/* resolução dinâmica: baixa a escala interna quando o quadro passa de ~22 ms e devolve quando sobra folga */
function adaptRes(dt){
  if(!(dt>0)||dt>.25)return;dynAvg+=(dt*1000-dynAvg)*.05;dynT-=dt;if(dynT>0)return;
  let s=dynScale;if(dynAvg>22&&s>.6)s=Math.max(.6,s-.1);else if(dynAvg<13&&s<1)s=Math.min(1,s+.1);
  if(s!==dynScale){dynScale=s;dynT=1.5;resize();}
}
export function renderFrame(dt,ui){
  if(!M||!world)return;
  adaptRes(dt);
  camS.yawA+=(camS.yaw*Math.PI/2-camS.yawA)*Math.min(1,dt*7);
  if(camS.zoomT!=null){camS.zoom+=(camS.zoomT-camS.zoom)*Math.min(1,dt*12);if(Math.abs(camS.zoomT-camS.zoom)<.002){camS.zoom=camS.zoomT;camS.zoomT=null;}}
  let sx=0,sy=0;if(M.shake>0){sx=(Math.random()-.5)*M.shake*.4;sy=(Math.random()-.5)*M.shake*.4;}
  const ox=camS.x,oy=camS.y;camS.x+=sx;camS.y+=sy;updCam();camS.x=ox;camS.y=oy;
  cullBegin(camera);
  for(const u of M.units)syncUnit(u,dt);
  for(const c of M.cars)syncCar(c,dt);
  syncFx();syncDecor(dt);syncDestruct();syncVfx();syncSecurity(dt);cloakMat.opacity=.13+.08*Math.sin(M.t*9);syncLights(dt);cutaway();
  if(M.decalsDirty){decalT-=dt;if(decalT<=0){decalT=.3;M.decalsDirty=false;groundTex.needsUpdate=true;}}
  if(settings.bloom)composer.render();else renderer.render(scene,camera);
  listener.x=camS.x;listener.y=camS.y;
  overlay(dt,ui);
}

/* ---------- camada 2D: marcadores, chuva, vinheta ---------- */
let vignette=null;
function makeVignette(){
  vignette=document.createElement('canvas');vignette.width=Math.max(1,VW>>1);vignette.height=Math.max(1,VH>>1);
  const v=vignette.getContext('2d'),w=vignette.width,h=vignette.height;
  const g=v.createRadialGradient(w/2,h/2,Math.min(w,h)*.32,w/2,h/2,Math.max(w,h)*.75);g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(1,'rgba(2,3,10,.62)');v.fillStyle=g;v.fillRect(0,0,w,h);
}
const rain=Array.from({length:260},()=>({x:Math.random()*2400,y:Math.random()*1400,s:800+Math.random()*500,l:12+Math.random()*16}));
function overlay(dt,ui){
  const c=octx;c.setTransform(ODPR,0,0,ODPR,0,0);c.clearRect(0,0,VW,VH);
  c.strokeStyle='rgba(160,185,255,.2)';c.lineWidth=1;c.beginPath();
  const rn=REDUCED?80:rain.length;
  for(let k=0;k<rn;k++){const r=rain[k];r.y+=r.s*dt;r.x-=r.s*.16*dt;if(r.y>VH+20){r.y=-20;r.x=Math.random()*(VW+200);}if(r.x<-20)r.x+=VW+40;c.moveTo(r.x,r.y);c.lineTo(r.x+r.l*.16,r.y-r.l);}
  c.stroke();
  if(vignette)c.drawImage(vignette,0,0,VW,VH);
  if(M.hurtFlash>0){M.hurtFlash=Math.max(0,M.hurtFlash-dt*1.8);const g=c.createRadialGradient(VW/2,VH/2,Math.min(VW,VH)*.32,VW/2,VH/2,Math.max(VW,VH)*.72);g.addColorStop(0,'rgba(255,40,60,0)');g.addColorStop(1,`rgba(255,40,60,${Math.min(.5,M.hurtFlash*.5)})`);c.fillStyle=g;c.fillRect(0,0,VW,VH);}
  if(M.demo)return;
  c.textAlign='center';
  for(const mk of M.marks){const p=toScreen(mk.x,mk.y),k=mk.life/.6,s=SCALE*camS.zoom*(.15+.5*(1-k));c.globalAlpha=k;c.strokeStyle=mk.col;c.lineWidth=2;c.beginPath();c.ellipse(p.x,p.y,s,s*.58,0,0,TAU);c.stroke();}
  c.globalAlpha=1;
  // barras de vida e progresso
  for(const u of M.units){
    if(u.dead||u.inCar)continue;
    if(u.hj>0&&u.fac!=='player'){const p=toScreen(u.x,u.y,1.25);c.strokeStyle='rgba(79,216,255,.9)';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y,8,-Math.PI/2,-Math.PI/2+TAU*Math.min(1,u.hj));c.stroke();}
    if(u.barT>0&&u.kind!=='civil'){const p=toScreen(u.x,u.y,u.fly?1.9:1.18),w=22,f=clamp(u.hp/u.maxHp,0,1);c.fillStyle='rgba(0,0,0,.7)';c.fillRect(p.x-w/2-1,p.y-3,w+2,4);c.fillStyle=f>.5?'#5dffa0':f>.25?'#ffa53d':'#ff4d5e';c.fillRect(p.x-w/2,p.y-2,w*f,2);}
    if(u.hackP>0){const p=toScreen(u.x,u.y,u.fly?1.8:1.1);c.strokeStyle='#4fd8ff';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y,9,-Math.PI/2,-Math.PI/2+TAU*u.hackP);c.stroke();}
  }
  for(const q of M.nades){if(!q.src||q.src.fac==='player')continue;const p=toScreen(q.tx,q.ty),R=SCALE*camS.zoom*WD.granada.raio*.75,k=.6+.4*Math.sin(M.t*18);c.strokeStyle=`rgba(255,77,94,${k})`;c.lineWidth=2;c.setLineDash([6,4]);c.beginPath();c.ellipse(p.x,p.y,R,R*.58,0,0,TAU);c.stroke();c.setLineDash([]);}
  for(const v of M.units){if(v.dead||!v.disguise||!(v.revealP>0))continue;const p=toScreen(v.x,v.y,1.25);c.strokeStyle='rgba(255,165,61,.95)';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y,8,-Math.PI/2,-Math.PI/2+TAU*Math.min(1,v.revealP/1.6));c.stroke();c.fillStyle='#ffa53d';c.font='700 10px "JetBrains Mono",monospace';c.fillText('?',p.x,p.y+3.5);}
  for(const v of M.units){if(v.dead||!(v.hjT>0)||v.fac==='player')continue;const a=M.agents.find(q=>q.probing&&!q.dead&&Math.hypot(q.x-v.x,q.y-v.y)<4);if(!a)continue;const p1=toScreen(a.x,a.y,.95),p2=toScreen(v.x,v.y,.9);c.strokeStyle=`rgba(111,228,255,${.45+Math.random()*.4})`;c.lineWidth=1.5;c.setLineDash([2,3]);c.beginPath();c.moveTo(p1.x,p1.y);c.quadraticCurveTo((p1.x+p2.x)/2,(p1.y+p2.y)/2-14,p2.x,p2.y);c.stroke();c.setLineDash([]);}
  for(const t of M.terms){if(t.done||t.prog<=0)continue;const p=toScreen(t.x,t.y,1.4);c.strokeStyle='#ffa53d';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y,9,-Math.PI/2,-Math.PI/2+TAU*t.prog/4);c.stroke();}
  for(const a of M.agents){
    if(a.dead)continue;const s=a.inCar||a,p=toScreen(s.x,s.y,a.inCar?1.3:1.42);
    const idx=a.inCar?a.inCar.occ.filter(o=>o.kind==='agente').indexOf(a):0,X=p.x+idx*16-(a.inCar?(a.inCar.occ.filter(o=>o.kind==='agente').length-1)*8:0),Y=p.y;
    c.fillStyle=a.sel?'#4fd8ff':'rgba(10,14,22,.85)';c.strokeStyle='#4fd8ff';c.lineWidth=1.4;
    c.beginPath();c.moveTo(X,Y-8);c.lineTo(X+7,Y);c.lineTo(X,Y+8);c.lineTo(X-7,Y);c.closePath();c.fill();c.stroke();
    c.fillStyle=a.sel?'#06101a':'#4fd8ff';c.font='700 10px "JetBrains Mono",monospace';c.fillText(a.num,X,Y+3.5);
    if(a.colapso>0){c.fillStyle='#ff4d5e';c.font='600 9px "JetBrains Mono",monospace';c.fillText('COLAPSO',X,Y-12);}
    else if(a.supp>0){c.fillStyle='#ffa53d';c.font='600 9px "JetBrains Mono",monospace';c.fillText('SUPRIMIDO',X,Y-12);}
    if(a.covered&&!a.inCar){c.fillStyle='rgba(79,216,255,.9)';c.beginPath();c.moveTo(X-16,Y-6);c.lineTo(X-10,Y-6);c.lineTo(X-10,Y+1);c.lineTo(X-13,Y+5);c.lineTo(X-16,Y+1);c.closePath();c.fill();}
  }
  c.font='700 10px "JetBrains Mono",monospace';
  if(M.vip&&!M.vip.dead){const p=toScreen(M.vip.x,M.vip.y,1.45);c.fillStyle='#ffd36b';c.fillText('▼ ALVO',p.x,p.y);}
  for(const u of M.units){if(!u.cand||u.dead||u===M.vip)continue;const p=toScreen(u.x,u.y,1.45);if(u.scanned){c.fillStyle='#8a92a4';c.fillText('▼ SÓSIA',p.x,p.y);}else{c.fillStyle='#ffa53d';c.fillText('▼ ?',p.x,p.y);if(u.scanP>0){c.strokeStyle='#4fd8ff';c.lineWidth=3;c.beginPath();c.arc(p.x,p.y-14,8,-Math.PI/2,-Math.PI/2+TAU*Math.min(1,u.scanP/1.6));c.stroke();}}}
  if(M.sci&&!M.sci.dead&&!M.sci.inCar){const p=toScreen(M.sci.x,M.sci.y,1.45);c.fillStyle='#5dffa0';c.fillText(M.sci.follow?'▼ ESCOLTA':'▼ CIENTISTA',p.x,p.y);}
  for(const e of (M.evacs||(M.evac?[M.evac]:[]))){const p=toScreen(e.x,e.y,.05);c.fillStyle='#5dffa0';c.fillText('EVACUAÇÃO',p.x,p.y+4);}
  for(const u of M.units)if(u.fleeTo&&!u.dead){const p=toScreen(u.x,u.y,1.5);c.fillStyle='#ff4d5e';c.fillText(u.boardT>0?'▼ ENTRANDO NO CARRO':'▼ FUGINDO',p.x,p.y);}
  if(M.boss&&M.boss.shield&&!M.boss.dead)for(const p of M.units){if(!p.pylon||p.dead||p.fac!=='corp')continue;const p1=toScreen(p.x,p.y,1),p2=toScreen(M.boss.x,M.boss.y,.9);c.strokeStyle=`rgba(111,228,255,${.35+Math.random()*.35})`;c.lineWidth=2;c.beginPath();c.moveTo(p1.x,p1.y);c.lineTo(p2.x,p2.y);c.stroke();}
  for(const u of M.units)if(u.rival&&!u.dead){const p=toScreen(u.x,u.y,1.62);c.fillStyle=u.trim;c.fillText('▼ '+u.nome.toUpperCase(),p.x,p.y);}
  if(M.escape&&M.units.some(u=>u.kind==='vip'&&u.fleeing&&!u.dead&&!u.double)){const p=toScreen(M.escape.x,M.escape.y,.05);c.fillStyle='#ff4d5e';c.fillText(M.escapeLabel||'TRANSPORTE DO ALVO',p.x,p.y+4);}
  c.font='700 12px "Chakra Petch",sans-serif';
  const stack=new Map();
  for(const t of M.texts){const k=t.u||t,n=stack.get(k)||0;stack.set(k,n+1);const p=toScreen(t.x,t.y,1.6+(2.4-t.life)*.25);p.y-=n*15;c.globalAlpha=Math.min(1,t.life*2);c.lineWidth=3;c.strokeStyle='rgba(0,0,0,.8)';c.strokeText(t.txt,p.x,p.y);c.fillStyle=t.col;c.fillText(t.txt,p.x,p.y);}
  c.globalAlpha=1;
  if(!M.cine){
    c.lineWidth=1.5;
    for(const a of M.sel){
      if(a.dead)continue;
      const src=a.inCar||a,path=a.inCar?a.inCar.path:a.path,pi=a.inCar?a.inCar.pi:a.pi,o=a.ord;
      if(path&&path.length>pi){
        c.setLineDash([5,5]);c.strokeStyle='rgba(79,216,255,.55)';c.beginPath();let p=toScreen(src.x,src.y,.05);c.moveTo(p.x,p.y);
        for(let i=pi;i<path.length;i++){p=toScreen(path[i].x,path[i].y,.05);c.lineTo(p.x,p.y);}
        c.stroke();c.setLineDash([]);c.fillStyle='rgba(79,216,255,.75)';c.beginPath();c.arc(p.x,p.y,3,0,TAU);c.fill();
      }
      if(o&&o.k==='atk'&&o.t&&!o.t.dead){const tp=o.t.inCar||o.t,p1=toScreen(src.x,src.y,.6),p2=toScreen(tp.x,tp.y,.6);c.setLineDash([3,4]);c.strokeStyle='rgba(255,77,94,.6)';c.beginPath();c.moveTo(p1.x,p1.y);c.lineTo(p2.x,p2.y);c.stroke();}
      if(o&&o.k==='throw'){const p1=toScreen(src.x,src.y,.6),p2=toScreen(o.x,o.y,0);c.setLineDash([3,4]);c.strokeStyle='rgba(255,165,61,.65)';c.beginPath();c.moveTo(p1.x,p1.y);c.quadraticCurveTo((p1.x+p2.x)/2,Math.min(p1.y,p2.y)-60,p2.x,p2.y);c.stroke();}
      c.setLineDash([]);
    }
  }
  if(ui){
    if(ui.drag){c.strokeStyle='#4fd8ff';c.fillStyle='rgba(79,216,255,.08)';c.lineWidth=1;const x=Math.min(ui.sx,ui.x),y=Math.min(ui.sy,ui.y),w=Math.abs(ui.x-ui.sx),h=Math.abs(ui.y-ui.sy);c.fillRect(x,y,w,h);c.strokeRect(x+.5,y+.5,w,h);}
    if(ui.label&&ui.in){c.font='600 12px "JetBrains Mono",monospace';c.textAlign='left';const w=c.measureText(ui.label).width+12;c.fillStyle='rgba(6,8,14,.85)';c.fillRect(ui.x+14,ui.y+12,w,20);c.fillStyle=ui.labelCol||'#d3dcea';c.fillText(ui.label,ui.x+20,ui.y+26);}
  }
  if(M.cine){const h=Math.round(VH*.11);c.fillStyle='#000';c.fillRect(0,0,VW,h);c.fillRect(0,VH-h,VW,h);c.font='600 11px "JetBrains Mono",monospace';c.textAlign='right';c.fillStyle='rgba(255,255,255,.55)';c.fillText('ESPAÇO · pular',VW-20,VH-h/2+4);c.textAlign='left';c.font='700 13px "Chakra Petch",sans-serif';c.fillStyle='#ffa53d';c.fillText((M.scriptDef&&M.scriptDef.nome||'').toUpperCase()+' · '+M.D.nome.toUpperCase(),20,h/2+5);}
  if(M.paused&&!M.ended){c.fillStyle='rgba(10,20,40,.2)';c.fillRect(0,0,VW,VH);}
  if(M.banner){c.font='700 44px "Chakra Petch",sans-serif';c.textAlign='center';c.fillStyle=M.win?'#5dffa0':'#ff4d5e';c.fillText(M.banner,VW/2,VH*.32);}
  else if(M.paused){c.font='700 40px "Chakra Petch",sans-serif';c.textAlign='center';c.fillStyle='#ffa53d';c.fillText('PAUSA TÁTICA',VW/2,VH*.32);}
}

/* ---------- scanner (minimapa) ---------- */
let miniBase=null;
function buildMini(){
  const c=document.createElement('canvas');c.width=c.height=N*4;const g=c.getContext('2d');
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){const t=M.tile[y*N+x];g.fillStyle=t===T_BLD?'#4a5570':t===T_ROAD?'#10131b':t===T_WATER?'#0a1824':t===T_FENCE?'#6a7088':t===T_GLASS?'#5a9ab0':t===T_GRASS||t===T_TREE?'#1b3326':'#262b38';g.fillRect(x*4,y*4,4,4);}
  miniBase=c;
}
let miniT={th:0,k:1,cx:0};
export function drawMini(mc){
  if(!miniBase||!M)return;
  const c=mc.getContext('2d'),W=mc.width,cx=W/2,k=W/(N*4)*.7;
  const a=Math.PI/4+camS.yawA,th=-Math.PI/2-Math.atan2(-Math.sin(a),-Math.cos(a));
  miniT={th,k,cx};
  c.setTransform(1,0,0,1,0,0);c.clearRect(0,0,W,W);
  c.translate(cx,cx);c.rotate(th);c.scale(k,k);c.translate(-N*2,-N*2);
  c.drawImage(miniBase,0,0);
  const dot=(x,y,r,col)=>{c.fillStyle=col;c.fillRect(x*4-r/2,y*4-r/2,r,r);};
  for(const u of M.units){
    if(u.dead||u.inCar)continue;
    if(u.follower)dot(u.x,u.y,5,'#2a9fc0');
    else if(u.kind==='civil')dot(u.x,u.y,4,'#6f7890');
    else if(u.kind==='policia')dot(u.x,u.y,6,M.policeAggro>0?'#7fa8ff':'#4a6aaa');
    else if(u.fac==='corp')dot(u.x,u.y,u.kind==='vip'||u.rival?11:7,u.kind==='vip'?'#ffd36b':u.rival?u.trim:u.alerted?'#ff4d5e':'#a03040');
    else if(u.kind==='cientista')dot(u.x,u.y,10,'#5dffa0');
    else if(u.kind==='torre')dot(u.x,u.y,7,'#4fd8ff');
  }
  for(const cr of M.cars)if(cr.player&&!cr.dead)dot(cr.x,cr.y,9,'#9fe8ff');
  for(const t of M.terms)dot(t.x,t.y,11,t.done?'#5dffa0':'#ffa53d');
  for(const e of (M.evacs||(M.evac?[M.evac]:[])))dot(e.x,e.y,14,'rgba(93,255,160,.6)');
  for(const a of M.agents)if(!a.dead){const p=a.inCar||a;dot(p.x,p.y,10,'#4fd8ff');}
  const cs=[[0,0],[VW,0],[VW,VH],[0,VH]].map(([x,y])=>toWorld(x,y));
  c.strokeStyle='rgba(255,255,255,.6)';c.lineWidth=3;c.beginPath();cs.forEach((p,i)=>i?c.lineTo(p.x*4,p.y*4):c.moveTo(p.x*4,p.y*4));c.closePath();c.stroke();
  c.setTransform(1,0,0,1,0,0);
}
/* converte um clique no scanner (pixels do canvas) em coordenadas do mundo */
export function miniToWorld(px,py){
  const {th,k,cx}=miniT,dx=px-cx,dy=py-cx,cs=Math.cos(-th),sn=Math.sin(-th);
  return {x:((dx*cs-dy*sn)/k+N*2)/4,y:((dx*sn+dy*cs)/k+N*2)/4};
}
