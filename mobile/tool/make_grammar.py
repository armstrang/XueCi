"""The grammar book: content/grammar/<level>.txt → the points, each with example sentences found among the words'
own example sentences (so they come with pinyin and every translation), and the sentences it practises on.

A point: "= cat | 中文名 | formula", "k: a|b|c" (words that show the point: a sentence must hold one of them, and in
practice the one found is the gap), "m: regex" (optional: the sentence must match it too), one line of explanation
per language ("id: …", "en: …", "th: …", "vi: …"), and optional own examples "ex: 汉字 | pinyin | id | en | th | vi".
A point without k and m is read only (no sentences are looked for).

build(words) → (public, sealed, problems): public = HSK 1–6, sealed = 7–9 (it goes into s0.bin with the band).
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, 'content', 'grammar')
LANGS = ['id', 'en', 'th', 'vi']
CATS = 'WVPNARCUSFKE'
N_EX = 3  # examples shown
N_POOL = 40  # sentences kept for practice


BOOKS = {'h2': range(1, 7), 'yct': range(1, 5), 'bct': range(1, 3)}


def books(val, where):
    """"h2 2, yct 3, bct A" → {'h2': 2, 'yct': 3, 'bct': 1} (BCT A = 1, B = 2)"""
    out = {}
    for x in val.split(','):
        b, _, l = x.strip().partition(' ')
        l = {'A': '1', 'B': '2'}.get(l.strip(), l.strip()) if b == 'bct' else l.strip()
        assert b in BOOKS and l.isdigit() and int(l) in BOOKS[b], f'{where}: book level {x}'
        out[b] = int(l)
    return out


def parse(path, level):
    pts, cur = [], None
    with open(path, encoding='utf8') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            if line.startswith('= '):
                parts = [p.strip() for p in line[2:].split('|')]
                assert len(parts) == 3 and parts[0] in CATS, f'{path}:{n}: {line}'
                cur = {'l': level, 'c': parts[0], 'zh': parts[1], 'f': parts[2], 'k': [], 'x': {}, 'own': []}
                pts.append(cur)
                continue
            key, _, val = line.partition(':')
            val = val.strip()
            assert cur is not None, f'{path}:{n}'
            if key == 'k':
                cur['k'] = [w for w in val.split('|') if w]
            elif key == 'm':
                re.compile(val)
                cur['m'] = val
            elif key in LANGS:
                cur['x'][key] = val
            elif key == 'ex':
                e = [p.strip() for p in val.split('|')]
                assert len(e) == 6, f'{path}:{n}: ex needs 6 parts'
                cur['own'].append(e)
            elif key == 'i':
                cur['id'] = val
            elif key == 'n':
                e = [p.strip() for p in val.split('|')]
                assert len(e) == 5, f'{path}:{n}: n needs pinyin + 4 languages'
                cur['n'] = {'py': e[0], **dict(zip(LANGS, e[1:]))}
            elif key == 'fs':
                cur['fs'] = val
            elif key == 'w':
                e = [p.strip() for p in val.split('|')]
                assert len(e) == 4, f'{path}:{n}: w needs 4 languages'
                cur['w'] = dict(zip(LANGS, e))
            elif key == 'e':
                cur.setdefault('e', []).append((val, f'{path}:{n}'))
            elif key == 't':
                assert val.isdigit() and 1 <= int(val) <= 10, f'{path}:{n}: t is a stage 1-10'
                cur['t'] = int(val)
            elif key == 'v':
                cur['v'] = books(val, f'{path}:{n}')
            elif key == 'l':
                assert level == 0 and val.isdigit() and 1 <= int(val) <= 6, f'{path}:{n}: l only in x.txt, 1-6'
                cur['l'] = int(val)
            else:
                raise AssertionError(f'{path}:{n}: {line}')
    for i, p in enumerate(pts):
        assert set(p['x']) == set(LANGS), f'{path}: {p["zh"]} lacks {set(LANGS) - set(p["x"])}'
        assert 't' in p, f'{path}: {p["zh"]} has no stage (t:)'
        if level == 0:
            # x.txt: points of the other books only (not in the HSK 3.0 book): own id, base level, books
            assert p.get('id', '').startswith('x-') and p['l'] and p.get('v'), f'{path}: {p["zh"]} needs i: x-…, l: and v:'
            p['nh'] = 1
        else:
            assert level <= 6 or not p.get('v'), f'{path}: {p["zh"]}: the advanced band belongs to no other book'
        p.setdefault('id', f'{level}-{i + 1:03d}')
    ids = [p['id'] for p in pts]
    assert len(set(ids)) == len(ids), f'{path}: an id twice'
    return pts


# ---------------------------------------------------------------- v1.6.1: names, formulas, examples word by word
HZ = re.compile(r'[㐀-鿿]')
TONES = {c: (b, t) for b, row in zip('aeiouü', ['āáǎà', 'ēéěè', 'īíǐì', 'ōóǒò', 'ūúǔù', 'ǖǘǚǜ']) for t, c in enumerate(row, 1)}


def plain_py(x):
    return ''.join(TONES[c][0] if c in TONES else c for c in x.lower()).replace('ü', 'v')


def terms():
    out, kind = {}, 'f'
    with open(os.path.join(DIR, 'terms.txt'), encoding='utf8') as f:
        for line in f:
            if line.startswith('# ---- small words'):
                kind = 'w'
            if not line.strip() or line.startswith('#'):
                continue
            e = [p.strip() for p in line.rstrip('\n').split('|')]
            assert len(e) == 6, line
            out[e[0]] = {'py': e[1], 'kind': kind, **dict(zip(LANGS, e[2:]))}
    return out


def short(m):
    """the first meaning of a word-list meaning: up to the first ';'"""
    m = re.split(r'[;；]', m or '')[0].strip()
    return m


def syllables(words):
    out = set()
    for d in words:
        for x in d.get('s') or []:
            out.add(plain_py(re.sub(r'[^a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]', '', x)))
    out.discard('')
    # syllables without an initial, rare in the word list's own pinyin (interjections)
    out |= {'a', 'o', 'e', 'ai', 'ei', 'ao', 'ou', 'an', 'en', 'ang', 'eng', 'er', 'ng', 'm', 'hm', 'n', 'yo'}
    return out


def split_py(word, syl):
    """a written pinyin word ("méiyǒu") into syllables, by the syllables the word list knows"""
    w = re.sub(r"[^a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜü]", '', word, flags=re.I)
    pw = plain_py(w)
    n = len(pw)
    best = [None] * (n + 1)
    best[0] = []
    for i in range(n):
        if best[i] is None:
            continue
        for j in range(i + 1, min(n, i + 6) + 1):
            if pw[i:j] in syl or (pw[i:j] == 'r' and i > 0):
                cand = best[i] + [(i, j)]
                if best[j] is None or len(cand) < len(best[j]):
                    best[j] = cand
    if best[n] is None:
        return None
    return [w[i:j] for i, j in best[n]]


def align(tokens, py, syl):
    """pinyin per token: the sentence's pinyin cut into syllables, one per hanzi (erhua: r joins the syllable)"""
    sy = []
    for w in re.split(r"[\s'’]+", re.sub(r'[，。！？、；：,.!?;:“”"《》（）()…—]', ' ', py)):
        if not w:
            continue
        if re.fullmatch(r'\d+', w):
            sy.append(w)
            continue
        part = split_py(w, syl)
        if part is None:
            return None
        sy.extend(part)
    out, k = [], 0
    for t in tokens:
        hz = [c for c in t if HZ.match(c)]
        if not hz:
            if re.fullmatch(r'\d+', t) and k < len(sy) and sy[k] == t:
                k += 1
            out.append('')
            continue
        got = []
        for c in hz:
            if c == '儿' and got and k < len(sy) and plain_py(sy[k]) == 'r':
                got[-1] += 'r'
                k += 1
                continue
            if c == '儿' and got and (k >= len(sy) or plain_py(sy[k]) not in ('er', 'r')):
                got[-1] += 'r'
                continue
            if k >= len(sy):
                return None
            got.append(sy[k])
            k += 1
        out.append(''.join(got))
    if k != len(sy):
        return None
    return [x.lower() if i else x for i, x in enumerate(out)]


