/// Understanding what a learner said in a business voice note, on the phone, without a network.
///
/// The recognizer's guesses (best first) are split into clauses. In each clause every cue of the lexicon is matched
/// as written and as sound (homophones folded to one character); a longer cue of another act hides the cues inside
/// it. Each match then gets its meaning from its clause: a negation before or after it flips it (two negations cancel),
/// a question, a condition clause, a quote of someone else, a deed for a third party or a plan given up turn it into
/// no act at all. Numbers, days and reasons are read into slots. The guesses are merged with a weight per rank.
library;

import 'dart:math';

import 'lexicon.dart';
import 'model.dart';
import 'sound.g.dart';

class Frame {
  final String act;

  /// '+' said / offered, '-' denied or refused
  final String pol;
  final double conf;

  /// discount in percent (九折 = 10), when (today, tomorrow, dayafter, monday…, N_days), why (talkReasons keys)
  final int? pct;
  final String? when;
  final String? reason;

  /// the words that carried it
  final String span;
  const Frame(this.act, this.pol, this.conf, {this.pct, this.when, this.reason, this.span = ''});
  String get key => '$act$pol';
  @override
  String toString() => '$act$pol(${conf.toStringAsFixed(2)}${pct != null ? ' pct=$pct' : ''}'
      '${when != null ? ' when=$when' : ''}${reason != null ? ' reason=$reason' : ''} «$span»)';
}

class TalkNlu {
  /// at or above: taken as said; between ask and ok: confirm first; below: not heard
  static const ok = .6, ask = .45;

  /// matched by sound only (a homophone) weighs this much of the written match
  static const soundW = .88;

  final List<_C> _cues;
  final Map<String, RegExp> _reasons;
  static final Map<int, int> _fold = _makeFold();

  /// the learned part (null = rules only) and how it is mixed in: [wRule] is the rules' share where both have an
  /// opinion, the model's probability is stretched by [boost], a frame only the model sees is capped at [only]
  final TalkModel? model;
  double wRule, boost, only;

  TalkNlu({this.model, this.wRule = .5, this.boost = 1.4, this.only = .9})
      : _cues = [for (final c in talkCues) _C(c)],
        _reasons = {for (final e in talkReasons.entries) e.key: RegExp(e.value)};

  static Map<int, int> _makeFold() {
    final a = soundFrom.runes.toList(), b = soundTo.runes.toList();
    return {for (var i = 0; i < a.length; i++) a[i]: b[i]};
  }

  /// each character written as the one character of its toneless syllable
  static String fold(String s) => String.fromCharCodes(s.runes.map((r) => _fold[r] ?? r));

  /// the frames of one voice note; [hyps] are the recognizer's guesses, best first
  List<Frame> parse(List<String> hyps) {
    final ruled = _rules(hyps);
    final m = model;
    if (m == null || hyps.isEmpty) return ruled;
    final primary = repair(hyps.first);
    final framing = splitClauses(withoutQuotes(primary));
    final arrivalDenied = _arrivalRefusal(framing);
    // the model's view: the guesses' probabilities, best guess weighing most
    final p = <String, double>{};
    var tw = 0.0;
    for (var i = 0; i < hyps.length && i < 3; i++) {
      final w = const [1.0, .6, .4][i];
      tw += w;
      m.probs(hyps[i]).forEach((k, v) => p[k] = (p[k] ?? 0) + v * w);
    }
    p.updateAll((k, v) => v / tw);
    final byKey = {for (final f in ruled) f.key: f};
    final out = <Frame>[];
    for (final f in ruled) {
      final pm = p[f.key];
      if (pm == null) {
        out.add(f);
        continue;
      }
      final c = m.mix(f.key, f.conf, pm) ?? wRule * f.conf + (1 - wRule) * min(1.0, pm * boost);
      out.add(Frame(f.act, f.pol, c, pct: f.pct, when: f.when, reason: f.reason, span: f.span));
    }
    p.forEach((k, v) {
      if (byKey.containsKey(k)) return;
      final c = m.mix(k, 0, v) ?? min(1.0, v * boost) * only;
      if (c < ask) return;
      final pol = k.substring(k.length - 1);
      final act = k.substring(0, k.length - 1);
      if (pol == '+' && offerActsNlu.contains(act) && !framing.any(_isOfferClause)) return;
      if (act == 'deny_fault' &&
          !_explicitFault.hasMatch(primary) &&
          (_explainsAnInability(framing) || _takesResponsibility.hasMatch(primary) ||
              _correctsServiceHistory.hasMatch(primary))) {
        return;
      }
      if (act == 'promise_time' && pol == '+' && _differentDeadline.hasMatch(primary) &&
          !framing.any((c) => _isOfferClause(c) && _arrivalCommitment.hasMatch(c.text))) {
        return;
      }
      if (act == 'compensate' && pol == '+' && byKey.containsKey('discount+') &&
          !_separateCompensation.hasMatch(primary)) {
        return;
      }
      if (act == 'agree' && byKey.containsKey('promise_time+') && framing.any((c) => _reassuresDate.hasMatch(c.text))) {
        return;
      }
      final t = primary;
      String? why;
      if (act == 'cause') {
        for (final e in _reasons.entries) {
          if (e.value.hasMatch(t) || e.value.hasMatch(fold(t))) {
            why = e.key;
            break;
          }
        }
      }
      out.add(Frame(act, pol, c,
          pct: act == 'discount' ? readPct(t) : null,
          when: (act == 'resend' || act == 'promise_time' || act == 'expedite') ? readWhen(t) : null,
          reason: why,
          span: '·'));
    });
    // a thing both said and denied: a frame the rules read with their negation rules beats one only the model saw;
    // otherwise the surer one stays (a cause can be both: it names two things)
    out.removeWhere((f) {
      if (f.act == 'cause') return false;
      final o = out.where((g) => g.act == f.act && g.pol != f.pol).firstOrNull;
      if (o == null) return false;
      final fRule = byKey.containsKey(f.key), oRule = byKey.containsKey(o.key);
      if (fRule != oRule) return !fRule && o.conf >= ok;
      return o.conf > f.conf;
    });
    if (arrivalDenied != null && !byKey.containsKey('promise_time+')) {
      out.removeWhere((f) => f.act == 'promise_time');
      out.add(arrivalDenied);
    }
    if (framing.any((c) => _followUp.hasMatch(c.text)) &&
        !framing.any((c) => !c.q && !c.cond && _reportedIncident.hasMatch(c.text))) {
      out.removeWhere((f) => f.act == 'cause' && f.pol == '+');
    }
    _verifySpeechActs(primary, framing, out);
    out.sort((a, b) => talkActs.indexOf(a.act).compareTo(talkActs.indexOf(b.act)));
    return out;
  }

