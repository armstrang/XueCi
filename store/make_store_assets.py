"""Make the Google Play store images from the real app page.

    python3 web/build.py && python3 store/make_store_assets.py

Writes (JPEG, no transparency, as Play asks):
  store/screenshots/<lang>/0N-*.jpg   phone screenshots, 1080 x 1920 (9:16), caption on top
  store/feature-graphic-<lang>.jpg    feature graphic, 1024 x 500
  store/preview-<lang>.jpg            all of them on one sheet, to check at a glance (not for upload)

The app runs with sample progress (levels, memory states, a goal and two weeks of answers) so the screens look
lived-in. Captions are in CAPTIONS below.
Needs Playwright for Python with Chromium.
"""
import asyncio
import datetime
import functools
import http.server
import json
import os
import random
import socketserver
import threading
import time

from PIL import Image
from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, 'store')

CAPTIONS = {
    'id': {
        'locale': 'id-ID',
        'shots': [
            ('home', 'Kuasai 5.334 kata HSK 1–6', 'Rencana harian sesuai tujuanmu'),
            ('soul', 'Lautan Jiwa', 'Ranah kultivasi & lima elemen dari ingatanmu'),
            ('card', 'Bilang tahu? Buktikan', 'Kartu dengan cek kilat sebelum dibalik'),
            ('quiz', 'Kuis terarah', 'Arti, hanzi, nada, dengar, dan kalimat'),
            ('stats', 'Kenali kelemahanmu', 'Dihitung di HP, tanpa server'),
            ('tones', 'Warna nada', 'Ucapkan setiap kata dengan nada yang tepat'),
            ('list', 'Terang, gelap, hitam pekat', 'Dalam 4 bahasa · tanpa internet'),
            ('placement', 'Tes penempatan 50 soal', 'Temukan ranah awalmu'),
        ],
        'feature': ('Kosakata HSK 1–6', 'Ranah kultivasi · Kartu · Kuis terarah · Offline'),
    },
    'en': {
        'locale': 'en-US',
        'shots': [
            ('home', 'Master 5,334 HSK 1–6 words', 'A daily plan built from your goal'),
            ('soul', 'Your Sea of Consciousness', 'Cultivation realms and five elements from your memory'),
            ('card', 'Say you know it? Prove it', 'Cards with a quick check before they flip'),
            ('quiz', 'A guided quiz', 'Meaning, hanzi, tones, listening, sentences'),
            ('stats', 'Know your weak spots', 'Worked out on your phone, no server'),
            ('tones', 'Tone colours', 'Say every word with the right tone'),
            ('list', 'Light, dark, true black', 'In 4 languages · no internet needed'),
            ('placement', 'A 50-question placement test', 'Find your starting realm'),
        ],
        'feature': ('HSK 1–6 vocabulary', 'Cultivation realms · Flashcards · Guided quiz · Offline'),
    },
}
THEME = {'home': 'light', 'soul': 'dark', 'card': 'light', 'quiz': 'light', 'stats': 'light', 'tones': 'dark', 'list': 'black', 'placement': 'light'}
LEVEL = {'home': 2, 'soul': 2, 'card': 2, 'quiz': 2, 'stats': 1, 'tones': 2, 'list': 1, 'placement': 2}


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


EPOCH = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc).timestamp()


