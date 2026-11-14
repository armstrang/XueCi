#!/usr/bin/env python3
"""Make the background music: one quiet piece per realm, after the calm music of the guqin and the xiao.

    python3 art/make_bgm.py [realm …]      (needs numpy, scipy, ffmpeg with libvorbis)

Josh, Nov 2026: the first sampled version (zither, concert flute, glass, bells, string sections, a long hall) was
"not friendly to the ear, dizzying". This one follows what calm Chinese meditation music does:
  - one low plucked zither that sounds like a guqin (dark, woody, long notes, a slow slide into some notes, a soft
    harmonic now and then) and one low breathy flute like a xiao; never more than two voices at once;
  - free rhythm: no beat, phrases like breaths, long silences between them;
  - one pentatonic mode (D E F# A B) over a still drone on D and A, so no two notes ever clash;
  - warm and dark: nothing above about 4 kHz, a short room instead of a hall, no detuned layers (they beat);
  - quiet and even, and a loop of 160 s so it does not feel like a loop.
One theme (four phrases) belongs to the cultivator; each realm is a mood of it:
  0 凡人  the guqin alone; the theme stops halfway. A little wind.
  1 炼气  the xiao alone, on the breath: a tone on the out-breath, silence on the in-breath.
  2 筑基  the guqin in its low register over the drone.
  3 金丹  the guqin, answered by soft harmonics.
  4 元婴  the guqin and the xiao take turns.
  5 化神  almost silence: a harmonic, one long xiao tone, the drone far away.
  6 渡劫  the deep drone and a slow descending guqin: stillness inside the trial.
  7 飞升  the whole theme, home at last: guqin, then the xiao with it.

Instruments: samples from two CC0 (public domain) libraries by Versilian Studios, used only to render the files:
  VCSL       https://github.com/sgossner/VCSL       Dan Tranh (played an octave lower and filtered: the "guqin")
  VSCO 2 CE  https://github.com/sgossner/VSCO-2-CE  flute, lowest register, filtered, with breath (the "xiao")
Clone them (sparse: "Chordophones/Zithers/Dan Tranh", "Woodwinds/Flute/susNV") to ~/sgossner/vcsl and
~/sgossner/vsco-2-ce, or set VCSL and VSCO. The drone, the harmonics and the wind are synthesised here. Every note
is written for XueCi.

Writes mobile/android/app/src/main/res/raw/bgm_<r>.ogg (r = 0…7; the realms after 7 reuse bgm_7 at another pitch, in
the player). Each loop closes on itself: what rings past the end continues at the start.
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt

SR = 44100
LEN = 160.0
N = int(SR * LEN)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')
VCSL = os.environ.get('VCSL', os.path.expanduser('~/sgossner/vcsl'))
VSCO = os.environ.get('VSCO', os.path.expanduser('~/sgossner/vsco-2-ce'))
NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def midi(s):
    return 12 * (int(s[-1]) + 1) + NOTE[s[:-1]]


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def lowpass(x, fc, order=2):
    return sosfilt(butter(order, fc, 'low', fs=SR, output='sos'), x, axis=0)


_cache = {}


def load(path):
    if path not in _cache:
        r = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                           capture_output=True, check=True)
        x = np.frombuffer(r.stdout, np.float32).reshape(-1, 2).astype(np.float64)
        a = np.abs(x).max(axis=1)
        start = max(0, int(np.argmax(a > 0.02 * a.max())) - 64)
        _cache[path] = x[start:] / (a.max() + 1e-9)
    return _cache[path]


def f0(x):
    m = x[int(.15 * SR):int(.15 * SR) + 16384, 0]
    sp = np.abs(np.fft.rfft(m * np.hanning(len(m)), 65536))
    fr = np.fft.rfftfreq(65536, 1 / SR)
    h = sp.copy()
    for k in (2, 3, 4):
        h[:len(sp) // k] *= sp[::k][:len(sp) // k]
    band = (fr > 50) & (fr < 2000)
    return fr[band][np.argmax(h[band])]


class Inst:
    """sampled notes: the nearest sample, moved to the pitch wanted by resampling (with an optional slide)"""

    def __init__(self, folder, pat, only=None):
        self.map = {}
        for p in glob.glob(os.path.join(folder, '*.wav')):
            name = os.path.basename(p)
            if only and not re.search(only, name):
                continue
            m = re.search(r'(?:^|_)' + pat + r'(?=[_.])', name)
            if m:
                self.map.setdefault(12 * (int(m.group(2)) + 1) + NOTE[m.group(1).upper()], []).append(p)
        if not self.map:
            raise SystemExit(f'no samples in {folder}: clone VCSL and VSCO 2 CE (see the top of this file)')
        # the files often name the octave wrongly: measure it
        offs = []
        ks = sorted(self.map)
        for k in ks[len(ks) // 4::max(1, len(ks) // 4)][:3]:
            heard = 69 + 12 * np.log2(f0(load(sorted(self.map[k])[0])) / 440)
            offs.append(round((heard - k) / 12) * 12)
        off = max(set(offs), key=offs.count)
        self.map = {k + off: v for k, v in self.map.items()}
        self.keys = np.array(sorted(self.map))

    def raw(self, m, secs, source_shift=0, slide=0.0, slide_t=.22, loop=False):
        """the note [m] for [secs]; [source_shift] picks a sample that many semitones away (a lower sample played
        up is thinner, a higher one played down is darker and longer); [slide] semitones below at the start"""
        k = int(self.keys[np.argmin(np.abs(self.keys - (m + source_shift)))])
        x = load(sorted(self.map[k])[0])
        n = int(secs * SR)
        t = np.arange(n) / SR
        ratio = 2 ** ((m - k) / 12) * 2 ** (-slide * np.clip(1 - t / slide_t, 0, 1) ** 2 / 12)
        pos = np.cumsum(ratio) - ratio[0]
        if loop and pos[-1] >= len(x) - 2:
            x = _extend(x, int(pos[-1]) + 4)
        pos = pos[pos < len(x) - 2]
        i0 = pos.astype(int)
        fr = (pos - i0)[:, None]
        return x[i0] * (1 - fr) + x[i0 + 1] * fr


def _extend(x, need):
    """a held note made longer by crossfading loops of its steady middle"""
    a, b = int(len(x) * .35), int(len(x) * .85)
    fade = min(int(.3 * SR), (b - a) // 3)
    out = x[:b].copy()
    while len(out) < need:
        seg = x[a:b].copy()
        w = np.linspace(0, 1, fade)[:, None]
        out[-fade:] = out[-fade:] * (1 - w) + seg[:fade] * w
        out = np.concatenate([out, seg[fade:]])
    return out


class Voices:
    def __init__(self):
        self.z = Inst(f'{VCSL}/Chordophones/Zithers/Dan Tranh/Normal', r'([A-Ga-g]#?)(\d)', only=r'_mf_')
        self.f = Inst(f'{VSCO}/Woodwinds/Flute/susNV', r'([A-Ga-g]#?)(-?\d)', only=r'_v1_')
        print(f'  zither notes {self.z.keys.min()}–{self.z.keys.max()}, flute notes {self.f.keys.min()}–{self.f.keys.max()}')

    def qin(self, m, vel=.5, slide=0.0, ring=5.5):
        """the guqin: a zither sample from an octave above played down (darker, longer), filtered warm, a soft
        attack, a long even decay"""
        y = self.z.raw(m, ring, source_shift=12, slide=slide)
        y = lowpass(y, 1500 + 14 * hz(m) / 10, 2)
        t = np.arange(len(y)) / SR
        env = np.minimum(1, t / .012) * np.exp(-t * .55)
        tail = min(len(y), int(.8 * SR))
        env[-tail:] *= np.linspace(1, 0, tail) ** 2
        return y * env[:, None] * vel

    def xiao(self, m, secs, vel=.4, rng=None):
        """the xiao: the flute's low register, filtered dark, a slow breath in and out of the tone, air around it"""
        n = int((secs + 1.4) * SR)
        y = self.f.raw(m, secs + 1.4, loop=True)[:n]
        y = lowpass(y, 1900, 2)
        t = np.arange(len(y)) / SR
        env = np.clip(t / .9, 0, 1) ** 1.5 * np.clip((secs + 1.4 - t) / 1.4, 0, 1) ** 1.5
        y = y * env[:, None]
        if rng is not None:  # breath: a little band-limited air that follows the tone
            air = rng.standard_normal((len(y), 2))
            air = sosfiltfilt(butter(2, [700, 2200], 'band', fs=SR, output='sos'), air, axis=0)
            y = y + air * env[:, None] * .035
        return y * vel

    @staticmethod
    def harmonic(m, vel=.3, ring=4.0):
        """a guqin harmonic (泛音): nearly a pure tone, soft start, dies away"""
        t = np.arange(int(ring * SR)) / SR
        f = hz(m)
        s = np.sin(2 * np.pi * f * t) + .12 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
        s *= np.minimum(1, t / .02) * np.exp(-t * 1.1)
        tail = int(.5 * SR)
        s[-tail:] *= np.linspace(1, 0, tail)
        return np.stack([s, s], axis=1) * vel


