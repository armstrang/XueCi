#!/usr/bin/env python3
"""Play Store feature graphic (1024 × 500), Indonesian and English.

Uses the phone screenshots in store/shots/<lang>/ (STORE=1 flutter test --no-pub --update-goldens
test/store_shots_test.dart), the Play icon and the app's own fonts; renders with Playwright's Chromium.
Writes store/feature-<lang>.png (24-bit, no alpha, as Play wants).

    python3 art/make_banner.py
"""
import base64
import io
import pathlib

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / 'mobile/assets/fonts'
W, H = 1024, 500

TEXT = {
    'id': dict(
        tag='Kuasai 5.334 kata HSK 1–6,<br>sedikit demi sedikit setiap hari.',
        chips=['Kartu', 'Kuis', 'Nada', 'Simulasi HSK'],
    ),
    'en': dict(
        tag='Master all 5,334 HSK 1–6 words,<br>a little every day.',
        chips=['Cards', 'Quiz', 'Tones', 'HSK mock exam'],
    ),
}


def data_url(path, size=None, fmt='PNG'):
    im = Image.open(path).convert('RGB')
    if size:
        im = im.resize(size, Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, fmt, quality=92)
    return f'data:image/{fmt.lower()};base64,' + base64.b64encode(b.getvalue()).decode()


def font(name, file, weight):
    return f"@font-face{{font-family:{name};src:url('file://{FONTS / file}');font-weight:{weight}}}"


def page(lang):
    t = TEXT[lang]
    shots = ROOT / 'store/shots' / lang
    home = data_url(shots / '1-home.png', (540, 960), 'JPEG')
    soul = data_url(shots / '2-soul.png', (540, 960), 'JPEG')
    icon = data_url(ROOT / 'art/play-icon-512.png', (192, 192))
    faces = ''.join([
        font('J', 'pjs-500.ttf', 500), font('J', 'pjs-700.ttf', 700), font('J', 'pjs-800.ttf', 800),
        font('S', 'serif-sc-900.ttf', 900),
    ])
    chips = ''.join(f'<span>{c}</span>' for c in t['chips'])
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
{faces}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;font-family:J,sans-serif;color:#fff;
  background:
    radial-gradient(560px 420px at 8% 0%, rgba(255,92,58,.85), transparent 70%),
    radial-gradient(520px 460px at 100% 100%, rgba(40,96,255,.75), transparent 70%),
    radial-gradient(420px 320px at 62% 40%, rgba(255,196,92,.22), transparent 70%),
    linear-gradient(135deg,#5a1a5e 0%,#2a1666 45%,#14237a 100%)}}
.grain{{position:absolute;inset:0;opacity:.07;mix-blend-mode:overlay;
  background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence baseFrequency='.9' numOctaves='2'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>")}}
.ring{{position:absolute;border-radius:50%;border:1.5px solid rgba(255,214,120,.28)}}
.left{{position:absolute;left:64px;top:0;bottom:0;width:470px;display:flex;flex-direction:column;justify-content:center}}
.brand{{display:flex;align-items:center;gap:18px}}
.brand img{{width:84px;height:84px;border-radius:22px;
  box-shadow:0 14px 30px -10px rgba(0,0,0,.55),0 0 0 1px rgba(255,255,255,.25)}}
.cn{{font-family:S;font-weight:900;font-size:19px;letter-spacing:6px;color:#ffd27a}}
h1{{font-weight:800;font-size:46px;letter-spacing:-1px;line-height:1.02}}
h1 b{{font-weight:800;color:#ffd27a}}
.tag{{margin-top:26px;font-weight:700;font-size:25px;line-height:1.32;color:#fff}}
.chips{{margin-top:22px;display:flex;gap:9px;flex-wrap:wrap}}
.chips span{{font-weight:700;font-size:15px;padding:8px 15px;border-radius:999px;
  background:linear-gradient(180deg,rgba(255,255,255,.22),rgba(255,255,255,.09));
  border:1px solid rgba(255,255,255,.32);box-shadow:inset 0 1px 0 rgba(255,255,255,.35)}}
.phone{{position:absolute;width:236px;height:420px;border-radius:38px;padding:7px;
  background:linear-gradient(160deg,#3b3f52,#16171f 60%,#2b2d3a);
  box-shadow:0 30px 60px -18px rgba(5,5,30,.75),inset 0 0 0 1.5px rgba(255,255,255,.18)}}
.phone img{{width:100%;height:100%;border-radius:31px;display:block;object-fit:cover;object-position:top}}
.p1{{left:742px;top:60px;transform:rotate(5deg)}}
.p2{{left:562px;top:98px;transform:rotate(-4deg);z-index:2}}
.glow{{position:absolute;left:640px;top:200px;width:360px;height:360px;border-radius:50%;
  background:radial-gradient(circle,rgba(255,200,110,.35),transparent 65%)}}
</style></head><body>
<div class="ring" style="left:600px;top:-120px;width:560px;height:560px"></div>
<div class="ring" style="left:660px;top:-60px;width:440px;height:440px;border-color:rgba(255,255,255,.10)"></div>
<div class="glow"></div>
<div class="phone p1"><img src="{soul}"></div>
<div class="phone p2"><img src="{home}"></div>
<div class="left">
  <div class="brand"><img src="{icon}"><div><div class="cn">学词 · XUÉCÍ</div><h1>XueCi <b>Mandarin</b></h1></div></div>
  <div class="tag">{t['tag']}</div>
  <div class="chips">{chips}</div>
</div>
<div class="grain"></div>
</body></html>'''


def main():
    tmp = ROOT / 'art/.banner'
    tmp.mkdir(exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path='/opt/pw-browsers/chromium' if pathlib.Path('/opt/pw-browsers/chromium').exists() else None)
        pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
        for lang in TEXT:
            html = tmp / f'{lang}.html'
            html.write_text(page(lang), encoding='utf-8')
            pg.goto(html.as_uri())
            pg.wait_for_timeout(300)
            png = pg.screenshot(type='png')
            out = ROOT / f'store/feature-{lang}.png'
            Image.open(io.BytesIO(png)).convert('RGB').save(out, optimize=True)
            print(out.relative_to(ROOT), Image.open(out).size)
        b.close()
    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()


if __name__ == '__main__':
    main()
