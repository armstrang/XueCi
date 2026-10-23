/// Practice: Cards, Quiz and today's session share one runner (runner.js, cards.js, quiz.js, summary.js, mock.js).
/// A run is a list of items: cards and questions. Answers go to the engine (LM.answer). Wrong answers come back a
/// few items later (at most twice per word). Tiredness offers one short break per sitting (调息).
library;

import 'dart:async';
import 'dart:math' as math;

import '../data/words.dart';
import '../engine/learn.dart';
import '../engine/model.dart';
import '../i18n/l10.dart';
import 'app.dart';
import 'speech.dart';
import 'native.dart';

const roundQ = 12, roundC = 20;

int nowMs() => DateTime.now().millisecondsSinceEpoch;

class MockRun {
  final Mock m;
  bool started = false;
  final Set<String> shown = {};
  int t0 = 0;
  MockScore? r;
  List<dynamic>? prev;
  List<({String t, String? bk, String? bl})> adv = [];
  double used = 0;
  int warned = 0;
  String? sec; // the section whose clock runs
  int secT0 = 0;
  final Set<String> late = {}; // sections that ran out of time
  MockRun(this.m);
}

class Brk {
  final Map<String, Object> f; // why: {k: acc|slow|time, a, b, m}
  int? end, t0;
  Brk(this.f);
}

class Run {
  final String mode;
  final List<Item> items;
  int i = 0, ok = 0, tot = 0, over = 0;
  final Map<String, int> before = {};
  final Map<String, Word> wrong = {};
  final List<(String, String)> conf = [];
  final Map<String, int> again = {};
  final bool exam;
  final int lv;
  final void Function(int right, int words)? after;
  final MockRun? mock;
  int? end; // the clock of the simulation's section (ms)
  Timer? timer;
  bool timeUp = false, closed = false;
  List<String> notes = [];
  Brk? brk;
  Timer? brT;
  bool quick = false; // today's practice, the two-minute version
  final List<bool> recent = []; // answers in this run, for the easy word after a run of misses
  int eased = 0, easedAt = -9;
  Run(this.mode, this.items, {this.exam = false, required this.lv, this.after, this.mock});
  Item? get cur => i < items.length ? items[i] : null;
}

/// a ready-made round (today's trial, words to strengthen, a test's mistakes)
class Pending {
  final String mode;
  final List<Item> items;
  final void Function(int right, int words)? after;
  Pending(this.mode, this.items, {this.after});
}

/// a sitting: answers with gaps of 10 minutes at most (for the rest offer)
class Sitting {
  int t0 = 0, last = 0;
  final List<(int, int)> ans = []; // right 1/0, ms
  bool shown = false;
  ({int at, int acc, bool told})? brk;
}

class Runner {
  final App a;
  Runner(this.a);
  Run? run;
  Pending? pending;
  Sitting sit = Sitting();
  LM get lm => a.lm;

  void reset() {
    run?.timer?.cancel();
    run?.brT?.cancel();
    run = null;
    a.inExam = false;
  }

  bool get ttsOK => a.ttsOK;

  Run make(String mode) {
    reset();
    List<Item> items;
    void Function(int, int)? after;
    var exam = false;
    MockRun? mock;
    final lv = a.level;
    if (pending != null && pending!.mode == mode) {
      items = pending!.items;
      after = pending!.after;
      pending = null;
    } else if (mode == 'card') {
      items = [for (final d in lm.cardDeck(a.pool(), roundC)) Item.card(d)];
    } else if (mode == 'session') {
      items = lm.session(a.sessionExtra);
      if (a.sessionQuick) items = quickOf(items);
    } else if (a.qType == 'mock') {
      exam = true;
      mock = MockRun(lm.mockExam(lv, short: a.mockShort));
      items = mock.m.items;
    } else {
      items = lm.quizRound(a.pool(), roundQ, a.qType);
    }
    return run = Run(mode, items, exam: exam, lv: lv, after: after, mock: mock)..quick = mode == 'session' && a.sessionQuick;
  }

