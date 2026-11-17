"""The speaking bank (HSKK practice and mock tests) for the app, from content/speak/.

Called by make_assets.py; on its own: python3 mobile/tool/make_speak.py (prints the counts, writes nothing).

Sources, edited by hand:
  content/speak/1-dasar.txt, 2-menengah.txt, 3-lanjutan.txt   one item per line under a section:
      #R  repeat a sentence (Dasar)          #S  listen, then retell (Menengah, Lanjutan)
      #T  read aloud                         #Q  question | keyword keyword keyword
      #R-latihan  extra repeat practice (sentences from the word list)
  content/speak/questions.tsv   question <tab> id <tab> en <tab> th <tab> vi

Out (assets/data/speak.json): {"L": [level 1..3 → {"r": [...], "s": [...], "t": [...], "q": [...], "x": [...]}]}
  an item from the word list is {"w": "<level>:<hanzi>"} (the app takes the sentence, its pinyin and translations
  from the word); others are {"zh", "py", "kw"?, "tr"?}. Pinyin of hand-written text is read here from the word
  list: the longest words first, then the readings of single characters, then the tone changes of 一 and 不.
Keywords of a retold text: up to five words of the level's own band in it (Dasar HSK 3, Menengah HSK 4,
Lanjutan HSK 5–6), content words first.
"""
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'content', 'speak')
FILES = ['1-dasar.txt', '2-menengah.txt', '3-lanjutan.txt']
BAND = {1: (3, 3), 2: (4, 4), 3: (5, 6)}  # the words that make a level's own vocabulary
TOP = {1: 4, 2: 5, 3: 6}                    # nothing harder than this, ever (a few common words a band up are fine)
PUNCT = {'，': ',', '。': '.', '？': '?', '！': '!', '、': ',', '：': ':', '；': ';', '“': '"', '”': '"', '"': '"',
         '（': '(', '）': ')', '…': '…', '—': '—', '·': '·'}
NEUTRAL = {'的': 'de', '了': 'le', '吗': 'ma', '呢': 'ne', '吧': 'ba', '着': 'zhe', '得': 'de', '地': 'de', '们': 'men',
           '么': 'me', '啊': 'a'}
CONTENT_POS = ('n', 'v', 'a', 'i', 'l', 'vn', 'an', 'nz', 'ns')
NAMES = {'小李': 'Xiǎo Lǐ', '小王': 'Xiǎo Wáng', '小张': 'Xiǎo Zhāng', '小刘': 'Xiǎo Liú', '小陈': 'Xiǎo Chén',
         '老张': 'Lǎo Zhāng', '王丽': 'Wáng Lì', '小明': 'Xiǎomíng', '山田': 'Shāntián', '王教授': 'Wáng jiàoshòu',
         '李阿姨': 'Lǐ āyí', '王老师': 'Wáng lǎoshī'}
# words of another reading that the shortest split would pick wrongly, and the same syllables split or whole (no harm)
NOT_WORDS = {'个人'}
EXEMPT = {'学会', '才能', '好不', '个人'}


def is_han(c):
    return '一' <= c <= '鿿' or '㐀' <= c <= '䶿'


def tone(syl):
    for c in unicodedata.normalize('NFD', syl):
        o = ord(c)
        if o == 0x304:
            return 1
        if o == 0x301:
            return 2
        if o == 0x30C:
            return 3
        if o == 0x300:
            return 4
    return 5


def retone(syl, t):
    """the same syllable with tone t (1–4, 5 = neutral)"""
    base = ''.join(c for c in unicodedata.normalize('NFD', syl) if ord(c) not in (0x304, 0x301, 0x30C, 0x300))
    base = unicodedata.normalize('NFC', base)
    if t == 5:
        return base
    mark = {1: '̄', 2: '́', 3: '̌', 4: '̀'}[t]
    low = base.lower()
    if 'a' in low:
        i = low.index('a')
    elif 'e' in low:
        i = low.index('e')
    elif 'ou' in low:
        i = low.index('o')
    else:
        i = max(low.rfind(v) for v in 'iouü')
    return unicodedata.normalize('NFC', base[:i + 1] + mark + base[i + 1:])


