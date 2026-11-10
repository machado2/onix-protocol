"""Monta um personagem completo do Protocolo Ônix e exporta para o Godot:
humano do MPFB2 (humans.py) + equipamento ajustado ao corpo (sobretudo, colete, visor, capacete, boné, fuzil, pistola)
+ osso "gun" com IK nas duas mãos + animações de mocap do CMU redirecionadas (mocap.py), com e sem arma.
Uso: blender -b -P tools/blender/build_chars.py -- <nome> <saída.glb> <pasta dos BVH> [--preview pasta]
"""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector, Matrix
import humans, mocap
from lib import Part, mat

R = math.radians
GEAR = {
    'agent_m': ['coat', 'visor', 'rifle'], 'agent_f': ['coat', 'visor', 'rifle'],
    'guard': ['vest', 'helmet', 'rifle'], 'police': ['vest', 'cap', 'pistol'],
}
# clipe: (arquivo, laço (s mín, s máx) ou None, segundos se não for laço, início relativo)
CLIPS = {
    'idle':   ('137_28', None, 4.0, .25),
    'walk':   ('16_15', (.8, 1.4), None, .3),
    'run':    ('16_35', (.5, .9), None, .3),
    'panic':  ('91_32', (.6, 1.4), None, .3),
    'crouch': ('136_09', (.8, 1.8), None, .3),
    'sneak':  ('77_29', (.9, 2.0), None, .3),
    'type':   ('79_85', None, 3.0, .4),
    'die':    ('90_16', None, None, .0),
}
ARMED = {  # ação com arma: (ação base, pose da arma)
    'idle_gun': ('idle', 'low'), 'walk_gun': ('walk', 'low'), 'run_gun': ('run', 'low'),
    'aim': ('idle', 'aim'), 'aim_walk': ('walk', 'aim'), 'crouch_gun': ('crouch', 'aim'), 'die_gun': ('die', 'low'),
}


# ---------------------------------------------------------------- medidas do corpo
def body_obj():
    return [o for o in bpy.data.objects if o.type == 'MESH' and ('generic' in o.name or 'proxy' in o.name.lower())][0]


def section(body, z, band=.02, xmax=None):
    """Meia-largura e meia-profundidade do corpo na altura z (ignora braços se xmax)."""
    xs, ys = [], []
    mw = body.matrix_world
    for v in body.data.vertices:
        p = mw @ v.co
        if abs(p.z - z) < band and (xmax is None or abs(p.x) < xmax):
            xs.append(abs(p.x))
            ys.append(p.y)
    if not xs:
        return .15, .1, 0
    return max(xs), (max(ys) - min(ys)) / 2, (max(ys) + min(ys)) / 2


def bone_head(rig, n):
    return rig.matrix_world @ rig.data.bones[n].head_local


def loft(P, rings, m, seg=28, gap=None):
    vs = []
    for (z, rx, ry, cy) in rings:
        ring = []
        for k in range(seg + (1 if gap else 0)):
            a = (-math.pi / 2 + gap / 2 + k / seg * (2 * math.pi - gap)) if gap else k / seg * 2 * math.pi
            ring.append(P.bm.verts.new((math.cos(a) * rx, math.sin(a) * ry + cy, z)))
        vs.append(ring)
    n = len(vs[0])
    fs = []
    for i in range(len(vs) - 1):
        for k in range(n if not gap else n - 1):
            a, b = vs[i][k], vs[i][(k + 1) % n]
            c, d = vs[i + 1][(k + 1) % n], vs[i + 1][k]
            fs.append(P.bm.faces.new((a, b, c, d)))
    for f in fs:
        f.normal_update()
    P._finish(fs, m)


