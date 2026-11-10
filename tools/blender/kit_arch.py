"""Kit modular de fachadas do Protocolo Ônix. Cada peça é um vão de 3 m x 3,2 m (um tile x um andar).
Estilos: A = concreto residencial, B = pele de vidro corporativa, C = tijolo e concreto (favela), G = térreo comercial.
Uso: blender -b --factory-startup -P tools/blender/kit_arch.py -- godot/assets/kit/arch.glb
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from lib import Part, reset, export

W, FH = 3.0, 3.2


def opening(P, x0, x1, z0, z1, m='wall', t0=0.0, t1=0.3, X0=0.0, X1=W, Z0=0.0, Z1=FH):
    """Parede de X0..X1 x Z0..Z1 com um vão retangular."""
    if x0 > X0: P.box(X0, t0, Z0, x0, t1, Z1, m)
    if x1 < X1: P.box(x1, t0, Z0, X1, t1, Z1, m)
    if z0 > Z0: P.box(x0, t0, Z0, x1, t1, z0, m)
    if z1 < Z1: P.box(x0, t0, z1, x1, t1, Z1, m)


def frame(P, x0, x1, z0, z1, y=0.12, d=0.06, b=0.055, mullions=(), transoms=(), m='frame'):
    P.box(x0, y, z0, x0 + b, y + d, z1, m)
    P.box(x1 - b, y, z0, x1, y + d, z1, m)
    P.box(x0, y, z0, x1, y + d, z0 + b, m)
    P.box(x0, y, z1 - b, x1, y + d, z1, m)
    for mx in mullions:
        P.box(mx - b / 2, y - .01, z0, mx + b / 2, y + d, z1, m)
    for tz in transoms:
        P.box(x0, y - .01, tz - b / 2, x1, y + d, tz + b / 2, m)


def glass(P, x0, x1, z0, z1, y, m='glass'):
    P.quad([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], m, uvrect=(x0, z0, x1, z1))


def band(P, m='trim', h=0.22, out=0.06):
    P.box(0, -out, 0, W, 0.02, h, m)


# ---------------------------------------------------------------- estilo A: concreto
def A_win():
    P = Part('A_win')
    opening(P, .7, 2.3, .9, 2.5)
    band(P)
    P.box(.62, -.07, .84, 2.38, .14, .9, 'trim')            # peitoril
    P.box(.66, -.03, 2.5, 2.34, .1, 2.58, 'trim')           # verga
    frame(P, .7, 2.3, .9, 2.5, mullions=(1.5,))
    glass(P, .7, 2.3, .9, 2.5, .15)
    return P.obj(bevel=.012)


def A_wall():
    P = Part('A_wall')
    P.box(0, 0, 0, W, .3, FH, 'wall')
    band(P)
    P.box(1.47, -.012, .22, 1.53, .0, FH, 'trim')           # junta de painel
    return P.obj(bevel=.01)


def A_vent():
    """Vão com janela basculante pequena (banheiro) e grelha de ventilação."""
    P = Part('A_vent')
    opening(P, 1.1, 1.9, 1.9, 2.5)
    band(P)
    P.box(1.04, -.06, 1.84, 1.96, .14, 1.9, 'trim')
    frame(P, 1.1, 1.9, 1.9, 2.5, transoms=(2.2,))
    glass(P, 1.1, 1.9, 1.9, 2.5, .15, 'glass_frost')
    for k in range(6):
        P.box(.35, -.04, .6 + k * .06, .75, .0, .63 + k * .06, 'frame')
    return P.obj(bevel=.008)


def A_balc():
    P = Part('A_balc')
    opening(P, .55, 2.45, .22, 2.6)
    P.box(0, -.04, 0, W, .02, .22, 'trim')
    frame(P, .55, 2.45, .22, 2.6, mullions=(1.5,), transoms=(2.3,))
    glass(P, .55, 2.45, .22, 2.6, .15)
    P.box(.06, -1.05, 0, 2.94, 0, .2, 'trim')                # laje da sacada
    P.box(.06, -1.05, -.04, 2.94, -.99, 0, 'trim')            # pingadeira
    # guarda-corpo de barras
    y = -.98
    P.tube([(.14, 0, 1.08), (.14, y, 1.08), (2.86, y, 1.08), (2.86, 0, 1.08)], .022, 'rail')
    P.tube([(.14, y, .32), (2.86, y, .32)], .015, 'rail', joints=False)
    for k in range(23):
        x = .14 + k * (2.72 / 22)
        P.cyl((x, y, .2), (x, y, 1.08), .009, m='rail', seg=6, caps=False)
    for k in range(1, 8):
        yy = y * k / 8
        for x in (.14, 2.86):
            P.cyl((x, yy, .2), (x, yy, 1.08), .009, m='rail', seg=6, caps=False)
    return P.obj(bevel=.01)


def A_corner():
    P = Part('A_corner')
    P.box(-.12, -.12, 0, .12, .12, FH, 'trim')
    return P.obj(bevel=.012)


# ---------------------------------------------------------------- estilo B: pele de vidro
def B_win():
    P = Part('B_win')
    P.box(0, .14, 0, W, .3, .9, 'spandrel')
    glass(P, 0, W, .9, FH, .12)
    glass(P, 0, W, 0, .9, .13, 'spandrel_glass')
    for x in (0, 1.5):
        P.box(x - .025 if x else 0, -.32, 0, x + .025 if x else .025, .12, FH, 'fin')   # aletas verticais
    P.box(0, -.04, .86, W, .12, .94, 'frame')
    P.box(0, -.04, 0, W, .12, .05, 'frame')
    return P.obj(bevel=.006)


def B_wall():
    P = Part('B_wall')
    P.box(0, .1, 0, W, .3, FH, 'frame')
    g = .012
    for (x0, x1) in ((0, 1.5), (1.5, 3)):
        for (z0, z1) in ((0, 1.6), (1.6, 3.2)):
            P.box(x0 + g, -.02, z0 + g, x1 - g, .1, z1 - g, 'panel')
    return P.obj(bevel=.005)


def B_corner():
    P = Part('B_corner')
    P.box(-.16, -.16, 0, .16, .16, FH, 'fin')
    return P.obj(bevel=.01)


# ---------------------------------------------------------------- estilo C: favela
def C_win():
    P = Part('C_win')
    P.box(0, -.05, 0, .24, .3, FH, 'trim')                    # pilar
    P.box(0, -.05, 2.92, W, .3, FH, 'trim')                   # viga
    opening(P, 1.0, 2.0, 1.15, 2.1, 'brick', .02, .3, .24, W, 0, 2.92)
    P.box(.96, -.04, 1.1, 2.04, .1, 1.15, 'trim')
    frame(P, 1.0, 2.0, 1.15, 2.1, y=.14, mullions=(1.5,), m='frame_rust')
    glass(P, 1.0, 2.0, 1.15, 2.1, .17)
    for k in range(6):                                        # grade
        x = 1.04 + k * .184
        P.box(x - .01, -.03, 1.12, x + .01, -.01, 2.13, 'rail')
    for z in (1.3, 1.9):
        P.box(.98, -.04, z - .01, 2.02, -.02, z + .01, 'rail')
    return P.obj(bevel=.008)


def C_wall():
    P = Part('C_wall')
    P.box(0, -.05, 0, .24, .3, FH, 'trim')
    P.box(0, -.05, 2.92, W, .3, FH, 'trim')
    P.box(.24, .02, 0, W, .3, 2.92, 'brick')
    return P.obj(bevel=.008)


def C_door():
    """Porta de aço com toldo de lona."""
    P = Part('C_door')
    P.box(0, -.05, 0, .24, .3, FH, 'trim')
    P.box(0, -.05, 2.92, W, .3, FH, 'trim')
    opening(P, .8, 1.9, 0, 2.2, 'brick', .02, .3, .24, W, 0, 2.92)
    P.box(.8, .1, 0, 1.9, .16, 2.2, 'shutter')
    P.box(.6, -.9, 2.35, 2.2, .02, 2.42, 'awning')
    return P.obj(bevel=.008)


def C_corner():
    P = Part('C_corner')
    P.box(-.13, -.13, 0, .13, .13, FH, 'trim')
    return P.obj(bevel=.008)


# ---------------------------------------------------------------- térreo comercial
def G_shop():
    P = Part('G_shop')
    P.box(0, -.06, 0, .26, .3, FH, 'trim')
    P.box(.26, .02, 2.62, W, .3, FH, 'wall')
    glass(P, .26, W, .02, 2.5, .1, 'shopglass')
    P.box(.26, .04, 0, W, .16, .02, 'frame')
    P.box(.26, .04, 2.48, W, .16, 2.56, 'frame')
    P.box(1.61, .04, .02, 1.66, .14, 2.5, 'frame')
    P.box(.12, -.32, 2.66, 2.94, -.02, 3.12, 'sign')          # caixa de luz do letreiro
    P.box(.26, -.12, 2.53, W, .06, 2.64, 'metal')             # caixa da porta de enrolar
    return P.obj(bevel=.008)


def G_shut():
    P = Part('G_shut')
    P.box(0, -.06, 0, .26, .3, FH, 'trim')
    P.box(.26, .02, 2.62, W, .3, FH, 'wall')
    P.box(.26, .02, 0, W, .1, 2.55, 'shutter')
    P.box(.12, -.32, 2.66, 2.94, -.02, 3.12, 'sign')
    P.box(.26, -.12, 2.53, W, .06, 2.64, 'metal')
    return P.obj(bevel=.008)


def G_lobby():
    """Entrada de prédio corporativo: vidro do chão ao teto com marquise."""
    P = Part('G_lobby')
    glass(P, 0, W, 0, FH - .1, .14, 'shopglass')
    P.box(0, .06, FH - .1, W, .3, FH, 'frame')
    for x in (0, 1.5):
        P.box(x, .06, 0, x + .05, .18, FH, 'frame')
    P.box(0, -1.6, 2.9, W, .02, 3.05, 'fin')                  # marquise
    return P.obj(bevel=.006)


# ---------------------------------------------------------------- topo
def parapet(name, m):
    P = Part(name)
    P.box(0, 0, 0, W, .25, .95, m)
    P.box(0, -.04, .95, W, .29, 1.0, 'frame')
    return P.obj(bevel=.008)


def ledge(name, m):
    """Faixa de coroamento entre o último andar e a platibanda."""
    P = Part(name)
    P.box(0, -.18, 0, W, .05, .3, m)
    return P.obj(bevel=.015)


if __name__ == '__main__':
    out = sys.argv[sys.argv.index('--') + 1]
    reset()
    for fn in (A_win, A_wall, A_vent, A_balc, A_corner, B_win, B_wall, B_corner, C_win, C_wall, C_door, C_corner,
               G_shop, G_shut, G_lobby):
        fn()
    parapet('A_parapet', 'wall'); parapet('B_parapet', 'panel'); parapet('C_parapet', 'brick')
    ledge('A_ledge', 'trim'); ledge('B_ledge', 'fin')
    export(out)
