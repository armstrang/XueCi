#!/usr/bin/env python3
"""Add contrast examples for promises, inquiries, quotes, and reversals in billing."""

import json
from itertools import product

from make_talk_context_corpus import CORPUS, ROOT, frame, normalized


def rows():
    amounts = ('七十元', '一百六十块', '88.50元', '三百二十块', '四百五十元', '620元')
    affirmative = (
        '贵司多付了{money}，款项我们今天原路划回。',
        '这笔重复扣的{money}，我把它退给贵司。',
        '差额是{money}，我马上将这笔钱返还。',
        '我已经核实，{money}会退到当时付款的账户。',
        '我们现在就退{money}，请留意入账通知。',
        '财务将把多收的{money}打回原账户。',
        '按照合同，这笔{money}我们会全数退还。',
        '对账确认有误，给您原路退回{money}。',
        '那{money}由我司原渠道返还，您等到账即可。',
        '这是一笔多收款，我们从原支付渠道退回{money}。',
    )
    pending = (
        '那{money}能不能退还，得等财务签字。',
        '关于退{money}，我先把您的意见交给主管。',
        '账面差了{money}，要不要退回需要另开会。',
        '我尚未收到批准，{money}的退款还在审核。',
        '您刚提到退{money}，我先核对银行流水。',
        '如果把{money}退了就好了，但现阶段只是讨论。',
        '您问可不可以退{money}，我明早再答复。',
        '上星期同事说可能退{money}，我没有确认。',
        '那笔{money}只是用来核对的数，不是退款承诺。',
        '我可以申请退{money}，没有批准前不作承诺。',
    )
    negated = (
        '关于{money}的现金赔付，公司明确拒绝承担。',
        '这笔{money}不会报销，也不会另送礼券。',
        '合同没有{money}额外赔偿这一项。',
        '这笔{money}的手续费不能由我方负担。',
        '我们无法承担这{money}的额外运费。',
    )
    for money in amounts:
        for pattern in affirmative:
            yield 'refund_confirmed', pattern.format(money=money), [frame('compensate')]
        for pattern in pending:
            yield 'refund_pending_or_reported', pattern.format(money=money), []
        for pattern in negated:
            yield 'other_compensation_refused', pattern.format(money=money), [frame('compensate', '-')]

    replacements = (
        ('把新发票发给贵司', '开好的更正发票发给您', '更正发票上的金额'),
        ('更正账单上的总价', '重新开一张金额正确的票', '账单上的金额更新'),
        ('把重复入账的那一笔冲掉', '撤掉旧账单再出一份', '把那条记录标成作废'),
    )
    apologies = ('给您添麻烦了，向您致歉。', '对不住。', '真抱歉。', '不好意思，让您久等了。')
    for (fix, revised, reminder), apology, money in product(replacements, apologies, amounts):
        yield 'apology_and_refund', f'{apology}我们先{fix}，多扣的{money}也全数退回。', [frame('apologize'), frame('compensate')]
        yield 'paperwork_only', f'我们会{revised}。{reminder}之后再通知您。', []
        yield 'mixed_with_quote', f'买家问退{money}可不可以。{apology}我现在先{fix}。', [frame('apologize')]

    discounts = [('九二折', 8), ('七五折', 25), ('九折', 10), ('八六折', 14), ('六五折', 35)]
    roles = ('这次给贵司', '这张单就给您', '针对这次订单，我给您', '算上这次差错，给您')
    for (discount, pct), front, money in product(discounts, roles, amounts):
        yield 'discount_with_accounting_amount', f'{front}打{discount}。账面上有一笔{money}我们还要先对一下。', [frame('discount', pct=pct)]
        yield 'discount_plus_real_refund', f'{front}打{discount}，另外重复扣的{money}也原路退回。', [frame('discount', pct=pct), frame('compensate')]
        yield 'discount_refused_refund_kept', f'这回打{discount}不行，实际多收那{money}我们会给您退回去。', [frame('discount', '-'), frame('compensate')]

    inquiries = (
        '给我一下您那边的订购编号，方便调出原始流水。', '请说一下订单号码，我对一下合同。',
        '麻烦发订单编号，我看哪一笔重复记账了。', '劳驾报一下这次的订单号。',
        '我能看一下这张订单的编号吗？', '您手头有这单的订货号码吗？',
        '这笔付款关联的订单编号是什么？', '您把订单号给我吧，我请会计认一下。',
    )
    for inquiry, apology in product(inquiries, apologies):
        yield 'ask_order_with_apology', f'{apology}{inquiry}', [frame('apologize'), frame('ask_order')]


def main():
    test = ROOT / 'mobile/test/talk/billing_cases.json'
    reserved = [CORPUS / 'train5_all.jsonl', CORPUS / 'context_v5_train.jsonl', *CORPUS.glob('blind*.jsonl'),
                *CORPUS.glob('asr_sim_*.jsonl')]
    seen = {normalized(json.loads(line)['text']) for path in reserved for line in path.read_text().splitlines() if line.strip()}
    if test.exists():
        seen.update(normalized(text) for case in json.loads(test.read_text()) for text in [*case.get('before', []), case['text']])
    path = CORPUS / 'billing_v8_train.jsonl'
    counts = {}
    with path.open('w', encoding='utf-8') as out:
        for family, text, acts in rows():
            key = normalized(text)
            if key in seen:
                continue
            seen.add(key)
            counts[family] = counts.get(family, 0) + 1
            row = {'text': text, 'frames': acts or [frame('none')], 'tags': [family],
                   'set': 'billing_v8_train', 'source': 'constructed_pairs'}
            out.write(json.dumps(row, ensure_ascii=False) + '\n')
    print(sum(counts.values()), path.name, counts)


if __name__ == '__main__':
    main()
