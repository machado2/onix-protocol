"""Gera as texturas PBR do Protocolo Ônix por código (sem fotos nem pacotes de terceiros).

Tudo é periódico (ruído filtrado por FFT e Voronoi com wrap), então as texturas repetem sem emenda.
Saída por material, em godot/assets/tex/:
  <nome>_a.png   cor (sRGB)
  <nome>_n.png   normal (convenção OpenGL, Y+), como o Godot espera
  <nome>_orm.png R = oclusão, G = rugosidade, B = metal (ORMMaterial3D)
Uso: python tools/texgen/texgen.py [pasta de saída] [nome ...]
"""
import os, sys, struct, zlib, time
import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'tex')
ONLY = set(sys.argv[2:])


# ---------------------------------------------------------------- utilidades
def png(path, a):
    """Grava uint8 HxW, HxWx3 ou HxWx4 como PNG (sem dependências)."""
    a = np.ascontiguousarray(a)
    h, w = a.shape[:2]
    ch = 1 if a.ndim == 2 else a.shape[2]
    ct = {1: 0, 3: 2, 4: 6}[ch]
    raw = np.zeros((h, w * ch + 1), np.uint8)
    raw[:, 1:] = a.reshape(h, w * ch)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, ct, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(raw.tobytes(), 6)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def norm01(x):
    x = x - x.min()
    return x / (x.max() + 1e-9)


