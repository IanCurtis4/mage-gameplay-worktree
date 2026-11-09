"""Deterministic, original synthesis for E08. No external recordings or music.

P6 A3: the 11 world_*/ui_* one-shots are now owned by tools/prepare_e08_p6_audio.py (layered synthesis);
the P3 sine-sweep generator (SPECS/oneshot) was removed from here and survives in git history only.
This script keeps generating the two ambience beds, byte-identically, and merges only their provenance
entries (every other provenance entry is preserved)."""
from pathlib import Path
import hashlib, json, math, random, struct, sys, wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/e08'
RATE = 44100
def ambience():
    # A bank of phase-stable periodic sines with integer cycle counts over 8 s.
    # Every oscillator and its slow modulation wrap exactly; no random seam.
    seconds = 8
    n = RATE * seconds
    rng = random.Random('e08:forest-air-v1')
    tones = [(rng.randrange(320, 2200), rng.random() * math.tau, rng.uniform(0.002, 0.006)) for _ in range(28)]
    return [sum(a * math.sin(math.tau * k * i / n + p) for k,p,a in tones) * (0.65 + 0.35 * math.cos(math.tau * i / n)) for i in range(n)]

def _circular_lowpass(values, alpha):
    # One-pole filter run over two laps so the state at the seam matches: no click.
    n = len(values); y = values[-1]; out = [0.0] * n
    for lap in range(2):
        for i in range(n):
            y += alpha * (values[i] - y)
            if lap: out[i] = y
    return out

def ambience_forest():
    """P5 A2: wind through leaves plus sparse bird chirps, 12 s seamless loop.
    Rustle = circularly high-passed noise, gust-modulated by integer-cycle cosines;
    air = low noise under the gusts; chirps = short vibrato sweeps placed away from
    the seam. Level matched to ambience_stage (RMS about 0.0113)."""
    seconds = 12
    n = RATE * seconds
    rng = random.Random('e08:forest-ambience-v1')
    white = [rng.uniform(-1, 1) for _ in range(n)]
    low = _circular_lowpass(white, 0.025)                       # soft body, below about 170 Hz corner
    smooth = _circular_lowpass(white, 0.55)
    rustle = [smooth[i] - low[i] * 0 for i in range(n)]
    slow = _circular_lowpass(white, 0.08)
    rustle = [rustle[i] - slow[i] for i in range(n)]            # high-passed leaves
    gust_cycles = [(1, 0.5, rng.random() * math.tau), (2, 0.3, rng.random() * math.tau), (5, 0.2, rng.random() * math.tau)]
    values = []
    for i in range(n):
        g = sum(a * math.cos(math.tau * k * i / n + p) for k, a, p in gust_cycles)
        gust = 0.55 + 0.45 * g / 1.0
        gust = max(0.12, gust)
        values.append(gust * (0.9 * rustle[i] + 4.0 * low[i] * (0.4 + 0.6 * gust)))
    rms = math.sqrt(sum(v * v for v in values) / n)
    values = [v * 0.0108 / rms for v in values]
    chirps = [(1.1, 3300, 0.9), (1.45, 3700, 0.7), (4.6, 2900, 0.6), (4.9, 3100, 0.5), (5.15, 3400, 0.5), (8.2, 4100, 0.8), (8.5, 3800, 0.6), (10.4, 3000, 0.7)]
    for start, base, strength in chirps:
        length = round(0.13 * RATE); first = round(start * RATE); phase = 0.0
        for j in range(length):
            t = j / (length - 1)
            f = base * (1.0 + 0.35 * math.sin(math.pi * t) + 0.04 * math.sin(math.tau * 38 * t * 0.13))
            phase += math.tau * f / RATE
            env = math.sin(math.pi * t) ** 2
            values[(first + j) % n] += 0.016 * strength * env * (math.sin(phase) + 0.25 * math.sin(2 * phase))
    mean = sum(values) / n
    values = [v - mean for v in values]
    return values

def save(name, values):
    peak = max(abs(v) for v in values)
    assert peak < 0.95 and all(math.isfinite(v) for v in values)
    data = b''.join(struct.pack('<h', round(max(-1, min(1, v)) * 32767)) for v in values)
    path = OUT / (name + '.wav')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(data)
    return {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'frames':len(values), 'peak':round(peak,6), 'rms':round(math.sqrt(sum(x*x for x in values)/len(values)),6), 'edge_delta':round(abs(values[0]-values[-1]),6)}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if sys.argv[1:] == ['forest']:
        # Regenerate only the P5 forest ambience and merge its provenance entry.
        meta = json.loads((OUT / 'provenance.json').read_text(encoding='utf-8'))
        meta['samples']['ambience_forest'] = save('ambience_forest', ambience_forest())
        (OUT / 'provenance.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
        print(json.dumps(meta['samples']['ambience_forest'], indent=2))
        return
    # Default run: only the two ambience beds; one-shots belong to prepare_e08_p6_audio.py.
    meta = json.loads((OUT / 'provenance.json').read_text(encoding='utf-8'))
    meta['samples']['ambience_stage'] = save('ambience_stage', ambience())
    meta['samples']['ambience_forest'] = save('ambience_forest', ambience_forest())
    (OUT / 'provenance.json').write_text(json.dumps(meta, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: meta['samples'][k] for k in ('ambience_stage', 'ambience_forest')}, indent=2))
if __name__ == '__main__': main()
