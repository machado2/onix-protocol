"""Redireciona capturas de movimento do CMU (BVH da conversão de Bruce Hahne / cgspeed) para o rig "game_engine" do MPFB.

Método: para cada osso mapeado, rotação no mundo do alvo = rotação atual da fonte * inversa do repouso da fonte * repouso
do alvo "alinhado" (o alvo posto na mesma pose de repouso da fonte, em T, alinhando a direção de cada osso dos membros).
Depois converte para rotações locais na ordem da hierarquia. O quadril recebe a translação escalada pelo comprimento da perna,
sem o deslocamento horizontal médio (animação no lugar), e os ciclos são recortados no período que melhor fecha o laço.
"""
import bpy, math
from mathutils import Vector, Matrix, Quaternion

MAP = {
    'Hips': 'pelvis', 'LowerBack': 'spine_01', 'Spine': 'spine_02', 'Spine1': 'spine_03', 'Neck': 'neck_01', 'Head': 'head',
    'LeftShoulder': 'clavicle_l', 'LeftArm': 'upperarm_l', 'LeftForeArm': 'lowerarm_l', 'LeftHand': 'hand_l',
    'RightShoulder': 'clavicle_r', 'RightArm': 'upperarm_r', 'RightForeArm': 'lowerarm_r', 'RightHand': 'hand_r',
    'LeftUpLeg': 'thigh_l', 'LeftLeg': 'calf_l', 'LeftFoot': 'foot_l', 'LeftToeBase': 'ball_l',
    'RightUpLeg': 'thigh_r', 'RightLeg': 'calf_r', 'RightFoot': 'foot_r', 'RightToeBase': 'ball_r',
}
ALIGN = {'clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l', 'clavicle_r', 'upperarm_r', 'lowerarm_r', 'hand_r',
         'thigh_l', 'calf_l', 'foot_l', 'ball_l', 'thigh_r', 'calf_r', 'foot_r', 'ball_r'}


def load_bvh(path):
    before = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=path, axis_forward='-Z', axis_up='Y', global_scale=1.0, use_fps_scale=False,
                            update_scene_fps=False, update_scene_duration=False, rotate_mode='NATIVE')
    src = [o for o in bpy.data.objects if o not in before][0]
    return src


def _rot(m):
    return m.to_3x3().normalized()


def sample_source(src, f0, f1, step):
    """Lê rotações e posição do quadril da fonte, no mundo, quadro a quadro."""
    out = []
    for f in range(f0, f1 + 1, step):
        bpy.context.scene.frame_set(f)
        fr = {}
        for sb in MAP:
            pb = src.pose.bones.get(sb)
            if pb:
                fr[sb] = _rot(src.matrix_world @ pb.matrix)
        fr['_hips'] = (src.matrix_world @ src.pose.bones['Hips'].matrix).translation.copy()
        fr['_lr'] = ((src.matrix_world @ src.pose.bones['LeftUpLeg'].matrix).translation - (src.matrix_world @ src.pose.bones['RightUpLeg'].matrix).translation)
        fr['_foot'] = min((src.matrix_world @ src.pose.bones[k].matrix).translation.z for k in ('LeftFoot', 'RightFoot'))
        out.append(fr)
    return out


def source_rest(src):
    rest, dirs, heads = {}, {}, {}
    for sb in MAP:
        b = src.data.bones.get(sb)
        if not b:
            continue
        m = src.matrix_world @ b.matrix_local
        rest[sb] = _rot(m)
        heads[sb] = (src.matrix_world @ b.head_local)
        dirs[sb] = ((src.matrix_world @ b.tail_local) - heads[sb]).normalized()
    return rest, dirs, heads


def target_rest(rig):
    rest, dirs, heads = {}, {}, {}
    for b in rig.data.bones:
        m = rig.matrix_world @ b.matrix_local
        rest[b.name] = _rot(m)
        heads[b.name] = rig.matrix_world @ b.head_local
        dirs[b.name] = ((rig.matrix_world @ b.tail_local) - heads[b.name]).normalized()
    return rest, dirs, heads