def sample_progress():
    """Plausible progress: HSK 1 mostly learned, HSK 2 under way, HSK 3 just started; an HSK 3 exam goal;
    memory states whose level matches (some words due today) and two weeks of answers for the insights."""
    with open(os.path.join(ROOT, 'web', 'data', 'vocab.json'), encoding='utf8') as f:
        words = json.load(f)
    rnd = random.Random(7)
    now = int((time.time() - EPOCH) / 60)
    stats, mem, ids = {}, {}, []
    for d in words:
        share, lo, hi = {1: (.92, 6, 20), 2: (.55, 0, 16), 3: (.12, 0, 8)}.get(d['l'], (0, 0, 0))
        if rnd.random() < share:
            lvl = rnd.randint(lo, hi) if d['l'] > 1 else min(20, max(lo, int(rnd.triangular(lo, 21, 20))))
            wid = f"{d['l']}:{d['h']}"
            stats[wid] = [lvl + rnd.randint(0, 4), rnd.randint(0, 3), lvl]
            s = max(.1, 121 ** (lvl / 20) - 1)
            t = now - int(s * rnd.uniform(.25, 1.12) * 1440)
            dd = round(rnd.uniform(3, 7), 2)
            sk = lambda g: [dd, round(s * rnd.uniform(.7, 1.3), 3), t, g, rnd.randint(1, 5)]
            e = {'w': [dd, round(s, 3), t], 'i': now - rnd.randint(20, 90) * 1440, 'm': sk(3)}
            if lvl >= 7:
                e['f'] = sk(3)
                e['s'] = sk(3 if lvl >= 14 or rnd.random() < .6 else 1)
            mem[wid] = e
            ids.append(d)
    # answers over the last 14 days: tones are the weak spot, a few look-alikes get mixed up
    acc = {'m': .93, 'f': .82, 's': .66, 'c': .86, 'cm': .9, 'cs': .86}
    log = []
    for k in range(640):
        q = rnd.choice(['m', 'm', 'f', 'f', 's', 's', 'c', 'cm', 'cs'])
        d = rnd.choice(ids)
        ok = rnd.random() < acc[q]
        x = 0
        if not ok and q in ('m', 'f', 'c', 'cm'):
            near = [o for o in ids if o is not d and set(o['h']) & set(d['h'])]
            if near:
                o = rnd.choice(near)
                x = f"{o['l']}:{o['h']}"
        log.append([now - int((640 - k) / 640 * 14 * 1440), f"{d['l']}:{d['h']}", q, 3 if ok else 1, rnd.randint(25, 90), x, 2 if q[0] == 'c' else 0])
    goal = {'t': 'exam', 'lv': 3, 'date': (datetime.date.today() + datetime.timedelta(days=150)).isoformat(), 'pace': 'min', 'n': 25}
    lvl = {'r': 2, 'lv': 2, 'src': 'test', 'at': now - 20 * 1440, 'm': 1, 'per': [97, 64, 14, 4, 1, 0], 'hist': [[1, now - 60 * 1440], [2, now - 20 * 1440]]}
    return {'mm_stats': stats, 'xc_mem': mem, 'xc_log': log, 'xc_goal': goal, 'xc_onb': 1, 'xc_lvl': lvl, 'xc_tests': [now - 20 * 1440]}


FRAME = """<!doctype html><meta charset="utf-8"><style>
@font-face{font-family:"Plus Jakarta Sans";src:url("BASE/app/src/main/assets/fonts/pjs.woff");font-weight:400 800}
@font-face{font-family:"Noto Sans Thai";src:url("BASE/app/src/main/assets/fonts/thai.woff");font-weight:400 800}
@font-face{font-family:"Noto Serif SC";src:url("BASE/app/src/main/assets/fonts/serif-sc-900.woff");font-weight:900}
html,body{margin:0;width:360px;height:640px;overflow:hidden}
body{font-family:"Plus Jakarta Sans","Noto Sans Thai",sans-serif;color:#10241a;
  background:radial-gradient(120% 70% at 15% 0%,#cfeedd 0%,rgba(207,238,221,0) 60%),radial-gradient(90% 60% at 100% 100%,#d7e6f7 0%,rgba(215,230,247,0) 65%),#f2f5f3}
body.dark{color:#eef3f0;background:radial-gradient(120% 70% at 15% 0%,#1f4d35 0%,rgba(31,77,53,0) 62%),radial-gradient(90% 60% at 100% 100%,#1c2a44 0%,rgba(28,42,68,0) 65%),#0d1210}
.cap{position:absolute;left:24px;right:24px;top:30px;text-align:center}
.cap h1{margin:0;font-size:25px;line-height:1.15;font-weight:800;letter-spacing:-.02em}
.cap p{margin:7px 0 0;font-size:13.5px;font-weight:600;opacity:.72}
.hz{position:absolute;font-family:"Noto Serif SC",serif;font-weight:900;font-size:120px;opacity:.05;right:-8px;top:62px;letter-spacing:-.05em}
.phone{position:absolute;left:38px;top:132px;width:284px;height:568px;border-radius:34px;padding:7px;background:#0b0f0d;
  box-shadow:0 30px 60px -20px rgba(10,30,20,.45),0 0 0 1px rgba(255,255,255,.08) inset}
.phone img{display:block;width:284px;height:568px;border-radius:28px;object-fit:cover;object-position:top}
</style><body class="BODY"><div class="hz">学词</div><div class="cap"><h1>TITLE</h1><p>SUB</p></div><div class="phone"><img src="SHOT"></div></body>"""

