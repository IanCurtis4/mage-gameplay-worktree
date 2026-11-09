#!/usr/bin/env python3
"""E08 P6 A3: deterministic, original sound synthesis (no external samples, no music).

Generates the 75 planned P6 cues (assets/audio/e08/p6/) and re-renders the 11 world_*/ui_*
one-shots (assets/audio/e08/) in the same style. The two ambience beds are NOT touched here
(they stay owned by tools/prepare_e08_pilot_audio.py).

Technique (replaces the P3 bare sine sweep + 2.01x harmonic + raw white noise):
  * every cue is built from layers: click (transient) + body (tonal/inharmonic partials, FM,
    pitch-dropping thump) + grit (element-coloured filtered noise) + optional whoosh / chime notes;
  * element = shared timbre (partial set, noise colour, transient), delivery = shared envelope shape;
  * RBJ biquads (low/high/band-pass, also swept), jagged gating for lightning, sparse-impulse crackle
    for fire, inharmonic partials for ice/metal, damped wood partials for nature/physical;
  * a light synthetic room (pre-delay + 4 combs + 2 all-passes, low-passed wet) on every cue,
    then a 28 Hz high-pass (no DC), a soft low-pass (no harsh full-band hiss), short fades and
    a sample-peak target per role.
Seeds derive from the cue id (SHA-256), so output is byte-reproducible with the same numpy.

Usage:
  python tools/prepare_e08_p6_audio.py            # regenerate all WAVs + provenance.json entries
  python tools/prepare_e08_p6_audio.py preview DIR OLD_DIR   # listening preview + stress clip
"""
from pathlib import Path
import hashlib, json, math, sys, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'assets/audio/e08'
P6 = AUDIO / 'p6'
RATE = 44100
GENERATOR = 'tools/prepare_e08_p6_audio.py'


# --------------------------------------------------------------------------- DSP primitives
def rng_for(name):
    seed = int.from_bytes(hashlib.sha256(('e08p6:' + name).encode()).digest()[:4], 'little')
    return np.random.RandomState(seed)


def _coef(kind, f, q):
    f = min(max(float(f), 20.0), RATE * 0.45)
    w = 2 * math.pi * f / RATE
    c = math.cos(w)
    a = math.sin(w) / (2 * q)
    if kind == 'lp':
        b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0
    elif kind == 'hp':
        b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0
    else:  # band-pass, 0 dB peak gain
        b0 = a; b1 = 0.0; b2 = -a
    a0 = 1 + a
    return b0 / a0, b1 / a0, b2 / a0, -2 * c / a0, (1 - a) / a0


def filt(x, kind, f, q=0.707):
    """RBJ biquad. f may be an array (per-sample cutoff, coefficients refreshed every 32 samples)."""
    xs = np.asarray(x, float).tolist()
    n = len(xs)
    fa = None if np.isscalar(f) else np.asarray(f, float)
    b0, b1, b2, a1, a2 = _coef(kind, f if fa is None else fa[0], q)
    y = [0.0] * n
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        if fa is not None and i % 32 == 0:
            b0, b1, b2, a1, a2 = _coef(kind, fa[i], q)
        v = xs[i]
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = v; y2 = y1; y1 = o
        y[i] = o
    return np.array(y)


def pk(x):
    m = np.max(np.abs(x))
    return x / m if m > 1e-12 else x


def tvec(n):
    return np.arange(n) / RATE


def sweep(n, a, b):
    return a * (b / a) ** np.linspace(0, 1, n)


def adr(n, att, tau):
    """smooth raised-cosine attack, then exponential decay."""
    t = tvec(n)
    att = max(att, 1e-4)
    a = np.where(t < att, 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / att, 1.0)), 1.0)
    return a * np.exp(-np.maximum(t - att, 0) / tau)


def hump(n, peak=0.4, rise=1.6, fall=1.4):
    t = np.linspace(0, 1, n)
    return np.where(t < peak, (t / peak) ** rise, ((1 - t) / (1 - peak)) ** fall)


def phase(f):
    return 2 * np.pi * np.cumsum(f) / RATE


def mix(n, layers):
    out = np.zeros(n)
    for sig, off, gain in layers:
        i = int(round(off * RATE))
        if i >= n:
            continue
        m = min(len(sig), n - i)
        out[i:i + m] += gain * sig[:m]
    return out


def partials(f, ratios, amps, taus, n):
    t = tvec(n)
    ph = phase(f * np.ones(n))
    out = np.zeros(n)
    for k, (rt, a, tau) in enumerate(zip(ratios, amps, taus)):
        out += a * np.sin(rt * ph + 0.9 * k) * np.exp(-t / tau)
    return out


def saw_add(f, n, top=5500.0, rolloff=1.0):
    """band-limited sawtooth by additive synthesis; f scalar or array."""
    fa = f * np.ones(n)
    ph = phase(fa)
    out = np.zeros(n)
    for k in range(1, 40):
        if k * float(np.max(fa)) > top:
            break
        out += np.sin(k * ph) / (k ** rolloff)
    return out


def thump(n, f0, f1, tau, drop=0.035):
    t = tvec(n)
    f = f1 + (f0 - f1) * np.exp(-t / drop)
    return np.sin(phase(f)) * np.exp(-t / tau)


# --------------------------------------------------------------------------- room + finishing
def _allpass(x, d, g):
    n = len(x)
    y = np.zeros(n)
    y[:min(d, n)] = -g * x[:min(d, n)]
    for i in range(d, n, d):
        m = min(d, n - i)
        y[i:i + m] = -g * x[i:i + m] + x[i - d:i - d + m] + g * y[i - d:i - d + m]
    return y


def room(x, wet, size=1.0):
    n = len(x)
    pre = int(0.008 * RATE)
    sig = np.concatenate([np.zeros(pre), x])[:n]
    acc = np.zeros(n)
    for d, g in ((1307, 0.58), (1637, 0.55), (1811, 0.52), (1933, 0.50)):
        d = int(d * size)
        y = sig.copy()
        for i in range(d, n, d):
            m = min(d, n - i)
            y[i:i + m] += g * y[i - d:i - d + m]
        acc += y / 4
    acc = _allpass(_allpass(acc, 225, 0.5), 556, 0.5)
    acc = filt(acc, 'lp', 4800, 0.707)
    return x + wet * acc


def finish(x, peak_db, wet=0.10, lp=11000.0, fade=0.02, size=1.0):
    x = np.asarray(x, float)
    if wet > 0:
        x = room(x, wet, size)
    x = filt(x, 'hp', 28, 0.707)
    if lp:
        x = filt(x, 'lp', lp, 0.707)
    n = len(x)
    fi = max(int(0.0008 * RATE), 2)
    fo = min(int(fade * RATE), n // 3)
    x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    x[n - fo:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(fo) / fo)
    x[0] = 0.0
    x[-1] = 0.0
    return x * (10 ** (peak_db / 20) / np.max(np.abs(x)))


# --------------------------------------------------------------------------- element timbres
def b_arcane(n, pm, r):
    t = tvec(n)
    ph = phase(640 * pm * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)))
    idx = 2.2 * np.exp(-t / 0.12) + 0.35
    fm = np.sin(ph + idx * np.sin(1.4142 * ph))
    return pk(0.6 * fm + 0.35 * np.sin(1.005 * ph + 1.0) + 0.15 * np.sin(2.99 * ph) * np.exp(-t / 0.07))


def b_blood(n, pm, r):
    t = tvec(n)
    ph = phase(75 * pm * (1 + 1.2 * np.exp(-t / 0.04)))
    return pk(np.sin(ph) + 0.3 * np.sin(2 * ph + 0.5) * np.exp(-t / 0.05))


