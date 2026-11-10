"""Gera os sons do Protocolo Ônix (porte offline da síntese WebAudio de v2/js/audio.js).

Efeitos com variações, ambiente (tráfego e zumbido, sem chuva), motor do carro e as seis camadas da
trilha dinâmica (pad, baixo, arpejo, chimbal, bumbo, caixa), todas em loop do mesmo tamanho.
Uso: python tools/sfxgen/sfxgen.py [pasta de saída]  (padrão: godot/assets/audio)
Só numpy: osciladores, biquads RBJ (os mesmos do WebAudio), envelopes e reverb por convolução FFT.
"""
import math
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "godot", "assets", "audio")
rng = np.random.default_rng(91)


# ---------------------------------------------------------------- blocos de síntese
def biquad_coefs(kind, f, q):
    f = min(max(f, 10.0), SR * .45)
    w = 2 * math.pi * f / SR
    cw, sw = math.cos(w), math.sin(w)
    if kind in ("lowpass", "highpass"):
        qq = max(.5, 10 ** (q / 20))      # no WebAudio o Q de passa-baixa/alta é em dB
    else:
        qq = max(.05, q)
    al = sw / (2 * qq)
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    else:  # bandpass (ganho constante no pico)
        b = [al, 0, -al]
    a = [1 + al, -2 * cw, 1 - al]
    return [x / a[0] for x in b], [1, a[1] / a[0], a[2] / a[0]]


