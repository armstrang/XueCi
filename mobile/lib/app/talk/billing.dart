library;

import 'clauses.dart';
import 'nlu.dart';

class BillingTerms {
  final bool? corrected;
  final int? refund;
  final bool withdrawsRefund, asksAmount, asksInvoice, mentionsRefund;
  const BillingTerms({
    this.corrected,
    this.refund,
    this.withdrawsRefund = false,
    this.asksAmount = false,
    this.asksInvoice = false,
    this.mentionsRefund = false,
  });

  bool get hasContent =>
      corrected != null ||
      refund != null ||
      withdrawsRefund ||
      asksAmount ||
      asksInvoice ||
      mentionsRefund;
}

const _number =
    r'(?:[0-9]+(?:[.．][0-9]{1,2})?|[零〇一二两三四五六七八九十百千万]+(?:点[零〇一二两三四五六七八九]{1,2})?)';
const _digit = r'[0-9零〇一二两三四五六七八九]';
const _cash =
    '(?:人民币|[￥¥])?($_number)(?:(?:元|块钱|块)(?:($_digit)[角毛])?(?:(?:零)?($_digit)分)?)?';
final _afterRefund = RegExp(
  '^(?:的是|给)?(?:您|你|贵司)?(?:原账户)?$_cash(?![0-9.．元块百千万一二两三四五六七八九十角毛分])',
);
final _beforeRefund = RegExp(
  '$_cash(?:差[额价]|多收款|原路|按原路|会|也|都|全数|全额|马上|给[您你]|我司|我们){0,3}\$',
);
final _shortAmount = RegExp('^(?:一共|总共|就是|是|按)?$_cash(?:整|没问题|可以)?\$');
final _invoiceAmount = RegExp(
  '(?:改成|改为|更正为|修正为|金额写成|金额填成|重开(?:一张)?)$_cash(?![0-9.．份张一二两三四五六七八九十百千万])',
);
final _moneyBack = RegExp(
  r'退还|退回|退给|退款|退到|退回去|返还|退(?!货|订|出)|打回原(?:账|帐)户|划回原(?:账|帐)户',
);
final _excess = RegExp(r'多扣|多付|多收|超收|溢收|差额|差价|重复扣');
final _whole = RegExp(r'全(部|额|数)|一分不少|一并|都|整笔');
final _invoice = RegExp(r'发票|账单|帳單|票据|对账单');
final _fix = RegExp(r'重开|重新开|更正|改正|修正|改好|改成|改为|换.{0,3}正确的|开.{0,8}(?:正确的|新的发票)');
final _noActionBefore = RegExp(
  r'(?:不(?:会|能|给|再|肯|予)|没法|无法|拒绝|取消|收回)(?:再|给[您你]|给贵司|原路|重新|为[您你]){0,3}$',
);
final _noActionAfter = RegExp(
  '^(?:不(?:了|成|算|作数)|作废|取消|$_cash(?:的退款)?(?:取消|不算|不给|不退))',
);
final _past = RegExp(r'^(?:原来|先前|之前|刚才|本来|原先|原定|上次)');
final _approvalRestriction = RegExp(
  r'待审核|待批准|等.{0,12}(?:批准|审批|同意|签字)|(?:需要|必须|得先|要先).{0,8}(?:批准|审批|同意|签字)',
);
final _pending = RegExp(
  r'还要申请|还.{0,5}(?:没确定|没同意)|不确定|先申请|可以申请|申请一下|没批准|暂不能|也许|可能|先核对|再考虑',
);
final _question = RegExp(r'吗$|行不行|能不能|可不可以|是不是|要不要|是否|多少|几多');
final _whichAmount = RegExp(r'多少|几多|哪笔|哪一笔|差额.{0,5}多少');
final _whichInvoice = RegExp(r'编号|号码|票号|哪张|哪一张');
final _foreignCurrency = RegExp(
  r'美元|美金|港币|港元|日元|韩元|欧元|英镑|印尼盾|新币|台币|澳元|新加坡元|泰铢',
);
final _additive = RegExp(r'^(?:另(?:外)?|剩下|剩余)|(?:再|还)(?:给[您你])?退');
final _remainder = RegExp(r'^(?:另外|剩下|剩余|余下)|再多退');
final _meansVoucher = RegExp(
  r'以.{0,5}(?:代金券|礼券|礼卡|购物卡|积分)|退.{0,10}(?:代金券|礼券|礼卡|积分|购物卡)',
);
final _thousands = RegExp(r'(?<=[0-9]),(?=[0-9]{3}(?:[^0-9]|$))');
final _colloquialAmount = RegExp(r'([百千万])([一二两三四五六七八九])$');
const _spokenPlace = {'百': 10, '千': 100, '万': 1000};