# ---------------------------------------------------------------- equipamento
def coat(rig, body):
    P = Part('gear_coat')
    sh = bone_head(rig, 'upperarm_l')
    neck = bone_head(rig, 'neck_01')
    ch = bone_head(rig, 'spine_03')
    wa = bone_head(rig, 'spine_01')
    hp = bone_head(rig, 'thigh_l')
    kn = bone_head(rig, 'calf_l')
    xin = sh.x * .92
    xhip = hp.x + .11
    rings = []
    for z, extra, xm in ((neck.z - .02, .012, .09), (sh.z - .02, .03, sh.x + .05), (ch.z, .03, xin), ((ch.z + wa.z) / 2, .03, xin),
                         (wa.z, .03, xin), (hp.z + .05, .035, xhip)):
        rx, ry, cy = section(body, z, .025, xm)
        rings.append((z, rx + extra, ry + extra, cy))
    rx, ry, cy = rings[-1][1:]
    for t, z in ((.45, hp.z - (hp.z - kn.z) * .45), (1.0, kn.z - .05)):
        rings.append((z, rx + .04 + .06 * t, ry + .03 + .05 * t, cy + .01 * t))
    loft(P, rings, 'coat', 32, gap=.45)
    loft(P, [(neck.z - .02, rings[0][1] + .005, rings[0][2] + .005, rings[0][3]), (neck.z + .1, rings[0][1] + .02, rings[0][2] + .025, rings[0][3] + .01)],
         'coat', 24, gap=1.0)
    zb = (wa.z + hp.z) / 2
    rx, ry, cy = section(body, zb, .025, xin)
    loft(P, [(zb - .025, rx + .045, ry + .045, cy), (zb + .025, rx + .045, ry + .045, cy)], 'belt', 32)
    P.n_torso = len(P.bm.verts)
    for s in ('l', 'r'):
        a, b, c = bone_head(rig, 'upperarm_' + s), bone_head(rig, 'lowerarm_' + s), bone_head(rig, 'hand_' + s)
        ra = section_arm(body, a, b)
        P.cyl(a + (a - b).normalized() * .03, b, ra + .028, ra * .85 + .022, 'coat', 16, caps=False)
        P.sphere(b.x, b.y, b.z, ra * .85 + .022, 'coat', 2)
        P.cyl(b, c - (c - b).normalized() * .04, ra * .85 + .022, ra * .7 + .02, 'coat', 16, caps=False)
    n = P.n_torso
    o = P.obj(smooth_angle=70)
    o['n_torso'] = n
    return o


def section_arm(body, a, b):
    mid = (a + b) / 2
    d = (b - a).normalized()
    rs = []
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        q = p - mid
        if abs(q.dot(d)) < .03:
            r = (q - d * q.dot(d)).length
            if r < .09:
                rs.append(r)
    return max(rs) if rs else .045


def vest(rig, body):
    P = Part('gear_vest')
    sh = bone_head(rig, 'upperarm_l')
    ch = bone_head(rig, 'spine_03')
    wa = bone_head(rig, 'spine_01')
    xin = sh.x * .9
    rings = []
    for z in (wa.z - .02, (wa.z + ch.z) / 2, ch.z, sh.z - .04):
        rx, ry, cy = section(body, z, .025, xin)
        rings.append((z, rx + .03, ry + .035, cy))
    loft(P, rings, 'vest', 28)
    fz = (wa.z + ch.z) / 2
    fy = rings[1][3] - rings[1][2] - .02
    for x in (-.08, 0, .08):
        P.box(x - .035, fy - .045, fz - .05, x + .035, fy + .01, fz + .05, 'vest_pouch')
    by = rings[1][3] + rings[1][2] + .01
    P.box(-.13, by, wa.z, .13, by + .08, sh.z - .06, 'vest_pouch')
    for s in (1, -1):
        P.box(s * .07, rings[-1][3] - rings[-1][2] - .005, sh.z - .06, s * .14, rings[-1][3] + rings[-1][2] + .005, sh.z + .0, 'vest')
    return P.obj(bevel=.004, smooth_angle=50)


def head_frame(rig):
    eyes = [o for o in bpy.data.objects if o.type == 'MESH' and 'low-poly' in o.name]
    hd = bone_head(rig, 'head')
    if eyes:
        bb = [eyes[0].matrix_world @ Vector(c) for c in eyes[0].bound_box]
        ez = sum(p.z for p in bb) / 8
        ey = min(p.y for p in bb)
    else:
        ez, ey = hd.z + .09, hd.y - .09
    return hd, ez, ey


def visor(rig, body):
    P = Part('gear_visor')
    hd, ez, ey = head_frame(rig)
    rx, ry, cy = section(body, ez, .012)
    rx += .012
    ry += .012
    for k in range(12):
        a0 = -math.pi / 2 - 1.0 + k / 12 * 2.0
        a1 = -math.pi / 2 - 1.0 + (k + 1) / 12 * 2.0
        P.quad([(math.cos(a0) * rx, math.sin(a0) * ry + cy, ez - .018), (math.cos(a1) * rx, math.sin(a1) * ry + cy, ez - .018),
                (math.cos(a1) * rx, math.sin(a1) * ry + cy, ez + .022), (math.cos(a0) * rx, math.sin(a0) * ry + cy, ez + .022)], 'visor')
    for s in (1, -1):
        P.box(s * (rx - .005), cy - .02, ez - .015, s * (rx + .008), cy + .04, ez + .02, 'gun')
    return P.obj(smooth_angle=80)


