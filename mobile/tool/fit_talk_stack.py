#!/usr/bin/env python3
"""Fits how the talk engine mixes the rules and the model: for every act+polarity a tiny logistic regression over the
rules' confidence r and the model's out-of-fold logit, then a shift so the best cut-off lands on the engine's .6.
Writes the result into the model file under "stack".

  python3 mobile/tool/fit_talk_stack.py --oof OOF.jsonl --rules RULES.jsonl --gold train_all.jsonl --model talk_model.json"""
import json, argparse, math
import numpy as np
from sklearn.linear_model import LogisticRegression

ap = argparse.ArgumentParser()
ap.add_argument('--oof'); ap.add_argument('--rules'); ap.add_argument('--gold'); ap.add_argument('--model')
a = ap.parse_args()

oof = {}
for l in open(a.oof, encoding='utf8'):
    o = json.loads(l); oof[o['text']] = o['p']
rules = {}
for l in open(a.rules, encoding='utf8'):
    o = json.loads(l); rules[o['text']] = o['r']
gold = {}
for l in open(a.gold, encoding='utf8'):
    o = json.loads(l); gold[o['text']] = {f['act'] + f['pol'] for f in o['frames'] if f['act'] != 'none'}
texts = [t for t in oof if t in rules and t in gold]
model = json.load(open(a.model, encoding='utf8'))
labels = model['labels']

def lg(p):
    p = min(max(p, 1e-4), 1 - 1e-4)
    return math.log(p / (1 - p))

stack = {}
Z, Y = [], []
for k, lab in enumerate(labels):
    X = np.array([[rules[t].get(lab, 0.0), lg(oof[t][lab])] for t in texts])
    y = np.array([1 if lab in gold[t] else 0 for t in texts])
    if y.sum() < 10:
        continue
    m = LogisticRegression(C=2.0, max_iter=300).fit(X, y)
    stack[lab] = [round(float(m.coef_[0][0]), 4), round(float(m.coef_[0][1]), 4), round(float(m.intercept_[0]), 4)]
    z = X @ m.coef_[0] + m.intercept_[0]
    Z.append(z); Y.append(y)
Z = np.concatenate(Z); Y = np.concatenate(Y)
best = (0, 0)
for tau in np.arange(.25, .75, .025):
    pred = Z >= math.log(tau / (1 - tau))
    tp = (pred & (Y == 1)).sum(); fp = (pred & (Y == 0)).sum(); fn = ((~pred) & (Y == 1)).sum()
    f = 2 * tp / max(1, 2 * tp + fp + fn)
    if f > best[0]: best = (f, tau)
print('best OOF F1 %.4f at tau %.3f' % best)
tau = best[1]
model['stack'] = stack
model['shift'] = round(math.log(.6 / .4) - math.log(tau / (1 - tau)), 4)
json.dump(model, open(a.model, 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
print('stack for', len(stack), 'labels, shift', model['shift'])
