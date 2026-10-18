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
RN = ['凡人', '炼气', '筑基', '金丹', '元婴', '化神', '渡劫', '飞升']


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
        check(await pg.locator('#gPt').count() == 1, f'{tag}: first start suggests the placement test')
        await pg.click('.gseg[data-g="t"][data-v="exam"]')
        await pg.click('.gseg[data-g="lv"][data-v="3"]')
        await pg.click('.gseg[data-g="pace"][data-v="min"]')
        await pg.click('.gnum[data-n="5"]')
        await pg.wait_for_timeout(150)
        await shot('goal', True)
        check(await pg.locator('.gfc.bad [data-fix="min"]').count() == 1, f'{tag}: too little time is flagged with a fix')
        await pg.click('.gfc [data-fix="min"]')
        check(await pg.locator('.gfc.good').count() == 1, f'{tag}: the fix puts the goal on track')
        for w in ('0', '6', '3'):
            await pg.click(f'[data-wk="{w}"]')
        check(await pg.locator('[data-wk][aria-pressed="true"]').count() == 2, f'{tag}: at most two meditation days')
        await pg.click('[data-wk="3"]')
        await pg.click('[data-wk="0"]')
        await pg.click('#gSave')
        await pg.wait_for_timeout(300)
        g = await pg.evaluate('LM.goal')
        check(g and g['t'] == 'exam' and g['lv'] == 3 and g['pace'] == 'min' and g['n'] > 5, f'{tag}: goal saved {g}')
        check(sorted(await pg.evaluate('LM.rest')) == [0, 6], f'{tag}: meditation days saved')
        await pg.evaluate('LM.setRest([])')
        check(await pg.locator('#goalSheet').is_hidden() and 'HSK 3' in await pg.locator('#goalBtn').text_content(), f'{tag}: plan card shows the goal')
    else:
        check(await pg.locator('#goalSheet').is_hidden(), f'{tag}: no goal sheet after the first start')

    check(await pg.evaluate('state.screen') == 'home' and not await overflow(), f'{tag}: home, no sideways scroll')
    check(await pg.locator('#planGo').is_visible(), f'{tag}: plan card with a start button')
    check(await pg.locator('#curLvName').text_content() == '凡人' and 'Armstrang' not in await pg.locator('header.top').text_content(),
          f'{tag}: header shows the realm (凡人 before any test) and no "by Armstrang"')
    check(await pg.locator('#chalBtn').is_visible(), f'{tag}: plan card shows today\'s trial')
    check(await pg.evaluate("getComputedStyle(document.getElementById('curLvBtn')).getPropertyValue('--p').trim()") == '0', f'{tag}: the realm chip has a progress ring')
    if fs == 1 and width >= 360:
        await pg.set_viewport_size({'width': width, 'height': 680})
        await pg.wait_for_timeout(250)
        fits = await pg.evaluate('document.documentElement.scrollHeight <= innerHeight + 1')
        await shot('home-680')
        check(fits, f'{tag}: Home fits one screen at {width}x680')
        await pg.set_viewport_size({'width': width, 'height': 800})
        await pg.wait_for_timeout(150)
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
    # sentence gaps: no translation before answering, sentence pinyin with a gap (HSK 1–3), optional translation hint
    await pg.click('#qTypeBtn')
    await pg.wait_for_timeout(250)
    await pg.click('.qtrow[data-qt="c"]')
    await pg.wait_for_timeout(200)
    check(await pg.locator('.qt-c .id').count() == 0 and await pg.locator('#qTr').count() == 1, f'{tag}: sentence question hides the translation')
    check('＿＿' in (await pg.locator('.qt-c .zp').text_content() or ''), f'{tag}: sentence pinyin is shown with a gap')
    await pg.click('#qTr')
    await pg.wait_for_timeout(100)
    check(await pg.locator('.qt-c .id').count() == 1 and await pg.evaluate('run.items[run.i].hint') is True, f'{tag}: the translation hint can be opened')
    await step(False)
    await pg.wait_for_timeout(150)
    check(await pg.evaluate('LM.allLog().slice(-1)[0][6] & 32') == 32, f'{tag}: a hinted answer is logged as hinted')
    if await pg.locator('#qAmb').count():
        tot, logn = await pg.evaluate('run.tot'), await pg.evaluate('LM.allLog().length')
        await pg.click('#qAmb')
        await pg.wait_for_timeout(100)
        check(await pg.locator('.fbv.amb').count() == 1 and await pg.evaluate('run.tot') == tot - 1 and await pg.evaluate('LM.allLog().length') == logn - 1,
              f'{tag}: "my choice fits too" takes the answer back')
    await shot('quiz-cloze')
    # a tired sitting (25 min, accuracy falling) is offered a short break before the next question
    await pg.evaluate("sit = {t0: Date.now() - 26*6e4, last: Date.now(), ans: Array.from({length: 20}, (_, i) => [i < 10 ? 1 : i % 2, 3000]), shown: false, brk: null}")
    await pg.click('#qNext')
    await pg.wait_for_timeout(150)
    check(await pg.locator('.restcard').count() == 1 and await pg.locator('#brGo').count() == 1, f'{tag}: tiredness offers a 调息 break')
    await pg.click('#brGo')
    await pg.wait_for_timeout(150)
    check(await pg.locator('.bcirc').count() == 1 and (await pg.locator('#brTime').text_content()).startswith('5:00') or (await pg.locator('#brTime').text_content()).startswith('4:5'),
          f'{tag}: the break counts down with a breathing guide')
    await shot('rest-break')
    await pg.click('#brSkip')
    await pg.wait_for_timeout(150)
    check(await pg.evaluate('run.brk') is None and await pg.locator('.qcard .opts button').count() == 4, f'{tag}: the round carries on after the break')
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

    # realm: the sheet has only tests (no manual pick); placement test (an HSK 1–2 learner who says "don't know" honestly)
    if width == 360:
        await pg.click('#curLvBtn')
        await pg.wait_for_timeout(350)
        check(await pg.locator('#lvlSheet').is_visible() and await pg.locator('[data-lvset]').count() == 0 and await pg.locator('#soulGo').count() == 1,
              f'{tag}: realm sheet with the test and "see more", no manual pick')
        await shot('realm-sheet')
        await pg.click('#ptGo')
        await pg.wait_for_timeout(450)
        check(await pg.evaluate('state.screen') == 'placement' and await pg.locator('#ptBegin').count() == 1, f'{tag}: placement test intro')
        await pg.click('#ptBegin')
        await pg.wait_for_timeout(200)
        await shot('placement')
        rnd = random.Random(11)
        for _ in range(50):
            it = await pg.evaluate('pt && pt.it ? {l: pt.it.l, ans: pt.it.ans, n: pt.it.opts.length} : null')
            if not it:
                break
            check(it['n'] == 4, f'{tag}: placement question has 4 options') if _ == 0 else None
            known = rnd.random() < [.97, .9, .2, .05, .02, .01][it['l'] - 1]
            await pg.click(f'#ptOpts [data-p="{it["ans"]}"]' if known else '#ptIdk')
            await pg.wait_for_timeout(190)
        await pg.wait_for_timeout(300)
        res = await pg.evaluate('pt && pt.res')
        await shot('placement-result', True)
        check(await pg.locator('.ptres .stage .sg i.tc').count() >= 1 and await pg.locator('.ptres .sttest').count() == 1,
              f'{tag}: the result shows where the test puts you inside the realm')
        check(res and res['n'] == 50 and 2 <= res['lv'] <= 3, f'{tag}: placement test of 50 places an HSK 1–2 learner at HSK 2–3 ({res and res["lv"]})')
        check(await pg.evaluate('LM.level.src') == 'test' and await pg.evaluate('LM.realm()') == res['lv'] and await pg.locator('#curLvName').text_content() == RN[res['lv']],
              f'{tag}: the chip shows the tested realm ({RN[res["lv"]]})')
        check(await pg.evaluate("LM.allLog().filter(e => e[6] & 16).length") >= 1, f'{tag}: placement answers are logged as placement')
        await pg.click('#ptHome')
        await pg.wait_for_timeout(400)
        await pg.click('#curLvBtn')
        await pg.wait_for_timeout(300)
        check(await pg.locator('#ptGo').is_disabled() and await pg.locator('#lvlSheet .lockn').count() == 1, f'{tag}: one test a week (the next test is locked)')
        await pg.click('#soulGo')
        await pg.wait_for_timeout(500)
        check(await pg.evaluate('state.screen') == 'soul' and await pg.locator('.wheel .wtrk').count() == 5 and await pg.locator('.elrow').count() == 5,
              f'{tag}: Soul Sea shows the orb inside the five-element ring')
        # the placement test counts toward realm progress: half its estimate, shown as a lighter layer and a line
        st = await pg.evaluate('LM.stage()')
        check(st['testShare'] > 0 and st['share'] >= st['testShare'] and await pg.locator('#soulBody .sg i.tc').count() >= 1 and await pg.locator('#soulBody .sttest').count() == 1,
              f'{tag}: the placement test counts toward realm progress ({round(st["share"] * 100)}%)')
        # each ring segment fills clockwise from its badge and never reaches the next badge unless full
        segs = await pg.evaluate('''() => [...document.querySelectorAll('.wheel .wseg')].map(g => [g.querySelector('.wval') ? g.querySelector('.wval').getTotalLength() : 0, g.querySelector('.wtrk').getTotalLength(), g.querySelector('.wnum').textContent])''')
        check(len(segs) == 5 and all(v <= t + .5 for v, t, _ in segs), f'{tag}: ring segments fill within their track ({[x[2] for x in segs]})')
        check(await pg.evaluate("document.getElementById('orb').width") > 0 and await pg.locator('#soulBody .hrow').count() == 1, f'{tag}: soul orb drawn, realm history')
        check(await pg.locator('#soulBody .rpath .rp').count() == 8 and await pg.locator('#soulBody .rp.cur').count() == 1 and await pg.locator('#soulBody .sgtrack .sg').count() == 4,
              f'{tag}: realm path and stage progress are shown')
        check(await pg.locator('#soulBody .advs .adv').count() >= 1, f'{tag}: guidance lists what to improve')
        inside = await pg.evaluate('''() => { const w = document.querySelector('.wheel').getBoundingClientRect();
            return [...document.querySelectorAll('.wheel .elg circle')].every(c => { const r = c.getBoundingClientRect(); return r.top >= w.top - .5 && r.left >= w.left - .5 && r.right <= w.right + .5 && r.bottom <= w.bottom + .5 }) }''')
        check(inside, f'{tag}: every element badge sits inside the wheel (none cut off)')
        await pg.click('#soulBody .rp[data-rp="5"]')
        check('huàshén' in await pg.locator('#soulBody .rpinfo').text_content(), f'{tag}: tapping a realm on the path explains it')
        check(not await overflow(), f'{tag}: Soul Sea, no sideways scroll')
        await shot('soul', True)
        await pg.click('#soulHelp')
        await pg.wait_for_timeout(300)
        check(await pg.locator('details.hlp[data-k="soul"][open]').count() == 1, f'{tag}: "?" opens the help topic')
        await pg.evaluate('mmBack()')
        await pg.wait_for_timeout(200)
        await pg.evaluate('mmBack()')
        await pg.wait_for_timeout(350)

    # tone info sheet
    await pg.click('#toneInfo')
    await pg.wait_for_timeout(450)
    check(await pg.locator('.tone').count() == 5, f'{tag}: tone sheet lists 5 tones')
    check(await pg.locator('details.hlp').count() == 10, f'{tag}: help guide has 10 topics')
    await pg.click('details.hlp[data-k="realm"] summary')
    await pg.wait_for_timeout(150)
    check(await pg.locator('details.hlp[data-k="realm"][open] p').count() >= 3, f'{tag}: a help topic opens')
    rows = await pg.locator('details.hlp[data-k="realm"] .hrow2').all_text_contents()
    check(len(rows) == 12 and 'liànqì' in rows[1] and 'yuánmǎn' in rows[11], f'{tag}: help lists every realm and stage with pinyin and meaning ({len(rows)} rows)')
    check(await pg.locator('details.hlp[data-k="gloss"] .hrow2').count() == 11 and await pg.locator('details.hlp[data-k="soul"] .hrow2').count() == 5,
          f'{tag}: glossary and the five elements are explained one by one')
    await shot('help', False)
    check(await pg.get_attribute('.plink', 'href') == 'https://armstrang.github.io/XueCi/privacy/' and bool((await pg.locator('.plink').text_content()).strip()), f'{tag}: privacy policy link in About')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(200)

    # progress backup -> restore round trip (levels, memory states and goal)
    await pg.evaluate('LM.setRest([2])')
    before = await pg.evaluate('[stats, LM.exportMem(), LM.goal, LM.rest, LM.tests]')
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
    check(await pg.evaluate('[stats, LM.exportMem(), LM.goal, LM.rest, LM.tests]') == before, f'{tag}: restore brings the same progress, memory, goal, meditation days and tests back')
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


