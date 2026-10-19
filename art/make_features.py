#!/usr/bin/env python3
"""One 4K picture (3840 × 2160) of the app's main features, Indonesian and English.

Uses the phone screenshots in store/shots/<lang>/ (STORE=1 flutter test --no-pub --update-goldens
test/store_shots_test.dart), the Play icon and the app's own fonts; renders with Playwright's Chromium.
Writes store/features-<lang>.png.

    python3 art/make_features.py
"""
import base64
import io
import pathlib

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / 'mobile/assets/fonts'
W, H = 3840, 2160

# (screenshot, Indonesian title + line, English title + line)
SHOTS = [
    ('1-home', 'Beranda', 'Rencana harian & ranahmu', 'Home', 'Your daily plan & realm'),
    ('3-card', 'Kartu', '"Saya tahu"? Buktikan dulu', 'Cards', '"I know it"? Prove it first'),
    ('4-quiz', 'Kuis kalimat', 'Bantuan sesuai level HSK', 'Sentence quiz', 'Help that fits your HSK level'),
    ('7-tones', 'Nada', 'Latih pinyin dan nada', 'Tones', 'Practise pinyin and tones'),
    ('5-list', 'Daftar kata', 'Contoh kalimat berpinyin', 'Word list', 'Example sentences with pinyin'),
    ('9-mock', 'Simulasi HSK', 'Seperti ujian HSK 3.0', 'HSK mock exam', 'Laid out like HSK 3.0'),
    ('10-placement', 'Tes penempatan', '50 soal adaptif', 'Placement test', '50 adaptive questions'),
    ('11-bt', 'Terobosan', 'Ujian untuk naik ranah', 'Breakthrough', 'The test to rise a realm'),
    ('2-soul', 'Lautan Jiwa', 'Semua katamu dalam satu bola', 'Sea of Consciousness', 'All your words in one orb'),
    ('8-stats', 'Statistik', 'Seberapa kuat ingatanmu', 'Stats', 'How well you remember'),
]

TEXT = {
    'id': dict(
        head='Kuasai 5.334 kata<br>HSK 1–6, sedikit<br>demi sedikit<br>setiap hari.',
        sub='Kartu, kuis, simulasi ujian, dan perjalanan kultivasi dari 凡人 sampai 飞升. Aplikasi mengatur '
            'kata mana yang perlu diulang hari ini.',
        foot='Gratis · tanpa iklan · tanpa akun · bisa offline',
    ),
    'en': dict(
        head='Master all 5,334<br>HSK 1–6 words,<br>a little<br>every day.',
        sub='Cards, quizzes, mock exams and a cultivation journey from 凡人 to 飞升. The app picks the words '
            'you need to review today.',
        foot='Free · no ads · no account · works offline',
    ),
}

REALMS = ['凡', '炼', '筑', '金', '元', '化', '渡', '飞']


def data_url(path, width=None, fmt='JPEG'):
    im = Image.open(path).convert('RGB')
    if width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, fmt, quality=94)
    return f'data:image/{fmt.lower()};base64,' + base64.b64encode(b.getvalue()).decode()


def font(name, file, weight):
    return f"@font-face{{font-family:{name};src:url('file://{FONTS / file}');font-weight:{weight}}}"


