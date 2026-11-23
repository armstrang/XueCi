#!/usr/bin/env python3
"""Simulated speech-recognizer output (NOT real speech): rewrites a labelled corpus the way a phone recognizer tends to
write it. Punctuation is dropped; each hanzi may be swapped for another with the same syllable (other tone), the same
syllable and tone, or a near-sounding one (zh/z, ch/c, sh/s, n/l, in/ing, en/eng, an/ang: typical learner accents);
a few characters are dropped. Character sounds come from the word list (content/vocab.json), not from the engine's
own homophone fold. Labels are kept. Used only as a robustness test, never as proof for real speech, never for training.

  python3 mobile/tool/make_asr_sim.py IN.jsonl OUT.jsonl RATE [SEED]     (RATE = chance per hanzi, e.g. .03 / .08)"""
import sys, json, re, random, unicodedata, collections, os
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
inp, outp, rate = sys.argv[1], sys.argv[2], float(sys.argv[3])
rng = random.Random(int(sys.argv[4]) if len(sys.argv) > 4 else 11)
syl = collections.defaultdict(collections.Counter)
for l in open(os.path.join(root, 'content/vocab.json'), encoding='utf8'):
    l = l.strip().rstrip(',')
    if not l.startswith('{'): continue
    o = json.loads(l)
    if len(o['h']) == len(o['s']):
        for c, s in zip(o['h'], o['s']): syl[c][s] += 1
ch = {c: cnt.most_common(1)[0][0] for c, cnt in syl.items()}
def base(s): return ''.join(x for x in unicodedata.normalize('NFD', s) if not unicodedata.combining(x)).replace('ü', 'u').lower()
def tone(s):
    for x in unicodedata.normalize('NFD', s):
        if x in '̄́̌̀': return x
    return ''
by_base = collections.defaultdict(list); by_full = collections.defaultdict(list)
for c, s in ch.items():
    by_base[base(s)].append(c); by_full[s].append(c)
NEAR = [('zh', 'z'), ('ch', 'c'), ('sh', 's'), ('n', 'l'), ('ing', 'in'), ('eng', 'en'), ('ang', 'an')]
def near(b):
    out = []
    for a, z in NEAR + [(z, a) for a, z in NEAR]:
        if b.startswith(a) and a in ('zh', 'ch', 'sh', 'n') and not (a == 'n' and b.startswith('ng')): out.append(z + b[len(a):])
        if b.endswith(a) and a in ('ing', 'eng', 'ang', 'in', 'en', 'an'): out.append(b[:len(b) - len(a)] + z)
    return out
def swap(c):
    s = ch.get(c)
    if not s: return c
    r = rng.random(); b = base(s)
    if r < .35: pool = [x for x in by_full[s] if x != c]
    elif r < .7: pool = [x for x in by_base[b] if x != c and ch[x] != s]
    else: pool = [x for n in near(b) for x in by_base.get(n, [])]
    return rng.choice(pool) if pool else c
n = 0
with open(outp, 'w', encoding='utf8') as w:
    for l in open(inp, encoding='utf8'):
        o = json.loads(l); t = ''
        for c in re.sub(r'[，。！？、；：,.!?;:"“”‘’（）() ]', '', o['text']):
            r = rng.random()
            if '一' <= c <= '鿿':
                if r < rate: c = swap(c); n += 1
                elif r < rate + rate / 4: continue
            t += c
        o['text'] = t; o['tags'] = list(o.get('tags', [])) + ['asr_sim']
        w.write(json.dumps(o, ensure_ascii=False) + '\n')
print('changed hanzi', n, '->', outp)