async def store_case(browser):
    """Progress store (v1.12): data from v1.11 (localStorage) moves to IndexedDB, survives a cleared localStorage,
    v1.7 data is migrated; word meanings load per language; the backup sheet shows the last backup."""
    tag = 'store'
    errors = []
    blank = HOST + '/no-such-page'   # same origin, so localStorage can be prepared before the app first starts
    ctx = await browser.new_context(viewport={'width': 390, 'height': 800}, locale='en-US', permissions=['clipboard-read', 'clipboard-write'])
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(blank)
    await pg.evaluate("""() => { const t = Math.round((Date.now() - Date.UTC(2026,0,1)) / 6e4) - 1440;
      localStorage.setItem('mm_stats', JSON.stringify({'1:学生': [5, 0, 12]}));
      localStorage.setItem('xc_mem', JSON.stringify({'1:学生': {w: [5, 20, t], i: t - 9000, f: [5, 20, t, 3, 1], s: [5, 20, t, 3, 1]}}));
      localStorage.setItem('xc_log', JSON.stringify([[t, '1:学生', 'f', 3, 30, 0, 0]]));
      localStorage.setItem('xc_onb', '1'); localStorage.setItem('hsk16_theme', JSON.stringify('dark'));
      localStorage.setItem('xc_lvl', JSON.stringify({lv: 2, r: 2, src: 'test', at: t, m: 1, per: [95, 60, 20, 5, 1, 0]})) }""")
    await pg.goto(PAGE)
    await pg.wait_for_timeout(900)
    info = await pg.evaluate('STORE.info()')
    check(info['mode'] == 'idb' and info['from'] == 2, f'{tag}: v1.11 progress is moved into IndexedDB {info}')
    check(await pg.evaluate("LM.has('1:学生') && stats['1:学生'][0] === 5 && document.documentElement.dataset.theme === 'dark'"), f'{tag}: words, records and theme carried over')
    idb = await pg.evaluate("""() => new Promise(res => { const r = indexedDB.open('xueci'); r.onsuccess = () => { const q = r.result.transaction('kv').objectStore('kv').get('xc_schema');
      q.onsuccess = () => res(q.result) } })""")
    check(idb == '3', f'{tag}: IndexedDB holds schema version 3 ({idb})')
    check(await pg.evaluate('LM.stage().testShare') > 0, f'{tag}: a placement test taken in v1.11 counts toward realm progress')
    await pg.evaluate("LM.answer(IDX.get('1:你好'), {q: 'm', ok: true, ms: 3000})")
    await pg.wait_for_timeout(700)
    await pg.goto(blank)
    await pg.evaluate('localStorage.clear()')
    await pg.goto(PAGE)
    await pg.wait_for_timeout(900)
    check(await pg.evaluate("LM.has('1:你好') && LM.has('1:学生') && STORE.info().from === 3 && document.documentElement.dataset.theme === 'dark'"),
          f'{tag}: progress comes back from IndexedDB with localStorage cleared')
    # meanings of another language load when it is chosen
    await pg.evaluate("setLang('vi')")
    await pg.wait_for_timeout(500)
    check(await pg.evaluate("lang === 'vi' && XC.has('vi') && M(IDX.get('1:学生')) === IDX.get('1:学生').vm && !!IDX.get('1:学生').vm"), f'{tag}: Vietnamese meanings loaded on demand')
    await pg.evaluate("setLang('en')")
    await pg.wait_for_timeout(300)
    # backup: a quiet dot after real progress with no backup; the sheet says when the last one was made
    await pg.evaluate("BY[1].slice(0, 40).forEach(d => stats[d.id] = [1, 0, 3]); renderHome()")
    check(await pg.locator('#bkBtn.due').count() == 1, f'{tag}: a dot on Backup when there is progress and no backup')
    await pg.click('#bkBtn')
    await pg.wait_for_timeout(300)
    check(await pg.locator('#bkLast.old').is_visible() and await pg.locator('#bkLast').text_content() == await pg.evaluate('L10.bkNever'), f'{tag}: the sheet says no backup yet')
    await pg.click('.bkopt[data-bk="make"]')
    await pg.wait_for_timeout(400)
    await pg.click('#bkCopy')
    await pg.wait_for_timeout(300)
    check(await pg.evaluate("ls.get('xc_bk', 0) > 0") and await pg.locator('#bkBtn.due').count() == 0, f'{tag}: copying the code records the backup and clears the dot')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(200)
    check('2026' in await pg.locator('#bkLast').text_content() and await pg.locator('#bkLast.old').count() == 0, f'{tag}: the sheet shows the last backup date')
    days = await pg.evaluate("makeCode().then(readCode).then(b => b.days)")
    today = await pg.evaluate('LM.dayOf(LM.now())')
    check(isinstance(days, list) and today in days and today - 1 in days, f'{tag}: the backup code carries the study days')
    await pg.evaluate('mmBack()')
    await ctx.close()
    # v1.7 data: two-number records and the old list of known words
    ctx = await browser.new_context(viewport={'width': 390, 'height': 800}, locale='id-ID')
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(blank)
    await pg.evaluate("""() => { localStorage.setItem('mm_stats', JSON.stringify({'1:学生': [4, 1]}));
      localStorage.setItem('hsk16_known', JSON.stringify(['1:你好', '9:none'])) }""")   # no xc_ key: data from before v1.8
    await pg.goto(PAGE)
    await pg.wait_for_timeout(900)
    check(await pg.evaluate("STORE.info().from === 1 && stats['1:学生'].length === 3 && stats['1:学生'][2] >= 0 && LM.has('1:学生')"), f'{tag}: v1.7 records get a level')
    check(await pg.evaluate("ls.get('mm_stats', {})['1:学生'].length === 3"), f'{tag}: migration is saved')
    await ctx.close()
    check(not errors, f'{tag}: no page errors {errors[:2]}')


