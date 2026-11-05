/* Texturas PBR (CC0, Poly Haven) aplicadas por posição no mundo: cor, relevo (normal) e rugosidade.
   O chão escolhe o material pelo tipo de tile; os prédios pelo estilo da fachada. As janelas ficam lisas e refletem o ambiente.
   Enquanto as texturas não carregam (ou se falharem), os shaders ignoram o detalhe. */
import * as THREE from 'three';

export const LAYER={asphalt:0,pavers:1,granite:2,grass:3,planks:4,concrete:5,panels:6,bricks:7,plaster:8,corrugated:9,gravel:10};
const NL=11;
const blank=()=>{const t=new THREE.DataArrayTexture(new Uint8Array([128,128,255,255]),1,1,1);t.needsUpdate=true;return t;};
export const U={
  tPbrAlb:{value:blank()},tPbrNrm:{value:blank()},uPbr:{value:0},
  uPbrScale:{value:new Array(NL).fill(.6)},uPbrLum:{value:new Array(NL).fill(.15)},
  uPbrK:{value:1.15},uPbrNs:{value:1.1},
};

function arrayTex(img,S,n,srgb){
  const c=document.createElement('canvas');c.width=S;c.height=S*n;const g=c.getContext('2d',{willReadFrequently:true});g.drawImage(img,0,0);
  const t=new THREE.DataArrayTexture(new Uint8Array(g.getImageData(0,0,S,S*n).data.buffer),S,S,n);
  t.format=THREE.RGBAFormat;t.type=THREE.UnsignedByteType;t.wrapS=t.wrapT=THREE.RepeatWrapping;
  t.magFilter=THREE.LinearFilter;t.minFilter=THREE.LinearMipmapLinearFilter;t.generateMipmaps=true;t.anisotropy=8;
  if(srgb)t.colorSpace=THREE.SRGBColorSpace;t.needsUpdate=true;return t;
}
const loadImg=src=>new Promise((ok,err)=>{const i=new Image();i.onload=()=>ok(i);i.onerror=err;i.src=src;});
export const loadPbr=(async()=>{
  try{
    const meta=await (await fetch('tex/pbr.json')).json();
    const [a,n]=await Promise.all([loadImg('tex/pbr_alb.jpg'),loadImg('tex/pbr_nrm.jpg')]);
    const S=meta.size,L=meta.layers.length;
    U.tPbrAlb.value=arrayTex(a,S,L,true);U.tPbrNrm.value=arrayTex(n,S,L,false);
    U.uPbrScale.value=meta.layers.map(l=>l.scale);U.uPbrLum.value=meta.layers.map(l=>l.lum);
    U.uPbr.value=1;
  }catch(e){console.warn('texturas PBR indisponíveis',e);}
})();

const VDECL='varying vec3 vPbrWP;\nvarying vec3 vPbrWN;\n';
const VBODY='#include <begin_vertex>\nvPbrWP=(modelMatrix*vec4(transformed,1.)).xyz;vPbrWN=normalize(mat3(modelMatrix)*objectNormal);\n';
const FDECL=`uniform highp sampler2DArray tPbrAlb;
uniform highp sampler2DArray tPbrNrm;
uniform float uPbr,uPbrK,uPbrNs,uPbrMatK,uPbrGain;
uniform float uPbrScale[${NL}];
uniform float uPbrLum[${NL}];
varying vec3 vPbrWP;
varying vec3 vPbrWN;
`;
// aplica a camada L com coordenadas uv e o referencial (T,B,N) em espaço de mundo; k = intensidade (0 nas janelas)
const FAPPLY=`
  if(pbrL>=0.){
    int li=int(pbrL+.5);vec2 puv=pbrUV*uPbrScale[li];
    vec4 pa=texture(tPbrAlb,vec3(puv,pbrL)),pn=texture(tPbrNrm,vec3(puv,pbrL));
    diffuseColor.rgb*=max(mix(vec3(1.),pa.rgb/max(uPbrLum[li],.02),uPbrK*uPbrMatK*pbrK),0.);
    pbrRough=pn.b;pbrNxy=(pn.rg*2.-1.)*uPbrNs*uPbrMatK*pbrK;
  }
`;
function common(s){
  Object.assign(s.uniforms,U);
  s.vertexShader=VDECL+s.vertexShader.replace('#include <begin_vertex>',VBODY);
  s.fragmentShader=FDECL+s.fragmentShader;
}
function normalAndRough(s,roughExpr){
  s.fragmentShader=s.fragmentShader
    .replace('#include <roughnessmap_fragment>','#include <roughnessmap_fragment>\n'+roughExpr)
    .replace('#include <normal_fragment_maps>',`#include <normal_fragment_maps>
  if(pbrL>=0.&&dot(pbrNxy,pbrNxy)>0.){vec3 nW=normalize(pbrT*pbrNxy.x+pbrB*pbrNxy.y+pbrWN*sqrt(max(0.,1.-dot(pbrNxy,pbrNxy))));normal=normalize((viewMatrix*vec4(nW,0.)).xyz);}
`);
}

