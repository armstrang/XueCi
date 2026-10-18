"""Build XueCi Mandarin.

    python3 web/build.py

Sources (web/src):
  base.css.html    <title>, the text-size script and the base styles
  glass.css.html   Liquid Glass look; goes right after the base styles so its rules win
  app.html         markup of every screen and sheet
  store.js         progress store: IndexedDB (memory first) with a localStorage safety copy, schema version + migrations
  boot.js          start-up: opens the store, loads the word data, runs the migrations, then runs the app
  i18n.js, i18n-app.js, i18n-learn.js   interface text in Indonesian, English, Thai and Vietnamese
  app/*.js         the app, one file per part, in the order of APP below
  learn.js         learning engine (LM): memory model, answer log, plan, question choice, realms
  soul.js          Soul Sea orb and five-element wheel (SOUL)
  glass.js         Liquid Glass interactions: HSK lens, screen zoom, theme reveal, haptics
Data: web/data/vocab.json (canonical, one word per line) is split into data/core.json (everything but the meanings)
and data/<lang>.json (meaning + sentence translation per word, same order), which the page loads beside itself.

Writes:
  app/src/main/assets/index.html + app/src/main/assets/data/   the app (fonts from assets/fonts/, web/make_fonts.py)
  web/dist/xueci-mandarin.html + web/dist/data/                the same for the web (fonts from Google Fonts)
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'web', 'src')

# The app script: interface text, the shared core, the engine, then one file per screen or feature.
APP = ['i18n.js', 'i18n-app.js', 'i18n-learn.js',
       'app/core.js', 'app/mastery.js', 'learn.js', 'soul.js',
       'app/state.js', 'app/screens.js', 'app/home.js', 'app/pickers.js', 'app/language.js', 'app/list.js',
       'app/runner.js', 'app/cards.js', 'app/quiz.js', 'app/summary.js', 'app/stats.js', 'app/info.js',
       'app/speech.js', 'app/backup.js', 'app/plan.js', 'app/goal.js', 'app/realm.js', 'app/placement.js',
       'app/breakthrough.js', 'app/soul-page.js', 'app/reminder.js', 'app/notes.js', 'app/keys.js', 'app/start.js']

# vocab.json fields: everything but the meanings goes to core.json; meanings per study language go to <lang>.json.
CORE = ['l', 'n', 'u', 'h', 'p', 's', 'z', 'zp', 'f', 'g', 'pm']
LANG_COLS = {'id': ('m', 't'), 'en': ('em', 'et'), 'th': ('hm', 'ht'), 'vi': ('vm', 'vt')}


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding='utf8') as f:
        return f.read()


def replace_once(text, old, new):
    assert text.count(old) == 1, f'expected exactly one {old!r}'
    return text.replace(old, new)


def script_text(name):
    s = read('web', 'src', *name.split('/'))
    assert '</script' not in s.lower(), f'{name} must not contain </script>'
    return f'/* ---- {name} ---- */\n' + s.rstrip() + '\n'


def data_files():
    words = json.loads(read('web', 'data', 'vocab.json'))
    for d in words:
        # usable in the placement test: a short first meaning (Indonesian, as before the data was split)
        d['pm'] = 1 if len(d['m'].split(';')[0]) <= 28 else 0
    pack = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':'))
    files = {'core.json': pack({'cols': CORE, 'rows': [[d.get(k) for k in CORE] for d in words]})}
    for lang, (m, t) in LANG_COLS.items():
        files[f'{lang}.json'] = pack({'lang': lang, 'rows': [[d[m], d[t]] for d in words]})
    return words, files


base = read('web', 'src', 'base.css.html')
markup = read('web', 'src', 'app.html')
app_js = ''.join(script_text(n) for n in APP)
boot_js = script_text('store.js') + script_text('boot.js')
glass_js = script_text('glass.js')
page = (base + '\n' + markup.rstrip() + '\n'
        + "<script>window.MM_THEMES=['auto','light','dark','black'];</script>\n"
        + '<script>\n' + boot_js + '</script>\n'
        + '<script type="text/x-xueci" id="xc-app">\n' + app_js + '</script>\n'
        + '<script type="text/x-xueci" id="xc-glass">\n' + glass_js + '</script>\n')

# Liquid Glass look goes right after the base styles, so its rules win; a static glow sits behind everything.
i = page.index('</style>') + len('</style>')
page = page[:i] + '\n' + read('web', 'src', 'glass.css.html') + page[i:]
page = replace_once(page, '<div class="wrap">', '<div class="liquid-bg" aria-hidden="true"></div>\n<div class="wrap">')

# Text follows the phone's text size: every font size written in px is multiplied by --fs (set from Android's
# font scale by the first script in base.css.html). Display sizes (26px and up: big hanzi, the ring percentage)
# use --fsd, which grows half as much, so large text never pushes the layout apart.
def scale_font(m):
    prop, val = m.group(1), m.group(2)
    big = val.startswith('clamp') or float(val[:-2]) >= 26
    return f"{prop}:calc({val}*var({'--fsd' if big else '--fs'},1))"
page = re.sub(r'(font-size|font):\s*(clamp\([^)]*\)|[\d.]+px)', scale_font, page)

words, files = data_files()

# The app ships its own fonts: swap the Google Fonts links for local @font-face rules.
GOOGLE_FONTS = [l for l in page.splitlines() if 'fonts.googleapis.com' in l]
assert len(GOOGLE_FONTS) == 2, 'expected the preconnect + stylesheet links to Google Fonts'
app_page = page
for line in GOOGLE_FONTS:
    app_page = replace_once(app_page, line + '\n', '')
app_page = replace_once(app_page, '</title>', '</title>\n<style>\n' + read('web', 'fonts', 'fonts.css') + '</style>')
with open(os.path.join(ROOT, 'web', 'fonts', 'charset.txt'), encoding='utf8') as f:
    covered = set(f.read().strip())
shown = app_page + ''.join(files.values())
han = {c for c in shown if 0x3400 <= ord(c) <= 0x9FFF or 0xF900 <= ord(c) <= 0xFAFF}
missing = ''.join(sorted(han - covered))
if missing:
    print(f'WARNING: the bundled Chinese fonts lack {len(missing)} characters ({missing[:40]}...). Run python3 web/make_fonts.py')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf8') as f:
        f.write(text)


assets = os.path.join(ROOT, 'app', 'src', 'main', 'assets')
dist = os.path.join(ROOT, 'web', 'dist')
write(os.path.join(dist, 'xueci-mandarin.html'), page)
write(os.path.join(assets, 'index.html'),
      '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">\n' + app_page)
for name, text in files.items():
    write(os.path.join(assets, 'data', name), text)
    write(os.path.join(dist, 'data', name), text)
size = lambda s: len(s.encode()) / 1e6
print(f'built page {size(app_page):.2f} MB + data {size("".join(files.values())):.2f} MB '
      f'(core {size(files["core.json"]):.2f}, id {size(files["id.json"]):.2f}), {len(words)} words')
