"""Browser smoke test for the built app page (app/src/main/assets/index.html).

    python3 web/build.py && python3 tests/smoke.py

Needs Playwright for Python with Chromium (pip install playwright && playwright install chromium).
Screenshots go to tests/out/ (ignored by git). Exits non-zero on any failed check or page error.
"""
import asyncio
import os
import sys

from playwright.async_api import async_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = 'file://' + os.path.join(ROOT, 'app', 'src', 'main', 'assets', 'index.html')
OUT = os.path.join(ROOT, 'tests', 'out')
failures = []


def check(cond, what):
    print(('ok   ' if cond else 'FAIL ') + what)
    if not cond:
        failures.append(what)


async def run_case(browser, width, locale, theme):
    tag = f'{width}-{locale}-{theme}'
    errors = []
    ctx = await browser.new_context(viewport={'width': width, 'height': 800}, locale=locale, has_touch=True)
    await ctx.add_init_script("localStorage.setItem('hsk16_theme', JSON.stringify('%s'));" % theme)
    pg = await ctx.new_page()
    pg.on('pageerror', lambda e: errors.append(str(e)))
    await pg.goto(PAGE)
    await pg.wait_for_timeout(900)
    overflow = lambda: pg.evaluate('document.documentElement.scrollWidth > innerWidth')
    shot = lambda name: pg.screenshot(path=os.path.join(OUT, f'{tag}-{name}.png'))

    check(await pg.title() == 'XueCi Mandarin', f'{tag}: page title')
    check(await pg.evaluate('state.screen') == 'home' and not await overflow(), f'{tag}: home, no sideways scroll')
    await shot('home')

    # level pills (Home lens)
    await pg.click('.lvpill[data-l="3"]')
    await pg.wait_for_timeout(450)
    check(await pg.evaluate('state.level') == 3, f'{tag}: HSK pill changes level')

    # cards: answer a few, progress is recorded
    await pg.click('.tile[data-go="card"]')
    await pg.wait_for_timeout(400)
    for ok in (True, True, False, True):
        await pg.click('#fcYes' if ok else '#fcNo')
        await pg.wait_for_timeout(40)
    check(await pg.evaluate('Object.keys(stats).length') >= 3, f'{tag}: card answers are recorded')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # quiz: type dropdown, answer, unit menu in the header
    await pg.click('.tile[data-go="quiz"]')
    await pg.wait_for_timeout(400)
    await shot('quiz')
    await pg.click('#qTypeBtn')
    await pg.wait_for_timeout(250)
    await pg.click('.qtrow[data-qt="hanzi"]')
    await pg.wait_for_timeout(200)
    check(await pg.evaluate('qz.type') == 'hanzi', f'{tag}: quiz type dropdown')
    await pg.click('.opts button >> nth=0')
    await pg.wait_for_timeout(200)
    check(await pg.evaluate('qz.answered') is True, f'{tag}: quiz answer')
    await pg.click('#ubtn')
    await pg.wait_for_timeout(250)
    check(await pg.locator('#uMenu').is_visible(), f'{tag}: unit menu opens')
    check(await pg.evaluate('mmBack()') is True and await pg.evaluate('state.screen') == 'quiz', f'{tag}: back closes the menu first')
    frow = await pg.evaluate('''() => { const f = document.querySelector('#scr-focus .frow').getBoundingClientRect();
        return [...document.querySelectorAll('#scr-focus .frow > *')].every(k => { const r = k.getBoundingClientRect(); return r.right <= f.right + .5 && r.left >= f.left - .5 }) }''')
    check(frow, f'{tag}: header controls fit inside the capsule')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # list
    await pg.click('.tile[data-go="list"]')
    await pg.wait_for_timeout(400)
    check(await pg.locator('.item').count() > 10 and not await overflow(), f'{tag}: list shows words')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # stats: lens on the HSK selector, tap changes level
    await pg.click('#hero')
    await pg.wait_for_timeout(450)
    await shot('stats')
    check(await pg.locator('#scr-stats .lvseg .lens').count() == 1, f'{tag}: stats HSK selector has the lens')
    await pg.click('#stLevels .lvpill[data-sl="5"]')
    await pg.wait_for_timeout(300)
    check(await pg.evaluate('stLevel') == 5, f'{tag}: stats level pill')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(350)

    # tone info sheet
    await pg.click('#toneInfo')
    await pg.wait_for_timeout(450)
    check(await pg.locator('.tone').count() == 5, f'{tag}: tone sheet lists 5 tones')
    check(await pg.get_attribute('.plink', 'href') == 'https://armstrang.github.io/XueCi/privacy/' and bool((await pg.locator('.plink').text_content()).strip()), f'{tag}: privacy policy link in About')
    await pg.evaluate('mmBack()')
    await pg.wait_for_timeout(200)

    # progress backup -> restore round trip
    before = await pg.evaluate('JSON.stringify(stats)')
    await pg.click('#hero')
    await pg.wait_for_timeout(450)
    await pg.click('#bkMakeBtn')
    await pg.wait_for_timeout(500)
    code = await pg.input_value('#bkCode')
    check(code.startswith('XUECI'), f'{tag}: backup code is made')
    await pg.evaluate('mmBack()')
    await pg.click('#bkRestoreBtn')
    await pg.wait_for_timeout(300)
    await pg.fill('#bkCode', 'not a code')
    await pg.click('#bkCheck')
    await pg.wait_for_timeout(150)
    check(await pg.locator('#bkApply').count() == 0, f'{tag}: a wrong code is refused')
    await pg.fill('#bkCode', 'XueCi backup:\n' + code)
    await pg.click('#bkCheck')
    await pg.wait_for_timeout(300)
    await pg.click('#bkApply')
    await pg.wait_for_timeout(1300)
    check(await pg.evaluate('JSON.stringify(stats)') == before, f'{tag}: restore brings the same progress back')

    # language switch
    await pg.click('#langBtn')
    await pg.wait_for_timeout(200)
    await pg.click('.lgrow[data-lang="vi"]')
    await pg.wait_for_timeout(300)
    check('Kiểm tra' in await pg.locator('.tiles').text_content(), f'{tag}: switch to Vietnamese')

    check(await pg.evaluate('mmBack()') is False, f'{tag}: back on Home leaves the app')
    check(not errors, f'{tag}: no page errors {errors[:2]}')
    await ctx.close()


async def main():
    os.makedirs(OUT, exist_ok=True)
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        for width, locale, theme in ((360, 'id-ID', 'light'), (412, 'en-US', 'dark'), (320, 'th-TH', 'black'), (1280, 'vi-VN', 'auto')):
            await run_case(browser, width, locale, theme)
        await browser.close()
    print(f'\n{len(failures)} failed' if failures else '\nall checks passed')
    sys.exit(1 if failures else 0)


asyncio.run(main())