async def realm_case(browser):
    """Realms: a v1.9 manual level, the breakthrough (fail, then pass), the weekly lock, a meditation day, welcome back."""
    tag = 'realm'
    errors = []
    # 1) a level picked by hand in v1.9 is no test: 凡人, but the daily plan keeps starting at that level
    ctx = await browser.new_context(viewport={'width': 390, 'height': 800}, locale='en-US')
    await ctx.add_init_script("localStorage.setItem('xc_onb','1');localStorage.setItem('xc_lvl',JSON.stringify({lv:4,src:'manual',at:1000}))")
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(800)
    check(await pg.locator('#curLvName').text_content() == '凡人' and await pg.evaluate('LM.baseLevel()') == 4
          and await pg.evaluate("LM.session(false).filter(i => i.k === 'card').every(i => i.d.l >= 4)"), f'{tag}: a v1.9 manual level keeps steering the plan, realm 凡人')
    await ctx.close()
    # 2) every HSK 1 word solid → 炼气 圆满 → breakthrough
    ctx = await browser.new_context(viewport={'width': 360, 'height': 780}, locale='id-ID')
    await ctx.add_init_script("localStorage.setItem('xc_onb','1')")
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(800)
    await pg.evaluate('''() => { const t = LM.now(), m = {}; for (const d of BY[1]) m[d.id] = {w: [4, 40, t - 60], i: t - 30*1440, k: t - 20*1440,
        m: [4, 40, t - 60, 3, 2], f: [4, 40, t - 60, 3, 2], s: [4, 40, t - 60, 3, 2]};
      LM.replace(m); LM.restoreLevel({lv: 1, src: 'test', at: t - 8*1440, r: 1, hist: [[1, t - 8*1440]]}); renderHome() }''')
    st = await pg.evaluate('LM.stage()')
    check(await pg.evaluate("getComputedStyle(document.getElementById('curLvBtn')).getPropertyValue('--p').trim()") == '100', f'{tag}: the chip ring is full at 圆满')
    check(st['i'] == 3 and await pg.evaluate('LM.btOpen()') and await pg.locator('#curLvBtn.btready').count() == 1, f'{tag}: 圆满 opens the breakthrough {st["share"]:.2f}')
    await pg.click('#curLvBtn')
    await pg.wait_for_timeout(350)
    check(await pg.locator('#btGo').is_enabled(), f'{tag}: breakthrough button in the realm sheet')
    await pg.screenshot(path=os.path.join(OUT, f'{tag}-sheet.png'))
    await pg.click('#btGo')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.screen') == 'bt' and await pg.locator('.btpath').count() == 1, f'{tag}: breakthrough intro 炼气 → 筑基')
    await pg.click('#btBegin')
    await pg.wait_for_timeout(150)
    check(await pg.evaluate('bt.st.items.length') == 20, f'{tag}: 20 breakthrough questions')
    for _ in range(20):
        await pg.click('#btIdk')
        await pg.wait_for_timeout(190)
    await pg.wait_for_timeout(200)
    check(await pg.locator('.btres').count() == 1 and await pg.locator('.btres.pass').count() == 0 and await pg.evaluate('LM.realm()') == 1,
          f'{tag}: a failed breakthrough keeps the realm')
    check(await pg.locator('.btres .wchip').count() >= 10 and await pg.locator('.btres .lockn').count() == 1, f'{tag}: the words to strengthen and the next test date')
    await pg.screenshot(path=os.path.join(OUT, f'{tag}-bt-fail.png'), full_page=True)
    await pg.click('#btPractice')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.screen') == 'quiz' and await pg.evaluate('run.items.length') == 12, f'{tag}: the words to strengthen become a quiz round')
    await pg.evaluate('LM.testsReset()')
    await pg.evaluate("go('bt')")
    await pg.wait_for_timeout(450)
    await pg.click('#btBegin')
    for _ in range(20):
        ans = await pg.evaluate('bt.st.items[bt.st.i].ans')
        await pg.click(f'#btOpts [data-b="{ans}"]')
        await pg.wait_for_timeout(190)
    await pg.wait_for_timeout(450)
    check(await pg.locator('.btres.pass').count() == 1 and await pg.evaluate('LM.realm()') == 2 and await pg.locator('#curLvName').text_content() == '筑基',
          f'{tag}: a passed breakthrough rises to 筑基')
    await pg.screenshot(path=os.path.join(OUT, f'{tag}-bt-pass.png'))
    await pg.evaluate("go('placement')")
    await pg.wait_for_timeout(450)
    check(await pg.locator('#ptBegin').count() == 0 and await pg.locator('#tHome').count() == 1, f'{tag}: the placement test waits a week after a breakthrough')
    await pg.evaluate("go('soul')")
    await pg.wait_for_timeout(500)
    check(await pg.locator('#soulBody .hrow').count() == 2, f'{tag}: realm history lists 炼气 and 筑基')
    adv = await pg.evaluate('LM.advice().items.map(x => x.k)')
    check(len(adv) >= 1 and await pg.locator('#soulBody [data-adv]').count() >= 1, f'{tag}: guidance with actions {adv}')
    await pg.click('#soulBody [data-adv="0"]')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.screen') in ('quiz', 'session'), f'{tag}: a guidance button starts the practice ({await pg.evaluate("state.screen")})')
    await pg.evaluate("go('soul')")
    await pg.wait_for_timeout(450)
    await pg.screenshot(path=os.path.join(OUT, f'{tag}-soul.png'), full_page=True)
    # a meditation day: no plan today
    await pg.evaluate("LM.setRest([new Date().getDay()]); go('home')")
    await pg.wait_for_timeout(450)
    check(await pg.locator('#plan .medz').count() == 1 and await pg.evaluate('LM.plan().todayLeft') == 0, f'{tag}: a meditation day has no plan')
    fits = await pg.evaluate('document.documentElement.scrollHeight <= innerHeight + 1')
    check(fits, f'{tag}: Home with a realm still fits one screen')
    await pg.screenshot(path=os.path.join(OUT, f'{tag}-home.png'))
    await ctx.close()
    # 3) back after three days off: a welcome-back note with how much is still remembered
    ctx = await browser.new_context(viewport={'width': 390, 'height': 800}, locale='en-US')
    await ctx.add_init_script('''localStorage.setItem('xc_onb','1'); const t = Math.round((Date.now() - Date.UTC(2026,0,1)) / 6e4) - 3*1440;
      localStorage.setItem('xc_log', JSON.stringify([[t, '1:学生', 'm', 3, 30, 0, 0]])); localStorage.setItem('xc_mem', JSON.stringify({'1:学生': {w: [5, 10, t], i: t}}))''')
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(1300)
    check(await pg.locator('.toast.long').is_visible() and '3 days' in await pg.locator('.toast').text_content(), f'{tag}: welcome back after 3 days')
    await ctx.close()
    check(not errors, f'{tag}: no page errors {errors[:2]}')


