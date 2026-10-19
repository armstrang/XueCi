"""The fonts inside the Flutter app (static TrueType instances, cut to the characters the app shows).

    python3 mobile/tool/make_fonts.py [SOURCE_DIR]

SOURCE_DIR (default web/fonts/src, not committed) holds the original variable fonts, as the WebView line did
(Plus Jakarta Sans, Noto Sans SC, Noto Serif SC, Noto Sans Thai; all SIL OFL 1.1). Writes mobile/assets/fonts/*.ttf
and the licences (committed). Re-run after adding words or interface text with new Chinese characters:
test/fonts_test.dart fails when a character the app can show is missing.
"""
import glob
import json
import os
import shutil
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'web', 'fonts', 'src')
OUT = os.path.join(ROOT, 'mobile', 'assets', 'fonts')


def is_han(c):
    o = ord(c)
    return 0x3400 <= o <= 0x9FFF or 0xF900 <= o <= 0xFAFF or 0x20000 <= o <= 0x2FFFF


def app_text():
    """Every character the app can show: the word data, the interface text and the Dart sources."""
    parts = []
    for pat in ('web/src/**/*', 'mobile/lib/**/*.dart'):
        for p in glob.glob(os.path.join(ROOT, pat), recursive=True):
            if os.path.isfile(p):
                with open(p, encoding='utf8') as f:
                    parts.append(f.read())
    with open(os.path.join(ROOT, 'web', 'data', 'vocab.json'), encoding='utf8') as f:
        parts.append(json.dumps(json.load(f), ensure_ascii=False))
    return ''.join(parts)


def rng(a, b):
    return list(range(a, b + 1))


LATIN = (rng(0x20, 0x7E) + rng(0xA0, 0x24F) + rng(0x1E00, 0x1EFF) + rng(0x2000, 0x206F) + [0x20AB, 0x20AC]
         + rng(0x2190, 0x21FF) + [0x2248, 0x2212, 0x2022, 0x2026, 0x2713, 0x2717, 0x25CF, 0x25CB])
THAI = rng(0x20, 0x40) + rng(0x0E00, 0x0E7F) + rng(0x2000, 0x206F)


def build(src, out, unicodes, axes):
    font = TTFont(src)
    opts = subset.Options()
    opts.hinting = False
    opts.desubroutinize = True
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=unicodes)
    sub.subset(font)
    if 'fvar' in font:
        font = instancer.instantiateVariableFont(font, axes, updateFontNames=True)
    path = os.path.join(OUT, out)
    font.save(path)
    return os.path.getsize(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, '*.ttf')):
        os.remove(f)
    text = app_text()
    han = sorted({c for c in text if is_han(c)})
    # pinyin letters too: Plus Jakarta Sans has no ǎ ǐ ǒ ǔ ǚ, so they fall back to Noto Sans SC
    cjk = [ord(c) for c in han] + rng(0x20, 0x7E) + rng(0xA0, 0x24F) + rng(0x3000, 0x303F) + rng(0xFF00, 0xFFEF) + rng(0x2010, 0x2027)
    cjk += rng(0x2190, 0x23FF) + rng(0x25A0, 0x27BF)  # arrows, maths, shapes, ✓ (missing from Plus Jakarta Sans)
    S = lambda name: os.path.join(SRC, name)
    jobs = [('pjs-%d.ttf' % w, 'PlusJakartaSans[wght].ttf', LATIN, {'wght': w}) for w in (400, 500, 600, 700, 800)]
    jobs += [('pjs-italic-500.ttf', 'PlusJakartaSans-Italic[wght].ttf', LATIN, {'wght': 500})]
    jobs += [('thai-%d.ttf' % w, 'NotoSansThai[wdth,wght].ttf', THAI, {'wdth': 100, 'wght': w}) for w in (400, 600, 700)]
    jobs += [('sans-sc-%d.ttf' % w, 'NotoSansSC[wght].ttf', cjk, {'wght': w}) for w in (400, 700)]
    jobs += [('serif-sc-%d.ttf' % w, 'NotoSerifSC[wght].ttf', cjk, {'wght': w}) for w in (700, 900)]
    total = 0
    for out, src, uni, axes in jobs:
        size = build(S(src), out, uni, axes)
        total += size
        print(f'{out:22s} {size / 1024:8.0f} KB')
    for lic in glob.glob(os.path.join(SRC, 'OFL-*.txt')):
        shutil.copy(lic, os.path.join(OUT, os.path.basename(lic)))
    with open(os.path.join(OUT, 'charset.txt'), 'w', encoding='utf8') as f:
        f.write(''.join(han) + '\n')
    print(f'total {total / 1024 / 1024:.2f} MB, {len(han)} Chinese characters')


main()
