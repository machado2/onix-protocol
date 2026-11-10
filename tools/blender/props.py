"""Objetos de rua e de telhado do Protocolo Ônix, modelados por script.
Origem na base, frente voltada para -Y no Blender (vira +Z no Godot). Medidas em metros.
Uso: blender -b --factory-startup -P tools/blender/props.py -- godot/assets/kit/props.glb
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from lib import Part, reset, export


def lamp():
    """Poste de LED com braço curvo sobre a rua (a rua fica em -Y)."""
    P = Part('lamp')
    P.box(-.2, -.2, 0, .2, .2, .55, 'concrete')
    P.cyl((0, 0, .55), (0, 0, .7), .16, .11, 'metal_dark', 20)
    P.cyl((0, 0, .7), (0, 0, 7.0), .1, .065, 'metal_dark', 20)
    pts = [(0, 0, 6.6)]
    for k in range(1, 9):
        a = k / 8 * math.pi / 2
        pts.append((0, -(1 - math.cos(a)) * .9, 6.6 + math.sin(a) * .55))
    pts.append((0, -1.95, 7.18))
    P.tube(pts, .045, 'metal_dark', 10)
    P.box(-.19, -2.55, 7.08, .19, -1.75, 7.24, 'metal_dark')
    P.box(-.16, -2.5, 7.21, .16, -1.8, 7.27, 'metal_dark')
    P.quad([(-.15, -2.48, 7.075), (-.15, -1.82, 7.075), (.15, -1.82, 7.075), (.15, -2.48, 7.075)], 'lamp_light')
    P.box(-.14, -.06, 2.6, .14, .06, 3.2, 'metal_dark')       # caixa de força
    return P.obj(bevel=.01)


def util_pole(name, transformer):
    """Poste de concreto com cruzetas, isoladores e (opcional) transformador. Os fios são feitos no Godot."""
    P = Part(name)
    P.cyl((0, 0, 0), (0, 0, 10.5), .17, .09, 'concrete', 4)
    for z, half in ((9.9, 1.0), (8.9, .8)):
        P.box(-half, -.06, z - .1, half, .06, z, 'concrete')
        for x in (-half + .12, 0.0 if half > .9 else None, half - .12):
            if x is None:
                continue
            P.cyl((x, 0, z), (x, 0, z + .14), .035, .025, 'ceramic', 8)
            P.sphere(x, 0, z + .15, .035, 'ceramic', 1)
    P.box(-.5, -.05, 7.4, .5, .05, 7.48, 'metal_dark')         # suporte de cabos de telefone
    for k in range(5):
        P.cyl((-.4 + k * .2, -.08, 7.2), (-.4 + k * .2, -.08, 7.6), .025, m='cable', seg=6)
    if transformer:
        P.cyl((.38, 0, 6.2), (.38, 0, 7.3), .3, m='transformer', seg=20)
        P.cyl((.38, 0, 7.3), (.38, 0, 7.36), .32, .26, 'transformer', 20)
        for k in range(3):
            P.cyl((.25 + k * .13, 0, 7.36), (.25 + k * .13, 0, 7.55), .03, m='ceramic', seg=8)
        P.box(.08, -.12, 6.6, .14, .12, 6.9, 'metal_dark')
    return P.obj(bevel=.008)


def traffic():
    """Semáforo de braço sobre a rua (a rua fica em -Y), com grupo focal de três luzes."""
    P = Part('traffic')
    P.cyl((0, 0, 0), (0, 0, .2), .16, .13, 'metal_dark', 16)
    P.cyl((0, 0, .2), (0, 0, 5.6), .09, .075, 'metal_dark', 16)
    P.tube([(0, 0, 5.4), (0, -4.2, 5.4)], .06, 'metal_dark', 12, False)
    P.tube([(0, 0, 4.7), (0, -1.6, 5.4)], .03, 'metal_dark', 8, False)
    P.box(-.2, -3.9, 4.25, .2, -3.62, 5.38, 'metal_dark')
    for i, (z, m) in enumerate(((5.1, 'tl_red'), (4.8, 'tl_amber'), (4.5, 'tl_green'))):
        P.cyl((0, -3.9, z), (0, -3.92, z), .12, m=m, seg=20, caps=True)
        # pala
        P.box(-.15, -4.14, z + .1, .15, -3.9, z + .14, 'metal_dark')
    # semáforo de pedestre no poste
    P.box(-.16, -.32, 2.4, .16, -.1, 3.1, 'metal_dark')
    P.quad([(-.12, -.321, 2.78), (.12, -.321, 2.78), (.12, -.321, 3.04), (-.12, -.321, 3.04)], 'tl_red')
    P.quad([(-.12, -.321, 2.46), (.12, -.321, 2.46), (.12, -.321, 2.72), (-.12, -.321, 2.72)], 'tl_off')
    return P.obj(bevel=.008)


def bench():
    P = Part('bench')
    for x in (-.75, .75):
        P.box(x - .05, -.25, 0, x + .05, .25, .42, 'concrete')
    for k in range(5):
        y = -.22 + k * .11
        P.box(-.95, y, .42, .95, y + .085, .47, 'wood')
    for k in range(3):
        z = .62 + k * .13
        P.box(-.95, .27, z, .95, .3, z + .1, 'wood')
    for x in (-.75, .75):
        P.box(x - .03, .24, .42, x + .03, .28, .96, 'metal_dark')
    return P.obj(bevel=.008)


def bollard():
    P = Part('bollard')
    P.cyl((0, 0, 0), (0, 0, .85), .09, .085, 'metal_dark', 16)
    P.sphere(0, 0, .85, .085, 'metal_dark', 2, (1, 1, .5))
    P.cyl((0, 0, .66), (0, 0, .72), .092, m='reflector', seg=16)
    return P.obj(bevel=.004)


def bin_():
    P = Part('bin')
    P.cyl((0, 0, 0), (0, 0, .82), .22, .25, 'bin', 20)
    P.cyl((0, 0, .82), (0, 0, .86), .26, .26, 'bin', 20)
    P.cyl((0, 0, .02), (0, 0, 1.0), .03, m='metal_dark', seg=8)
    return P.obj(bevel=.006)


def hydrant():
    P = Part('hydrant')
    P.cyl((0, 0, 0), (0, 0, .08), .17, .15, 'hydrant', 16)
    P.cyl((0, 0, .08), (0, 0, .6), .12, .11, 'hydrant', 16)
    P.sphere(0, 0, .6, .11, 'hydrant', 2, (1, 1, .7))
    P.cyl((0, 0, .66), (0, 0, .74), .03, m='hydrant', seg=8)
    for a in (0, math.pi):
        P.cyl((math.cos(a) * .1, 0, .42), (math.cos(a) * .2, 0, .42), .05, m='hydrant', seg=10)
    P.cyl((0, -.1, .34), (0, -.2, .34), .065, m='hydrant', seg=12)
    return P.obj(bevel=.004)


def ac_unit():
    """Ar-condicionado de janela/parede; a parede fica em Y=0, o aparelho avança para -Y."""
    P = Part('ac')
    P.box(-.42, -.36, 0, .42, -.02, .52, 'ac')
    P.cyl((.1, -.36, .26), (.1, -.375, .26), .2, m='grill', seg=24)
    for k in range(7):
        P.box(-.38, -.37, .08 + k * .055, -.16, -.355, .1 + k * .055, 'grill')
    for x in (-.36, .36):
        P.tube([(x, 0, -.25), (x, -.34, -.02)], .015, 'metal_dark', 6, False)
        P.box(x - .02, -.34, -.03, x + .02, -.02, 0, 'metal_dark')
    P.tube([(.3, -.05, .02), (.3, -.05, -.6)], .012, 'cable', 6, False)   # dreno
    return P.obj(bevel=.01)


def water_tank():
    """Caixa-d'água de fibra azul sobre base de concreto."""
    P = Part('tank')
    P.box(-.75, -.75, 0, .75, .75, .25, 'concrete')
    P.cyl((0, 0, .25), (0, 0, 1.05), .58, .7, 'tank', 32)
    P.cyl((0, 0, 1.05), (0, 0, 1.1), .73, .73, 'tank', 32)
    P.cyl((0, 0, 1.1), (0, 0, 1.24), .7, .5, 'tank', 32)
    P.tube([(.55, 0, .4), (.9, 0, .4), (.9, 0, .25)], .03, 'pipe', 8)
    return P.obj(bevel=.01)