def facing(heads, l, r):
    v = heads[l] - heads[r]
    return math.atan2(v.y, v.x)


class Retarget:
    def __init__(self, rig, src):
        self.rig, self.src = rig, src
        self.srest, self.sdir, self.shead = source_rest(src)
        self.trest, self.tdir, self.thead = target_rest(rig)
        # alinha a direção em que a fonte olha com a do alvo (rotação em Z)
        a = facing(self.thead, 'thigh_l', 'thigh_r') - facing(self.shead, 'LeftUpLeg', 'RightUpLeg')
        self.Q = Matrix.Rotation(a, 3, 'Z')
        self.Qrest = self.Q.copy()
        # alvo em "pose T": cada osso de membro gira para apontar como o osso da fonte em repouso
        self.tT = {}
        for sb, tb in MAP.items():
            if sb not in self.srest:
                continue
            if tb in ALIGN:
                d = self.Q @ self.sdir[sb]
                q = self.tdir[tb].rotation_difference(d).to_matrix()
                self.tT[tb] = q @ self.trest[tb]
            else:
                self.tT[tb] = self.trest[tb]
        # escala da translação: comprimento da perna
        ls = (self.shead['LeftUpLeg'] - self.shead['LeftFoot']).length
        lt = (self.thead['thigh_l'] - self.thead['foot_l']).length
        self.k = lt / ls
        self.hips0 = self.shead['Hips'].copy()
        self.pelvis0 = self.thead['pelvis'].copy()

    def world_rots(self, fr):
        out = {}
        for sb, tb in MAP.items():
            if sb in fr and sb in self.srest:
                out[tb] = self.Q @ fr[sb] @ self.srest[sb].inverted() @ self.Qrest.inverted() @ self.tT[tb]
        return out

    def set_heading(self, frames):
        # gira o clipe para que a direção média do quadril coincida com a frente do alvo
        v = sum((fr['_lr'] for fr in frames), Vector())
        a = facing(self.thead, 'thigh_l', 'thigh_r') - math.atan2(v.y, v.x)
        self.Q = Matrix.Rotation(a, 3, 'Z')

    def set_ground(self, frames):
        # chão da fonte = altura do tornozelo apoiado (o menor ao longo do trecho)
        self.ground_s = min(fr['_foot'] for fr in frames)
        self.ground_t = min(self.thead['foot_l'].z, self.thead['foot_r'].z)

    def pelvis_pos(self, fr):
        d = self.Q @ (fr['_hips'] - self.hips0)
        p = self.pelvis0 + d * self.k
        p.z = self.ground_t + (fr['_hips'].z - self.ground_s) * self.k
        return p


def to_local(rig, wrots, pelvis_pos):
    """Rotação/posição no mundo -> base local (matrix_basis) de cada osso, na ordem da hierarquia."""
    W = rig.matrix_world.inverted()
    Wr = W.to_3x3()
    pose = {}
    basis = {}
    for b in _ordered(rig):
        rest = b.matrix_local
        if b.parent:
            P = pose[b.parent.name] @ b.parent.matrix_local.inverted() @ rest
        else:
            P = rest.copy()
        if b.name in wrots:
            R = (Wr @ wrots[b.name]).to_4x4()
            pos = (W @ pelvis_pos) if b.name == 'pelvis' else P.translation
            D = Matrix.Translation(pos) @ R
            B = P.inverted() @ D
        else:
            B = finger_curl(b.name)
            D = P @ B
        pose[b.name] = D
        basis[b.name] = B
    return basis


def finger_curl(name):
    """Dedos levemente fechados (mão relaxada) nos ossos que o mocap não cobre."""
    if any(k in name for k in ('index', 'middle', 'ring', 'pinky')):
        k = {'01': .35, '02': .5, '03': .35}.get(name.split('_')[1], .3)
        return Matrix.Rotation(k, 4, 'X')
    if 'thumb' in name:
        return Matrix.Rotation(.2, 4, 'X')
    return Matrix.Identity(4)


