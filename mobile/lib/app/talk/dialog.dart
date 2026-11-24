/// A client who reasons: what the learner said (frames from TalkNlu) changes what the client still needs, how the
/// client feels and how much patience is left, and the client's next line follows from that, never from a fixed
/// script. The client wants an explanation, an arrival by the deadline, and something for the trouble
/// (a discount of at least [Scenario.minPct], or another compensation). Apologies affect rapport and coaching. Being rude (blaming
/// others, refusing) costs mood; apologizing, understanding and politeness win it back. Every run ends: well, fair,
/// or with the client gone.
library;

import 'dart:math';

import 'billing.dart';
import 'practice.dart' show PracticeGoal;
import 'clauses.dart';
import 'compensation.dart';
import 'delivery.dart';
import 'nlu.dart';

/// days from "today" (the scenario's day) for each `when` the engine reads
int? daysOf(String? when, {int today = 1}) {
  if (when == null) return null;
  const week = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  switch (when) {
    case 'today':
      return 0;
    case 'tomorrow':
      return 1;
    case 'dayafter':
      return 2;
  }
  final w = week.indexOf(when);
  if (w >= 0) return (w - today + 7) % 7;
  final m = RegExp(r'^(\d+)_days$').firstMatch(when);
  return m == null ? null : int.parse(m[1]!);
}

class Line {
  final String zh, id;
  const Line(this.zh, this.id);
}

class Scenario {
  final String id, title, client;

  /// today's weekday (0 Monday) and the day the goods must be there (days from today)
  final int today, deadline;
  final String deadlineZh, deadlineId;

  /// the smallest discount (percent) the client takes
  final int minPct;
  final int patience;
  final PracticeGoal? practice;
  final bool requiresReplacement;
  final int? overchargeCents, correctInvoiceCents;
  bool get requiresBilling => overchargeCents != null;

  /// what the client says, by situation; {d} = the deadline, {p} = the discount offered, {m} = the minimum
  final Map<String, List<Line>> lines;
  const Scenario({
    required this.id,
    required this.title,
    required this.client,
    required this.today,
    required this.deadline,
    required this.deadlineZh,
    required this.deadlineId,
    required this.minPct,
    required this.patience,
    this.practice,
    this.requiresReplacement = false,
    this.overchargeCents,
    this.correctInvoiceCents,
    required this.lines,
  }) : assert((overchargeCents == null) == (correctInvoiceCents == null));
}

/// what the client still wants
enum Need { reason, replacement, delivery, compensation, refund, invoice, close }

class Turn {
  final String said;
  final List<Frame> frames;
  final Line reply;
  final String situation;
  final int mood;
  Turn(this.said, this.frames, this.reply, this.situation, this.mood);
}

class ClientState {
  int mood = 0, patience, turns = 0, refusals = 0, denials = 0;
  bool apology = false, reason = false, delivery = false, compensation = false, closed = false;
  bool askedWhen = false, gaveUpCompensation = false;
  int? offeredDays, offeredPct;
  int? dispatchDays;
  bool otherCompensation = false;
  bool? replacementChoice;
  bool get replacement => replacementChoice == true;
  bool invoiceCorrected = false;
  int? refundCents;
  bool answeredDeadline = false, answeredOrder = false;
  String? end; // good, fair, lost
  final Set<String> heard = {};
  ClientState(this.patience);
}

class TalkDialog {
  final Scenario sc;
  final ClientState st;
  final Random _rnd;
  final List<Turn> turns = [];
  TalkDialog(this.sc, {int seed = 1})
      : st = ClientState(sc.patience),
        _rnd = Random(seed);

  bool get over => st.end != null;

  Line _say(String situation) {
    final l = sc.lines[situation]!;
    final x = l[_rnd.nextInt(l.length)];
    String f(String s, bool zh) => s
        .replaceAll('{d}', zh ? sc.deadlineZh : sc.deadlineId)
        .replaceAll('{p}', st.offeredPct == null ? '' : (zh ? _zhe(st.offeredPct!) : '${st.offeredPct}%'))
        .replaceAll('{m}', zh ? _zhe(sc.minPct) : '${sc.minPct}%');
    return Line(f(x.zh, true), f(x.id, false));
  }

  static String _zhe(int pct) {
    const n = '零一二三四五六七八九';
    final paid = 100 - pct;
    if (paid % 10 == 0) return '${n[paid ~/ 10]}折';
    return '${n[paid ~/ 10]}${n[paid % 10]}折';
  }