  /// the frames the rules alone find (no model)
  List<Frame> ruleFrames(List<String> hyps) => _rules(hyps);

  List<Frame> _rules(List<String> hyps) {
    final best = <String, Frame>{};
    for (var i = 0; i < hyps.length && i < 5; i++) {
      final w = const [1.0, .9, .82, .75, .7][i];
      for (final f in parseOne(hyps[i])) {
        final g = Frame(f.act, f.pol, f.conf * w, pct: f.pct, when: f.when, reason: f.reason, span: f.span);
        final old = best[g.key];
        if (old == null || g.conf > old.conf) {
          best[g.key] = Frame(g.act, g.pol, g.conf,
              pct: g.pct ?? old?.pct, when: g.when ?? old?.when, reason: g.reason ?? old?.reason, span: g.span);
        }
      }
    }
    final out = best.values.toList();
    // a thing both said and denied: keep the surer one
    out.removeWhere((f) {
      final o = best['${f.act}${f.pol == '+' ? '-' : '+'}'];
      return o != null && o.conf > f.conf && f.act != 'cause';
    });
    out.sort((a, b) => talkActs.indexOf(a.act).compareTo(talkActs.indexOf(b.act)));
    return out;
  }

  /// the acts taken as said (conf >= ok)
  List<Frame> said(List<String> hyps) => parse(hyps).where((f) => f.conf >= ok).toList();

  List<Frame> parseOne(String text) {
    // words quoted from someone else say nothing of the speaker
    text = repair(withoutQuotes(text));
    final out = <Frame>[];
    final clauses = splitClauses(text);
    for (var ci = 0; ci < clauses.length; ci++) {
      final c = clauses[ci];
      final prev = ci > 0 ? clauses[ci - 1] : null;
      // a question the speaker answers at once (能不能星期六送到？可以的 / 会不会赔偿？会的) says what it asks
      if (prev != null && prev.q && RegExp('^(答案是)?(可以|会|能|行|有|当然|肯定)(的|啊|呀|会的|可以)*\$').hasMatch(c.text)) {
        final plain = prev.text.replaceAll(_question, '').replaceAll(RegExp('(吗|么|呢)\$'), '');
        out.addAll(_clause(Clause(plain, false), null, null));
        continue;
      }
      out.addAll(_clause(c, prev, ci + 1 < clauses.length ? clauses[ci + 1] : null));
    }
    return out;
  }

  // ---------------------------------------------------------------- repair

  /// words the rules read as written: when the recognizer wrote one of them with homophones (对不其, 名天), it is
  /// written back, so negation, questions, days and reasons are still read
  static const repairWords = [
    '对不起', '不好意思', '不客气', '没关系', '没问题', '不用谢', '能不能', '要不要', '可不可以', '是不是', '会不会', '有没有', //
    '行不行', '好不好', '需不需要', '来不及', '大后天', '明天', '后天', '今天', '明早', '星期', '礼拜', '工作日', '小时', '百分之', //
    '个点', '之前', '以前', '之内', '以内', '因为', '由于', '所以', '导致', '耽误', '延误', '耽搁', '推迟', '原因', '问题', '晚了', //
    '如果', '要是', '假如', '的话', '本来', '原本', '难道', '已经', '上次', '缺货', '断货', '爆仓', '台风', '下雨', '海关', '清关', //
    '物流', '快递', '工厂', '故障', '天气', '堵车', '库存', '仓库',
    '客服', '办公室', '就算', '是否需要', '无法送到', '正式答复', '服务',
  ];
  static final List<(String, String)> _repairFold = [for (final w in repairWords) (fold(w), w)];
  static const _nums = '零一二两三四五六七八九十';
  static final Map<String, String> _numOf = {for (final n in _nums.split('')) fold(n): n};
  static final _numCtx = RegExp('^(折|天|号|个点|小时|个工作日|工作日|个小时)');
  static final _moneyNumber = RegExp(r'[零〇一二两三四五六七八九十百千万]{2,}(?=元|块|角|毛|分|原路退|退|[，。！？,!?]|$)');

  static String repair(String t, {bool protectAmounts = false}) {
    if (t.isEmpty) return t;
    final f = fold(t);
    final out = t.split('');
    if (out.length != f.length) return t;
    final amounts = protectAmounts ? _moneyNumber.allMatches(t).toList() : const <RegExpMatch>[];
    for (final (fw, w) in _repairFold) {
      var i = f.indexOf(fw);
      while (i >= 0) {
        if (!amounts.any((amount) => amount.start < i + w.length && i < amount.end)) {
          for (var k = 0; k < w.length; k++) {
            out[i + k] = w[k];
          }
        }
        i = f.indexOf(fw, i + w.length);
      }
    }
    // numbers next to 折/天/号/周/星期/百分之: 久折 → 九折, 星期屋 → 星期五
    var s = out.join();
    for (var i = 0; i < out.length; i++) {
      final n = _numOf[f[i]];
      if (n == null || out[i] == n || _nums.contains(out[i])) continue;
      final after = s.substring(i + 1);
      final before = s.substring(0, i);
      final ctx = _numCtx.hasMatch(after) ||
          (i + 1 < out.length && _numOf.containsKey(f[i + 1]) && _numCtx.hasMatch(s.substring(i + 2))) ||
          RegExp('(星期|礼拜|周|百分之|打)\$').hasMatch(before) ||
          (i > 0 && _nums.contains(out[i - 1]) && _numCtx.hasMatch(after));
      if (ctx) {
        out[i] = n;
        s = out.join();
      }
    }
    return out.join();
  }

  // ---------------------------------------------------------------- clauses

  static final _punct = RegExp(r'(?:[，。！？；：,!?;:、\s…—~～"“”‘’（）()\[\]【】]|(?<![0-9])\.|\.(?![0-9]))+');
  static final _conn = RegExp('(但是|可是|不过|然而|而且|并且|然后|所以|因此|另外|还有就是|同时|再说|而是|否则|要不然|不然)');
  static final _ifMark = RegExp('(如果|要是|假如|假设|万一|若是|倘若|如若|只要)');
  static final _then = RegExp('(的话|就|那么|那就|那)');

