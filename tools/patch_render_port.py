"""Patch único: elementos 3D do porto no renderizador (registro da mudança)."""
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

PORT = r"""
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
  if(b.style==='cont'){
    const col=CONT_COLS[b.col%CONT_COLS.length],H=b.fl*.52;
    for(let k=0;k<b.fl;k++){
      const c=k===0?col:CONT_COLS[(b.col+k*2)%CONT_COLS.length];
      const geo=new THREE.BoxGeometry(b.w-.08,.5,b.d-.08);scaleUV(geo,b.w,.5,b.d);
      const m=new THREE.Mesh(geo,corrMat(c));m.position.set(b.x+b.w/2,.25+k*.52,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);
    }
    return;
  }
  if(b.style==='ware'){
    const H=b.fl*FLOOR,geo=new THREE.BoxGeometry(b.w,H,b.d);scaleUV(geo,b.w,H,b.d);
    const wall=corrMat('#4a5058'),roof=lam('#2c3036');
    const m=new THREE.Mesh(geo,[wall,wall,roof,roof,wall,wall]);m.position.set(b.x+b.w/2,H/2,b.y+b.d/2);m.castShadow=m.receiveShadow=true;world.add(m);
    m.userData={mats:{norm:m.material,fade:[wall,wall,roof,roof,wall,wall].map(x=>{const f=x.clone();f.transparent=true;f.opacity=.13;f.depthWrite=false;return f;})},fade:false,extra:[]};
    bldMeshes.push(m);
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
  const c=document.createElement('canvas');c.width=c.height=256;const g=c.getContext('2d');
  for(let k=0;k<160;k++){const x=Math.random()*256,y=Math.random()*256,w=6+Math.random()*26;g.fillStyle=`rgba(${150+Math.random()*80},${190+Math.random()*50},255,${.15+Math.random()*.35})`;g.fillRect(x,y,w,1.5);}
  const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;
  waterMesh=new THREE.Mesh(geo,new THREE.MeshBasicMaterial({map:t,transparent:true,opacity:.55,blending:THREE.AdditiveBlending,depthWrite:false,toneMapped:false}));
  world.add(waterMesh);
  for(const p of M.piers){
    const w=p.x1-p.x0+1,d=p.y1-p.y0+1;
    for(let k=0;k<4;k++){const post=new THREE.Mesh(new THREE.CylinderGeometry(.09,.09,.7,6),lam('#2a1e16'));post.position.set(k<2?p.x0+.1:p.x1+.9,-.2,p.y0+.2+(k%2)*(d-.4));world.add(post);}
    const edge=new THREE.Mesh(new THREE.BoxGeometry(w,.08,d),lam('#3c2c20'));edge.position.set(p.x0+w/2,-.03,p.y0+d/2);world.add(edge);
  }
}
const chainTex=(()=>{const c=document.createElement('canvas');c.width=c.height=64;const g=c.getContext('2d');g.strokeStyle='rgba(170,180,195,.9)';g.lineWidth=1.4;for(let i=-64;i<128;i+=8){g.beginPath();g.moveTo(i,0);g.lineTo(i+64,64);g.stroke();g.beginPath();g.moveTo(i+64,0);g.lineTo(i,64);g.stroke();}g.fillStyle='rgba(170,180,195,1)';g.fillRect(0,0,64,3);const t=new THREE.CanvasTexture(c);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(1,1);return t;})();
function buildFence(){
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
    }else if(d.type==='van'){
      const body=new THREE.Mesh(mergeGeometries([box(1.9,.85,.9,0,.55,0,'#22262e'),box(1.92,.12,.92,0,.12,0,'#111318'),box(.5,.4,.8,.72,.7,0,'#1a2433'),box(1.2,.05,.02,-.2,.6,.46,'#4fd8ff')]),vcMat);
      body.castShadow=true;g.add(body);g.position.set(d.x,0,d.y);g.rotation.y=-(d.ang||0);
    }
    decorObjs.push(o);
  }
}
function syncDecor(dt){
  if(waterMesh){waterMesh.material.map.offset.x+=dt*.015;waterMesh.material.map.offset.y+=dt*.006;}
  for(const o of decorObjs){
    if(o.bob){o.g.position.y=Math.sin(M.t*1.3)*.05-.05;o.g.rotation.z=Math.sin(M.t*.9)*.03;}
    if(o.arm){const tgt=M.flags&&M.flags.gate?1.35:0;o.arm.rotation.z+=(tgt-o.arm.rotation.z)*Math.min(1,dt*3);}
    if(o.hang){o.hang.visible=o.cable.visible=!(M.flags&&M.flags.dropped);if(o.hang.visible)o.hang.rotation.y=Math.sin(M.t*.7)*.04;}
  }
  if(M.falling)M.falling.forEach((f,i)=>{
    let m=fallMeshes[i];
    if(!m){m=new THREE.Mesh(new THREE.BoxGeometry(2.8,.5,.95),corrMat('#8a2e22'));m.castShadow=true;world.add(m);fallMeshes[i]=m;}
    const k=Math.min(1,f.t/f.T),y=4.6-(4.6-.25)*k*k;m.position.set(f.x,y,f.y);m.rotation.z=f.landed?.05:k*.08;
  });
  if(M.convoy&&M.convoy[0]&&!M.flags.gate&&M.convoy.some(c=>!c.dead&&c.y<36.5))M.flags.gate=true;
  if(M.flags&&!M.flags.gate&&M.cars.some(c=>c.scripted&&!c.dead&&c.y<36.5))M.flags.gate=true;
}
"""