def b_fire(n, pm, r):
    t = tvec(n)
    ph = phase(95 * pm * (1 + 0.6 * np.exp(-t / 0.08)))
    return pk(np.sin(ph) + 0.25 * np.sin(1.5 * ph) * np.exp(-t / 0.1) + 0.12 * np.sin(2.5 * ph) * np.exp(-t / 0.05))


def b_geometry(n, pm, r):
    return pk(partials(523.25 * pm, [1, 2, 3, 5], [1.0, 0.45, 0.28, 0.12], [0.30, 0.18, 0.12, 0.08], n))


def b_ice(n, pm, r):
    f = 1500 * pm
    return pk(partials(f, [1, 2.76, 5.40, 8.93], [1.0, 0.6, 0.4, 0.22], [0.22, 0.14, 0.09, 0.05], n)
              + 0.35 * partials(f * 1.0037, [1, 2.76], [1.0, 0.5], [0.2, 0.12], n))


def b_lightning(n, pm, r):
    t = tvec(n)
    buzz = filt(saw_add(120 * pm, n, 6000, 1.0), 'bp', 1400, 1.5)
    ping = np.sin(phase(3200 * pm)) * np.exp(-t / 0.05)
    return pk(0.8 * pk(buzz) + 0.5 * ping)


def b_nature(n, pm, r):
    return pk(partials(330 * pm, [1, 3.9, 9.0], [1.0, 0.35, 0.10], [0.12, 0.04, 0.02], n))


def b_physical(n, pm, r):
    t = tvec(n)
    wood = np.sin(phase(170 * pm * (1 + 0.5 * np.exp(-t / 0.03)))) * np.exp(-t / 0.08)
    metal = partials(1100 * pm, [1, 2.32, 4.25], [1.0, 0.5, 0.25], [0.10, 0.06, 0.03], n)
    return pk(wood + 0.14 * metal)


def b_spirit(n, pm, r):
    t = tvec(n)
    ph = phase(392 * pm * (1 + 0.006 * np.sin(2 * np.pi * 4.5 * t)))
    return pk(np.sin(ph) + 0.8 * np.sin(1.0035 * ph + 0.7) + 0.5 * np.sin(1.5 * ph + 0.3) + 0.25 * np.sin(2 * ph))


BODY = {'arcane': b_arcane, 'blood': b_blood, 'fire': b_fire, 'geometry': b_geometry, 'ice': b_ice,
        'lightning': b_lightning, 'nature': b_nature, 'physical': b_physical, 'spirit': b_spirit}


def g_arcane(n, r):
    w = r.standard_normal(n)
    return pk(0.7 * pk(filt(w, 'bp', 3200, 3.0)) + 0.3 * pk(filt(w, 'hp', 6500, 0.7)))


def g_blood(n, r):
    w = r.standard_normal(n)
    return pk(pk(filt(w, 'lp', sweep(n, 900, 200), 1.2)) + 0.4 * pk(filt(r.standard_normal(n), 'bp', 250, 1.5)))


def g_fire(n, r):
    imp = (r.rand(n) < 0.0035) * r.uniform(0.3, 1.0, n)
    return pk(0.8 * pk(filt(imp, 'bp', 2200, 1.1)) + 0.45 * pk(filt(r.standard_normal(n), 'bp', 650, 0.9))
              + 0.5 * pk(filt(r.standard_normal(n), 'lp', 260, 0.8)))


def g_geometry(n, r):
    return pk(0.6 * pk(filt(r.standard_normal(n), 'bp', 2400, 2.5)) + 0.2 * pk(filt(r.standard_normal(n), 'hp', 7000, 0.7)))


def g_ice(n, r):
    imp = (r.rand(n) < 0.002) * r.uniform(0.4, 1.0, n)
    return pk(0.7 * pk(filt(imp, 'hp', 4500, 0.8)) + 0.5 * pk(filt(r.standard_normal(n), 'bp', 6500, 9.0))
              + 0.25 * pk(filt(r.standard_normal(n), 'hp', 3500, 0.7)))