class Reader:
    def __init__(self, vocab):
        self.words = {}
        self.level = {}
        self.pos = {}
        chars = {}
        for d in vocab:
            h, s = d['h'], d['s']
            if len(h) != len(s) or not all(is_han(c) for c in h):
                continue
            self.words.setdefault(h, s)
            self.level.setdefault(h, d['l'])
            self.pos.setdefault(h, d.get('g') or '')
            for c, x in zip(h, s):
                k = chars.setdefault(c, {})
                k[x] = k.get(x, 0) + (3 if len(h) == 1 else 1)
        self.char = {c: max(v, key=v.get) for c, v in chars.items()}
        for w in NOT_WORDS:
            self.words.pop(w, None)
        for w, py in NAMES.items():
            self.words[w] = [py]
            self.level[w] = 0
        self.maxlen = max(len(w) for w in self.words)

    def cut(self, text):
        """the text as (piece, syllables or None, level or 0): the fewest words (each run of hanzi on its own), words
        past HSK 6 only when nothing else fits (都|会, not 都会 'metropolis'), ties to the easier words"""
        out, i = [], 0
        while i < len(text):
            if not is_han(text[i]):
                out.append((text[i], None, 0))
                i += 1
                continue
            j = i
            while j < len(text) and is_han(text[j]):
                j += 1
            out += self._run(text[i:j])
            i = j
        return out

    def _run(self, s):
        n = len(s)
        best = [None] * (n + 1)
        best[0] = (0.0, 0, None)
        for i in range(n):
            if best[i] is None:
                continue
            for k in range(1, min(self.maxlen, n - i) + 1):
                w = s[i:i + k]
                if k > 1 and w not in self.words:
                    continue
                l = self.level.get(w, 0)
                cost = best[i][0] + 1 + (1.2 if l >= 7 else 0) + (0.5 if w not in self.words else 0)
                key = (cost, best[i][1] + l)
                if best[i + k] is None or key < best[i + k][:2]:
                    best[i + k] = (cost, best[i][1] + l, i)
        out, j = [], n
        while j > 0:
            i = best[j][2]
            w = s[i:j]
            if w in self.words:
                out.append((w, list(self.words[w]), self.level[w]))
            else:
                out.append((w, [self.char.get(w, '?')], 0))
            j = i
        return out[::-1]

    def pinyin(self, text):
        toks = self.cut(text)
        # neutral particles standing alone; 一 and 不 change their tone before the next syllable
        flat = []
        for w, s, _ in toks:
            if s is None:
                flat.append((w, None, None))
                continue
            if len(w) == 1 and w in NEUTRAL:
                s = [NEUTRAL[w]]
            if w == '了' and flat and flat[-1][0] == '不':  # 吃不了: bu liǎo
                flat[-1] = ('不', ['bu'], None)
                s = ['liǎo']
            if w == '儿' and flat and flat[-1][1]:  # erhua: 一会儿 yíhuìr
                pw, ps, _ = flat[-1]
                flat[-1] = (pw + w, ps[:-1] + [ps[-1] + 'r'], None)
                continue
            if w == '们' and flat and flat[-1][1]:
                flat[-1] = (flat[-1][0] + w, flat[-1][1] + ['men'], None)
                continue
            flat.append((w, s, None))
        nxt_tone = [None] * len(flat)
        nt = None
        for i in range(len(flat) - 1, -1, -1):
            w, s, _ = flat[i]
            nxt_tone[i] = nt
            if s:
                nt = tone(s[0])
            elif w not in '，。？！、：；…':
                pass
            else:
                nt = None
        words = []
        for i, (w, s, _) in enumerate(flat):
            if s is None:
                words.append(PUNCT.get(w, w))
                continue
            if len(w) == 1 and w in '一不' and nxt_tone[i] and s != ['bu']:
                n = nxt_tone[i]
                if w == '不':
                    s = ['bú' if n == 4 else 'bù']
                elif n in (1, 2, 3):
                    s = ['yì']
                elif n == 4:
                    s = ['yí']
            words.append(join(s))
        # spaces between words, none before punctuation; capitals at the start of each sentence
        out, cap, quote = '', True, False
        for x in words:
            if x == '"':
                if quote:
                    out = out.rstrip() + '" '
                else:
                    out += '"'
                quote = not quote
                continue
            if x in ('.', ',', '?', '!', ':', ';', '…', '—', ')'):
                out = out.rstrip() + x + ' '
                if x in '.?!':
                    cap = True
                continue
            if cap and x and x[0].isalpha():
                x = x[0].upper() + x[1:]
                cap = False
            out += x + ' '
        return re.sub(r'\s+', ' ', out).strip()

    def keywords(self, text, lo, hi, n=5):
        seen, first, rest = set(), [], []
        for w, s, l in self.cut(text):
            if s is None or not (lo <= l <= hi) or w in seen:
                continue
            seen.add(w)
            (first if self.pos.get(w, '').startswith(CONTENT_POS) and len(w) > 1 else rest).append(w)
        return (first + rest)[:n]


