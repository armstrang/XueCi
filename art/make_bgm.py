#!/usr/bin/env python3
"""Make the background music, one calm piece per realm (Josh, Nov 2026: "very calming, the psychology of a calm
cultivator, not burning ambition"; made the way Verbarium makes its music, from recorded instruments).

    python3 art/make_bgm.py            (needs numpy, scipy, ffmpeg with libvorbis)

One short theme belongs to the cultivator. It never changes; how far it gets does. The mortal plays only its first
phrase; at each realm it goes a little further, more still; at 飞升 it comes home, whole, for the first time. Nothing
grows louder or faster from realm to realm: the music deepens, it does not rise. Very slow (a breath is 4 s in, 6 s
out), no driving drum, no crescendo, the same loudness from start to end.
  0 凡人  the zither alone, many silences; the theme stops halfway. Wind.
  1 炼气  the flute, long tones on the breath (in 4, out 6); the zither under it, a glass hum.
  2 筑基  the zither plays the theme over low strings that never move: a foundation.
  3 金丹  warm: a hand bell now and then, violas, the zither.
  4 元婴  the flute and the zither answer each other, gently.
  5 化神  almost empty: glass, far bells, long echoes.
  6 渡劫  stillness inside the trial: a soft low gong, a deep drone, the zither in a minor mode. No thunder.
  7 飞升  the theme whole and at rest: zither, flute, strings, harp, bells.

The instruments are samples from two CC0 (public domain) libraries by Versilian Studios, used only to render the
files; nothing of them ships in the app except the rendered music:
  VCSL         https://github.com/sgossner/VCSL        (Dan Tranh zither, gong, Nepalese hand bells, tubular bells,
                                                        wine glasses, bowed psaltery)
  VSCO 2 CE    https://github.com/sgossner/VSCO-2-CE   (flute, viola and cello sections, contrabass, harp)
Clone them (a sparse checkout of those folders is enough, ~500 MB) to ~/sgossner/vcsl and ~/sgossner/vsco-2-ce, or
point VCSL and VSCO at them. Their files often name the note an octave off; each instrument's octave is measured here.
Every note is written for XueCi; none is taken from any soundtrack.

Writes mobile/android/app/src/main/res/raw/bgm_<r>.ogg (r = 0…7; the realms after 7 reuse bgm_7 at another pitch,
in the player). Each is a loop of 64 s that closes on itself: notes and their echoes that run past the end continue
at the start.
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 60.0
BEATS = 64
LEN = BEATS * 60 / BPM
N = int(SR * LEN)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res', 'raw')
VCSL = os.environ.get('VCSL', os.path.expanduser('~/sgossner/vcsl'))
VSCO = os.environ.get('VSCO', os.path.expanduser('~/sgossner/vsco-2-ce'))
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
        'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(s):
    return 12 * (int(s[-1]) + 1) + NOTE[s[:-1]]


def lp(x, fc):
    return sosfilt(butter(2, fc, 'low', fs=SR, output='sos'), x, axis=0)


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
    """the fundamental of a sample's steady part (harmonic product spectrum)"""
    m = x[int(.15 * SR):int(.15 * SR) + 16384, 0]
    if len(m) < 8192:
        m = x[:16384, 0]
    sp = np.abs(np.fft.rfft(m * np.hanning(len(m)), 65536))
    fr = np.fft.rfftfreq(65536, 1 / SR)
    h = sp.copy()
    for k in (2, 3, 4):
        h[:len(sp) // k] *= sp[::k][:len(sp) // k]
    band = (fr > 50) & (fr < 2000)
    return fr[band][np.argmax(h[band])]


class Inst:
    """a sampled instrument: the nearest sample, moved to the pitch wanted by resampling"""

    def __init__(self, folder, pat=r'([A-Ga-g]#?)(-?\d)', only=None, sustain=True, release=.6, ring=4.0,
                 attack=.004, gain=1.0):
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
        # the files' octave, measured: the named note against the heard one, over a few samples
        offs = []
        for k in sorted(self.map)[len(self.map) // 4::max(1, len(self.map) // 4)][:3]:
            heard = 69 + 12 * np.log2(f0(load(sorted(self.map[k])[0])) / 440)
            offs.append(round((heard - k) / 12) * 12)
        off = max(set(offs), key=offs.count)
        if off:
            self.map = {k + off: v for k, v in self.map.items()}
        self.keys = np.array(sorted(self.map))
        self.sustain, self.release, self.ring, self.attack, self.gain = sustain, release, ring, attack, gain
        self.name = os.path.basename(folder)
        self.off = off

    def note(self, m, dur, vel=.6):
        k = int(self.keys[np.argmin(np.abs(self.keys - m))])
        files = sorted(self.map[k])
        x = load(files[min(len(files) - 1, int(vel * len(files)))])
        ratio = 2 ** ((m - k) / 12)
        keep = (dur + self.release) if self.sustain else (dur + self.ring)
        need = int(keep * SR * ratio) + 2
        if self.sustain and need > len(x):
            x = _extend(x, need)
        x = x[:need]
        idx = np.arange(0, len(x) - 1, ratio)
        i0 = idx.astype(int)
        fr = (idx - i0)[:, None]
        y = x[i0] * (1 - fr) + x[i0 + 1] * fr
        t = np.arange(len(y)) / SR
        env = np.minimum(1, t / self.attack)
        if self.sustain:
            env = env * np.where(t > dur, np.clip(1 - (t - dur) / self.release, 0, 1) ** 1.5, 1)
        else:
            tail = min(len(env), int(.6 * SR))
            env[-tail:] *= np.linspace(1, 0, tail) ** 2
        return y * env[:, None] * vel * self.gain


def _extend(x, need):
    """lengthens a sustained note by crossfading loops of its steady middle"""
    a, b = int(len(x) * .35), int(len(x) * .85)
    fade = min(int(.25 * SR), (b - a) // 3)
    out = x[:b].copy()
    while len(out) < need:
        seg = x[a:b].copy()
        w = np.linspace(0, 1, fade)[:, None]
        out[-fade:] = out[-fade:] * (1 - w) + seg[:fade] * w
        out = np.concatenate([out, seg[fade:]])
    return out


class Hit:
    """a one-shot (gong, bells), optionally moved in pitch"""

    def __init__(self, folder, pattern):
        self.files = sorted(p for p in glob.glob(os.path.join(folder, '*.wav')) if re.search(pattern, os.path.basename(p)))
        if not self.files:
            raise SystemExit(f'no samples for {pattern} in {folder}')

    def hit(self, i=0, vel=.6, shift=0.0):
        x = load(self.files[i % len(self.files)])
        if shift:
            ratio = 2 ** (shift / 12)
            idx = np.arange(0, len(x) - 1, ratio)
            i0 = idx.astype(int)
            fr = (idx - i0)[:, None]
            x = x[i0] * (1 - fr) + x[i0 + 1] * fr
        return x * vel


def kit():
    Z = f'{VCSL}/Chordophones/Zithers'
    I = f'{VCSL}/Idiophones'
    S, W = f'{VSCO}/Strings', f'{VSCO}/Woodwinds'
    k = {
        'zheng': Inst(f'{Z}/Dan Tranh/Normal', pat=r'([A-Ga-g]#?)(\d)', only=r'_mf_|_f_', sustain=False, ring=5.0, gain=.9),
        'zhengV': Inst(f'{Z}/Dan Tranh/Vibrato', pat=r'([A-Ga-g]#?)(\d)', only=r'_vib_mf_', sustain=False, ring=5.5, gain=.85),
        'flute': Inst(f'{W}/Flute/susNV', only=r'_v1_', release=1.2, attack=.45, gain=.45),
        'violas': Inst(f'{S}/Viola Section/susvib', only=r'_v1_', release=1.6, attack=1.2, gain=.55),
        'cellos': Inst(f'{S}/Cello Section/susvib', only=r'_v1_', release=1.8, attack=1.4, gain=.6),
        'bass': Inst(f'{S}/Solo Contrabass/SusNV', release=1.8, attack=1.2, gain=.5),
        'harp': Inst(f'{S}/Harp', sustain=False, ring=5.0, gain=.7),
        'glass': Inst(f'{I}/Friction Idiophones/Wine Glasses/Sustains/Slow', release=2.0, attack=1.5, gain=.35),
        'psaltery': Inst(f'{Z}/Psaltery, Bowed and Plucked/LongBow', release=1.4, attack=.9, gain=.45),
        'tbells': Inst(f'{I}/Struck Idiophones/Tubular Bells 1', sustain=False, ring=7.0, gain=.35),
        'gong': Hit(f'{I}/Struck Idiophones/Gong 1', r'^gong_(p|mf|2_mp)\.wav'),
        'hbell': Hit(f'{I}/Struck Idiophones/Hand Bells, Nepalese', r'HB_'),
    }
    for name, v in k.items():
        if isinstance(v, Inst):
            print(f'  {name:9s} octave {v.off:+d}  {len(v.keys)} notes  {v.keys.min()}–{v.keys.max()}')
    return k


# ---------------------------------------------------------------------------------------------- the ring

class Ring:
    def __init__(self):
        self.b = np.zeros((N, 2))

    def add(self, beat, sig, pan=0.0, gain=1.0):
        i = int(beat * 60 / BPM * SR) % N
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sig = sig[:N]
        idx = (i + np.arange(len(sig))) % N
        np.add.at(self.b[:, 0], idx, sig[:, 0] * gain * l * 1.41)
        np.add.at(self.b[:, 1], idx, sig[:, 1] * gain * r * 1.41)


def beats(s):
    """'D4:2 E4:1 r:3' -> [(midi or None, beats)]"""
    out = []
    for tok in s.replace('|', ' ').split():
        n, b = tok.split(':')
        out.append((None if n == 'r' else midi(n), float(b)))
    return out


def play(r, inst, line, at=0.0, vel=.55, pan=0.0, shift=0, legato=1.0, human=.03, rng=None):
    """a melody from beat [at]; returns the beat after it"""
    b = at
    for m, d in line:
        if m is not None:
            dt = rng.uniform(-human, human) if rng is not None else 0
            v = vel * (rng.uniform(.88, 1.0) if rng is not None else 1)
            r.add(b + dt, inst.note(m + shift, d * 60 / BPM * legato, v), pan, 1)
        b += d
    return b


def hold(r, inst, notes, at, length, vel=.5, pan_w=.5):
    """a held chord, each voice to its side"""
    for i, m in enumerate(notes):
        p = (i / max(1, len(notes) - 1) - .5) * 2 * pan_w if len(notes) > 1 else 0
        r.add(at, inst.note(m, length * 60 / BPM, vel), p, 1)


def wind(rng, level):
    """the air, looping (shaped noise in the frequency domain)"""
    out = np.zeros((N, 2))
    fr = np.fft.rfftfreq(N, 1 / SR)
    w = np.exp(-0.5 * ((np.log(np.maximum(fr, 1)) - np.log(520)) / .75) ** 2)
    t = np.arange(N) / SR
    for c in range(2):
        s = np.fft.irfft(np.fft.rfft(rng.standard_normal(N)) * w, N)
        s /= np.abs(s).max()
        out[:, c] = s * (.55 + .45 * np.sin(2 * np.pi * 3 * t / LEN + c * 2.1))
    return out * level


def reverb(b, rng, secs=4.0, wet=.4, damp=3000.0):
    """a hall, as a circular convolution: the echo of the end runs into the start"""
    n = int(secs * SR)
    fr = np.fft.rfftfreq(N, 1 / SR)
    lpf = 1 / np.sqrt(1 + (fr / damp) ** 2)
    out = np.zeros_like(b)
    for ch in range(2):
        ir = np.zeros(N)
        ir[:n] = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / secs))
        ir[:int(.02 * SR)] = 0
        ir /= np.sqrt((ir ** 2).sum())
        out[:, ch] = np.fft.irfft(np.fft.rfft(b[:, ch]) * np.fft.rfft(ir) * lpf, N)
    return b * (1 - wet * .5) + out * wet


# ---------------------------------------------------------------------------------------------- the music
# D 宫 pentatonic: D E F# A B. The theme, in two phrases (the second comes home to D).
PH1 = 'A4:2 B4:1 D5:3 | B4:2 A4:1 F#4:3 | E4:2 F#4:1 A4:2 r:1'
PH2 = 'B4:2 A4:1 F#4:2 E4:1 | D4:6'
PH2_OPEN = 'B4:2 A4:1 F#4:2 E4:1 | E4:3 r:3'  # does not come home
# the minor (羽) colour for the trial: B D E F# A, resting on B
PH1_YU = 'F#4:2 A4:1 B4:3 | A4:2 F#4:1 D4:3 | E4:2 D4:1 B3:2 r:1'


def realm(k, K):
    rng = np.random.default_rng(2600 + k)
    r = Ring()
    z, zv, fl = K['zheng'], K['zhengV'], K['flute']
    D2, D3, A2, A3, D4, A4, F4s, B3, E4 = (midi(n) for n in ('D2', 'D3', 'A2', 'A3', 'D4', 'A4', 'F#4', 'B3', 'E4'))
    wet, damp, secs = .42, 3000.0, 4.5
    if k == 0:  # 凡人: the zither alone; the first phrase only, then silence
        play(r, z, beats(PH1), 2, .5, -.15, rng=rng)
        play(r, z, beats('A4:2 B4:1 D5:3 | B4:3 A4:3'), 34, .42, .15, rng=rng)
        for b in (0, 16, 32, 48):
            r.add(b + 12, z.note(D3, 4, .3), -.3)
        r.b += wind(rng, .05)
    elif k == 1:  # 炼气: the flute breathes: a tone on the out-breath (6 s), silence on the in-breath (4 s)
        tones = [A4, F4s, midi('E4'), D4, midi('B4'), A4]
        b = 4.0
        for i, m in enumerate(tones):
            r.add(b, fl.note(m, 5.2, .45), (-1) ** i * .15)
            b += 10
        for b in range(0, BEATS, 8):
            r.add(b, z.note(D3 if b % 16 == 0 else A2, 4, .32), 0)
        hold(r, K['glass'], [D4 + 12, A4 + 12], 0, 30, .3)
        hold(r, K['glass'], [D4 + 12, F4s + 12], 32, 30, .3)
        wet = .45
    elif k == 2:  # 筑基: the theme further, over low strings that do not move
        hold(r, K['cellos'], [D3, A3], 0, 32, .42, .4)
        hold(r, K['cellos'], [D3, A3], 32, 32, .42, .4)
        hold(r, K['bass'], [D2], 0, 32, .4)
        hold(r, K['bass'], [D2], 32, 32, .4)
        b = play(r, z, beats(PH1), 2, .5, -.1, rng=rng)
        play(r, z, beats(PH2_OPEN), b + 2, .48, .1, rng=rng)
        play(r, z, beats('D5:3 B4:3 A4:6'), 50, .4, 0, rng=rng)
    elif k == 3:  # 金丹: warm; a hand bell now and then
        hold(r, K['violas'], [D4, A4], 0, 32, .4, .5)
        hold(r, K['violas'], [D4, F4s], 32, 32, .4, .5)
        b = play(r, zv, beats(PH1), 2, .48, -.1, rng=rng)
        play(r, z, beats(PH2_OPEN), b + 2, .46, .1, rng=rng)
        for i, b in enumerate((0, 22, 40)):
            r.add(b, K['hbell'].hit(i, .22), (-.5, .4, 0)[i])
        wet = .45
    elif k == 4:  # 元婴: the flute and the zither answer each other
        hold(r, K['cellos'], [D3, A3], 0, 32, .32, .4)
        hold(r, K['cellos'], [B3 - 12, F4s - 12], 32, 32, .3, .4)
        b = play(r, fl, beats('A4:2 B4:1 D5:3 | B4:3 A4:3'), 2, .4, -.2, legato=.95, rng=rng)
        b = play(r, z, beats('F#4:2 E4:1 A4:3 | r:2'), b + 1, .5, .2, rng=rng)
        b = play(r, fl, beats('B4:2 A4:1 F#4:3 | E4:6'), b + 2, .4, -.2, legato=.95, rng=rng)
        play(r, z, beats('A4:2 F#4:1 E4:3 | D4:4'), b + 1, .48, .2, rng=rng)
        wet = .46
    elif k == 5:  # 化神: almost empty: glass, far bells, long echoes
        hold(r, K['glass'], [D4 + 12, A4 + 12], 0, 32, .32, .7)
        hold(r, K['glass'], [B3 + 12, F4s + 12], 32, 32, .32, .7)
        for i, (b, m) in enumerate([(3, 'A5'), (14, 'F#5'), (27, 'D5'), (41, 'B5'), (53, 'E5')]):
            r.add(b, K['tbells'].note(midi(m), 6, .3), (-.6, .5, -.2, .6, 0)[i])
        play(r, z, beats('D5:3 B4:3 A4:6'), 18, .32, .3, rng=rng)
        play(r, K['psaltery'], beats('A4:8 F#4:8'), 40, .35, -.2, rng=rng)
        wet, damp, secs = .55, 3600.0, 6.0
    elif k == 6:  # 渡劫: stillness inside the trial: a soft low gong, a deep drone, the zither in minor
        hold(r, K['cellos'], [B3 - 12, F4s - 12], 0, 32, .4, .4)
        hold(r, K['cellos'], [B3 - 12, F4s - 12], 32, 32, .4, .4)
        hold(r, K['bass'], [B3 - 24], 0, 64, .38)
        r.add(0, K['gong'].hit(0, .32, -2), 0)
        r.add(32, K['gong'].hit(1, .26, -2), 0)
        b = play(r, z, beats(PH1_YU), 4, .48, -.1, rng=rng)
        play(r, zv, beats('D4:3 E4:3 | F#4:2 E4:1 D4:3 | B3:6'), b + 6, .42, .1, rng=rng)
        wet, damp = .45, 2400.0
    else:  # 飞升: the theme whole, at rest
        hold(r, K['violas'], [D4, A4], 0, 32, .32, .6)
        hold(r, K['violas'], [D4, F4s], 32, 32, .32, .6)
        hold(r, K['cellos'], [D3, A3], 0, 64, .3, .4)
        b = play(r, z, beats(PH1), 2, .48, -.1, rng=rng)
        b = play(r, z, beats(PH2), b, .48, -.1, rng=rng)
        b = play(r, fl, beats(PH1), b + 2, .36, .15, legato=.95, rng=rng)
        play(r, fl, beats(PH2), b, .36, .15, legato=.95, rng=rng)
        for i, m in enumerate(('D4', 'F#4', 'A4', 'D5')):
            r.add(32 + i * .5, K['harp'].note(midi(m), 4, .3), .3)
        r.add(28, K['tbells'].note(midi('D5'), 6, .22), -.5)
        r.add(60, K['hbell'].hit(1, .16), .4)
        wet, damp, secs = .48, 3600.0, 5.0
    b = reverb(r.b, rng, secs, wet, damp)
    b = lp(b, 9000)
    # roll the deep bass off (phone speakers only rattle there), then the same loudness for every realm, measured
    # where a phone is heard (above 200 Hz), and a soft ceiling
    fr = np.fft.rfftfreq(N, 1 / SR)
    sp = np.fft.rfft(b, axis=0) * (1 / np.sqrt(1 + (80 / np.maximum(fr, 1)) ** 4))[:, None]
    b = np.fft.irfft(sp, N, axis=0)
    heard = np.fft.irfft(sp * (fr > 200)[:, None], N, axis=0)
    b *= 0.075 / np.sqrt((heard ** 2).mean())
    return np.tanh(b * 1.8) / 1.8


def main():
    want = [int(a) for a in sys.argv[1:]] or list(range(8))
    print('instruments:')
    K = kit()
    os.makedirs(OUT, exist_ok=True)
    for k in want:
        b = realm(k, K)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
            tmp = f.name
        with wave.open(tmp, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(b, -1, 1) * 32767).astype('<i2').tobytes())
        out = os.path.join(OUT, f'bgm_{k}.ogg')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '2', '-map_metadata',
                        '-1', out], check=True)
        os.unlink(tmp)
        win = b[:len(b) // SR * SR, 0].reshape(-1, SR * 4)
        rms = np.sqrt((win ** 2).mean(1))
        print(f'bgm_{k}: peak {np.abs(b).max():.2f}  4-s loudness {rms.min():.3f}…{rms.max():.3f}  '
              f'{os.path.getsize(out) // 1024} KB')


main()
