/* Objetos de cenário em 3D (CC0: Kenney e Quaternius Cyberpunk Game Kit), carregados de models/props.glb.
   Cada objeto vira uma lista de peças (geometria + material) já na escala do jogo, com a base no chão e a frente em +X.
   Objetos repetidos (árvores, postes, semáforos) são desenhados por instância. */
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {MeshoptDecoder} from 'three/addons/libs/meshopt_decoder.module.js';

export const props={ready:false,defs:{}};
const darkened=new Set();
/* altura no jogo (tiles) e giro para a frente ficar em +X */
const SPEC={
  tree_a:{h:2.2,dark:.42},tree_b:{h:1.8,dark:.42},tree_c:{h:2,dark:.42},tree_d:{h:1.75,dark:.42},bush:{h:.5,dark:.5},
  lamp_c:{h:2.45,rot:Math.PI/2,pivot:true},traffic:{h:2.1,rot:Math.PI/2},sign_stop:{h:1.6,rot:Math.PI/2},sign_warn:{h:1.6,rot:Math.PI/2},
  cone:{h:.32},cbarrier:{h:.5},dumpster:{h:.75},barrel:{h:.5},box:{h:.4},box_large:{h:.4},
  ac:{h:.42},ac_side:{h:.3,rot:Math.PI/2},ac_stack:{h:.6},antenna_a:{h:1.5},antenna_b:{h:.55},
  computer:{h:.95},computer_l:{h:1.6},tv_a:{h:.9},tv_b:{h:.8},planter:{h:.35},parasol:{h:1.5},
};

/* os atributos vêm quantizados (inteiros normalizados); passa para float antes de transformar */
function toFloat(g){
  for(const k of Object.keys(g.attributes)){
    const a=g.attributes[k];if(a.array instanceof Float32Array&&!a.isInterleavedBufferAttribute)continue;
    const n=a.count,w=a.itemSize,arr=new Float32Array(n*w);
    for(let i=0;i<n;i++)for(let j=0;j<w;j++)arr[i*w+j]=a.getComponent?a.getComponent(i,j):[a.getX(i),a.getY(i),a.getZ(i),a.getW(i)][j];
    g.setAttribute(k,new THREE.BufferAttribute(arr,w));
  }
  return g;
}
function prepare(scene,spec){
  const root=new THREE.Group();root.add(scene);
  if(spec.rot)scene.rotation.y=spec.rot;
  root.updateMatrixWorld(true);
  const bb=new THREE.Box3().setFromObject(root),s=spec.h/(bb.max.y-bb.min.y);
  const c=bb.getCenter(new THREE.Vector3());
  // pivot: mantém a origem do modelo (o pé do poste) em vez de centralizar
  const fix=new THREE.Matrix4().makeScale(s,s,s).multiply(new THREE.Matrix4().makeTranslation(spec.pivot?0:-c.x,-bb.min.y,spec.pivot?0:-c.z));
  const parts=[];let light=null;
  root.traverse(o=>{
    if(!o.isMesh)return;
    const g=toFloat(o.geometry.clone()).applyMatrix4(new THREE.Matrix4().multiplyMatrices(fix,o.matrixWorld));
    g.computeBoundingBox();g.computeBoundingSphere();g.userData.shared=true;
    const mats=(Array.isArray(o.material)?o.material:[o.material]);
    mats.forEach(m=>{m.userData.shared=true;if(m.map)m.map.anisotropy=4;if(spec.dark&&!darkened.has(m)){darkened.add(m);m.color.multiplyScalar(spec.dark);m.color.offsetHSL(/leaf/i.test(m.name)?-.1:0,-.12,0);}});
    if(mats.some(m=>/light/i.test(m.name||'')))light=g.boundingBox.getCenter(new THREE.Vector3());
    parts.push({geo:g,mat:o.material});
  });
  const box=new THREE.Box3();parts.forEach(p=>box.union(p.geo.boundingBox));
  return {parts,box,light};
}

export const loadProps=(async()=>{
  try{
    const ld=new GLTFLoader();ld.setMeshoptDecoder(MeshoptDecoder);
    const P=await ld.loadAsync('models/props.glb').catch(()=>ld.loadAsync('models/props.json'));
    for(const s of P.scenes){const spec=SPEC[s.name];if(spec)props.defs[s.name]=prepare(s,spec);}
    props.ready=true;
  }catch(e){console.warn('objetos 3D indisponíveis',e);}
})();

/* um objeto avulso (Group de Meshes); tint multiplica a cor dos materiais (clonados) */
export function propMesh(name,tint){
  const D=props.defs[name];if(!D)return null;
  const g=new THREE.Group();
  for(const p of D.parts){
    let mat=p.mat;
    if(tint){mat=(Array.isArray(mat)?mat:[mat]).map(m=>{const c=m.clone();c.color.multiply(new THREE.Color(tint));c.userData.shared=false;return c;});if(mat.length===1)mat=mat[0];}
    const m=new THREE.Mesh(p.geo,mat);m.castShadow=true;m.receiveShadow=true;g.add(m);
  }
  return g;
}
/* várias cópias de um objeto: uma InstancedMesh por peça; mats é uma lista de Matrix4 */
export function propInstances(name,mats){
  const D=props.defs[name];if(!D||!mats.length)return [];
  return D.parts.map(p=>{
    const im=new THREE.InstancedMesh(p.geo,p.mat,mats.length);
    mats.forEach((m,i)=>im.setMatrixAt(i,m));im.castShadow=true;im.receiveShadow=true;im.computeBoundingSphere();
    return im;
  });
}
export const propDef=name=>props.defs[name]||null;