  /// the clauses of [text], each with whether it ended in a question mark
  static List<Clause> splitClauses(String text) {
    final t = text.replaceAll('？', '?');
    final out = <Clause>[];
    var start = 0;
    final parts = <(String, bool)>[];
    for (final m in _punct.allMatches(t)) {
      parts.add((t.substring(start, m.start), m[0]!.contains('?')));
      start = m.end;
    }
    parts.add((t.substring(start), false));
    for (final (p, q) in parts) {
      if (p.isEmpty) continue;
      // split before connectors, and a condition from what follows it (如果您同意我们就…)
      final pieces = <String>[];
      var s = 0;
      for (final m in _conn.allMatches(p)) {
        if (m.start > s) pieces.add(p.substring(s, m.start));
        s = m.start;
      }
      pieces.add(p.substring(s));
      for (var k = 0; k < pieces.length; k++) {
        final piece = pieces[k];
        final im = _ifMark.firstMatch(piece);
        if (im != null) {
          final tm = _then.allMatches(piece).where((x) => x.start > im.end + 1).firstOrNull;
          if (tm != null) {
            out.add(Clause(piece.substring(0, tm.end), false, cond: true));
            final rest = piece.substring(tm.end);
            if (rest.isNotEmpty) out.add(Clause(rest, q && k == pieces.length - 1, afterCond: true));
            continue;
          }
          out.add(Clause(piece, q && k == pieces.length - 1, cond: true));
          continue;
        }
        out.add(Clause(piece, q && k == pieces.length - 1));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------- one clause

  static final _quotedWords = RegExp(r'[“"「『][^”"」』]*[”"」』]|‘[^’]*’');
  static final _courtesy = RegExp(r'对不起|对不住|抱歉|歉意|不好意思|见谅|谅解|原谅');
  static final _negatesCourtesy = RegExp(r'(?:毫不|并不|一点也不|并无|毫无|没有|不想|不愿|不觉得|不必|不用|无需|不)(?:再|向.{0,4}|表现出|表示|感到|觉得|有|让.{0,3})?$|不(?:会|愿|想|肯)(?:向|跟|对)(?:您|你|贵司)说$');

  /// A quoted example is separate from the speaker's own commitment.
  static String withoutQuotes(String text) => text.replaceAll(_quotedWords, '，');

  static final _negWord = RegExp('(没有|绝不|并不|并非|并无|不|没|别|未|无法|甭|休想|拒绝)');
  // not negations: fixed words that hold 不/没
  static final _notNeg = RegExp('(能不能|要不要|可不可以|可以不可以|是不是|会不会|有没有|行不行|好不好|需不需要|愿不愿意|该不该|'
      '着不着急|急不急|赶不赶|对不对|来不来得及|来不及|要不然|要不|不然的话|不一会|不论|不如|不仅仅|'
      '不好意思|对不起|对不住|对[您你]不住|不客气|不错|不久|不断|不仅|不少|不管|不过|不然|差不多|了不起|不得了|不一定|不舒服|不便|'
      '不满|不愉快|不高兴|不对|不够|不足|不了解|没关系|没事|没问题|不用谢|不止|不只|没多久|不知道|不清楚|不太清楚|免不了|少不了|'
      '不得不|不能不|不会不|不可能不|没有不|不是不|不应该不)');
  static final _mustDouble = RegExp('(不得不|不能不|不会不|不可能不|没有不|不是不|不应该不)');
  static final _postNeg = RegExp('^.{0,6}?(是)?(不可能|不行|没门|不会的|做不到|办不到|不了|不太可能|恐怕不行|没戏|不现实|免谈|是不会有的|没有的|就算了|算了|'
      '不能同意|无法同意|不同意|不接受|不能接受|不考虑|不可以|没有\$|也没有)');
  static final _question = RegExp('(要不要|能不能|可不可以|可以不可以|需不需要|行不行|好不好|是不是|有没有|会不会|愿不愿意|该不该|是否|难道|怎么样|如何|行吗|好吗|可以吗|对吗)');
  static final _qEnd = RegExp('(吗|么|呢|嘛)[啊呀吧]?\$');
  static final _quote = RegExp('(?<!跟|对|和|向|给|替|帮|与|按|照|依)(贵公司|贵方|贵司|您|你|他|她|他们|她们|经理|老板|领导|客户|对方|别人|人家|公司|上面|老王|同事|有人|大家)'
      '(.{0,2}?)(刚才|刚刚|刚|之前|上次|昨天|早上|也|还|一直|都|已经|又|不是|老|总|总是|老是|还老)?(说|讲|要求|让|叫|希望|建议|觉得|认为|想要|提到|表示|问|说过|以为|想让|提出|提的|要的|所说)');
  static final _ourQuote = RegExp('(老板|经理|领导|公司|上面)(让|叫|要)(我|我们)(跟|和|对|给|告诉|转告)?(您|你)?(说)?');
  static final _third = RegExp('(给|向|跟|对|为)(别的|其他|其它|另外的|另一个|那个|那位|这些|那些|他们|她们|他|她)(客户|人|公司|老板|顾客|买家)?');
  static final _given = RegExp('(本来(?!就)|原本(?!就)|本想|原来打算|原打算|原先|之前想|本打算|一度想)');
  static final _strong = RegExp(talkStrongReasons);
  static final _marks = RegExp(talkCauseMarks);
  static final _past = RegExp('(上次|上回|去年|上个月|以前)');
  static final _topic = RegExp('^(的)?(事|事情|问题|方面|金额|这块|这一块|方案|计划|的话|这件事|一事|的情况)');
  static final _cancel = RegExp('^(那个|这个|那|这)?(不算|作废|不作数|收回|取消了|没批|不行了|也不行)');
  static final _hedge = RegExp('(争取|申请|请示|问问|帮你问|帮您问|看看能不能|尽量|考虑)(一下)?(.{0,3})\$');
  static final _notGoods = RegExp('(方案|资料|合同|报价|消息|邮件|截图|订单号|单号|照片|链接|发票|计划|文件|通知|短信|信息|位置|地址)');
  static final _meta = RegExp('不是说');
  static final _depends = RegExp('^(要看|得看|看|取决于|前提是|但要看|就看)');
  static final _thirdSubj = RegExp('(他|她|他们|她们|对方|快递|物流公司|人家|快递员|司机|老板|经理|工厂)(也|都|已经|还)?(向.{0,4})?\$');

  /// acts whose words, when longer, hide the cues of other acts inside them (这不是我们的错 hides 我们的错)
  static const _hides = {'deny_fault', 'refuse', 'ask_deadline', 'ask_order', 'acknowledge', 'agree'};
  static final _notButIs = RegExp('不是(我们|我)?(不想|不愿意|不肯|不愿|不能|不会|故意不|不给|不发|没)');
  static final _explain = RegExp('^(是|只是|而是|实在是|真的是|就是|但是|可是|不过|主要是|确实是|因为|实在|真的)');
  static final _explicitFault = RegExp(r'(?:不是|并非|不在|无关|没关系).{0,7}(?:错|责任|过失)|(?:错|责任|过失).{0,5}(?:不在|无关|不是)|与.{0,4}(?:我们|本司|我方)无关');
  static final _takesResponsibility = RegExp(r'我们的错|我的错|我们要负责|我们有责任|我方承担责任|(?:负|承担)(?:全部|主要|所有)?责任|责任在我');
  static final _correctsServiceHistory = RegExp(r'不是(?:我们)?(?:偷懒|故意拖延|压着不发)|不是的.{0,5}(?:早就发|已经发|早发)');
  static final _followUp = RegExp(r'(?:以便|方便|好让|我们好|请.{0,18}我(?:们)?).{0,7}(?:联系|向|跟|查一下|核对|核实)|(?:我|我们)(?:先去|这就去|再去|会去).{0,5}(?:核实|问一下|查一下)');
  static final _reportedIncident = RegExp(r'因为|由于|是.{0,14}(?:耽误|晚到|晚了|延误|搞错|弄错)|导致|造成|出了问题|压在|卡在|卡住|库存不足|缺货|坏了|抛锚|封路|滞留|暴雨|台风|爆仓|海关查验|海关扣');
  static final _arrivalCommitment = RegExp(r'送到|送上门|送达|到达|到货|收到|抵达|交货|交到|拿到|到手|运到|寄到|落地|准时|按时|晚不了|不会再晚|到[货了]?$|到(?:您|你|贵司|门口)');
  static final _differentDeadline = RegExp(r'放行|发车|出库|寄出|发货|发给|寄给|发不了|寄不了|发不出|寄不出|联系您|联系你|回复|回电|通知|查收|您说|你说|您提到|你提到');
  static final _cannotArrive = RegExp(r'(?:不能|没法|无法|不会|不可能|没办法|来不及).{0,8}(?:送到|送达|抵达|交货|交付|收到|到货)|(?:送|运|寄|交)不到|到不了');
  static final _separateCompensation = RegExp(r'退款|退钱|退回|退还|免单|免邮|赔偿|赔付|赔钱|赔款|补发款|券|红包|礼品|礼物|积分|延保|(?:快递|邮|运|配送)费');
  static final _waitForAnswer = RegExp(r'^(?:请问|不知|能不能|要不要|是否|假设|就算|即使)|(?:会不会|可不可以|行不行|怎么样|如何|吗|么)[啊呀吧]?$');
  static final _reassuresDate = RegExp(r'^(?:这次|这样|这个时间|这个安排)没问题');

  static bool _isOfferClause(Clause clause) => !clause.cond && !clause.q &&
      !_waitForAnswer.hasMatch(clause.text) && (!_quote.hasMatch(clause.text) || _ourQuote.hasMatch(clause.text));

  static bool _explainsAnInability(List<Clause> clauses) => clauses.indexed.any(
      (entry) => entry.$1 + 1 < clauses.length && _notButIs.hasMatch(entry.$2.text) && _explain.hasMatch(clauses[entry.$1 + 1].text));

  static final _reportedSpeaker = RegExp(r'^(?:(?:那个|听说|之前)[，,]?)?(?:客服|快递员|司机|承运人|仓库.{0,4}(?:同事|主管)|客户|对方|同事).{0,5}(?:说|讲|表示|提过|问)');
  static final _sellerRestatement = RegExp(r'我(?:们)?(?:刚|已经|已|现在)?(?:核实|确认|决定|承诺|保证)|(?:但|不过|后来)(?:我|我们)(?:会|一定|可以)');
  static final _uncommittedReport = RegExp(r'听说|(?:没|没有|并非).{0,4}(?:说过|正式答复|确认|同意)|尚待.{0,5}(?:回复|批准|审核)|请以我.{0,4}为准|还没.{0,4}(?:确认|批准)');
  static final _counterfactual = RegExp(r'^(?:(?:退一步讲|那|可|但)?(?:就算|即使|即便|哪怕|倘若|假使)|(?:也)?(?:未必|不至于))');
  static final _acceptanceQuestion = RegExp(r'^(?:请问)?(?:您|你)?(?:觉.{0,2}|看)?(?:这样|这么做|这种方案|这个安排)?(?:合适吗|如何|可以吗|可不可以|行吗|行不行)$');
  static final _unmarkedProposal = RegExp(r'^(?:请问|您看|您觉得|你看|是否|能否|可不可以).{0,6}(?:是否需要|要不要|需不需要|给不给)|(?:您|你)(?:觉得|觉的|看这样|觉得这样).{0,3}(?:如何|怎么样|可以吗)$');
  static final _confirmedOffer = RegExp(r'我们(?:已经|确定|承诺|保证)|我(?:已经|确定|承诺|保证)|一定|正式确认');
  static final _separateDecision = RegExp(r'^(?:但是|不过|然而|另外|现在|实际|结果|我们|我).{0,6}(?:愿意|决定|还是会|仍然会|会|肯定|一定|可以).{0,10}(?:发|寄|送|承担|退|赔|打折|改)');
  static final _askingAboutFault = RegExp(r'^(?:您|你|客户)(?:是|会|难道|是否|是不是)?.{0,4}(?:觉得|认为|以为).{0,16}(?:故意|拖延|责任|错|骗)');
  static final _orderDate = RegExp(r'(?:订单|单子).{0,8}(?:哪一天|哪天|几号|什么时候).{0,4}(?:下|订|买)|(?:哪一天|哪天|几号|什么时候).{0,6}(?:下单|订购)');
  static final _orderId = RegExp(r'编号|号码|单号|运单|订单号|快递号|物流号|手机号|身份证|电话号码');
  static final _personalContext = RegExp(r'公室.{0,4}电脑|在门口.{0,6}收快递|太阳.{0,9}(?:在门口|都出汗)|(?:我|我们).{0,4}(?:放学|上学|下班).{0,4}(?:顺便|的时候)|我在家.{0,6}(?:收|等)');
  static final _businessContext = RegExp(r'贵司|订单|货款|货物|货车|批货|库存|欠款|发票|补发|我们公司|我方|贵公司|客户|代您|为您|给您|您这单');
  static final _approvalOnly = RegExp(r'(?:上报|提交|已报).{0,10}(?:主管|领导|法务|财务)|尚待.{0,5}(?:回复|审批)|(?:没有|没|并未)说过');
  static final _moneyDenial = RegExp(r'不予(?:提供|办理|承担|支付|给付)?|无法(?:提供|办理|承担|支付)|拒绝(?:提供|办理|承担|支付)|(?:真|确实)?给不了|不得行|不接受');
  static final _priceRefused = RegExp(r'(?:折|优惠).{0,4}(?:都|也)?[不怖布步]行|(?:不|没法|无法)(?:再)?(?:降价|减价)|(?:价钱|价格).{0,8}底线');
  static final _pricePosition = RegExp(r'这是(?:我方|我们|公司)的底线|价格.{0,5}到底了');
  static final _denialQuestion = RegExp(r'^(?:您|你).{0,4}(?:说|讲|认为)|^(?:这个|这点)?我不认');
  static final _refundWords = RegExp(r'补偿|赔偿|退款|退钱|退回|赔付|免运费|承担.{0,6}(?:费用|运费)|礼券|差价');
  static final _discountWords = RegExp(r'折扣|降价|减价|优惠|打折|[零一二三四五六七八九0-9]折');
  static final _refuseWords = RegExp(r'恐怕.{0,4}(?:不行|做不到|办不到)|没法|无法|不认|不可能|不同意|不能|不接受|拒绝');
  static final _delayTerms = RegExp(r'送到|送达|到货|抵达|交货|交付|到您|到你|运到|(?:必须|一定|能|得到|要)到');
  static final _declinesPromise = RegExp(r'(?:无法|不能|没法|不敢|不便).{0,10}(?:承诺|保证|确认)|(?:承诺|保证).{0,6}(?:做不到|办不到)');
  static final _speedTerms = RegExp(r'加急|提速|加快|空运|优先(?:发|寄|配送)|插单|特快');
  static final _repeatTerms = RegExp(r'补发|补寄|重发|重寄|重新发货|重新寄|再寄一次|再发一次');
  static final _unavailable = RegExp(r'做不到|办不到|不得行|没得.{0,7}(?:服务|渠道|选项)|(?:不能|没法|无法|拒绝).{0,8}(?:加急|提速|加快|插单|补发|补寄|重发|重寄)|(?:加急|补发|补寄|重发|重寄).{0,6}(?:不行|不可以|做不到)');
  static final _rejectsAccusation = RegExp(r'^(?:您|你).{0,5}(?:讲|说).{0,9}(?:骗|故意|撒谎)');
  static final _externalDeal = RegExp(r'^(?:我(?:刚)?听说|据说).{0,10}(?:有的店|别家|有的公司|那家店|其他卖家)|^(?:别家|隔壁|另一家|其他)(?:店铺|店家|商家|公司)');
  static final _refersToApology = RegExp(r'道歉(?:信|函|模板)|^(?:我同事|同事|我妈|他|她).{0,8}(?:道歉|致歉|跟.{0,8}道歉)');
  static final _deniesExcuse = RegExp(r'不是在找借口|并不是找借口|我们没有骗|我们并没有骗');

  /// A trailing request for approval can make an earlier phrase a proposal.
  static bool seeksOfferApproval(String text, List<Clause> clauses) {
    final asks = clauses.length > 1 && _acceptanceQuestion.hasMatch(clauses.last.text) || _unmarkedProposal.hasMatch(text);
    if (!asks) return false;
    return !clauses.any((c) => _isOfferClause(c) && !_reportedSpeaker.hasMatch(c.text) &&
        !_counterfactual.hasMatch(c.text) && (_confirmedOffer.hasMatch(c.text) || _separateDecision.hasMatch(c.text)));
  }

  static void _verifySpeechActs(String text, List<Clause> clauses, List<Frame> frames) {
    final visible = withoutQuotes(text);
    final independent = clauses.where((c) => !_reportedSpeaker.hasMatch(c.text) && !_quote.hasMatch(c.text) && !_counterfactual.hasMatch(c.text));
    final claims = independent.where(_isOfferClause).toList();
    final confirmed = claims.any((c) => _confirmedOffer.hasMatch(c.text) || _separateDecision.hasMatch(c.text));
    final acceptanceQuestion = seeksOfferApproval(visible, clauses);
    final reported = clauses.any((c) => _reportedSpeaker.hasMatch(c.text));
    final reportsWithoutDecision = reported && !confirmed && !_sellerRestatement.hasMatch(visible) &&
        (claims.isEmpty || _uncommittedReport.hasMatch(visible));
    final counterfactualOnly = clauses.any((c) => _counterfactual.hasMatch(c.text)) && !confirmed;
    final orderDateOnly = _orderDate.hasMatch(visible) && !_orderId.hasMatch(visible);
    final ownFault = independent.any((c) => !c.q && !_denialQuestion.hasMatch(c.text) && _takesResponsibility.hasMatch(c.text));
    final denialOfReportedFault = clauses.any((c) => _denialQuestion.hasMatch(c.text)) &&
        clauses.any((c) => c.q || c.text.endsWith('不认')) && !ownFault;
    final quotedMaterial = visible != text;
    final anyArrivalDate = claims.any((c) => readWhen(c.text) != null && _arrivalCommitment.hasMatch(c.text) && !_declinesPromise.hasMatch(c.text));
    final orderAsked = _orderId.hasMatch(visible);
    final hasDeadlineRequest = frames.any((f) => f.key == 'ask_deadline+' && f.conf >= ok);
    final dateRefused = _declinesPromise.hasMatch(visible) && _delayTerms.hasMatch(text) && readWhen(text) != null && !anyArrivalDate;
    final agrees = frames.any((f) => f.key == 'agree+' && f.conf >= ok);
    final otherVendorsOnly = clauses.any((c) => _externalDeal.hasMatch(c.text)) && !confirmed;
    final directApology = claims.any((c) => !_refersToApology.hasMatch(c.text) && _courtesy.hasMatch(c.text));

    frames.removeWhere((f) {
      if (f.pol != '+') return false;
      if (offerActsNlu.contains(f.act) && (acceptanceQuestion || reportsWithoutDecision || counterfactualOnly || otherVendorsOnly)) return true;
      if (f.act == 'promise_time' && quotedMaterial && !anyArrivalDate &&
          claims.any((c) => _refuseWords.hasMatch(c.text))) {
        return true;
      }
      if (f.act == 'promise_time' && dateRefused) return true;
      if (f.act == 'ask_order' && (orderDateOnly || hasDeadlineRequest && !orderAsked)) return true;
      if (f.act == 'acknowledge' && denialOfReportedFault) return true;
      if (f.act == 'acknowledge' && f.span == '·' && _pricePosition.hasMatch(visible) && !ownFault) return true;
      if (f.act == 'deny_fault' && independent.isEmpty && !_explicitFault.hasMatch(visible)) return true;
      if (f.act == 'deny_fault' && (_askingAboutFault.hasMatch(visible) || _rejectsAccusation.hasMatch(visible)) && !_explicitFault.hasMatch(visible)) return true;
      if (f.act == 'deny_fault' && (otherVendorsOnly || _deniesExcuse.hasMatch(visible)) && !_explicitFault.hasMatch(visible)) return true;
      if (f.act == 'apologize' && !directApology && clauses.any((c) => _refersToApology.hasMatch(c.text))) return true;
      if (f.act == 'cause' && (_personalContext.hasMatch(visible) && !_businessContext.hasMatch(visible) || counterfactualOnly)) return true;
      if (const {'apologize', 'compensate', 'deny_fault'}.contains(f.act) && _approvalOnly.hasMatch(visible) &&
          (quotedMaterial || _uncommittedReport.hasMatch(visible)) &&
          !claims.any((c) => _confirmedOffer.hasMatch(c.text) || f.act == 'apologize' && _courtesy.hasMatch(c.text))) {
        return true;
      }
      if (f.act == 'refuse' && agrees && !claims.any((c) => _refuseWords.hasMatch(c.text))) return true;
      return false;
    });

    if (dateRefused && !frames.any((f) => f.key == 'promise_time-')) {
      frames.add(Frame('promise_time', '-', ok, when: readWhen(text), span: _declinesPromise.firstMatch(visible)![0]!));
    }

    for (final (act, words) in [('resend', _repeatTerms), ('expedite', _speedTerms)]) {
      final denial = clauses.indexed.any((entry) {
        final (index, current) = entry;
        if (!claims.contains(current) || !_unavailable.hasMatch(current.text)) return false;
        if (words.hasMatch(current.text)) return true;
        return !_repeatTerms.hasMatch(current.text) && !_speedTerms.hasMatch(current.text) &&
            index > 0 && independent.contains(clauses[index - 1]) && words.hasMatch(clauses[index - 1].text);
      });
      if (!denial || claims.any((c) => words.hasMatch(c.text) && _confirmedOffer.hasMatch(c.text))) {
        continue;
      }
      final positive = frames.where((f) => f.act == act && f.pol == '+').firstOrNull;
      final negative = frames.where((f) => f.act == act && f.pol == '-' && f.conf >= ok).firstOrNull;
      frames.removeWhere((f) => f.act == act && f != negative);
      if (negative == null) {
        frames.add(Frame(act, '-', max(ok, positive?.conf ?? 0), when: positive?.when, span: words.firstMatch(visible)![0]!));
      }
    }

    for (final c in claims) {
      if (_mustDouble.hasMatch(c.text) || _approvalOnly.hasMatch(c.text)) continue;
      for (final (act, terms) in [('discount', _discountWords), ('compensate', _refundWords)]) {
        bool declined(Clause clause) => _moneyDenial.hasMatch(clause.text) || act == 'discount' && _priceRefused.hasMatch(clause.text);
        if (!declined(c)) continue;
        if (!terms.hasMatch(c.text)) continue;
        final positive = frames.where((f) => f.act == act && f.pol == '+').firstOrNull;
        if (positive == null || claims.any((other) => other != c && terms.hasMatch(other.text) && !declined(other))) continue;
        frames.removeWhere((f) => f.act == act);
        frames.add(Frame(act, '-', max(ok, positive.conf), pct: positive.pct, span: positive.span));
      }
    }
  }

  static Frame? _arrivalRefusal(List<Clause> clauses) {
    for (final clause in clauses.reversed) {
      if (!_isOfferClause(clause)) continue;
      final text = clause.text;
      if (_mustDouble.hasMatch(text)) continue;
      final denied = _cannotArrive.firstMatch(text);
      if (denied != null) return Frame('promise_time', '-', .9, when: readWhen(text), span: denied[0]!);
    }
    return null;
  }

  List<Frame> _clause(Clause c, Clause? prev, Clause? next) {
    final t = c.text;
    final f = fold(t);
    final hits = <_Hit>[];
    for (final cue in _cues) {
      for (final m in cue.exactRe.allMatches(t)) {
        if (m.end == m.start) continue;
        hits.add(_Hit(cue, m.start, m.end, cue.c.w));
      }
      if (!cue.c.exact) {
        for (final m in cue.soundRe!.allMatches(f)) {
          if (m.end == m.start) continue;
          if (hits.any((h) => h.cue == cue && h.s == m.start && h.e == m.end)) continue;
          if (!cue.likely(t, m.start, m.end)) continue;
          hits.add(_Hit(cue, m.start, m.end, cue.c.w * soundW));
        }
      }
    }
    // a longer cue of another act hides the shorter ones inside it
    hits.sort((a, b) => (b.e - b.s).compareTo(a.e - a.s));
    final kept = <_Hit>[];
    for (final h in hits) {
      final inside = kept.any((k) =>
          k.cue.c.act != h.cue.c.act &&
          k.s <= h.s &&
          h.e <= k.e &&
          (k.e - k.s) > (h.e - h.s) &&
          (_hides.contains(k.cue.c.act) || h.cue.c.act == 'agree' || h.cue.c.act == 'greet'));
      if (!inside) kept.add(h);
    }

    final out = <Frame>[];
    final q = c.q || _qEnd.hasMatch(t);
    for (final h in kept) {
      final act = h.cue.c.act;
      var conf = h.w;
      var pol = h.cue.c.neg ? -1 : 1;
      final before = t.substring(0, h.s), after = t.substring(h.e);
      // negation before (in the clause), with double negation; fixed words do not count
      var lead = before.length > 10 ? before.substring(before.length - 10) : before;
      lead = lead.replaceAll(_mustDouble, '必须').replaceAll(_notNeg, '〇');
      var n = _negWord.allMatches(lead).length;
      // a negation inside a cue with a gap (运费我们不能承担), when the cue itself does not hold it
      final inner = t.substring(h.s, h.e).replaceAll(_notNeg, '〇');
      for (final m in _negWord.allMatches(inner)) {
        if (!h.cue.c.re.contains(m[0]!)) n++;
      }
      if (n.isOdd) pol = -pol;
      if (act == 'apologize' && pol < 0 && _courtesy.hasMatch(t.substring(h.s, h.e)) && !_negatesCourtesy.hasMatch(before)) {
        // A denial elsewhere in an unpunctuated transcript does not negate a courtesy formula.
        pol = 1;
      }
      // Explaining why a proposal is unavailable does not make the proposal or assign blame.
      if (next != null && _explain.hasMatch(next.text) && _notButIs.hasMatch(t) &&
          (offerActsNlu.contains(act) || (act == 'deny_fault' && !_explicitFault.hasMatch(t)))) {
        continue;
      }
      // negation after: 道歉是不可能的 / 折扣没有
      if (_postNeg.hasMatch(after) && (offerActsNlu.contains(act) || act == 'apologize' || act == 'agree')) pol = -pol;
      var none = false;
      if (q && !questionActs.contains(act) && act != 'greet' && act != 'thanks') none = true;
      final offer = offerActsNlu.contains(act);
      if ((offer || act == 'apologize') && _topic.hasMatch(after)) none = true;
      if (offer && act != 'promise_time' && _hedge.hasMatch(before)) none = true;
      if (offer && _meta.hasMatch(before)) none = true;
      if (offer && (_notButIs.hasMatch(before) || RegExp('^.{0,3}不是不(能|想|给|可以)').hasMatch(after)) && next != null && _depends.hasMatch(next.text)) {
        none = true;
      }
      if (act == 'resend' && RegExp('已经(.{0,2})\$').hasMatch(before)) none = true;
      if (act == 'resend' && _notGoods.hasMatch(t)) none = true;
      if (act == 'apologize' && _thirdSubj.hasMatch(before)) none = true;
      if (RegExp('^过(?!去|来)').hasMatch(after)) none = true;
      if (questionActs.contains(act) && (pol < 0 || RegExp('(不知道|不清楚|不确定|不用|不必)').hasMatch(before))) none = true;
      if (act == 'promise_time' && kept.any((k) => k.cue.c.act == 'ask_deadline')) none = true;
      if (offer && next != null && _cancel.hasMatch(next.text)) pol = -1;
      if (_question.hasMatch(before) && !questionActs.contains(act)) none = true;
      // 难道我们还要给您道歉吗: a question that means no
      if (before.contains('难道') && !questionActs.contains(act)) {
        none = false;
        pol = -1;
      }
      if (c.cond && act != 'cause' && act != 'acknowledge') none = true;
      if (_quote.hasMatch(before) && !_ourQuote.hasMatch(before) && act != 'agree') none = true;
      if (_third.hasMatch(before) && act != 'cause') none = true;
      if (_past.hasMatch(before)) none = true;
      if (_given.hasMatch(before) || (_given.hasMatch(prev?.text ?? '') && next == null && act != 'cause')) pol = -1;
      if (none) continue;
      String? reason;
      if (act == 'deny_fault' && pol < 0) continue;
      if (act == 'compensate' && pol < 0 && RegExp('退(款|钱|货)').hasMatch(t.substring(h.s, h.e))) {
        out.add(Frame('refuse', '+', conf, span: t.substring(h.s, h.e)));
        continue;
      }
      if (act == 'agree' && pol < 0) {
        out.add(Frame('refuse', '+', conf, span: t.substring(h.s, h.e)));
        continue;
      }
      if (act == 'ask_order' && !RegExp('(请|麻烦|发|告诉|提供|给我|多少|是什么|报|查|说一下|看一下|方便|吗|呢|几|哪)').hasMatch(t) && !q) {
        conf *= .7;
      }
      out.add(Frame(act, pol > 0 ? '+' : '-', conf,
          pct: act == 'discount' ? readPct(t) : null,
          when: (act == 'resend' || act == 'promise_time' || act == 'expedite') ? readWhen(t) : null,
          reason: reason,
          span: t.substring(h.s, h.e)));
    }

    // causes: a reason with a mark of delay or trouble near it
    if (!c.cond || true) {
      for (final e in _reasons.entries) {
        final m = e.value.firstMatch(t) ?? e.value.firstMatch(f);
        if (m == null) continue;
        if (kept.any((k) => k.s <= m.start && m.end <= k.e && k.cue.c.act != 'deny_fault' && k.cue.c.act != 'apologize')) continue;
        final marked = _strong.hasMatch(t) ||
            _marks.hasMatch(t) ||
            RegExp('(因为|由于)').hasMatch(prev?.text ?? '') ||
            _marks.hasMatch(next?.text ?? '');
        if (q || _quote.hasMatch(t.substring(0, m.start)) && !RegExp('(说|讲)').hasMatch(t.substring(m.start))) continue;
        if (RegExp('(哪一|哪个|哪段|哪里|是否|是不是|为了|申请)').hasMatch(t)) continue;
        if (RegExp('(对于|关于)\$').hasMatch(t.substring(0, m.start))) continue;
        var pol = 1;
        final lead = t.substring(0, m.start).replaceAll(_mustDouble, '必须').replaceAll(_notNeg, '〇');
        final leadTail = lead.length > 6 ? lead.substring(lead.length - 6) : lead;
        if (RegExp('(不是|并非|并不是|不在于|不是因为|并不是因为|跟.{0,3}没关系|和.{0,3}无关|并没有|没有|别怪|不怪)').hasMatch(leadTail)) pol = -1;
        final counter = c.cond && next != null && RegExp('就.{0,6}了').hasMatch(next.text);
        if (counter) pol = 1;
        out.add(Frame('cause', pol > 0 ? '+' : '-', marked || counter ? .95 : .5, reason: e.key, span: m[0]!));
      }
    }

    // a refusal that only says "no" to an offer named in the same clause is that offer denied
    if (out.any((x) => x.pol == '-' && x.act != 'cause')) out.removeWhere((x) => x.act == 'refuse' && x.span.length <= 4);
    // keep one frame per act and polarity in the clause (cause: one per reason)
    final seen = <String, Frame>{};
    for (final x in out) {
      final k = x.act == 'cause' ? '${x.key}${x.reason}' : x.key;
      final o = seen[k];
      if (o == null || x.conf > o.conf) seen[k] = x;
    }
    final res = seen.values.toList();
    // several reasons said together: one cause, the first named
    final causes = res.where((x) => x.act == 'cause' && x.pol == '+').toList();
    if (causes.length > 1) {
      causes.sort((a, b) => t.indexOf(a.span).compareTo(t.indexOf(b.span)));
      final top = causes.reduce((a, b) => b.conf > a.conf ? b : a);
      res.removeWhere((x) => x.act == 'cause' && x.pol == '+' && !identical(x, top));
      res.remove(top);
      res.add(Frame('cause', '+', top.conf, reason: causes.first.conf >= .9 ? causes.first.reason : top.reason, span: top.span));
    }
    return res;
  }

  // ---------------------------------------------------------------- slots

  static const _digit = {'零': 0, '〇': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};

  /// a number written in digits or hanzi (一百二十, 十五, 2.5, 八五 as 8.5 in 八五折)
  static num? readNumber(String s) {
    s = s.replaceAll('．', '.').replaceAll('点', '.');
    final d = double.tryParse(s);
    if (d != null) return d;
    if (s.isEmpty) return null;
    if (s == '半') return .5;
    if (s.runes.every((r) => _digit.containsKey(String.fromCharCode(r)))) {
      // 八五 → 85, 九 → 9
      return int.parse(s.runes.map((r) => _digit[String.fromCharCode(r)]!).join());
    }
    var total = 0, cur = 0;
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      if (_digit.containsKey(ch)) {
        cur = _digit[ch]!;
      } else if (ch == '十') {
        total += (cur == 0 ? 1 : cur) * 10;
        cur = 0;
      } else if (ch == '百') {
        total += cur * 100;
        cur = 0;
      } else if (ch == '千') {
        total += cur * 1000;
        cur = 0;
      } else if (ch == '万') {
        total = (total + cur) * 10000;
        cur = 0;
      } else {
        return null;
      }
    }
    return total + cur;
  }

  static final _zhe = RegExp('([零一二两三四五六七八九十点\\d.．]{1,3})折');
  static final _pctRe = RegExp('(百分之([零一二两三四五六七八九十\\d.]+)|([\\d.]+|[一二两三四五六七八九十]+)\\s*(%|％|个点|个百分点))');

  /// the discount in percent off the price, if the words say it (九折 10, 八五折 15, 8.5折 15, 对折 50, 百分之十 10)
  static int? readPct(String t) {
    if (t.contains('对折') || t.contains('半价')) return 50;
    final m = _zhe.firstMatch(t);
    if (m != null) {
      final v = readNumber(m[1]!);
      if (v != null) {
        // 9 → 90 %, 85 → 85 %, 8.5 → 85 %
        final paid = v < 10 ? v * 10 : v.toDouble();
        if (paid > 0 && paid < 100) return (100 - paid).round();
      }
    }
    final p = _pctRe.firstMatch(t);
    if (p != null) {
      final v = readNumber(p[2] ?? p[3]!);
      if (v != null && v > 0 && v < 100) return v.round();
    }
    return null;
  }

  static const _week = {'一': 'monday', '二': 'tuesday', '三': 'wednesday', '四': 'thursday', '五': 'friday', '六': 'saturday', '日': 'sunday', '天': 'sunday'};

  /// when it is sent or arrives, if said
  static String? readWhen(String t) {
    final m = RegExp('(大后天|后天|明天|明早|明晚|明儿|明日|今天|今日|今晚|当天|马上|立刻|现在|(下个?)?(周|星期|礼拜)([一二三四五六日天])|'
            '([零一二两三四五六七八九十\\d]+)\\s*(个)?(工作日|天|日|小时|个小时)(之内|以内|内)?)')
        .firstMatch(t);
    if (m == null) return null;
    final w = m[0]!;
    if (w == '大后天') return '3_days';
    if (w == '后天') return 'dayafter';
    if (w.startsWith('明')) return 'tomorrow';
    if (w.startsWith('今') || w == '当天' || w == '马上' || w == '立刻' || w == '现在') return 'today';
    if (m[4] != null) return _week[m[4]!];
    if (m[5] != null) {
      final n = readNumber(m[5]!);
      if (n == null) return null;
      if (m[7]!.contains('小时')) return '${(n / 24).ceil()}_days';
      if (n == 1 && !m[7]!.contains('工作')) return 'tomorrow';
      return '${n.round()}_days';
    }
    return null;
  }
}

const offerActsNlu = {'resend', 'expedite', 'discount', 'compensate', 'promise_time'};

class Clause {
  final String text;

  /// ended in a question mark
  final bool q;

  /// the condition of 如果…就… (what it says is not done), or what follows it
  final bool cond, afterCond;
  const Clause(this.text, this.q, {this.cond = false, this.afterCond = false});
  @override
  String toString() => '[$text${q ? '?' : ''}${cond ? ' if' : ''}]';
}

class _C {
  final Cue c;
  final RegExp exactRe;
  final RegExp? soundRe;
  _C(this.c)
      : exactRe = RegExp(c.re),
        soundRe = c.exact ? null : RegExp(TalkNlu.fold(c.re));

  /// a match by sound is taken as a slip of the recognizer only when writing back one of its characters (two in a
  /// span of five or more) as a character of the cue makes the cue match as written: 到歉 → 道歉, 锺新发 → 重新发;
  /// not 我是物 → 我失误 (two slips in three) nor 前一 → 歉意.
  late final Map<String, List<String>> _lit = () {
    final m = <String, List<String>>{};
    for (final r in c.re.runes) {
      if (r < 0x3400) continue;
      final ch = String.fromCharCode(r);
      final l = m[TalkNlu.fold(ch)] ??= [];
      if (!l.contains(ch)) l.add(ch);
    }
    return m;
  }();

  bool _whole(String s) {
    for (final m in exactRe.allMatches(s)) {
      if (m.start == 0 && m.end == s.length) return true;
    }
    return false;
  }

  static final Set<String> _words = {for (var i = 0; i + 1 < soundWords.length; i += 2) soundWords.substring(i, i + 2)};

  bool likely(String t, int start, int end) {
    final ch = t.substring(start, end).split('');
    // the character written by the recognizer makes a real word with its neighbour: not a slip (办法, 积分, 推卸)
    bool real(int i) {
      final p = start + i, o = t[p];
      return (p > 0 && _words.contains(t[p - 1] + o)) || (p + 1 < t.length && _words.contains(o + t[p + 1]));
    }

    final max = ch.length >= 5 ? 2 : 1;
    bool fix(int from, int left) {
      if (_whole(ch.join())) return true;
      if (left == 0) return false;
      for (var i = from; i < ch.length; i++) {
        final keep = ch[i];
        if (real(i)) continue;
        for (final alt in _lit[TalkNlu.fold(keep)] ?? const <String>[]) {
          if (alt == keep) continue;
          ch[i] = alt;
          if (fix(i + 1, left - 1)) {
            ch[i] = keep;
            return true;
          }
        }
        ch[i] = keep;
      }
      return false;
    }

    return fix(0, max);
  }
}

class _Hit {
  final _C cue;
  final int s, e;
  final double w;
  _Hit(this.cue, this.s, this.e, this.w);
}