def g_lightning(n, r):
    steps = (r.rand(n // 90 + 2) < 0.55).astype(float)
    gate = np.clip(filt(np.repeat(steps, 90)[:n], 'lp', 900, 0.7), 0, 1)
    return pk(pk(filt(r.standard_normal(n), 'hp', 2600, 0.8)) * gate + 0.4 * pk(filt(r.standard_normal(n), 'bp', 3300, 14.0)))


def g_nature(n, r):
    fl = filt(r.standard_normal(n), 'lp', 28, 0.7)
    amp = 0.55 + 0.45 * fl / max(np.max(np.abs(fl)), 1e-9)
    leaves = filt(r.standard_normal(n), 'bp', 3300, 1.2) * amp
    return pk(0.8 * pk(leaves) + 0.5 * pk(filt(r.standard_normal(n), 'lp', 420, 0.9)))


def g_physical(n, r):
    return pk(0.8 * pk(filt(r.standard_normal(n), 'bp', 1100, 1.4)) + 0.35 * pk(filt(r.standard_normal(n), 'bp', 250, 1.2)))


def g_spirit(n, r):
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * 3.1 * tvec(n))
    return pk((0.8 * pk(filt(r.standard_normal(n), 'bp', 820, 6.0)) + 0.7 * pk(filt(r.standard_normal(n), 'bp', 1750, 6.0))
               + 0.3 * pk(filt(r.standard_normal(n), 'hp', 3500, 0.7))) * wob)


GRIT = {'arcane': g_arcane, 'blood': g_blood, 'fire': g_fire, 'geometry': g_geometry, 'ice': g_ice,
        'lightning': g_lightning, 'nature': g_nature, 'physical': g_physical, 'spirit': g_spirit}


def _burst(r, kind, f, q, tau, extra=None):
    n = 1024
    y = filt(r.standard_normal(n), kind, f, q) * np.exp(-tvec(n) / tau)
    if extra is not None:
        y = pk(y) + extra
    return pk(y)


def _ping(f, tau, n=1024):
    return np.sin(phase(f * np.ones(n))) * np.exp(-tvec(n) / tau)


CLICK = {
    'arcane': lambda r: _burst(r, 'hp', 4000, 0.8, 0.002),
    'blood': lambda r: _burst(r, 'lp', 700, 1.0, 0.008),
    'fire': lambda r: _burst(r, 'hp', 1800, 0.8, 0.004),
    'geometry': lambda r: _ping(2093, 0.004),
    'ice': lambda r: _burst(r, 'hp', 6500, 0.8, 0.002, 0.5 * _ping(4800, 0.006)),
    'lightning': lambda r: _burst(r, 'hp', 3500, 0.7, 0.0015),
    'nature': lambda r: _burst(r, 'bp', 900, 2.0, 0.005),
    'physical': lambda r: pk(0.8 * _burst(r, 'bp', 1600, 1.5, 0.004) + 0.6 * _burst(r, 'lp', 400, 0.8, 0.01)),
    'spirit': lambda r: 0.4 * _burst(r, 'bp', 1500, 2.0, 0.01),
}
THUMP_W = {'arcane': 0.1, 'blood': 0.9, 'fire': 0.55, 'geometry': 0.15, 'ice': 0.0, 'lightning': 0.15,
           'nature': 0.4, 'physical': 0.6, 'spirit': 0.15}
OCT = {'arcane': 1.0, 'geometry': 1.0, 'spirit': 1.0, 'blood': 4.0, 'nature': 1.5, 'physical': 1.2, 'ice': 0.5,
       'fire': 3.0, 'lightning': 1.0}
WHOOSH_BAND = {'physical': (700, 3000), 'blood': (350, 1500), 'nature': (500, 2600), 'arcane': (900, 3600),
               'fire': (400, 1800), 'ice': (1500, 5000), 'lightning': (1500, 5000), 'geometry': (1000, 3000),
               'spirit': (600, 2200)}


def whoosh(r, dur, f0, f1, q=1.0, peak=0.45, lp=None):
    n = int(dur * RATE)
    y = filt(r.standard_normal(n), 'bp', sweep(n, f0, f1), q)
    if lp:
        y = filt(y, 'lp', lp, 0.707)
    return pk(y) * hump(n, peak)


def blast(r, dur, f0, f1, tau):
    n = int(dur * RATE)
    return pk(filt(r.standard_normal(n), 'lp', sweep(n, f0, f1), 0.9)) * adr(n, 0.001, tau)


def crack_ring(r, kind='metal'):
    """mechanical trap snap: wooden tick + metallic inharmonic ring."""
    n = int(0.12 * RATE)
    tick = _burst(r, 'bp', 1800, 2.0, 0.003)
    ring = partials(2800 * np.ones(n), [1, 1.32, 1.79], [1.0, 0.6, 0.4], [0.035, 0.03, 0.02], n)
    return mix(n, [(tick, 0, 0.9), (ring, 0.018, 0.4)])


# --------------------------------------------------------------------------- deliveries (shared envelope shapes)
def layered(el, r, dur, pm, att, btau, gtau, wb, wg, wc, wt=0.0, gatt=0.002):
    n = int(dur * RATE)
    b = BODY[el](n, sweep(n, *pm), r) * adr(n, att, btau)
    g = GRIT[el](n, r) * adr(n, gatt if att < 0.01 else att, gtau)
    layers = [(b, 0, wb), (g, 0, wg), (CLICK[el](r), 0, wc)]
    if wt:
        layers.append((thump(n, 110 if el != 'blood' else 85, 50 if el != 'blood' else 40, 0.07) * adr(n, 0.001, 0.08), 0, wt))
    return mix(n, layers)


def d_cast(el, r, dur=0.24, pm=(0.85, 1.25)):
    return layered(el, r, dur, pm, 0.06, 0.10, 0.08, 0.8, 0.5, 0.08)


def d_projectile(el, r, dur=0.26):
    n = int(dur * RATE)
    f0, f1 = WHOOSH_BAND[el]
    base = layered(el, r, dur, (1.3, 0.75), 0.004, 0.08, 0.09, 0.7, 0.45, 0.6, THUMP_W[el] * 0.25)
    return mix(n, [(base, 0, 1.0), (whoosh(r, dur * 0.9, f0 * 1.3, f1 * 0.8, 1.2, 0.3, 7000), 0, 0.35)])


def d_melee(el, r, dur=0.22, heavy=1.0):
    n = int(dur * RATE)
    f0, f1 = WHOOSH_BAND[el]
    body = BODY[el](n, sweep(n, 0.8, 0.55), r) * adr(n, 0.02, 0.1)
    grit = GRIT[el](n, r) * hump(n, 0.5)
    return mix(n, [(whoosh(r, dur, f0, f1, 1.2, 0.42), 0, 1.0), (body, 0.0, 0.25 * heavy), (grit, 0, 0.3)])


def d_impact(el, r, dur=0.32, btau=0.09, gtau=0.08, pm=(1.0, 0.8), wt=1.0):
    return layered(el, r, dur, pm, 0.001, btau, gtau, 0.7, 0.55, 0.9, THUMP_W[el] * 0.9 * wt, 0.0015)


def d_dot(el, r, dur=0.14):
    return layered(el, r, dur, (1.0, 0.85), 0.002, 0.04, 0.04, 0.5, 0.5, 0.3, THUMP_W[el] * 0.2)


def d_area(el, r, dur=0.75):
    n = int(dur * RATE)
    sw = int(0.24 * RATE)
    f0, f1 = WHOOSH_BAND[el]
    ramp = np.linspace(0, 1, sw) ** 2
    swell = mix(sw, [(BODY[el](sw, sweep(sw, 0.7, 1.0), r), 0, 0.5), (GRIT[el](sw, r), 0, 0.5)]) * ramp
    sweepn = whoosh(r, 0.24, f0 * 0.5, f1 * 0.9, 1.0, 0.95)
    burst = d_impact(el, r, 0.52, 0.2, 0.22, (0.9, 0.55), 1.1)
    tail = GRIT[el](n - int(0.3 * RATE), r) * adr(n - int(0.3 * RATE), 0.01, 0.22)
    return mix(n, [(swell, 0, 0.55), (sweepn, 0, 0.35), (burst, 0.22, 1.0), (tail, 0.3, 0.3)])


def d_trap(el, r, dur=0.38):
    n = int(dur * RATE)
    burst = d_impact(el, r, 0.3, 0.1, 0.1, (1.0, 0.8), 0.8)
    return mix(n, [(crack_ring(r), 0, 0.8), (burst, 0.035, 0.9)])


def notes(el, r, pms, step, ndur, tau, att=0.02, wg=0.0):
    n = int((step * (len(pms) - 1) + ndur) * RATE)
    layers = []
    for i, pm in enumerate(pms):
        m = int(ndur * RATE)
        s = BODY[el](m, np.ones(m) * pm, r) * adr(m, att, tau)
        layers.append((s, i * step, 1.0 - 0.1 * i))
        if wg:
            g = GRIT[el](m, r) * adr(m, att, tau * 0.6)
            layers.append((g, i * step, wg))
    return n, mix(n, layers)


def d_buff(el, r, dur=0.55):
    o = OCT[el]
    n, s = notes(el, r, [o, o * 1.26, o * 1.5], 0.11, 0.3, 0.2, 0.02, 0.25)
    sw = whoosh(r, 0.4, 500, 2400, 1.0, 0.6) * 0.3
    return mix(int(dur * RATE), [(s, 0, 1.0), (sw, 0, 0.5), (CLICK[el](r), 0, 0.3)])


def d_heal(el, r, dur=0.5):
    o = OCT[el]
    n, s = notes(el, r, [o, o * 1.26, o * 1.5, o * 2.0], 0.075, 0.3, 0.18, 0.012, 0.18)
    g = GRIT[el](int(0.35 * RATE), r) * hump(int(0.35 * RATE), 0.6)
    return mix(int(dur * RATE), [(s, 0, 1.0), (g, 0, 0.18)])


def d_movement(el, r, dur=0.30):
    n = int(dur * RATE)
    f0, f1 = WHOOSH_BAND[el]
    w = whoosh(r, 0.26, f0 * 0.9, f1 * 0.7, 1.0, 0.35)
    steps = []
    for off, g in ((0.0, 1.0), (0.12, 0.8)):
        m = int(0.1 * RATE)
        step = BODY[el](m, np.ones(m) * 0.5, r) * adr(m, 0.001, 0.04) + 0.6 * GRIT[el](m, r) * adr(m, 0.001, 0.03)
        steps.append((pk(step), off, 0.7 * g))
        steps.append((CLICK[el](r), off, 0.4 * g))
    return mix(n, [(w, 0.0, 0.8)] + steps)


def growl(n, f0, f1, ctr, q=2.0):
    return pk(filt(saw_add(sweep(n, f0, f1), n, 5000, 0.9), 'bp', ctr, q))


def d_summon(el, r, dur=1.0):
    n = int(dur * RATE)
    call = BODY[el](n, np.ones(n) * 0.4, r) * adr(n, 0.12, 0.45)
    leaf = GRIT[el](n, r) * hump(n, 0.45, 1.6, 1.2)
    horn = growl(n, 98, 108, sweep(n, 450, 900), 2.5) * hump(n, 0.4, 1.8, 1.2)
    creak = filt(r.standard_normal(n), 'bp', 480, 4.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * tvec(n)) ** 2)
    return mix(n, [(call, 0, 0.6), (leaf, 0, 0.5), (horn, 0, 0.55), (pk(creak) * hump(n, 0.5), 0, 0.2), (thump(n, 80, 45, 0.2) * adr(n, 0.001, 0.25), 0.28, 0.5)])