EX_TOK = re.compile(r'\[(\d+)\s+([^\]]*)\]|([^\s\[{]+\{[^}]*\}|[^\s\[]+)')
IN_TOK = re.compile(r'[^\s{]+\{[^}]*\}|\S+')
OVR = re.compile(r'^(.*?)\{([^}]*)\}$')


def ex_tokens(src):
    """"[1 我] [2 有] 一个 [3 哥哥] 。" → [(word, slot, gloss override or None)]"""
    out = []
    for m in EX_TOK.finditer(src):
        slot = int(m.group(1)) if m.group(1) else 0
        for t in (IN_TOK.findall(m.group(2)) if m.group(1) else [m.group(3)]):
            g = None
            o = OVR.match(t)
            if o:
                t = o.group(1)
                e = [x.strip() for x in o.group(2).split('|')]
                assert len(e) == 4, f'gloss needs 4 languages: {o.group(0)}'
                g = dict(zip(LANGS, e))
            out.append((t, slot, g))
    return out


def gloss(t, T, dic):
    if t in T:
        return {k: T[t][k] for k in LANGS}
    d = dic.get(t)
    if d:
        g = {'id': short(d.get('m')), 'en': short(d.get('em')), 'th': short(d.get('hm')), 'vi': short(d.get('vm'))}
        if all(g.values()):
            return g
    return None