def biquad(x, kind, f, q=1.0, f_end=None):
    """Filtro biquad; com f_end a frequência varia exponencialmente ao longo do sinal (em blocos)."""
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    n = len(x)
    blk = 64 if f_end else n
    for s in range(0, n, blk):
        ff = f * (f_end / f) ** (s / max(1, n - 1)) if f_end else f
        b, a = biquad_coefs(kind, ff, q)
        b0, b1, b2, a1, a2 = b[0], b[1], b[2], a[1], a[2]
        xs = x[s:s + blk]
        ys = y[s:s + blk]
        for i in range(len(xs)):
            xi = xs[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, xi, y1, yi
            ys[i] = yi
    return y


def osc(kind, f0, f1, n):
    t = np.arange(n) / SR
    dur = max(n / SR, 1e-6)
    f1 = max(20.0, f1)
    if abs(f1 - f0) < 1e-6:
        ph = f0 * t
    else:
        k = math.log(f1 / f0) / dur
        ph = f0 * (np.exp(k * t) - 1) / k
    ph = ph + rng.random()
    if kind == "sine":
        return np.sin(2 * math.pi * ph)
    fr = ph % 1.0
    if kind == "square":
        return np.where(fr < .5, 1.0, -1.0)
    if kind == "sawtooth":
        return 2 * fr - 1
    return 4 * np.abs(fr - .5) - 1  # triangle


def env_exp(n, vol, att=0.0):
    t = np.arange(n) / SR
    dur = n / SR
    e = vol * (0.0008 / max(vol, 1e-4)) ** (t / dur)
    if att > 0:
        na = min(n, int(att * SR))
        e[:na] = np.linspace(.0001, vol, na)
        rest = n - na
        if rest > 0:
            tr = np.arange(rest) / SR
            e[na:] = vol * (0.0008 / max(vol, 1e-4)) ** (tr / max(1e-6, (rest / SR)))
    return e


class Buf:
    def __init__(self, dur):
        self.x = np.zeros(int(dur * SR) + SR // 10)

    def add(self, sig, delay=0.0):
        s = int(delay * SR)
        e = min(len(self.x), s + len(sig))
        if e > s:
            self.x[s:e] += sig[:e - s]

    def tone(self, f0, f1, dur, vol, kind="square", delay=0.0, att=0.0):
        n = int(dur * SR)
        self.add(osc(kind, f0, f1, n) * env_exp(n, vol, att), delay)

    def noise(self, dur, freq, q, vol, kind="bandpass", delay=0.0, src=None):
        n = int(dur * SR)
        w = (src if src is not None else WHITE)
        o = rng.integers(0, len(w) - n - 1)
        sig = biquad(w[o:o + n].copy(), kind, freq, q)
        self.add(sig * env_exp(n, vol), delay)


WHITE = rng.random(SR * 8) * 2 - 1
_b = np.zeros(SR * 8)
_last = 0.0
_w = rng.random(SR * 8) * 2 - 1
for _i in range(len(_b)):
    _last = (_last + .02 * _w[_i]) / 1.02
    _b[_i] = _last * 3.5
BROWN = _b
_il = int(SR * 1.6)
IR = (rng.random(_il) * 2 - 1) * (1 - np.arange(_il) / _il) ** 3


def reverb(x, wet):
    if wet <= 0:
        return x
    n = len(x) + len(IR)
    m = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(IR, m), m)[:n]
    y *= .32 * wet / max(1e-6, np.sqrt(np.sum(IR ** 2)) * 6)
    out = np.zeros(n)
    out[:len(x)] = x
    return out + y


def trim(x):
    a = np.abs(x)
    thr = 10 ** (-62 / 20) * max(1e-6, a.max())
    idx = np.nonzero(a > thr)[0]
    return x[:idx[-1] + 1] if len(idx) else x


def save(name, x, norm=None, loop=False):
    os.makedirs(OUT, exist_ok=True)
    if norm:
        x = x / max(1e-6, np.abs(x).max()) * norm
    x = np.clip(x, -1, 1)
    p = os.path.join(OUT, name + ".wav")
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return p


# ---------------------------------------------------------------- efeitos (mesmas receitas da web, volume v=1)
def sfx(kind, vary):
    v = 1.0
    B = Buf(2.6)
    wet = 0.0
    if kind == "pist":
        wet = .35; B.tone(2200 * vary, 900, .012, .25); B.noise(.14, 1500 * vary, .7, .6); B.tone(130 * vary, 48, .11, .45, "sine")
    elif kind == "smg":
        wet = .25; B.tone(2600 * vary, 1200, .008, .18); B.noise(.075, 2100 * vary, .9, .42); B.tone(110, 50, .06, .25, "sine")
    elif kind == "shot":
        wet = .45; B.noise(.05, 4000, .5, .5, "highpass"); B.noise(.4, 800 * vary, .5, .9, "lowpass"); B.tone(95, 28, .3, .65, "sine")
    elif kind == "laser":
        wet = .4; B.tone(3200 * vary, 140, .35, .2, "sawtooth"); B.tone(1600, 70, .3, .14, "square"); B.tone(90, 40, .4, .35, "sine")
    elif kind == "flame":
        wet = .1; B.noise(.16, 420, .4, .38, "lowpass"); B.noise(.08, 2400, .6, .06)
    elif kind == "boom":
        wet = .7; B.noise(.06, 3500, .4, .7, "highpass"); B.noise(1.4, 300, .3, 1.2, "lowpass"); B.tone(70, 22, 1, .9, "sine"); B.noise(.9, 1200, .6, .15, "bandpass", .12)
    elif kind == "glass":
        wet = .35; B.noise(.25, 5200, .6, .35, "highpass")
        for i in range(4):
            B.tone(2800 + rng.random() * 3500, 2600 + rng.random() * 3000, .12 + rng.random() * .2, .03, "sine", .03 + i * .05)
    elif kind == "crash":
        wet = .5; B.noise(.6, 700, .5, .8, "lowpass"); B.tone(180, 90, .5, .15, "sawtooth"); B.tone(420, 300, .35, .08, "square", .05); B.noise(.4, 2500, 1.5, .12, "bandpass", .1)
    elif kind == "collapse":
        wet = .7; B.noise(1.8, 180, .4, 1, "lowpass", 0, BROWN); B.noise(1.2, 900, .5, .25, "lowpass", .15)
        for i in range(6):
            B.noise(.06, 1500 + rng.random() * 2000, 1, .12, "bandpass", .1 + i * .17)
    elif kind == "drone":
        wet = .1; B.tone(118 * vary, 124 * vary, .5, .03, "sawtooth"); B.tone(236 * vary, 230 * vary, .5, .012, "square")
    elif kind == "steam":
        wet = .15; B.noise(.9, 3400, .5, .2, "highpass"); B.noise(.7, 1100, .7, .1)
    elif kind == "train":
        wet = .3; B.noise(1.5, 140, .4, .55, "lowpass", 0, BROWN)
        for i in range(3):
            B.noise(.05, 900, 2, .12, "bandpass", .2 + i * .38)
    elif kind == "ric":
        wet = .4; B.tone(3400 * vary, 1300, .18, .07, "sine")
    elif kind == "hit":
        wet = .05; B.noise(.07, 600, 1, .3, "lowpass")
    elif kind == "die":
        wet = .1; B.noise(.2, 280, 1, .3, "lowpass")
    elif kind == "alarm":
        wet = .5
        for i in range(3):
            B.tone(880, 880, .14, .1, "square", i * .32); B.tone(620, 620, .14, .1, "square", i * .32 + .16)
    elif kind == "siren":
        wet = .5
        for i in range(2):
            B.tone(650, 1150, .4, .08, "triangle", i * .8); B.tone(1150, 650, .4, .08, "triangle", i * .8 + .4)
    elif kind == "ui":
        B.tone(1300, 1700, .05, .05)
    elif kind == "hack":
        wet = .2; B.tone(300, 1800, .45, .08); B.tone(1800, 2400, .15, .06, "square", .45)
    elif kind == "convert":
        wet = .6; B.tone(220, 880, .6, .08, "sine", 0, .1); B.tone(330, 1320, .6, .05, "triangle", .05, .1)
    elif kind == "pickup":
        B.tone(900, 1400, .07, .06, "square"); B.tone(1400, 1900, .07, .05, "square", .08)
    elif kind == "door":
        wet = .1; B.noise(.12, 240, 1.2, .4, "lowpass"); B.tone(110, 70, .1, .2, "sine")
    elif kind == "honk":
        wet = .4; B.tone(400, 392, .25, .07, "square"); B.tone(500, 492, .25, .05, "square")
    elif kind == "win":
        wet = .5
        for i, f in enumerate([523, 659, 784, 1046]):
            B.tone(f, f, .5, .08, "triangle", i * .14, .02)
    elif kind == "lose":
        wet = .5
        for i, f in enumerate([392, 330, 262, 196]):
            B.tone(f, f * .98, .5, .08, "triangle", i * .18, .02)
    elif kind == "squelch":
        B.noise(.05, 2600, 2, .12)
    # sons de ambiente (eventos distantes)
    elif kind == "amb_thunder":
        wet = .8; B = Buf(7); B.noise(4 + rng.random() * 2, 90, .5, 1.1, "lowpass", 0, BROWN); B.noise(.3, 500, .5, .25, "lowpass")
    elif kind == "amb_siren":
        wet = .8; B = Buf(4.5)
        for i in range(3):
            B.tone(600, 900, .6, .025, "triangle", i * 1.2, .2); B.tone(900, 600, .6, .025, "triangle", i * 1.2 + .6, .2)
    elif kind == "amb_horn":
        wet = .8; B = Buf(3); B.tone(90, 70, 2.5, .05, "sawtooth", 0, .8)
    x = B.x
    if kind.startswith("amb_"):
        x = biquad(x, "lowpass", 2500, 1)
    return trim(reverb(x, wet))


VARIANTS = {"pist": 4, "smg": 4, "shot": 3, "laser": 3, "flame": 3, "boom": 3, "glass": 2, "crash": 2, "collapse": 2, "drone": 1,
            "steam": 2, "train": 1, "ric": 3, "hit": 3, "die": 2, "alarm": 1, "siren": 1, "ui": 1, "hack": 1, "convert": 1, "pickup": 1,
            "door": 2, "honk": 1, "win": 1, "lose": 1, "squelch": 1, "amb_thunder": 2, "amb_siren": 1, "amb_horn": 1}


# ---------------------------------------------------------------- loops: ambiente e motor
def loop_wrap(x, n):
    """Dobra a cauda depois de n amostras para o começo, para o loop não ter emenda."""
    y = x[:n].copy()
    tail = x[n:]
    k = 0
    while k < len(tail):
        m = min(n, len(tail) - k)
        y[:m] += tail[k:k + m]
        k += m
    return y


def ambience():
    n = SR * 16
    src = np.concatenate([BROWN, BROWN[::-1], BROWN, BROWN[::-1]])[:n]
    traf = biquad(src, "lowpass", 160, 1) * .22
    hum = biquad(osc("sawtooth", 55, 55, n), "lowpass", 140, 1) * .018
    x = traf + hum
    f = int(SR * .5)
    x[:f] *= np.linspace(0, 1, f) ** .5
    x[-f:] *= np.linspace(1, 0, f) ** .5
    head = x[:f].copy()
    x2 = x[f:].copy()
    x2[-f:] += head
    return x2


def engine():
    n = SR * 2
    x = osc("sawtooth", 40, 40, n) + osc("square", 40.5, 40.5, n)
    return biquad(x, "lowpass", 300, 1) * .5


# ---------------------------------------------------------------- trilha dinâmica
BPM = 94
CHORDS = [[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59], [57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 56, 59]]
mtof = lambda m: 440 * 2 ** ((m - 69) / 12)


def music():
    sd = 60 / BPM / 4
    steps = 16 * 8
    N = int(round(steps * sd * SR))
    L = {k: Buf(steps * sd + 3) for k in ["pad", "bass", "arp", "hat", "kick", "snare"]}
    mr = np.random.default_rng(7)
    for step in range(steps):
        s, bar = step % 16, (step >> 4) % 8
        ch, t = CHORDS[bar], step * sd
        if s == 0:
            n = int(sd * 17.2 * SR)
            tt = np.arange(n) / SR
            env = np.interp(tt, [0, .9, sd * 14, sd * 17], [.0001, .03, .03, .0001])
            for note in ch:
                for det in (-6, 6):
                    L["pad"].add(osc("sawtooth", mtof(note) * 2 ** (det / 1200), mtof(note) * 2 ** (det / 1200), n) * env, t)
        if s in (0, 3, 6, 8, 11, 14):
            note = ch[0] - 12 + (7 if s == 14 else 0)
            n = int(sd * 2 * SR)
            sig = biquad(osc("sawtooth", mtof(note), mtof(note), n), "lowpass", 1100, 6, f_end=1100 * (160 / 1100) ** (2 / 1.6))
            L["bass"].add(sig * env_exp(n, .16), t)
        if mr.random() < (.35 if s % 2 else .7):
            note = ch[mr.integers(0, 3)] + 12 * (1 + mr.integers(0, 2))
            n = int(sd * 1.6 * SR)
            L["arp"].add(osc("triangle", mtof(note), mtof(note), n) * env_exp(n, .06), t)
        if s % 2 == 0:
            d = .07 if s % 4 == 2 else .035
            n = int(d * SR)
            o = mr.integers(0, len(WHITE) - n)
            L["hat"].add(biquad(WHITE[o:o + n].copy(), "highpass", 8000, .7) * env_exp(n, .12), t)
        if s in (0, 8) or (s == 10 and bar % 2):
            n = int(.32 * SR)
            L["kick"].add(osc("sine", 150, 42 * (42 / 150) ** (.32 / .22 - 1), n) * env_exp(n, .55), t)
        if s in (4, 12):
            n = int(.16 * SR)
            o = mr.integers(0, len(WHITE) - n)
            L["snare"].add(biquad(WHITE[o:o + n].copy(), "bandpass", 1800, .8) * env_exp(n, .32), t)
            n2 = int(.12 * SR)
            L["snare"].add(osc("triangle", 220, 140 * (140 / 220) ** (.12 / .08 - 1), n2) * env_exp(n2, .12), t)
    out = {}
    pad = biquad(L["pad"].x, "lowpass", 700, 1)
    out["pad"] = pad
    out["bass"] = L["bass"].x
    # arpejo com eco (atraso de 3/4 de batida, realimentação .35, passa-baixa 2200 no laço)
    arp = L["arp"].x
    dl = int(60 / BPM * .75 * SR)
    b, a = biquad_coefs("lowpass", 2200, 1)
    wet = np.zeros(len(arp) + dl * 8)
    buf_in = np.concatenate([arp, np.zeros(dl * 8)])
    x1 = x2 = y1 = y2 = 0.0
    line = np.zeros(len(buf_in))
    for i in range(len(buf_in)):
        d_in = buf_in[i - dl] + .35 * line[i - dl] if i >= dl else 0.0
        yi = b[0] * d_in + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
        x2, x1, y2, y1 = x1, d_in, y1, yi
        line[i] = yi
    out["arp"] = buf_in + line
    for k in ("hat", "kick", "snare"):
        out[k] = L[k].x
    return {k: loop_wrap(v, N) for k, v in out.items()}


def main():
    sfx_dir = os.path.join(OUT, "sfx")
    os.makedirs(sfx_dir, exist_ok=True)
    for k, nv in VARIANTS.items():
        for i in range(nv):
            vary = .9 + .2 * (i / max(1, nv - 1)) if nv > 1 else 1.0
            x = sfx(k, vary)
            p = save(os.path.join("sfx", "%s_%d" % (k, i)), x, norm=None)
            print(p, "%.2fs" % (len(x) / SR))
    save("amb_loop", ambience(), norm=.5)
    save("engine_loop", engine(), norm=.6)
    for k, v in music().items():
        save("mus_" + k, v * .9)
        print("mus", k, "%.2fs" % (len(v) / SR), "%.2f" % np.abs(v).max())


if __name__ == "__main__":
    main()