def d_charge(el, r, dur=0.6):
    n = int(dur * RATE)
    g = growl(n, 70, 115, sweep(n, 300, 1100), 1.6) * np.linspace(0.1, 1, n) ** 1.5
    tex = GRIT[el](n, r) * np.linspace(0.1, 1, n) ** 1.3
    steps = []
    for off, w in ((0.0, 0.5), (0.18, 0.65), (0.33, 0.8), (0.45, 1.0)):
        m = int(0.12 * RATE)
        steps.append((thump(m, 90, 45, 0.06) * adr(m, 0.001, 0.07), off, w * 0.7))
        steps.append((CLICK[el](r), off, w * 0.3))
    return mix(n, [(g, 0, 0.75), (tex, 0, 0.45)] + steps)


def d_teleport(el, r, dur=0.5, seed_shift=1.0):
    n = int(dur * RATE)
    inn = whoosh(r, 0.24, 4200, 300, 1.2, 0.8) * 1.0
    fall = BODY[el](int(0.24 * RATE), sweep(int(0.24 * RATE), 1.8 * seed_shift, 0.6), r) * adr(int(0.24 * RATE), 0.04, 0.16)
    pop = CLICK[el](r)
    pop2 = thump(int(0.1 * RATE), 140, 60, 0.04) * adr(int(0.1 * RATE), 0.001, 0.05)
    sp = []
    for i, pm in enumerate((2.0, 2.52, 3.0)):
        m = int(0.22 * RATE)
        s = BODY[el](m, np.ones(m) * pm * seed_shift, r) * adr(m, 0.004, 0.09)
        sp.append((s, 0.24 + 0.055 * i, 0.5 - 0.1 * i))
    return mix(n, [(inn, 0, 0.5), (fall, 0, 0.45), (pop, 0.235, 0.8), (pop2, 0.235, 0.5)] + sp)


# --------------------------------------------------------------------------- signatures
def s_fireball(r):
    n = int(0.9 * RATE)
    boom = d_impact('fire', r, 0.55, 0.22, 0.2, (0.85, 0.5), 1.4)
    th = thump(n, 95, 38, 0.2) * adr(n, 0.001, 0.22)
    b = blast(r, 0.4, 3500, 250, 0.12)
    crackle = GRIT['fire'](n, r) * adr(n, 0.03, 0.36)
    return mix(n, [(boom, 0, 0.9), (th, 0, 1.0), (b, 0, 0.7), (crackle, 0.05, 0.55)])


def s_slash(r):
    n = int(0.3 * RATE)
    w = whoosh(r, 0.28, 700, 3800, 1.1, 0.4)
    m = int(0.2 * RATE)
    ring = partials(2400 * np.ones(m), [1, 2.7, 5.1], [1.0, 0.45, 0.25], [0.1, 0.06, 0.03], m) * adr(m, 0.006, 0.12)
    low = BODY['physical'](int(0.2 * RATE), sweep(int(0.2 * RATE), 0.8, 0.5), r) * adr(int(0.2 * RATE), 0.02, 0.1)
    return mix(n, [(w, 0, 1.0), (ring, 0.08, 0.28), (low, 0, 0.25)])


def s_shout(r):
    n = int(0.7 * RATE)
    f = sweep(n, 100, 74)
    src = saw_add(f, n, 5000, 0.8)
    v = pk(filt(src, 'bp', sweep(n, 650, 420), 3.0)) + 0.8 * pk(filt(src, 'bp', 1100, 3.0))
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 13 * tvec(n))
    breath = pk(filt(r.standard_normal(n), 'lp', 1200, 0.8))
    env = adr(n, 0.07, 0.38)
    return pk(v * trem + 0.35 * breath) * env


def s_arrow_rain(r):
    n = int(0.8 * RATE)
    layers = []
    for i in range(12):
        off = 0.02 + 0.5 * (i / 11) ** 0.8 + 0.02 * r.uniform()
        w = whoosh(r, 0.2, 5200 + 400 * r.uniform(), 2300 + 200 * r.uniform(), 2.0, 0.3, 8000)
        layers.append((w, off, 0.25 + 0.5 * off))
        m = int(0.08 * RATE)
        th = pk(BODY['physical'](m, np.ones(m) * 0.9, r) * adr(m, 0.001, 0.025)) * 0.5
        layers.append((th, off + 0.19, 0.2 + 0.4 * off))
    swell = whoosh(r, 0.7, 1500, 3500, 0.8, 0.6, 9000)
    layers.append((swell, 0, 0.3))
    return mix(n, layers)


def s_explosive_trap(r):
    n = int(0.4 * RATE)
    burst = d_impact('fire', r, 0.32, 0.1, 0.1, (1.0, 0.7), 1.2)
    return mix(n, [(crack_ring(r), 0, 0.8), (burst, 0.04, 1.0), (blast(r, 0.2, 3000, 300, 0.06), 0.04, 0.5)])


def s_reprisal(r):
    n = int(0.6 * RATE)
    hit = d_impact('physical', r, 0.3, 0.1, 0.08, (1.0, 0.8), 1.0)
    m = int(0.3 * RATE)
    ring = partials(900 * np.ones(m), [1, 2.32, 4.25], [1.0, 0.5, 0.25], [0.12, 0.08, 0.04], m)
    wave_ = thump(n, 60, 36, 0.25) * adr(n, 0.04, 0.28)
    rumble = pk(filt(r.standard_normal(n), 'bp', sweep(n, 120, 260), 1.2)) * hump(n, 0.3)
    return mix(n, [(hit, 0, 0.9), (ring, 0, 0.18), (wave_, 0.02, 0.9), (rumble, 0.02, 0.4)])


def s_counter(r):
    n = int(0.32 * RATE)
    m = int(0.25 * RATE)
    clang = partials(700 * np.ones(m), [1, 2.32, 4.25, 6.7], [1.0, 0.6, 0.35, 0.2], [0.14, 0.1, 0.06, 0.04], m)
    thunk = d_impact('physical', r, 0.22, 0.07, 0.06, (1.0, 0.7), 1.3)
    sw = whoosh(r, 0.12, 1500, 4500, 1.2, 0.7)
    return mix(n, [(sw, 0, 0.4), (thunk, 0.05, 1.0), (clang, 0.05, 0.3)])