def join(syls):
    """a word's syllables written together, with an apostrophe before a, e, o inside it (kě'ài, Xī'ān)"""
    out = ''
    for i, x in enumerate(syls):
        if i and x and unicodedata.normalize('NFD', x)[0].lower() in 'aeo':
            out += "'"
        out += x
    return out


def read_bank(path):
    sec, out = None, {}
    with open(path, encoding='utf8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                sec = line
                out.setdefault(sec, [])
                continue
            out[sec].append(line)
    return out


def build(vocab):
    rd = Reader(vocab)
    by_z = {}
    for d in vocab:
        if d.get('z') and d['l'] <= 6:
            by_z.setdefault(d['z'], f"{d['l']}:{d['h']}")
    qtr = {}
    with open(os.path.join(SRC, 'questions.tsv'), encoding='utf8') as f:
        for line in f:
            p = line.rstrip('\n').split('\t')
            if len(p) == 5:
                qtr[p[0]] = dict(zip(['id', 'en', 'th', 'vi'], p[1:]))
    levels, problems = [], []
    for li, name in enumerate(FILES, start=1):
        src = read_bank(os.path.join(SRC, name))
        lo, hi = BAND[li]
        lv = {'r': [], 's': [], 't': [], 'q': [], 'x': []}
        for sec, items in src.items():
            k = {'#R': 'r', '#S': 's', '#T': 't', '#Q': 'q', '#R-latihan': 'x'}[sec]
            for raw in items:
                if k in 'rx' and raw in by_z:
                    lv[k].append({'w': by_z[raw]})
                    continue
                if k == 'q':
                    zh, _, kw = raw.partition('|')
                    zh = zh.strip()
                    it = {'zh': zh, 'py': rd.pinyin(zh), 'kw': kw.split()}
                    if zh in qtr:
                        it['tr'] = qtr[zh]
                    else:
                        problems.append(f'{name}: no translation for {zh}')
                else:
                    it = {'zh': raw, 'py': rd.pinyin(raw)}
                    if k == 's':
                        it['kw'] = rd.keywords(raw, lo, hi)
                lv[k].append(it)
                hard = [w for w, s, l in rd.cut(it['zh']) if s and l > TOP[li] and len(w) > 1 and w not in EXEMPT]
                if hard:
                    problems.append(f'{name} {k}: {it["zh"][:12]}… uses {hard}')
                if '?' in it['py'].split():
                    problems.append(f'{name}: no reading in {it["zh"][:12]}')
        levels.append(lv)
    return {'L': levels}, problems


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(ROOT, 'content', 'vocab.json'), encoding='utf8') as f:
        vocab = json.load(f)
    bank, problems = build(vocab)
    for i, lv in enumerate(bank['L'], 1):
        print(i, {k: len(v) for k, v in lv.items()})
    for p in problems:
        print('  !', p)


if __name__ == '__main__':
    main()