  /// the client's opening line
  Line open() => sc.practice?.prompt ?? _say('open');

  bool practiceAccepted(String text) {
    final goal = sc.practice!;
    return commitmentClauses(TalkNlu.repair(text), firmOnly: true).any((c) =>
        !c.q && !c.cond && !quotedCommitment(c.text) &&
        !RegExp(r'不能|没法|不会|不行|不打算|不接受|不同意|没有|无货|还没|尚未|只能考虑|待确认').hasMatch(c.text) &&
        goal.action.hasMatch(c.text) && goal.detail.hasMatch(c.text));
  }

  /// what the client needs next
  Need get next {
    if (sc.requiresBilling) {
      if (st.refundCents != sc.overchargeCents) return Need.refund;
      return st.invoiceCorrected ? Need.close : Need.invoice;
    }
    if (sc.requiresReplacement && !st.replacement) return Need.replacement;
    if (!sc.requiresReplacement && !st.reason) return Need.reason;
    if (!st.delivery) return Need.delivery;
    if (!sc.requiresReplacement && !st.compensation && !st.gaveUpCompensation) return Need.compensation;
    return Need.close;
  }

  static final _irrelevant = RegExp(r'学校|老师|同学|电影|球赛|食堂|图书馆|停车位|地铁|猫|咖啡|天气真不错');
  static final _uncommittedOffer = RegExp(r'只能.{0,4}(?:问|申请)|(?:还|现在|今天)?(?:不|没)(?:能|法|办法)(?:先|就|马上)?(?:答应|承诺|保证)|只.{0,6}考虑|可以考虑|只能考虑|先去问|要先.{0,4}(?:审批|请示)');
  static final _actualCompensation = RegExp(r'(?:我们|我方|这次|现在|今天|可以|愿意|同意|答应).{0,7}(?:给您|给你|给贵司|给贵公司|为您)(?:打|退|赔|减)|(?:打|给您|给你).{0,5}折|(?:费用|运费|差价|邮费).{0,4}(?:我们|我方)(?:来|先)?(?:承担|出|付)');
  static final _business = RegExp(r'订单|订货|货物|这批|商品|包裹|到货|补发|运费|赔偿|退款|物流|快递|交付|发货|送到|晚到|延误|贵公司|仓库|库存|海关|承运|折扣|收货');

  bool _unrelated(String text) => _irrelevant.hasMatch(text) && !_business.hasMatch(text);

  /// Keep courtesy and model-only offers from advancing the wrong business need.
  List<Frame> contextualFrames(String text, List<Frame> frames) {
    if (_unrelated(text)) return const [];
    if (!sc.requiresBilling && !sc.requiresReplacement) frames = composeCompensation(text, frames);
    if (!_uncommittedOffer.hasMatch(text)) return frames;
    final explicitOffer = TalkNlu.splitClauses(text).any(
        (c) => !c.cond && !c.q && !_uncommittedOffer.hasMatch(c.text) && _actualCompensation.hasMatch(c.text));
    if (explicitOffer) return frames;
    return frames.where((f) => f.key != 'discount+' && f.key != 'compensate+').toList();
  }

  DeliveryTerms _terms(String text, List<Frame> frames) {
    if (_unrelated(text) && frames.isEmpty) {
      return (dispatch: null, arrival: null, replacesArrival: false, needsDate: false);
    }
    const asksArrival = {'when', 'whenAgain', 'whichDay', 'tooLate', 'deadlineAnswer'};
    return deliveryTerms(text, frames,
        today: sc.today, deadline: sc.deadline, answeringArrival: asksArrival.contains(turns.lastOrNull?.situation));
  }

  static final _replacementAction = RegExp(r'换成|更换|换给|换货|改成|换[一蓝红黑白]|给您换|给你换|重新寄|重新发|补发|补寄|寄出');
  static final _color = RegExp(r'(蓝|红|黑|白)(?:色|款|的|版)');
  static final _noReplacement = RegExp(r'没货|没有库存|缺货|不能换|不换|没法换|无法换|换不了|不保证|不能确定');
  static final _otherSpeaker = RegExp(r'^(您|你|客户|买家|他说).{0,5}(说|问|想|要的是)');
  static final _unconfirmedItem = RegExp(r'要不要|能不能|是否|是不是|可以吗|可以考虑|申请一下');
  static final _historicItem = RegExp(r'^(原先|原来|本来|以前|刚才|之前)');
  static final _doubleNegativeItem = RegExp(r'不是不能换|并非不能换|不会不换');
  static final _confirmedReplacement = RegExp(r'(?:这就|马上|确定|肯定|一定|就).{0,5}(?:换|补发|补寄|重新发|重新寄)');