def s_blood_rift(r):
    n = int(0.36 * RATE)
    steps = (r.rand(n // 220 + 2) < 0.6).astype(float)
    gate = np.clip(filt(np.repeat(steps, 220)[:n], 'lp', 120, 0.7), 0, 1)
    tear = pk(filt(r.standard_normal(n), 'bp', sweep(n, 700, 200), 1.3)) * gate * hump(n, 0.35)
    th = thump(n, 85, 40, 0.1) * adr(n, 0.004, 0.12)
    return mix(n, [(tear, 0, 0.9), (th, 0.04, 0.8), (GRIT['blood'](n, r) * adr(n, 0.01, 0.12), 0, 0.4)])


def s_wound_leap(r):
    n = int(0.45 * RATE)
    push = thump(int(0.1 * RATE), 100, 50, 0.04) * adr(int(0.1 * RATE), 0.001, 0.05)
    w = whoosh(r, 0.22, 400, 1500, 1.0, 0.5)
    land = d_impact('blood', r, 0.2, 0.08, 0.08, (1.0, 0.8), 1.1)
    return mix(n, [(push, 0, 0.7), (w, 0.02, 0.8), (land, 0.24, 1.0)])


def s_tri_nova(r):
    n = int(0.75 * RATE)
    sw = whoosh(r, 0.55, 400, 3200, 0.9, 0.7)
    return mix(n, [(sw, 0, 0.35), (d_impact('fire', r, 0.28, 0.1, 0.09, (1.0, 0.8), 0.9), 0.0, 0.8),
                   (d_impact('ice', r, 0.28, 0.1, 0.09, (1.0, 0.9), 0.9), 0.14, 0.8),
                   (d_impact('lightning', r, 0.3, 0.1, 0.09, (1.0, 0.9), 0.9), 0.28, 0.9)])


def s_lightning_arc(r):
    n = int(0.55 * RATE)
    layers = []
    for i, (off, f) in enumerate(((0.0, 3200), (0.09, 3600), (0.19, 4100), (0.28, 4700))):
        m = int(0.16 * RATE)
        z = GRIT['lightning'](m, r) * adr(m, 0.001, 0.035)
        p = np.sin(phase(f * np.ones(m))) * adr(m, 0.001, 0.05)
        layers += [(z, off, 0.9), (p, off, 0.35), (CLICK['lightning'](r), off, 0.8)]
    buzz = pk(filt(saw_add(110, n, 6000, 1.0), 'bp', 1500, 1.5)) * adr(n, 0.01, 0.2)
    layers.append((buzz, 0, 0.3))
    return mix(n, layers)


def s_dissipation(r):
    n = int(0.85 * RATE)
    layers = []
    for i, pm in enumerate((1.0, 1.25, 1.5, 1.875)):
        m = int(0.8 * RATE)
        s = BODY['spirit'](m, sweep(m, pm, pm * 1.12), r) * adr(m, 0.1, 0.28)
        layers.append((s, 0.02 * i, 0.5))
    g = GRIT['spirit'](n, r) * hump(n, 0.4)
    sh = whoosh(r, 0.6, 6000, 2000, 2.0, 0.3, 9000)
    layers += [(g, 0, 0.5), (sh, 0.1, 0.25)]
    return mix(n, layers)


def s_collapse(r):
    n = int(0.75 * RATE)
    layers = []
    for pm in (1.0, 1.25, 1.5, 2.0):
        m = int(0.5 * RATE)
        s = BODY['geometry'](m, sweep(m, pm, pm * 0.5), r) * adr(m, 0.003, 0.2)
        layers.append((s, 0, 0.45))
    inn = whoosh(r, 0.3, 4500, 250, 1.2, 0.85)
    layers += [(inn, 0.15, 0.5), (thump(n, 80, 38, 0.15) * adr(n, 0.001, 0.2), 0.45, 0.9), (CLICK['geometry'](r), 0.45, 0.5)]
    return mix(n, layers)


def s_triangulation(r):
    n = int(0.38 * RATE)
    layers = [(whoosh(r, 0.3, 1000, 3500, 1.2, 0.3), 0, 0.3)]
    for i, pm in enumerate((1.0, 1.26, 1.5)):
        m = int(0.14 * RATE)
        layers.append((BODY['geometry'](m, np.ones(m) * pm, r) * adr(m, 0.002, 0.05), 0.07 * i, 0.8))
        layers.append((CLICK['geometry'](r), 0.07 * i, 0.4))
    return mix(n, layers)


def twang(r, f=180, tau=0.06, m=None):
    m = m or int(0.2 * RATE)
    return partials(f * np.ones(m), [1, 2, 3, 4, 5], [1.0, 0.6, 0.4, 0.25, 0.15], [tau, tau * 0.8, tau * 0.6, tau * 0.5, tau * 0.4], m)


def s_explosive_shot(r):
    n = int(0.45 * RATE)
    sn = _burst(r, 'bp', 2500, 1.2, 0.003)
    burst = d_impact('fire', r, 0.38, 0.15, 0.15, (0.95, 0.65), 1.2)
    return mix(n, [(pk(twang(r)), 0, 0.45), (sn, 0, 0.7), (burst, 0.05, 1.0), (blast(r, 0.2, 3500, 300, 0.07), 0.05, 0.5)])


def s_headshot(r):
    n = int(0.24 * RATE)
    m = int(0.22 * RATE)
    return mix(n, [(pk(twang(r, 190, 0.07, m)), 0, 0.7), (_burst(r, 'bp', 2600, 1.2, 0.004), 0, 1.0),
                   (_burst(r, 'bp', 700, 1.0, 0.012), 0, 0.5), (whoosh(r, 0.1, 3500, 1800, 1.5, 0.3, 7000), 0.0, 0.2)])


def s_covering(r):
    n = int(0.3 * RATE)
    m = int(0.2 * RATE)
    tw = filt(pk(twang(r, 160, 0.05, m)), 'lp', 1800, 0.7)
    leaf = GRIT['nature'](n, r) * hump(n, 0.3, 1.0, 1.3)
    return mix(n, [(tw, 0, 0.6), (CLICK['nature'](r), 0, 0.5), (leaf, 0, 0.55)])


def s_warden_charge(r):
    n = int(0.72 * RATE)
    layers = []
    for off, w in ((0.0, 0.6), (0.17, 0.75), (0.31, 0.9), (0.43, 1.0), (0.54, 1.0)):
        m = int(0.14 * RATE)
        layers.append((thump(m, 75, 38, 0.07) * adr(m, 0.001, 0.08), off, w * 0.9))
        layers.append((GRIT['nature'](m, r) * adr(m, 0.002, 0.04), off, w * 0.35))
        layers.append((CLICK['nature'](r), off, w * 0.35))
    groan = growl(n, 80, 125, sweep(n, 600, 900), 2.2) * np.linspace(0.2, 1, n) ** 1.3
    layers.append((groan, 0, 0.55))
    return mix(n, layers)


def s_warden_summon(r):
    n = int(1.1 * RATE)
    call = growl(n, 105, 112, sweep(n, 480, 800), 2.5) * hump(n, 0.4, 1.7, 1.2)
    steps = (0.35 + 0.65 * (r.rand(n // 1600 + 2) < 0.5)).astype(float)
    creak = pk(filt(r.standard_normal(n), 'bp', 520, 4.0)) * np.clip(filt(np.repeat(steps, 1600)[:n], 'lp', 20, 0.7), 0, 1) * hump(n, 0.5)
    wind = whoosh(r, 1.0, 600, 1500, 0.7, 0.5, 4000)
    wood = BODY['nature'](n, np.ones(n) * 0.35, r) * adr(n, 0.01, 0.4)
    return mix(n, [(call, 0, 0.7), (creak, 0, 0.3), (wind, 0, 0.35), (wood, 0.35, 0.5), (thump(n, 70, 40, 0.2) * adr(n, 0.002, 0.25), 0.3, 0.5)])


# --------------------------------------------------------------------------- one-shot fallbacks / UI
def w_cast_cancel(r):
    n = int(0.2 * RATE)
    b = BODY['arcane'](n, sweep(n, 1.1, 0.55), r) * adr(n, 0.006, 0.07)
    g = pk(filt(r.standard_normal(n), 'lp', sweep(n, 4000, 300), 1.0)) * adr(n, 0.004, 0.06)
    return mix(n, [(b, 0, 0.7), (g, 0, 0.5)])


def w_area_end(r):
    n = int(0.4 * RATE)
    b = BODY['arcane'](n, sweep(n, 1.0, 0.5), r) * adr(n, 0.02, 0.14)
    g = pk(filt(r.standard_normal(n), 'bp', sweep(n, 3500, 500), 1.4)) * adr(n, 0.01, 0.12)
    return mix(n, [(b, 0, 0.6), (g, 0, 0.6), (thump(n, 90, 45, 0.1) * adr(n, 0.002, 0.1), 0, 0.3)])


def w_death(r):
    n = int(0.8 * RATE)
    s = BODY['spirit'](n, sweep(n, 0.9, 0.45), r) * adr(n, 0.01, 0.34)
    br = pk(filt(r.standard_normal(n), 'lp', sweep(n, 2500, 200), 0.9)) * adr(n, 0.01, 0.2)
    return mix(n, [(s, 0, 0.6), (br, 0, 0.45), (thump(n, 100, 40, 0.18) * adr(n, 0.001, 0.2), 0, 0.9), (CLICK['blood'](r), 0, 0.5)])


def w_revive(r):
    n, s = notes('spirit', r, [0.8, 1.0, 1.26, 1.5, 2.0], 0.085, 0.4, 0.2, 0.02, 0.15)
    glow = whoosh(r, 0.5, 700, 3000, 1.0, 0.7) * 0.3
    return mix(int(0.62 * RATE), [(s, 0, 1.0), (glow, 0, 0.5)])


def w_ui_confirm(r):
    n, s = notes('geometry', r, [1.0, 1.5], 0.055, 0.1, 0.05, 0.002)
    return mix(int(0.14 * RATE), [(s, 0, 1.0)])


def w_ui_cancel(r):
    n, s = notes('geometry', r, [0.85, 0.63], 0.05, 0.11, 0.045, 0.002)
    return mix(int(0.16 * RATE), [(s, 0, 1.0), (_burst(r, 'bp', 1200, 2.0, 0.004), 0, 0.3)])


# --------------------------------------------------------------------------- cue catalogue
# family -> (renderer(el, rng), peak dBFS, room wet, low-pass Hz)
FAMILIES = {
    'cast': (lambda el, r: d_cast(el, r), -12.0, 0.08, 11000),
    'projectile': (lambda el, r: d_projectile(el, r), -10.0, 0.08, 11500),
    'melee': (lambda el, r: d_melee(el, r), -7.0, 0.07, 11000),
    'impact': (lambda el, r: d_impact(el, r), -5.0, 0.10, 11500),
    'dot': (lambda el, r: d_dot(el, r), -12.0, 0.05, 10000),
    'area': (lambda el, r: d_area(el, r), -6.0, 0.14, 11500),
    'trap': (lambda el, r: d_trap(el, r), -5.0, 0.09, 11500),
    'buff': (lambda el, r: d_buff(el, r), -9.0, 0.12, 11000),
    'heal': (lambda el, r: d_heal(el, r), -9.0, 0.13, 11000),
    'movement': (lambda el, r: d_movement(el, r), -10.0, 0.07, 10500),
    'summon': (lambda el, r: d_summon(el, r), -5.0, 0.14, 10500),
    'charge': (lambda el, r: d_charge(el, r), -5.0, 0.08, 10500),
    'teleport': (lambda el, r: d_teleport(el, r), -7.0, 0.14, 12000),
}
FAMILY_RECIPE = {
    'cast': 'soft 60 ms attack, rising pitch contour, body + grit + faint transient, 0.24 s',
    'projectile': 'sharp exit click, falling pitch (doppler-like), air whoosh layer, 0.26 s',
    'melee': 'swept band-pass cloth/air whoosh with hump envelope, low grunt body, no hit sound, 0.22 s',
    'impact': 'click + element body + grit + soft low thump, exponential tail, 0.32 s',
    'dot': 'quiet short tick: damped body + grit + faint click, 0.14 s',
    'area': 'rising swell + inward sweep, impact burst at 0.22 s, filtered grit tail, 0.75 s',
    'trap': 'mechanical wood tick + metallic ring, then element burst at 35 ms, 0.38 s',
    'buff': 'three rising notes of the element body (soft attack) over an air swell, 0.55 s',
    'heal': 'four ascending notes (arpeggio) of the element body with faint grit shimmer, 0.50 s',
    'movement': 'air whoosh + two quick soft steps, 0.30 s',
    'summon': 'low element call + formant horn + leaf/creak texture + late low thump, 1.0 s',
    'charge': 'rising formant growl + four accelerating heavy steps, 0.6 s',
    'teleport': 'inward band-pass suck + falling body, pop, then three rising sparkle notes, 0.5 s',
}
ELEMENT_RECIPE = {
    'arcane': 'FM bell (inharmonic 1.414 ratio, decaying index) with detuned pair and slow vibrato; 3.2 kHz air band',
    'blood': 'pitch-dropping 75 Hz thump, swept low-pass wet noise; dull and short',
    'fire': 'low woomph + sparse-impulse crackle (band-pass 2.2 kHz) + mid hiss',
    'geometry': 'clean additive partials 1/2/3/5, no vibrato, faint band-pass grit',
    'ice': 'inharmonic partials 1/2.76/5.4/8.93 with beating pair, 6.5 kHz resonant noise and clicks',
    'lightning': 'jagged-gated high-passed noise + 3.3 kHz resonant ping + band-passed 120 Hz saw buzz',
    'nature': 'damped wood partials 1/3.9/9, fluttering 3.3 kHz leaf noise + earth low-pass',
    'physical': 'wooden thunk with faint metal ring, leather band-pass noise, dry',
    'spirit': 'detuned soft sine pad with vibrato, two formant bands (820 / 1750 Hz) breath',
}

SIGNATURES = {  # id suffix -> (renderer, peak dBFS, wet, lp, recipe)
    'mage_fireball': (s_fireball, -4.0, 0.12, 11000, 'blast + pitch-dropping thump + long fire crackle tail'),
    'mage_teleport': (lambda r: d_teleport('arcane', r, 0.5, 1.15), -6.0, 0.14, 12000, 'arcane suck + pop + sparkle arpeggio (higher than the generic teleport)'),
    'swordsman_slash': (s_slash, -5.0, 0.07, 11500, 'wide 0.7-3.8 kHz blade whoosh + inharmonic metal shimmer'),
    'swordsman_terrifying_shout': (s_shout, -6.0, 0.10, 9000, 'additive saw growl through moving formants with 13 Hz tremor'),
    'archer_arrow_rain': (s_arrow_rain, -8.0, 0.10, 11000, '12 doppler whistles with wood landings, density growing over 0.8 s'),
    'archer_explosive_trap': (s_explosive_trap, -4.0, 0.09, 11500, 'mechanical click + dry fire burst'),
    'defender_reprisal_wave': (s_reprisal, -5.0, 0.10, 10000, 'shield impact with metal ring + sub wave + swept rumble'),
    'defender_counterstroke': (s_counter, -4.0, 0.07, 11000, 'blade swish, shield thunk and clang, short and heavy'),
    'berserker_blood_rift': (s_blood_rift, -5.0, 0.08, 10000, 'gated wet tearing sweep + low thump'),
    'berserker_wound_leap': (s_wound_leap, -6.0, 0.08, 10500, 'push-off thump, air whoosh, wet landing'),
    'elementalist_tri_nova': (s_tri_nova, -5.0, 0.12, 12000, 'fire, ice, lightning bursts 140 ms apart over a rising sweep'),
    'elementalist_lightning_arc': (s_lightning_arc, -6.0, 0.10, 12000, 'four chained crackles with rising pings and a buzz bed'),
    'spiritualist_dissipation': (s_dissipation, -7.0, 0.16, 11000, 'four-voice spirit chord drifting upward and fading, breath shimmer'),
    'geometer_collapse': (s_collapse, -6.0, 0.12, 11500, 'descending geometric chord, inward sweep, implosion thump'),
    'geometer_triangulation': (s_triangulation, -10.0, 0.08, 11500, 'three geometric arpeggio pulses with launch whoosh'),
    'sentinel_explosive_shot': (s_explosive_shot, -4.0, 0.10, 11500, 'bowstring twang + snap, fire burst'),
    'sentinel_headshot': (s_headshot, -9.0, 0.06, 11500, 'hard bowstring twang + dry snap'),
    'hunter_freezing_trap': (lambda r: d_trap('ice', r, 0.45), -5.0, 0.10, 12500, 'trap click + ice crystallisation burst (longer than trap_ice)'),
    'hunter_covering_shot': (s_covering, -10.0, 0.07, 9500, 'muffled twang + foliage rustle'),
    'warden_charge': (s_warden_charge, -4.0, 0.08, 10000, 'five accelerating heavy steps + wooden groan'),
    'warden_summon': (s_warden_summon, -4.0, 0.15, 10000, 'low horn call, branch creaks, wind, wooden body, late thump'),
}
SIG_ELEMENT = {'mage_fireball': 'fire', 'mage_teleport': 'arcane', 'swordsman_slash': 'physical', 'swordsman_terrifying_shout': 'physical',
               'archer_arrow_rain': 'physical', 'archer_explosive_trap': 'fire', 'defender_reprisal_wave': 'physical',
               'defender_counterstroke': 'physical', 'berserker_blood_rift': 'blood', 'berserker_wound_leap': 'blood',
               'elementalist_tri_nova': 'arcane', 'elementalist_lightning_arc': 'lightning', 'spiritualist_dissipation': 'spirit',
               'geometer_collapse': 'geometry', 'geometer_triangulation': 'geometry', 'sentinel_explosive_shot': 'fire',
               'sentinel_headshot': 'physical', 'hunter_freezing_trap': 'ice', 'hunter_covering_shot': 'physical',
               'warden_charge': 'nature', 'warden_summon': 'nature'}

# (family, element) rows of the 54 non-signature P6 cues from docs/epics/e08_p6_a1_delivery.md
GRID = {
    'cast': 'arcane blood fire geometry ice lightning nature physical spirit',
    'projectile': 'arcane fire geometry ice lightning nature physical',
    'melee': 'blood physical',
    'impact': 'arcane blood fire geometry ice lightning nature physical spirit',
    'dot': 'blood fire geometry nature',
    'area': 'arcane blood fire geometry ice lightning nature physical spirit',
    'trap': 'fire ice nature',
    'buff': 'blood nature physical',
    'heal': 'blood spirit',
    'movement': 'blood physical',
    'summon': 'nature',
    'charge': 'nature physical',
    'teleport': 'arcane',
}

ONESHOTS = {  # name -> (renderer, peak dBFS, wet, lp, recipe)
    'world_cast_start': (lambda r: d_cast('arcane', r, 0.26, (0.8, 1.3)), -12.0, 0.09, 11000, 'neutral arcane cast: soft FM bell rise + air band'),
    'world_cast_cancel': (w_cast_cancel, -12.0, 0.06, 10000, 'falling FM tone with low-passed noise puff'),
    'world_projectile_launch': (lambda r: d_projectile('physical', r, 0.24), -9.0, 0.07, 11500, 'neutral launch: wood thunk, click, air whoosh'),
    'world_impact': (lambda r: d_impact('physical', r, 0.30), -5.0, 0.10, 11500, 'neutral hit: click + wood/metal body + soft thump'),
    'world_area_start': (lambda r: d_area('arcane', r, 0.72), -7.0, 0.14, 11500, 'neutral arcane area: swell, burst, tail'),
    'world_area_end': (w_area_end, -10.0, 0.10, 10500, 'falling FM tone + falling noise sweep + soft thump'),
    'world_teleport': (lambda r: d_teleport('arcane', r, 0.46, 0.95), -7.0, 0.14, 12000, 'neutral arcane teleport: suck, pop, sparkle'),
    'world_death': (w_death, -6.0, 0.14, 9000, 'falling spirit pad + low-passed breath + low thump'),
    'world_revive': (w_revive, -8.0, 0.14, 11500, 'rising spirit arpeggio over an air glow'),
    'ui_confirm': (w_ui_confirm, -9.0, 0.04, 12000, 'two soft geometric notes (up a fifth)'),
    'ui_cancel': (w_ui_cancel, -10.0, 0.04, 10000, 'two soft descending geometric notes + tick'),
}


def build_cues():
    """-> ordered list of dict(name, path, id, family, element, peak_db, signal)."""
    cues = []
    for fam, els in GRID.items():
        render, peak, wet, lp = FAMILIES[fam]
        for el in els.split():
            cid = f'p6.{fam}.{el}'
            sig = render(el, rng_for(cid))
            cues.append(dict(name=f'p6/{fam}_{el}', id=cid, family=fam, element=el, peak_db=peak, wet=wet, lp=lp, raw=sig,
                             recipe=f'{FAMILY_RECIPE[fam]}; {ELEMENT_RECIPE[el]}'))
    for suf, (render, peak, wet, lp, recipe) in SIGNATURES.items():
        cid = f'p6.sig.{suf}'
        cues.append(dict(name=f'p6/sig_{suf}', id=cid, family='signature', element=SIG_ELEMENT[suf], peak_db=peak, wet=wet, lp=lp,
                         raw=render(rng_for(cid)), recipe=recipe))
    for name, (render, peak, wet, lp, recipe) in ONESHOTS.items():
        cues.append(dict(name=name, id=name, family='oneshot', element='neutral', peak_db=peak, wet=wet, lp=lp,
                         raw=render(rng_for(name)), recipe=recipe))
    return cues


def write_wav(path, x):
    pcm = np.round(np.clip(x, -1, 1) * 32767).astype('<i2')
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return pcm


def read_wav(path):
    with wave.open(str(path), 'rb') as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1 and w.getsampwidth() == 2
        return np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(float) / 32768.0


def db(v):
    return 20 * math.log10(max(v, 1e-9))


def generate():
    prov_path = AUDIO / 'provenance.json'
    prov = json.loads(prov_path.read_text(encoding='utf-8'))
    out = []
    for cue in build_cues():
        x = finish(cue['raw'], cue['peak_db'], cue['wet'], cue['lp'])
        pcm = write_wav(AUDIO / (cue['name'] + '.wav'), x)
        f = pcm.astype(float) / 32768.0
        peak = float(np.max(np.abs(f)))
        rms = float(math.sqrt(np.mean(f * f)))
        entry = {
            'sha256': hashlib.sha256((AUDIO / (cue['name'] + '.wav')).read_bytes()).hexdigest(),
            'frames': int(len(pcm)), 'duration_s': round(len(pcm) / RATE, 4),
            'peak': round(peak, 6), 'peak_dbfs': round(db(peak), 2), 'target_peak_dbfs': cue['peak_db'],
            'rms': round(rms, 6), 'rms_dbfs': round(db(rms), 2), 'dc_offset': round(float(np.mean(f)), 7),
            'edge_delta': round(abs(float(f[0]) - float(f[-1])), 6),
            'path': f"res://assets/audio/e08/{cue['name']}.wav",
            'cue_id': cue['id'], 'family': cue['family'], 'element': cue['element'],
            'recipe': cue['recipe'], 'generator': GENERATOR,
            'source': 'original synthesis, no external samples',
        }
        prov['samples'][cue['name']] = entry
        out.append((cue['name'], entry))
    prov['p6_a3'] = {'generator': GENERATOR, 'note': 'P6 A3 layered synthesis: 75 cues in p6/ plus re-rendered world_*/ui_* one-shots; ambience beds remain owned by prepare_e08_pilot_audio.py'}
    prov_path.write_text(json.dumps(prov, indent=2) + '\n', encoding='utf-8')
    for name, e in out:
        print(f"{name:42s} {e['duration_s']:5.3f}s peak {e['peak_dbfs']:6.2f} rms {e['rms_dbfs']:6.2f} dc {e['dc_offset']:+.1e}")
    print(len(out), 'files')


# --------------------------------------------------------------------------- preview + stress clip
def limiter(x, ceiling_db=-1.0, look_ms=5.0):
    """look-ahead brick-wall limiter: windowed minimum of the required gain, then a box smoothing that stays
    inside the window, so the output never exceeds the ceiling (no hard clipping, no overshoot)."""
    c = 10 ** (ceiling_db / 20)
    need = np.minimum(1.0, c / np.maximum(np.abs(x), 1e-9))
    w = int(look_ms / 1000 * RATE)
    pad = np.concatenate([np.ones(w), need, np.ones(w)])
    mn = np.lib.stride_tricks.sliding_window_view(pad, 2 * w + 1).min(axis=1)
    h = w // 2
    padm = np.concatenate([np.full(h, 1.0), mn, np.full(h, 1.0)])
    g = np.convolve(padm, np.ones(2 * h + 1) / (2 * h + 1), 'valid')
    return x * g, g


def preview(outdir, olddir):
    outdir = Path(outdir); olddir = Path(olddir)
    outdir.mkdir(parents=True, exist_ok=True)

    def new(name):
        return read_wav(AUDIO / (name + '.wav'))

    def old(name):
        return read_wav(olddir / (name + '.wav'))
    seq = []  # (label, signal, group_gap_before)
    chains = [('arcane', ['cast', 'projectile', 'impact']), ('fire', ['cast', 'projectile', 'impact']),
              ('ice', ['cast', 'projectile', 'impact']), ('lightning', ['cast', 'projectile', 'impact']),
              ('nature', ['cast', 'projectile', 'impact']), ('physical', ['cast', 'projectile', 'impact']),
              ('geometry', ['cast', 'projectile', 'impact']), ('blood', ['cast', 'impact']), ('spirit', ['cast', 'impact'])]
    for el, fams in chains:
        for i, fam in enumerate(fams):
            seq.append((f'{el}: {fam}', new(f'p6/{fam}_{el}'), 0.9 if i == 0 else 0.35))
    items = [('melee swing light (physical)', 'p6/melee_physical'), ('melee swing heavy (signature slash)', 'p6/sig_swordsman_slash'),
             ('melee blood', 'p6/melee_blood'), ('buff (physical)', 'p6/buff_physical'), ('buff (blood)', 'p6/buff_blood'),
             ('heal (spirit)', 'p6/heal_spirit'), ('heal (blood)', 'p6/heal_blood'),
             ('trap trigger (fire)', 'p6/trap_fire'), ('trap trigger (ice)', 'p6/trap_ice'), ('trap trigger (nature)', 'p6/trap_nature'),
             ('movement (physical)', 'p6/movement_physical'), ('movement (blood)', 'p6/movement_blood'),
             ('teleport (arcane)', 'p6/teleport_arcane'), ('area (fire)', 'p6/area_fire'), ('area (ice)', 'p6/area_ice'),
             ('dot (fire)', 'p6/dot_fire'), ('charge (nature)', 'p6/charge_nature'), ('summon (nature)', 'p6/summon_nature'),
             ('signature: mage fireball', 'p6/sig_mage_fireball'), ('signature: lightning arc', 'p6/sig_elementalist_lightning_arc'),
             ('signature: arrow rain', 'p6/sig_archer_arrow_rain'), ('signature: terrifying shout', 'p6/sig_swordsman_terrifying_shout'),
             ('death (new world_death)', 'world_death'), ('revive (new world_revive)', 'world_revive'),
             ('UI confirm (new)', 'ui_confirm'), ('UI cancel (new)', 'ui_cancel')]
    for i, (lab, nm) in enumerate(items):
        seq.append((lab, new(nm), 0.9 if i == 0 else 0.35))
    seq.append(('OLD world_impact', old('world_impact'), 0.9))
    seq.append(('NEW world_impact', new('world_impact'), 0.35))
    seq.append(('OLD world_projectile_launch', old('world_projectile_launch'), 0.9))
    seq.append(('NEW world_projectile_launch', new('world_projectile_launch'), 0.35))
    seq.append(('OLD ui_confirm', old('ui_confirm'), 0.9))
    seq.append(('NEW ui_confirm', new('ui_confirm'), 0.35))
    seq.append(('OLD world_death', old('world_death'), 0.9))
    seq.append(('NEW world_death', new('world_death'), 0.35))
    t = 0.3
    labels = []
    total = sum(len(s) for _, s, _ in seq) / RATE + sum(g for _, _, g in seq) + 1.0
    buf = np.zeros(int(total * RATE))
    for lab, s, gap in seq:
        t += gap if labels else 0
        i = int(t * RATE)
        buf[i:i + len(s)] += s
        labels.append({'label': lab, 'start_s': round(t, 3), 'duration_s': round(len(s) / RATE, 3)})
        t += len(s) / RATE
    buf = buf[:int((t + 0.5) * RATE)]
    assert np.max(np.abs(buf)) < 1.0
    write_wav(outdir / 'e08_p6_a3_preview.wav', buf)
    (outdir / 'e08_p6_a3_preview_labels.json').write_text(json.dumps({'file': 'e08_p6_a3_preview.wav', 'rate_hz': RATE, 'gap_within_group_s': 0.35, 'gap_between_groups_s': 0.9, 'items': labels}, indent=2) + '\n', encoding='utf-8')

    # stress: 24 overlapping impacts + casts (all started within 0.35 s), hard limiter at -1 dB
    r = rng_for('stress')
    fams = [('impact', e) for e in GRID['impact'].split()] + [('cast', e) for e in GRID['cast'].split()]
    n = int(2.2 * RATE)
    mixbuf = np.zeros(n)
    for k in range(24):
        fam, el = fams[k % len(fams)]
        s = new(f'p6/{fam}_{el}')
        off = int(r.uniform(0.0, 0.35) * RATE)
        m = min(len(s), n - off)
        mixbuf[off:off + m] += s[:m] * r.uniform(0.9, 1.0)
    pre_peak = float(np.max(np.abs(mixbuf)))
    limited, gain = limiter(mixbuf, -1.0)
    post_peak = float(np.max(np.abs(limited)))
    stats = {
        'voices': 24, 'pre_limiter_peak_dbfs': round(db(pre_peak), 2), 'pre_limiter_peak_linear': round(pre_peak, 4),
        'samples_above_full_scale_before': int(np.sum(np.abs(mixbuf) > 1.0)),
        'post_limiter_peak_dbfs': round(db(post_peak), 3), 'post_limiter_peak_linear': round(post_peak, 5),
        'samples_above_ceiling_after': int(np.sum(np.abs(limited) > 10 ** (-1 / 20) + 1e-6)),
        'post_rms_dbfs': round(db(float(math.sqrt(np.mean(limited ** 2)))), 2),
        'max_gain_reduction_db': round(-db(float(np.min(gain))), 2),
        'mean_gain_reduction_db_where_active': round(-db(float(np.mean(gain[gain < 0.999]))) if np.any(gain < 0.999) else 0.0, 2),
        'fraction_of_samples_limited': round(float(np.mean(gain < 0.999)), 4),
    }
    write_wav(outdir / 'e08_p6_a3_stress_24_voices_limited.wav', limited)
    (outdir / 'e08_p6_a3_stress_stats.json').write_text(json.dumps(stats, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(stats, indent=2))
    print('preview seconds', round(len(buf) / RATE, 1), 'peak dBFS', round(db(float(np.max(np.abs(buf)))), 2))


if __name__ == '__main__':
    if sys.argv[1:2] == ['preview']:
        preview(sys.argv[2], sys.argv[3])
    else:
        generate()
