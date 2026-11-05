/* Personagens e veículos em 3D: modelos CC0 (Quaternius, Kenney) carregados de models/*.glb.
   Cada personagem vira uma única malha com esqueleto (uma chamada de desenho), recolorida por paleta no shader.
   Se os modelos não carregarem, o renderer continua com os bonecos de blocos. */
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {MeshoptDecoder} from 'three/addons/libs/meshopt_decoder.module.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

export const assets={ready:false,failed:false,chars:{},clips:{},cars:{}};
const HUMAN_H=1.12;     // altura de um personagem comum, em tiles
const CAR_LEN=1.75;     // comprimento de um sedã, em tiles
const MAXSLOT=16;

/* papéis de cada material: qual cor da unidade tinge qual parte do modelo */
const ROLES={
  m_suit:{Suit:'coat',Tie:'trim'},
  f_suit:{Swat_Black:'coat'},
  m_swat:{Swat:'coat',Swat_Black:'legs',Visor:'trim'},
  f_soldier:{Swat:'coat',Swat_Black:'legs'},
  m_space:{SciFi_Main:'coat',SciFi_MainDark:'legs',SciFi_Light_Accent:'trim'},
  f_scifi:{Swat_Black:'coat',Blue:'trim',LightBlue:'trim2'},
  m_punk:{Black:'coat'},
  f_punk:{Swat_Black:'coat',Pink:'trim'},
  m_casual:{White:'coat'},
  m_hoodie:{Purple:'coat'},
  m_worker:{},
  f_casual:{White:'coat'},
  f_formal:{LimeGreen:'coat'},
  f_worker:{},
};
const HAIRMAT=/^(Hair|Hair_Blond|Hair_Black|Eyebrows|Moustache)$/;

function sanitize(n){return n.replace(/\s/g,'_').replace(/[\[\]\.:\/]/g,'');}

/* junta as malhas de um modelo numa geometria só, na pose de repouso, com um atributo de "slot" de material */
function buildTemplate(scene){
  scene.updateMatrixWorld(true);
  const meshes=[];scene.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o);});
  const bones=[];scene.traverse(o=>{if(o.isBone)bones.push(o);});
  const boneIdx=new Map(bones.map((b,i)=>[b.name,i]));
  const boneInverses=bones.map(b=>b.matrixWorld.clone().invert());
  const slots=[],slotIdx=new Map(),base=[];
  const P=[],Nn=[],SI=[],SW=[],SL=[],IDX=[];
  const v=new THREE.Vector3(),n=new THREE.Vector3(),acc=new THREE.Matrix4(),tmp=new THREE.Matrix4(),nm=new THREE.Matrix3();
  for(const mesh of meshes){
    const g=mesh.geometry,sk=mesh.skeleton;
    sk.bones.forEach(b=>b.updateMatrixWorld(true));
    const bm=sk.bones.map((b,i)=>new THREE.Matrix4().multiplyMatrices(b.matrixWorld,sk.boneInverses[i]).multiply(mesh.bindMatrix));
    const remap=sk.bones.map(b=>boneIdx.get(b.name)??0);
    const mat=mesh.material,mname=mat.name||'mat';
    let s=slotIdx.get(mname);if(s===undefined){s=slots.length;slotIdx.set(mname,s);slots.push(mname);base.push(mat.color.clone());}
    const pos=g.attributes.position,nor=g.attributes.normal,si=g.attributes.skinIndex,sw=g.attributes.skinWeight,off=P.length/3;
    for(let i=0;i<pos.count;i++){
      acc.set(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
      const w=[sw.getX(i),sw.getY(i),sw.getZ(i),sw.getW(i)],j=[si.getX(i),si.getY(i),si.getZ(i),si.getW(i)];
      for(let k=0;k<4;k++)if(w[k]>0){tmp.copy(bm[j[k]]);for(let e=0;e<16;e++)acc.elements[e]+=tmp.elements[e]*w[k];}
      v.fromBufferAttribute(pos,i).applyMatrix4(acc);P.push(v.x,v.y,v.z);
      nm.setFromMatrix4(acc);n.fromBufferAttribute(nor,i).applyMatrix3(nm).normalize();Nn.push(n.x,n.y,n.z);
      SI.push(remap[j[0]],remap[j[1]],remap[j[2]],remap[j[3]]);SW.push(w[0],w[1],w[2],w[3]);SL.push(s);
    }
    if(g.index)for(let i=0;i<g.index.count;i++)IDX.push(g.index.getX(i)+off);
    else for(let i=0;i<pos.count;i++)IDX.push(i+off);
  }
  const geo=new THREE.BufferGeometry();
  geo.setAttribute('position',new THREE.Float32BufferAttribute(P,3));
  geo.setAttribute('normal',new THREE.Float32BufferAttribute(Nn,3));
  geo.setAttribute('skinIndex',new THREE.Uint16BufferAttribute(SI,4));
  geo.setAttribute('skinWeight',new THREE.Float32BufferAttribute(SW,4));
  geo.setAttribute('slot',new THREE.Float32BufferAttribute(SL,1));
  geo.setIndex(IDX);geo.userData.shared=true;
  geo.computeBoundingBox();
  const bb=geo.boundingBox,H=bb.max.y-bb.min.y;
  geo.boundingSphere=new THREE.Sphere(new THREE.Vector3(0,H/2,0),H*.75);
  // olhos: ponto mais à frente na faixa da altura dos olhos, para o visor
  const eyeY=bb.max.y-H*.075;let ez=0;
  for(let i=0;i<P.length;i+=3)if(Math.abs(P[i+1]-eyeY)<H*.025&&Math.abs(P[i])<H*.05)ez=Math.max(ez,P[i+2]);
  return {scene,geo,bones:bones.map(b=>b.name),boneInverses,slots,base,H,eye:new THREE.Vector3(0,eyeY,ez||H*.06),meshes};
}

