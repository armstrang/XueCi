/// Resolves transport dates in context. The intent classifier's `when` field
/// can describe either dispatch or arrival, so it cannot settle a deadline.
library;

import 'clauses.dart';
import 'nlu.dart';

typedef DeliveryTerms = ({int? dispatch, int? arrival, bool replacesArrival, bool needsDate});

final _date = RegExp(
  r'(?:下(?:个)?|本|这(?:个)?|上(?:个)?)?(?:周|星期|礼拜)[一二三四五六日天]|'
  r'大后天|后天|明天|明早|明晚|明日|今天|今晚|今日|当日|当天|'
  r'[零一二两三四五六七八九十0-9]+(?:个)?(?:工作日|天|日|小时)(?:之内|以内|内)?',
);
final _personalArrival = RegExp(r'(?:到|到达|抵达)(?:了|的)?(?:学校|家里|车站|图书馆|食堂)');
final _shipping = RegExp(r'重新发|补发|补寄|寄出|发货|发出|出库|发走|寄走|安排发|发车');
final _arrival = RegExp(
  r'送到|送上门|收到|收货|到货|到达|抵达|到手|送达|交到|到您|到你|到仓|到不了|送不到|能到|会到|可以到|(?<!看|找|碰|买|遇|拿|听|闻|想|提|不)到(?!歉|底|现在|时候|学校|家|车站|图书馆)',
);
final _old = RegExp(r'^(?:原先|原来|本来|原定|之前|先前|原计划|原本)');
final _revision = RegExp(r'改到|改为|改成|改期|取消|更正|重新确认|最早|最快|最新|现在|推迟|提前');
final _question = RegExp(r'什么时候|哪天|能不能|可不可以|会不会|能否');
final _uncertain = RegExp(r'不确定|还没确定|无法确认|还不清楚|还不知道|说不准|不敢保证|不能保证|可能|也许|或许|看情况|说不好|不一定|才有机会|待定|没把握');
final _negative = RegExp(
  r'到不了|送不到|赶不上|不能.{0,5}到|不会.{0,5}到|无法.{0,3}(?:到|收)|没法.{0,3}(?:到|收)|不能.{0,4}(?:送到|收到)|不可能.{0,4}到|已取消|取消了|不行了|作废|不作数',
);
final _urgent = RegExp(r'急用|紧急|要紧|优先|先送|先到|先交');
final _remainder = RegExp(r'剩下|其余|余下|后面那批|第二批|尾货');
final _split = RegExp(r'分批|那一批|那批|那部分|一部分|先把|先给|先送|先到|先交');
final _uncertainTerms = RegExp(r'到货时间|到达时间|具体.{0,5}到|送到时间|收货时间');
final _lowerBound = RegExp(r'(?:最早|最快)[^，。；]{0,5}$');
final _upperBound = RegExp(r'(?:最晚|最迟|不超过)[^，。；]{0,5}$');
final _betweenDates = RegExp(r'^\s*(?:到|至|[-~～—])\s*$');
final _rangeEnd = RegExp(r'^(?:之间|期间|中间)');
const _week = {'一': 0, '二': 1, '三': 2, '四': 3, '五': 4, '六': 5, '日': 6, '天': 6};

int? _day(String token, int today) {
  final weekday = _week[token[token.length - 1]];
  if (weekday != null && RegExp(r'周|星期|礼拜').hasMatch(token)) {
    final offset = weekday - today;
    if (token.startsWith('下')) return 7 + offset;
    if (token.startsWith('上')) return null;
    if (token.startsWith('这') || token.startsWith('本')) return offset < 0 ? null : offset;
    return (offset + 7) % 7;
  }
  if (token.contains('工作日')) {
    final count = TalkNlu.readNumber(token.split(RegExp(r'个?工作日')).first);
    if (count == null || count < 0 || count > 3650) return null;
    var remaining = count.toInt();
    var days = 0;
    while (remaining > 0) {
      days++;
      if ((today + days) % 7 < 5) remaining--;
    }
    return days;
  }
  final when = TalkNlu.readWhen(token);
  return switch (when) {
    'today' => 0,
    'tomorrow' => 1,
    'dayafter' => 2,
    final String v when v.endsWith('_days') => int.tryParse(v.split('_').first),
    _ => null,
  };
}