  /// This client needs the blue item. A color in a quote, a question, or a
  /// description of the original order does not offer a replacement.
  bool? _replacementOffer(String text) {
    if (!sc.requiresReplacement) return null;
    bool? offered;
    String? tentativeColor;
    for (final clause in commitmentClauses(TalkNlu.repair(text), firmOnly: true)) {
      final words = clause.text;
      if (clause.cond || clause.q || _otherSpeaker.hasMatch(words) || _unconfirmedItem.hasMatch(words) ||
          _historicItem.hasMatch(words) || quotedCommitment(words)) {
        continue;
      }
      final color = _color.allMatches(words).lastOrNull?.group(1);
      if (_doubleNegativeItem.hasMatch(words)) {
        tentativeColor = color;
        continue;
      }
      if (tentativeColor != null && _confirmedReplacement.hasMatch(words) && !_noReplacement.hasMatch(words)) {
        offered = (color ?? tentativeColor) == '蓝';
        tentativeColor = null;
      }
      if (color == null) continue;
      if (_noReplacement.hasMatch(words)) {
        if (color == '蓝') offered = false;
        continue;
      }
      final shortConfirmation = turns.lastOrNull?.situation == 'whichItem' &&
          RegExp(r'^(?:是|对|可以|换|就用)?(?:蓝|红|黑|白)(?:色(?:款|的)?|款|的|版)(?:没问题|可以)?$').hasMatch(words);
      if (_replacementAction.hasMatch(words) || shortConfirmation) offered = color == '蓝';
    }
    return offered;
  }

  bool _asksReplacement(String text) => sc.requiresReplacement && commitmentClauses(TalkNlu.repair(text)).any(
        (c) => (c.q || _unconfirmedItem.hasMatch(c.text)) && _replacementAction.hasMatch(c.text) &&
            _color.hasMatch(c.text) && !quotedCommitment(c.text),
      );

  bool understandsReply(String text, List<Frame> frames) =>
      (sc.practice != null && text.trim().isNotEmpty) || frames.isNotEmpty || _billingTerms(text).hasContent || commitments(text, frames).isNotEmpty || _asksReplacement(text);

  BillingTerms _billingTerms(String text) {
    final amount = sc.overchargeCents;
    if (amount == null) return const BillingTerms();
    const asksRefund = {'whichRefund', 'wrongRefund'};
    return billingTerms(text, overcharged: amount, correctInvoice: sc.correctInvoiceCents!, promisedRefund: st.refundCents,
        answeringAmount: asksRefund.contains(turns.lastOrNull?.situation));
  }

  /// Comparable facts from one transcript. Missing values are left out so a
  /// truncated alternative does not veto a clear primary reading.
  Map<String, String> commitments(String text, List<Frame> recognized) {
    final frames = contextualFrames(text, recognized);
    final transport = _terms(text, frames);
    final replacement = _replacementOffer(text);
    final bill = _billingTerms(text);
    final result = <String, String>{
      if (replacement != null) 'replacement': replacement ? 'blue' : 'unavailable',
      if (!sc.requiresBilling && transport.replacesArrival) 'arrival': '${transport.arrival ?? "withdrawn"}',
      if (!sc.requiresBilling && transport.dispatch != null) 'dispatch': '${transport.dispatch}',
      if (bill.corrected != null) 'invoice': '${bill.corrected}',
      if (bill.refund != null || bill.withdrawsRefund) 'refund': '${bill.refund ?? "withdrawn"}',
    };
    for (final f in frames) {
      if (f.act == 'discount') {
        if (f.pol == '-') {
          result['discount'] = 'no';
        } else if (f.pct != null) {
          result['discount'] = '${f.pct}';
        }
      }
      if (f.act == 'compensate' || f.act == 'deny_fault') result[f.act] = f.pol;
      if (f.act == 'acknowledge' && f.pol == '+') result['responsibility'] = 'accepted';
      if (f.act == 'deny_fault' && f.pol == '+') result['responsibility'] = 'denied';
      if (f.act == 'cause' && f.pol == '+' && f.reason != null) result['cause'] = f.reason!;
      if (!sc.requiresBilling && f.act == 'promise_time' && f.pol == '-' && !transport.replacesArrival) {
        result['arrival'] = 'withdrawn';
      }
    }
    return result;
  }