class Ring:
    def __init__(self):
        self.b = np.zeros((N, 2))

    def add(self, at, sig, pan=0.0):
        i = int(at * SR) % N
        l, r = np.cos((pan + 1) * np.pi / 4) * 1.41, np.sin((pan + 1) * np.pi / 4) * 1.41
        sig = sig[:N]
        idx = (i + np.arange(len(sig))) % N
        np.add.at(self.b[:, 0], idx, sig[:, 0] * l)
        np.add.at(self.b[:, 1], idx, sig[:, 1] * r)


def drone(notes, level, breath=16.0):
    """a still drone: a few exact overtones per note (whole periods in the loop, nothing detuned, so nothing beats),
    its level breathing very slowly"""
    t = np.arange(N) / SR
    s = np.zeros(N)
    for i, m in enumerate(notes):
        f = round(hz(m) * LEN) / LEN
        for k, a in ((1, 1), (2, .5), (3, .28), (4, .12)):
            s += a / (1 + .5 * i) * np.sin(2 * np.pi * f * k * t + i + k)
    s *= .75 + .25 * np.sin(2 * np.pi * round(LEN / breath) * t / LEN)
    s /= np.abs(s).max()
    return np.stack([s, s], axis=1) * level * .45  # far under the notes: a constant hum tires the ear