/* chão: tipo de material por tile numa textura N×N (0 = sem detalhe, k = camada k-1) */
export function groundTypeTex(N,typeAt){
  const d=new Uint8Array(N*N);for(let y=0;y<N;y++)for(let x=0;x<N;x++)d[y*N+x]=typeAt(x,y);
  const t=new THREE.DataTexture(d,N,N,THREE.RedFormat,THREE.UnsignedByteType);t.magFilter=t.minFilter=THREE.NearestFilter;t.needsUpdate=true;return t;
}
export function pbrGround(mat,typeTex,N){
  mat.onBeforeCompile=s=>{
    common(s);s.uniforms.uPbrMatK={value:1};s.uniforms.uPbrGain={value:1};s.uniforms.tPbrType={value:typeTex};s.uniforms.uPbrN={value:N};
    s.fragmentShader='uniform sampler2D tPbrType;\nuniform float uPbrN;\n'+s.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
  float pbrL=-1.,pbrK=1.,pbrRough=1.;vec2 pbrNxy=vec2(0.),pbrUV=vPbrWP.xz;vec3 pbrT=vec3(1.,0.,0.),pbrB=vec3(0.,0.,1.),pbrWN=vec3(0.,1.,0.);
  if(uPbr>.5)pbrL=floor(texture2D(tPbrType,vPbrWP.xz/uPbrN).r*255.+.5)-1.;
  ${FAPPLY}`);
    normalAndRough(s,'if(pbrL>=0.)roughnessFactor=clamp(roughnessFactor*pbrRough*1.3,.04,1.);');
  };
  mat.customProgramCacheKey=()=>'pbrground';
}

/* fachada: a camada vem do material; o alfa do mapa marca a parede (1) e as janelas (0,5) */
export function pbrWall(mat,layer,k=1,gain=1.45){
  mat.onBeforeCompile=s=>{
    common(s);s.uniforms.uPbrLayer={value:layer};s.uniforms.uPbrMatK={value:k};s.uniforms.uPbrGain={value:gain};
    s.fragmentShader='uniform float uPbrLayer;\n'+s.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
  float pbrK=1.;
  #ifdef USE_MAP
  pbrK=step(.75,sampledDiffuseColor.a);diffuseColor.a=opacity;
  #endif
  float pbrL=uPbr>.5?uPbrLayer:-1.,pbrRough=1.;vec2 pbrNxy=vec2(0.),pbrUV;vec3 pbrT,pbrB,pbrWN=normalize(vPbrWN);
  if(abs(pbrWN.y)>.5){pbrUV=vPbrWP.xz;pbrT=vec3(1.,0.,0.);pbrB=vec3(0.,0.,-1.);}
  else if(abs(pbrWN.x)>.5){float sg=sign(pbrWN.x);pbrUV=vec2(-vPbrWP.z*sg,vPbrWP.y);pbrT=vec3(0.,0.,-sg);pbrB=vec3(0.,1.,0.);}
  else{float sg=sign(pbrWN.z);pbrUV=vec2(vPbrWP.x*sg,vPbrWP.y);pbrT=vec3(sg,0.,0.);pbrB=vec3(0.,1.,0.);}
  ${FAPPLY}
  if(pbrL>=0.)diffuseColor.rgb*=mix(1.,uPbrGain,pbrK);`)
      .replace('#include <metalnessmap_fragment>','#include <metalnessmap_fragment>\nmetalnessFactor=mix(.6,metalnessFactor,pbrK);');
    normalAndRough(s,'if(pbrL>=0.)roughnessFactor=mix(.07,clamp(pbrRough*1.1,.25,1.),pbrK);');
  };
  mat.customProgramCacheKey=()=>'pbrwall';
}