  /// A practice score for this reply using the current client need.
  /// The draft does not mutate conversation state or reward a recognizer confidence value.
  int turnScore(String text, List<Frame> recognized) {
    final goal = sc.practice;
    if (goal != null) {
      if (practiceAccepted(text)) return RegExp(r'您|请|谢谢').hasMatch(text) ? 10 : 8;
      return goal.action.hasMatch(text) ? 4 : 1;
    }
    final frames = contextualFrames(text, recognized);
    final keys = frames.map((f) => f.key).toSet();
    if (sc.requiresBilling) return _billingScore(_billingTerms(text), keys);
    final transport = _terms(text, frames);
    final proposedItem = _replacementOffer(text);
    final badArrival = transport.arrival != null && transport.arrival! > sc.deadline;
    final timelyArrival = transport.arrival != null && !badArrival;
    final reason = keys.contains('cause+');
    final compensation = keys.contains('compensate+') ||
        frames.any((f) => f.key == 'discount+' && f.pct != null && f.pct! >= sc.minPct);
    final apologized = keys.contains('apologize+') || keys.contains('acknowledge+');
    final closing = keys.contains('thanks+') || keys.contains('closing+');
    final question = keys.contains('ask_deadline+') || keys.contains('ask_order+');
    final addressed = switch (next) {
      Need.reason => reason,
      Need.replacement => proposedItem == true,
      Need.delivery => timelyArrival,
      Need.compensation => compensation,
      Need.refund || Need.invoice => false,
      Need.close => closing,
    };
    final useful = [reason, proposedItem == true, timelyArrival, compensation, apologized, question].where((v) => v).length;
    if (badArrival || keys.contains('deny_fault+')) return useful > 0 ? 5 : 3;
    if (addressed) return min(10, 8 + max(0, useful - 1));
    if (timelyArrival || reason || compensation) return min(7, 5 + useful);
    if (transport.dispatch != null || transport.needsDate || question) return 5;
    if (apologized || closing) return 4;
    if (keys.contains('greet+')) return 2;
    return 1;
  }

  int _billingScore(BillingTerms bill, Set<String> keys) {
    final refund = bill.refund == sc.overchargeCents;
    final invoice = bill.corrected == true;
    final polite = keys.any(const {'apologize+', 'acknowledge+', 'thanks+', 'closing+'}.contains);
    if (keys.contains('deny_fault+')) return 2;
    if (refund && invoice) return polite ? 10 : 9;
    if (refund) return next == Need.refund ? 8 : 6;
    if (bill.refund != null) return invoice ? 5 : 3;
    if (invoice) return next == Need.invoice ? 8 : 6;
    if (bill.asksAmount || bill.asksInvoice || keys.contains('ask_order+')) return 5;
    return polite ? 4 : 1;
  }

