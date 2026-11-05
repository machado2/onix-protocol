"""Patch: objetos de cenário em 3D (props.js) — árvores, postes, barris, telhados, fachadas e esquinas."""
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

TREES = r"""function buildTrees(){treeRefs=null;
  if(!M.trees.length)return;
  if(props.ready){
    const kinds=['tree_a','tree_b','tree_c','tree_d'],lists={tree_a:[],tree_b:[],tree_c:[],tree_d:[]},where=[],o=new THREE.Object3D();
    M.trees.forEach(t=>{const h=Math.abs(Math.floor(t.r*7.3)),k=kinds[h%4];o.position.set(t.x,0,t.y);o.rotation.set(0,t.r,0);o.scale.setScalar(t.s*(.88+(h%5)*.06));o.updateMatrix();where.push([k,lists[k].length]);lists[k].push(o.matrix.clone());});
    const ims={};for(const k of kinds){ims[k]=propInstances(k,lists[k]);ims[k].forEach(m=>world.add(m));}
    treeRefs={glb:true,at:where.map(([k,i])=>({ims:ims[k],i}))};return;
  }
"""

LAMPS = r"""function buildLamps(){lampRefs=null;
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
"""

PROPS_ON = r"""  for(const p of M.props){
    const g=new THREE.Group();
    if(props.ready&&propDef('barrel')){
      const b=propMesh('barrel','#e05038');
      const s=new THREE.Mesh(new THREE.CylinderGeometry(.182,.182,.06,14),basic('#ffb13d'));s.position.y=.33;
      g.add(b,s);g.position.set(p.x,0,p.y);world.add(g);propObjs.push({p,g});continue;
    }
"""

ROOF = r"""    if(!b.kiosk&&b.fl>=(b.favela?2:3)&&b.roof>0){
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
"""

CORNERS = r"""/* semáforos e placas nas esquinas e aparelhos de ar nas fachadas */
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
    if(M.tile[y*N+x]!==T_WALK)continue;
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
function buildObjectives(){"""

DESTR_LAMP = r"""  }else if(type==='lamp'&&lampRefs&&lampRefs.glb){
    const i=M.lamps.indexOf(o);if(i<0)return;const s=o.tall?1.5:1;
    o3.position.set(o.x+.08,.06,o.y);o3.rotation.set(0,0,-1.45);o3.scale.setScalar(s);o3.updateMatrix();
    for(const im of lampRefs.ims){im.setMatrixAt(i,o3.matrix);im.instanceMatrix.needsUpdate=true;}
    lampRefs.head.setMatrixAt(i,ZERO);lampRefs.head.instanceMatrix.needsUpdate=true;lampT=0;
  }else if(type==='tree'&&treeRefs&&treeRefs.glb){
    const a=treeRefs.at[M.trees.indexOf(o)];if(!a)return;
    for(const im of a.ims){im.setMatrixAt(a.i,ZERO);im.instanceMatrix.needsUpdate=true;}
  }else if(type==='lamp'&&lampRefs){"""

patch(os.path.join(V2, 'js', 'render.js'), 'buildStreetProps', [
    ("import {pbrGround,", "import {props,propMesh,propInstances,propDef} from './props.js';\nimport {pbrGround,"),
    ("function buildTrees(){treeRefs=null;\n  if(!M.trees.length)return;\n", TREES),
    ("function buildLamps(){lampRefs=null;\n  const n=M.lamps.length;if(!n)return;\n", LAMPS),
    ("  for(const p of M.props){\n    const g=new THREE.Group();\n", PROPS_ON),
    ("    if(!b.kiosk&&b.fl>=(b.favela?2:3)&&b.roof>0){\n      const r=new THREE.Mesh(b.roof===1?roofGeoAC:b.favela?roofGeoTankBlue:roofGeoTank,vcMat);r.position.set(b.x+.4+rng()*(b.w-.8),H+.05,b.y+.4+rng()*(b.d-.8));r.castShadow=true;world.add(r);m.userData.extra.push(r);\n    }\n", ROOF),
    ("function buildObjectives(){", CORNERS),
    ("  buildGround();buildBuildings();buildTrees();buildLamps();", "  acList=[];buildGround();buildBuildings();buildTrees();buildLamps();buildStreetProps();"),
    ("  }else if(type==='lamp'&&lampRefs){", DESTR_LAMP),
    ("    for(const e of m.userData.extra)e.visible=!f;",
     "    for(const e of m.userData.extra)e.visible=!f;\n    if(m.userData.acs)for(const a of m.userData.acs)for(const im of a.ims){im.setMatrixAt(a.i,f?ZERO:a.mtx);im.instanceMatrix.needsUpdate=true;}"),
])