  /// two minutes: six of today's reviews (or, with none due, the first two new words and what comes with them)
  static List<Item> quickOf(List<Item> all) {
    final q = all.where((it) => it.k == 'q').take(6).toList();
    if (q.length >= 4) return q;
    final out = <Item>[];
    var cards = 0;
    for (final it in all) {
      if (it.k == 'card' && ++cards > 2) break;
      out.add(it);
    }
    return out;
  }

  /// after several misses in a row, a word the learner is sure of comes next: a quick win keeps the run going
  /// (at most four times a run, not in tests)
  void _ease(Run r, bool ok) {
    if (r.exam) return;
    r.recent.add(ok);
    final n = r.recent.length;
    if (n < 6 || r.eased >= 4 || r.i - r.easedAt < 3) return;
    final last = r.recent.sublist(math.max(0, n - 8));
    if (last.where((x) => x).length / last.length >= .7) return;
    final skip = {for (final it in r.items) it.d.id};
    final d = lm.easyWord(r.mode == 'session' ? lm.data : a.pool(), skip);
    if (d == null) return;
    r.items.insert(math.min(r.items.length, r.i + 1), r.mode == 'card' ? Item.card(d) : Item.q(d, 'm'));
    r.eased++;
    r.easedAt = r.i;
  }

  /// the run of the screen, made when needed; the item to show next (null = the summary)
  Run ensure(String mode) => run != null && run!.mode == mode ? run! : make(mode);

  void tick() {
    final r = run;
    final m = r?.mock;
    if (r == null || m == null || r.end == null || m.sec == null) return;
    if (nowMs() >= r.end!) {
      // time's up for this section: what's left in it counts as unanswered, the next section waits for its start
      final k = m.sec!;
      for (final it in r.items.where((x) => x.part == k && !x.done)) {
        it.done = true;
        it.ok = false;
      }
      m.late.add(k);
      r.timeUp = true;
      while (r.i < r.items.length && r.items[r.i].part == k) {
        r.i++;
      }
      _secEnd();
      a.changed();
    }
  }

  /// the section's clock stops: its time goes to the time used
  void _secEnd() {
    final r = run!, m = r.mock!;
    if (m.sec == null) return;
    r.timer?.cancel();
    r.timer = null;
    r.end = null;
    final p = m.m.parts.firstWhere((x) => x.k == m.sec);
    m.used += math.min(p.sec.toDouble(), (nowMs() - m.secT0) / 1000);
    m.sec = null;
  }

  /// a section of the simulation starts: its own clock, like the real paper
  void mockPart(String k) {
    final r = run!, m = r.mock!;
    m.shown.add(k);
    m.sec = k;
    m.secT0 = nowMs();
    r.end = nowMs() + m.m.parts.firstWhere((x) => x.k == k).sec * 1000;
    r.timer?.cancel();
    r.timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    a.changed();
  }

  int secondsLeft() {
    final e = run?.end;
    return e == null ? 0 : math.max(0, ((e - nowMs()) / 1000).ceil());
  }

  /// before showing an item: a break offer when tired (never during a test), the level before the answer
  void prepare() {
    final r = run;
    if (r == null) return;
    a.inExam = r.mock != null && r.mock!.started && r.mock!.r == null && r.i < r.items.length;
    final it = r.cur;
    if (it == null || r.brk != null) return;
    if (r.mock != null && (!r.mock!.started || !r.mock!.shown.contains(it.part))) return;
    if (!r.exam && it.st == null && it.words == null && it.tones == null && !it.typed) {
      final f = fatigue();
      if (f != null) {
        sit.shown = true;
        r.brk = Brk(f);
        return;
      }
    }
    r.before.putIfAbsent(it.d.id, () => a.lvl(it.d));
  }

  void next() {
    final r = run;
    if (r == null) return;
    r.i++;
    a.changed();
  }

