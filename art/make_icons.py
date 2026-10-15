"""Make every app icon from art/icon-source.jpg (the round badge on a white background).

    python3 art/make_icons.py

Writes:
  art/icon-badge.png                                     the badge cut out of its white background
  app/src/main/res/mipmap-*/ic_launcher(_round).png      legacy icons (badge fills ~96%)
  app/src/main/res/mipmap-*/ic_launcher_foreground.png   adaptive icon foreground (badge ~64%, inside the safe zone);
                                                         the background is the colour ic_bg in res/values/colors.xml
  art/play-icon-512.png                                  Google Play store icon (512 x 512, 32-bit PNG)
  docs/privacy/icon.png                                  small icon for the privacy policy page
  art/icon-preview.png                                   how the icons look (check it after a change)
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'app', 'src', 'main', 'res')
BG = (253, 253, 253, 255)          # same as ic_bg (#FDFDFD)
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def cut_badge(src):
    """Make the white area around the badge transparent (white inside the badge, e.g. the clouds, stays)."""
    rgb = src.convert('RGB')
    w, h = rgb.size
    px = rgb.load()
    mask = Image.new('L', (w, h), 0)
    m = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 236 and g > 236 and b > 236:
                m[x, y] = 255
    # everything near-white that is connected to the border is background
    for seed in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if mask.getpixel(seed) == 255:
            ImageDraw.floodfill(mask, seed, 128)
    alpha = mask.point(lambda v: 0 if v == 128 else 255)
    badge = rgb.convert('RGBA')
    badge.putalpha(alpha)
    return badge.crop(alpha.getbbox())


def place(badge, size, fill, bg=None):
    canvas = Image.new('RGBA', (size, size), bg or (0, 0, 0, 0))
    scale = fill * size / max(badge.size)
    b = badge.resize((round(badge.width * scale), round(badge.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(b, ((size - b.width) // 2, (size - b.height) // 2))
    return canvas


def main():
    src = Image.open(os.path.join(ROOT, 'art', 'icon-source.jpg'))
    badge = cut_badge(src)
    badge.save(os.path.join(ROOT, 'art', 'icon-badge.png'), optimize=True)
    for name, k in DENSITIES.items():
        d = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(d, exist_ok=True)
        legacy = place(badge, round(48 * k), 0.96)
        legacy.save(os.path.join(d, 'ic_launcher.png'), optimize=True)
        legacy.save(os.path.join(d, 'ic_launcher_round.png'), optimize=True)
        place(badge, round(108 * k), 0.64).save(os.path.join(d, 'ic_launcher_foreground.png'), optimize=True)
    play = place(badge, 512, 0.84, BG)
    play.save(os.path.join(ROOT, 'art', 'play-icon-512.png'), optimize=True)
    play.resize((128, 128), Image.LANCZOS).save(os.path.join(ROOT, 'docs', 'privacy', 'icon.png'), optimize=True)

    # preview: legacy icon, adaptive icon in a circle and a rounded square, Play icon
    fg = place(badge, 432, 0.64)
    adaptive = Image.new('RGBA', (432, 432), BG)
    adaptive.alpha_composite(fg)
    adaptive = adaptive.crop((72, 72, 360, 360)).resize((192, 192), Image.LANCZOS)   # the visible 72dp of 108dp
    prev = Image.new('RGBA', (4 * 220 + 20, 240), (58, 62, 70, 255))
    circle = Image.new('L', (192, 192), 0)
    ImageDraw.Draw(circle).ellipse((0, 0, 191, 191), fill=255)
    squircle = Image.new('L', (192, 192), 0)
    ImageDraw.Draw(squircle).rounded_rectangle((0, 0, 191, 191), radius=48, fill=255)
    prev.alpha_composite(place(badge, 192, 0.96), (20, 24))
    c = Image.new('RGBA', (192, 192), (0, 0, 0, 0)); c.paste(adaptive, (0, 0), circle); prev.alpha_composite(c, (240, 24))
    s = Image.new('RGBA', (192, 192), (0, 0, 0, 0)); s.paste(adaptive, (0, 0), squircle); prev.alpha_composite(s, (460, 24))
    prev.alpha_composite(play.resize((192, 192), Image.LANCZOS), (680, 24))
    prev.convert('RGB').save(os.path.join(ROOT, 'art', 'icon-preview.png'))
    print('icons written; badge', badge.size)


main()