def wind(rng, level):
    """soft low wind, looping (noise shaped in the frequency domain; no hiss: nothing above ~900 Hz)"""
    fr = np.fft.rfftfreq(N, 1 / SR)
    w = np.exp(-0.5 * ((np.log(np.maximum(fr, 1)) - np.log(380)) / .5) ** 2)
    t = np.arange(N) / SR
    out = np.zeros((N, 2))
    for c in range(2):
        s = np.fft.irfft(np.fft.rfft(rng.standard_normal(N)) * w, N)
        s /= np.abs(s).max()
        out[:, c] = s * (.5 + .5 * np.sin(2 * np.pi * 5 * t / LEN + c * 1.7)) ** 2
    return out * level


def room(b, rng, secs=1.6, wet=.2):
    """a small warm room, as a circular convolution (the end's echo runs into the start)"""
    n = int(secs * SR)
    fr = np.fft.rfftfreq(N, 1 / SR)
    damp = 1 / np.sqrt(1 + (fr / 1800) ** 2)
    out = np.zeros_like(b)
    for ch in range(2):
        ir = np.zeros(N)
        ir[:n] = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / secs))
        ir[:int(.015 * SR)] = 0
        ir /= np.sqrt((ir ** 2).sum())
        out[:, ch] = np.fft.irfft(np.fft.rfft(b[:, ch]) * np.fft.rfft(ir) * damp, N)
    return b + out * wet


