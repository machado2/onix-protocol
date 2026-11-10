"""Carros do Protocolo Ônix: carroceria feita por seções transversais (loft) ao longo do comprimento,
suavizada por subdivisão, com caixas de roda, vidros, faróis e lanternas definidos por região.
Frente em -Y no Blender (vira +Z no Godot). A cor da pintura é aplicada no Godot.
Uso: blender -b --factory-startup -P tools/blender/cars.py -- godot/assets/kit/cars.glb
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy, bmesh
from mathutils import Vector
from lib import Part, reset, export, mat, subsurf, apply_all


def interp(keys, y):
    for (y0, v0), (y1, v1) in zip(keys, keys[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0) if y1 > y0 else 0
            t = t * t * (3 - 2 * t) * .35 + t * .65
            return v0 + (v1 - v0) * t
    return keys[0][1] if y < keys[0][0] else keys[-1][1]


def body(name, spec):
    L = spec['L']
    top, bot, wid = spec['top'], spec['bot'], spec['w']
    belt, roof_z, wr = spec['belt'], spec['roof'], spec['wr']
    S, R = 36, 24
    bm = bmesh.new()
    rings = []
    for i in range(S):
        t = i / (S - 1)
        t = .5 - .5 * math.cos(t * math.pi)          # mais estações nas pontas
        y = -L / 2 + t * L
        zt, zb, w = interp(top, y), interp(bot, y), interp(wid, y)
        ring = []
        for j in range(R):
            th = -math.pi / 2 + j / R * 2 * math.pi
            c, s = math.cos(th), math.sin(th)
            n = 5.0
            u = math.copysign(abs(c) ** (2 / n), c)
            v = math.copysign(abs(s) ** (2 / n), s)
            z = zb + (v + 1) / 2 * (zt - zb)
            hw = w if z <= belt else w + (wr - w) * min(1, (z - belt) / max(roof_z - belt, .05))
            ring.append(bm.verts.new((u * hw, y, z)))
        rings.append(ring)
    faces = []
    for i in range(S - 1):
        for j in range(R):
            a, b = rings[i][j], rings[i][(j + 1) % R]
            c, d = rings[i + 1][(j + 1) % R], rings[i + 1][j]
            faces.append(bm.faces.new((a, d, c, b)))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    faces.append(bm.faces.new(rings[-1]))
    bm.normal_update()
    names = ['paint', 'glass', 'headlight', 'taillight', 'grille', 'trim_dark']
    kill = []
    for f in bm.faces:
        cc = f.calc_center_median()
        x, y, z = abs(cc.x), cc.y, cc.z
        m = 'paint'
        for (y0, y1, side_only) in spec['glass']:
            if y0 <= y <= y1 and belt + .04 < z < roof_z - .03 and (not side_only or x > wr * .8):
                if not side_only and x > wr * .92:
                    continue                          # coluna A/C
                if any(abs(y - p) < .06 for p in spec.get('pillars', ())):
                    continue
                m = 'glass'
        fy, ry = -L / 2, L / 2
        if y < fy + .14 and spec['head'][0] < z < spec['head'][1] and .42 < x < spec['w'][len(spec['w']) // 2][1] - .1:
            m = 'headlight'
        if y > ry - .14 and spec['tail'][0] < z < spec['tail'][1] and .38 < x:
            m = 'taillight'
        if y < fy + .12 and .36 < z < spec['head'][0] - .02 and x < .5:
            m = 'grille'
        if z < bot[len(bot) // 2][1] + .1:
            m = 'trim_dark'
        f.material_index = names.index(m)
        for wy in spec['wheels']:
            if x > .45 and (y - wy) ** 2 + (z - .35) ** 2 < .46 ** 2:
                kill.append(f)
    bmesh.ops.delete(bm, geom=list(set(kill)), context='FACES')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for n in names:
        me.materials.append(mat(n))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for p in me.polygons:
        p.use_smooth = True
    subsurf(o, 2)
    apply_all(o)
    return o


def extras(name, spec, kind):
    P = Part(name + '_x')
    W = spec['w'][len(spec['w']) // 2][1]
    for wy in spec['wheels']:
        for s in (-1, 1):
            xo = s * (W - .02)
            xi = s * (W - .25)
            P.cyl((xi, wy, .34), (xo, wy, .34), .34, m='tire', seg=28)
            P.cyl((xo, wy, .34), (xo + s * .01, wy, .34), .23, m='rim', seg=24)
            for k in range(5):
                a = k / 5 * 2 * math.pi
                P.box(xo, wy + math.cos(a) * .2 - .025, .34 + math.sin(a) * .2 - .025, xo + s * .015, wy + math.cos(a) * .2 + .025, .34 + math.sin(a) * .2 + .025, 'rim')
            P.cyl((s * (W - .5), wy, .34), (s * (W + .01), wy, .34), .47, m='liner', seg=24, caps=False)
    L = spec['L']
    P.box(-.26, -L / 2 - .02, .4, .26, -L / 2 + .02, .52, 'plate')
    P.box(-.26, L / 2 - .02, .6, .26, L / 2 + .03, .72, 'plate')
    mz = spec['belt'] + .05
    my = spec['mirror']
    for s in (-1, 1):
        P.box(s * (W - .05), my - .06, mz, s * (W + .14), my + .06, mz + .13, 'paint')
    if kind == 'taxi':
        rz = spec['roof']
        P.box(-.32, .15, rz - .01, .32, .45, rz + .2, 'taxi_sign')
    if kind == 'police':
        rz = spec['roof']
        P.box(-.6, .05, rz - .01, .6, .3, rz + .04, 'trim_dark')
        P.box(-.58, .07, rz + .04, -.04, .28, rz + .14, 'police_red')
        P.box(.04, .07, rz + .04, .58, .28, rz + .14, 'police_blue')
    return P.obj(bevel=.006)


def car(name, spec, kind=''):
    b = body(name, spec)
    x = extras(name, spec, kind)
    apply_all(x)
    bpy.ops.object.select_all(action='DESELECT')
    b.select_set(True)
    x.select_set(True)
    bpy.context.view_layer.objects.active = b
    bpy.ops.object.join()
    b.name = name
    return b


SEDAN = dict(
    L=4.6, belt=.92, roof=1.42, wr=.66,
    top=[(-2.3, .62), (-2.2, .74), (-1.9, .82), (-1.15, .9), (-.95, .96), (-.3, 1.42), (.85, 1.42), (1.6, 1.0), (1.85, .96), (2.2, .9), (2.3, .72)],
    bot=[(-2.3, .34), (-2.15, .25), (-1.9, .22), (2.0, .22), (2.2, .27), (2.3, .36)],
    w=[(-2.3, .72), (-2.0, .86), (-1.4, .9), (1.4, .9), (2.0, .87), (2.3, .76)],
    glass=[(-.95, -.3, False), (-.3, .85, True), (.85, 1.62, False)], pillars=(.28,),
    head=(.56, .72), tail=(.68, .84), wheels=(-1.42, 1.38), mirror=-.9)

HATCH = dict(
    L=4.0, belt=.95, roof=1.46, wr=.66,
    top=[(-2.0, .62), (-1.9, .74), (-1.6, .83), (-.95, .9), (-.75, .98), (-.1, 1.46), (1.25, 1.44), (1.85, 1.08), (2.0, .8)],
    bot=[(-2.0, .34), (-1.85, .25), (-1.6, .22), (1.7, .22), (1.9, .28), (2.0, .38)],
    w=[(-2.0, .7), (-1.7, .84), (-1.1, .88), (1.2, .88), (1.8, .84), (2.0, .76)],
    glass=[(-.75, -.1, False), (-.1, 1.25, True), (1.25, 1.85, False)], pillars=(.45,),
    head=(.58, .74), tail=(.76, .94), wheels=(-1.25, 1.2), mirror=-.7)

VAN = dict(
    L=5.0, belt=1.05, roof=2.0, wr=.88,
    top=[(-2.5, .7), (-2.42, .9), (-2.25, 1.0), (-2.15, 1.08), (-1.65, 2.0), (2.45, 2.0), (2.5, 1.9)],
    bot=[(-2.5, .38), (-2.35, .28), (-2.1, .26), (2.3, .26), (2.5, .36)],
    w=[(-2.5, .85), (-2.2, .95), (2.3, .95), (2.5, .92)],
    glass=[(-2.15, -1.65, False), (-1.65, -.9, True)], pillars=(),
    head=(.62, .8), tail=(.85, 1.25), wheels=(-1.6, 1.65), mirror=-1.95)

if __name__ == '__main__':
    out = sys.argv[sys.argv.index('--') + 1]
    reset()
    car('sedan', SEDAN)
    car('hatch', HATCH)
    car('van', VAN)
    car('taxi', SEDAN, 'taxi')
    car('police', SEDAN, 'police')
    export(out)