STUB = '''window.__calls = []; window.MMAndroid = {fontScale: () => 1, setBars() {}, setTheme() {}, ttsStatus: () => 'none', speak() {}, stopSpeaking() {},
  openTtsSettings() {}, copyText() {}, shareText() {}, pasteText: () => '', openNotifSettings() {},
  setReminder(...a) { __calls.push(['setReminder', ...a]) }, markStudied() { __calls.push(['markStudied']) }, setRestDays(d) { __calls.push(['setRestDays', d]) },
  notifStatus: () => window.__notif || 'off',
  requestNotifications() { __calls.push(['request']); setTimeout(() => { window.__notif = 'granted'; window.mmNotifResult && mmNotifResult(true) }, 30) }};'''


async def reminder_case(browser):
    """Android bridge (stubbed): the first-start goal sheet suggests a daily reminder, asks for permission, sets it."""
    tag = 'reminder'
    ctx = await browser.new_context(viewport={'width': 360, 'height': 780}, locale='id-ID')
    await ctx.add_init_script(STUB)
    pg = await ctx.new_page()
    errors = []
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(900)
    check(await pg.locator('#gTime').count() == 1 and await pg.get_attribute('[data-rem="1"]', 'aria-pressed') == 'true', f'{tag}: reminder suggested on first start')
    await pg.fill('#gTime', '20:30')
    await pg.dispatch_event('#gTime', 'change')
    await pg.click('[data-wk="3"]')
    await pg.click('#gSave')
    await pg.wait_for_timeout(300)
    calls = await pg.evaluate('__calls')
    check(['setRestDays', '3'] in calls, f'{tag}: meditation days go to Android (no reminder on those days)')
    sets = [c for c in calls if c[0] == 'setReminder']
    check(['request'] in calls and sets and sets[-1][1:4] == [True, 20, 30] and 'Mandarin' in sets[-1][4], f'{tag}: permission asked, reminder set for 20:30 {sets[-1:]}')
    await pg.click('.tile[data-go="quiz"]')
    await pg.wait_for_timeout(400)
    await pg.evaluate(STEP, True)
    check(['markStudied'] in await pg.evaluate('__calls'), f'{tag}: practising today keeps the reminder quiet')
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
        await store_case(browser)
        await realm_case(browser)
        await reminder_case(browser)
        await browser.close()
    print(f'\n{len(failures)} failed' if failures else '\nall checks passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    asyncio.run(main())