/* material com paleta: cada vértice pega a cor do seu slot */
function palMaterial(pal,cloak){
  const m=cloak?new THREE.MeshStandardMaterial({roughness:.3,metalness:.5,transparent:true,opacity:.18,depthWrite:false,emissive:'#1a6f88'})
               :new THREE.MeshStandardMaterial({roughness:.66,metalness:.08});
  m.onBeforeCompile=s=>{
    s.uniforms.uPal={value:pal};
    s.vertexShader='attribute float slot;\nuniform vec3 uPal['+MAXSLOT+'];\nvarying vec3 vPal;\n'+s.vertexShader.replace('#include <color_vertex>','#include <color_vertex>\nvPal=uPal[int(slot+.5)];');
    s.fragmentShader='varying vec3 vPal;\n'+s.fragmentShader.replace('#include <color_fragment>','#include <color_fragment>\ndiffuseColor.rgb*=vPal;');
  };
  m.customProgramCacheKey=()=>'pal'+(cloak?1:0);
  return m;
}

/* posiciona um objeto (dado no espaço do modelo) preso a um osso, a partir de uma pose de referência */
function boneLocal(T,clipName,boneName,objMatrix){
  const root=SkeletonUtils.clone(T.scene);
  if(clipName&&assets.clips[clipName]){const mx=new THREE.AnimationMixer(root);mx.clipAction(assets.clips[clipName]).play();mx.update(0);}
  root.updateMatrixWorld(true);
  const b=root.getObjectByName(boneName);if(!b)return null;
  return new THREE.Matrix4().copy(b.matrixWorld).invert().multiply(objMatrix);
}

