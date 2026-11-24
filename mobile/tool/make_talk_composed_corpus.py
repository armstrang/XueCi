#!/usr/bin/env python3
"""Compose business turns from independently labelled clauses."""

import itertools
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / 'content/talk/corpus'

# A clause carries its own action and slots into the composed turn.
CLAUSES = {
    'arrival': [
        ('最迟周末前这批货会交到贵司', 'promise_time', '+', {}),
        ('保证星期五午休之前送上门', 'promise_time', '+', {'when': 'friday'}),
        ('贵司礼拜四下班前就能收货', 'promise_time', '+', {'when': 'thursday'}),
        ('后天中午货就到您仓库', 'promise_time', '+', {'when': 'dayafter'}),
        ('最晚三天之内会送达', 'promise_time', '+', {'when': '3_days'}),
        ('现在只能保证下周二交货', 'promise_time', '+', {'when': 'tuesday'}),
        ('我们三天以内送不到', 'promise_time', '-', {'when': '3_days'}),
        ('明早肯定来不及送达', 'promise_time', '-', {'when': 'tomorrow'}),
    ],
    'dispatch': [
        ('这箱我给贵司另外再寄一份', 'resend', '+', {}),
        ('我方今天会重新安排发出', 'resend', '+', {'when': 'today'}),
        ('明儿一早把漏掉的那一箱补寄出去', 'resend', '+', {'when': 'tomorrow'}),
        ('我会另发一批新的', 'resend', '+', {}),
        ('这个单子我方没法再寄一次', 'resend', '-', {}),
        ('现有的这个型号不能补发', 'resend', '-', {}),
    ],
    'cause': [
        ('晚到是因为卡在中转站了', 'cause', '+', {'reason': 'logistics'}),
        ('仓库把两张运单贴反了所以一直没到', 'cause', '+', {'reason': 'other'}),
        ('这周海上有大风货船延误了', 'cause', '+', {'reason': 'weather'}),
        ('生产线停了一天所以赶不出来', 'cause', '+', {'reason': 'factory'}),
        ('报关的材料不齐货物放不出来', 'cause', '+', {'reason': 'customs'}),
        ('原来那款一直没库存才耽误您的单', 'cause', '+', {'reason': 'stock'}),
    ],
    'compensate': [
        ('这趟额外运费由我司支付', 'compensate', '+', {}),
        ('多收的那笔钱给贵司原路划回', 'compensate', '+', {}),
        ('财务会把重复扣的钱全数返还', 'compensate', '+', {}),
        ('配送的差价算我们公司的', 'compensate', '+', {}),
        ('额外的仓储费用我们负担不了', 'compensate', '-', {}),
        ('公司不提供额外赔付', 'compensate', '-', {}),
    ],
    'discount': [
        ('这次给贵司打七五折', 'discount', '+', {'pct': 25}),
        ('这笔货款我们少收百分之十二', 'discount', '+', {'pct': 12}),
        ('我们这边可以给您打八六折', 'discount', '+', {'pct': 14}),
        ('我可以在总价上给贵司减百分之十五', 'discount', '+', {'pct': 15}),
        ('您说的六折我们实在做不到', 'discount', '-', {'pct': 40}),
        ('这一单确实不能再打折了', 'discount', '-', {}),
    ],
    'social': [
        ('请接受我们真诚的歉意', 'apologize', '+', {}),
        ('这次给您添了麻烦真过意不去', 'apologize', '+', {}),
        ('这事确实是我们操作失误', 'acknowledge', '+', {}),
        ('这次的责任在我方', 'acknowledge', '+', {}),
        ('多谢您的理解和耐心', 'thanks', '+', {}),
    ],
}

COMBINATIONS = [
    ('dispatch', 'arrival', 'compensate'), ('social', 'cause', 'arrival'), ('cause', 'discount', 'compensate'),
    ('social', 'dispatch', 'arrival'), ('arrival', 'discount', 'compensate'),
]


def rows():
    separators = [('，', '，'), ('。', '；'), ('', '')]
    for combination in COMBINATIONS:
        for index, parts in enumerate(itertools.product(*(CLAUSES[name] for name in combination))):
            a, b = separators[index % len(separators)]
            order = (0, 1, 2) if index % 2 else (1, 0, 2)
            text = a.join(parts[i][0] for i in order[:2]) + b + parts[order[2]][0] + '。'
            yield {
                'text': text,
                'frames': [{'act': parts[i][1], 'pol': parts[i][2], **parts[i][3]} for i in order],
                'tags': ['composition', 'unpunctuated' if not a else 'punctuated'],
                'set': 'composition_v9_train', 'source': 'composed_clauses',
            }


if __name__ == '__main__':
    path = CORPUS / 'composition_v9_train.jsonl'
    samples = list(rows())
    path.write_text(''.join(json.dumps(row, ensure_ascii=False) + '\n' for row in samples), encoding='utf-8')
    print(f'{len(samples)} composed turns in {path.name}')