def roof_box():
    """Casa de máquinas / saída de escada no telhado."""
    P = Part('roofbox')
    P.box(0, 0, 0, 2.6, 2.2, 2.4, 'concrete')
    P.box(-.08, -.08, 2.4, 2.68, 2.28, 2.5, 'concrete')
    P.box(.9, -.02, 0, 1.8, .05, 2.05, 'door')
    P.box(1.25, -.06, 2.1, 1.45, -.02, 2.2, 'lamp_light')
    return P.obj(bevel=.015)


def antenna():
    P = Part('antenna')
    P.cyl((0, 0, 0), (0, 0, 4.2), .035, .02, 'metal', 8)
    for k in range(5):
        z = 2.4 + k * .4
        w = .9 - k * .14
        P.cyl((-w / 2, 0, z), (w / 2, 0, z), .01, m='metal', seg=6)
        for x in (-w / 2, w / 2):
            P.cyl((x, -.15, z), (x, .15, z), .008, m='metal', seg=6)
    for a in (0, 2.1, 4.2):
        P.tube([(0, 0, 3.0), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0)], .004, 'cable', 4, False)
    P.sphere(0, 0, 4.25, .05, 'beacon', 1)
    return P.obj()


def dish():
    P = Part('dish')
    P.cyl((0, 0, 0), (0, 0, .9), .04, m='metal', seg=10)
    P.sphere(0, -.18, 1.05, .45, 'dish', 2, (1, .18, 1))
    P.tube([(0, -.25, 1.05), (0, -.6, 1.05)], .015, 'metal', 6, False)
    P.box(-.05, -.66, 1.0, .05, -.58, 1.1, 'metal_dark')
    return P.obj(bevel=.004)