  // ---------------------------------------------------------------- rest (调息)
  void noteAns(bool ok, int ms) {
    final t = nowMs();
    if (sit.last == 0 || t - sit.last > 600000) sit = Sitting()..t0 = t;
    sit.last = t;
    sit.ans.add((ok ? 1 : 0, math.min(60000, ms)));
  }

  static int accOf(List<(int, int)> a) =>
      a.isEmpty ? 0 : ((a.fold<int>(0, (x, y) => x + y.$1) / a.length) * 100).round();

  Map<String, Object>? fatigue() {
    final x = sit.ans;
    if (sit.shown || x.length < 20 || nowMs() - sit.last > 600000) return null;
    final f = x.sublist(0, 10), l = x.sublist(x.length - 10);
    double med(List<(int, int)> y) {
      final m = y.map((e) => e.$2).toList()..sort();
      return (m[4] + m[5]) / 2;
    }

    final aa = accOf(f), bb = accOf(l);
    if (aa - bb >= 15) return {'k': 'acc', 'a': aa, 'b': bb};
    if (med(l) >= 1.4 * math.max(1500, med(f))) return {'k': 'slow'};
    final m = ((nowMs() - sit.t0) / 60000).round();
    return m >= 25 ? {'k': 'time', 'm': m} : null;
  }

  void breakStart() {
    final b = run?.brk;
    if (b == null) return;
    b.end = nowMs() + 300000;
    b.t0 = nowMs();
    // the break view counts down by itself; the app changes only when the break is over
    run!.brT = Timer.periodic(const Duration(seconds: 1), (_) {
      if (run?.brk != b) return;
      if (nowMs() >= b.end!) {
        run!.brT?.cancel();
        a.changed();
      }
    });
    a.changed();
  }

  void breakEnd(bool stop) {
    final r = run;
    if (r == null) return;
    r.brT?.cancel();
    final b = r.brk;
    r.brk = null;
    if (b != null && b.end != null) {
      sit.brk = (at: sit.ans.length, acc: accOf(sit.ans.length > 10 ? sit.ans.sublist(sit.ans.length - 10) : sit.ans), told: false);
    }
    if (stop) r.i = r.items.length;
    a.changed();
  }

  /// bring a word back a few items later (at most twice per word in a run)
  void again(Item it, Item copy) {
    final r = run!;
    final n = r.again[it.d.id] ?? 0;
    if (n >= 2 || r.exam) return;
    r.again[it.d.id] = n + 1;
    r.items.insert(math.min(r.items.length, r.i + 4), copy);
  }

  // ---------------------------------------------------------------- cards
  void cardStart(Item it) {
    if (it.st != null) return;
    it.st = 'front';
    it.t0 = nowMs();
    it.extra = !lm.has(it.d.id); // fresh
  }

  bool fresh(Item it) => it.extra == true;

  void _cardShow(Item it, bool ok) {
    final r = run!;
    it.st = 'back';
    r.tot++;
    if (ok) {
      r.ok++;
    } else {
      r.wrong[it.d.id] = it.d;
    }
    noteAns(ok, nowMs() - it.t0);
    _ease(r, ok);
    studied();
    a.changed();
  }

  void _cardFollow(Item it, bool ok) {
    final r = run!;
    if (!ok) {
      again(it, Item.card(it.d));
      return;
    }
    if (r.mode == 'session' && fresh(it) && !it.again && it.alt != true) {
      it.alt = true; // followed
      r.items.insert(math.min(r.items.length, r.i + 5), Item.q(it.d, 's'));
    }
  }

  void cardDont(Item it) {
    lm.answer(it.d, Ans('cn', false, ms: nowMs() - it.t0));
    it.res = 'no';
    _cardShow(it, false);
    _cardFollow(it, false);
  }