def formula(fs, T, dic):
    """"主语 + 有 + 名词" → parts with meaning and pinyin, and the signs between them"""
    # the signs between parts, never inside a {meaning} (a meaning may hold " + " itself)
    src = ' ' + fs.strip() + ' '
    toks, buf, depth, i = [], '', 0, 0
    while i < len(src):
        c = src[i]
        depth += (c == '{') - (c == '}')
        m = re.match(r'\s+([+＋，,…]|……)\s+', src[i:]) if depth == 0 else None
        if m:
            toks += [buf, m.group(1)]
            buf = ''
            i += m.end()
            continue
        buf += c
        i += 1
    toks.append(buf)
    parts, seps = [], []
    for i, t in enumerate(toks):
        t = t.strip()
        if i % 2:
            seps.append('，' if t in '，,' else ('…' if t.startswith('…') else '+'))
            continue
        g = None
        o = OVR.match(t)
        if o:
            t = o.group(1)
            e = [x.strip() for x in o.group(2).split('|')]
            assert len(e) == 4, f'formula gloss needs 4 languages: {fs}'
            g = dict(zip(LANGS, e))
        alts = [a for a in re.split(r'[/／]', t) if a]
        # a part that is the grammar word itself (有, 了, 会/能) takes the accent; a slot (主语, 名词, A) a colour
        key = bool(HZ.search(t)) and not all(T.get(a, {}).get('kind') == 'f' for a in alts)
        py = ''
        if t in T:
            g = g or {k: T[t][k] for k in LANGS}
            py = T[t]['py']
        else:
            gs = [gloss(a, T, dic) for a in alts]
            if g is None and all(gs):
                g = {k: ' / '.join(dict.fromkeys(x[k] for x in gs)) for k in LANGS}
            pys = [(T[a]['py'] if a in T else (dic[a]['p'] if a in dic else '')) for a in alts]
            py = ' / '.join(x for x in pys if x)
        parts.append({'t': t, 'py': py, 'g': g, 'k': key})
    return parts, seps


def examples(p, T, dic, byz, syl, problems):
    out = []
    for src, where in p.get('e', []):
        ctx = ''
        m = re.match(r'@([dswy])\s+', src)
        if m:  # v1.8: where the sentence lives: d everyday, s study, w work, y children (YCT)
            ctx, src = m.group(1), src[m.end():]
        head, *rest = [x.strip() for x in re.split(r'\|(?![^{]*\})', src)]
        toks = ex_tokens(head)
        z = ''.join(t for t, _, _ in toks)
        if rest:
            assert len(rest) == 5, f'{where}: own example needs pinyin + 4 languages'
            py, tr = rest[0], dict(zip(LANGS, rest[1:]))
        else:
            d = byz.get(z)
            if d is None:
                problems.append(f'{where}: not a word-list sentence, give pinyin and translations: {z}')
                continue
            py = re.sub(r'[{}]', '', d.get('zp') or '')
            tr = {'id': d.get('t', ''), 'en': d.get('et', ''), 'th': d.get('ht', ''), 'vi': d.get('vt', '')}
        pys = align([t for t, _, _ in toks], py, syl)
        if pys is None:
            problems.append(f'{where}: pinyin does not fit the words: {z} / {py}')
            pys = [''] * len(toks)
        rows = []
        for (t, slot, g), tp in zip(toks, pys):
            if not HZ.search(t):
                rows.append([t, '', 0, None])
                continue
            g = g or gloss(t, T, dic)
            if g is None:
                problems.append(f'{where}: no meaning for {t} (split it or write {t}{{id|en|th|vi}})')
            rows.append([t, tp, slot, g])
        out.append({'z': z, 'py': py, 'tr': tr, 'w': rows, **({'c': ctx} if ctx else {})})
    return out


