"""Build XueCi Mandarin into one self-contained HTML file.

    python3 web/build.py

Pieces (web/src):
  base.css.html   layout and base styles
  app.html        markup + app logic (placeholders __I18N__, __I18N_LEARN__, __LEARN__, __SOUL__ and __DATA__)
  i18n.js         interface text in Indonesian, English, Thai and Vietnamese
  i18n-learn.js   text for guided learning (daily plan, goals, cards, quiz, insights), same four languages
  learn.js        learning engine: memory model (FSRS), answer log, goals and daily plan, question choice, realms
  soul.js         Soul Sea page: the word-network orb (canvas) and the five-element wheel (SVG)
  glass.css.html  the Liquid Glass look (overrides base styles)
  glass.js.html   Liquid Glass interactions: HSK lens, screen zoom, theme reveal, haptics
Data: web/data/vocab.json (HSK 1-6, one word per line).

Writes:
  app/src/main/assets/index.html   the page inside the Android app; fonts come from assets/fonts/ (web/make_fonts.py)
  web/dist/xueci-mandarin.html     the same page for the web (no doctype line); fonts come from Google Fonts
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'web', 'src')


def read(*parts):
    with open(os.path.join(ROOT, *parts), encoding='utf8') as f:
        return f.read()


def replace_once(text, old, new):
    assert text.count(old) == 1, f'expected exactly one {old!r}'
    return text.replace(old, new)


base = read('web', 'src', 'base.css.html')
app = replace_once(read('web', 'src', 'app.html'), '__I18N__', read('web', 'src', 'i18n.js'))
app = replace_once(app, '__I18N_LEARN__', read('web', 'src', 'i18n-learn.js'))
app = replace_once(app, '__LEARN__', read('web', 'src', 'learn.js'))
app = replace_once(app, '__SOUL__', read('web', 'src', 'soul.js'))
page = base + '\n' + app

# Liquid Glass look goes right after the base styles, so its rules win.
i = page.index('</style>') + len('</style>')
page = page[:i] + '\n' + read('web', 'src', 'glass.css.html') + page[i:]
# Static background glow behind everything.
page = replace_once(page, '<div class="wrap">', '<div class="liquid-bg" aria-hidden="true"></div>\n<div class="wrap">')
# Fourth theme (true black), declared before the app restores the saved theme.
page = replace_once(page, '<script>\nconst DATA = __DATA__;',
                    "<script>window.MM_THEMES=['auto','light','dark','black'];</script>\n<script>\nconst DATA = __DATA__;")
page = page.rstrip() + '\n' + read('web', 'src', 'glass.js.html')

# Text follows the phone's text size: every font size written in px is multiplied by --fs (set from Android's
# font scale by the first script in base.css.html). Display sizes (26px and up: big hanzi, the ring percentage)
# use --fsd, which grows half as much, so large text never pushes the layout apart.
def scale_font(m):
    prop, val = m.group(1), m.group(2)
    big = val.startswith('clamp') or float(val[:-2]) >= 26
    return f"{prop}:calc({val}*var({'--fsd' if big else '--fs'},1))"
page = re.sub(r'(font-size|font):\s*(clamp\([^)]*\)|[\d.]+px)', scale_font, page)

data = json.loads(read('web', 'data', 'vocab.json'))
page = replace_once(page, '__DATA__', json.dumps(data, ensure_ascii=False, separators=(',', ':')))

# The app ships its own fonts: swap the Google Fonts links for local @font-face rules.
GOOGLE_FONTS = [l for l in page.splitlines() if 'fonts.googleapis.com' in l]
assert len(GOOGLE_FONTS) == 2, 'expected the preconnect + stylesheet links to Google Fonts'
app_page = page
for line in GOOGLE_FONTS:
    app_page = replace_once(app_page, line + '\n', '')
app_page = replace_once(app_page, '</title>', '</title>\n<style>\n' + read('web', 'fonts', 'fonts.css') + '</style>')
with open(os.path.join(ROOT, 'web', 'fonts', 'charset.txt'), encoding='utf8') as f:
    covered = set(f.read().strip())
han = {c for c in app_page if 0x3400 <= ord(c) <= 0x9FFF or 0xF900 <= ord(c) <= 0xFAFF}
missing = ''.join(sorted(han - covered))
if missing:
    print(f'WARNING: the bundled Chinese fonts lack {len(missing)} characters ({missing[:40]}...). Run python3 web/make_fonts.py')

dist = os.path.join(ROOT, 'web', 'dist')
os.makedirs(dist, exist_ok=True)
with open(os.path.join(dist, 'xueci-mandarin.html'), 'w', encoding='utf8') as f:
    f.write(page)
assets = os.path.join(ROOT, 'app', 'src', 'main', 'assets')
os.makedirs(assets, exist_ok=True)
with open(os.path.join(assets, 'index.html'), 'w', encoding='utf8') as f:
    f.write('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">\n' + app_page)
print(f'built {len(page.encode()) / 1e6:.2f} MB, {len(data)} words')