export const loadAssets=(async()=>{
  try{
    const ld=new GLTFLoader();ld.setMeshoptDecoder(MeshoptDecoder);
    // .glb é menor; .json (glTF com dados embutidos) serve onde .glb não é servido
    const get=n=>ld.loadAsync('models/'+n+'.glb').catch(()=>ld.loadAsync('models/'+n+'.json'));
    const [C,A,V]=await Promise.all(['chars','anims','cars'].map(get));
    for(const a of A.animations)assets.clips[a.name]=a;
    for(const s of C.scenes){
      // o carregador numera nomes repetidos entre modelos (Hips_1, Hips_2…); as animações usam o nome original
      s.traverse(o=>{o.name=o.name.replace(/_\d+$/,'');});
      const T=buildTemplate(s);T.key=s.name;T.roles=ROLES[s.name]||{};
      // mão direita segurando a arma, na pose de mira
      const wr=sanitize('Wrist.R');
      T.gripBone=wr;T.headBone='Head';
      const probe=SkeletonUtils.clone(s);const mx=new THREE.AnimationMixer(probe);mx.clipAction(assets.clips.Idle_Gun_Pointing).play();mx.update(0);probe.updateMatrixWorld(true);
      const wb=probe.getObjectByName(wr);
      const grip=new THREE.Matrix4().makeTranslation(new THREE.Vector3().setFromMatrixPosition(wb.matrixWorld));
      T.gunLocal=new THREE.Matrix4().copy(wb.matrixWorld).invert().multiply(grip);
      T.visorLocal=boneLocal(T,null,'Head',new THREE.Matrix4().makeTranslation(T.eye.x,T.eye.y,T.eye.z+T.H*.01));
      assets.chars[s.name]=T;
    }
    for(const s of V.scenes){
      s.updateMatrixWorld(true);
      const bb=new THREE.Box3().setFromObject(s),sz=bb.getSize(new THREE.Vector3());
      const wheels=[];s.traverse(o=>{if(/wheel/i.test(o.name)&&!o.isMesh)wheels.push(o.name);});
      s.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;o.geometry.userData.shared=true;(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>m.userData.shared=true);}});
      assets.cars[s.name]={scene:s,size:sz,center:bb.getCenter(new THREE.Vector3()),minY:bb.min.y,wheels,alongZ:sz.z>=sz.x};
    }
    assets.ready=true;
  }catch(e){console.warn('modelos 3D indisponíveis, usando bonecos de blocos',e);assets.failed=true;assets.err=String(e&&e.stack||e);}
})();

/* ---------- escolha de modelo e cores por unidade ---------- */
const hash=n=>{n=(n^61)^(n>>>16);n=n+(n<<3);n=n^(n>>>4);n=Math.imul(n,0x27d4eb2d);return (n^(n>>>15))>>>0;};
const CIVM=['m_casual','m_hoodie','m_worker','m_punk','m_suit','m_casual','m_hoodie'];
const CIVF=['f_casual','f_formal','f_punk','f_worker','f_suit','f_casual','f_formal'];
const RIVM={navalha:'m_punk',sibila:'f_scifi',ferro:'m_swat',mariposa:'f_punk',juiz:'m_suit'};
const isFemName=n=>/^(Dra\.|Executiva|Diretora|Senadora)/.test(n||'');
export function modelFor(u){
  const h=hash(u.id*7+3);
  if(u.kind==='agente')return u.voz==='f'?'f_scifi':'m_space';
  if(u.rival)return RIVM[u.rival]||'m_suit';
  if(u.disguise||u.kind==='civil')return (h&1?CIVF:CIVM)[(h>>>1)%7];
  if(u.kind==='inimigo')return u.heavy?'m_swat':(h%3===0?'f_suit':'m_suit');
  if(u.kind==='guarda'||u.kind==='policia')return h%3===0?'f_soldier':'m_swat';
  if(u.kind==='vip')return isFemName(u.nome)?'f_suit':'m_suit';
  if(u.kind==='cientista')return isFemName(u.nome)?'f_formal':'m_casual';
  return 'm_casual';
}
const tint=(c,k)=>new THREE.Color(c).multiplyScalar(k);
function palette(T,u,key){
  const pal=[];for(let i=0;i<MAXSLOT;i++)pal.push(new THREE.Color(1,1,1));
  const civ=u.kind==='civil'||u.disguise;
  T.slots.forEach((name,i)=>{
    const role=T.roles[name];let c=T.base[i].clone();
    if(name==='Skin'||name==='Skin_Darker')c=new THREE.Color(u.skin).multiplyScalar(name==='Skin'?.62:.5);
    else if(HAIRMAT.test(name)&&u.hair&&key!=='m_space')c=new THREE.Color(u.hair).multiplyScalar(.7);
    else if(role==='coat'&&u.coat&&(!civ||(hash(u.id)&3)!==0))c=tint(u.coat,civ?.75:.55);
    else if(role==='legs'&&u.legs&&!civ)c=tint(u.legs,.9);
    else if((role==='trim'||role==='trim2')&&u.trim&&!civ)c=tint(u.trim,role==='trim2'?.35:.5);
    if(u.kind==='cientista'&&role==='coat')c=new THREE.Color('#d8dee6').multiplyScalar(.7);
    pal[i].copy(c);
  });
  return pal;
}