def inside(p, words):
    """the longer words that hold one of the point's words without being it (涉及 for 及, 以便 for 以): a sentence
    shows the point only where its word stands alone (v1.8, Josh: examples that do not fit the formula)"""
    if p['c'] in 'WK' or not p['k']:  # affixes and complements live inside words (桌子, 回来)
        return []
    ks = set(p['k'])
    return sorted({w for w in words if len(w) > 1 and w not in ks and any(k in w and len(k) < len(w) for k in ks)}, key=len, reverse=True)


def bare_of(z, longer):
    for w in longer:
        if w in z:
            z = z.replace(w, '□' * len(w))
    return z


def fits(p, z, longer=()):
    if not p['k'] and 'm' not in p:
        return None
    if p['k'] and not any(k in bare_of(z, longer) for k in p['k']):
        return None
    if 'm' in p and not re.search(p['m'], z):
        return None
    return True


def build(words):
    problems = []
    wid = lambda d: f"{d['l']}:{d['h']}"
    pub, sealed = [], []
    T = terms()
    syl = syllables(words)
    dic_pub, dic_all = {}, {}
    for d in sorted(words, key=lambda d: -d['l']):  # the lowest level wins
        dic_all[d['h']] = d
        if d['l'] <= 6:
            dic_pub[d['h']] = d
    hz_words = {d['h'] for d in words if len(d['h']) > 1}
    byz = {}
    for d in sorted(words, key=lambda d: -d['l']):
        if d.get('z'):
            byz[d['z']] = d
    for level in [*range(1, 10), 0]:
        path = os.path.join(DIR, f'{level}.txt' if level else 'x.txt')
        if not os.path.exists(path):
            continue
        for p in parse(path, level):
            level = p['l']
            top = min(level + 1, 6) if level <= 6 else 9
            longer = inside(p, hz_words)
            cand = [d for d in words if d['l'] <= top and d.get('z') and fits(p, d['z'], longer)]
            # nearest level first, then the shortest sentences (clearest examples)
            cand.sort(key=lambda d: (abs(d['l'] - level) + (0.5 if d['l'] > level else 0), len(d['z'])))
            seen, ex, pool = set(), [], []
            for d in cand:
                if d['z'] in seen:
                    continue
                seen.add(d['z'])
                if len(ex) < N_EX and abs(d['l'] - level) <= (2 if level >= 7 else 1):
                    ex.append(wid(d))
                if len(pool) < N_POOL:
                    pool.append(wid(d))
            if (p['k'] or 'm' in p) and not ex and not p['own'] and not p.get('e'):
                problems.append(f"{p['id']} {p['zh']}: no example sentence")
            out = {k: v for k, v in p.items() if k not in ('own', 'e', 'fs')}
            out['ex'], out['pool'] = ex, pool
            dic = dic_pub if level <= 6 else dic_all
            out['fp'], out['fx'] = formula(p.get('fs') or p['f'], T, dic)
            eg = examples(p, T, dic, byz, syl, problems)
            if eg:
                out['eg'] = eg
            if not p.get('n'):
                problems.append(f"{p['id']} {p['zh']}: no name (n:)")
            if len(eg) < 3:
                problems.append(f"{p['id']} {p['zh']}: {len(eg)} examples, 3 wanted")
            # practice: the old own examples and the own examples written word by word
            own = list(p['own'])
            for e in eg:
                if e['z'] not in byz and e['z'] not in {o[0] for o in own}:
                    own.append([e['z'], e['py'], e['tr']['id'], e['tr']['en'], e['tr']['th'], e['tr']['vi']])
            if own:
                out['own'] = own
            (pub if level <= 6 else sealed).append(out)
    return pub, sealed, problems


if __name__ == '__main__':
    import json
    with open(os.path.join(ROOT, 'content', 'vocab.json'), encoding='utf8') as f:
        words = json.load(f)
    pub, sealed, problems = build(words)
    for p in problems:
        print(p)
    by = {}
    for p in pub + sealed:
        by.setdefault(p['l'], []).append(p)
    for l, ps in sorted(by.items()):
        print(f'HSK {l}: {len(ps)} points, {sum(1 for p in ps if p["ex"])} with examples, '
              f'{sum(1 for p in ps if len(p["pool"]) >= 5)} with 5+ practice sentences')