  /// one turn: [frames] are what the engine took as said (conf >= ok); [text] is what was heard
  Line reply(String text, List<Frame> frames) {
    final goal = sc.practice;
    if (goal != null) {
      if (over) return turns.last.reply;
      st.turns++;
      final passed = practiceAccepted(text);
      if (passed || st.turns >= sc.patience) st.end = passed ? 'good' : 'lost';
      final line = passed
          ? const Line('好，我确认了，谢谢。', 'Baik, saya sudah mengonfirmasi. Terima kasih.')
          : st.end != null
              ? const Line('这次先到这里吧。', 'Kita cukupkan sampai di sini dulu.')
              : goal.prompt;
      turns.add(Turn(text, frames, line, passed ? 'settled' : 'open', st.mood));
      return line;
    }
    if (over) return _say('bye');
    frames = contextualFrames(text, frames);
    st.turns++;
    final has = {for (final f in frames) f.key};
    st.heard.addAll(has);
    String situation;

    // mood
    final polite = RegExp('(您|请|麻烦|贵公司|不好意思|谢谢|感谢)').allMatches(text).length;
    if (has.contains('apologize+') && !st.apology) st.mood += 1;
    if (has.contains('acknowledge+')) st.mood += 1;
    if (polite >= 2) st.mood += 1;
    if (has.contains('deny_fault+')) {
      st.mood -= 2;
      st.denials++;
    }
    if (has.contains('apologize-')) st.mood -= 2;
    st.mood = st.mood.clamp(-4, 3);

    // needs
    if (has.contains('apologize+') || (has.contains('acknowledge+') && st.turns > 1)) st.apology = true;
    if (sc.requiresBilling) return _replyBilling(text, frames, has);
    if (frames.any((f) => f.act == 'cause' && f.pol == '+')) st.reason = true;
    final item = _replacementOffer(text);
    if (item != null) {
      if (!item || (st.replacementChoice != null && st.replacementChoice != item)) {
        st.delivery = false;
        st.offeredDays = null;
        st.closed = false;
      }
      st.replacementChoice = item;
    }
    final delivery = _terms(text, frames);
    final itemQuestion = _asksReplacement(text);
    final hasContent = frames.isNotEmpty || item != null || itemQuestion || delivery.replacesArrival || delivery.dispatch != null;
    if (delivery.dispatch != null) st.dispatchDays = delivery.dispatch;
    if (delivery.replacesArrival && item != false) {
      st.offeredDays = delivery.arrival;
      st.delivery = delivery.arrival != null && delivery.arrival! <= sc.deadline;
      if (!st.delivery) st.closed = false;
    }
    final late = delivery.replacesArrival && delivery.arrival != null && !st.delivery;
    final noDay = delivery.needsDate && !st.delivery;
    var lowPct = false, pctUnknown = false;
    if (has.contains('discount-')) st.offeredPct = null;
    if (has.contains('compensate-')) st.otherCompensation = false;
    for (final f in frames.where((f) => f.pol == '+' && f.act == 'discount')) {
      if (f.pct == null) {
        pctUnknown = true;
      } else {
        st.offeredPct = f.pct;
        lowPct = f.pct! < sc.minPct;
      }
    }
    if (has.contains('compensate+')) st.otherCompensation = true;
    st.compensation = st.otherCompensation || (st.offeredPct ?? -1) >= sc.minPct;
    if (!sc.requiresReplacement && !st.compensation) st.closed = false;
    final refused = has.contains('refuse+') || has.contains('discount-') || has.contains('compensate-');
    if (refused && !st.compensation) {
      st.refusals++;
      st.mood -= 1;
    }
    final closing = has.contains('thanks+') || has.contains('closing+');

    // the end
    if (st.mood <= -3 || st.denials >= 2 || (!hasContent && st.patience <= 1)) {
      st.end = 'lost';
      return _record(text, frames, 'lost');
    }
    if (st.turns >= 12) {
      st.end = st.delivery && (!sc.requiresReplacement || st.replacement) ? 'fair' : 'lost';
      return _record(text, frames, st.end == 'fair' ? 'fair' : 'lost');
    }
    if (!hasContent) {
      st.patience--;
      return _record(text, frames, 'unclear');
    }

    if (has.contains('deny_fault+')) {
      situation = 'deny';
    } else if (refused && !sc.requiresReplacement && !st.compensation && st.delivery) {
      if (st.refusals >= 2) {
        st.gaveUpCompensation = true;
        st.mood -= 1;
        situation = st.mood <= -2 ? 'lost' : 'grudge';
        if (situation == 'lost') st.end = 'lost';
      } else {
        situation = 'pushComp';
      }
    } else if (late && (!sc.requiresReplacement || st.replacement)) {
      st.patience--;
      situation = 'tooLate';
    } else if (has.contains('ask_order+') && !st.answeredOrder && sc.lines.containsKey('orderAnswer')) {
      st.answeredOrder = true;
      situation = 'orderAnswer';
    } else if (has.contains('ask_deadline+') && !st.delivery && !st.answeredDeadline) {
      st.answeredDeadline = true;
      st.askedWhen = true;
      situation = sc.lines.containsKey('deadlineAnswer') ? 'deadlineAnswer' : 'when';
    } else if (noDay && (!sc.requiresReplacement || st.replacement)) {
      st.askedWhen = true;
      situation = 'whichDay';
    } else if (lowPct && !sc.requiresReplacement && !st.compensation) {
      situation = 'lowPct';
    } else if (pctUnknown && !sc.requiresReplacement && !st.compensation) {
      situation = 'howMuch';
    } else {
      switch (next) {
        case Need.reason:
          situation = st.apology || !sc.lines.containsKey('whyDirect') ? 'why' : 'whyDirect';
        case Need.replacement:
          situation = 'whichItem';
        case Need.delivery:
          situation = st.askedWhen ? 'whenAgain' : 'when';
          st.askedWhen = true;
        case Need.compensation:
          situation = st.mood >= 2 ? 'compSoft' : 'comp';
        case Need.refund || Need.invoice:
          throw StateError('Billing needs a billing reply');
        case Need.close:
          if (closing || st.closed) {
            st.end = st.mood >= 1 ? 'good' : 'fair';
            situation = st.end == 'good' ? 'byeGood' : 'byeFair';
          } else {
            st.closed = true;
            situation = 'settled';
          }
      }
    }
    if (situation == 'settled' && closing) {
      st.end = st.mood >= 1 ? 'good' : 'fair';
      situation = st.end == 'good' ? 'byeGood' : 'byeFair';
    }
    if (st.patience <= 0 && st.end == null) {
      st.end = 'lost';
      situation = 'lost';
    }
    return _record(text, frames, situation);
  }

