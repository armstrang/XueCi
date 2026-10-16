"""Browser smoke test for the built app page (app/src/main/assets/index.html).

    python3 web/build.py && python3 tests/smoke.py

Needs Playwright for Python with Chromium (pip install playwright && playwright install chromium).
Screenshots go to tests/out/ (ignored by git). Exits non-zero on any failed check or page error.
"""
import asyncio
import functools
import http.server
import json
import os
import random
import socketserver
import sys
import threading

from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'app', 'src', 'main', 'assets')


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


# Serve the app's assets over http, like the app does, so the bundled fonts load too.
SERVER = socketserver.ThreadingTCPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=ASSETS))
threading.Thread(target=SERVER.serve_forever, daemon=True).start()
HOST = f'http://127.0.0.1:{SERVER.server_address[1]}'
PAGE = HOST + '/index.html'
OUT = os.path.join(ROOT, 'tests', 'out')
failures = []


def check(cond, what):
    print(('ok   ' if cond else 'FAIL ') + what)
    if not cond:
        failures.append(what)


# Answers whatever the current practice item is: right (ok=True) or wrong. Returns what it did.
STEP = '''ok => { const it = run && run.items[run.i]; if (!it) return 'end';
  if (it.k === 'card') {
    if (it.st === 'front') { document.getElementById('fcYes').click(); return 'claim' }
    if (it.st === 'check') { const i = ok ? it.chk.ans : (it.chk.ans + 1) % it.chk.opts.length; document.querySelectorAll('#fcAct [data-c]')[i].click(); return 'check' }
    document.getElementById('fcNext').click(); return 'next' }
  if (!it.done) { const i = ok ? it.ans : (it.ans + 1) % it.opts.length; document.querySelectorAll('.opts button')[i].click(); return 'answer' }
  document.getElementById('qNext').click(); return 'next' }'''