int? _cents(RegExpMatch? amount) {
  if (amount == null) return null;
  final raw = amount[1]!;
  final pieces = raw.split(RegExp(r'[.．点]'));
  var yuan = TalkNlu.readNumber(pieces.first)?.toInt();
  if (yuan == null || yuan < 0 || yuan > 10000000) return null;
  if (pieces.length == 1) {
    final short = _colloquialAmount.firstMatch(raw);
    if (short != null) {
      yuan +=
          TalkNlu.readNumber(short[2]!)!.toInt() *
          (_spokenPlace[short[1]]! - 1);
    }
    final dimes = TalkNlu.readNumber(amount[2] ?? '')?.toInt() ?? 0;
    final pennies = TalkNlu.readNumber(amount[3] ?? '')?.toInt() ?? 0;
    return yuan * 100 + dimes * 10 + pennies;
  }
  final cents = TalkNlu.readNumber(pieces.last)?.toInt();
  return cents == null
      ? null
      : yuan * 100 + cents * (pieces.last.length == 1 ? 10 : 1);
}

/// A refund and a correction are independent promises. Only definite words in
/// the learner's turn can change either, and an amount must belong to the refund.
BillingTerms billingTerms(
  String text, {
  required int overcharged,
  required int correctInvoice,
  int? promisedRefund,
  bool answeringAmount = false,
}) {
  bool? corrected;
  int? refund;
  var asksAmount = false,
      asksInvoice = false,
      withdrawsRefund = false,
      mentionsRefund = false;
  var mentionedInvoice = false;
  final repaired = TalkNlu.repair(
    text.replaceAll(_thousands, ''),
    protectAmounts: true,
  );
  for (final clause in commitmentClauses(repaired, billing: true)) {
    final words = clause.text;
    if (quotedCommitment(words)) continue;
    final invoice = _invoice.hasMatch(words);
    final action = _moneyBack.firstMatch(words);
    final question = clause.q || _question.hasMatch(words);
    if (question) {
      asksInvoice |= invoice && _whichInvoice.hasMatch(words);
      asksAmount |=
          _whichAmount.hasMatch(words) &&
          (_excess.hasMatch(words) || action != null);
    }
    mentionsRefund |= action != null;
    if (clause.cond || clause.afterCond || question) continue;

    final refundDenied = action != null && _declines(words, action);
    if (refundDenied) {
      refund = null;
      withdrawsRefund = true;
    }
    if (_past.hasMatch(words)) continue;
    if (_approvalRestriction.hasMatch(words)) {
      if (!invoice && !_excess.hasMatch(words) && (action == null || words.startsWith('退款'))) refund = null;
      continue;
    }
    if (_pending.hasMatch(words)) continue;

    final fix = _fix.firstMatch(words);
    if ((invoice || mentionedInvoice) && fix != null) {
      final proposedInvoice = _cents(_invoiceAmount.firstMatch(words));
      corrected =
          !_declines(words, fix) &&
          (proposedInvoice == null || proposedInvoice == correctInvoice);
    }
    mentionedInvoice |= invoice;
    if (_foreignCurrency.hasMatch(words) || _meansVoucher.hasMatch(words)) {
      continue;
    }
    if (action == null) {
      if (answeringAmount) {
        refund = _cents(_shortAmount.firstMatch(words)) ?? refund;
      }
      continue;
    }
    if (refundDenied) continue;

    final after = words.substring(action.end);
    final before = words.substring(0, action.start);
    final beforeAmount = !invoice || _excess.hasMatch(before)
        ? _beforeRefund.firstMatch(before)
        : null;
    final explicit = _cents(_afterRefund.firstMatch(after) ?? beforeAmount);
    final amount =
        explicit ??
        (_excess.hasMatch(words) && _whole.hasMatch(words)
            ? overcharged
            : null);
    if (amount != null) {
      final prior =
          refund ??
          (!withdrawsRefund && _remainder.hasMatch(words)
              ? promisedRefund
              : null);
      refund = prior != null && _additive.hasMatch(words)
          ? prior + amount
          : amount;
    }
  }
  return BillingTerms(
    corrected: corrected,
    refund: refund,
    withdrawsRefund: withdrawsRefund,
    asksAmount: asksAmount,
    asksInvoice: asksInvoice,
    mentionsRefund: mentionsRefund,
  );
}

bool _declines(String words, RegExpMatch action) =>
    _noActionBefore.hasMatch(words.substring(0, action.start)) ||
    _noActionAfter.hasMatch(words.substring(action.end));
