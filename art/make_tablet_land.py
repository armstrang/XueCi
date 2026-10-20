#!/usr/bin/env python3
"""Landscape tablet screenshots for Play (1920x1200 and 2560x1600): two app screens side by side, as in split view,
on the app's light aurora. Uses store/shots/tab10/*.png (STORE=1 flutter test ... test/store_tablet_test.dart).
    python3 art/make_tablet_land.py   ->  store/shots/land7/, store/shots/land10/
"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter
R = pathlib.Path(__file__).resolve().parent.parent
PAIRS = [('1-home', '2-soul'), ('3-card', '4-quiz'), ('5-mock', '2-soul')]

def bg(w, h):
    im = Image.new('RGB', (w, h), (236, 232, 240))
    d = ImageDraw.Draw(im)
    for (cx, cy, r, c) in [(0, 0, .7, (176, 214, 214)), (1, 1, .75, (246, 196, 176)), (.35, 1, .55, (206, 204, 238))]:
        d.ellipse([(cx - r) * w, (cy - r) * h * 1.6, (cx + r) * w, (cy + r) * h * 1.6], fill=c)
    return im.filter(ImageFilter.GaussianBlur(w // 8))

def shot(S, name, h):
    im = Image.open(S / f'{name}.png').convert('RGB')
    w = round(im.width * h / im.height)
    im = im.resize((w, h), Image.LANCZOS)
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=h // 28, fill=255)
    return im, m

for sfx in ['', '-en']:
  S = R / f'store/shots/tab10{sfx}'
  for out0, (W, H) in {'land7': (1920, 1200), 'land10': (2560, 1600)}.items():
    out = out0 + sfx
    (R / 'store/shots' / out).mkdir(parents=True, exist_ok=True)
    for i, (a, b) in enumerate(PAIRS, 1):
        c = bg(W, H)
        h = round(H * .9)
        ims = [shot(S, a, h), shot(S, b, h)]
        gap = round(W * .03)
        tw = sum(x[0].width for x in ims) + gap
        x = (W - tw) // 2
        y = (H - h) // 2
        for im, m in ims:
            sh = Image.new('L', (W, H), 0)
            ImageDraw.Draw(sh).rounded_rectangle([x, y + h // 60, x + im.width, y + h + h // 60], radius=h // 28, fill=70)
            c.paste(Image.new('RGB', (W, H), (40, 30, 70)), (0, 0), sh.filter(ImageFilter.GaussianBlur(h // 40)))
            c.paste(im, (x, y), m)
            x += im.width + gap
        c.save(R / 'store/shots' / out / f'{i}-{a}-{b}.png', optimize=True)
        print(out, i)