  void cardKnow(Item it) {
    it.ms = nowMs() - it.t0;
    if (lm.rnd.next() < lm.checkP(it.d)) {
      final q = lm.checkType(it.d, it.heard);
      it.checkQ = q;
      it.check = lm.question(it.d, q);
      it.st = 'check';
      a.changed();
      return;
    }
    lm.answer(it.d, Ans('cu', true, ms: it.ms, claim: true, unchecked: true));
    it.res = 'trust';
    _cardShow(it, true);
    _cardFollow(it, true);
  }

  void cardCheck(Item it, int i) {
    final c = it.check!;
    final ok = i == c.ans;
    final x = !ok && it.checkQ == 'cm' ? c.words![i].id : null;
    it.pick = i;
    lm.answer(it.d, Ans(it.checkQ!, ok, ms: it.ms, x: x, claim: true, over: !ok));
    if (!ok) {
      run!.over++;
      if (x != null) run!.conf.add((it.d.id, x));
    }
    it.res = ok ? 'ok' : 'over';
    _cardShow(it, ok);
    _cardFollow(it, ok);
  }

  /// "I was wrong" after an unchecked claim: taken back and counted as not known (no extra penalty)
  void cardOops(Item it) {
    final r = run!;
    lm.undo();
    lm.answer(it.d, Ans('cn', false, ms: it.ms));
    r.ok--;
    r.wrong[it.d.id] = it.d;
    it.res = 'no';
    if (sit.ans.isNotEmpty) sit.ans[sit.ans.length - 1] = (0, sit.ans.last.$2);
    _cardFollow(it, false);
    a.changed();
  }

  // ---------------------------------------------------------------- questions
  void qPrepare(Item it) {
    if (it.words != null || it.tones != null || it.typed) return;
    if (it.q == 'u') {
      // speaking: nothing to build, the phone listens (qSpoken)
      it.typed = true;
      it.t0 = nowMs();
      return;
    }
    it.apply(lm.question(it.d, it.q!));
    it.t0 = nowMs();
  }

  void qTyped(Item it, String? text) {
    if (it.done) return;
    final r = text == null ? const PyRes(false) : lm.pyCheck(it.d, text);
    it.typedText = text ?? '';
    it.timedOut = r.toneless == true; // shown as "the tones were missing"
    it.alt = r.alt;
    qAnswer(it, r.ok ? -2 : -3);
  }

  /// speaking: the first try is the answer (every hanzi right = right); later tries only show again
  void qSpoken(Item it, SpeakResult r) {
    it.alt = r;
    it.typedText = r.heard;
    if (!it.done) {
      qAnswer(it, r.all ? -2 : -3);
    } else {
      a.changed();
    }
  }

  void qAnswer(Item it, int i) {
    final r = run!;
    if (it.done) return;
    it.done = true;
    it.pick = i;
    final ok = i == -2 || (i >= 0 && i == it.ans);
    it.ok = ok;
    final x = !ok && i >= 0 && !const {'s', 't', 'lt', 'lj'}.contains(it.q) && it.words != null ? it.words![i].id : null;
    final ms = nowMs() - it.t0;
    lm.answer(it.d, Ans(LM.logQ(it.q!), ok, ms: ms, x: x, exam: r.exam, hint: it.hint));
    r.tot++;
    if (!r.exam) noteAns(ok, ms);
    _ease(r, ok);
    if (ok) {
      r.ok++;
    } else {
      r.wrong[it.d.id] = it.d;
      if (x != null) r.conf.add((it.d.id, x));
      again(it, Item.q(it.d, it.q!));
    }
    studied();
    if (r.exam) {
      r.i++;
      final m = r.mock;
      if (m != null && m.sec != null && (r.cur == null || r.cur!.part != m.sec)) _secEnd();
    }
    a.changed();
  }

  /// sentence building: the pieces in the order tapped
  void qOrder(Item it, List<String> picked) {
    if (it.done) return;
    it.typedText = picked.join();
    final want = RegExp(r'[。！？!?.]+$').hasMatch(it.d.z.trim()) ? it.d.z.trim().replaceAll(RegExp(r'[。！？!?.]+$'), '') : it.d.z.trim();
    qAnswer(it, picked.isNotEmpty && it.typedText == want ? -2 : -3);
  }