def _ordered(rig):
    out = []
    def rec(b):
        out.append(b)
        for c in b.children:
            rec(c)
    for b in rig.data.bones:
        if b.parent is None:
            rec(b)
    return out


def find_loop(frames, pmin, pmax, start):
    """Período (em quadros amostrados) que melhor fecha o laço a partir de 'start'."""
    keys = ['LeftUpLeg', 'RightUpLeg', 'LeftLeg', 'RightLeg', 'LeftArm', 'RightArm', 'Spine1']
    def dist(a, b):
        s = 0
        for k in keys:
            if k in a and k in b:
                s += 1 - abs(a[k].to_quaternion().dot(b[k].to_quaternion()))
        return s
    best, bp = 1e9, pmin
    for p in range(pmin, min(pmax, len(frames) - start - 1) + 1):
        d = dist(frames[start], frames[start + p]) + .5 * dist(frames[start + 1], frames[start + p + 1] if start + p + 1 < len(frames) else frames[start + p])
        if d < best:
            best, bp = d, p
    return bp, best


def bake(rig, rt, frames, name, loop=True, inplace=True, blend=4):
    """Grava uma ação no rig a partir dos quadros da fonte. Devolve a velocidade média (m/s) e a ação."""
    n = len(frames)
    pels = [rt.pelvis_pos(fr) for fr in frames]
    speed = 0.0
    if inplace and n > 1:
        span = n - 1 if not loop else n
        dv = (pels[-1] - pels[0]) / (n - 1)
        speed = Vector((dv.x, dv.y, 0)).length * 30.0
        pels = [p - Vector((dv.x * i, dv.y * i, 0)) for i, p in enumerate(pels)]
        c = sum((p for p in pels), Vector()) / n
        pels = [Vector((p.x - c.x + rt.pelvis0.x, p.y - c.y + rt.pelvis0.y, p.z)) for p in pels]
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    bases = []
    for i, fr in enumerate(frames):
        bases.append(to_local(rig, rt.world_rots(fr), pels[i]))
    if loop and blend > 0:
        # funde o fim no começo para o laço não pular
        for j in range(blend):
            t = (j + 1) / (blend + 1)
            i = n - blend + j
            for bn in bases[i]:
                qa = bases[i][bn].to_quaternion()
                qb = bases[0][bn].to_quaternion()
                q = qa.slerp(qb, t)
                la = bases[i][bn].translation
                lb = bases[0][bn].translation
                bases[i][bn] = Matrix.Translation(la.lerp(lb, t)) @ q.to_matrix().to_4x4()
    for i, B in enumerate(bases + ([bases[0]] if loop else [])):
        f = i + 1
        for bn, M in B.items():
            pb = rig.pose.bones[bn]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = M.to_quaternion()
            pb.keyframe_insert('rotation_quaternion', frame=f)
            if bn == 'pelvis':
                pb.location = M.translation
                pb.keyframe_insert('location', frame=f)
    act.use_fake_user = True
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    tr.strips.new(name, 1, act)
    tr.mute = True
    rig.animation_data.action = None
    # reseta a pose
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return speed, act


def clip(rig, path, name, fps_src=120, seconds=None, start=.3, loop=None, inplace=True):
    """Importa um BVH e grava a ação 'name'. loop=(período mín, máx) em segundos para ciclos."""
    src = load_bvh(path)
    act = src.animation_data.action
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    step = max(1, round(fps_src / 30))
    frames = sample_source(src, f0, f1, step)
    rt = Retarget(rig, src)
    s0 = int(len(frames) * start)
    if loop:
        p, err = find_loop(frames, int(loop[0] * 30), int(loop[1] * 30), s0)
        frames = frames[s0:s0 + p]
        print('laço', name, p, 'quadros, erro', round(err, 3))
    elif seconds:
        frames = frames[s0:s0 + int(seconds * 30)]
    else:
        frames = frames[s0:]
    rt.set_heading(frames)
    rt.set_ground(frames)
    sp, a = bake(rig, rt, frames, name, loop=bool(loop) or seconds is not None, inplace=inplace)
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.actions.remove(act)
    return sp
