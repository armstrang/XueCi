"""Build content/bct/bct.json (committed; make_assets.py copies it into the app) from the BCT-style sentence banks in content/bct/ (a.txt, b.txt).

    python3 content/tools/bct_build.py PYPINYIN_DIR JIEBA_DIR

A line of a bank:  sentence with one gap [right|wrong1|wrong2|wrong3] | id | en | th | vi
`## name` starts a topic. Checked: one gap with 3 different wrong words, every hanzi in the font subset, all four
translations, no sentence twice, the wrong words really are wrong (they are written by hand, see the bank's header).
Written: the sentence, its pinyin (the same reading rules as the word list, the gap word in {}), the pieces for
sentence building, the topic, the four translations. Fails (exit 1) on any problem.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sentence_pinyin as sp  # noqa: E402  (takes the two library folders from argv[1:3])
import jieba  # noqa: E402

ROOT = sp.ROOT
CHARSET = open(os.path.join(ROOT, 'mobile', 'assets', 'fonts', 'charset.txt'), encoding='utf8').read()
HAN = re.compile(r'[一-鿿]')
AUTO = re.compile(r'\[([^\]|:]+):([nva])\]')
# shorthand [word:n] (noun) / :v (verb) / :a (adjective): three clearly wrong words of the same kind, picked by hand-made pools
POOL = {
    'n': ['雨伞', '牙膏', '眼泪', '拖鞋', '眉毛', '胡子', '雨点', '书包', '鞋带', '窗帘', '西瓜', '月亮'],
    'v': ['游泳', '睡觉', '唱歌', '洗澡', '散步', '跳舞'],
    'a': ['酸甜', '肥胖', '窄小', '苦涩'],
}


def auto_gap(word, kind):
    pool = [w for w in POOL[kind] if w != word and w not in word]
    h = sum(ord(c) for c in word)
    pick = [pool[(h + i * 5) % len(pool)] for i in range(3)]
    for i in range(3):
        while pick.count(pick[i]) > 1:
            pick[i] = pool[(pool.index(pick[i]) + 1) % len(pool)]
    return '[' + '|'.join([word] + pick) + ']'


GAP = re.compile(r'\[([^\]|]+)\|([^\]|]+)\|([^\]|]+)\|([^\]|]+)\]')
BANKS = {'a': 'a.txt', 'b': 'b.txt'}
PARTICLES = set('的了吗吧呢啊着过地得')


def pieces(z):
    """3–6 pieces for sentence building: words (jieba), punctuation stays on the piece before it."""
    s = re.sub(r'[。！？!?.]+$', '', z)
    toks = [t for t in jieba.cut(s, HMM=False) if t.strip()]
    out = []
    for t in toks:
        if re.fullmatch(r'[，、；：]', t) and out:
            out[-1] += t
        else:
            out.append(t)
    def bare(x):
        return re.sub(r'[，、；：]', '', x)
    # one-character pieces lean on a neighbour: particles to the left, the rest to the right
    i = 0
    while i < len(out) and len(out) > 3:
        if len(bare(out[i])) == 1:
            if bare(out[i]) in PARTICLES and i > 0 and not out[i - 1].endswith(('，', '、')):
                out[i - 1] += out.pop(i)
                continue
            if i + 1 < len(out) and not out[i].endswith(('，', '、')):
                out[i] += out.pop(i + 1)
                continue
        i += 1
    while len(out) > 6:
        j = min(range(len(out) - 1), key=lambda k: len(bare(out[k])) + len(bare(out[k + 1])) + (100 if out[k].endswith('，') else 0))
        out[j] += out.pop(j + 1)
    return out if len(out) >= 3 and len(set(out)) == len(out) else None


def main():
    with open(sp.VOCAB, encoding='utf8') as f:
        data = json.load(f)
    vocab = {d['h']: d['s'] for d in data if d['l'] <= 6}
    jieba.initialize()
    for w in sp.NOT_WORDS:
        jieba.del_word(w)
    for w in vocab:
        if len(w) > 1 and w not in jieba.dt.FREQ and w not in sp.NOT_WORDS:
            jieba.add_word(w)
    for w in ('小李', '小王', '小张', '小刘', '小陈', '小林', '小周', '小赵'):
        jieba.add_word(w, 100000)
    problems = []
    out = {}
    seen = set()
    for key, fn in BANKS.items():
        path = os.path.join(ROOT, 'content', 'bct', fn)
        if not os.path.exists(path):
            continue
        rows, sec, n = [], '', 0
        for ln, line in enumerate(open(path, encoding='utf8').read().split('\n'), 1):
            line = line.strip()
            if not line or line.startswith('# '):
                continue
            if line.startswith('## '):
                sec = line[3:].strip()
                continue
            where = f'{fn}:{ln}'
            f = [x.strip() for x in line.split(' | ')]
            if len(f) != 5:
                problems.append(f'{where}: {len(f)} fields, want 5')
                continue
            zg, idt, en, th, vi = f
            zg = AUTO.sub(lambda a: auto_gap(a.group(1), a.group(2)), zg)
            m = GAP.search(zg)
            if not m or len(GAP.findall(zg)) != 1 or zg.count('[') != 1:
                problems.append(f'{where}: need exactly one gap [right|w1|w2|w3]')
                continue
            right, ws = m.group(1), [m.group(i) for i in (2, 3, 4)]
            if len({right, *ws}) != 4:
                problems.append(f'{where}: the four words of the gap must differ')
            z = GAP.sub(right, zg)
            if z.find(right) != m.start():
                problems.append(f'{where}: {right} stands earlier in the sentence than the gap (the app marks the first one)')
            if z in seen:
                problems.append(f'{where}: sentence twice')
            seen.add(z)
            for ch in set(HAN.findall(zg)):
                if ch not in CHARSET:
                    problems.append(f'{where}: {ch} is not in the font subset')
            if not all(f[1:]):
                problems.append(f'{where}: a translation is empty')
            if not z.endswith(('。', '？', '！')):
                problems.append(f'{where}: no final punctuation')
            n += 1
            zp = sp.read_sentence(z, right, vocab)
            for nm, py in (('小李', 'Xiǎo Lǐ'), ('小王', 'Xiǎo Wáng'), ('小张', 'Xiǎo Zhāng'), ('小刘', 'Xiǎo Liú'), ('小陈', 'Xiǎo Chén'), ('小林', 'Xiǎo Lín'), ('小周', 'Xiǎo Zhōu'), ('小赵', 'Xiǎo Zhào')):
                if nm in z:
                    zp = re.sub(py.lower().replace(' ', r'\s*') if False else '(?i)' + py.replace(' ', ' ?'), py, zp)
            rows.append({'id': f'{key}{n:03d}', 'z': z, 'g': right, 'd': ws, 'zp': zp, 'w': pieces(z), 's': sec,
                         't': {'id': idt, 'en': en, 'th': th, 'vi': vi}})
        out[key] = rows
        print(f'bank {key}: {len(rows)} sentences')
    if problems:
        print('\n'.join(problems[:60]))
        print(f'{len(problems)} problems')
        sys.exit(1)
    dst = os.path.join(ROOT, 'content', 'bct', 'bct.json')
    with open(dst, 'w', encoding='utf8') as f:
        f.write('{' + ',\n'.join(f'"{k}":[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False, separators=(',', ':')) for r in v) + '\n]' for k, v in out.items()) + '}\n')
    print('wrote', dst)


if __name__ == '__main__':
    main()
