#!/usr/bin/env python3
"""Draws an Android status bar (One UI style: the time on the left; signal, Wi-Fi and battery on the right) into
the device screenshots made by
    STORE=1 flutter test --no-pub --update-goldens test/store_device_test.dart   (in mobile/)
    python3 art/make_device_bars.py
The app leaves that room free (the status bar padding), so the bar sits on the app's own aurora, as on the phone.
Dark marks: the pictures use the light theme. Writes the pictures in place (drawing twice gives the same picture).
"""
import pathlib
from PIL import Image, ImageDraw, ImageFont

R = pathlib.Path(__file__).resolve().parent.parent
DEV = {  # name: (dpr, status bar dp)
    's26': (2.625, 34),
    'galaxytab': (2.0, 28),
    'galaxytab-land': (2.0, 28),
    'oppopadmini': (2.1, 28),
    'oppopadmini-land': (2.1, 28),
}
INK = (17, 19, 25)
FONT = R / 'mobile/assets/fonts/pjs-600.ttf'


def bar(im, dpr, h):
    d = ImageDraw.Draw(im)
    H = h * dpr
    cy = H * .55
    pad = 22 * dpr
    f = ImageFont.truetype(str(FONT), int(13.5 * dpr))
    # the time
    d.text((pad, cy), '09.41', font=f, fill=INK, anchor='lm')
    x = im.width - pad
    # battery: body, cap, fill and the share
    bw, bh = 23 * dpr, 11.5 * dpr
    x0 = x - bw
    d.rounded_rectangle([x0, cy - bh / 2, x - 2 * dpr, cy + bh / 2], radius=3 * dpr, outline=INK, width=max(1, int(1.2 * dpr)))
    d.rounded_rectangle([x - 1.6 * dpr, cy - 2.5 * dpr, x, cy + 2.5 * dpr], radius=1 * dpr, fill=INK)
    inner = [x0 + 2 * dpr, cy - bh / 2 + 2 * dpr, x0 + 2 * dpr + (bw - 6 * dpr) * .87, cy + bh / 2 - 2 * dpr]
    d.rounded_rectangle(inner, radius=1.5 * dpr, fill=INK)
    fs = ImageFont.truetype(str(FONT), int(12 * dpr))
    x = x0 - 5 * dpr
    d.text((x, cy), '87%', font=fs, fill=INK, anchor='rm')
    x -= d.textlength('87%', font=fs) + 8 * dpr
    # Wi-Fi: three arcs and a dot
    wc = (x - 8 * dpr, cy + 5 * dpr)
    for i, r in enumerate((3, 6.5, 10)):
        rr = r * dpr
        if i == 0:
            d.pieslice([wc[0] - rr, wc[1] - rr, wc[0] + rr, wc[1] + rr], 225, 315, fill=INK)
        else:
            d.arc([wc[0] - rr, wc[1] - rr, wc[0] + rr, wc[1] + rr], 225, 315, fill=INK, width=max(1, int(1.7 * dpr)))
    x -= 22 * dpr
    # signal: four rising bars
    for i in range(4):
        bx = x - (3 - i) * 4.2 * dpr
        top = cy + 5.5 * dpr - (3 + i * 2.6) * dpr
        d.rounded_rectangle([bx - 3 * dpr, top, bx, cy + 5.5 * dpr], radius=.8 * dpr, fill=INK)


def main():
    for p in sorted((R / 'store/device').glob('*/*.png')):
        dev = p.parent.name.rsplit('-', 1)[0]
        dpr, h = DEV[dev]
        im = Image.open(p).convert('RGB')
        bar(im, dpr, h)
        im.save(p)
    print('bars drawn')


if __name__ == '__main__':
    main()
