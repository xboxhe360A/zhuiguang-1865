"""Generate original placeholder SFX and ambience for 追光1865 (CC0, self-authored)."""
import math, os, random, struct, subprocess, wave

SR = 44100
SFX = "game/assets/audio/sfx"
AMB = "game/assets/audio/ambience"
random.seed(1865)


def env(t, attack, decay):
    a = min(1.0, t / max(attack, 1e-4))
    return a * math.exp(-t * decay)


def write_wav(name, samples, sr=SR):
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.82 / peak if peak > 0.82 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples)
    with wave.open(os.path.join(SFX, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(data)


def tone(dur, parts, noise=0.0, decay=8.0, attack=0.002):
    n = int(dur * SR); out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for freq, amp, d in parts:
            v += amp * math.sin(2 * math.pi * freq * t + random.random()) * env(t, attack, d)
        if noise:
            v += noise * (random.random() * 2 - 1) * env(t, 0.001, 60)
        out.append(v)
    return out


def lowpass(samples, alpha):
    out = []; y = 0.0
    for s in samples:
        y += alpha * (s - y); out.append(y)
    return out


def highpass(samples, alpha):
    lp = lowpass(samples, alpha)
    return [s - l for s, l in zip(samples, lp)]


def noise_burst(dur, alpha=0.15, mod=0.0, attack=0.005, decay=9.0):
    n = int(dur * SR); raw = [random.random() * 2 - 1 for _ in range(n)]
    lp = lowpass(raw, alpha)
    out = []
    for i, s in enumerate(lp):
        t = i / SR
        m = 1.0 + mod * math.sin(2 * math.pi * 27 * t)
        out.append(s * env(t, attack, decay) * m)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, s in enumerate(tr):
            out[i] += s
    return out


def slice_wrap(samples, seconds):
    n = int(seconds * SR)
    return samples[:n]


def loopify(samples, seconds, fade=1.0):
    """Crossfade the overhang into the head so the clip loops without a click."""
    n = int(seconds * SR); f = int(fade * SR)
    out = list(samples[:n])
    for i in range(f):
        w = i / f
        out[i] = samples[i] * w + samples[n + i] * (1 - w)
    return out


def save_ogg(name, samples):
    tmp = os.path.join(AMB, name.replace(".ogg", ".wav"))
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = 0.55 / peak if peak > 0.55 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * norm)) * 32767)) for s in samples)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
                    "-c:a", "libvorbis", "-q:a", "4", os.path.join(AMB, name)], check=True)
    os.remove(tmp)


# ---- SFX ----
write_wav("click.wav", tone(0.09, [(2350, 0.5, 120), (3520, 0.25, 160)], noise=0.18, decay=70))
write_wav("brass_tick.wav", tone(0.42, [(1780, 0.5, 16), (2650, 0.3, 22), (4020, 0.16, 30)], noise=0.1, decay=12))
write_wav("paper.wav", noise_burst(0.34, alpha=0.55, mod=0.5, decay=11))
write_wav("chime.wav", tone(1.5, [(523.25, 0.4, 2.4), (1046.5, 0.24, 3.0), (1568, 0.12, 3.8), (2093, 0.06, 4.6)], decay=2.0))
write_wav("stamp.wav", mix(
    tone(0.55, [(72, 0.9, 8), (48, 0.5, 6)], noise=0.2, decay=9),
    tone(0.55, [(58, 0.6, 4)], decay=4),
))
write_wav("seal.wav", mix(
    noise_burst(0.55, alpha=0.06, decay=9),
    tone(0.55, [(92, 0.5, 10), (138, 0.2, 14)], decay=8),
))
write_wav("align_snap.wav", mix(
    tone(0.8, [(98, 0.55, 5.0), (196, 0.25, 6.0), (294, 0.12, 7.0)]),
    tone(0.8, [(1760, 0.18, 3.2), (2637, 0.08, 4.0)]),
))
write_wav("tear.wav", mix(noise_burst(0.36, alpha=0.33, mod=1.1, decay=8), tone(0.36, [(180, 0.18, 22)])))
write_wav("pencil.wav", noise_burst(0.42, alpha=0.9, mod=0.7, decay=6))
write_wav("shutter.wav", mix(
    tone(0.08, [(3100, 0.5, 140)], noise=0.4, decay=70),
    tone(0.08, [(2400, 0.4, 130)], noise=0.3, decay=70),
))
write_wav("wood.wav", tone(0.22, [(420, 0.6, 30), (840, 0.3, 42), (1260, 0.14, 55)], noise=0.06, decay=24))
write_wav("wrong.wav", mix(tone(0.42, [(90, 0.5, 12)], noise=0.12), tone(0.42, [(74, 0.3, 10)])))
write_wav("water.wav", mix(noise_burst(0.62, alpha=0.05, mod=0.9, decay=5.5), tone(0.62, [(120, 0.1, 6)])))
write_wav("develop_done.wav", mix(
    noise_burst(1.4, alpha=0.05, mod=0.9, decay=2.2),
    tone(1.5, [(196, 0.22, 1.1), (293.7, 0.12, 1.3)], attack=0.25, decay=1.0),
))

