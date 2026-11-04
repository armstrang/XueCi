#!/usr/bin/env python3
"""Make every app icon from art/icon.html (Josh, Nov 2026: very simple, only 词; red seal by default, night and gold
when the phone is dark). Renders the drawing with Playwright (Chromium), then:

    python3 art/make_icons.py

  mobile/android/app/src/main/res/mipmap-*/ic_launcher_background.png        adaptive icon (Android 8+): the whole
                                                    design is the background layer (108 dp, 72 dp of it show); the
                                                    foreground is transparent (mipmap-anydpi-v26); 词 stays inside the
                                                    circle every launcher keeps
  mobile/android/app/src/main/res/mipmap-night-*/ic_launcher_background.png  the same in night and gold (dark theme;
                                                    whether it switches is up to the launcher)
  mobile/android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png        Android 13 themed icon: 词 alone
  mobile/android/app/src/main/res/mipmap-[night-]*/ic_launcher[_round].png   legacy icons (Android 7): rounded square
                                                    and circle
  art/play-icon-512.png                             Google Play icon (512 x 512, full square, Play rounds it)
  art/icon-badge.png                                the circle, cut out (store feature graphics)
  docs/privacy/icon.png                             small icon for the privacy policy page
  art/icon-preview.png                              both colours in a circle, a squircle and a rounded square, and the
                                                    themed icon
(art/icon-source-*.png are the earlier artwork, no longer used.)
"""
import asyncio
import io
import os

from PIL import Image, ImageDraw
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'mobile', 'android', 'app', 'src', 'main', 'res')
SRC = 'file://' + os.path.join(ROOT, 'art', 'icon.html')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


async def render(b, v, m, px):
    pg = await b.new_page(viewport={'width': px, 'height': px})
    await pg.goto(f'{SRC}?v={v}&m={m}&px={px}')
    await pg.wait_for_timeout(150)
    png = await pg.screenshot(omit_background=True)
    await pg.close()
    return Image.open(io.BytesIO(png)).convert('RGBA')


def fit(img, size, share):
    """[img] at [share] of a transparent [size] square (the legacy icons keep a small margin)"""
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    w = round(size * share)
    c.alpha_composite(img.resize((w, w), Image.LANCZOS), ((size - w) // 2, (size - w) // 2))
    return c


def save(img, *path):
    p = os.path.join(*path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True)


async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--allow-file-access-from-files'])
        art = {}
        for v in ('red', 'gold'):
            art[v] = {m: await render(b, v, m, 1024) for m in ('layer', 'rounded', 'round', 'square')}
        mono = await render(b, 'red', 'mono', 1024)
        await b.close()
    for name, k in DENSITIES.items():
        for v, night in (('red', ''), ('gold', '-night')):
            d = os.path.join(RES, f'mipmap{night}-{name}')
            save(art[v]['layer'].resize((round(108 * k),) * 2, Image.LANCZOS), d, 'ic_launcher_background.png')
            save(fit(art[v]['rounded'], round(48 * k), 0.92), d, 'ic_launcher.png')
            save(fit(art[v]['round'], round(48 * k), 0.94), d, 'ic_launcher_round.png')
        save(mono.resize((round(108 * k),) * 2, Image.LANCZOS), RES, f'mipmap-{name}', 'ic_launcher_monochrome.png')
    red = art['red']
    save(red['square'].resize((512, 512), Image.LANCZOS), ROOT, 'art', 'play-icon-512.png')
    save(red['round'], ROOT, 'art', 'icon-badge.png')
    save(red['round'].resize((128, 128), Image.LANCZOS), ROOT, 'docs', 'privacy', 'icon.png')

    # preview: each colour in a circle, a squircle and a rounded square (cut from the adaptive layer), the themed icon
    prev = Image.new('RGBA', (4 * 212 + 20, 2 * 212 + 20), (38, 42, 50, 255))
    for row, v in enumerate(('red', 'gold')):
        lay = art[v]['layer'].resize((288, 288), Image.LANCZOS).crop((48, 48, 240, 240))
        for i, kind in enumerate(('circle', 'squircle', 'rounded')):
            mk = Image.new('L', (192, 192), 0)
            dr = ImageDraw.Draw(mk)
            if kind == 'circle':
                dr.ellipse((0, 0, 191, 191), fill=255)
            else:
                dr.rounded_rectangle((0, 0, 191, 191), radius=64 if kind == 'squircle' else 28, fill=255)
            c = Image.new('RGBA', (192, 192), (0, 0, 0, 0))
            c.paste(lay, (0, 0), mk)
            prev.alpha_composite(c, (20 + i * 212, 20 + row * 212))
    th = Image.new('RGBA', (192, 192), (0, 0, 0, 0))
    ImageDraw.Draw(th).ellipse((0, 0, 191, 191), fill=(214, 227, 255, 255))
    ml = mono.resize((288, 288), Image.LANCZOS).crop((48, 48, 240, 240))
    ink = Image.new('RGBA', (192, 192), (30, 50, 110, 255))
    th.paste(ink, (0, 0), ml)
    prev.alpha_composite(th, (20 + 3 * 212, 20))
    prev.convert('RGB').save(os.path.join(ROOT, 'art', 'icon-preview.png'))
    print('icons written')


asyncio.run(main())