def vending():
    P = Part('vending')
    P.box(-.45, -.4, 0, .45, .4, 1.95, 'vend_body')
    P.quad([(-.4, -.401, .55), (.25, -.401, .55), (.25, -.401, 1.85), (-.4, -.401, 1.85)], 'vend_glass')
    P.box(.28, -.42, .9, .42, -.4, 1.3, 'metal_dark')
    P.box(-.4, -.42, .15, .25, -.38, .4, 'metal_dark')
    return P.obj(bevel=.01)


def newsstand():
    """Banca de jornal: caixa de chapa verde com toldo e vitrine acesa na frente."""
    P = Part('banca')
    P.box(-1.3, -1.0, 0, 1.3, 1.0, .25, 'concrete')
    P.box(-1.25, -.95, .25, 1.25, .95, 2.45, 'kiosk')
    P.quad([(-1.15, -.951, .9), (1.15, -.951, .9), (1.15, -.951, 2.2), (-1.15, -.951, 2.2)], 'shopglass')
    P.box(-1.5, -1.6, 2.45, 1.5, 1.15, 2.55, 'kiosk')
    P.box(-1.5, -1.6, 2.55, 1.5, -1.5, 2.85, 'sign')
    for x in (-1.2, 1.2):
        P.box(x - .02, -1.0, .25, x + .02, -.95, 2.45, 'metal_dark')
    return P.obj(bevel=.012)