FEATURE = """<!doctype html><meta charset="utf-8"><style>
@font-face{font-family:"Plus Jakarta Sans";src:url("BASE/app/src/main/assets/fonts/pjs.woff");font-weight:400 800}
@font-face{font-family:"Noto Serif SC";src:url("BASE/app/src/main/assets/fonts/serif-sc-900.woff");font-weight:900}
html,body{margin:0;width:1024px;height:500px;overflow:hidden}
body{font-family:"Plus Jakarta Sans",sans-serif;color:#10241a;position:relative;
  background:radial-gradient(70% 90% at 8% 10%,#cdeedb 0%,rgba(205,238,219,0) 62%),radial-gradient(60% 80% at 100% 100%,#d4e3f6 0%,rgba(212,227,246,0) 70%),#f3f6f4}
.badge{position:absolute;left:60px;top:58px;width:128px}
.name{position:absolute;left:60px;top:206px;font-size:50px;font-weight:800;letter-spacing:-.03em;line-height:1}
.tag{position:absolute;left:62px;top:270px;font-size:25px;font-weight:700;color:#2f8a4c}
.sub{position:absolute;left:62px;top:310px;font-size:18px;font-weight:600;opacity:.7}
.by{position:absolute;left:62px;bottom:44px;font-size:15px;font-weight:600;opacity:.55}
.hz{position:absolute;left:300px;top:20px;font-family:"Noto Serif SC",serif;font-weight:900;font-size:150px;letter-spacing:-.04em;opacity:.06}
.phone{position:absolute;right:60px;top:46px;width:214px;height:440px;border-radius:30px;padding:6px;background:#0b0f0d;transform:rotate(6deg);
  box-shadow:0 30px 60px -18px rgba(10,30,20,.5)}
.phone img{display:block;width:214px;height:440px;border-radius:25px;object-fit:cover;object-position:top}
.phone.back{right:250px;top:74px;transform:rotate(-6deg)}
</style><body><img class="badge" src="BASE/art/icon-badge.png"><div class="name">XueCi Mandarin</div><div class="tag">TAG</div><div class="sub">SUB</div>
<div class="by">by Armstrang</div><div class="hz">学词</div>
<div class="phone back"><img src="BACK"></div><div class="phone"><img src="FRONT"></div></body>"""


async def app_shot(browser, base, lang, locale, kind, sample, out):
    ctx = await browser.new_context(viewport={'width': 360, 'height': 720}, device_scale_factor=3, locale=locale)
    init = dict(sample, hsk16_theme=THEME[kind], hsk16_ui={'level': LEVEL[kind], 'unitBy': {}, 'qt': 's' if kind == 'quiz' else 'auto'})
    await ctx.add_init_script('const S=' + json.dumps(init) + ';for(const k in S)localStorage.setItem(k,JSON.stringify(S[k]));')
    # same cards and quiz questions on every run
    await ctx.add_init_script('{let x=12345;Math.random=()=>((x=(x*1103515245+12345)%2147483648)/2147483648)}')
    pg = await ctx.new_page()
    await pg.goto(base + '/app/src/main/assets/index.html')
    await pg.wait_for_timeout(1500)
    if kind in ('card', 'quiz', 'list'):
        await pg.click(f'.tile[data-go="{kind}"]')
        await pg.wait_for_timeout(600)
    if kind == 'card':
        await pg.evaluate('LM.checkP = () => 1')       # always show the quick check for the picture
        await pg.click('#fcYes')
        await pg.wait_for_timeout(500)
        await pg.evaluate('window.scrollTo(0, 0); document.activeElement.blur()')
        await pg.mouse.move(0, 0)
        await pg.wait_for_timeout(300)
    if kind == 'quiz':
        i = await pg.evaluate('run.items[run.i].ans')
        await pg.click(f'.opts button >> nth={i}')
        await pg.wait_for_timeout(900)
    if kind == 'soul':
        await pg.click('#curLvBtn')
        await pg.wait_for_timeout(400)
        await pg.click('#soulGo')
        await pg.wait_for_timeout(1600)
        await pg.mouse.move(0, 0)
    if kind == 'stats':
        await pg.click('#hero')
        await pg.wait_for_timeout(900)
    if kind == 'placement':
        # a fresh learner who knows HSK 1–2 well and HSK 3 a little, honest with "Don't know"
        await pg.evaluate("localStorage.removeItem('xc_lvl')")
        await pg.click('#curLvBtn')
        await pg.wait_for_timeout(400)
        await pg.click('#ptGo')
        await pg.wait_for_timeout(500)
        await pg.click('#ptBegin')
        rnd = random.Random(4)
        for _ in range(50):
            it = await pg.evaluate('pt && pt.it ? {l: pt.it.l, ans: pt.it.ans} : null')
            if not it:
                break
            known = rnd.random() < [.98, .94, .55, .12, .03, .01][it['l'] - 1]
            await pg.click(f'#ptOpts [data-p="{it["ans"]}"]' if known else '#ptIdk')
            await pg.wait_for_timeout(180)
        await pg.wait_for_timeout(900)
    if kind == 'tones':
        await pg.click('#toneInfo')
        await pg.wait_for_timeout(900)
    await pg.screenshot(path=out)
    await ctx.close()


