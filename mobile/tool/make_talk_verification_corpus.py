#!/usr/bin/env python3
"""Build training pairs that distinguish reports, questions, and explicit decisions."""

import json
from itertools import product

from make_talk_context_corpus import CORPUS, ROOT, frame, normalized


def samples():
    actions = (
        ('返还这笔额外仓储费', 'compensate', {}), ('免费补偿一张礼券', 'compensate', {}),
        ('为您补寄那六件商品', 'resend', {}), ('给贵公司另发一批', 'resend', {}),
        ('把这批件改成航空加急', 'expedite', {}), ('安排次日达专线优先发货', 'expedite', {}),
        ('给这个订单减百分之十五', 'discount', {'pct': 15}), ('这批货按八八折结账', 'discount', {'pct': 12}),
        ('星期三之前把商品运到贵司', 'promise_time', {'when': 'wednesday'}),
        ('明晚前交到贵司库房', 'promise_time', {'when': 'tomorrow'}),
    )
    families = {
        'reported': (('承运人说可以{}。我司还没有确认。', None), ('有人提出可以{}，我只转达一下。', None)),
        'question': (('您看是否需要我们{}？', None), ('还没定，要不要{}？', None)),
        'consideration': (('他们讨论过{}。我们还在等审批。', None), ('就算可以{}，情况也未必会改变。', None)),
        'confirmed': (('我已经核实并获批，这次确定{}。', '+'), ('前面的说法有误，我方决定{}。', '+')),
        'denied': (('不用再等，本次确实不能{}。', '-'), ('说实话，这回我们无法{}。', '-')),
    }
    tails = ('', '明早我会再联系您。', '麻烦报一下运单号码。')
    for (words, act, slots), (family, phrases), tail in product(actions, families.items(), tails):
        for template, sign in phrases:
            text = template.format(words) + tail
            frames = [frame(act, sign, **slots)] if sign else []
            if '号码' in tail:
                frames.append(frame('ask_order'))
            yield text, frames, family


def main():
    train_names = ('train5_all', 'context_v5_train', 'billing_v8_train', 'composition_v9_train', 'scope_v10_train')
    known_paths = [*(CORPUS / f'{name}.jsonl' for name in train_names), *CORPUS.glob('blind*.jsonl'), *CORPUS.glob('asr_sim_*.jsonl')]
    known = {normalized(json.loads(line)['text']) for path in known_paths for line in path.read_text().splitlines() if line.strip()}
    fixture = ROOT / 'mobile/test/talk/verification_cases.json'
    known.update(normalized(example['text']) for example in json.loads(fixture.read_text()))
    records = []
    for text, frames, family in samples():
        key = normalized(text)
        if key in known:
            continue
        known.add(key)
        records.append({'text': text, 'frames': frames or [frame('none')], 'tags': [family],
                        'set': 'verification_v11_train', 'source': 'constructed_pairs'})
    out = CORPUS / 'verification_v11_train.jsonl'
    out.write_text(''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in records), encoding='utf-8')
    print(f'{len(records)} examples in {out.name}')


if __name__ == '__main__':
    main()
