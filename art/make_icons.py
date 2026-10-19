"""Make every app icon from Josh's artwork (v1.17): art/icon-source-square.png (the rounded square) and
art/icon-source-round.png (the same design in a circle), both on a white background.

    python3 art/make_icons.py

The square artwork is cut out of its white background and its gradient is extended outwards (normalized
convolution: the colours near the edge flow on smoothly), giving a full-bleed square with no corners. From it:
  app/src/main/res/mipmap-*/ic_launcher_background.png   adaptive icon (Android 8+): the whole design is the
                                                         background layer, sized so the star, the sword and the
                                                         golden arc stay inside the visible circle of every launcher
                                                         (the foreground layer is transparent, mipmap-anydpi-v26)
  app/src/main/res/mipmap-*/ic_launcher_monochrome.png   Android 13 themed icon: the light shapes of the design
  app/src/main/res/mipmap-*/ic_launcher.png              legacy icon: the rounded square
  app/src/main/res/mipmap-*/ic_launcher_round.png        legacy round icon: the circle
  app/src/main/res/drawable-nodpi/ic_splash.webp          splash screen icon (Android 12 shows it inside a circle)
  art/play-icon-512.png                                  Google Play icon (512 x 512, full square, Play rounds it)
  art/icon-badge.png                                     the circle, cut out (store feature graphics)
  docs/privacy/icon.png                                  small icon for the privacy policy page
  art/icon-preview.png                                   how the icons look in different launcher masks
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'app', 'src', 'main', 'res')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
ART = 0.70  # the design's width as a share of the 108dp adaptive layer (its visible window is 72dp = 66.7 %)


def cut(src):
    """The white area around the design becomes transparent; returns RGBA cropped to the design."""
    rgb = src.convert('RGB')
    a = np.asarray(rgb).astype(np.int16)
    white = (a.min(axis=2) > 232).astype(np.uint8) * 255
    mask = Image.fromarray(white, 'L').copy()  # own buffer: floodfill cannot write into numpy memory
    w, h = mask.size
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if mask.getpixel(seed) == 255:
            ImageDraw.floodfill(mask, seed, 128)
    alpha = mask.point(lambda v: 0 if v == 128 else 255)
    # soften the cut edge by one pixel (the artwork's own edge is anti-aliased into white)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = rgb.convert('RGBA')
    out.putalpha(alpha)
    out = out.crop(alpha.point(lambda v: 255 if v > 8 else 0).getbbox())
    side = max(out.size)  # centred on a square
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.alpha_composite(out, ((side - out.width) // 2, (side - out.height) // 2))
    return sq


def full_bleed(art, size):
    """The design centred on a size x size square, the space around it filled by its own colours flowing outwards."""
    S = art.width
    off = (size - S) // 2
    rgb = np.zeros((size, size, 3), np.float64)
    m = np.zeros((size, size), np.float64)
    a = np.asarray(art).astype(np.float64)
    from scipy.ndimage import minimum_filter
    inner = minimum_filter(a[:, :, 3], size=71) / 255.0  # 35px in: the artwork's glossy rim is not a source colour
    rgb[off:off + S, off:off + S] = a[:, :, :3] * inner[:, :, None]
    m[off:off + S, off:off + S] = inner
    fill = np.zeros_like(rgb)
    got = np.zeros_like(m)
    # normalized convolution: every pixel outside takes the 30px-scale average of the design's colours near it
    # (pixels too far for that take a 120px one), then one soft pass
    for r in (30, 120):
        num = np.stack([gauss(rgb[:, :, c], r) for c in range(3)], axis=2)
        den = gauss(m, r)
        ok = (den > 1e-4) & (got == 0)
        fill[ok] = num[ok] / den[ok][:, None]
        got[ok] = 1
    # a last soft pass so the bands between radii never show
    fill = np.stack([gauss(fill[:, :, c], 16) for c in range(3)], axis=2)
    # the artwork's own rim (a soft dark edge and the white fringe) is replaced by the extension: its outline is pulled
    # in by 35px and feathered, so no ring shows where the old edge was
    rim = Image.fromarray((inner * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(12))
    alpha = np.zeros((size, size))
    alpha[off:off + S, off:off + S] = np.asarray(rim) / 255.0
    region = np.zeros((size, size, 3))
    region[off:off + S, off:off + S] = a[:, :, :3]
    comp = fill * (1 - alpha[:, :, None]) + region * alpha[:, :, None]
    return Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8), 'RGB')


def gauss(x, r):
    """Gaussian blur of a float array (scipy; this script runs by hand, CI does not need it)"""
    from scipy.ndimage import gaussian_filter
    return gaussian_filter(x, r, mode='nearest')


def fit(img, size, share):
    """img scaled so its width is share * size, centred on a transparent size x size canvas"""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    w = round(size * share)
    b = img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)
    canvas.alpha_composite(b.convert('RGBA'), ((size - b.width) // 2, (size - b.height) // 2))
    return canvas


def main():
    square = cut(Image.open(os.path.join(ROOT, 'art', 'icon-source-square.png')))
    round_ = cut(Image.open(os.path.join(ROOT, 'art', 'icon-source-round.png')))
    S = square.width
    big = full_bleed(square, round(S / ART))  # the design at ART of the whole square
    # Android 13 themed icons: the light parts of the design (the cream characters and sword, the golden star and arc)
    # as one shape; the launcher paints it in the wallpaper's colours
    px = np.asarray(big).astype(np.float64) / 255.0
    lum = 0.2126 * px[:, :, 0] + 0.7152 * px[:, :, 1] + 0.0722 * px[:, :, 2]
    gold = (px[:, :, 0] > 0.8) & (px[:, :, 1] > 0.55) & (px[:, :, 2] < 0.45)
    a_m = np.clip((lum - 0.62) / 0.16, 0, 1)
    a_m = np.maximum(a_m, gold.astype(np.float64))
    mono = Image.new('RGBA', big.size, (255, 255, 255, 0))
    mono.putalpha(Image.fromarray((a_m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)))
    for name, k in DENSITIES.items():
        d = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(d, exist_ok=True)
        big.resize((round(108 * k),) * 2, Image.LANCZOS).save(os.path.join(d, 'ic_launcher_background.png'), optimize=True)
        mono.resize((round(108 * k),) * 2, Image.LANCZOS).save(os.path.join(d, 'ic_launcher_monochrome.png'), optimize=True)
        fit(square, round(48 * k), 0.92).save(os.path.join(d, 'ic_launcher.png'), optimize=True)
        fit(round_, round(48 * k), 0.94).save(os.path.join(d, 'ic_launcher_round.png'), optimize=True)
        old = os.path.join(d, 'ic_launcher_foreground.png')
        if os.path.exists(old):
            os.remove(old)
    nd = os.path.join(RES, 'drawable-nodpi')
    os.makedirs(nd, exist_ok=True)
    # splash: 288dp box, Android 12 masks it to the middle circle of 192dp (2/3); the round design fills that circle
    fit(round_, 864, 0.66).save(os.path.join(nd, 'ic_splash.webp'), quality=92, method=6)
    # Play: a full square (Play rounds the corners itself); the design fills it edge to edge
    play = full_bleed(square, round(S / 0.94)).resize((512, 512), Image.LANCZOS)
    play.save(os.path.join(ROOT, 'art', 'play-icon-512.png'), optimize=True)
    round_.save(os.path.join(ROOT, 'art', 'icon-badge.png'), optimize=True)
    round_.resize((128, 128), Image.LANCZOS).save(os.path.join(ROOT, 'docs', 'privacy', 'icon.png'), optimize=True)

    # preview: legacy square and round, the adaptive icon in a circle, a squircle and a rounded square, Play, splash
    lay = big.resize((432, 432), Image.LANCZOS).crop((72, 72, 360, 360)).resize((192, 192), Image.LANCZOS)
    masks = []
    for kind in ('circle', 'squircle', 'rounded'):
        mk = Image.new('L', (192, 192), 0)
        dr = ImageDraw.Draw(mk)
        if kind == 'circle':
            dr.ellipse((0, 0, 191, 191), fill=255)
        else:
            dr.rounded_rectangle((0, 0, 191, 191), radius=64 if kind == 'squircle' else 28, fill=255)
        masks.append(mk)
    prev = Image.new('RGBA', (7 * 212 + 20, 236), (38, 42, 50, 255))
    prev.alpha_composite(fit(square, 192, 0.92), (20, 22))
    prev.alpha_composite(fit(round_, 192, 0.94), (232, 22))
    for i, mk in enumerate(masks):
        c = Image.new('RGBA', (192, 192), (0, 0, 0, 0))
        c.paste(lay, (0, 0), mk)
        prev.alpha_composite(c, (444 + i * 212, 22))
    pm = Image.new('L', (192, 192), 0)
    ImageDraw.Draw(pm).rounded_rectangle((0, 0, 191, 191), radius=38, fill=255)
    c = Image.new('RGBA', (192, 192), (0, 0, 0, 0))
    c.paste(play.resize((192, 192), Image.LANCZOS), (0, 0), pm)
    prev.alpha_composite(c, (1080, 22))
    sp = Image.new('RGBA', (192, 192), (246, 247, 249, 255))
    sp.alpha_composite(fit(round_, 192, 0.66))
    prev.alpha_composite(sp, (1292, 22))
    prev.convert('RGB').save(os.path.join(ROOT, 'art', 'icon-preview.png'))
    print('icons written; square', square.size, 'round', round_.size)


main()