async def run_case(browser, width, locale, theme, fs=1, onboarding=False):
    tag = f'{width}-{locale}-{theme}' + (f'-text{fs}' if fs != 1 else '')
    errors, outside = [], []
    ctx = await browser.new_context(viewport={'width': width, 'height': 800}, locale=locale, has_touch=True)
    await ctx.add_init_script("localStorage.setItem('hsk16_theme', JSON.stringify('%s'));%s" % (
        theme, '' if onboarding else "localStorage.setItem('xc_onb','1');"))
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    pg.on('request', lambda r: r.url.startswith(HOST) or r.url.startswith('data:') or outside.append(r.url))
    await pg.goto(PAGE + (f'?fs={fs}' if fs != 1 else ''))
    await pg.wait_for_timeout(900)
    fonts = await pg.evaluate("""() => document.fonts.check('900 40px "Noto Serif SC"', '学') && document.fonts.check('700 16px "Plus Jakarta Sans"', 'A')""")
    check(fonts, f'{tag}: bundled fonts are in use')
    overflow = lambda: pg.evaluate('document.documentElement.scrollWidth > innerWidth')
    shot = lambda name, full=False: pg.screenshot(path=os.path.join(OUT, f'{tag}-{name}.png'), full_page=full)
    step = lambda ok=True: pg.evaluate(STEP, ok)

    check(await pg.title() == 'XueCi Mandarin', f'{tag}: page title')

    # first start: the goal sheet opens once; set an exam goal with too little time, take the suggested fix, save
    if onboarding:
        check(await pg.locator('#goalSheet').is_visible(), f'{tag}: goal sheet opens on first start')
        await pg.click('.gseg[data-g="t"][data-v="exam"]')
        await pg.click('.gseg[data-g="lv"][data-v="3"]')
        await pg.click('.gseg[data-g="pace"][data-v="min"]')
        await pg.click('.gnum[data-n="5"]')
        await pg.wait_for_timeout(150)
        await shot('goal', True)
        check(await pg.locator('.gfc.bad [data-fix="min"]').count() == 1, f'{tag}: too little time is flagged with a fix')
        await pg.click('.gfc [data-fix="min"]')
        check(await pg.locator('.gfc.good').count() == 1, f'{tag}: the fix puts the goal on track')
        await pg.click('#gSave')
        await pg.wait_for_timeout(300)
        g = await pg.evaluate('LM.goal')
        check(g and g['t'] == 'exam' and g['lv'] == 3 and g['pace'] == 'min' and g['n'] > 5, f'{tag}: goal saved {g}')
        check(await pg.locator('#goalSheet').is_hidden() and 'HSK 3' in await pg.locator('#goalBtn').text_content(), f'{tag}: plan card shows the goal')
    else:
        check(await pg.locator('#goalSheet').is_hidden(), f'{tag}: no goal sheet after the first start')

    check(await pg.evaluate('state.screen') == 'home' and not await overflow(), f'{tag}: home, no sideways scroll')
    check(await pg.locator('#planGo').is_visible(), f'{tag}: plan card with a start button')
    await shot('home')

    # level pills (Home lens)
    await pg.click('.lvpill[data-l="3"]')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.level') == 3, f'{tag}: HSK pill changes level')

    # cards: "I know it" asks for proof first; right → proven, wrong → sure but wrong; "Don't know" shows the back
    await pg.click('.tile[data-go="card"]')
    await pg.wait_for_timeout(400)
    await pg.click('#flip .spk.lg')
    await pg.wait_for_timeout(150)
    check(await pg.evaluate("run.items[run.i].st") == 'front', f'{tag}: speaker on the card does not reveal it')
    await pg.click('#fcYes')
    await pg.wait_for_timeout(150)
    check(await pg.locator('#fcAct [data-c]').count() >= 3, f'{tag}: "I know it" asks a quick check first')
    check(not await pg.evaluate("document.getElementById('flip').classList.contains('on')"), f'{tag}: card stays closed during the check')
    check(await pg.evaluate("run.items[run.i].chk.q") == 'cm', f'{tag}: after listening the check asks the meaning')
    await shot('card-check')
    await step(True)
    await pg.wait_for_timeout(550)
    check(await pg.evaluate("run.items[run.i].res") == 'ok' and await pg.evaluate("document.getElementById('flip').classList.contains('on')"), f'{tag}: right check opens the card as proven')
    await shot('card-back')
    await step()
    await pg.click('#fcNo')
    await pg.wait_for_timeout(100)
    check(await pg.evaluate("run.items[run.i].res") == 'no', f'{tag}: "Don\'t know" shows the answer')
    await step()
    await step()
    await pg.wait_for_timeout(100)
    await step(False)
    check(await pg.evaluate("run.items[run.i].res") == 'over' and await pg.evaluate('run.over') == 1, f'{tag}: sure but wrong is marked')
    check(await pg.evaluate('LM.allLog().length') == 3 and await pg.evaluate('Object.keys(stats).length') >= 3, f'{tag}: card answers are recorded')
    check(not await overflow(), f'{tag}: cards, no sideways scroll')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # quiz: guided by default; tone questions offer pinyin; wrong answers come back; exam practice is timed
    await pg.click('.tile[data-go="quiz"]')
    await pg.wait_for_timeout(400)
    check(await pg.evaluate('qType') == 'auto' and await pg.evaluate('run.items.length') == 12, f'{tag}: guided quiz round of 12')
    await step(False)
    await pg.wait_for_timeout(200)
    check(await pg.locator('.fbv.bad').count() == 1 and await pg.locator('#qNext').count() == 1, f'{tag}: wrong answer shows feedback')
    check(await pg.evaluate('run.items.length') == 13, f'{tag}: a wrong answer comes back later in the round')
    await shot('quiz')
    await pg.click('#qTypeBtn')
    await pg.wait_for_timeout(250)
    await pg.click('.qtrow[data-qt="s"]')
    await pg.wait_for_timeout(200)
    check(await pg.evaluate('qType') == 's' and await pg.locator('.opts .pyo').count() == 4, f'{tag}: tone questions offer four pinyin options')
    pys = await pg.locator('.opts .pyo').all_text_contents()
    check(len(set(pys)) == 4, f'{tag}: tone options are all different {pys}')
    await step(True)
    await pg.wait_for_timeout(200)
    check(await pg.locator('.fbv.good').count() == 1, f'{tag}: right tone answer')
    await shot('quiz-tone')
    await pg.click('#ubtn')
    await pg.wait_for_timeout(250)
    check(await pg.locator('#uMenu').is_visible(), f'{tag}: unit menu opens')
    check(await pg.evaluate('mmBack()') is True and await pg.evaluate('state.screen') == 'quiz', f'{tag}: back closes the menu first')
    frow = await pg.evaluate('''() => { const f = document.querySelector('#scr-focus .frow').getBoundingClientRect();
        return [...document.querySelectorAll('#scr-focus .frow > *')].every(k => { const r = k.getBoundingClientRect(); return r.right <= f.right + .5 && r.left >= f.left - .5 }) }''')
    check(frow, f'{tag}: header controls fit inside the capsule')
    await pg.click('#qTypeBtn')
    await pg.wait_for_timeout(250)
    await pg.click('.qtrow[data-qt="exam"]')
    await pg.wait_for_timeout(200)
    check(await pg.locator('#exTimer').count() == 1 and await pg.evaluate('run.items.length') == 20, f'{tag}: exam practice has 20 questions and a timer')
    for _ in range(20):
        await step(True)
    await pg.wait_for_timeout(200)
    check(await pg.locator('.sum').count() == 1 and await pg.evaluate('run.timer') == 0, f'{tag}: exam practice ends with a score')
    await shot('exam-done')
    await pg.click('#qTypeBtn')
    await pg.wait_for_timeout(200)
    await pg.click('.qtrow[data-qt="auto"]')
    await pg.wait_for_timeout(150)
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # today's session from Home: every item can be answered through to the summary
    await pg.click('#planGo')
    await pg.wait_for_timeout(400)
    check(await pg.evaluate('state.screen') == 'session' and await pg.locator('#lvbtn').is_hidden(), f'{tag}: session opens without level pickers')
    await shot('session')
    n = 0
    while await step(n % 5 != 3) != 'end' and n < 400:
        n += 1
    await pg.wait_for_timeout(200)
    check(await pg.locator('.sum').count() == 1, f'{tag}: session ends with a summary ({n} steps)')
    await shot('session-done', True)
    await pg.click('#sumHome')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.screen') == 'home', f'{tag}: summary leads back Home')

    # list
    await pg.click('.tile[data-go="list"]')
    await pg.wait_for_timeout(400)
    check(await pg.locator('.item').count() > 10 and not await overflow(), f'{tag}: list shows words')
    check(await pg.locator('.item .spk').count() >= 20, f'{tag}: list has speaker buttons for words and sentences')
    check(await pg.locator('.item .zp').count() >= 10 and await pg.locator('.item .zp mark').count() >= 10, f'{tag}: example sentences show pinyin with the word highlighted')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # stats: insights, lens, word detail with skills; answer history can be deleted
    await pg.click('#hero')
    await pg.wait_for_timeout(450)
    check(await pg.locator('#stIns .kpis').count() == 1 and await pg.locator('#stIns .skrow').count() >= 2, f'{tag}: stats show learning insights')
    await shot('stats')
    check(await pg.locator('#scr-stats .lvseg .lens').count() == 1, f'{tag}: stats HSK selector has the lens')
    await pg.click('#stLevels .lvpill[data-sl="5"]')
    await pg.wait_for_timeout(300)
    check(await pg.evaluate('stLevel') == 5, f'{tag}: stats level pill')
    sid = await pg.evaluate("Object.keys(stats).find(id => LM.has(id))")
    lv = int(sid.split(':')[0])
    await pg.click(f'#stLevels .lvpill[data-sl="{lv}"]')
    await pg.wait_for_timeout(300)
    await pg.click(f'[data-sid="{sid}"]')
    check(await pg.locator('#stDetail .skc').count() == 4 and await pg.locator('#stDetail .ans').count() == 0, f'{tag}: word detail shows skills, no self-report buttons')
    await pg.click('#hxAsk')
    await pg.click('#hxYes')
    await pg.wait_for_timeout(150)
    check(await pg.evaluate('LM.allLog().length') == 0 and await pg.evaluate('Object.keys(stats).length') > 0, f'{tag}: deleting the answer history keeps progress')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # tone info sheet
    await pg.click('#toneInfo')
    await pg.wait_for_timeout(450)
    check(await pg.locator('.tone').count() == 5, f'{tag}: tone sheet lists 5 tones')
    check(await pg.get_attribute('.plink', 'href') == 'https://armstrang.github.io/XueCi/privacy/' and bool((await pg.locator('.plink').text_content()).strip()), f'{tag}: privacy policy link in About')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(200)

    # progress backup -> restore round trip (levels, memory states and goal)
    before = await pg.evaluate('[stats, LM.exportMem(), LM.goal]')
    await pg.click('#bkBtn')
    await pg.wait_for_timeout(350)
    check(await pg.locator('.bkopt').count() == 2, f'{tag}: backup sheet offers back up and restore')
    await pg.click('.bkopt[data-bk="make"]')
    await pg.wait_for_timeout(500)
    code = await pg.input_value('#bkCode')
    check(code.startswith('XUECI'), f'{tag}: backup code is made ({len(code)} characters)')
    await pg.evaluate('mmBack()')
    check(await pg.locator('#bkOpts').is_visible(), f'{tag}: back returns to the two choices')
    await pg.click('.bkopt[data-bk="restore"]')
    await pg.wait_for_timeout(300)
    await pg.fill('#bkCode', 'not a code')
    await pg.click('#bkCheck')
    await pg.wait_for_timeout(150)
    check(await pg.locator('#bkApply').count() == 0, f'{tag}: a wrong code is refused')
    await pg.evaluate("Object.keys(stats).slice(0, 3).forEach(id => { delete stats[id]; LM.forget(id) })")
    await pg.fill('#bkCode', 'XueCi backup:\n' + code)
    await pg.click('#bkCheck')
    await pg.wait_for_timeout(300)
    await pg.click('#bkApply')
    await pg.wait_for_timeout(400)
    check(await pg.locator('#bkSheet').is_hidden(), f'{tag}: sheet closes after restoring')
    check(await pg.evaluate('[stats, LM.exportMem(), LM.goal]') == before, f'{tag}: restore brings the same progress, memory and goal back')
    tone_row = await pg.evaluate('''() => { const a = document.getElementById('toneInfo').getBoundingClientRect(), b = document.getElementById('bkBtn').getBoundingClientRect();
        return Math.abs(a.top - b.top) < 2 && b.left >= a.right && b.right <= innerWidth - 8 }''')
    check(tone_row, f'{tag}: backup button sits beside tone info')

    # language switch
    await pg.click('#langBtn')
    await pg.wait_for_timeout(200)
    await pg.click('.lgrow[data-lang="vi"]')
    await pg.wait_for_timeout(300)
    check('Kiểm tra' in await pg.locator('.tiles').text_content() and 'Hôm nay' in await pg.locator('#plan').text_content(), f'{tag}: switch to Vietnamese')

    check(await pg.evaluate('mmBack()') is False, f'{tag}: back on Home leaves the app')
    check(not outside, f'{tag}: no requests leave the app {outside[:2]}')
    check(not errors, f'{tag}: no page errors {errors[:2]}')
    await ctx.close()