  Line _replyBilling(String text, List<Frame> frames, Set<String> has) {
    final bill = _billingTerms(text);
    if (bill.corrected != null) st.invoiceCorrected = bill.corrected!;
    if (bill.refund != null || bill.withdrawsRefund) st.refundCents = bill.refund;
    if (next != Need.close) st.closed = false;

    final String situation;
    if (st.mood <= -3 || st.denials >= 2 || (st.turns >= 12 && next != Need.close)) {
      st.end = 'lost';
      situation = 'lost';
    } else if (next == Need.close && (st.closed || _billingFarewell.hasMatch(TalkNlu.repair(text)) || st.turns >= 12)) {
      st.end = st.mood >= 1 ? 'good' : 'fair';
      situation = st.end == 'good' ? 'byeGood' : 'byeFair';
    } else if (next == Need.close) {
      st.closed = true;
      situation = 'settled';
    } else if (has.contains('deny_fault+')) {
      situation = 'deny';
    } else if (bill.asksAmount) {
      situation = 'amountAnswer';
    } else if (bill.asksInvoice || has.contains('ask_order+')) {
      situation = 'invoiceAnswer';
    } else if (next == Need.invoice) {
      situation = 'correctInvoice';
    } else if (st.refundCents != null) {
      situation = 'wrongRefund';
    } else {
      situation = 'whichRefund';
    }
    return _record(text, frames, situation);
  }

  static final _billingFarewell = RegExp(r'谢谢|感谢|再见|拜拜|期待.{0,5}合作');

  Line _record(String text, List<Frame> frames, String situation) {
    final l = _say(situation);
    turns.add(Turn(text, frames, l, situation, st.mood));
    return l;
  }
}