async def compose(browser, html, w, h, out, base):
    html = html.replace('BASE', base)
    ctx = await browser.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1080 / 360 if w == 360 else 1)
    pg = await ctx.new_page()
    await pg.set_content(html)
    await pg.wait_for_function('[...document.images].every(i => i.complete && i.naturalWidth > 0) && document.fonts.status === "loaded"')
    await pg.wait_for_timeout(300)
    tmp = out + '.png'
    await pg.screenshot(path=tmp)
    await ctx.close()
    Image.open(tmp).convert('RGB').save(out, quality=90, optimize=True)
    os.remove(tmp)


async def main():
    srv = socketserver.ThreadingTCPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=ROOT))
    srv.handle_error = lambda *a: None   # a closed page can drop a connection mid-file; that's fine
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f'http://127.0.0.1:{srv.server_address[1]}'
    sample = sample_progress()
    raw = os.path.join(STORE, 'raw')
    os.makedirs(raw, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for lang, cfg in CAPTIONS.items():
            outdir = os.path.join(STORE, 'screenshots', lang)
            os.makedirs(outdir, exist_ok=True)
            done = []
            for n, (kind, title, sub) in enumerate(cfg['shots'], 1):
                shot = os.path.join(raw, f'{lang}-{kind}.png')
                await app_shot(browser, base, lang, cfg['locale'], kind, sample, shot)
                html = (FRAME.replace('TITLE', title).replace('SUB', sub).replace('SHOT', f'{base}/store/raw/{lang}-{kind}.png')
                        .replace('BODY', 'dark' if THEME[kind] != 'light' else ''))
                out = os.path.join(outdir, f'{n:02d}-{kind}.jpg')
                await compose(browser, html, 360, 640, out, base)
                done.append(out)
            tag, sub = cfg['feature']
            html = (FEATURE.replace('TAG', tag).replace('SUB', sub)
                    .replace('FRONT', f'{base}/store/raw/{lang}-home.png').replace('BACK', f'{base}/store/raw/{lang}-card.png'))
            fg = os.path.join(STORE, f'feature-graphic-{lang}.jpg')
            await compose(browser, html, 1024, 500, fg, base)
            # preview sheet
            thumbs = [Image.open(f).resize((270, 480)) for f in done]
            sheet = Image.new('RGB', (20 + 290 * len(thumbs), 520 + 260), (235, 238, 236))   # all screenshots in one row
            for i, t in enumerate(thumbs):
                sheet.paste(t, (20 + 290 * i, 20))
            sheet.paste(Image.open(fg).resize((512, 250)), (20, 515))
            sheet.save(os.path.join(STORE, f'preview-{lang}.jpg'), quality=85)
            print(lang, 'done')
        await browser.close()
    srv.shutdown()


asyncio.run(main())
