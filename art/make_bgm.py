#!/usr/bin/env python3
"""Make the background music: one quiet ambience per realm (Josh, Nov 2026), synthesised here, no samples.

    python3 art/make_bgm.py [out_dir]      (needs numpy + ffmpeg with libvorbis)

Writes mobile/android/app/src/main/res/raw/bgm_<r>.ogg for the realms 0…7 (the realms after 7 reuse bgm_7 at
another pitch, in the player: no file of their own). Each piece is a loop of 48 s that closes on itself: every
note, swell and echo is written into a ring (indexes wrap), and the reverb is a circular convolution, so the last
sample runs into the first. The higher the realm, the wider and brighter: wind and a few plucked notes for the
mortal, breath-like swells, a slow drum, bell tones, a bamboo flute, high chimes, thunder under a dark drone, and
open fifths with a choir-like pad at the top. All in pentatonic modes.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
LEN = 48.0
N = int(SR * LEN)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')


def hz(semi, base=146.83):  # D3
    return base * 2 ** (semi / 12)


GONG = [0, 2, 4, 7, 9]  # major pentatonic (宫)
YU = [0, 3, 5, 7, 10]  # minor pentatonic (羽)


def scale(mode, lo, hi):
    return [o * 12 + s for o in range(lo, hi) for s in mode]


class Ring:
    def __init__(self):
        self.b = np.zeros((2, N))

    def add(self, at, sig, pan=0.0, gain=1.0):
        """[sig] starting at [at] seconds, wrapped around the loop"""
        i = int(at * SR) % N
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        idx = (i + np.arange(len(sig))) % N
        np.add.at(self.b[0], idx, sig * gain * l)
        np.add.at(self.b[1], idx, sig * gain * r)


def tt(d):
    return np.arange(int(d * SR)) / SR


def pluck(f, d=5.0, bright=1.0):
    """a guqin-like string: harmonics that die away, the high ones first, a soft slide into the note"""
    t = tt(d)
    bend = 1 + 0.012 * np.exp(-t * 9)
    ph = 2 * np.pi * f * np.cumsum(bend) / SR
    s = np.zeros_like(t)
    for k, a in enumerate([1, .55, .32, .2, .12, .07, .04], 1):
        s += a * bright ** (k - 1) * np.sin(k * ph * (1 + 0.0004 * k * k)) * np.exp(-t * (0.55 + 0.42 * k))
    att = np.minimum(1, t / 0.006)
    return s * att * np.minimum(1, (d - t) / 0.3)


def flute(f, d, vib=5.2):
    """a bamboo flute: a breathy sine with a late vibrato"""
    t = tt(d)
    v = 1 + 0.006 * np.sin(2 * np.pi * vib * t) * np.minimum(1, t / 0.9)
    ph = 2 * np.pi * f * np.cumsum(v) / SR
    env = np.minimum(1, t / 0.28) * np.minimum(1, (d - t) / 0.6)
    s = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    return s * env


def bell(f, d=7.0):
    """a bronze bell or chime: partials that are not whole multiples"""
    t = tt(d)
    s = np.zeros_like(t)
    for m, a, dec in [(1, 1, .5), (2.0, .5, .7), (2.76, .35, .9), (4.07, .2, 1.3), (5.4, .12, 1.9), (6.8, .06, 2.6)]:
        s += a * np.sin(2 * np.pi * f * m * t) * np.exp(-t * dec)
    return s * np.minimum(1, t / 0.004) * np.minimum(1, (d - t) / 0.5)


def drum(d=2.2, f=58.0):
    t = tt(d)
    ph = 2 * np.pi * np.cumsum(f * (1 + 0.5 * np.exp(-t * 22))) / SR
    return np.sin(ph) * np.exp(-t * 3.2) * np.minimum(1, t / 0.004)


def pad(r, freqs, gain, cycles=(1, 2, 3), pan_w=0.5, rng=None):
    """held tones over the whole loop: each breathes in a whole number of cycles, so the loop closes"""
    t = np.arange(N) / SR
    for i, f in enumerate(freqs):
        f = round(f * LEN) / LEN  # a whole number of periods in the loop
        for det in (-1, 1):
            ff = f + det * round(0.11 * LEN) / LEN
            lfo = 0.55 + 0.45 * np.sin(2 * np.pi * cycles[i % len(cycles)] * t / LEN + rng.uniform(0, 6.28))
            ph = 2 * np.pi * ff * t + rng.uniform(0, 6.28)
            # overtones: a phone's speaker plays little under 200 Hz, the low tones are heard through these
            s = (np.sin(ph) + 0.42 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph) + 0.08 * np.sin(4 * ph)) * lfo
            r.add(0, s, pan=det * pan_w * (0.4 + 0.6 * rng.random()), gain=gain / (1 + 0.35 * i))


def noise_ring(rng, lo, hi, cycles=2, depth=0.6):
    """band-limited noise that loops (shaped in the frequency domain): wind, breath"""
    sp = np.fft.rfft(rng.standard_normal(N))
    fr = np.fft.rfftfreq(N, 1 / SR)
    w = np.exp(-0.5 * ((np.log(np.maximum(fr, 1)) - np.log(np.sqrt(lo * hi))) / (np.log(hi / lo) / 2.2)) ** 2)
    s = np.fft.irfft(sp * w, N)
    s /= np.abs(s).max()
    t = np.arange(N) / SR
    return s * (1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / LEN + rng.uniform(0, 6.28))))


def reverb(b, rng, secs=3.2, wet=0.35, damp=2600.0):
    """a hall, as a circular convolution with a decaying noise tail: the echo of the end runs into the start"""
    n = int(secs * SR)
    out = np.zeros_like(b)
    fr = np.fft.rfftfreq(N, 1 / SR)
    lp = 1 / np.sqrt(1 + (fr / damp) ** 2)
    for ch in range(2):
        ir = np.zeros(N)
        ir[:n] = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / secs))
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt((ir**2).sum())
        out[ch] = np.fft.irfft(np.fft.rfft(b[ch]) * np.fft.rfft(ir) * lp, N)
    cross = 0.25
    out = np.stack([out[0] * (1 - cross) + out[1] * cross, out[1] * (1 - cross) + out[0] * cross])
    return b * (1 - wet * 0.4) + out * wet


def melody(r, rng, notes, voice, n, gain, grid=1.5, pan_w=0.6, **kw):
    """[n] notes at random places on a slow grid, moving by small steps through [notes]"""
    slots = rng.choice(int(LEN / grid), size=n, replace=False)
    i = rng.integers(len(notes))
    for s in sorted(slots):
        i = int(np.clip(i + rng.choice([-2, -1, -1, 1, 1, 2]), 0, len(notes) - 1))
        at = s * grid + rng.uniform(-0.05, 0.05)
        r.add(at, voice(hz(notes[i]), **kw), pan=rng.uniform(-pan_w, pan_w), gain=gain * rng.uniform(0.7, 1.0))


def realm(k):
    rng = np.random.default_rng(1000 + k)
    r = Ring()
    wet, damp = 0.34, 2600.0
    if k == 0:  # 凡人: the wind, a few low plucked notes
        r.add(0, noise_ring(rng, 180, 900, 3, 0.7), -0.3, 0.05)
        r.add(0, noise_ring(rng, 300, 1400, 2, 0.8), 0.4, 0.035)
        pad(r, [hz(-12), hz(-5)], 0.05, rng=rng)
        melody(r, rng, scale(GONG, 0, 1) + [12], pluck, 9, 0.30, grid=2.0, d=6.0, bright=0.8)
    elif k == 1:  # 炼气: breath-like swells, qi gathering
        r.add(0, noise_ring(rng, 400, 2200, 6, 0.95), 0.0, 0.05)
        pad(r, [hz(-12), hz(-5), hz(0), hz(4)], 0.07, cycles=(6, 3, 6, 4), rng=rng)
        melody(r, rng, scale(GONG, 0, 2), pluck, 12, 0.26, grid=1.5, d=5.5)
    elif k == 2:  # 筑基: a slow, low drum under the strings
        for b in range(8):
            r.add(b * 6.0, drum(), 0, 0.42)
            r.add(b * 6.0 + 3.0, drum(1.6, 74), 0.1, 0.16)
        pad(r, [hz(-12), hz(-5), hz(2)], 0.06, rng=rng)
        melody(r, rng, scale(GONG, 0, 2), pluck, 16, 0.27, grid=1.5, d=5.0, bright=1.05)
    elif k == 3:  # 金丹: warm bell tones, a golden shimmer
        pad(r, [hz(-12), hz(-5), hz(4), hz(7)], 0.065, rng=rng)
        melody(r, rng, scale(GONG, 1, 2), bell, 9, 0.11, grid=2.0)
        melody(r, rng, scale(GONG, 0, 2), pluck, 12, 0.24, grid=1.5, d=5.5)
        melody(r, rng, scale(GONG, 3, 4), bell, 7, 0.022, grid=3.0, d=4.0)
        wet = 0.4
    elif k == 4:  # 元婴: a bamboo flute sings over the strings
        pad(r, [hz(-12), hz(-5), hz(0), hz(7)], 0.06, rng=rng)
        notes = scale(GONG, 1, 2) + [24]
        i, at = 2, 1.0
        while at < LEN - 5:
            i = int(np.clip(i + rng.choice([-2, -1, 1, 1, 2]), 0, len(notes) - 1))
            d = rng.choice([2.5, 3.5, 5.0])
            r.add(at, flute(hz(notes[i]), d), rng.uniform(-0.25, 0.25), 0.10)
            at += d + rng.choice([0.0, 0.5, 2.5])
        melody(r, rng, scale(GONG, 0, 1), pluck, 11, 0.24, grid=2.0, d=6.0)
        wet = 0.42
    elif k == 5:  # 化神: thin air, high pads and chimes far apart
        pad(r, [hz(-12), hz(7), hz(12), hz(16), hz(19)], 0.055, cycles=(1, 2, 3, 4, 5), pan_w=0.9, rng=rng)
        r.add(0, noise_ring(rng, 2500, 7000, 4, 0.9), 0.0, 0.012)
        melody(r, rng, scale(GONG, 2, 4), bell, 14, 0.034, grid=1.5, pan_w=0.9, d=6.0)
        melody(r, rng, scale(GONG, 1, 2), flute, 5, 0.06, grid=4.0, d=5.0)
        wet, damp = 0.5, 3400.0
    elif k == 6:  # 渡劫: a dark drone, thunder far off, a tense minor mode
        pad(r, [hz(-24), hz(-17), hz(-12), hz(-9)], 0.085, cycles=(1, 3, 2, 5), rng=rng)
        r.add(0, noise_ring(rng, 150, 700, 5, 0.9), 0.0, 0.05)
        for at in (4.0, 17.5, 29.0, 41.0):  # thunder: low noise bursts that roll off
            n = int(5.5 * SR)
            x = np.cumsum(rng.standard_normal(n))
            x -= np.linspace(x[0], x[-1], n)
            sp = np.fft.rfft(x)
            fr = np.fft.rfftfreq(n, 1 / SR)
            x = np.fft.irfft(sp * (fr > 28) * (1 / (1 + (fr / 110) ** 2)), n)
            t = tt(5.5)[:n]
            env = np.minimum(1, t / 0.08) * np.exp(-t * 0.9) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.1 * t) ** 2)
            r.add(at, x / np.abs(x).max() * env, rng.uniform(-0.6, 0.6), 0.34)
        melody(r, rng, scale(YU, 0, 1), pluck, 10, 0.27, grid=2.0, d=6.0, bright=1.1)
        melody(r, rng, scale(YU, -1, 0), bell, 4, 0.10, grid=6.0)
        wet, damp = 0.45, 1900.0
    else:  # 飞升: open fifths, a choir-like pad, chimes: above the clouds
        pad(r, [hz(-12), hz(-5), hz(0), hz(7), hz(12), hz(19), hz(24)], 0.05, cycles=(1, 2, 1, 3, 2, 4, 3), pan_w=0.9, rng=rng)
        t = np.arange(N) / SR
        for f, c in [(hz(12), 2), (hz(16), 3), (hz(19), 4)]:  # voices: tones with a slow vowel-like tremor
            f = round(f * LEN) / LEN
            v = np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * round(4.6 * LEN) / LEN * t))
            r.add(0, v * (0.5 + 0.5 * np.sin(2 * np.pi * c * t / LEN + f)) ** 2, rng.uniform(-0.5, 0.5), 0.024)
        melody(r, rng, scale(GONG, 2, 4), bell, 16, 0.032, grid=1.5, pan_w=0.9, d=6.0)
        melody(r, rng, scale(GONG, 0, 2), pluck, 12, 0.22, grid=2.0, d=6.0)
        melody(r, rng, scale(GONG, 1, 2), flute, 4, 0.07, grid=6.0, d=6.0)
        wet, damp = 0.5, 3600.0
    b = reverb(r.b, rng, wet=wet, damp=damp)
    # roll the deep bass off (phone speakers only rattle there), then the same loudness for every realm, measured
    # where a phone is heard (above 200 Hz), and a soft ceiling
    fr = np.fft.rfftfreq(N, 1 / SR)
    sp = np.fft.rfft(b, axis=1) * (1 / np.sqrt(1 + (95 / np.maximum(fr, 1)) ** 4))
    b = np.fft.irfft(sp, N, axis=1)
    heard = np.fft.irfft(sp * (fr > 200), N, axis=1)
    b *= 0.085 / np.sqrt((heard**2).mean())
    b = np.tanh(b * 1.6) / 1.6
    return b


def main():
    os.makedirs(OUT, exist_ok=True)
    for k in range(8):
        b = realm(k)
        peak, rms = np.abs(b).max(), np.sqrt((b**2).mean())
        seam = np.abs(b[:, 0] - b[:, -1]).max()
        step = np.abs(np.diff(b, axis=1)).max()
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            tmp = f.name
        with wave.open(tmp, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(b.T, -1, 1) * 32767).astype('<i2').tobytes())
        out = os.path.join(OUT, f'bgm_{k}.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '2', '-map_metadata', '-1', out], check=True)
        os.unlink(tmp)
        print(f'bgm_{k}: peak {peak:.2f}  rms {rms:.3f}  seam {seam:.4f} (largest step {step:.4f})  {os.path.getsize(out) // 1024} KB')


main()
