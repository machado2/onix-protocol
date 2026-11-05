"""Patch: texturas PBR (pbr.js) no chão e nas fachadas/telhados dos prédios."""
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

patch(os.path.join(V2, 'js', 'render.js'), 'pbrWall', [
    ("import {assets,makeChar,",
     "import {pbrGround,pbrWall,groundTypeTex,LAYER} from './pbr.js';\nimport {assets,makeChar,"),
    # fachadas: registra as janelas para a máscara e escolhe o material
    ("  const g=c.getContext('2d'),ge=e.getContext('2d');g.scale(2,2);ge.scale(2,2);const rng=RNG(key*991+3),[ct,cl,cr]=BPAL[pal];",
     "  const g=c.getContext('2d',{willReadFrequently:true}),ge=e.getContext('2d');g.scale(2,2);ge.scale(2,2);const rng=RNG(key*991+3),[ct,cl,cr]=BPAL[pal],wins=[];"),
    ("      g.fillStyle=col;g.fillRect(x+10,y+9,12,12);if(lit){",
     "      g.fillStyle=col;g.fillRect(x+10,y+9,12,12);wins.push([x+10,y+9,12,12]);if(lit){"),
    ("    for(const wx of corp?[3]:[4,18]){\n      const ww=corp?26:10;\n",
     "    for(const wx of corp?[3]:[4,18]){\n      const ww=corp?26:10;wins.push([x+wx,y+8,ww,15]);\n"),
    ("  const map=canvasTex(c,true),emi=canvasTex(e,true);",
     "  // alfa do mapa: 1 na parede, 0,5 nas janelas (o shader PBR usa como máscara)\n"
     "  const id=g.getImageData(0,0,c.width,c.height),px=id.data,W=c.width;\n"
     "  for(const [wx,wy,ww,wh] of wins)for(let yy=wy*2;yy<(wy+wh)*2;yy++)for(let xx=wx*2;xx<(wx+ww)*2;xx++)px[(yy*W+xx)*4+3]=128;\n"
     "  g.putImageData(id,0,0);\n"
     "  const map=canvasTex(c,true),emi=canvasTex(e,true);"),
    ("  const side=new THREE.MeshStandardMaterial({map,emissiveMap:emi,emissive:'#ffffff',emissiveIntensity:1.6,roughness:.55,metalness:.25});\n  const roof=new THREE.MeshStandardMaterial({color:ct,roughness:.85,metalness:.1});\n  const fs=side.clone();fs.transparent=true;fs.opacity=.13;fs.depthWrite=false;\n  const fr=roof.clone();fr.transparent=true;fr.opacity=.13;fr.depthWrite=false;\n",
     "  const side=new THREE.MeshStandardMaterial({map,emissiveMap:emi,emissive:'#ffffff',emissiveIntensity:1.6,roughness:.7,metalness:.06});\n  const roof=new THREE.MeshStandardMaterial({color:ct,roughness:.85,metalness:.05});\n  const fs=side.clone();fs.transparent=true;fs.opacity=.13;fs.depthWrite=false;\n  const fr=roof.clone();fr.transparent=true;fr.opacity=.13;fr.depthWrite=false;\n"
     "  const wl=corp?LAYER.panels:pal>=6?[LAYER.plaster,LAYER.bricks,LAYER.corrugated,LAYER.plaster][v%4]:[LAYER.concrete,LAYER.plaster,LAYER.panels,LAYER.bricks,LAYER.panels,LAYER.plaster][pal];\n"
     "  const rl=pal>=6?LAYER.corrugated:LAYER.gravel;\n"
     "  pbrWall(side,wl);pbrWall(fs,wl);pbrWall(roof,rl);pbrWall(fr,rl);\n"),
    # chão
    ("let world=null,ground=null,groundCan=null,gctx=null,groundTex=null,",
     "let groundType=null,world=null,ground=null,groundCan=null,gctx=null,groundTex=null,"),
    ("  if(groundTex)groundTex.dispose();world=null;",
     "  if(groundTex)groundTex.dispose();if(groundType)groundType.dispose();groundType=null;world=null;"),
    ("  const mat=new THREE.MeshStandardMaterial({map:groundTex,roughnessMap:roughTex,roughness:1,metalness:.15,envMapIntensity:1.4});\n",
     "  const mat=new THREE.MeshStandardMaterial({map:groundTex,roughnessMap:roughTex,roughness:1,metalness:.15,envMapIntensity:1.4});\n"
     "  const onPier=(x,y)=>(M.piers||[]).some(p=>x>=p.x0&&x<=p.x1&&y>=p.y0&&y<=p.y1);\n"
     "  groundType=groundTypeTex(N,(x,y)=>{const t=M.tile[y*N+x];if(onPier(x,y))return LAYER.planks+1;\n"
     "    return t===T_ROAD?LAYER.asphalt+1:t===T_WALK||t===T_FENCE||t===T_POST?LAYER.pavers+1:t===T_PLAZA||t===T_GLASS?LAYER.granite+1:t===T_GRASS||t===T_TREE?LAYER.grass+1:0;});\n"
     "  pbrGround(mat,groundType,N);\n"),
])
