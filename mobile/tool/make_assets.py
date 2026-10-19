"""Data and text for the Flutter app, from the same sources as the WebView app.

    python3 mobile/tool/make_assets.py          (needs node + acorn for the text: see make_i18n.js)

Writes (not committed; CI and local builds run this first):
  mobile/assets/data/core.json        HSK 1–6 words: {cols, rows} (everything but the meanings)
  mobile/assets/data/<lang>.json      their meanings + sentence translations in each study language, same order
  mobile/assets/data/s0.bin           sealed: HSK 7–9 words, and what the app needs past the gate (realm names,
                                      the gate's text in every language, the glossary entry)
  mobile/assets/data/s-<lang>.bin     sealed: HSK 7–9 meanings in each language
  mobile/assets/i18n/<lang>.json      interface text (functions as expression trees, lib/i18n/l10.dart)

The seal is the one of web/build.py (zlib, then a xoshiro128** keystream seeded by SHA-256 of a phrase, the HSK 6
words and the file name), opened by lib/data/seal.dart. Not real secrecy, only nothing to find by unzipping the app.
"""
import hashlib
import json
import os
import subprocess
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOBILE = os.path.join(ROOT, 'mobile')
GEN = os.path.join(MOBILE, 'build', 'gen')
OUT_DATA = os.path.join(MOBILE, 'assets', 'data')
OUT_I18N = os.path.join(MOBILE, 'assets', 'i18n')
CORE = ['l', 'n', 'u', 'h', 'p', 's', 'z', 'zp', 'f', 'g', 'pm']
LANG_COLS = {'id': ('m', 't'), 'en': ('em', 'et'), 'th': ('hm', 'ht'), 'vi': ('vm', 'vt')}
SECRET = ['真仙', '玄仙', '大罗', '仙门', 'HSK 7', 'HSK 8', 'HSK 9', '7–9', '7-9', 'xiānmén', 'zhēnxiān', 'xuánxiān', 'dàluó']

SEAL_HEAD = ('封 · 天外有天\n'
             'This scroll is sealed. Cultivate, and it opens by itself.\n'
             'Gulungan ini tersegel. Berkultivasilah, dan ia terbuka sendiri.\n').encode() + b'\0'


def seal(obj, name, material):
    raw = zlib.compress(json.dumps(obj, ensure_ascii=False, separators=(',', ':')).encode(), 9)
    seed = hashlib.sha256((material + '|' + name).encode()).digest()
    a, b, c, d = (int.from_bytes(seed[i:i + 4], 'little') for i in (0, 4, 8, 12))
    M = 0xFFFFFFFF
    rotl = lambda x, k: ((x << k) | (x >> (32 - k))) & M
    out = bytearray(raw)
    for i in range(0, len(out), 4):
        r = (rotl((b * 5) & M, 7) * 9) & M
        t = (b << 9) & M
        c ^= a
        d ^= b
        b ^= c
        a ^= d
        c ^= t
        d = rotl(d, 11)
        for k in range(min(4, len(out) - i)):
            out[i + k] ^= (r >> (8 * k)) & 255
    return SEAL_HEAD + bytes(out)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = 'wb' if isinstance(data, bytes) else 'w'
    with open(path, mode, **({} if mode == 'wb' else {'encoding': 'utf8'})) as f:
        f.write(data)


def main():
    # interface text: node converts the JS sources (public text + the sealed part)
    subprocess.run(['node', os.path.join(MOBILE, 'tool', 'make_i18n.js'), GEN], check=True)
    langs = list(LANG_COLS)
    for lang in langs:
        with open(os.path.join(GEN, f'i18n-{lang}.json'), encoding='utf8') as f:
            text = f.read()
        found = [w for w in SECRET if w in text]
        assert not found, f'i18n {lang}: the public text names {found}'
        write(os.path.join(OUT_I18N, f'{lang}.json'), text)
    with open(os.path.join(GEN, 'i18n-sealed.json'), encoding='utf8') as f:
        sealed_text = json.load(f)

    with open(os.path.join(ROOT, 'web', 'data', 'vocab.json'), encoding='utf8') as f:
        words = json.load(f)
    for d in words:
        d['pm'] = 1 if d['l'] <= 6 and len(d['m'].split(';')[0]) <= 28 else 0
    pack = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':'))
    low = [d for d in words if d['l'] <= 6]
    band = [d for d in words if d['l'] >= 7]
    material = '天外有天|' + ''.join(d['h'] for d in low if d['l'] == 6)
    write(os.path.join(OUT_DATA, 'core.json'), pack({'cols': CORE, 'rows': [[d.get(k) for k in CORE] for d in low]}))
    for lang, (m, t) in LANG_COLS.items():
        write(os.path.join(OUT_DATA, f'{lang}.json'), pack({'lang': lang, 'rows': [[d[m], d[t]] for d in low]}))
    # what lies past the gate: the words, and the few things the app shows about it
    extra = {
        'rn': ['真仙', '玄仙', '大罗'],
        'rpy': ['zhēnxiān', 'xuánxiān', 'dàluó'],
        'rs': ['真', '玄', '罗'],
        'gate': {'hz': '仙门', 'py': 'xiānmén', 'door': ['仙', '门']},
        'gl': [['仙门', 'xiānmén', 'xm', 1]],
        'i18n': sealed_text,
    }
    core_b = {'cols': CORE, 'rows': [[d.get(k) for k in CORE] for d in band]}
    write(os.path.join(OUT_DATA, 's0.bin'), seal({'core': core_b, 'x': extra}, 's0.bin', material))
    for lang, (m, t) in LANG_COLS.items():
        name = f's-{lang}.bin'
        write(os.path.join(OUT_DATA, name), seal({'lang': lang, 'rows': [[d[m], d[t]] for d in band]}, name, material))
    for f in sorted(os.listdir(OUT_DATA)):
        if f.endswith('.json'):
            with open(os.path.join(OUT_DATA, f), encoding='utf8') as fh:
                found = [w for w in SECRET if w in fh.read()]
            assert not found, f'{f} names {found}'
    sizes = {f: os.path.getsize(os.path.join(OUT_DATA, f)) for f in sorted(os.listdir(OUT_DATA))}
    print('assets:', len(low), 'words +', len(band), 'sealed;', ', '.join(f'{k} {v / 1024:.0f} KB' for k, v in sizes.items()))


if __name__ == '__main__':
    sys.exit(main())
