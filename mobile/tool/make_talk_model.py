#!/usr/bin/env python3
"""Trains the small on-device classifier of the talk engine and writes it to mobile/assets/data/talk_model.json.

The model reads a whole utterance and says, for every act+polarity (apologize+, discount-, ...), how likely it is
present. Features are the hanzi n-grams (1-4) of the text and the n-grams (2-4) of the text folded to toneless
syllables (so a homophone the recognizer wrote still counts). One logistic regression per label; weights are pruned and
stored as int8. Needs numpy, scipy, scikit-learn (training only; the app only reads the file).

  python3 mobile/tool/make_talk_model.py --train content/talk/corpus/train/*.jsonl --hold 0.1 [--out PATH] [--oof PATH]

--hold: share of the training lines (by hash) kept out to measure and to fit the blend of rules and model.
--oof: writes out-of-fold probabilities (5 folds) for every training line, for fitting the blend.
--asr-augment: adds synthetic homophone variants to each source's training fold.
--exclude: removes exact normalized matches to evaluation texts, including from augmentation."""
import sys, os, re, json, glob, hashlib, argparse, collections
import random
import numpy as np
from scipy import sparse
from sklearn.linear_model import LogisticRegression

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_fold():
    src = open(os.path.join(root, 'mobile/lib/app/talk/sound.g.dart'), encoding='utf8').read()
    a = re.search(r"const soundFrom = '([^']*)'", src).group(1)
    b = re.search(r"const soundTo = '([^']*)'", src).group(1)
    return dict(zip(a, b))


FOLD = load_fold()
KEEP = re.compile(r'[^一-鿿0-9]')
HOMOPHONES = collections.defaultdict(list)
for char, sound in sorted(FOLD.items()):
    HOMOPHONES[sound].append(char)
# Keep short words that decide who spoke, polarity or numeric commitments.
ASR_ANCHORS = set('不没无未非不能会要可是否别我你您他她它们一二两三四五六七八九十零百半折日月年')


def clean(t):
    return KEEP.sub('', t)


def feats(text):
    t = clean(text)
    s = '^' + t + '$'
    out = set()
    for n in (1, 2, 3, 4):
        for i in range(len(s) - n + 1):
            out.add(s[i:i + n])
    ft = ''.join(FOLD.get(c, c) for c in t)
    sf = '^' + ft + '$'
    for n in (2, 3, 4):
        for i in range(len(sf) - n + 1):
            out.add('~' + sf[i:i + n])
    return out


_scope = re.compile(r'不是不|不会不|不能不|不可能|没有|并非|并无|没法|无法|不能|不会|不再|不确定|会不会|能不能|能否|可不可以|是否|想|考虑|如果|假如|要是|确认|决定|保证|承诺|说|问')
_clause_delimiters = re.compile(r'[，。！？；：,.!?;:、…\s]+|但是|不过|而是|然而|否则|然后|另外')


def scope_feats(text):
    result = set()
    for clause in _clause_delimiters.split(text):
        for m in _scope.finditer(clause):
            before = clean(clause[:m.start()])[-3:]
            after = clean(clause[m.end():])[:14]
            for start in range(len(after) - 1):
                for length in (2, 3):
                    window = after[start:start + length]
                    if len(window) == length:
                        distance = 0 if start < 4 else 1
                        result.add(f'!{m[0]}{distance}{window}')
            if before:
                result.add(f'!{before}>{m[0]}')
    return result


def label_of(fr):
    return fr['act'] + fr['pol']


def read(paths):
    rows = []
    for p in paths:
        for l in open(p, encoding='utf8'):
            l = l.strip()
            if not l: continue
            try: o = json.loads(l)
            except Exception: continue
            fr = [x for x in o.get('frames', []) if x.get('act') != 'none']
            rows.append((o['text'], sorted({label_of(x) for x in fr})))
    return rows


def hash_hold(text, share):
    return int(hashlib.sha256(text.encode()).hexdigest(), 16) % 1000 < share * 1000


def asr_variant(text, rate):
    """Generate a repeatable training variant from the training text's sound fold."""
    rng = random.Random(text)
    result = []
    for char in text:
        if char not in ASR_ANCHORS and rng.random() < rate:
            sound = FOLD.get(char, char)
            choices = [c for c in HOMOPHONES[sound] if c != char and c not in ASR_ANCHORS]
            if choices:
                char = rng.choice(choices)
        result.append(char)
    return ''.join(result)