# the theme: four phrases in D 宫 pentatonic. (note, seconds until the next note); free rhythm.
P1 = [('A3', 2.6), ('B3', 1.7), ('D4', 3.8), ('B3', 2.4), ('A3', 1.8), ('F#3', 4.5)]  # rises, settles
P2 = [('E3', 2.4), ('F#3', 1.8), ('A3', 3.6), ('F#3', 2.2), ('E3', 2.0), ('D3', 6.0)]  # comes home
P3 = [('D4', 3.0), ('B3', 2.2), ('A3', 3.8), ('F#3', 2.0), ('A3', 5.0)]  # stays open
P4 = [('A3', 3.2), ('F#3', 2.6), ('E3', 3.0), ('D3', 7.0)]  # home, slowly


def qin_phrase(r, V, rng, phrase, at, vel=.5, shift=0, pan=-.12, stretch=1.0):
    t = at
    for i, (n, d) in enumerate(phrase):
        slide = 2.0 if (i in (2, len(phrase) - 1) and rng.random() < .8) else 0.0
        r.add(t + rng.uniform(-.06, .06), V.qin(midi(n) + shift, vel * rng.uniform(.85, 1.0), slide), pan)
        t += d * stretch * rng.uniform(.94, 1.08)
    return t


def xiao_phrase(r, V, rng, phrase, at, vel=.36, shift=12, pan=.15, stretch=1.25):
    t = at
    for n, d in phrase:
        d = d * stretch
        r.add(t, V.xiao(midi(n) + shift, d * .92, vel, rng), pan)
        t += d
    return t