/// the late delivery: Mr Wang ordered a batch three days ago; he needs it by Friday (today is Tuesday)
const lateDelivery = Scenario(
  id: 'late',
  title: 'Pengiriman terlambat',
  client: 'Pak Wang, pembeli',
  today: 1,
  deadline: 3,
  deadlineZh: '星期五',
  deadlineId: 'Jumat',
  minPct: 10,
  patience: 5,
  lines: {
    'open': [
      Line('喂，你好。我订的货已经晚了三天，到底是怎么回事？', 'Halo. Pesanan saya sudah terlambat tiga hari, sebenarnya ada apa?'),
      Line('你好，我是王先生。我们的货怎么还没到？已经晚了三天了。', 'Halo, saya Pak Wang. Kenapa barang kami belum sampai? Sudah terlambat tiga hari.'),
    ],
    'wantSorry': [
      Line('你先别解释。货晚了三天，你们连一句道歉都没有吗？', 'Jangan menjelaskan dulu. Barang terlambat tiga hari, kalian tidak minta maaf sama sekali?'),
      Line('我现在很生气。你们至少应该先道个歉吧？', 'Saya sangat kesal. Setidaknya kalian minta maaf dulu, kan?'),
    ],
    'wantSorry2': [
      Line('我已经说了，你们到现在还没道歉。', 'Saya sudah bilang, sampai sekarang kalian belum minta maaf.'),
      Line('说了半天，一句对不起都没有？', 'Sudah bicara panjang, tidak ada satu pun permintaan maaf?'),
    ],
    'whyDirect': [
      Line('我先想弄清楚，货为什么会晚？', 'Saya ingin tahu dulu kenapa barangnya terlambat.'),
      Line('订单是在哪一步耽误的？', 'Di tahap mana pesanan ini tertunda?'),
    ],
    'why': [
      Line('好吧。那到底是什么原因晚了？', 'Baiklah. Sebenarnya apa penyebab terlambatnya?'),
      Line('道歉我收到了。可是为什么会晚这么久？', 'Permintaan maafnya saya terima. Tapi kenapa bisa terlambat selama ini?'),
    ],
    'when': [
      Line('明白了。那你们什么时候能送到？我{d}之前一定要用。', 'Saya mengerti. Lalu kapan kalian bisa mengirimnya? Saya harus memakainya sebelum {d}.'),
      Line('原因我知道了。现在最重要的是，货什么时候到？我{d}就要用。', 'Penyebabnya sudah saya tahu. Yang penting sekarang, kapan barangnya tiba? Saya butuh hari {d}.'),
    ],
    'orderAnswer': [
      Line('订单号是XC-2048。麻烦您帮我查一下。', 'Nomor pesanan XC-2048. Tolong cek pesanannya.'),
    ],
    'deadlineAnswer': [
      Line('我{d}要用。最晚{d}得送到。你能确认到货时间吗？', 'Saya perlu barangnya hari {d}. Paling lambat harus tiba hari itu. Bisa pastikan kapan sampai?'),
    ],
    'whenAgain': [
      Line('你还是没告诉我哪天能到。', 'Kamu masih belum bilang hari apa barangnya tiba.'),
    ],
    'whichDay': [
      Line('具体哪天能到？我{d}之前必须收到。', 'Tepatnya hari apa tiba? Saya harus menerimanya sebelum {d}.'),
      Line('你说会送，那是哪一天？', 'Katamu akan dikirim, itu hari apa?'),
    ],
    'tooLate': [
      Line('那太晚了。我{d}就要用，能不能快一点？', 'Itu terlalu lambat. Saya butuh hari {d}, bisa lebih cepat?'),
      Line('不行，{d}之后我就用不上了。你们得想想办法。', 'Tidak bisa, setelah {d} barangnya sudah tidak berguna. Kalian harus cari cara.'),
    ],
    'comp': [
      Line('时间可以。可是这次耽误了我们的生产，你们打算怎么补偿？', 'Waktunya bisa. Tapi ini mengganggu produksi kami, bagaimana kalian akan memberi kompensasi?'),
      Line('好，那就这么送。不过晚了这么久，总得给点补偿吧？', 'Baik, kirim begitu saja. Tapi terlambat selama ini, harus ada kompensasi, kan?'),
    ],
    'compSoft': [
      Line('你们的态度我很满意。不过价格上能不能表示一下？', 'Saya puas dengan sikap kalian. Tapi bisakah ada sedikit keringanan harga?'),
    ],
    'howMuch': [
      Line('优惠是多少？打几折？', 'Diskonnya berapa? Berapa persen?'),
    ],
    'lowPct': [
      Line('{p}太少了，至少{m}吧。', '{p} terlalu sedikit, paling tidak {m}.'),
      Line('{p}？这次的损失可不止这些。{m}怎么样？', '{p}? Kerugian kali ini jauh lebih besar. Bagaimana kalau {m}?'),
    ],
    'pushComp': [
      Line('一点补偿都没有？你们这样我很难跟老板交代。', 'Tidak ada kompensasi sama sekali? Kalau begini saya sulit menjelaskan ke atasan.'),
    ],
    'grudge': [
      Line('好吧，这次就算了。希望下次别再这样。', 'Baiklah, kali ini sudahlah. Semoga lain kali tidak begini lagi.'),
    ],
    'deny': [
      Line('我不管是谁的问题，我只要我的货。', 'Saya tidak peduli salah siapa, saya hanya mau barang saya.'),
      Line('推来推去有什么用？你们是卖方，你们负责。', 'Saling lempar tanggung jawab untuk apa? Kalian penjualnya, kalian yang bertanggung jawab.'),
    ],
    'settled': [
      Line('好，那就按你说的办。', 'Baik, kita lakukan seperti katamu.'),
      Line('行，这样我可以接受。', 'Oke, kalau begini saya bisa terima.'),
    ],
    'byeGood': [
      Line('谢谢你，处理得很好。我们以后继续合作。', 'Terima kasih, penanganannya bagus. Kita lanjutkan kerja sama.'),
      Line('好的，辛苦了。再见。', 'Baik, terima kasih atas kerja kerasnya. Sampai jumpa.'),
    ],
    'byeFair': [
      Line('好吧，先这样。再见。', 'Baiklah, sampai di sini dulu. Sampai jumpa.'),
    ],
    'unclear': [
      Line('不好意思，我没听清楚，请你再说一遍。', 'Maaf, saya kurang jelas, tolong ulangi.'),
      Line('你说什么？我没明白。', 'Kamu bilang apa? Saya tidak mengerti.'),
    ],
    'lost': [
      Line('算了，我直接找你们经理。', 'Sudahlah, saya langsung bicara dengan manajer kalian.'),
      Line('这样的话，我们以后就不合作了。', 'Kalau begini, kami tidak akan bekerja sama lagi.'),
    ],
    'fair': [
      Line('好吧，先这样吧。', 'Baiklah, begitu saja dulu.'),
    ],
    'bye': [
      Line('再见。', 'Sampai jumpa.'),
    ],
  },
);


