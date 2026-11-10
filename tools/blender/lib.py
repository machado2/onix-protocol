"""Utilidades para modelar peças por script no Blender (rodar com blender -b --factory-startup -P <script> -- <saída>).

Convenção das peças de fachada (coordenadas do Blender, Z para cima):
  largura em X de 0 a 3 m, altura em Z de 0 a 3,2 m, face externa no plano Y=0 apontando para -Y.
Depois do export glTF (Y para cima) a face externa aponta para +Z no Godot.
Os materiais são só nomes ("wall", "trim", "frame", "glass", ...); o Godot troca cada um pelo shader certo.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

_mats = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def mat(name):
    if name not in _mats:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        _mats[name] = m
    return _mats[name]


class Part:
    """Acumula geometria (bmesh) com materiais por face; vira um objeto no fim."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.uv = self.bm.loops.layers.uv.new('UVMap')

    def _mi(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _finish(self, faces, m, uvmode='box', uvrect=None):
        mi = self._mi(m)
        for f in faces:
            f.material_index = mi
            n = f.normal
            for l in f.loops:
                co = l.vert.co
                if uvmode == 'rect' and uvrect:
                    (x0, z0, x1, z1) = uvrect
                    l[self.uv].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))
                else:
                    ax = max(range(3), key=lambda i: abs(n[i]))
                    if ax == 0:
                        l[self.uv].uv = (co.y, co.z)
                    elif ax == 1:
                        l[self.uv].uv = (co.x, co.z)
                    else:
                        l[self.uv].uv = (co.x, co.y)
        return faces

    def box(self, x0, y0, z0, x1, y1, z1, m):
        """Caixa alinhada aos eixos entre dois cantos."""
        x0, x1 = min(x0, x1), max(x0, x1); y0, y1 = min(y0, y1), max(y0, y1); z0, z1 = min(z0, z1), max(z0, z1)
        r = bmesh.ops.create_cube(self.bm, size=1)
        vs = r['verts']
        for v in vs:
            v.co = Vector((x0 if v.co.x < 0 else x1, y0 if v.co.y < 0 else y1, z0 if v.co.z < 0 else z1))
        faces = list({f for v in vs for f in v.link_faces})
        for f in faces:
            f.normal_update()
        return self._finish(faces, m)

    def quad(self, pts, m, uvrect=None):
        """Quadrilátero (para vidros: UV 0..1 em X/Z via uvrect)."""
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.normal_update()
        return self._finish([f], m, 'rect' if uvrect else 'box', uvrect)

    def quad_uv(self, pts, uvs, m):
        """Quadrilátero com UV explícito por vértice (cartões de folhagem)."""
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        f = self.bm.faces.new(vs)
        f.normal_update()
        f.material_index = self._mi(m)
        for l, uv in zip(f.loops, uvs):
            l[self.uv].uv = uv
        return f

    def cyl(self, a, b, r0, r1=None, m='metal', seg=16, caps=True):
        """Cilindro (ou tronco de cone) do ponto a ao ponto b."""
        r1 = r0 if r1 is None else r1
        a, b = Vector(a), Vector(b)
        d = b - a
        res = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=d.length)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        bmesh.ops.transform(self.bm, matrix=Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), verts=res['verts'])
        faces = list({f for v in res['verts'] for f in v.link_faces})
        for f in faces:
            f.normal_update()
        self._finish(faces, m)
        return res['verts']

    def tube(self, pts, r, m='metal', seg=8, joints=True):
        """Tubo passando por uma lista de pontos (corrimãos, braços de poste)."""
        for a, b in zip(pts, pts[1:]):
            self.cyl(a, b, r, r, m, seg)
        if joints:
            for p in pts[1:-1]:
                self.sphere(p[0], p[1], p[2], r, m, 1)

    def sphere(self, x, y, z, r, m, sub=2, scale=(1, 1, 1)):
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r)
        for v in res['verts']:
            v.co = Vector((v.co.x * scale[0] + x, v.co.y * scale[1] + y, v.co.z * scale[2] + z))
        faces = list({f for v in res['verts'] for f in v.link_faces})
        for f in faces:
            f.normal_update()
        self._finish(faces, m)
        return res['verts']

    def obj(self, bevel=0.0, seg=2, smooth_angle=35, loc=(0, 0, 0)):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        o = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(o)
        o.location = loc
        for p in me.polygons:
            p.use_smooth = True
        if bevel > 0:
            b = o.modifiers.new('bevel', 'BEVEL')
            b.width = bevel
            b.segments = seg
            b.limit_method = 'ANGLE'
            b.angle_limit = math.radians(30)
            b.harden_normals = True
            b.use_clamp_overlap = True
            b.miter_outer = 'MITER_ARC'
        o.modifiers.new('tri', 'TRIANGULATE').keep_custom_normals = True
        bpy.context.view_layer.objects.active = o
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        o.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
        o.select_set(False)
        return o


def subsurf(o, levels=2):
    m = o.modifiers.new('sub', 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    return m


def apply_all(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e:
            print('modifier', m.name, e)


def export(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_apply=True,
                              export_yup=True, export_tangents=True, export_materials='EXPORT')
    print('exportado', path)