patch('js/render.js', [
    ("import {N,P,NB,TAU,FLOOR,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,",
     "import {N,P,NB,TAU,FLOOR,T_ROAD,T_WALK,T_BLD,T_GRASS,T_PLAZA,T_TREE,T_WATER,T_FENCE,T_POST,"),
    ("    else if(t===T_GRASS||t===T_TREE){",
     "    else if(t===T_WATER){g.fillStyle=`rgb(${6+j/2},${16+j},${28+j})`;g.fillRect(X,Y,TS,TS);for(let k=0;k<3;k++){g.fillStyle='rgba(90,150,200,.12)';g.fillRect(X+rng()*TS,Y+rng()*TS,8+rng()*10,1);}sg.fillStyle='#ddd';}\n    else if(t===T_FENCE||t===T_POST){g.fillStyle=`rgb(${44+j},${46+j},${54+j})`;g.fillRect(X,Y,TS,TS);sg.fillStyle='#333';}\n    else if(t===T_GRASS||t===T_TREE){"),
    ("  // poças (reflexo)",
     """  // cais de madeira e borda do porto
  for(const p of (M.piers||[])){for(let y=p.y0;y<=p.y1;y++)for(let x=p.x0;x<=p.x1;x++){g.fillStyle='#3e2e22';g.fillRect(x*TS,y*TS,TS,TS);for(let k=0;k<4;k++){g.fillStyle=k%2?'#4a3828':'#35271c';g.fillRect(x*TS,y*TS+k*8,TS,7);}sg.fillStyle='#222';sg.fillRect(x*TS/4,y*TS/4,TS/4,TS/4);}}
  for(let y=1;y<N;y++)for(let x=0;x<N;x++){if(M.tile[y*N+x]!==T_WATER&&M.tile[(y-1)*N+x]===T_WATER&&!(M.piers||[]).some(p=>x>=p.x0&&x<=p.x1&&y-1>=p.y0&&y-1<=p.y1)){for(let s=0;s<4;s++){g.fillStyle=s%2?'#d8b020':'#1a1a1a';g.fillRect(x*TS+s*8,y*TS,8,4);}}}
  // poças (reflexo)"""),
    ("  for(let k=0;k<80;k++){\n    const x=rng()*N,y=rng()*N;if(M.tile[(y|0)*N+(x|0)]!==T_ROAD)continue;",
     "  for(let k=0;k<80;k++){\n    const x=rng()*N,y=rng()*N;if(M.tile[(y|0)*N+(x|0)]!==T_ROAD&&M.tile[(y|0)*N+(x|0)]!==T_PLAZA)continue;"),
    ("  buildGround();buildBuildings();buildTrees();buildLamps();buildObjectives();buildFx();buildMini();",
     "  buildGround();buildBuildings();buildTrees();buildLamps();buildObjectives();buildFx();buildMini();buildWater();buildFence();buildDecor();"),
    ("  for(const b of M.blds){\n    const H=b.fl*FLOOR+(b.kiosk?.2:0),",
     "  for(const b of M.blds){\n    if(b.style){buildSpecial(b);continue;}\n    const H=b.fl*FLOOR+(b.kiosk?.2:0),"),
    ("    o.position.set(l.x,1.15,l.y);o.rotation.set(0,0,0);o.updateMatrix();pole.setMatrixAt(i,o.matrix);\n    o.position.set(l.x+.18,2.28,l.y);o.updateMatrix();arm.setMatrixAt(i,o.matrix);\n    o.position.set(l.x+.34,2.24,l.y);o.updateMatrix();head.setMatrixAt(i,o.matrix);",
     "    const hs=l.tall?1.75:1;\n    o.position.set(l.x,1.15*hs,l.y);o.rotation.set(0,0,0);o.scale.set(1,hs,1);o.updateMatrix();pole.setMatrixAt(i,o.matrix);o.scale.set(1,1,1);\n    o.position.set(l.x+.18,2.28*hs,l.y);o.updateMatrix();arm.setMatrixAt(i,o.matrix);\n    o.position.set(l.x+.34,2.24*hs,l.y);o.scale.set(l.tall?1.8:1,l.tall?1.5:1,l.tall?1.8:1);o.updateMatrix();head.setMatrixAt(i,o.matrix);o.scale.set(1,1,1);"),
    ("l.position.set(s.x+.34,2.1,s.y);l.color.set(s.col);l.intensity=7;",
     "l.position.set(s.x+.34,s.tall?3.8:2.1,s.y);l.color.set(s.col);l.intensity=s.tall?16:7;l.distance=s.tall?14:9;"),
    ("  if(u.kind==='vip')parts.push(",
     "  if(u.helmet)parts.push(box(.2,.08,.2,0,1.0,0,'#e8c020'),box(.24,.03,.24,0,.965,0,'#e8c020'),box(.3,.05,.06,0,.66,.13,'#f2f2a0'));\n  if(u.kind==='vip')parts.push("),
    ("  syncFx();syncLights(dt);cutaway();",
     "  syncFx();syncDecor(dt);syncLights(dt);cutaway();"),
    ("  if(M.paused&&!M.ended){c.fillStyle='rgba(10,20,40,.2)';c.fillRect(0,0,VW,VH);}",
     "  if(M.cine){const h=Math.round(VH*.11);c.fillStyle='#000';c.fillRect(0,0,VW,h);c.fillRect(0,VH-h,VW,h);c.font='600 11px \"JetBrains Mono\",monospace';c.textAlign='right';c.fillStyle='rgba(255,255,255,.55)';c.fillText('ESPAÇO · pular',VW-20,VH-h/2+4);c.textAlign='left';c.font='700 13px \"Chakra Petch\",sans-serif';c.fillStyle='#ffa53d';c.fillText((M.scriptDef&&M.scriptDef.nome||'').toUpperCase()+' · '+M.D.nome.toUpperCase(),20,h/2+5);}\n  if(M.paused&&!M.ended){c.fillStyle='rgba(10,20,40,.2)';c.fillRect(0,0,VW,VH);}"),
    ("g.fillStyle=t===T_BLD?'#4a5570':t===T_ROAD?'#10131b':t===T_GRASS||t===T_TREE?'#1b3326':'#262b38';",
     "g.fillStyle=t===T_BLD?'#4a5570':t===T_ROAD?'#10131b':t===T_WATER?'#0a1824':t===T_FENCE?'#6a7088':t===T_GRASS||t===T_TREE?'#1b3326':'#262b38';"),
    ("/* ---------- personagens ---------- */", PORT + "\n/* ---------- personagens ---------- */"),
])
print('ok')