def f1(tp, fp, fn):
    p = tp / (tp + fp) if tp + fp else 0
    r = tp / (tp + fn) if tp + fn else 0
    return p, r, (2 * p * r / (p + r) if p + r else 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--train', nargs='+', required=True)
    ap.add_argument('--hold', type=float, default=0.1)
    ap.add_argument('--C', type=float, default=4.0)
    ap.add_argument('--min_df', type=int, default=2)
    ap.add_argument('--prune', type=float, default=0.12)
    ap.add_argument('--out', default=os.path.join(root, 'mobile/assets/data/talk_model.json'))
    ap.add_argument('--oof')
    ap.add_argument('--asr-augment', type=float, default=0,
                    help='character substitution rate for one extra variant per training text')
    ap.add_argument('--exclude', nargs='+', default=[], help='corpora reserved for evaluation')
    ap.add_argument('--scope-features', action='store_true', help='learn clause-local relations to modal verbs and negation')
    ap.add_argument('--full', action='store_true', help='train on everything (no hold-out) for the shipped model')
    a = ap.parse_args()

    def features(text):
        base = feats(text)
        if a.scope_features:
            base.update(scope_feats(text))
        return base

    files = []
    for p in a.train: files += glob.glob(p)
    rows = read(files)
    reserved = {clean(t) for t, _ in read(a.exclude)}
    seen = set(); uniq = []
    for t, l in rows:
        if t in seen or clean(t) in reserved: continue
        seen.add(t); uniq.append((t, l))
    rows = uniq
    hold = [r for r in rows if not a.full and hash_hold(r[0], a.hold)]
    train = [r for r in rows if a.full or not hash_hold(r[0], a.hold)]
    print(f'lines {len(rows)}  train {len(train)}  hold {len(hold)}')

    cnt = collections.Counter(l for _, ls in train for l in ls)
    labels = sorted(l for l, c in cnt.items() if c >= 8)
    print('labels', len(labels), dict(cnt.most_common()))
    L = {l: i for i, l in enumerate(labels)}

    df = collections.Counter()
    tf = [features(t) for t, _ in train]
    for f in tf: df.update(f)
    vocab = sorted(g for g, c in df.items() if c >= a.min_df)
    V = {g: i for i, g in enumerate(vocab)}
    print('features', len(vocab))

    def mat(fs):
        ri, ci = [], []
        for r, f in enumerate(fs):
            for g in f:
                j = V.get(g)
                if j is not None: ri.append(r); ci.append(j)
        return sparse.csr_matrix((np.ones(len(ri), dtype=np.float32), (ri, ci)), shape=(len(fs), len(vocab)))

    def norm(X):
        n = np.sqrt(np.asarray(X.sum(axis=1)).ravel()); n[n == 0] = 1
        return sparse.diags(1 / n) @ X

    X = norm(mat(tf))
    Y = np.zeros((len(train), len(labels)), dtype=np.int8)
    for r, (_, ls) in enumerate(train):
        for l in ls:
            if l in L: Y[r, L[l]] = 1

    augmented_rows = []
    augmented_features = []
    if a.asr_augment:
        used = reserved | {clean(t) for t, _ in rows}
        for i, (text, _) in enumerate(train):
            variant = asr_variant(text, a.asr_augment)
            key = clean(variant)
            if key in used:
                continue
            used.add(key)
            augmented_rows.append(i)
            augmented_features.append(features(variant))
        print('ASR variants', len(augmented_rows))
    source = np.array(augmented_rows, dtype=int)
    X_aug = norm(mat(augmented_features))

    def fit(indices):
        variants = np.flatnonzero(np.isin(source, indices))
        x = sparse.vstack((X[indices], X_aug[variants]), format='csr')
        y = np.vstack((Y[indices], Y[source[variants]]))
        weight = np.concatenate((np.ones(len(indices)), np.full(len(variants), .6)))
        W = np.zeros((len(labels), x.shape[1]), dtype=np.float32); B = np.zeros(len(labels), dtype=np.float32)
        for k in range(len(labels)):
            m = LogisticRegression(C=a.C, solver='liblinear', max_iter=200, class_weight=None)
            m.fit(x, y[:, k], sample_weight=weight); W[k] = m.coef_[0]; B[k] = m.intercept_[0]
        return W, B

    def prob(W, B, X):
        return 1 / (1 + np.exp(-(X @ W.T + B)))

    if a.oof:
        P = np.zeros(Y.shape, dtype=np.float32)
        groups = np.array([int(hashlib.sha256(clean(t).encode()).hexdigest(), 16) % 5 for t, _ in train])
        idx = np.arange(len(train))
        folds = [idx[groups == fold] for fold in range(5)]
        for fi, te in enumerate(folds):
            tr = np.setdiff1d(idx, te)
            W, B = fit(tr); P[te] = prob(W, B, X[te])
            print('fold', fi, 'done')
        with open(a.oof, 'w', encoding='utf8') as fh:
            for r, (t, ls) in enumerate(train):
                fh.write(json.dumps({'text': t, 'p': {labels[k]: round(float(P[r, k]), 4) for k in range(len(labels))}}, ensure_ascii=False) + '\n')
        print('oof written', a.oof)

    W, B = fit(np.arange(len(train)))
    # prune and quantize
    scale = np.maximum(np.abs(W).max(axis=1), 1e-6) / 127
    Q = np.round(W / scale[:, None]).astype(np.int8)
    Q[np.abs(W) < a.prune] = 0
    nz = int((Q != 0).sum())
    print('non-zero weights', nz)
    Wq = Q.astype(np.float32) * scale[:, None]

    if hold:
        Xh = norm(mat([features(t) for t, _ in hold]))
        Ph = prob(Wq, B, Xh)
        print('hold-out (utterance-level presence, threshold .5):')
        tot = [0, 0, 0]
        for k, l in enumerate(labels):
            tp = fp = fn = 0
            for r, (_, ls) in enumerate(hold):
                pred = Ph[r, k] >= .5; gold = l in ls
                tp += pred and gold; fp += pred and not gold; fn += (not pred) and gold
            p, rc, f = f1(tp, fp, fn)
            tot[0] += tp; tot[1] += fp; tot[2] += fn
            print(f'  {l:16s} n={tp + fn:4d}  P {p:.3f}  R {rc:.3f}  F1 {f:.3f}')
        p, rc, f = f1(*tot)
        print(f'  micro  P {p:.3f}  R {rc:.3f}  F1 {f:.3f}')

    entries = {}
    for k in range(len(labels)):
        for j in np.nonzero(Q[k])[0]:
            entries.setdefault(vocab[j], []).append([k, int(Q[k, j])])
    out = {'v': 1, 'labels': labels, 'bias': [round(float(b), 4) for b in B], 'scale': [round(float(s), 6) for s in scale],
           'w': entries}
    if a.scope_features:
        out['scope'] = True
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, 'w', encoding='utf8') as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(',', ':'))
    print('written', a.out, os.path.getsize(a.out) // 1024, 'KB', len(entries), 'features kept')


if __name__ == '__main__':
    main()