async def legacy_case(browser):
    """Progress saved by an older version keeps its levels; green words wait to be confirmed."""
    tag = 'legacy'
    ctx = await browser.new_context(viewport={'width': 390, 'height': 800}, locale='en-US')
    old = {'1:学生': [25, 1, 20], '1:你好': [10, 0, 10], '2:已经': [16, 0, 16]}
    with open(os.path.join(ROOT, 'web', 'data', 'vocab.json'), encoding='utf8') as f:
        rnd = random.Random(3)
        for d in rnd.sample(json.load(f), 600):
            old.setdefault(f"{d['l']}:{d['h']}", [rnd.randint(1, 30), rnd.randint(0, 9), rnd.randint(0, 20)])
    await ctx.add_init_script("localStorage.setItem('mm_stats', %s);localStorage.setItem('xc_onb','1')" % json.dumps(json.dumps(old)))
    pg = await ctx.new_page()
    errors = []
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(800)
    levels = await pg.evaluate("['1:学生','1:你好','2:已经'].map(id => stats[id][2])")
    check(levels == [20, 10, 16], f'{tag}: old levels are kept {levels}')
    changed = await pg.evaluate('o => Object.keys(o).filter(id => !stats[id] || stats[id][2] !== o[id][2] || !LM.mem(id)).length', old)
    check(changed == 0, f'{tag}: all {len(old)} old words keep their level ({changed} changed)')
    check(await pg.evaluate("LM.mem('1:学生').L") == 1 and await pg.evaluate("LM.pickType(IDX.get('1:学生'))") == 'f', f'{tag}: old green word is confirmed with a recall question')
    await pg.click('#hero')
    await pg.wait_for_timeout(400)
    await pg.click('[data-sid="1:学生"]')
    check(await pg.locator('#stDetail .badge').count() == 1, f'{tag}: word detail says it needs confirming')
    await pg.evaluate("LM.answer(IDX.get('1:学生'), {q:'f', ok:true, ms:3000}); LM.answer(IDX.get('1:学生'), {q:'s', ok:true, ms:3000})")
    check(await pg.evaluate("LM.mem('1:学生').L") == 2 and await pg.evaluate("stats['1:学生'][2]") == 20, f'{tag}: confirmed word stays green')
    # an old (v1) backup code restores as "needs confirming" too
    code = await pg.evaluate("""(async () => { const raw = new TextEncoder().encode(JSON.stringify({app:'xueci', v:1, at:Date.now(), stats:{'3:银行':[5,0,14]}}));
        return 'XUECI0:' + B64(raw) })()""")
    b = await pg.evaluate("readCode(%s).then(b => { bkPending = b; bkApply(); return LM.mem('3:银行') })" % json.dumps(code))
    check(b and b.get('L') == 1 and await pg.evaluate("stats['3:银行'][2]") == 14, f'{tag}: a v1 backup code restores its levels')
    # the engine: cramming the same day cannot turn a new word green; spaced right answers can
    crammed = await pg.evaluate("""(() => { let st = null; for (let i = 0; i < 12; i++) st = LM.step(LM.W0, st, 3, 1000 + i, 0); return LM.levelOf({w: st, f: [5,1,1,3,1], s: [5,1,1,3,1]}) })()""")
    spaced = await pg.evaluate("""(() => { let st = null, t = 1000; for (const d of [0, 3, 11, 35]) { t += d * 1440; st = LM.step(LM.W0, st, 3, t, 0) } return LM.levelOf({w: st, f: [5,1,1,3,1], s: [5,1,1,3,1]}) })()""")
    check(crammed < 14 <= spaced, f'{tag}: cramming stays below green ({crammed}), spaced reviews reach it ({spaced})')
    check(not errors, f'{tag}: no page errors {errors[:2]}')
    await ctx.close()


async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for width, locale, theme, fs, onb in ((360, 'id-ID', 'light', 1, True), (412, 'en-US', 'dark', 1, False), (320, 'th-TH', 'black', 1, False),
                                              (1280, 'vi-VN', 'auto', 1, False), (360, 'vi-VN', 'light', 1.6, True)):
            await run_case(browser, width, locale, theme, fs, onb)
        await legacy_case(browser)
        await browser.close()
    print(f'\n{len(failures)} failed' if failures else '\nall checks passed')
    sys.exit(1 if failures else 0)


asyncio.run(main())