def helmet(rig, body):
    P = Part('gear_helmet')
    hd, ez, ey = head_frame(rig)
    top = max((body.matrix_world @ v.co).z for v in body.data.vertices)
    rx, ry, cy = section(body, ez + .03, .015)
    cz = ez + .01
    hz = top - cz + .03
    P.sphere(0, cy, cz, 1.0, 'helmet', 3, (rx + .03, ry + .035, hz))
    kill = [f for f in P.bm.faces if f.calc_center_median().z < cz - .01 or (f.calc_center_median().z < ez + .045 and f.calc_center_median().y < cy - ry * .4)]
    bmesh.ops.delete(P.bm, geom=kill, context='FACES')
    for k in range(10):
        a0 = -math.pi / 2 - .9 + k / 10 * 1.8
        a1 = -math.pi / 2 - .9 + (k + 1) / 10 * 1.8
        r1, r2 = rx + .035, ry + .045
        P.quad([(math.cos(a0) * r1, math.sin(a0) * r2 + cy, ez - .03), (math.cos(a1) * r1, math.sin(a1) * r2 + cy, ez - .03),
                (math.cos(a1) * r1, math.sin(a1) * r2 + cy, ez + .045), (math.cos(a0) * r1, math.sin(a0) * r2 + cy, ez + .045)], 'visor')
    return P.obj(bevel=.004, smooth_angle=60)


def cap(rig, body):
    P = Part('gear_cap')
    hd, ez, ey = head_frame(rig)
    top = max((body.matrix_world @ v.co).z for v in body.data.vertices)
    rx, ry, cy = section(body, ez + .05, .015)
    z0 = ez + .035
    P.cyl((0, cy, z0), (0, cy, top + .01), max(rx, ry) + .012, max(rx, ry) + .005, 'cap', 24)
    P.sphere(0, cy, top + .01, 1.0, 'cap', 2, (max(rx, ry) + .005, max(rx, ry) + .005, .03))
    P.box(-.085, cy - ry - .1, z0, .085, cy - ry + .01, z0 + .012, 'cap_brim')
    P.box(-.022, cy - ry - .016, z0 + .03, .022, cy - ry - .006, z0 + .06, 'badge')
    return P.obj(bevel=.003, smooth_angle=50)


def rifle(grip):
    P = Part('gear_rifle')
    g = grip
    B = lambda x0, y0, z0, x1, y1, z1, m: P.box(g.x + x0, g.y + y0, g.z + z0, g.x + x1, g.y + y1, g.z + z1, m)
    B(-.024, -.26, -.02, .024, .12, .065, 'gun')
    P.cyl((g.x, g.y - .26, g.z + .032), (g.x, g.y - .62, g.z + .032), .011, m='gun', seg=10)
    P.cyl((g.x, g.y - .58, g.z + .032), (g.x, g.y - .66, g.z + .032), .016, m='gun', seg=10)
    B(-.026, -.44, -.01, .026, -.26, .066, 'gun_grip')
    B(-.019, .12, -.04, .019, .33, .055, 'gun_grip')
    B(-.016, -.12, -.17, .016, -.06, -.02, 'gun')
    B(-.015, .01, -.12, .015, .05, -.01, 'gun_grip')
    P.cyl((g.x, g.y - .15, g.z + .1), (g.x, g.y + .02, g.z + .1), .017, m='gun', seg=12)
    B(-.006, -.06, .065, .006, .02, .085, 'gun')
    return P.obj(bevel=.003)


def pistol(grip):
    P = Part('gear_pistol')
    g = grip
    P.box(g.x - .016, g.y - .17, g.z, g.x + .016, g.y + .03, g.z + .045, 'gun')
    P.box(g.x - .015, g.y - .01, g.z - .1, g.x + .015, g.y + .035, g.z, 'gun_grip')
    return P.obj(bevel=.003)


