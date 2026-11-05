"""Patch: gráfico moderno — resolução nativa, MSAA, ACES, sombras suaves, GTAO, reflexos de ambiente, materiais PBR, texturas nítidas.
Substitui o ajuste de pixelização por um ajuste de qualidade (Alta/Média/Baixa)."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, 'v2')

def patch(path, marker, reps):
    s = open(path, encoding='utf-8').read()
    if marker in s:
        print('já aplicado:', os.path.basename(path)); return
    for a, b in reps:
        if a not in s:
            sys.exit(f'{path}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8').write(s)
    print('ok:', os.path.basename(path))

patch(os.path.join(ROOT, 'tools', 'build_index.py'), 'touch-action:none}\\n#ov', [
    ("touch-action:none;image-rendering:pixelated;image-rendering:crisp-edges}\\n#ov", "touch-action:none}\\n#ov"),
])

patch(os.path.join(V2, 'js', 'core.js'), 'settings={q:1,', [
    ("export const settings={pix:2,", "export const settings={q:1,pix:2,"),
    ("try{Object.assign(settings,JSON.parse(localStorage.getItem('onix-gfx')||'{}'));}catch(e){}",
     "try{Object.assign(settings,JSON.parse(localStorage.getItem('onix-gfx')||'{}'));}catch(e){}\nif(!(settings.q>0))settings.q=1;"),
])

ENV = r"""
/* ambiente para reflexos: noite urbana com placas de neon */
function buildEnv(){
  const es=new THREE.Scene();es.background=new THREE.Color('#05070d');
  const add=(col,int,x,y,z,w,h)=>{const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({color:new THREE.Color(col).multiplyScalar(int),side:THREE.DoubleSide}));m.position.set(x,y,z);m.lookAt(0,0,0);es.add(m);};
  add('#3a4a78',1,0,30,0,60,60);add('#ff6ad5',2.2,22,6,-10,8,3);add('#4fd8ff',2.2,-20,5,14,10,3);add('#ffb35c',2.5,10,4,22,12,2);add('#a66bff',1.6,-18,8,-18,6,6);add('#1a2236',1,0,-10,0,80,80);
  const pm=new THREE.PMREMGenerator(renderer);const rt=pm.fromScene(es,.04);pm.dispose();return rt.texture;
}
scene.environment=buildEnv();
"""

patch(os.path.join(V2, 'js', 'render.js'), 'GTAOPass', [
    ("import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';",
     "import {OutputPass} from 'three/addons/postprocessing/OutputPass.js';\nimport {GTAOPass} from 'three/addons/postprocessing/GTAOPass.js';"),
    ("renderer.shadowMap.enabled=settings.shadows;renderer.shadowMap.type=THREE.PCFShadowMap;",
     "renderer.shadowMap.enabled=settings.shadows;renderer.shadowMap.type=THREE.PCFSoftShadowMap;\nrenderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.35;"),
    ("moon.shadow.mapSize.set(2048,2048);", "moon.shadow.mapSize.set(4096,4096);moon.shadow.radius=3;"),
    ("scene.add(moon,moon.target);", "scene.add(moon,moon.target);" + ENV),
    ("const composer=new EffectComposer(renderer);\ncomposer.addPass(new RenderPass(scene,camera));",
     "const composer=new EffectComposer(renderer,new THREE.WebGLRenderTarget(1,1,{type:THREE.HalfFloatType,samples:4}));\ncomposer.addPass(new RenderPass(scene,camera));\n"
     "const gtao=new GTAOPass(scene,camera,256,256);gtao.blendIntensity=.85;gtao.updateGtaoMaterial({radius:.9,distanceExponent:1.4,thickness:1.2,scale:1,samples:12});composer.addPass(gtao);\n"
     "export let PR=1;"),
    ("  VW=innerWidth;VH=innerHeight;const pr=1/settings.pix;",
     "  VW=innerWidth;VH=innerHeight;const pr=PR=Math.min(window.devicePixelRatio||1,2)*(settings.q||1);gtao.enabled=(settings.q||1)>=1;"),
    ("  composer.setPixelRatio(pr);composer.setSize(VW,VH);", "  composer.setPixelRatio(pr);composer.setSize(VW,VH);gtao.setSize(Math.round(VW*pr),Math.round(VH*pr));"),
    ("function lam(col){let m=matCache.get('l'+col);if(!m){m=new THREE.MeshLambertMaterial({color:col});",
     "function lam(col){let m=matCache.get('l'+col);if(!m){m=new THREE.MeshStandardMaterial({color:col,roughness:.78,metalness:.06});"),
    ("const vcMat=new THREE.MeshLambertMaterial({vertexColors:true});", "const vcMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.62,metalness:.12});"),
    ("const cloakMat=new THREE.MeshLambertMaterial({vertexColors:true,", "const cloakMat=new THREE.MeshStandardMaterial({vertexColors:true,roughness:.3,metalness:.5,"),
    ("const wreckMat=new THREE.MeshLambertMaterial({vertexColors:true,color:'#2a2a2a'});", "const wreckMat=new THREE.MeshStandardMaterial({vertexColors:true,color:'#2a2a2a',roughness:.9});"),
    ("function canvasTex(c,nearest){const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;if(nearest){t.magFilter=THREE.NearestFilter;}t.anisotropy=4;return t;}",
     "function canvasTex(c){const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=8;return t;}"),
    ("  const S=32,c=document.createElement('canvas'),e=document.createElement('canvas');c.width=e.width=c.height=e.height=S*8;\n  const g=c.getContext('2d'),ge=e.getContext('2d'),",
     "  const S=32,c=document.createElement('canvas'),e=document.createElement('canvas');c.width=e.width=c.height=e.height=S*16;\n  const g=c.getContext('2d'),ge=e.getContext('2d');g.scale(2,2);ge.scale(2,2);const "),
    ("  const side=new THREE.MeshLambertMaterial({map,emissiveMap:emi,emissive:'#ffffff',emissiveIntensity:1.25});\n  const roof=new THREE.MeshLambertMaterial({color:ct});",
     "  const side=new THREE.MeshStandardMaterial({map,emissiveMap:emi,emissive:'#ffffff',emissiveIntensity:1.6,roughness:.55,metalness:.25});\n  const roof=new THREE.MeshStandardMaterial({color:ct,roughness:.85,metalness:.1});"),
    ("const TS=32;", "const TS=48;"),
    ("  const mat=new THREE.MeshPhongMaterial({map:groundTex,specularMap:specTex,specular:'#8a95b8',shininess:60});",
     "  const rc=document.createElement('canvas');rc.width=spec.width;rc.height=spec.height;const rg=rc.getContext('2d');rg.fillStyle='#fff';rg.fillRect(0,0,rc.width,rc.height);rg.globalCompositeOperation='difference';rg.drawImage(spec,0,0);\n"
     "  const roughTex=new THREE.CanvasTexture(rc);\n"
     "  const mat=new THREE.MeshStandardMaterial({map:groundTex,roughnessMap:roughTex,roughness:1,metalness:.15,envMapIntensity:1.4});"),
    ("  const px=SCALE*camS.zoom/settings.pix;", "  const px=SCALE*camS.zoom*PR;"),
])

patch(os.path.join(V2, 'js', 'ui.js'), 'id="gQ"', [
    ('<label>Pixels <select id="gPix"><option value="1">1× nítido</option><option value="2">2× retrô</option><option value="3">3× chunky</option></select></label>',
     '<label>Qualidade <select id="gQ"><option value="1">Alta</option><option value="0.75">Média</option><option value="0.55">Baixa</option></select></label>'),
    ("  $('#gPix').value=String(settings.pix);", "  $('#gQ').value=String(settings.q||1);"),
    ("  $('#gPix').onchange=e=>{settings.pix=+e.target.value;saveSettings();applyGfx();};", "  $('#gQ').onchange=e=>{settings.q=+e.target.value;saveSettings();applyGfx();};"),
    ("2× retrô é o visual pensado para o jogo. Desligue sombras e brilho em computadores mais fracos.",
     "Alta usa resolução máxima e oclusão de ambiente. Em computadores mais fracos, use Média ou Baixa e desligue as sombras."),
])

patch(os.path.join(V2, 'js', 'en.js'), "'Qualidade':'Quality'", [
    ("  'Brilho neon':'Neon glow',",
     "  'Qualidade':'Quality','Alta':'High','Média':'Medium','Baixa':'Low',\n  'Alta usa resolução máxima e oclusão de ambiente. Em computadores mais fracos, use Média ou Baixa e desligue as sombras.':'High uses full resolution and ambient occlusion. On weaker computers, use Medium or Low and turn shadows off.',\n  'Brilho neon':'Neon glow',"),
])