/// Dates belong to a transport event within their own clause. A date by itself
/// can answer the client's last question about arrival.
DeliveryTerms deliveryTerms(String text, List<Frame> frames, {required int today, required int deadline, bool answeringArrival = false}) {
  int? dispatch, arrival, urgentArrival;
  var cancelled = false;
  var missing = false;
  var oldArrivalSeen = false;
  var urgentCancelled = false;
  var ambiguous = false;
  final deliveryActs = frames.where(
    (f) => f.pol == '+' && (f.act == 'resend' || f.act == 'promise_time' || f.act == 'expedite'),
  );
  final repaired = TalkNlu.repair(text);
  final split = _urgent.hasMatch(repaired) && (_remainder.hasMatch(repaired) || _split.hasMatch(repaired));
  for (final clause in commitmentClauses(repaired, firmOnly: true)) {
    final t = clause.text;
    final dates = _date.allMatches(t).toList();
    final ship = _shipping.hasMatch(t);
    final arrive = _arrival.hasMatch(t);
    final urgent = split && _urgent.hasMatch(t);
    if (clause.cond || quotedCommitment(t) || _personalArrival.hasMatch(t) || _remainder.hasMatch(t)) continue;
    if (_old.hasMatch(t) && arrive && dates.isNotEmpty) {
      oldArrivalSeen = true;
      if (_negative.hasMatch(t)) {
        arrival = null;
        cancelled = true;
      }
      continue;
    }
    final revision = _revision.hasMatch(t);
    if ((clause.q || _question.hasMatch(t)) && !_uncertain.hasMatch(t)) continue;
    if ((_negative.hasMatch(t) || _uncertain.hasMatch(t)) && (arrive || _uncertainTerms.hasMatch(t))) {
      missing = true;
      if (urgent) {
        urgentArrival = null;
        urgentCancelled = true;
      } else {
        arrival = null;
        cancelled = true;
      }
      continue;
    }
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final day = _day(date[0]!, today);
      final next = i + 1 < dates.length ? dates[i + 1].start : t.length;
      final previous = i == 0 ? 0 : dates[i - 1].end;
      final suffix = t.substring(date.end, next);
      final prefix = t.substring(previous, date.start);
      final endsWindow = i > 0 && _betweenDates.hasMatch(prefix) && _rangeEnd.hasMatch(suffix);
      if (i + 1 < dates.length && _betweenDates.hasMatch(suffix) &&
          _rangeEnd.hasMatch(t.substring(dates[i + 1].end))) {
        continue;
      }
      final shipAfter = _shipping.firstMatch(suffix);
      final arriveAfter = _arrival.firstMatch(suffix);
      // E.g. 周四发货周六到, and 发货时间是周四.
      final firstIsArrival = arriveAfter != null && (shipAfter == null || arriveAfter.start < shipAfter.start);
      final firstIsDispatch = shipAfter != null && !firstIsArrival;
      if (firstIsDispatch ||
          (ship && !arrive) ||
          (!firstIsArrival && _shipping.hasMatch(prefix) && !_arrival.hasMatch(prefix))) {
        dispatch = day;
        missing = true;
        continue;
      }
      final shortAnswer =
          (answeringArrival || cancelled) &&
          !ship &&
          !arrive &&
          dates.length == 1 &&
          RegExp(r'^(?:最晚|最早|大概|应该|就|在|是|好|可以|得等|得|要等)?(?:[一二两三四五六七八九十0-9]+)?$').hasMatch(prefix) &&
          RegExp(r'^(?:上午|下午|晚上|之前|以前|前|左右|吧|能行|就行|可以|没问题)?$').hasMatch(suffix);
      final arrivalClaim =
          firstIsArrival ||
          (!ship && (arrive || endsWindow)) ||
          shortAnswer ||
          (!ship && revision && (oldArrivalSeen || cancelled || answeringArrival) && dates.length == 1);
      if (!arrivalClaim) continue;
      if (day == null) {
        missing = true;
        continue;
      }
      if (_lowerBound.hasMatch(prefix) && !_upperBound.hasMatch(prefix) && day <= deadline) {
        missing = true;
        if (urgent) {
          urgentArrival = null;
          urgentCancelled = true;
        } else {
          arrival = null;
          cancelled = true;
        }
        continue;
      }
      if (urgent) {
        urgentArrival = day;
      } else {
        if (arrival != null && arrival != day && !revision) ambiguous = true;
        if (revision) ambiguous = false;
        arrival = day;
      }
    }
    if ((arrive || ship) && dates.isEmpty) missing = true;
  }
  // A same-turn revision can be elliptical: 本来周四能到，现在最早周六.
  final replacement = split ? urgentArrival : (ambiguous ? null : arrival);
  final replace =
      replacement != null ||
      cancelled ||
      urgentCancelled ||
      ambiguous ||
      (oldArrivalSeen && _revision.hasMatch(repaired));
  return (
    dispatch: dispatch,
    arrival: replacement,
    replacesArrival: replace,
    needsDate: replacement == null && (missing || ambiguous || deliveryActs.isNotEmpty),
  );
}