def skin_to_body(o, rig, body):
    """Copia os pesos de osso do corpo para a peça (vizinho mais próximo) e liga ao esqueleto."""
    dt = o.modifiers.new('dt', 'DATA_TRANSFER')
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}
    dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'
    dt.layers_vgroup_select_dst = 'NAME'
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.datalayout_transfer(modifier='dt')
    bpy.ops.object.modifier_apply(modifier='dt')
    if 'n_torso' in o:
        # tronco e saia do sobretudo não seguem braços e mãos
        arm = [g.index for g in o.vertex_groups if any(k in g.name for k in ('arm', 'hand', 'clavicle', 'thumb', 'index', 'middle', 'ring', 'pinky'))]
        names = {g.index: g.name for g in o.vertex_groups}
        for v in o.data.vertices[:o['n_torso']]:
            for g in list(v.groups):
                if g.group in arm:
                    o.vertex_groups[g.group].remove([v.index])
            if sum(g.weight for g in v.groups if names[g.group] in BONE_NAMES) < 1e-3:
                o.vertex_groups['spine_03' if v.co.z > 1.2 else 'pelvis'].add([v.index], 1.0, 'REPLACE')
    _bind(o, rig)


BONE_NAMES = set()


def skin_to_bone(o, rig, bone):
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    _bind(o, rig)


def _bind(o, rig):
    o.parent = rig
    o.matrix_parent_inverse = rig.matrix_world.inverted()
    am = o.modifiers.new('arm', 'ARMATURE')
    am.object = rig


# ---------------------------------------------------------------- arma e IK
IKC = []


def add_gun_bone(rig):
    sh = bone_head(rig, 'upperarm_r')
    grip = Vector((sh.x + .07, sh.y - .3, sh.z - .05))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    b = eb.new('gun')
    W = rig.matrix_world.inverted()
    b.head = W @ grip
    b.tail = W @ (grip + Vector((0, -.2, 0)))
    b.roll = 0
    b.parent = eb['spine_03']
    b.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    return grip


def setup_ik(rig, grip):
    tg = {}
    offs = {'r': Vector((0, .07, -.06)), 'l': Vector((.045, -.3, -.05))}
    for s, off in offs.items():
        e = bpy.data.objects.new('ik_' + s, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = rig
        e.parent_type = 'BONE'
        e.parent_bone = 'gun'
        e.matrix_world = Matrix.Translation(grip + off)
        tg[s] = e
    shr, shl = bone_head(rig, 'upperarm_r'), bone_head(rig, 'upperarm_l')
    poles = {'r': shr + Vector((-.35, .3, -.4)), 'l': shl + Vector((.3, -.05, -.45))}
    for s in ('r', 'l'):
        p = bpy.data.objects.new('pole_' + s, None)
        bpy.context.scene.collection.objects.link(p)
        p.location = poles[s]
        p.parent = rig
        p.matrix_parent_inverse = rig.matrix_world.inverted()
        c = rig.pose.bones['lowerarm_' + s].constraints.new('IK')
        c.target = tg[s]
        c.pole_target = p
        c.chain_count = 2
        c.use_tail = True
        IKC.append((s, c))
    bpy.context.view_layer.update()
    for s, c in IKC:
        best, ba = 1e9, 0
        for ang in (0, 90, -90, 180):
            c.pole_angle = R(ang)
            bpy.context.view_layer.update()
            el = rig.matrix_world @ rig.pose.bones['upperarm_' + s].tail
            d = (el - poles[s]).length
            if d < best:
                best, ba = d, ang
        c.pole_angle = R(ba)
        c.influence = 0.0


def gun_basis(rig, grip, mode, recoil=0.0):
    """Base local do osso 'gun' para a pose pedida, com o peito em repouso."""
    rest = rig.data.bones['gun'].matrix_local
    W = rig.matrix_world.inverted()
    if mode == 'low':
        sh = bone_head(rig, 'upperarm_r')
        g = Vector((sh.x + .12, sh.y - .2, sh.z - .32))
        Rw = Matrix.Rotation(R(32), 4, 'Z') @ Matrix.Rotation(R(34), 4, 'X')
    else:
        g = grip + Vector((0, .045 * recoil, 0))
        Rw = Matrix.Rotation(-R(6) * recoil, 4, 'X')
    D = Matrix.Translation(W @ g) @ Rw @ rest.to_3x3().to_4x4()
    return rest.inverted() @ D


def armed_action(rig, grip, base, name, mode, shoot=False):
    """Ação com arma: copia a ação base, liga o IK das mãos e posiciona o osso da arma quadro a quadro.
    Na mira, a arma segue a posição e o giro horizontal do peito, mas fica nivelada (sem inclinar com o tronco)."""
    src = bpy.data.actions[base]
    act = src.copy()
    act.name = name
    rig.animation_data.action = act
    f0, f1 = int(src.frame_range[0]), int(src.frame_range[1])
    if shoot:
        f1 = f0 + 8
        act.use_frame_range = True
        act.frame_start, act.frame_end = f0, f1
    pg = rig.pose.bones['gun']
    pg.rotation_mode = 'QUATERNION'
    sp = rig.pose.bones['spine_03']
    gb = rig.data.bones['gun']
    rest_rel = sp.bone.matrix_local.inverted() @ gb.matrix_local
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        rec = 0.0
        if shoot:
            t = (f - f0) / max(1, f1 - f0)
            rec = max(0.0, 1 - t * 2.5) if t > .04 else t * 25
        B = gun_basis(rig, grip, mode, rec)
        if mode == 'aim':
            # pose desejada: posição do peito, só o giro em Z do peito, arma reta (mais o coice do tiro)
            P = sp.matrix @ rest_rel
            ch = sp.matrix.to_3x3() @ sp.bone.matrix_local.to_3x3().inverted() @ Vector((0, -1, 0))
            yaw = math.atan2(ch.x, -ch.y)
            Ry = Matrix.Rotation(yaw, 4, 'Z')
            pos = P.translation + Ry.to_3x3() @ Vector((0, .045 * rec, 0))
            G = Matrix.Translation(pos) @ Ry @ Matrix.Rotation(-R(6) * rec, 4, 'X') @ gb.matrix_local.to_3x3().to_4x4()
            B = P.inverted() @ G
        pg.location = B.translation
        pg.rotation_quaternion = B.to_quaternion()
        pg.keyframe_insert('location', frame=f)
        pg.keyframe_insert('rotation_quaternion', frame=f)
        if f in (f0, f1):
            for s, c in IKC:
                c.influence = 1.0
                c.keyframe_insert('influence', frame=f)
    act.use_fake_user = True
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, f0, act)
    tr.mute = True
    rig.animation_data.action = None


