"""Deterministic, original synthesis for E08. No external recordings or music."""
from pathlib import Path
import hashlib, json, math, random, struct, wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/e08'
RATE = 44100
# seconds, initial/end frequency, amplitude, noise mix
SPECS = {
    'world_cast_start': (0.42, 330, 690, 0.24, 0.05),
    'world_cast_cancel': (0.23, 620, 205, 0.22, 0.12),
    'world_projectile_launch': (0.20, 720, 290, 0.28, 0.18),
    'world_impact': (0.24, 170, 65, 0.33, 0.40),
    'world_area_start': (0.52, 150, 390, 0.25, 0.16),
    'world_area_end': (0.35, 410, 130, 0.21, 0.18),
    'world_teleport': (0.48, 250, 920, 0.25, 0.10),
    'world_death': (0.65, 250, 95, 0.25, 0.12),
    'world_revive': (0.58, 220, 660, 0.25, 0.04),
    'ui_confirm': (0.12, 650, 980, 0.19, 0.00),
    'ui_cancel': (0.14, 500, 300, 0.19, 0.00),
}

def oneshot(name, spec):
    duration, start, end, amplitude, noise = spec
    n = round(duration * RATE)
    rng = random.Random('e08:' + name)
    phase = 0.0
    samples = []
    for i in range(n):
        t = i / (n - 1)
        f = start * (end / start) ** t
        phase += 2 * math.pi * f / RATE
        envelope = math.sin(math.pi * t) ** 0.7 * (1 - 0.45 * t)
        harmonic = math.sin(phase) * 0.72 + math.sin(phase * 2.01) * 0.18
        grain = rng.uniform(-1, 1) * noise
        samples.append(amplitude * envelope * (harmonic + grain))
    return samples

def ambience():
    # A bank of phase-stable periodic sines with integer cycle counts over 8 s.
    # Every oscillator and its slow modulation wrap exactly; no random seam.
    seconds = 8
    n = RATE * seconds
    rng = random.Random('e08:forest-air-v1')
    tones = [(rng.randrange(320, 2200), rng.random() * math.tau, rng.uniform(0.002, 0.006)) for _ in range(28)]
    return [sum(a * math.sin(math.tau * k * i / n + p) for k,p,a in tones) * (0.65 + 0.35 * math.cos(math.tau * i / n)) for i in range(n)]

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
    stats = {name: save(name, oneshot(name, spec)) for name, spec in SPECS.items()}
    stats['ambience_stage'] = save('ambience_stage', ambience())
    (OUT / 'provenance.json').write_text(json.dumps({'author':'RagRPG E08 P3 deterministic synthesis', 'source':'original procedural waveforms, no external recordings', 'license':'project-original', 'rate_hz':RATE, 'format':'PCM16 mono', 'samples':stats}, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(stats, indent=2))
if __name__ == '__main__': main()