def realm(k, V):
    rng = np.random.default_rng(4100 + k)
    r = Ring()
    D2, A2, D3 = midi('D2'), midi('A2'), midi('D3')
    dr = drone([D3, A2 + 12], .05)
    if k == 0:  # 凡人: the guqin alone; the theme stops halfway
        qin_phrase(r, V, rng, P1, 6)
        qin_phrase(r, V, rng, P3[:3], 46, .44)
        qin_phrase(r, V, rng, P1[:4], 86, .46)
        qin_phrase(r, V, rng, P3, 122, .42)
        r.b += wind(rng, .028)
        dr *= .5
    elif k == 1:  # 炼气: the xiao on the breath: 6 s out (a tone), 4 s in (silence)
        tones = ['A3', 'F#3', 'E3', 'D3', 'F#3', 'A3', 'B3', 'A3', 'F#3', 'E3', 'F#3', 'D3', 'E3', 'D3', 'A3', 'D3']
        for i, n in enumerate(tones):
            r.add(4 + i * 10, V.xiao(midi(n) + 12, 5.6, .36, rng), .12 if i % 2 else -.12)
        for at in (0, 40, 80, 120):
            r.add(at + 1, V.qin(D3, .34), 0)
    elif k == 2:  # 筑基: the guqin low, over the drone
        dr = drone([D2 + 12, A2], .07)
        t = qin_phrase(r, V, rng, P1, 5, .5, shift=-5)
        qin_phrase(r, V, rng, P4, t + 9, .48, shift=-5)
        t = qin_phrase(r, V, rng, P3, 84, .46, shift=-5)
        qin_phrase(r, V, rng, P4, t + 8, .46, shift=-5)
    elif k == 3:  # 金丹: the guqin, answered by harmonics
        t = qin_phrase(r, V, rng, P1, 5)
        for i, n in enumerate(('A4', 'D5', 'F#5')):
            r.add(t + 2 + i * 2.6, V.harmonic(midi(n), .13), .3)
        t = qin_phrase(r, V, rng, P2, 52, .46)
        for i, n in enumerate(('D5', 'A4')):
            r.add(t + 1 + i * 3.0, V.harmonic(midi(n), .12), .3)
        t = qin_phrase(r, V, rng, P3, 104, .44)
        for i, n in enumerate(('F#5', 'D5', 'A4')):
            r.add(t + 2 + i * 2.8, V.harmonic(midi(n), .12), .3)
    elif k == 4:  # 元婴: the guqin and the xiao take turns
        t = qin_phrase(r, V, rng, P1, 4)
        t = xiao_phrase(r, V, rng, P3[:4], t + 3)
        t = qin_phrase(r, V, rng, P2, t + 5, .46)
        xiao_phrase(r, V, rng, P4, t + 3)
    elif k == 5:  # 化神: almost silence
        dr *= .7
        r.add(8, V.harmonic(midi('A4'), .13, 5), -.3)
        r.add(22, V.harmonic(midi('D5'), .11, 5), .3)
        r.add(44, V.xiao(midi('A4'), 8, .3, rng), 0)
        r.add(70, V.qin(midi('D3'), .4), -.1)
        r.add(78, V.qin(midi('A3'), .36, 2.0), -.1)
        r.add(100, V.harmonic(midi('F#5'), .1, 5), .3)
        r.add(112, V.xiao(midi('F#4'), 8, .28, rng), 0)
        r.add(138, V.harmonic(midi('D5'), .11, 5), -.3)
        r.b += wind(rng, .02)
    elif k == 6:  # 渡劫: the deep drone, a slow descending guqin: still inside the trial
        dr = drone([D2 + 12, A2, D2], .085, breath=20)
        t = qin_phrase(r, V, rng, P4, 6, .5, shift=-5, stretch=1.3)
        t = qin_phrase(r, V, rng, P4, t + 12, .46, shift=-12, stretch=1.3)
        t = qin_phrase(r, V, rng, P3, 86, .44, shift=-5, stretch=1.3)
        qin_phrase(r, V, rng, P4, t + 8, .46, shift=-12, stretch=1.3)
    else:  # 飞升: the whole theme, home
        t = qin_phrase(r, V, rng, P1, 4)
        t = qin_phrase(r, V, rng, P2, t + 3)
        t = xiao_phrase(r, V, rng, P1[:4] + [('A3', 3.2)], t + 6, .34)
        for at in (t - 30, t - 18, t - 6):
            r.add(at, V.qin(midi('D3'), .34), -.15)
        t = xiao_phrase(r, V, rng, P4, t + 3, .34)
        r.add(t - 6, V.qin(midi('D3'), .4), -.15)
        r.add(t - 2, V.harmonic(midi('D5'), .12, 5), .25)
    b = room(r.b + dr, rng)
    b = lowpass(b, 4000, 2)  # nothing sharp
    fr = np.fft.rfftfreq(N, 1 / SR)
    b = np.fft.irfft(np.fft.rfft(b, axis=0) * (1 / np.sqrt(1 + (70 / np.maximum(fr, 1)) ** 4))[:, None], N, axis=0)
    # the same loudness for every realm, by its louder moments (the 95th percentile of half-second levels where a
    # phone is heard), so a sparse piece is not turned up; a clean ceiling well under full scale, no saturation
    heard = np.fft.irfft(np.fft.rfft(b, axis=0) * (fr > 180)[:, None], N, axis=0)
    w = heard[:N // (SR // 2) * (SR // 2), 0].reshape(-1, SR // 2)
    level = np.percentile(np.sqrt((w ** 2).mean(1)), 95)
    b *= 0.07 / level
    peak = np.abs(b).max()
    if peak > .6:
        b *= .6 / peak
    return b


def main():
    want = [int(a) for a in sys.argv[1:]] or list(range(8))
    V = Voices()
    os.makedirs(OUT, exist_ok=True)
    for k in want:
        b = realm(k, V)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            tmp = f.name
        with wave.open(tmp, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(b, -1, 1) * 32767).astype('<i2').tobytes())
        out = os.path.join(OUT, f'bgm_{k}.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '1', '-map_metadata',
                        '-1', out], check=True)
        os.unlink(tmp)
        sp = np.abs(np.fft.rfft(b[:, 0])) ** 2
        fr = np.fft.rfftfreq(N, 1 / SR)
        hi = sp[fr > 3000].sum() / sp.sum()
        win = b[:N // SR * SR, 0].reshape(-1, SR)
        rms = np.sqrt((win ** 2).mean(1))
        print(f'bgm_{k}: peak {np.abs(b).max():.2f}  1-s level median {np.median(rms):.3f} max {rms.max():.3f}  '
              f'above 3 kHz {hi * 100:.2f} %  {os.path.getsize(out) // 1024} KB')


main()
