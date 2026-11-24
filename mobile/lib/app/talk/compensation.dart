library;

import 'clauses.dart';
import 'nlu.dart';

final _discount = RegExp(r'打.{0,6}折|折扣|优惠|少收|减免|降价|让利|对折|半价|[一二三四五六七八九0-9]折');
final _repay = RegExp(
  r'赔偿|赔付|退款|退回|退还|返还|报销|全免|免邮|免运费|'
  r'(?:运费|邮费|快递费|配送费|差价|仓储费|额外费用).{0,7}(?:支付|出|我们包|承担|负担)|礼券|代金券|礼卡',
);
final _directRepay = RegExp(
  r'(?:运费|邮费|快递费|配送费|差价|仓储费|额外费用).{0,4}(?:由我|由本司|我们|我方|本司).{0,3}(?:承担|负担|支付|出|包)',
);
final _pending = RegExp(
  r'只能.{0,4}(?:问|申请)|可以考虑|只能考虑|只是考虑|先去问|(?:等|要先|得先).{0,10}(?:批准|同意|审批|请示)|'
  r'没有批准|还没批准|先申请|不能承诺|不能保证|不一定|看情况|只是方案|没答应',
);
final _hypothetical = RegExp(
  r'^(?:就算|假设|假如|要是|如果|即使)|(?:能不能|要不要|能否|可不可以|行不行|可以吗|好吗)$',
);
final _previousPlan = RegExp(r'^(?:之前|原先|上次|本来|原本|刚才|先前)');
final _strongNegation = RegExp(
  r'(?:没法|无法|不(?:能|会|再|给|肯|予)|拒绝|取消|取消了|作废|不作数|不行|做不到|承担不了|付不了)',
);
final _restart = RegExp(
  r'^(?:这次|但|现|改|重新|实际|更正|最新|我们现在|我现在|我刚|我们确认|确定)|(?:确定|决定|现在|同意|已经确认|刚确认)',
);

/// Preserve the classifier's default for implicit paraphrases. Where the text
/// names and revises a commitment, use the last scoped evidence for that act.
List<Frame> composeCompensation(String text, List<Frame> frames) {
  final candidates = <String, Frame?>{};
  final clean = TalkNlu.repair(text, protectAmounts: true);
  final clauses = commitmentClauses(clean, compensation: true);
  if (TalkNlu.seeksOfferApproval(clean, clauses)) {
    return frames.where((frame) => frame.key != 'discount+' && frame.key != 'compensate+').toList();
  }
  // An explicit conditional offer is intentionally resolved by the existing
  // NLU, which recognizes the condition and its consequent as one speech act.
  if (clauses.any((clause) => clause.cond || clause.afterCond)) return frames;
  for (final clause in clauses) {
    final words = clause.text;
    final offers = [
      if (_discount.hasMatch(words)) 'discount',
      if (_repay.hasMatch(words)) 'compensate',
    ];
    for (final action in offers) {
      if (quotedCommitment(words) ||
          clause.q ||
          _hypothetical.hasMatch(words) ||
          _pending.hasMatch(words)) {
        candidates.putIfAbsent(action, () => null);
        continue;
      }
      final negative = _strongNegation.hasMatch(words);
      if (_previousPlan.hasMatch(words) && !negative) {
        candidates.putIfAbsent(action, () => null);
        continue;
      }
      final recognized = frames.where((f) => f.act == action).firstOrNull;
      final explicitRepayment =
          action == 'compensate' && _directRepay.hasMatch(words);
      if (!negative &&
          recognized == null &&
          !explicitRepayment &&
          !_restart.hasMatch(words)) {
        continue;
      }
      final isOnlyClause = clauses.length == 1;
      final pct = action == 'discount' ? TalkNlu.readPct(words) : null;
      // A named continuation can revise polarity. A matching classifier frame
      // otherwise retains evidence for language as well as its confidence.
      final polarity = negative
          ? '-'
          : (!_restart.hasMatch(words) && isOnlyClause && recognized != null
                ? recognized.pol
                : '+');
      candidates[action] = Frame(
        action,
        polarity,
        recognized?.conf ?? TalkNlu.ok,
        pct: pct ?? (isOnlyClause ? recognized?.pct : null),
        span: words,
      );
    }
  }
  if (candidates.isEmpty) return frames;
  return [
    for (final f in frames)
      if (!candidates.containsKey(f.act)) f,
    ...candidates.values.nonNulls,
  ];
}