/* ---------- instância de personagem ---------- */
export function makeChar(u,scale){
  const key=modelFor(u),T=assets.chars[key];if(!T)return null;
  const root=SkeletonUtils.clone(T.scene);
  const old=[];root.traverse(o=>{if(o.isMesh)old.push(o);});for(const o of old)o.parent.remove(o);
  const bones=T.bones.map(n=>root.getObjectByName(n));
  const skel=new THREE.Skeleton(bones,T.boneInverses);
  const pal=palette(T,u,key),mat=palMaterial(pal,false);
  const mesh=new THREE.SkinnedMesh(T.geo,mat);mesh.castShadow=true;mesh.receiveShadow=true;
  mesh.bind(skel,new THREE.Matrix4());
  root.add(mesh);
  const s=HUMAN_H/T.H*(scale||1);root.scale.setScalar(s);
  const mixer=new THREE.AnimationMixer(root);
  return {key,T,root,mesh,mat,pal,mixer,cur:null,act:null,s,grip:root.getObjectByName(T.gripBone),head:root.getObjectByName(T.headBone)};
}
export function cloakChar(C,on){
  if(on){if(!C.cmat)C.cmat=palMaterial(C.pal,true);C.mesh.material=C.cmat;}else C.mesh.material=C.mat;
}
/* objeto preso ao osso, em unidades de tile */
export function attach(C,which,obj){
  const bone=which==='gun'?C.grip:C.head,L=which==='gun'?C.T.gunLocal:C.T.visorLocal;if(!bone||!L)return;
  const g=new THREE.Group();g.matrixAutoUpdate=false;g.matrix.copy(L);
  obj.scale.setScalar(1/C.s);g.add(obj);bone.add(g);
}
const ONCE=new Set(['Death','HitRecieve','Gun_Shoot','Punch_Right']);
export function play(C,name,ts=1,fade=.18){
  const clip=assets.clips[name];if(!clip)return;
  if(C.cur===name){if(C.act)C.act.timeScale=ts;return;}
  const a=C.mixer.clipAction(clip);
  a.reset();a.timeScale=ts;
  if(ONCE.has(name)){a.setLoop(THREE.LoopOnce,1);a.clampWhenFinished=true;}
  a.enabled=true;a.setEffectiveWeight(1);
  if(C.act&&fade>0){a.crossFadeFrom(C.act,fade,false);}else if(C.act)C.act.stop();
  a.play();C.act=a;C.cur=name;
}

/* ---------- veículos ---------- */
const CARMAP={'#e0a020':'taxi','#2c2f36':'suv-luxury','#8a1f2e':'sedan-sports','#1f4f8a':'sedan','#c9c2b0':'van','#3c6e5a':'suv','#d8d8dc':'hatchback-sports'};
const CARPOOL=['sedan','suv','hatchback-sports','truck','delivery','sedan-sports'];
export function makeCarModel(c){
  if(!assets.ready)return null;
  let key=c.limo?'suv-luxury':CARMAP[c.col];
  if(!key){let h=0;for(const ch of String(c.col))h=(h*31+ch.charCodeAt(0))>>>0;key=CARPOOL[h%CARPOOL.length];}
  const A=assets.cars[key]||assets.cars.sedan,ref=assets.cars.sedan;
  const s=CAR_LEN/(ref.alongZ?ref.size.z:ref.size.x);
  const inner=A.scene.clone(true);
  inner.position.set(-A.center.x,-A.minY,-A.center.z);
  const holder=new THREE.Group();holder.add(inner);holder.scale.setScalar(s);
  if(A.alongZ)holder.rotation.y=Math.PI/2;   // frente do modelo (+Z) para +X, que é a frente no jogo
  const wheels=A.wheels.map(n=>inner.getObjectByName(n)).filter(Boolean);
  return {holder,inner,wheels,len:(A.alongZ?A.size.z:A.size.x)*s,wid:(A.alongZ?A.size.x:A.size.z)*s,ht:A.size.y*s};
}

/* ---------- recorte por câmera: só anima quem aparece na tela ---------- */
const frus=new THREE.Frustum(),pm=new THREE.Matrix4(),sph=new THREE.Sphere(new THREE.Vector3(),1.4);
export function cullBegin(camera){camera.updateMatrixWorld();pm.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);frus.setFromProjectionMatrix(pm);}
export function onScreen(x,y){sph.center.set(x,.6,y);return frus.intersectsSphere(sph);}