  /// the learner says their wrong pick also fits the sentence: taken back, the two never offered together again
  /// (3 times a day at most)
  int ambLeft() {
    final d = a.lm.today();
    final x = a.note['amb'];
    return x is Map && x['d'] == d ? 3 - (x['n'] as num).toInt() : 3;
  }

  void qAmbig(Item it) {
    final r = run!;
    final p = it.words != null && (it.pick ?? -1) >= 0 ? it.words![it.pick!] : null;
    if (p == null || it.heard || it.ok == true) return;
    lm.undo();
    lm.markAmbiguous(it.d.id, p.id);
    it.heard = true; // marked ambiguous
    r.tot--;
    r.wrong.remove(it.d.id);
    r.conf.removeWhere((c) => c.$1 == it.d.id && c.$2 == p.id);
    final j = r.items.indexWhere((x) => r.items.indexOf(x) > r.i && x.d == it.d && x.q == it.q && x.words == null && x.tones == null);
    if (j > 0) {
      r.items.removeAt(j);
      r.again[it.d.id] = math.max(0, (r.again[it.d.id] ?? 1) - 1);
    }
    if (sit.ans.isNotEmpty) sit.ans.removeLast();
    final day = a.lm.today();
    final x = a.note['amb'];
    a.note['amb'] = {'d': day, 'n': (x is Map && x['d'] == day ? (x['n'] as num).toInt() : 0) + 1};
    a.saveNote();
    a.changed();
  }

  // ---------------------------------------------------------------- the end of a run
  /// notes under the summary: answers after a break, repeating now vs tomorrow, a late-night note
  List<String> sumNotes() {
    final r = run!;
    final t = a.t;
    final out = <String>[];
    if (r.exam || r.tot == 0) return out;
    final b = sit.brk;
    if (b != null && !b.told && sit.ans.length - b.at >= 5) {
      final x = sit.ans.sublist(b.at);
      sit.brk = (at: b.at, acc: b.acc, told: true);
      out.add(t.brAfter(x.fold<int>(0, (s, y) => s + y.$1), x.length, b.acc));
    }
    final p = lm.plan();
    if ((r.mode == 'session' && a.sessionExtra) || (r.mode != 'session' && p.todayLeft == 0)) {
      final g = lm.gainList(r.before.keys.map((id) => a.vocab.idx[id]).whereType<Word>());
      if (g.n >= 5 && g.later > g.now * 1.5) {
        String f(double x) => a.fmt1(x / g.n);
        out.add(t.capNote(g.n, f(g.now), f(g.later)));
      }
    }
    final h = DateTime.now().hour;
    if (h >= 23 || h < 4) {
      final key = lm.dayOf(lm.now() - 240);
      if (a.note['night'] != key) {
        a.note['night'] = key;
        a.saveNote();
        out.add(t.nightNote);
      }
    }
    return out;
  }

  void close() {
    final r = run!;
    r.timer?.cancel();
    if (r.closed) return;
    r.closed = true;
    lm.updWeak();
    r.notes = sumNotes();
    if (r.after != null) {
      final words = r.items.map((x) => x.d.id).toSet().length;
      final f = r.after!;
      Timer.run(() => f(words - r.wrong.length, words));
    }
  }

  // ---------------------------------------------------------------- HSK simulation
  void mockStart() {
    final m = run!.mock!;
    m.started = true;
    m.t0 = nowMs();
    a.changed();
  }

  /// the full paper or the short one (a third of it, same sections)
  void mockLength(bool short) {
    if (a.mockShort == short) return;
    a.mockShort = short;
    a.saveUI();
    reset();
    a.changed();
  }