def fbm(S, rng, lo=2, hi=None, beta=2.0, aniso=(1, 1)):
    """Ruído fractal periódico: espectro ~ 1/f^beta entre as frequências lo e hi (ciclos por textura)."""
    hi = hi or S // 2
    fx = np.fft.fftfreq(S) * S * aniso[0]
    fy = np.fft.rfftfreq(S) * S * aniso[1]
    f = np.sqrt(fx[:, None] ** 2 + fy[None, :] ** 2)
    amp = np.where((f >= lo) & (f <= hi), 1.0 / np.maximum(f, 1e-6) ** (beta / 2), 0)
    ph = rng.standard_normal((S, S // 2 + 1)) + 1j * rng.standard_normal((S, S // 2 + 1))
    n = np.fft.irfft2(ph * amp, s=(S, S))
    return norm01(n).astype(np.float32)


def voronoi(S, cells, rng, jitter=1.0):
    """Voronoi periódico com um ponto por célula. Devolve F1, F2 (em unidades de célula) e o id da célula."""
    c = cells
    pts = (rng.random((c, c, 2)) - .5) * jitter + .5
    ids = rng.random((c, c)).astype(np.float32)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) * (c / S)
    ix, iy = np.floor(x).astype(np.int32), np.floor(y).astype(np.int32)
    fx, fy = x - ix, y - iy
    F1 = np.full((S, S), 9, np.float32); F2 = np.full((S, S), 9, np.float32); ID = np.zeros((S, S), np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx, cy = (ix + ox) % c, (iy + oy) % c
            p = pts[cy, cx]
            d = np.sqrt((ox + p[..., 0] - fx) ** 2 + (oy + p[..., 1] - fy) ** 2)
            closer = d < F1
            F2 = np.where(closer, F1, np.minimum(F2, d))
            ID = np.where(closer, ids[cy, cx], ID)
            F1 = np.where(closer, d, F1)
    return F1, F2, ID


def blur(a, r):
    """Desfoque periódico gaussiano (via FFT)."""
    S = a.shape[0]
    f = np.fft.fftfreq(S)
    g = np.exp(-(f[:, None] ** 2 + f[None, :] ** 2) * (2 * np.pi * r) ** 2 / 2)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)


def normal_from_height(h, strength):
    """h em [0,1]; strength = altura máxima em pixels."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * .5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * .5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * .5 + .5) * 255 + .5).clip(0, 255).astype(np.uint8)


def ao_from_height(h, r=6, k=2.5):
    return np.clip(1 - np.maximum(blur(h, r) - h, 0) * k, 0, 1)


def srgb(c):
    """Cor linear [0,1] -> uint8 sRGB."""
    c = np.clip(c, 0, 1)
    s = np.where(c <= .0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - .055)
    return (s * 255 + .5).astype(np.uint8)


def lin(hexcol):
    v = np.array([int(hexcol[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255
    return np.where(v <= .04045, v / 12.92, ((v + .055) / 1.055) ** 2.4)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def save(name, alb, h, rough, strength, metal=None, ao=None, ao_r=6, ao_k=2.5):
    S = h.shape[0]
    if ao is None:
        ao = ao_from_height(h, ao_r, ao_k)
    metal = np.zeros((S, S), np.float32) if metal is None else metal
    png(os.path.join(OUT, name + '_a.png'), srgb(alb * ao[..., None] ** .5))
    png(os.path.join(OUT, name + '_n.png'), normal_from_height(h, strength))
    orm = np.stack([ao, np.clip(rough, .02, 1), metal], -1)
    png(os.path.join(OUT, name + '_orm.png'), (orm * 255 + .5).astype(np.uint8))


# ---------------------------------------------------------------- materiais
def asphalt(S=2048, seed=1):
    """Asfalto gasto: agregado, remendos de piche, rachaduras, óleo. Representa 4 m."""
    r = np.random.default_rng(seed)
    base = fbm(S, r, 2, 64, 1.6)
    grain = fbm(S, r, 300, 1024, 0.0)
    F1, F2, ID = voronoi(S, 420, r, .9)              # pedras do agregado (~1 cm)
    stone = smooth(.45, .25, F1)
    F1b, F2b, _ = voronoi(S, 1000, r)                 # areia fina
    sand = smooth(.35, .1, F1b)
    # rachaduras: curvas de nível finas de um ruído médio, só em algumas regiões
    cn = fbm(S, r, 4, 90, 1.7)
    crack = smooth(.006, 0, np.abs(cn - .5)) * smooth(.58, .7, fbm(S, r, 2, 8, 2))
    crack = np.maximum(crack, smooth(.004, 0, np.abs(fbm(S, r, 10, 160, 1.5) - .5)) * smooth(.62, .72, fbm(S, r, 2, 8, 2)))
    patch = smooth(.62, .645, fbm(S, r, 2, 14, 2.0) + (fbm(S, r, 20, 200, 1.4) - .5) * .06)   # remendos de piche
    oil = smooth(.6, .85, fbm(S, r, 3, 50, 2.0) + (fbm(S, r, 30, 300, 1.3) - .5) * .15) * .6
    wear = fbm(S, r, 2, 20, 2)
    h = .5 * stone * (1 - patch) + .2 * sand + .12 * grain - .6 * crack + .08 * patch
    h = norm01(h)
    g = .05 + .025 * base + .03 * stone * (.3 + ID) * (1 - patch) + .01 * grain + .015 * wear
    g = g * (1 - .3 * patch) * (1 - .45 * oil) * (1 - .7 * crack)
    alb = np.stack([g * 1.0, g * .985, g * .965], -1)
    alb = mix(alb, alb * np.array([1.04, 1.0, .92]), oil)
    rough = .8 - .2 * stone * (1 - patch) - .2 * patch - .35 * oil + .06 * grain
    save('asphalt', alb, h, rough, 9)


def pavers(S=2048, seed=2):
    """Calçada de placas de concreto 50 cm (6x6 por textura = 3 m)."""
    r = np.random.default_rng(seed)
    n = 6
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) * (n / S)
    cx, cy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - cx, y - cy
    gap = .018
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    bevel = smooth(gap, gap + .03, edge)
    tone = r.random((n, n)).astype(np.float32)[cy % n, cx % n]
    chips = smooth(.5, .7, fbm(S, r, 20, 200, 1.5)) * (edge < .06)
    pores = smooth(.25, .05, voronoi(S, 600, r)[0]) * .5
    fine = fbm(S, r, 200, 1024, .5)
    stain = fbm(S, r, 2, 30, 2.2)
    h = norm01(bevel * (1 - chips * .7) - pores * .08 + fine * .05)
    agg = smooth(.4, .2, voronoi(S, 500, r)[0]) * .5
    v = .2 + .08 * tone + .05 * fine + .04 * agg - .09 * stain * stain
    v = v * (.35 + .65 * bevel)
    alb = np.stack([v * 1.0, v * .98, v * .95], -1)
    rough = .78 + .1 * fine - .25 * smooth(.6, .9, stain) - .1 * (1 - bevel)
    save('pavers', alb, h, rough, 12)


def concrete(S=2048, seed=3):
    """Concreto moldado de fachada, com poros, manchas e escorridos de chuva. 4 m."""
    r = np.random.default_rng(seed)
    mott = fbm(S, r, 2, 40, 2.0)
    fine = fbm(S, r, 120, 1024, .8)
    F1, _, _ = voronoi(S, 420, r)
    pore = smooth(.12, .02, F1) * (fbm(S, r, 4, 40, 2) > .45)
    streak = fbm(S, r, 3, 200, 1.6, aniso=(14, 1))   # escorridos verticais
    streak = smooth(.55, .85, streak)
    form = .5 + .5 * np.cos(np.mgrid[0:S, 0:S][0] / S * 2 * np.pi * 4)   # juntas de forma, fracas
    h = norm01(.25 * fine - .35 * pore + .15 * mott)
    v = .32 + .07 * mott + .012 * fine - .09 * streak - .03 * smooth(.97, 1, form) - .03 * pore
    alb = np.stack([v, v * .985, v * .96], -1)
    rough = .86 - .12 * streak + .06 * fine
    save('concrete', alb, h, rough, 3)


def plaster(S=2048, seed=4):
    """Reboco pintado (tingido no shader por prédio). Cor clara e quase neutra. 3 m."""
    r = np.random.default_rng(seed)
    bumps = fbm(S, r, 60, 700, 1.1)
    big = fbm(S, r, 2, 30, 2.2)
    peel = smooth(.74, .75, fbm(S, r, 3, 120, 1.7)) * smooth(.55, .7, fbm(S, r, 2, 8, 2))    # tinta descascando
    cracks = smooth(.005, 0, np.abs(fbm(S, r, 6, 120, 1.8) - .5)) * smooth(.66, .75, fbm(S, r, 2, 10, 2))
    h = norm01(bumps * .8 - peel * .3 - cracks * .5)
    v = .62 + .08 * big + .04 * bumps
    alb = np.stack([v, v, v], -1)
    alb = mix(alb, np.array(lin('#8a8478')) * (.8 + .4 * big[..., None]), peel)
    alb = alb * (1 - .5 * cracks)[..., None]
    rough = .9 - .1 * big
    save('plaster', alb, h, rough, 7)


def brick(S=2048, seed=5):
    """Tijolo baiano/aparente com argamassa irregular. 2,4 m."""
    r = np.random.default_rng(seed)
    rows, cols = 32, 10
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    ry = y / S * rows
    row = np.floor(ry).astype(int)
    rx = x / S * cols + (row % 2) * .5
    col = np.floor(rx).astype(int) % cols
    fx, fy = rx - np.floor(rx), ry - row
    warp = fbm(S, r, 10, 120, 1.5) - .5
    m = np.minimum(np.minimum(fx * 3.2, (1 - fx) * 3.2), np.minimum(fy, 1 - fy)) + warp * .06
    body = smooth(.06, .12, m)
    tone = r.random((rows, cols)).astype(np.float32)[row % rows, col]
    burn = r.random((rows, cols)).astype(np.float32)[row % rows, col]
    fine = fbm(S, r, 150, 1024, .8)
    dirt = fbm(S, r, 2, 30, 2)
    chip = smooth(.62, .7, fbm(S, r, 30, 300, 1.4)) * (m < .2)
    h = norm01(body * (1 - .8 * chip) + fine * .1)
    bc = mix(np.array(lin('#9a4a30')), np.array(lin('#b8683e')), tone)
    bc = mix(bc, np.array(lin('#5a2a1e')), smooth(.8, 1, burn) * .7)
    mort = np.array(lin('#8c857a'))[None, None] * (.8 + .3 * fine[..., None])
    alb = mix(mort, bc * (.85 + .3 * fine[..., None]), body * (1 - chip))
    alb = alb * (1 - .35 * dirt)[..., None]
    rough = .85 + .1 * fine - .1 * body
    save('brick', alb, h, rough, 10)


def granite(S=2048, seed=6):
    """Piso de granito polido em placas de 1 m (4x4 = 4 m). Reflete o neon."""
    r = np.random.default_rng(seed)
    n = 4
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) * (n / S)
    cx, cy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - cx, y - cy
    edge = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    tile = smooth(.004, .008, edge)
    F1, _, ID = voronoi(S, 700, r, 1)
    spk = (ID > .8) * smooth(.4, .2, F1)
    blk = (ID < .25) * smooth(.45, .2, F1)
    fine = fbm(S, r, 300, 1024, .2)
    scuff = fbm(S, r, 3, 60, 2)
    tone = r.random((n, n)).astype(np.float32)[cy % n, cx % n]
    v = .1 + .03 * tone + .12 * spk - .05 * blk + .02 * fine
    alb = np.stack([v, v * .99, v * 1.02], -1) * tile[..., None] ** .3
    h = norm01(tile + fine * .02)
    rough = .18 + .35 * smooth(.5, .9, scuff) + .4 * (1 - tile)
    save('granite', alb, h, rough, 4)


def metal(S=1024, seed=7):
    """Metal pintado com riscos e pontos de ferrugem (postes, carros, caixas). 1,5 m. Tingido no shader."""
    r = np.random.default_rng(seed)
    big = fbm(S, r, 2, 30, 2)
    fine = fbm(S, r, 100, 512, .6)
    scr = smooth(.985, 1, fbm(S, r, 4, 300, .8, aniso=(1, 30)))  # riscos finos
    rust = smooth(.68, .76, fbm(S, r, 3, 120, 1.8))
    h = norm01(fine * .2 - scr * .5 + rust * .3)
    paint = np.full((S, S, 3), .6, np.float32) * (.9 + .15 * big[..., None])
    rc = np.array(lin('#6b3a1f')) * (.7 + .5 * fine[..., None])
    alb = mix(mix(paint, np.array(lin('#9a9a9a')), scr), rc, rust)
    rough = .45 + .1 * big - .2 * scr + .4 * rust
    met = np.clip(scr * .9, 0, 1)
    save('metal', alb, h, rough, 4, metal=met)


def galvanized(S=1024, seed=8):
    """Chapa galvanizada (telhas, dutos), com escorridos de ferrugem. 2 m."""
    r = np.random.default_rng(seed)
    F1, F2, ID = voronoi(S, 50, r)   # flor do zinco
    spang = ID * .5 + smooth(.03, 0, F2 - F1) * .3
    streak = smooth(.55, .9, fbm(S, r, 3, 200, 1.6, aniso=(12, 1)))
    rust = smooth(.62, .75, fbm(S, r, 3, 80, 1.8))
    fine = fbm(S, r, 100, 512, .6)
    v = .45 + .12 * spang + .04 * fine
    alb = mix(np.stack([v, v, v * 1.02], -1), np.array(lin('#7a4020')) * (.6 + .6 * fine[..., None]), np.clip(rust + streak * .5, 0, 1))
    h = norm01(fine * .3 + rust * .5)
    rough = .4 + .2 * spang + .4 * rust
    met = (1 - np.clip(rust + streak * .5, 0, 1)) * .9
    save('galvanized', alb, h, rough, 3, metal=met)


def soil(S=2048, seed=9):
    """Terra com grama falhada (canteiros e parques). 4 m."""
    r = np.random.default_rng(seed)
    big = fbm(S, r, 2, 20, 2.2)
    grassm = smooth(.38, .6, big + (fbm(S, r, 20, 200, 1.5) - .5) * .3)
    blades = fbm(S, r, 200, 1024, .3)
    F1, _, ID = voronoi(S, 300, r)
    peb = smooth(.35, .15, F1) * (ID > .7) * (1 - grassm)
    dirt = mix(np.array(lin('#3a2e22')), np.array(lin('#5a4836')), fbm(S, r, 10, 300, 1.4))
    dirt = mix(dirt, np.array(lin('#8a8070')), peb)
    gc = mix(np.array(lin('#25361a')), np.array(lin('#4c5a2c')), blades)
    gc = mix(gc, np.array(lin('#6a6338')), smooth(.55, .9, fbm(S, r, 3, 40, 2)) * .6)
    grassm = grassm * (.75 + .25 * smooth(.3, .7, fbm(S, r, 60, 500, 1)))
    alb = mix(dirt, gc, grassm)
    h = norm01(grassm * .3 + blades * grassm * .5 + peb * .6)
    rough = .95 - .05 * grassm
    save('soil', alb, h, rough, 8)


def roof(S=1024, seed=10):
    """Manta asfáltica de laje, com emendas e poças secas. 4 m."""
    r = np.random.default_rng(seed)
    big = fbm(S, r, 2, 20, 2)
    fine = fbm(S, r, 100, 512, .6)
    y = np.mgrid[0:S, 0:S][0] / S * 4
    seam = smooth(.02, 0, np.abs(y - np.round(y)))
    bubble = smooth(.7, .8, fbm(S, r, 8, 60, 2))
    v = .07 + .04 * big + .015 * fine + .04 * seam
    alb = np.stack([v, v * .99, v * .97], -1)
    h = norm01(seam * .6 + bubble * .4 + fine * .2)
    rough = .7 - .2 * smooth(.6, .9, big) + .1 * fine
    save('roof', alb, h, rough, 6)


def wood(S=1024, seed=12):
    """Madeira de ripas (bancos, paletes), veio ao longo de X. 1 m."""
    r = np.random.default_rng(seed)
    y = np.mgrid[0:S, 0:S][0].astype(np.float32) / S
    warp = fbm(S, r, 2, 40, 1.8, aniso=(1, 8)) - .5
    rings = .5 + .5 * np.sin((y * 38 + warp * 3) * 2 * np.pi)
    grain = fbm(S, r, 30, 512, 1.0, aniso=(1, 25))
    knots = smooth(.12, .02, voronoi(S, 6, r)[0]) * (fbm(S, r, 2, 8, 2) > .55)
    v = .55 + .2 * rings * .5 + .25 * grain
    base = np.array(lin('#6a4528'))
    alb = base[None, None] * v[..., None] * (1 - .5 * knots)[..., None]
    h = norm01(rings * .3 + grain * .5 - knots * .5)
    rough = .75 + .15 * grain
    save('wood', alb, h, rough, 5)


def bark(S=1024, seed=13):
    """Casca de árvore com fissuras verticais. 1,5 m."""
    r = np.random.default_rng(seed)
    f = fbm(S, r, 4, 300, 1.4, aniso=(10, 1))
    fis = smooth(.42, .3, f)
    fine = fbm(S, r, 60, 512, .8)
    moss = smooth(.6, .8, fbm(S, r, 2, 20, 2))
    alb = mix(np.array(lin('#5a4a3c')) * (.7 + .5 * fine[..., None]), np.array(lin('#1e1812')), fis)
    alb = mix(alb, np.array(lin('#3a4a22')), moss * .5)
    h = norm01(f * .8 + fine * .2)
    save('bark', alb, h, .9 - .05 * fine, 10)


def leaves(S=1024, seed=14):
    """Atlas de folhagem com alfa: um raminho denso de folhas ovais (cartões das copas)."""
    r = np.random.default_rng(seed)
    a = np.zeros((S, S), np.float32)
    col = np.zeros((S, S, 3), np.float32)
    hh = np.zeros((S, S), np.float32)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32) / S
    greens = [lin('#2f4a1a'), lin('#3e5a20'), lin('#4c6a26'), lin('#2a4020'), lin('#56702e')]
    for k in range(170):
        # folhas espalhadas num disco, maiores no centro
        ang = r.random() * 2 * np.pi
        rad = np.sqrt(r.random()) * .4
        cx, cy = .5 + np.cos(ang) * rad, .5 + np.sin(ang) * rad
        L = .05 + r.random() * .05
        Wd = L * (.38 + r.random() * .15)
        th = ang + (r.random() - .5) * 1.4
        dx, dy = x - cx, y - cy
        u = dx * np.cos(th) + dy * np.sin(th)
        v = -dx * np.sin(th) + dy * np.cos(th)
        t = np.clip(u / L, -1, 1)
        half = Wd * np.sqrt(np.clip(1 - t * t, 0, 1)) * (1 - .35 * t)
        inside = (np.abs(u) < L) & (np.abs(v) < half)
        dome = np.where(inside, np.sqrt(np.clip(1 - (v / np.maximum(half, 1e-4)) ** 2, 0, 1)), 0) * (1 - np.abs(t) * .3)
        rib = np.where(inside, smooth(.012, 0, np.abs(v)) * .3, 0)
        c = np.array(greens[r.integers(len(greens))]) * (.75 + .5 * r.random())
        sel = inside & (dome + k * 1e-3 > hh)
        col[sel] = c * (.75 + .35 * dome[sel, None]) * (1 + rib[sel, None])
        hh = np.where(sel, dome * .8 + k * 1e-3, hh)
        a = np.maximum(a, inside.astype(np.float32))
    a = np.where(a > .5, 1.0, 0.0)
    rgba = np.concatenate([srgb(col), (a[..., None] * 255).astype(np.uint8)], -1)
    png(os.path.join(OUT, 'leaf_a.png'), rgba)
    png(os.path.join(OUT, 'leaf_n.png'), normal_from_height(blur(hh, 1.5), 40))


def grime(S=1024, seed=11):
    """Máscaras em escala de cinza para o shader: R = sujeira manchada, G = escorridos, B = poças."""
    r = np.random.default_rng(seed)
    a = fbm(S, r, 2, 60, 2.0)
    b = smooth(.5, .85, fbm(S, r, 3, 200, 1.6, aniso=(12, 1)))
    c = fbm(S, r, 2, 24, 2.4)
    png(os.path.join(OUT, 'grime.png'), (np.stack([a, b, c], -1) * 255 + .5).astype(np.uint8))


ALL = [asphalt, pavers, concrete, plaster, brick, granite, metal, galvanized, soil, roof, wood, bark, leaves, grime]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for fn in ALL:
        if ONLY and fn.__name__ not in ONLY:
            continue
        t = time.time()
        fn()
        print(f'{fn.__name__}: {time.time() - t:.1f}s', flush=True)
