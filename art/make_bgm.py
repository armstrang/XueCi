#!/usr/bin/env python3
"""Make the background sound: nature, one place per realm (Josh, Nov 2026).

    python3 art/make_bgm.py [realm …]      (needs numpy, scipy, ffmpeg with libvorbis)

History: a synthesised ambience (v1.1 test), then sampled zither, flute, bells and strings (v1.1), then a sparse guqin
and xiao (v1.2): all of it was tiring to listen to while studying ("capek di kuping"). Music asks the ear to follow
it. So since v1.3 there is no music at all, only places: sounds without a tune, low and soft, that the mind can let
go of. Everything is synthesised here from shaped noise and small physical models (no recordings, so no licence):
  0 凡人  a quiet village field: soft wind in the grass.
  1 炼气  a bamboo grove: wind, the leaves rustling now and then.
  2 筑基  a small mountain stream over stones.
  3 金丹  fine rain on a temple roof, a drip from the eaves now and then.
  4 元婴  a waterfall far away, a stream nearer.
  5 化神  thin wind high on a mountain: almost silence.
  6 渡劫  steady rain, heavier, and nothing else (no thunder: Josh, no lightning anywhere).
  7 飞升  a clear morning in the mountains: a stream, a few far, soft birds.
No sharp sounds: everything is filtered warm (nothing much above 5 kHz), no insects, no near birds. Each piece is a
loop of 160 s that closes on itself (noise is shaped over the whole loop at once, every slow swell turns a whole
number of times, and events that ring past the end continue at the start).

Writes mobile/android/app/src/main/res/raw/bgm_<r>.ogg (r = 0…7; the realms after 7 reuse bgm_7, in the player).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
LEN = 160.0
N = int(SR * LEN)
T = np.arange(N) / SR
FR = np.fft.rfftfreq(N, 1 / SR)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')


def shaped(rng, shape):
    """looping noise with the spectrum [shape](freq) (the loop is the noise's own period)"""
    s = np.fft.irfft(np.fft.rfft(rng.standard_normal(N)) * shape(np.maximum(FR, 1)), N)
    return s / (np.sqrt((s ** 2).mean()) + 1e-12)


def band(lo, hi, slope=2.0):
    """a soft band: flat between lo and hi, rolling off on both sides"""
    return lambda f: 1 / np.sqrt(1 + (lo / f) ** (2 * slope)) / np.sqrt(1 + (f / hi) ** (2 * slope))


def pink(f):
    return 1 / np.sqrt(f)


def swell(rng, cycles, depth, floor=0.0):
    """a slow level change made of a few whole-number cycles over the loop (gusts, the rain thickening)"""
    s = np.zeros(N)
    for c in cycles:
        s += np.sin(2 * np.pi * c * T / LEN + rng.uniform(0, 6.3)) / len(cycles)
    s = (s - s.min()) / (s.max() - s.min() + 1e-12)
    return floor + (1 - floor) * (1 - depth + depth * s)


def stereo(rng, shape, width=.7):
    """two channels from partly shared noise (a wide, natural bed)"""
    a, b, c = shaped(rng, shape), shaped(rng, shape), shaped(rng, shape)
    return np.stack([a * (1 - width) + b * width, a * (1 - width) + c * width], axis=1)


class Ring:
    def __init__(self):
        self.b = np.zeros((N, 2))

    def add(self, at, sig, pan=0.0, gain=1.0):
        i = int(at * SR) % N
        l, r = np.cos((pan + 1) * np.pi / 4) * 1.41, np.sin((pan + 1) * np.pi / 4) * 1.41
        sig = sig[:N]
        idx = (i + np.arange(len(sig))) % N
        np.add.at(self.b[:, 0], idx, sig * gain * l)
        np.add.at(self.b[:, 1], idx, sig * gain * r)


def bubble(rng, f0=None, dur=None):
    """a water bubble: a short sine that rises in pitch as it dies away (the sound of a stream is many of these)"""
    f0 = f0 or np.exp(rng.uniform(np.log(260), np.log(1100)))
    dur = dur or rng.uniform(.03, .09)
    t = np.arange(int(dur * 2.5 * SR)) / SR
    rise = 1 + rng.uniform(.4, 1.6) * t / dur
    ph = 2 * np.pi * f0 * np.cumsum(rise) / SR
    return np.sin(ph) * np.exp(-t / dur * 3) * np.minimum(1, t / .002)


def drop(rng, soft=1.0):
    """a raindrop or a drip landing: a tiny noise tick, warm"""
    n = int(rng.uniform(.006, .02) * SR)
    x = rng.standard_normal(n) * np.exp(-np.arange(n) / n * 5)
    return sosfilt(butter(2, [rng.uniform(500, 1200), rng.uniform(2500, 4200)], 'band', fs=SR, output='sos'), x) * soft


def bird(rng):
    """a far, soft bird: two or three short whistled glides, a little apart"""
    out = []
    f = rng.uniform(2100, 2900)
    for _ in range(rng.integers(2, 4)):
        d = rng.uniform(.08, .16)
        t = np.arange(int(d * SR)) / SR
        g = f * (1 + rng.uniform(-.18, .22) * t / d)
        s = np.sin(2 * np.pi * np.cumsum(g) / SR) * np.sin(np.pi * t / d) ** 2
        out += [s, np.zeros(int(rng.uniform(.05, .12) * SR))]
        f *= rng.uniform(.9, 1.1)
    return np.concatenate(out)


def stream(rng, r, rate, level, pan_w=.6):
    """bubbles at random over the loop: [rate] per second; and the low bed under them"""
    for at in rng.uniform(0, LEN, int(rate * LEN)):
        r.add(at, bubble(rng), rng.uniform(-pan_w, pan_w), level * rng.uniform(.15, 1) ** 2)
    return stereo(rng, band(150, 1400)) * .035 * level / .3


def realm(k):
    rng = np.random.default_rng(5300 + k)
    r = Ring()
    if k == 0:  # 凡人: soft wind in the grass
        b = stereo(rng, lambda f: band(120, 900)(f) * pink(f)) * swell(rng, [3, 5, 8], .7)[:, None]
        b += stereo(rng, band(900, 3500)) * .12 * swell(rng, [4, 7], .9)[:, None]  # the grass
    elif k == 1:  # 炼气: a bamboo grove: wind, the leaves rustling in gusts
        g = swell(rng, [4, 6, 11], .85)
        b = stereo(rng, lambda f: band(150, 800)(f) * pink(f)) * g[:, None]
        b += stereo(rng, band(1200, 4500), .9) * .22 * (g ** 3)[:, None]
        for at in rng.uniform(0, LEN, 18):  # a stalk knocks softly against another
            x = np.sin(2 * np.pi * rng.uniform(380, 520) * np.arange(int(.12 * SR)) / SR) * np.exp(-np.arange(int(.12 * SR)) / SR * 45)
            r.add(at, x, rng.uniform(-.7, .7), .05)
    elif k == 2:  # 筑基: a small stream over stones
        b = stream(rng, r, 55, .3)
    elif k == 3:  # 金丹: fine rain on a roof, a drip from the eaves now and then
        b = stereo(rng, lambda f: band(300, 3200)(f) * pink(f) ** .5, .8) * swell(rng, [2, 5], .3)[:, None]
        for at in rng.uniform(0, LEN, int(70 * LEN)):
            r.add(at, drop(rng), rng.uniform(-.8, .8), .05 * rng.uniform(.2, 1))
        for at in np.arange(0, LEN, 2.9) + rng.uniform(-.4, .4, len(np.arange(0, LEN, 2.9))):
            r.add(at, bubble(rng, rng.uniform(500, 700), .05), -.35, .12)
    elif k == 4:  # 元婴: a far waterfall, a stream nearer
        b = stereo(rng, lambda f: band(80, 700)(f) * pink(f), .6) * .9
        b += stream(rng, r, 30, .22, .8)
    elif k == 5:  # 化神: thin wind high on a mountain, almost silence
        b = stereo(rng, lambda f: band(200, 1100)(f) * pink(f)) * swell(rng, [2, 3, 5], .95)[:, None] * .7
    elif k == 6:  # 渡劫: steady rain, heavier; nothing else
        b = stereo(rng, lambda f: band(200, 3800)(f) * pink(f) ** .4, .85) * swell(rng, [2, 3], .25)[:, None]
        for at in rng.uniform(0, LEN, int(160 * LEN)):
            r.add(at, drop(rng), rng.uniform(-.9, .9), .045 * rng.uniform(.2, 1))
    else:  # 飞升: a clear morning: a stream and a few far birds
        b = stream(rng, r, 35, .25)
        for at in np.sort(rng.uniform(0, LEN, 9)):
            r.add(at, bird(rng), rng.uniform(-.8, .8), .03)
    x = b + r.b
    # warm: nothing sharp above ~5 kHz; nothing under 70 Hz (phone speakers only rattle there)
    x = np.fft.irfft(np.fft.rfft(x, axis=0) * (band(70, 5000, 1.5)(np.maximum(FR, 1)))[:, None], N, axis=0)
    # the same quiet level for every place; a clean ceiling
    x *= .06 / np.sqrt((x ** 2).mean())
    peak = np.abs(x).max()
    if peak > .5:
        x *= .5 / peak
    return x


def main():
    want = [int(a) for a in sys.argv[1:]] or list(range(8))
    os.makedirs(OUT, exist_ok=True)
    for k in want:
        x = realm(k)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            tmp = f.name
        with wave.open(tmp, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
        out = os.path.join(OUT, f'bgm_{k}.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '0', '-map_metadata',
                        '-1', out], check=True)
        os.unlink(tmp)
        sp = np.abs(np.fft.rfft(x[:, 0])) ** 2
        hi = sp[FR > 4000].sum() / sp.sum()
        seam = np.abs(x[0] - x[-1]).max()
        print(f'bgm_{k}: peak {np.abs(x).max():.2f}  above 4 kHz {hi * 100:.1f} %  seam {seam:.3f}  '
              f'{os.path.getsize(out) // 1024} KB')


main()