  void mockFinish() {
    final r = run!;
    final m = r.mock!;
    if (m.r != null) return;
    _secEnd();
    r.timer?.cancel();
    m.r = lm.mockScore(m.m);
    final prev = lm.mocks.where((x) => x[1] == m.m.L).toList();
    m.prev = prev.isEmpty ? null : prev.last;
    lm.mockSave(m.m, m.r!, m.used);
    m.adv = mockAdvice(m);
    lm.updWeak();
    a.inExam = false;
  }

  List<({String t, String? bk, String? bl})> mockAdvice(MockRun m) {
    final t = a.t;
    final r = m.r!;
    final mA = t.mkA;
    String f(String k, [List<Object?> args = const []]) => l10f(mA[k], args);
    final out = <({String t, String? bk, String? bl})>[];
    final L = m.m.L;
    final wrong = m.m.items.where((it) => it.ok != true).toList();
    final pct = r.total / r.max;
    final next = a.vocab.levels.contains(L + 1) ? L + 1 : 0;
    if (r.pass && pct >= .85) {
      out.add((t: f('top', [L, next]), bk: next > 0 ? 'next' : null, bl: next > 0 ? f('nextBtn', [next]) : null));
    } else if (r.pass) {
      out.add((t: f('pass'), bk: null, bl: null));
    } else if (pct >= .5) {
      out.add((t: f('near', [r.need - r.total]), bk: null, bl: null));
    } else {
      out.add((t: f('low', [L]), bk: 'plan', bl: f('planBtn')));
    }
    final parts = [...r.parts]..sort((x, y) => x.score - y.score);
    final weak = parts.isEmpty ? null : parts.first;
    if (weak != null && weak.score < 85 && r.parts.length > 1) {
      out.add((t: l10f((mA['part'] as Map)[weak.k], [weak.score]), bk: 'part:${weak.k}', bl: f('partBtn')));
    }
    bool hard(Set<String> q) {
      final n = m.m.items.where((it) => q.contains(it.q)).length;
      return n > 0 && wrong.where((it) => q.contains(it.q)).length / n >= .34;
    }

    if (hard({'c'})) out.add((t: f('cloze'), bk: null, bl: null));
    if (hard({'t', 'lt'})) out.add((t: f('trans'), bk: null, bl: null));
    if (hard({'wo'})) out.add((t: f('order'), bk: null, bl: null));
    if (hard({'wh'})) out.add((t: f('hz'), bk: null, bl: null));
    final older = wrong.where((it) => it.d.l < L).length;
    if (older >= 2) out.add((t: f('older', [older, L]), bk: null, bl: null));
    if (run!.timeUp) {
      out.add((t: f('time'), bk: null, bl: null));
    } else if (m.used < m.m.sec * .35 && pct < .7) {
      out.add((t: f('fast'), bk: null, bl: null));
    }
    if (wrong.isNotEmpty) {
      out.add((t: f('wrong', [wrong.length]), bk: 'wrong', bl: f('wrongBtn', [wrong.length])));
    }
    return out;
  }

  /// the practice kind for a simulation question
  String practiceQ(String q) {
    final p = const {'ls': 'l', 'lj': 'l', 'lt': 't', 'wh': 'f', 'wo': 'c'}[q] ?? q;
    return p == 'l' && !ttsOK ? 'm' : p;
  }

  /// a practice round from the exam's mistakes (the quiz type goes back to Recognise)
  void mockPractice(List<Item> items) {
    if (items.isEmpty) return;
    pending = Pending('quiz', [for (final it in items) Item.q(it.d, practiceQ(it.q!))]);
    a.qType = 'm';
    a.saveUI();
    reset();
    a.changed();
  }

  // ---------------------------------------------------------------- practised today (the reminder stays quiet)
  int _studiedDay = -1;
  void studied() {
    final d = lm.today();
    if (d == _studiedDay) return;
    _studiedDay = d;
    Native.I.markStudied();
  }
}

/// a text function inside an i18n map
String l10f(Object? fn, [List<Object?> args = const []]) => L10.text(fn, args);
