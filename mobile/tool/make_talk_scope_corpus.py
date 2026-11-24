#!/usr/bin/env python3
"""Generate matched examples that differ in speaker, proposal, or commitment."""

import json
from itertools import product

from make_talk_context_corpus import CORPUS, ROOT, frame, normalized


def cases():
    actions = [
        ('把遗漏的货重新寄出', 'resend', {}), ('再发一箱新的货', 'resend', {}),
        ('给这票件走加急通道', 'expedite', {}), ('用专车优先发', 'expedite', {}),
        ('给您的订单打七五折', 'discount', {'pct': 25}), ('直接给贵司减百分之十二', 'discount', {'pct': 12}),
        ('把多收的钱原路退回', 'compensate', {}), ('由我们报销这笔额外运费', 'compensate', {}),
        ('周五中午前把这批货交到贵司', 'promise_time', {'when': 'friday'}),
        ('在三天内把原来的箱子送到', 'promise_time', {'when': '3_days'}),
    ]
    wrappers = {
        'confirmed': [('我方决定{}。', '+'), ('我们做完核对了，这次会{}。', '+'),
                      ('我们这边已经定了，就按这个办法{}。', '+')],
        'reported': [('买家问能不能{}，我还没回应。', None), ('同事的意见是考虑{}，还没报批。', None),
                     ('我转述一下，经理刚才说“{}”。我还没确认。', None)],
        'pending': [('想{}，需要走审批。我先核实。', None), ('现在讨论的是能否{}。', None),
                    ('是否能{}，我还在等回复。', None)],
        'declined': [('我们不可能{}。', '-'), ('抱歉，我们不能{}。', '-'),
                     ('本次明确无法{}。', '-')],
    }
    closing = ('等我核实完会给您回电。', '至于其他情况，我还在了解。', '请问您手上的订单编号是多少？', '')
    for (phrase, act, slots), (family, variants), ending in product(actions, wrappers.items(), closing):
        for pattern, polarity in variants:
            text = pattern.format(phrase) + ending
            frames = [frame(act, polarity, **slots)] if polarity else []
            if pattern.startswith('抱歉'):
                frames.insert(0, frame('apologize'))
            if '订单编号' in ending:
                frames.append(frame('ask_order'))
            yield family, text, frames


def main():
    existing = [CORPUS / name for name in ('train5_all.jsonl', 'context_v5_train.jsonl', 'billing_v8_train.jsonl', 'composition_v9_train.jsonl')]
    existing += [*CORPUS.glob('blind*.jsonl'), *CORPUS.glob('asr_sim*.jsonl')]
    known = {normalized(json.loads(line)['text']) for path in existing for line in path.read_text().splitlines() if line.strip()}
    fixtures = ROOT / 'mobile/test/talk'
    for name in ('scope_cases.json', 'composed_cases.json'):
        known.update(normalized(row['text']) for row in json.loads((fixtures / name).read_text()))
    path = CORPUS / 'scope_v10_train.jsonl'
    rows = []
    for family, text, frames in cases():
        key = normalized(text)
        if key in known:
            continue
        known.add(key)
        rows.append({'text': text, 'frames': frames or [frame('none')], 'tags': [family],
                     'set': 'scope_v10_train', 'source': 'composed_contrast'})
    path.write_text(''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in rows), encoding='utf-8')
    print(f'{len(rows)} contrasts in {path.name}')


if __name__ == '__main__':
    main()