# ---- Ambience ----
def fade_edges(x, f=int(0.8 * SR)):
    for i in range(f):
        w = i / f
        x[i] *= w; x[-1 - i] *= w


n = int(42 * SR)
brown = []; y = 0.0
for _ in range(n):
    y = 0.995 * y + (random.random() * 2 - 1) * 0.02
    brown.append(y)
room = lowpass(brown, 0.02)
drone = []
for i in range(n):
    t = i / SR
    lfo = 0.6 + 0.4 * math.sin(2 * math.pi * t / 19.0)
    drone.append((0.05 * math.sin(2 * math.pi * 73.42 * t) +
                  0.035 * math.sin(2 * math.pi * 110.0 * t + 1.1) +
                  0.02 * math.sin(2 * math.pi * 174.61 * t + 2.3)) * lfo)
clicks = [0.0] * n
for beat in range(0, 42, 5):
    off = int((beat + 0.6) * SR)
    for i in range(int(0.03 * SR)):
        clicks[off + i] += 0.05 * math.sin(2 * math.pi * 2400 * i / SR) * math.exp(-i / SR * 180)
archive = [a * 3.0 + b + c for a, b, c in zip(room, drone, clicks)]
fade_edges(archive)
save_ogg("amb_archive.ogg", loopify(archive, 40.0))

n = int(42 * SR)
wind = lowpass([random.random() * 2 - 1 for _ in range(n)], 0.015)
field = []
for i, s in enumerate(wind):
    t = i / SR
    field.append(s * (0.5 + 0.5 * math.sin(2 * math.pi * t / 13.0)) * 1.6)
field = [s + 0.02 * math.sin(2 * math.pi * 55 * i / SR) for i, s in enumerate(field)]
fade_edges(field)
save_ogg("amb_field.ogg", loopify(field, 40.0))

n = int(34 * SR)
brown = []; y = 0.0
for _ in range(n):
    y = 0.997 * y + (random.random() * 2 - 1) * 0.015
    brown.append(y)
dark = lowpass(brown, 0.012)
drips = [0.0] * n
for at in (3.2, 9.7, 15.3, 23.8, 28.1):
    off = int(at * SR)
    for i in range(int(0.35 * SR)):
        t = i / SR
        f = 1500 * math.exp(-t * 9) + 420
        drips[off + i] += 0.11 * math.sin(2 * math.pi * f * t) * math.exp(-t * 11)
dark = [b * 3.5 + d + 0.02 * math.sin(2 * math.pi * 55 * i / SR) for i, (b, d) in enumerate(zip(dark, drips))]
fade_edges(dark)
save_ogg("amb_darkroom.ogg", loopify(dark, 32.0))

print("done")