/// A replacement request tests the promised item and arrival time instead of
/// making a discount or an apology sufficient to settle the transaction.
final wrongBatch = Scenario(
  id: 'wrongBatch',
  title: 'Barang salah',
  client: 'Ms Chen',
  today: 1,
  deadline: 2,
  deadlineZh: '星期四',
  deadlineId: 'Kamis',
  minPct: 10,
  patience: 6,
  requiresReplacement: true,
  lines: {
    ...lateDelivery.lines,
    'open': [
      const Line('我是陈女士。我们订的是蓝色款，可收到的是红色款。{d}就要用，能给我们换吗？',
          'Saya Bu Chen. Kami pesan yang biru, tapi yang datang merah. Barangnya dibutuhkan hari {d}. Bisa diganti?'),
    ],
    'whichItem': [
      const Line('我还是需要蓝色款。你能确认会换成蓝色的吗？', 'Saya tetap perlu yang biru. Bisa pastikan barangnya diganti dengan yang biru?'),
      const Line('先确认一下，换来的会是我们订的蓝色款吗？', 'Pastikan dulu, apakah penggantinya warna biru sesuai pesanan?'),
    ],
    'orderAnswer': [
      const Line('订单编号是XC-3176。我们订的是蓝色款。', 'Nomor pesanannya XC-3176. Kami pesan yang biru.'),
    ],
    'when': [
      const Line('蓝色的可以。具体哪天能送到？我们{d}就要用。', 'Yang biru sesuai. Tepatnya kapan tiba? Kami perlu hari {d}.'),
    ],
    'settled': [
      const Line('好，你们换成蓝色款，按说好的日期送到就行。', 'Baik, ganti dengan yang biru dan kirim sampai pada tanggal yang disepakati.'),
    ],
  },
);

final invoiceMismatch = Scenario(
  id: 'invoice',
  title: 'Tagihan salah',
  client: 'Pak Lin, bagian keuangan',
  today: 1,
  deadline: 0,
  deadlineZh: '',
  deadlineId: '',
  minPct: 10,
  patience: 6,
  overchargeCents: 20000,
  correctInvoiceCents: 100000,
  lines: {
    ...lateDelivery.lines,
    'open': [
      const Line('你好，我是林先生。合同写的是一千元，你们却扣了一千二百元。发票金额也错了。请问怎么处理？',
          'Halo, saya Pak Lin. Kontraknya 1.000 yuan, tapi rekening kami didebit 1.200 yuan. Nominal fakturnya juga salah. Bisa dibantu?'),
    ],
    'amountAnswer': [
      const Line('两百元。我们付了一千二，合同金额是一千。', 'Selisihnya 200 yuan. Kami bayar 1.200, sementara kontraknya 1.000.'),
    ],
    'invoiceAnswer': [
      const Line('发票编号是XC-2816。这一笔已经扣款了。', 'Nomor fakturnya XC-2816. Pembayaran sudah terdebit.'),
    ],
    'whichRefund': [
      const Line('我们实际多付了钱。请确认会退多少。', 'Kami sudah kelebihan bayar. Tolong pastikan berapa yang akan dikembalikan.'),
      const Line('请把多扣的款退回。你能确认金额吗？', 'Tolong kembalikan kelebihannya. Bisa pastikan nominal pengembaliannya?'),
    ],
    'wrongRefund': [
      const Line('对不上。多扣的金额是两百元，请复核一下。', 'Nominalnya belum cocok. Kelebihan bayarnya 200 yuan, tolong cek lagi.'),
    ],
    'correctInvoice': [
      const Line('退款金额对了。发票上的金额也能改正吗？', 'Nominal pengembaliannya sudah benar. Bisa sekalian betulkan faktur yang salah?'),
    ],
    'deny': [
      const Line('我只想把账对上。请核对合同、扣款和发票。', 'Saya hanya ingin angkanya cocok. Tolong cek kontrak, pembayaran, dan faktur.'),
    ],
    'settled': [
      const Line('好，那就退回两百元，再发一张正确的发票给我们。', 'Baik, kembalikan 200 yuan dan kirimkan faktur yang sudah dibetulkan.'),
    ],
  },
);