def jersey():
    P = Part('jersey')
    P.box(-1.0, -.3, 0, 1.0, .3, .22, 'concrete')
    P.box(-1.0, -.22, .22, 1.0, .22, .45, 'concrete')
    P.box(-1.0, -.12, .45, 1.0, .12, .8, 'concrete')
    P.box(-1.0, -.125, .62, 1.0, .125, .7, 'paint_stripe')
    return P.obj(bevel=.03, seg=3)


def barrel():
    P = Part('barrel')
    P.cyl((0, 0, 0), (0, 0, .88), .29, m='barrel', seg=28)
    for z in (.02, .29, .59, .86):
        P.cyl((0, 0, z - .015), (0, 0, z + .015), .3, m='barrel', seg=28)
    P.cyl((.15, 0, .88), (.15, 0, .9), .03, m='metal_dark', seg=8)
    return P.obj(bevel=.004)


def crates():
    P = Part('crates')
    P.box(-.6, -.5, 0, .6, .5, .14, 'wood')
    for (x, y, z, s) in ((-.3, -.2, .14, .5), (.28, -.2, .14, .5), (0, .2, .14, .45), (-.05, -.05, .64, .45)):
        P.box(x - s / 2, y - s / 2, z, x + s / 2, y + s / 2, z + s * .9, 'cardboard')
    return P.obj(bevel=.01)


def trash_bags():
    P = Part('bags')
    for (x, y, s) in ((0, 0, .32), (.38, .1, .28), (-.3, .2, .3), (.1, .35, .25)):
        P.sphere(x, y, s * .8, s, 'bag', 2, (1, 1.05, .85))
        P.cyl((x, y, s * 1.5), (x, y, s * 1.75), .05, .02, 'bag', 8)
    return P.obj()


def dumpster():
    """Caçamba de entulho."""
    P = Part('dumpster')
    P.box(-1.6, -.85, .1, 1.6, .85, .2, 'dumpster')
    P.box(-1.75, -1.0, .2, -1.6, 1.0, 1.15, 'dumpster')
    P.box(1.6, -1.0, .2, 1.75, 1.0, 1.15, 'dumpster')
    P.box(-1.6, -1.0, .2, 1.6, -.85, 1.15, 'dumpster')
    P.box(-1.6, .85, .2, 1.6, 1.0, 1.15, 'dumpster')
    P.box(-1.5, -.8, .2, 1.5, .8, .75, 'rubble')
    for x in (-1.2, 1.2):
        P.box(x - .08, -.9, 0, x + .08, .9, .1, 'metal_dark')
    return P.obj(bevel=.015)


def sign_box():
    """Caixa de letreiro horizontal genérica (2,4 x 0,8 m), o texto vem do Godot."""
    P = Part('signbox')
    P.box(-1.2, -.18, 0, 1.2, 0, .8, 'sign')
    for x in (-.9, .9):
        P.box(x - .03, -.02, .3, x + .03, .25, .4, 'metal_dark')
    return P.obj(bevel=.01)


def clothesline():
    """Varal com roupas entre dois suportes de parede (2,6 m), para fachadas da favela."""
    P = Part('clothes')
    for x in (-1.3, 1.3):
        P.tube([(x, 0, 0), (x, -.5, 0)], .012, 'metal_dark', 6, False)
    P.tube([(-1.3, -.45, 0), (1.3, -.45, 0)], .004, 'cable', 4, False)
    cols = ('cloth_a', 'cloth_b', 'cloth_c', 'cloth_a', 'cloth_c')
    for k, m in enumerate(cols):
        x = -1.0 + k * .5
        h = .5 + (k % 3) * .12
        P.box(x - .17, -.46, -h, x + .17, -.44, 0, m)
    return P.obj()


if __name__ == '__main__':
    out = sys.argv[sys.argv.index('--') + 1]
    reset()
    lamp(); util_pole('pole', False); util_pole('pole_tr', True); traffic(); bench(); bollard(); bin_(); hydrant()
    ac_unit(); water_tank(); roof_box(); antenna(); dish(); vending(); newsstand(); jersey(); barrel(); crates()
    trash_bags(); dumpster(); sign_box(); clothesline()
    export(out)
