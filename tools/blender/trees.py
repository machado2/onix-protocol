"""Árvores do Protocolo Ônix: tronco e galhos recursivos (cilindros afunilados) e copa de cartões de folhagem
com a textura leaf_a.png (alfa recortado no Godot). Uso: blender -b --factory-startup -P tools/blender/trees.py -- saída.glb
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from mathutils import Vector, Matrix
from lib import Part, reset, export


def tree(name, seed, height, spread, depth=3, cards=6, card_size=1.9, lean=.15):
    rnd = random.Random(seed)
    P = Part(name)

    def card(c, size):
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-.2, 1.2))).normalized()
        t = n.cross(Vector((0, 0, 1)))
        if t.length < .1:
            t = Vector((1, 0, 0))
        t.normalize()
        b = n.cross(t).normalized()
        rot = rnd.uniform(0, math.tau)
        t, b = t * math.cos(rot) + b * math.sin(rot), b * math.cos(rot) - t * math.sin(rot)
        h = size / 2
        pts = [c - t * h - b * h, c + t * h - b * h, c + t * h + b * h, c - t * h + b * h]
        P.quad_uv(pts, [(0, 0), (1, 0), (1, 1), (0, 1)], 'leaf')

    def branch(p, d, length, r, lvl):
        e = p + d * length
        P.cyl(p, e, r, r * .72, 'bark', 10 if lvl > 1 else 7, caps=False)
        if lvl == 0:
            for k in range(cards):
                off = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-.4, .8))) * card_size * .35
                card(e + off, card_size * rnd.uniform(.8, 1.2))
            return
        kids = 2 if lvl == depth else rnd.choice((2, 3, 3))
        for k in range(kids):
            az = rnd.uniform(0, math.tau) if lvl == depth else math.atan2(d.y, d.x) + rnd.uniform(-1.3, 1.3)
            el = rnd.uniform(.35, .8) * spread
            nd = Vector((math.cos(az) * math.sin(el), math.sin(az) * math.sin(el), math.cos(el)))
            nd = (nd * .75 + d * .25).normalized()
            branch(e, nd, length * rnd.uniform(.62, .78), r * .62, lvl - 1)
        # cartões ao longo do galho também, para encher a copa
        if lvl == 1:
            for k in range(2):
                card(p + d * length * rnd.uniform(.4, 1), card_size * .9)

    trunk_h = height * .38
    d0 = Vector((rnd.uniform(-lean, lean), rnd.uniform(-lean, lean), 1)).normalized()
    P.cyl((0, 0, -.2), (0, 0, .25), .32, .24, 'bark', 12, caps=False)     # raiz alargada
    branch(Vector((0, 0, .2)), d0, trunk_h, .24, depth)
    return P.obj(smooth_angle=60)


def palm(name, seed, height):
    """Palmeira: tronco anelado e coroa de folhas em cartões longos."""
    rnd = random.Random(seed)
    P = Part(name)
    segs = 14
    prev = Vector((0, 0, 0))
    bend = Vector((rnd.uniform(-.6, .6), rnd.uniform(-.6, .6), 0))
    for k in range(1, segs + 1):
        t = k / segs
        p = Vector((0, 0, height * t)) + bend * t * t
        P.cyl(prev, p, .2 - .06 * t, .2 - .06 * t, 'bark', 10, caps=False)
        P.cyl(p - Vector((0, 0, .04)), p, .21 - .06 * t, m='bark', seg=10, caps=False)
        prev = p
    top = prev
    for k in range(11):
        az = k / 11 * math.tau + rnd.uniform(-.2, .2)
        d = Vector((math.cos(az), math.sin(az), 0))
        L = rnd.uniform(2.6, 3.4)
        droop = rnd.uniform(.5, 1.1)
        side = Vector((-d.y, d.x, 0)) * .55
        a, b = top, top + d * L * .5 + Vector((0, 0, .3))
        c = top + d * L - Vector((0, 0, droop))
        for (p0, p1) in ((a, b), (b, c)):
            P.quad_uv([p0 - side, p0 + side, p1 + side, p1 - side], [(0, .5), (1, .5), (1, 1), (0, 1)] if p0 is a else [(0, 0), (1, 0), (1, .5), (0, .5)], 'leaf')
    return P.obj(smooth_angle=60)


if __name__ == '__main__':
    out = sys.argv[sys.argv.index('--') + 1]
    reset()
    tree('tree_a', 3, 8.5, 1.0, depth=3, cards=7, card_size=2.1)
    tree('tree_b', 11, 9.5, .75, depth=3, cards=6, card_size=1.9)
    tree('tree_c', 23, 6.5, 1.15, depth=3, cards=6, card_size=1.8, lean=.25)
    palm('palm', 5, 9.0)
    export(out)
