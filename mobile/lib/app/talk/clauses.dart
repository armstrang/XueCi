library;

import 'nlu.dart';

final _contrast = RegExp(
  r'(?<!不)但(?!是|凡|愿)(?=我|现|最|周|礼拜|星期|明|后|今|改|还|不|没|只|退款|发票|账单)',
);
final _reportingColon = RegExp(r'(说|问|原话)[：:]');
final _quoted = RegExp(
  r'^(?:客户|买家|您|你|对方|客服|经理|主管|仓库主管|仓库|快递员|快递|物流|司机|承运人|他|她|财务|会计|银行|老板)'
  r'.{0,6}?(?:说|原话|问|希望|要是|转述|提出|提过)',
);

// Topic or speaker transitions that a speech recognizer often leaves unmarked.
// Require a new predicate or a finished numeric phrase before cutting the text.
final _speakerBoundary = RegExp(
  r'(?<!让|叫|请|要求|要|想|希望|通知|告诉|让您)'
  r'(?=我(?:们)?(?:(?:刚|已经|已|现在)?(?:核实|确认|确定)|核过了|会按合同|另开|没法重开|来重开))',
);
final _updatedBySeller = RegExp(r'^(?:我|我们)(?:刚|已经|已|现在)(?:核实|确认|确定)');
final _independent = RegExp(r'^(?:但|不过|然而|另外|其实)|^(?:我|我们)(?:已经|刚|这就|一定)(?:确认|确定|核实|安排|保证|会)');
final _lateCondition = RegExp(r'(?<!不)(?:如果|前提是|要等|得先).{0,14}(?:放行|批准|审批|审核|同意|确认|库存|有货|查清|查库存|查一下库存)');
final _standaloneCondition = RegExp(r'^(?:前提是|要等|得先|要先)');
final _businessCondition = RegExp(r'^(?:如果|若是|假如|要是|假设|只要).{0,24}(?:仓库|库存|有货|缺货|主管|银行|海关|财务|老板|批准|审核|审批|放行)');
final _transportRevision = RegExp(r'(?<=发货|出库|发出|寄出)(?=(?:之前|原来|原定|刚才)(?:说|答应|承诺))');
final _billingBoundary = RegExp(
  r'(?<=[元块款票账单])(?=发票(?:我|我们|会|重开|更正|改)|账单(?:我|我们|也|会|重开|更正|改))|'
  r'(?<=发票|账单|重开)(?=(?:剩下|余下|剩余|下周再退|下个星期再退|今天再退|明天再退)|最迟[^，。]{0,8}退)',
);
final _compensationBoundary = RegExp(
  r'(?<=[折到款])(?=(?:我们|我方)?(?:现在|改成|改为|确定|同意|只给|不给))|'
  r'(?<=[折到款应])(?=(?:这次|这单|另外|此外)(?:的)?(?:运费|邮费|快递费|费用))|'
  r'(?<=[折到])(?=(?:您|客户|对方)(?:刚|刚才)?(?:说|问))',
);

/// Split only at domain cues with enough structure to represent a new thought.
/// The shared NLU still assigns punctuation, questions and conditions.
List<Clause> commitmentClauses(
  String text, {
  bool billing = false,
  bool compensation = false,
  bool firmOnly = false,
}) {
  var working = TalkNlu.withoutQuotes(text)
      .replaceAllMapped(_reportingColon, (m) => m[1]!)
      .replaceAll(_contrast, '，');
  if (billing) working = working.replaceAll(_billingBoundary, '，');
  if (compensation) working = working.replaceAll(_compensationBoundary, '，');
  if (firmOnly) working = working.replaceAll(_transportRevision, '，');
  final clauses = <Clause>[];
  var contingent = false;
  final split = TalkNlu.splitClauses(working);
  for (final clause in split) {
    if (firmOnly && _independent.hasMatch(clause.text)) contingent = false;
    if (firmOnly && clause.cond && _businessCondition.hasMatch(clause.text)) contingent = true;
    if (firmOnly && (_lateCondition.hasMatch(clause.text) || contingent && !clause.cond)) {
      if (_standaloneCondition.hasMatch(clause.text) && clauses.isNotEmpty) {
        final prev = clauses.last;
        if (!prev.cond) clauses[clauses.length - 1] = Clause(prev.text, prev.q, cond: true);
      }
      clauses.add(Clause(clause.text, clause.q, cond: true));
      continue;
    }
    if (clause.q || clause.cond || clause.afterCond) {
      clauses.add(clause);
      continue;
    }
    final boundaries = _speakerBoundary
        .allMatches(clause.text)
        .where((m) => m.start >= 4);
    var start = 0;
    for (final boundary in boundaries) {
      final before = clause.text.substring(start, boundary.start);
      final after = clause.text.substring(boundary.start);
      if (!quotedCommitment(before) && !billing && !(firmOnly && _updatedBySeller.hasMatch(after))) continue;
      clauses.add(Clause(before, false));
      start = boundary.start;
    }
    clauses.add(Clause(clause.text.substring(start), false));
  }
  return clauses;
}

bool quotedCommitment(String clause) => _quoted.hasMatch(clause);