def page(lang):
    t = TEXT[lang]
    shots = ROOT / 'store/shots' / lang
    icon = data_url(ROOT / 'art/play-icon-512.png', 360, 'PNG')
    faces = ''.join([
        font('J', 'pjs-500.ttf', 500), font('J', 'pjs-700.ttf', 700), font('J', 'pjs-800.ttf', 800),
        font('S', 'serif-sc-900.ttf', 900),
    ])
    cells = []
    for i, (f, it, il, et, el) in enumerate(SHOTS):
        title, line = (it, il) if lang == 'id' else (et, el)
        cells.append(f'''<div class="cell">
  <div class="cap"><span class="n">{i + 1}</span><div><b>{title}</b><i>{line}</i></div></div>
  <div class="phone"><img src="{data_url(shots / (f + '.png'), 1000)}"></div>
</div>''')
    realms = ''.join(f'<span class="{"on" if i == 2 else ""}">{c}</span>' for i, c in enumerate(REALMS))
    return f'''<!doctype html><html><head><meta charset="utf-8"><style>
{faces}
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{W}px;height:{H}px;overflow:hidden}}
body{{position:relative;font-family:J,sans-serif;color:#fff;
  background:
    radial-gradient(1700px 1300px at 0% 0%, rgba(255,92,58,.80), transparent 70%),
    radial-gradient(1800px 1500px at 100% 100%, rgba(40,96,255,.70), transparent 70%),
    radial-gradient(1500px 900px at 60% 45%, rgba(255,196,92,.14), transparent 70%),
    linear-gradient(135deg,#5a1a5e 0%,#2a1666 45%,#14237a 100%)}}
.grain{{position:absolute;inset:0;opacity:.06;mix-blend-mode:overlay;
  background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='300' height='300'><filter id='n'><feTurbulence baseFrequency='.8' numOctaves='2'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>")}}
.ring{{position:absolute;border-radius:50%;border:3px solid rgba(255,214,120,.16)}}
.left{{position:absolute;left:150px;top:0;bottom:0;width:860px;display:flex;flex-direction:column;justify-content:center}}
.icon{{width:200px;height:200px;border-radius:52px;
  box-shadow:0 36px 70px -24px rgba(0,0,0,.6),0 0 0 2px rgba(255,255,255,.25)}}
.cn{{margin-top:56px;font-family:S;font-weight:900;font-size:40px;letter-spacing:14px;color:#ffd27a}}
h1{{margin-top:10px;font-weight:800;font-size:112px;letter-spacing:-3px;line-height:1}}
h1 b{{color:#ffd27a;font-weight:800}}
.head{{margin-top:60px;font-weight:800;font-size:76px;line-height:1.12;letter-spacing:-1.5px}}
.sub{{margin-top:44px;font-weight:500;font-size:36px;line-height:1.5;color:rgba(255,255,255,.86)}}
.realms{{margin-top:54px;display:flex;align-items:center}}
.realms span{{width:76px;height:76px;border-radius:50%;display:grid;place-items:center;font-family:S;font-weight:900;
  font-size:36px;color:#ffe6b0;border:2.5px solid rgba(255,214,120,.55);background:rgba(255,255,255,.06)}}
.realms span+span{{margin-left:26px;position:relative}}
.realms span+span::before{{content:'';position:absolute;right:100%;top:50%;width:26px;height:2.5px;background:rgba(255,214,120,.45)}}
.realms span.on{{background:linear-gradient(180deg,#ffd27a,#e59a3a);color:#3a1d4a;border-color:#ffe2a0;
  box-shadow:0 0 34px rgba(255,200,110,.75)}}
.foot{{margin-top:56px;font-weight:700;font-size:32px;color:#ffd27a;letter-spacing:.5px}}
.grid{{position:absolute;left:1110px;right:110px;top:90px;bottom:90px;
  display:grid;grid-template-columns:repeat(5,1fr);grid-template-rows:1fr 1fr;column-gap:46px;row-gap:56px}}
.cell{{display:flex;flex-direction:column;align-items:center;min-height:0}}
.cap{{display:flex;align-items:center;gap:16px;width:100%;margin-bottom:22px;padding-left:6px}}
.cap .n{{flex:none;width:52px;height:52px;border-radius:50%;display:grid;place-items:center;font-weight:800;font-size:26px;
  color:#3a1d4a;background:linear-gradient(180deg,#ffe2a0,#f0a945)}}
.cap b{{display:block;font-weight:800;font-size:34px;line-height:1.1}}
.cap i{{display:block;font-style:normal;font-weight:500;font-size:24px;color:rgba(255,255,255,.78);margin-top:4px;white-space:nowrap}}
.phone{{flex:1;min-height:0;aspect-ratio:1080/1920;border-radius:58px;padding:11px;
  background:linear-gradient(160deg,#454a5e,#16171f 55%,#2f3140);
  box-shadow:0 50px 90px -30px rgba(5,5,30,.8),inset 0 0 0 2.5px rgba(255,255,255,.18)}}
.phone img{{width:100%;height:100%;border-radius:47px;display:block;object-fit:cover;object-position:top}}
</style></head><body>
<div class="ring" style="left:-420px;top:1100px;width:1500px;height:1500px"></div>
<div class="ring" style="left:-300px;top:1220px;width:1260px;height:1260px;border-color:rgba(255,255,255,.07)"></div>
<div class="left">
  <img class="icon" src="{icon}">
  <div class="cn">学词 · XUÉCÍ</div>
  <h1>XueCi <b>Mandarin</b></h1>
  <div class="head">{t['head']}</div>
  <div class="sub">{t['sub']}</div>
  <div class="realms">{realms}</div>
  <div class="foot">{t['foot']}</div>
</div>
<div class="grid">{''.join(cells)}</div>
<div class="grain"></div>
</body></html>'''


def main():
    tmp = ROOT / 'art/.features'
    tmp.mkdir(exist_ok=True)
    with sync_playwright() as p:
        exe = pathlib.Path('/opt/pw-browsers/chromium')
        b = p.chromium.launch(executable_path=str(exe) if exe.exists() else None)
        pg = b.new_page(viewport={'width': W, 'height': H}, device_scale_factor=1)
        for lang in TEXT:
            html = tmp / f'{lang}.html'
            html.write_text(page(lang), encoding='utf-8')
            pg.goto(html.as_uri())
            pg.wait_for_timeout(500)
            out = ROOT / f'store/features-{lang}.png'
            Image.open(io.BytesIO(pg.screenshot(type='png'))).convert('RGB').save(out, optimize=True)
            print(out.relative_to(ROOT), Image.open(out).size, f'{out.stat().st_size // 1024} KB')
        b.close()
    for f in tmp.iterdir():
        f.unlink()
    tmp.rmdir()


if __name__ == '__main__':
    main()
