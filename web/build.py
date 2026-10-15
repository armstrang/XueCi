"""Build XueCi Mandarin into one self-contained HTML file.

    python3 web/build.py

Pieces (web/src):
  base.css.html   layout and base styles
  app.html        markup + app logic (placeholders __I18N__ and __DATA__)
  i18n.js         interface text in Indonesian, English, Thai and Vietnamese
  glass.css.html  the Liquid Glass look (overrides base styles)
  glass.js.html   Liquid Glass interactions: HSK lens, screen zoom, theme reveal, haptics
Data: web/data/vocab.json (HSK 1-6, one word per line).

Writes:
  app/src/main/assets/index.html   the page inside the Android app
  web/dist/xueci-mandarin.html   the same page for the web (no doctype line)
"""
import json
import os

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

data = json.loads(read('web', 'data', 'vocab.json'))
page = replace_once(page, '__DATA__', json.dumps(data, ensure_ascii=False, separators=(',', ':')))

dist = os.path.join(ROOT, 'web', 'dist')
os.makedirs(dist, exist_ok=True)
with open(os.path.join(dist, 'xueci-mandarin.html'), 'w', encoding='utf8') as f:
    f.write(page)
assets = os.path.join(ROOT, 'app', 'src', 'main', 'assets')
os.makedirs(assets, exist_ok=True)
with open(os.path.join(assets, 'index.html'), 'w', encoding='utf8') as f:
    f.write('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">\n' + page)
print(f'built {len(page.encode()) / 1e6:.2f} MB, {len(data)} words')
