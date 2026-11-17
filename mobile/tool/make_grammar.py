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
            else:
                raise AssertionError(f'{path}:{n}: {line}')
    for i, p in enumerate(pts):
        assert set(p['x']) == set(LANGS), f'{path}: {p["zh"]} lacks {set(LANGS) - set(p["x"])}'
        p['id'] = f'{level}-{i + 1:03d}'
    return pts


def fits(p, z):
    if not p['k'] and 'm' not in p:
        return None
    if p['k'] and not any(k in z for k in p['k']):
        return None
    if 'm' in p and not re.search(p['m'], z):
        return None
    return True


def build(words):
    problems = []
    wid = lambda d: f"{d['l']}:{d['h']}"
    pub, sealed = [], []
    for level in range(1, 10):
        path = os.path.join(DIR, f'{level}.txt')
        if not os.path.exists(path):
            continue
        for p in parse(path, level):
            top = min(level + 1, 6) if level <= 6 else 9
            cand = [d for d in words if d['l'] <= top and d.get('z') and fits(p, d['z'])]
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
            if (p['k'] or 'm' in p) and not ex and not p['own']:
                problems.append(f"{p['id']} {p['zh']}: no example sentence")
            out = {k: v for k, v in p.items() if k not in ('own',)}
            out['ex'], out['pool'] = ex, pool
            if p['own']:
                out['own'] = p['own']
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