def key_unarmed(rig):
    """Nas ações sem arma, IK desligado e osso da arma parado."""
    for tr in rig.animation_data.nla_tracks:
        act = tr.strips[0].action
        if act.name in CLIPS:
            rig.animation_data.action = act
            f0 = int(act.frame_range[0])
            for s, c in IKC:
                c.influence = 0.0
                c.keyframe_insert('influence', frame=f0)
            rig.animation_data.action = None


def shrink_images(maxs=1024):
    for img in bpy.data.images:
        if img.size[0] > maxs or img.size[1] > maxs:
            r = maxs / max(img.size)
            img.scale(max(1, int(img.size[0] * r)), max(1, int(img.size[1] * r)))


if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:]
    name, out, bvh_dir = a[0], a[1], a[2]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    humans.build(name)
    rig = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name.endswith('.body'):
            bpy.data.objects.remove(o, do_unlink=True)
    body = body_obj()
    BONE_NAMES.update(b.name for b in rig.data.bones)
    grip = add_gun_bone(rig)
    gear = GEAR.get(name, [])
    for g in gear:
        if g in ('rifle', 'pistol'):
            o = rifle(grip) if g == 'rifle' else pistol(grip)
            skin_to_bone(o, rig, 'gun')
        else:
            o = {'coat': coat, 'vest': vest, 'visor': visor, 'helmet': helmet, 'cap': cap}[g](rig, body)
            skin_to_body(o, rig, body)
    setup_ik(rig, grip)
    meta = {'speed': {}}
    for cn, (f, loop, secs, st) in CLIPS.items():
        if name not in ('agent_m', 'agent_f', 'guard', 'police') and cn in ('sneak',):
            continue
        sp = mocap.clip(rig, os.path.join(bvh_dir, f + '.bvh'), cn, loop=loop, seconds=secs, start=st, inplace=cn != 'die')
        meta['speed'][cn] = round(sp, 3)
    key_unarmed(rig)
    if any(g in gear for g in ('rifle', 'pistol')):
        for an, (base, mode) in ARMED.items():
            armed_action(rig, grip, base, an, mode)
            meta['speed'][an] = meta['speed'].get(base, 0)
        armed_action(rig, grip, 'idle', 'shoot', 'aim', shoot=True)
    for tr in rig.animation_data.nla_tracks:
        tr.mute = False
    shrink_images(1024)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False, export_apply=True, export_yup=True,
                              export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
                              export_skins=True, export_materials='EXPORT', export_image_format='WEBP', export_image_quality=85,
                              export_optimize_animation_size=False, export_bake_animation=True)
    with open(out.replace('.glb', '.json'), 'w') as fp:
        json.dump(meta, fp)
    print('exportado', out, meta)
