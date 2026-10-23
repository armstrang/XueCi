/// The learning engine: memory model, storage, plan and question choice (checked by test/engine_trace_test.dart).
/// Everything runs on the phone; nothing is sent anywhere.
///
/// Memory model: FSRS-5 (fsrs.dart). Every word has one state for the word (drives scheduling and the 0–20 level)
/// plus one per skill: m = meaning, f = form (meaning → hanzi, sentence gap, typed pinyin), s = sound (tones,
/// listening). Level 0–20 = 20·ln(1+S)/ln(121); green also needs a passed form and sound answer.
///
/// Storage (Store, same keys as v1.x):
///   xc_mem   {id: {w:[d,s,t], m|f|s:[d,s,t,lastGrade,timesRight], i, L, p, k}}
///   xc_log   recent answers, xc_logA older answers: [t, id, type, grade, tenths, wrong pick|0, flags]
///   xc_goal  {t:'level'|'exam'|'none', lv, date:'YYYY-MM-DD', pace:'min'|'new'|'auto', n}
///   xc_lvl   realm, placement result, history, gate, stabilising trial
///   xc_tests xc_days xc_rest xc_game xc_amb xc_w xc_fit xc_mock, and mm_stats (the old per-word records)
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../data/pinyin.dart';
import '../data/store.dart';
import '../data/words.dart';
import 'fsrs.dart' as fsrs;
import 'js.dart';
import 'model.dart';

typedef Json = Map<String, dynamic>;

/// what one answer was: o in LM.answer(d, o)
class Ans {
  final String q;
  final bool ok;
  final num ms;
  final String? x;
  final bool claim, over, unchecked, hint, placement;
  bool exam;
  Ans(
    this.q,
    this.ok, {
    this.ms = 0,
    this.x,
    this.claim = false,
    this.over = false,
    this.unchecked = false,
    this.exam = false,
    this.placement = false,
    this.hint = false,
  });
}

class Stage {
  final int i;
  final double share;
  final int solid;
  final int test;
  final double testShare;
  final int total;
  final int need;
  final bool fin;
  const Stage({
    required this.i,
    required this.share,
    required this.solid,
    required this.test,
    required this.testShare,
    required this.total,
    required this.need,
    this.fin = false,
  });
  Json toJson() => {
    'i': i,
    'share': share,
    'solid': solid,
    'test': test,
    'testShare': testShare,
    'total': total,
    'need': need,
    if (fin) 'final': true,
  };
}

class Stab {
  final bool ok;
  final int? P;
  final int n;
  final double? acc;
  final int rn;
  final double? rec;
  final String? why;
  const Stab({required this.ok, this.P, this.n = 0, this.acc, this.rn = 0, this.rec, this.why});
  Json toJson() => P == null ? {'ok': ok} : {'ok': ok, 'P': P, 'n': n, 'acc': acc, 'rn': rn, 'rec': rec, 'why': why};
}

/// a typed pinyin answer checked: ok, or empty, or right as another word with the same meaning (alt)
class PyRes {
  final bool ok;
  final bool? empty;
  final bool? toneless;
  final Word? alt;
  const PyRes(this.ok, {this.empty, this.toneless, this.alt});
}

class Strike {
  final String k, hz, py, q;
  final int n;
  final bool tts, timed, band;
  const Strike(this.k, this.hz, this.py, this.q, this.n, {this.tts = false, this.timed = false, this.band = false});
}

/// a strike in a tribulation: how many questions, and after it the result
class StrikeRes {
  final String k, hz, py;
  final int n;
  final bool timed;
  final bool skipped;
  int right;
  bool pass;
  StrikeRes(this.k, this.hz, this.py, this.n, {this.timed = false, this.skipped = false, this.right = 0, this.pass = false});
  /// as the JS objects: {k, hz, py, n, timed} or {k, hz, py, n: 0, skipped: true}, plus right/pass after the end
  Json toJson({bool done = false}) => {
    'k': k,
    'hz': hz,
    'py': py,
    'n': n,
    if (skipped) 'skipped': true else 'timed': timed,
    if (done) 'right': right,
    if (done) 'pass': pass,
  };
}

class Trib {
  final int r, L;
  final bool makeup;
  final List<Item> items;
  final List<StrikeRes> strikes;
  int i = 0, right = 0;
  Trib(this.r, this.L, this.makeup, this.items, this.strikes);
}

class TribResult {
  final bool pass, gate, makeup;
  final double need, acc;
  final int right, n, grade, r;
  final List<StrikeRes> strikes;
  final List<Word> weak;
  TribResult({
    required this.pass,
    required this.need,
    required this.acc,
    required this.right,
    required this.n,
    required this.grade,
    required this.gate,
    required this.strikes,
    required this.r,
    required this.makeup,
    required this.weak,
  });
}

class PtState {
  List<double>? post;
  final List<Item> items = [];
  final Set<String> used = {};
  final Set<String> chars = {};
}

class PtResult {
  final int m, lv, right, idk, n;
  final double mean, sd;
  final List<int> per;
  PtResult(this.m, this.lv, this.mean, this.sd, this.per, this.right, this.idk, this.n);
  Json toJson() => {'m': m, 'lv': lv, 'mean': mean, 'sd': sd, 'per': per, 'right': right, 'idk': idk, 'n': n};
}

class Mock {
  final int L;
  final List<({String k, int n, int sec})> parts;
  final List<Item> items;
  final int sec;
  final bool skipped, short;
  Mock(this.L, this.parts, this.items, this.sec, this.skipped, this.short);
}

class MockPart {
  final String k;
  final int n, right, score;
  MockPart(this.k, this.n, this.right, this.score);
}

class MockScore {
  final List<MockPart> parts;
  final int total, max, need;
  final bool pass;
  MockScore(this.parts, this.total, this.max, this.need, this.pass);
}

/// the daily plan (LM.plan)
class Plan {
  String t = 'none';
  int due = 0, introT = 0, ansT = 0, minT = 0;
  ({double rev, double neu}) sp = (rev: 10, neu: 30);
  int? lv;
  String? date;
  int? remaining;
  int need = 0;
  int? days;
  int newPerDay = 0, revPerDay = 0, minutes = 0;
  int? needMin;
  int newToday = 0, revToday = 0;
  String status = 'free';
  DateTime? finish;
  DateTime? fixDate;
  bool rest = false;
  int todayLeft = 0;
  Json toJson() => {
    't': t,
    'due': due,
    'introT': introT,
    'ansT': ansT,
    'minT': minT,
    'sp': {'rev': sp.rev, 'neu': sp.neu},
    'lv': lv,
    'date': date,
    'remaining': remaining,
    'need': need,
    'days': days,
    'newPerDay': newPerDay,
    'revPerDay': revPerDay,
    'minutes': minutes,
    'needMin': needMin,
    'newToday': newToday,
    'revToday': revToday,
    'status': status,
    'finish': finish == null ? null : LM.isoDay(finish!),
    'fixDate': fixDate == null ? null : LM.isoDay(fixDate!),
    if (rest) 'rest': true,
    'todayLeft': todayLeft,
  };
}

class LM {
  final Store ls;
  final Vocab V;
  final JsRandom rnd;

  /// minutes since 1 Jan 2026 UTC (tests set a fixed clock)
  final int Function() _clock;

  /// JS getTimezoneOffset(): minutes, positive west of UTC
  final int tz;

  LM(this.ls, this.V, {JsRandom? random, int Function()? clock, int? tzOffset})
    : rnd = random ?? JsRandom.system(),
      _clock = clock ?? _sysClock,
      tz = tzOffset ?? -DateTime.now().timeZoneOffset.inMinutes {
    _init();
  }

  static int _sysClock() => jsRound((DateTime.now().millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

  int now() => _clock();
  int dayOf(num t) => fsrs.dayOfTz(t, tz);
  bool sameDay(num t, num t0) => fsrs.sameDayTz(t, t0, tz);
  double R() => rnd.next();

  List<Word> get data => V.data;
  Map<String, Word> get idx => V.idx;
  List<Word> by(int l) => V.by[l] ?? const [];
  List<int> get levels => V.levels;
  String m1(Word d) => V.m1(d);
  String tr(Word d) => V.trOf(d);

  static double r2(num x) => jsRound(x * 100) / 100;
  static double r3(num x) => jsRound(x * 1000) / 1000;

  // ---------------------------------------------------------------- word difficulty
  /// A word's difficulty inside its HSK level, from how common it is (Zipf frequency f) and whether it brings
  /// characters that are new at its level: −0.6 (easy) … +0.6 (hard).
  Map<String, double>? _wd;
  double wdiff(Word d) {
    if (_wd == null) {
      final wd = <String, double>{};
      final seen = <String>{};
      for (final l in levels) {
        final w = by(l);
        final nov = w.map((x) {
          final c = chars(x.h);
          return c.where((y) => !seen.contains(y)).length / c.length;
        }).toList();
        final fm = w.fold<double>(0, (a, x) => a + (x.f ?? 0)) / w.length;
        double fOr(Word x) => (x.f == null || x.f == 0) ? fm : x.f!;
        var fs = math.sqrt(w.fold<double>(0, (a, x) => a + (fOr(x) - fm) * (fOr(x) - fm)) / w.length);
        if (fs == 0 || fs.isNaN) fs = 1;
        final nm = nov.fold<double>(0, (a, b) => a + b) / w.length;
        for (var i = 0; i < w.length; i++) {
          final x = w[i];
          wd[x.id] = cl((-0.28 * (fOr(x) - fm)) / fs + 0.35 * (nov[i] - nm), -0.6, 0.6);
        }
        for (final x in w) {
          seen.addAll(chars(x.h));
        }
      }
      _wd = wd;
    }
    return _wd![d.id] ?? 0;
  }

  // ---------------------------------------------------------------- storage
  List<double> W = List.of(fsrs.w0);
  Json? wMeta;
  Map<String, Mem> mem = {};
  Json? goal;
  List<LogE> logR = [], logA = [];
  List<LogE>? _logCache;
  Map<String, int>? _confMap;
  Map<String, double>? _charS;
  Map<String, List<num>> stats = {};
  Timer? _saveT;

  List<double> step(List<double>? st, int g, num t, [double prior = 0, double dd = 0]) =>
      fsrs.step(W, st, g, t, tz, prior, dd);

  List<LogE> allLog() => _logCache ??= logA.isNotEmpty ? [...logA, ...logR] : List.of(logR);

  void _logPush(LogE e) {
    logR.add(e);
    if (logR.length >= 2000) {
      final all = [...logA, ...logR];
      logA = all.length > 28000 ? all.sublist(all.length - 28000) : all;
      ls.set('xc_logA', logA.map((x) => x.toJson()).toList());
      logR = [];
    }
    ls.set('xc_log', logR.map((x) => x.toJson()).toList());
    _logCache = null;
  }

  void flush() {
    _saveT?.cancel();
    _saveT = null;
    ls.set('xc_mem', mem.map((k, v) => MapEntry(k, v.toJson())));
  }

  void _saveMem() {
    _saveT?.cancel();
    _saveT = Timer(const Duration(milliseconds: 300), flush);
  }

  void saveStats() => ls.set('mm_stats', stats);

  /// when the app goes to the background
  void pause() {
    if (_saveT != null) flush();
  }

  static bool okS(List<double>? se) => se != null && se[3] > 1;
  static final double _ln121 = math.log(121);
  int levelOf(Mem? e) {
    if (e == null || e.w.isEmpty) return -1;
    var l = cl(jsRound((20 * math.log(1 + e.w[1])) / _ln121), 0, 20).toInt();
    if (l > 13 && e.L != 1 && !(okS(e.f) && okS(e.s))) l = 13;
    return l;
  }

  /// a solid word: level 10+ (remembered for about a week) and a passed recall and tone question
  bool solid(Mem? e) => e != null && levelOf(e) >= 10 && okS(e.f) && okS(e.s);
  int skLevel(List<double>? se) => se == null ? -1 : cl(jsRound((20 * math.log(1 + se[1])) / _ln121), 0, 20).toInt();

  static bool _isState(Object? a) {
    if (a is! List || a.length < 3) return false;
    if (!a.take(3).every(isFin)) return false;
    final d = (a[0] as num), s = (a[1] as num);
    return d >= 1 && d <= 10 && s > 0;
  }

  static Mem? cleanEntry(Object? e) {
    if (e is! Map || !_isState(e['w'])) return null;
    final w = e['w'] as List;
    final i = e['i'];
    final o = Mem(
      w: [r2(w[0] as num), r3(w[1] as num), jsRound(w[2] as num).toDouble()],
      i: isFin(i) ? jsRound(i as num) : 0,
    );
    for (final k in const ['m', 'f', 's']) {
      final s = e[k];
      if (_isState(s)) {
        final a = s as List;
        o.setSk(k, [
          r2(a[0] as num),
          r3(a[1] as num),
          jsRound(a[2] as num).toDouble(),
          cli(i32(a.length > 3 ? a[3] : null), 1, 4).toDouble(),
          math.max(0, i32(a.length > 4 ? a[4] : null)).toDouble(),
        ]);
      }
    }
    if (e['L'] == 1 || e['L'] == 2) o.L = (e['L'] as num).toInt();
    if (e['p'] == 1) o.p = 1;
    if (isFin(e['k'])) o.k = jsRound(e['k'] as num);
    return o;
  }

  /// Keep the old per-word records (mm_stats) and the memory states in step: old progress becomes a state with
  /// the same level ("needs confirming"); every level is recalculated from the state.
  void sync() {
    final t = now();
    stats.forEach((id, e) {
      if (!idx.containsKey(id) || e[0] + e[1] <= 0 || mem.containsKey(id)) return;
      final l = cl(i32(e[2]), 0, 20);
      final s = math.max(0.1, math.pow(121, l / 20) - 1);
      final d = cl(4 + (6 * e[1]) / math.max(1, e[0] + e[1]), 1, 10);
      mem[id] = Mem(w: [r2(d), r3(s), t.toDouble()], i: 0, L: 1);
    });
    mem.forEach((id, m) {
      final st = stats[id] ??= [0, 0, 0];
      st[2] = math.max(0, levelOf(m));
    });
    _charS = null;
    flush();
    saveStats();
  }

  void _loadStats() {
    final s = ls.get('mm_stats', null);
    stats = {};
    if (s is Map) {
      s.forEach((k, e) {
        if (e is! List) return;
        final l = <num>[for (final x in e) x is num ? x : i32(x)];
        while (l.length < 2) {
          l.add(0);
        }
        if (l.length < 3) l.add(cl(i32(l[0]) - i32(l[1]), 0, 20).toInt());
        stats['$k'] = l;
      });
    }
  }

  // ---------------------------------------------------------------- answering
  static const sk = {'cm': 'm', 'cs': 's', 'cn': 'm', 'm': 'm', 'f': 'f', 's': 's', 'l': 's', 'c': 'f', 'p': 'f', 't': 'm'};
  static const defMs = {
    'cm': 4500,
    'cs': 4500,
    'cu': 4500,
    'cn': 4500,
    'm': 5000,
    'f': 6000,
    's': 6000,
    'l': 7000,
    'c': 9000,
    'p': 15000,
    't': 12000,
  };
  static const quiz = {'m', 'f', 's', 'l', 'c', 'p', 't'};
  ({String id, Mem? mem, List<num>? st, int n})? _last;

  double medMs(String q) {
    final l = allLog();
    final a = <double>[];
    for (var i = l.length - 1; i >= 0 && a.length < 40 && i > l.length - 800; i--) {
      final e = l[i];
      if (e.q == q && e.g > 1) a.add(e.ms * 100.0);
    }
    if (a.length < 8) return (defMs[q] ?? 6000).toDouble();
    jsSort(a, byNum);
    return a[a.length >> 1];
  }

  int _grade(Ans o, Mem e) {
    final med = medMs(o.q);
    var g = o.ms <= med * 1.8 && !o.hint ? 3 : 2;
    if (g == 3 && o.ms < med * 0.6 && e.w.isNotEmpty && e.w[1] >= 3 && !const {'m', 'cm', 'cu'}.contains(o.q)) g = 4;
    return g;
  }

  double knownShare(Word d) {
    if (_charS == null) {
      final cs = <String, double>{};
      mem.forEach((id, e) {
        final x = idx[id];
        if (x == null) return;
        final s = e.w[1];
        for (final c in chars(x.h)) {
          if ((cs[c] ?? 0) < s) cs[c] = s;
        }
      });
      _charS = cs;
    }
    final cs = chars(d.h).toSet().toList();
    return cs.where((c) => (_charS![c] ?? 0) >= 2).length / cs.length;
  }

  ({int g, int before, int after}) answer(Word d, Ans o) {
    final t = now(), id = d.id, had = mem[id];
    if (o.placement) o.exam = true;
    final flags =
        (o.unchecked ? 1 : 0) |
        (o.claim ? 2 : 0) |
        (o.over ? 4 : 0) |
        (o.exam ? 8 : 0) |
        (o.placement ? 16 : 0) |
        (o.hint ? 32 : 0);
    final ms = math.min(9999, jsRound(o.ms / 100));
    if (o.exam && had == null && !o.ok) {
      _logPush(LogE(t, id, o.q, 1, ms, o.x, flags));
      if (o.x != null) _addConf(id, o.x!);
      return (g: 1, before: -1, after: -1);
    }
    _last = (id: id, mem: had?.clone(), st: stats[id] == null ? null : List.of(stats[id]!), n: logR.length);
    final e = had ?? Mem(i: t);
    final before = levelOf(had);
    final g = o.ok ? _grade(o, e) : 1;
    if (had == null && o.exam) e.p = 1;
    e.w = step(e.w.isEmpty ? null : e.w, g, t, had != null ? 0 : knownShare(d), had != null ? 0 : wdiff(d));
    if (o.over) e.w[0] = math.min(10, e.w[0] + 1);
    e.w = [r2(e.w[0]), r3(e.w[1]), t.toDouble()];
    final k = o.unchecked || o.hint ? null : sk[o.q];
    if (k != null) {
      final se = e.sk(k);
      final ns = step(se?.sublist(0, 3), g, t, 0);
      e.setSk(k, [r2(ns[0]), r3(ns[1]), t.toDouble(), g.toDouble(), (se != null ? se[4] : 0) + (g > 1 ? 1 : 0)]);
    }
    if (e.L == 1 && e.f != null && e.s != null) e.L = 2;
    if ((e.k ?? 0) == 0 && solid(e)) e.k = t;
    mem[id] = e;
    final st = stats[id] ?? <num>[0, 0, 0];
    if (o.ok) {
      st[0] = st[0] + 1;
    } else {
      st[1] = st[1] + 1;
    }
    st[2] = levelOf(e);
    stats[id] = st;
    _logPush(LogE(t, id, o.q, g, ms, o.x, flags));
    if (o.x != null) _addConf(id, o.x!);
    if (had == null) _charS = null;
    _saveMem();
    saveStats();
    return (g: g, before: before, after: st[2].toInt());
  }

  /// "Turns out I was wrong" right after an unchecked claim: take that answer back
  bool undo() {
    final l = _last;
    if (l == null) return false;
    _last = null;
    if (l.mem != null) {
      mem[l.id] = l.mem!;
    } else {
      mem.remove(l.id);
    }
    if (l.st != null) {
      stats[l.id] = l.st!;
    } else {
      stats.remove(l.id);
    }
    if (logR.length > l.n) {
      logR = logR.sublist(0, l.n);
      ls.set('xc_log', logR.map((x) => x.toJson()).toList());
      _logCache = null;
    }
    _charS = null;
    _confMap = null;
    _saveMem();
    saveStats();
    return true;
  }

  // ---------------------------------------------------------------- confusions
  Set<String> amb = {};
  void markAmbiguous(String a, String b) {
    amb.add(pairKey(a, b));
    final l = amb.toList();
    ls.set('xc_amb', l.length > 500 ? l.sublist(l.length - 500) : l);
  }

  static String pairKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  Map<String, int> confs() {
    if (_confMap == null) {
      final m = <String, int>{};
      for (final e in allLog()) {
        if (e.x != null && idx.containsKey(e.x)) {
          final k = pairKey(e.id, e.x!);
          m[k] = (m[k] ?? 0) + 1;
        }
      }
      _confMap = m;
    }
    return _confMap!;
  }

  void _addConf(String a, String b) {
    if (_confMap == null || !idx.containsKey(b)) return;
    final k = pairKey(a, b);
    _confMap![k] = (_confMap![k] ?? 0) + 1;
  }

  List<String> partners(String id) {
    final out = <(String, int)>[];
    confs().forEach((k, n) {
      final p = k.split('|');
      if (p[0] == id) {
        out.add((p[1], n));
      } else if (p[1] == id) {
        out.add((p[0], n));
      }
    });
    jsSort(out, (x, y) => y.$2 - x.$2);
    return out.map((x) => x.$1).toList();
  }

  // ---------------------------------------------------------------- calibration
  ({int n, double acc}) calib() {
    final l = allLog();
    var n = 0, c = 0;
    for (var i = l.length - 1; i >= 0 && n < 40; i--) {
      final e = l[i];
      if (e.q == 'cm' || e.q == 'cs') {
        n++;
        if (e.g > 1) c++;
      }
    }
    return (n: n, acc: n > 0 ? c / n : 0.0);
  }

  double checkP(Word d) {
    final e = mem[d.id];
    if (e == null || e.L == 1 || !(e.m != null || e.s != null)) return 1;
    final c = calib();
    if (c.n < 8) return 1;
    return cl((1 - c.acc) * 4 + 0.25, 0.25, 1);
  }

  String checkType(Word d, [bool heard = false]) {
    final e = mem[d.id], t = now();
    if (heard || e == null || !okS(e.m)) return 'cm';
    double r(List<double>? se) => se != null ? fsrs.rt((t - se[2]) / 1440, se[1]) : 0;
    return r(e.s) < r(e.m) ? 'cs' : 'cm';
  }

  // ---------------------------------------------------------------- question material
  ({Map<String, List<Word>> byChar, Map<String, List<Word>> byPk})? _ix;
  ({Map<String, List<Word>> byChar, Map<String, List<Word>> byPk}) ix() {
    if (_ix != null) return _ix!;
    final byChar = <String, List<Word>>{}, byPk = <String, List<Word>>{};
    for (final d in data) {
      for (final c in chars(d.h).toSet()) {
        (byChar[c] ??= []).add(d);
      }
      (byPk[d.pk] ??= []).add(d);
    }
    return _ix = (byChar: byChar, byPk: byPk);
  }

  static String fullPy(Word d) => d.p.toLowerCase().replaceAll(RegExp(r"['\s]"), '');

  List<Word> similar(Word d) {
    final x = ix();
    final out = <Word>[];
    final seen = <String>{d.id};
    void add(Word? w) {
      if (w != null && !seen.contains(w.id)) {
        seen.add(w.id);
        out.add(w);
      }
    }

    for (final id in partners(d.id)) {
      add(idx[id]);
    }
    for (final w in x.byPk[d.pk] ?? const <Word>[]) {
      add(w);
    }
    final sh = <Word>[];
    for (final c in chars(d.h).toSet()) {
      for (final w in x.byChar[c] ?? const <Word>[]) {
        if (!seen.contains(w.id)) sh.add(w);
      }
    }
    final n = charLen(d.h);
    final scored = <(double, Word)>[];
    for (final w in sh.toSet()) {
      scored.add(((charLen(w.h) - n).abs() * 2 + (w.l - d.l).abs() + R(), w));
    }
    jsSort(scored, (a, b) => a.$1 - b.$1);
    for (final p in scored) {
      add(p.$2);
    }
    return out;
  }

  ({int n, double acc}) recentAcc() {
    final l = allLog();
    var n = 0, c = 0;
    for (var i = l.length - 1; i >= 0 && n < 30; i--) {
      final e = l[i];
      if (quiz.contains(e.q) && e.f & 8 == 0) {
        n++;
        if (e.g > 1) c++;
      }
    }
    return (n: n, acc: n > 0 ? c / n : 0.0);
  }

  /// how often a wrong option is a look-alike: more for words you know better, adjusted to keep you near 80–85 %
  double hardness(Word d) {
    final l = levelOf(mem[d.id]);
    var h = l < 0 ? 0.15 : (l < 7 ? 0.3 : (l < 14 ? 0.6 : 0.85));
    final a = recentAcc();
    if (a.n >= 10) {
      if (a.acc > 0.88) {
        h += 0.15;
      } else if (a.acc < 0.72) {
        h -= 0.25;
      }
    }
    return cl(h, 0, 1);
  }

  List<T> shuf<T>(List<T> a0) {
    final a = List<T>.of(a0);
    for (var i = a.length - 1; i > 0; i--) {
      final j = (R() * (i + 1)).floor();
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
    }
    return a;
  }

  /// four options: the word plus three others (never the same meaning, never the same sound in listening)
  List<Word> wordOpts(Word d, String type, double? hard) {
    final used = <String>{type == 'm' ? m1(d).toLowerCase() : d.h};
    final fp = fullPy(d);
    final picks = <Word>[];
    final dm = m1(d).toLowerCase();
    bool okX(Word x) {
      if (x.id == d.id) return false;
      if (type == 'm') {
        final m = m1(x).toLowerCase();
        return m.isNotEmpty && !used.contains(m);
      }
      if (used.contains(x.h)) return false;
      if (type == 'l' && fullPy(x) == fp) return false;
      final xm = m1(x).toLowerCase();
      if (xm == dm || (xm.length > 2 && dm.length > 2 && (xm.contains(dm) || dm.contains(xm)))) return false;
      return true;
    }

    void take(Word x) {
      picks.add(x);
      used.add(type == 'm' ? m1(x).toLowerCase() : x.h);
    }

    final h = type == 'c' ? 0.0 : (hard ?? hardness(d));
    final sim = type == 'c' ? <Word>[] : similar(d);
    final n = charLen(d.h);
    final near = by(d.l).where((x) => (x.u - d.u).abs() <= 3).toList();
    double sameClass(Word x) =>
        type == 'c' && d.g != null && d.g!.isNotEmpty && x.g != null && x.g!.isNotEmpty && x.g![0] == d.g![0]
        ? 0
        : (type == 'c' ? 1.2 : 0);
    final sh = shuf(near.length >= 12 ? near : by(d.l)).where((x) => !amb.contains(pairKey(d.id, x.id))).toList();
    final sc = <(double, Word)>[];
    for (final x in sh) {
      sc.add(((type == 'm' ? 0 : (charLen(x.h) - n).abs()) + sameClass(x) + R() * 1.5, x));
    }
    jsSort(sc, (a, b) => a.$1 - b.$1);
    final rndL = sc.map((p) => p.$2).toList();
    var si = 0, ri = 0;
    while (picks.length < 3 && (si < sim.length || ri < rndL.length)) {
      Word? x;
      if (R() < h) {
        while (si < sim.length && x == null) {
          final c = sim[si++];
          if (okX(c)) x = c;
        }
      }
      while (x == null && ri < rndL.length) {
        final c = rndL[ri++];
        if (okX(c)) x = c;
      }
      while (x == null && si < sim.length) {
        final c = sim[si++];
        if (okX(c)) x = c;
      }
      if (x != null) {
        take(x);
      } else {
        break;
      }
    }
    return shuf([d, ...picks]);
  }

  static const _near = {
    1: [4, 2, 3],
    2: [3, 1, 4],
    3: [2, 4, 1],
    4: [1, 3, 2],
    5: [4, 1, 3],
  };

  /// tone options: the word's pinyin plus three versions with other tones (一/不 and neutral syllables keep theirs,
  /// unless nothing else can change)
  QMat toneOpts(Word d) {
    final syl = d.s;
    final ch = chars(d.h);
    String key(List<String> a) => a.join(' ');
    final seen = <String>{key(syl)};
    final out = <List<String>>[];
    bool can(int i) => markTone(bareSyl(syl[i]), 1) != bareSyl(syl[i]);
    var ix = [
      for (var i = 0; i < syl.length; i++)
        if (can(i) && tone(syl[i]) != 5 && !(syl.length == ch.length && (ch[i] == '一' || ch[i] == '不'))) i,
    ];
    if (ix.isEmpty) ix = [for (var i = 0; i < syl.length; i++) if (can(i)) i];
    List<String> vary(List<String> a, int i, int t) {
      final b = List<String>.of(a);
      b[i] = markTone(bareSyl(a[i]), t);
      return b;
    }

    final near = <List<String>>[], far = <List<String>>[];
    for (final i in ix) {
      final nn = _near[tone(syl[i])]!;
      near.add(vary(syl, i, nn[0]));
      near.add(vary(syl, i, nn[1]));
      far.add(vary(syl, i, nn[2]));
    }
    for (var k = 0; k < 16 && ix.length > 1; k++) {
      final i = ix[(R() * ix.length).floor()];
      final j = ix[(R() * ix.length).floor()];
      if (i == j) continue;
      final inner = vary(syl, i, _near[tone(syl[i])]![(R() * 2).floor()]);
      far.add(vary(inner, j, _near[tone(syl[j])]![(R() * 2).floor()]));
    }
    final a = shuf(near);
    final b = shuf(far);
    for (final v in [...a, ...b]) {
      if (out.length == 3) break;
      final k = key(v);
      if (!seen.contains(k)) {
        seen.add(k);
        out.add(v);
      }
    }
    final opts = shuf(<List<String>>[syl, ...out]);
    return QMat(tones: opts, ans: opts.indexWhere((x) => identical(x, syl)));
  }

  static bool clozeOK(Word d) => d.z.isNotEmpty && d.z.contains(d.h);
  bool Function() ttsReady = () => false;

  /// the translation of an example sentence: the right one and three of other words' sentences, preferring look-
  /// or sound-alikes, then sentences of about the same length
  QMat transOpts(Word d, double? hard) {
    String trx(Word x) => tr(x).trim();
    final own = trx(d);
    final used = <String>{own};
    final picks = <Word>[];
    final len = own.isEmpty ? 1 : own.length;
    final sim = R() < (hard ?? 0.6) ? similar(d) : <Word>[];
    final nearS = <(double, Word)>[];
    for (final x in by(d.l).where((x) => (x.u - d.u).abs() <= 4)) {
      nearS.add(((trx(x).length - len).abs() / len + R() * 0.25, x));
    }
    jsSort(nearS, (a, b) => a.$1 - b.$1);
    final near = nearS.map((p) => p.$2).toList();
    final all = [...sim, ...near, ...shuf(by(d.l))];
    for (final x in all) {
      if (picks.length == 3) break;
      final t = trx(x);
      if (x.id == d.id || t.isEmpty || used.contains(t) || !clozeOK(x)) continue;
      used.add(t);
      picks.add(x);
    }
    final opts = shuf([d, ...picks]);
    return QMat(words: opts, ans: opts.indexOf(d));
  }

  /// material for one question: ans is the index of the right option; a typed question has no options
  QMat question(Word d, String q, [double? hard]) {
    if (q == 's' || q == 'cs') return toneOpts(d);
    if (q == 'p') return const QMat(typed: true);
    if (q == 't') return transOpts(d, hard);
    final opts = wordOpts(d, q == 'cm' ? 'm' : q, hard);
    return QMat(words: opts, ans: opts.indexOf(d));
  }

  // ---------------------------------------------------------------- typed pinyin
  static const Map<String, (String, int)> _toned = {
    'ā': ('a', 1), 'á': ('a', 2), 'ǎ': ('a', 3), 'à': ('a', 4),
    'ē': ('e', 1), 'é': ('e', 2), 'ě': ('e', 3), 'è': ('e', 4),
    'ī': ('i', 1), 'í': ('i', 2), 'ǐ': ('i', 3), 'ì': ('i', 4),
    'ō': ('o', 1), 'ó': ('o', 2), 'ǒ': ('o', 3), 'ò': ('o', 4),
    'ū': ('u', 1), 'ú': ('u', 2), 'ǔ': ('u', 3), 'ù': ('u', 4),
    'ǖ': ('v', 1), 'ǘ': ('v', 2), 'ǚ': ('v', 3), 'ǜ': ('v', 4),
    'ü': ('v', 0),
  };

  /// typed text → letters + tones by letter position (null when it has other characters)
  static ({String letters, Map<int, int> tones})? pyParse(String? text) {
    final s = composePinyin(text ?? '').toLowerCase().replaceAll('u:', 'v').replaceAll(RegExp(r"[\s'’\-·]"), '');
    final letters = StringBuffer();
    var n = 0;
    final tones = <int, int>{};
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final t = _toned[ch];
      if (t != null) {
        letters.write(t.$1);
        n++;
        if (t.$2 != 0) tones[n - 1] = t.$2;
      } else if (r >= 0x30 && r <= 0x35) {
        if (n > 0) {
          final v = r - 0x30;
          tones[n - 1] = v == 0 ? 5 : v;
        }
      } else if (r >= 0x61 && r <= 0x7A) {
        letters.write(ch);
        n++;
      } else {
        return null;
      }
    }
    return (letters: letters.toString(), tones: tones);
  }

  PyRes pyCheck(Word d, String text) {
    final inp = pyParse(text);
    if (inp == null || inp.letters.isEmpty) return const PyRes(false, empty: true);
    final syl = d.s.map(pyParse).toList();
    final want = syl.map((x) => x?.letters ?? '').join();
    if (inp.letters != want) {
      Word? alt;
      for (final x in similarMeaning(d)) {
        if (pyParse(x.s.join())?.letters == inp.letters && pyCheck(x, text).ok) {
          alt = x;
          break;
        }
      }
      return alt != null ? PyRes(true, alt: alt) : const PyRes(false);
    }
    final ch = chars(d.h);
    var pos = 0;
    var toneless = true, ok = true;
    for (var i = 0; i < syl.length; i++) {
      final x = syl[i]!;
      final end = pos + x.letters.length;
      var given = 0;
      for (var k = pos; k < end; k++) {
        final v = inp.tones[k];
        if (v != null && v != 0) given = v;
      }
      if (given != 0) toneless = false;
      final t = tone(d.s[i]), g = given != 0 ? given : 5;
      final c = syl.length == ch.length ? ch[i] : '';
      final fine = g == t || t == 5 || (c == '一' && const [1, 2, 4].contains(g)) || (c == '不' && const [2, 4].contains(g));
      if (!fine) ok = false;
      pos = end;
    }
    return PyRes(ok, toneless: toneless && !ok);
  }

  List<Word> similarMeaning(Word d) {
    final m = m1(d).toLowerCase();
    return data.where((x) => x.id != d.id && m1(x).toLowerCase() == m).toList();
  }

  // ---------------------------------------------------------------- what to ask next
  static bool _has(Mem? e, String k) => e != null && e.sk(k) != null && e.sk(k)![4] > 0;
  Map<String, double> skillW = {'m': 0, 'f': 0, 's': 0};

  String pickType(Word d) {
    final e = mem[d.id], t = now();
    if (e == null) return 'm';
    if (e.L == 1) {
      if (e.f == null) return 'f';
      if (e.s == null) return 's';
    }
    double r(List<double>? se) => se != null ? fsrs.rt((t - se[2]) / 1440, se[1]) : 0;
    final c = <(String, double)>[('m', r(e.m))];
    if (_has(e, 'm') || e.L != null) {
      c.add(('f', r(e.f)));
      c.add(('s', r(e.s)));
    }
    final sc = <(String, double)>[for (final p in c) (p.$1, p.$2 - skillW[p.$1]! + R() * 0.12)];
    jsSort(sc, (a, b) => a.$2 - b.$2);
    final k = sc[0].$1;
    final x = R();
    if (k == 'f' && _has(e, 'f') && x < 0.2) return 'p';
    if (k == 'm' && _has(e, 'm') && d.l >= 3 && clozeOK(d) && x < 0.2) return 't';
    if (k == 'f' && _has(e, 'f') && clozeOK(d) && x < 0.5) return 'c';
    if (k == 's' && _has(e, 's') && ttsReady() && R() < 0.4) return 'l';
    return k;
  }

  double dr([Json? g, bool useGoal = true]) {
    g = useGoal ? (g ?? goal) : g;
    if (g != null && g['t'] == 'exam' && g['date'] is String && (g['date'] as String).isNotEmpty) {
      final dl = daysTo(g['date']);
      if (dl >= 0 && dl <= 30) return 0.9 + 0.05 * (1 - dl / 30);
    }
    return 0.9;
  }

  double rNowE(Mem? e, int t) => e != null && e.w.isNotEmpty ? fsrs.rt((t - e.w[2]) / 1440, e.w[1]) : 0;

  /// words in curriculum order that haven't been seen yet; familiar-looking ones a little earlier, and two
  /// look-alikes never introduced together
  List<Word> pickNew(int n, List<Word> src) {
    if (n <= 0) return [];
    final cand = <Word>[];
    for (final d in src) {
      if (!mem.containsKey(d.id)) cand.add(d);
      if (cand.length >= 60) break;
    }
    final scs = <(double, Word)>[];
    for (var i = 0; i < cand.length; i++) {
      final d = cand[i];
      scs.add((i - 14 * knownShare(d) + 12 * wdiff(d), d));
    }
    jsSort(scs, (a, b) => a.$1 - b.$1);
    final sc = scs.map((p) => p.$2).toList();
    final out = <Word>[];
    final ch = <String>{}, pks = <String>{};
    for (final d in sc) {
      if (out.length >= n) break;
      final cs = chars(d.h);
      if (cs.any(ch.contains) || pks.contains(d.pk)) continue;
      out.add(d);
      ch.addAll(cs);
      pks.add(d.pk);
    }
    for (final d in sc) {
      if (out.length >= n) break;
      if (!out.contains(d)) out.add(d);
    }
    return out;
  }

  static List<Word> tsort(Iterable<Word> a) => sorted(a, (x, y) => x.l != y.l ? x.l - y.l : x.n - y.n);

  /// Cards: due words first (lowest recall chance), then up to half a round of new ones, then the rest by weakness
  List<Word> cardDeck(List<Word> pool, int n) {
    final t = now(), r = dr();
    final due = <(double, Word)>[], rest = <(double, Word)>[];
    for (final d in pool) {
      final e = mem[d.id];
      if (e == null) continue;
      final rr = rNowE(e, t);
      if (rr < r) {
        due.add((rr, d));
      } else {
        rest.add((rr, d));
      }
    }
    jsSort(due, (a, b) => a.$1 - b.$1);
    jsSort(rest, (a, b) => a.$1 - b.$1);
    final out = due.take(n).map((p) => p.$2).toList();
    if (out.length < n) out.addAll(pickNew(math.min(n - out.length, math.max(4, jsRound(n / 2))), tsort(pool)));
    for (final p in rest) {
      if (out.length >= n) break;
      out.add(p.$2);
    }
    return spread(out.take(n).toList());
  }

  bool alike(Word? a, Word? b) =>
      a != null &&
      b != null &&
      (chars(a.h).any((c) => b.h.contains(c)) || a.pk == b.pk || confs().containsKey(pairKey(a.id, b.id)));

  /// random order, and two look-alikes never one after the other
  List<Word> spread(List<Word> words) {
    final a = shuf(words);
    for (var i = 1; i < a.length; i++) {
      if (alike(a[i], a[i - 1])) {
        final nx = i + 1 < a.length ? a[i + 1] : null;
        var j = -1;
        for (var k = 0; k < a.length; k++) {
          if (k > i && !alike(a[k], a[i - 1]) && !alike(a[k], nx)) {
            j = k;
            break;
          }
        }
        if (j > 0) {
          final t = a[i];
          a[i] = a[j];
          a[j] = t;
        }
      }
    }
    return a;
  }

  /// Quiz round inside the chosen level/unit; type null = the app chooses per word
  List<Item> quizRound(List<Word> pool, int n, String? type) {
    final t = now(), r = dr();
    final sc = <(double, Word)>[];
    final src = type == 'c' || type == 't' ? pool.where(clozeOK).toList() : pool;
    for (final d in src) {
      final e = mem[d.id];
      if (e == null) continue;
      final rr = rNowE(e, t);
      sc.add((rr < r ? rr : (e.L == 1 ? 0.95 : 1 + rr), d));
    }
    jsSort(sc, (a, b) => a.$1 - b.$1);
    var words = sc.take(n).map((p) => p.$2).toList();
    final fresh = pickNew(math.max(type != null ? 0 : 3, n - words.length), tsort(src));
    if (type == null && words.length > n - 3 && fresh.isNotEmpty) {
      words = words.take(math.max(0, n - math.min(3, fresh.length))).toList();
    }
    words = [...words, ...fresh].take(n).toList();
    return [for (final d in shuf(words)) Item.q(d, type ?? pickType(d))];
  }

  /// a word the learner is sure of (the highest recall now, at least 0.9), for a quick win after misses
  Word? easyWord(Iterable<Word> pool, Set<String> skip) {
    final t = now();
    Word? best;
    var br = 0.9;
    for (final d in pool) {
      final e = mem[d.id];
      if (e == null || skip.contains(d.id) || levelOf(e) < 7) continue;
      final r = rNowE(e, t);
      if (r >= br) {
        br = r;
        best = d;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------- HSK simulation (the HSK 3.0 paper)
  /// the real paper per level: questions in listening, reading, writing and the minutes for each. HSK 5–6 write
  /// two short essays; here that section builds sentences instead
  static const mockPaper = {
    1: (n: [20, 20, 0], min: [15, 17, 0]),
    2: (n: [25, 25, 10], min: [17, 25, 10]),
    3: (n: [30, 30, 10], min: [25, 33, 20]),
    4: (n: [32, 32, 6], min: [25, 35, 20]),
    5: (n: [35, 35, 6], min: [30, 45, 25]),
    6: (n: [40, 40, 6], min: [35, 50, 30]),
  };
  static const mockSections = ['listen', 'read', 'write'];

  /// the kinds of question in a section, with weights: l a word heard, ls which word was in the sentence heard,
  /// lj is this what you heard (true/false), lt what the sentence heard means; m c t reading; wo sentence
  /// building, wh the character for the pinyin in a sentence
  static Map<String, int> mockMix(String part, int l) => switch (part) {
    'listen' => l == 1
        ? const {'l': 8, 'lj': 6, 'ls': 6}
        : l == 2
        ? const {'l': 5, 'lj': 10, 'ls': 10}
        : l <= 4
        ? const {'lj': 3, 'ls': 3, 'lt': 4}
        : const {'lj': 1, 'ls': 1, 'lt': 2},
    'read' => l == 1
        ? const {'m': 1, 'c': 1}
        : l == 2
        ? const {'m': 1, 'c': 2, 't': 1}
        : l <= 4
        ? const {'c': 1, 't': 1}
        : const {'c': 2, 't': 3},
    _ => l <= 3 ? const {'wo': 1, 'wh': 1} : const {'wo': 1},
  };

  /// n split by weights (largest remainders first, ties in the given order)
  static Map<String, int> split(int n, Map<String, int> w) {
    final tot = w.values.fold<int>(0, (a, b) => a + b);
    final out = {for (final e in w.entries) e.key: n * e.value ~/ tot};
    var left = n - out.values.fold<int>(0, (a, b) => a + b);
    final rem = w.keys.toList()..sort((a, b) => (n * w[b]! % tot) - (n * w[a]! % tot));
    for (var i = 0; left > 0; i++, left--) {
      out[rem[i % rem.length]] = out[rem[i % rem.length]]! + 1;
    }
    return out;
  }

  /// the answer as the log keeps it: listening kinds count as listening, writing kinds as form
  static String logQ(String q) => const {'ls': 'l', 'lt': 'l', 'lj': 'l', 'wh': 'f', 'wo': 'c', 'u': 's'}[q] ?? q;

  Set<String>? _syl;

  /// syllables in a word of pinyin (null when it doesn't read as pinyin)
  int? sylCount(String w) {
    final syl = _syl ??= {
      for (final d in data)
        for (final x in d.s) plain(x).replaceAll(RegExp('[^a-z]'), ''),
    }..remove('');
    final t = plain(w).replaceAll(RegExp('[^a-z]'), '');
    if (t.isEmpty) return 0;
    final best = List<int?>.filled(t.length + 1, null)..[0] = 0;
    for (var i = 0; i < t.length; i++) {
      if (best[i] == null) continue;
      for (var j = i + 1; j <= math.min(t.length, i + 6); j++) {
        if (syl.contains(t.substring(i, j)) && (best[j] == null || best[j]! > best[i]! + 1)) best[j] = best[i]! + 1;
      }
    }
    return best[t.length];
  }

  static final _hz = RegExp(r'[一-鿿]');
  static const _after = {'的', '了', '着', '过', '吗', '呢', '吧', '啊', '们', '得', '地'};
  static const _before = {'这', '那', '一', '两', '几', '每', '很', '最', '不', '没', '也', '都', '还', '就', '太', '真', '更', '在', '把', '被', '给', '跟', '和', '对', '从'};

  /// the example sentence cut into words by its pinyin, then into a few pieces for sentence building (null when
  /// the sentence has a comma inside, doesn't line up with its pinyin, or gives fewer than three pieces)
  List<String>? pieces(Word d, int max) {
    final zp = d.zp;
    var z = d.z.trim();
    if (zp == null || zp.isEmpty || !clozeOK(d)) return null;
    final end = RegExp(r'[。！？!?.]+$').firstMatch(z);
    if (end != null) z = z.substring(0, end.start);
    if (z.isEmpty || RegExp(r'[，、：；“”‘’（）,;:"\s0-9a-zA-Z]').hasMatch(z)) return null;
    final cs = chars(z);
    final words = <String>[];
    var i = 0;
    for (final tk in zp.replaceAll(RegExp('[{}]'), '').split(RegExp(r'\s+'))) {
      final n = sylCount(tk);
      if (n == null || n == 0) continue;
      final b = StringBuffer();
      var k = 0;
      while (i < cs.length && k < n) {
        if (_hz.hasMatch(cs[i])) k++;
        b.write(cs[i++]);
      }
      if (k != n) return null;
      words.add(b.toString());
    }
    if (i != cs.length || words.length < 3) return null;
    // little words lean on a neighbour, then the shortest neighbours join until there are few enough pieces
    final out = <String>[];
    var glue = false;
    for (final w in words) {
      if (out.isNotEmpty && (glue || _after.contains(w))) {
        out[out.length - 1] += w;
      } else {
        out.add(w);
      }
      glue = _before.contains(w) && w != d.h;
    }
    while (out.length > max) {
      var j = 0;
      for (var k = 1; k < out.length - 1; k++) {
        if (out[k].length + out[k + 1].length < out[j].length + out[j + 1].length) j = k;
      }
      out[j] += out.removeAt(j + 1);
    }
    return out.length >= 3 && out.toSet().length == out.length ? out : null;
  }

  static int piecesMax(int l) => l <= 3 ? 4 : (l == 4 ? 5 : 6);

  /// a word to swap into the sentence for "is this what you heard": same kind and length, another meaning
  Word? swapFor(Word d) {
    final n = charLen(d.h), dm = m1(d).toLowerCase();
    final c = by(d.l)
        .where((x) => x.id != d.id && charLen(x.h) == n && x.g == d.g && !d.z.contains(x.h) && m1(x).toLowerCase() != dm && x.pk != d.pk)
        .toList();
    return c.isEmpty ? null : c[(R() * c.length).floor()];
  }

  /// words that sound like it (same pinyin without tones, same length), for writing the character from pinyin
  List<Word> soundAlikes(Word d) {
    final by = _byPk ??= () {
      final m = <String, List<Word>>{};
      for (final x in data) {
        (m[x.pk] ??= []).add(x);
      }
      return m;
    }();
    return (by[d.pk] ?? const <Word>[]).where((x) => x.id != d.id && x.h != d.h && charLen(x.h) == charLen(d.h)).toList();
  }

  Map<String, List<Word>>? _byPk;

  QMat mockQ(Word d, String q) {
    switch (q) {
      case 'ls':
        final o = wordOpts(d, 'l', 0.8);
        return QMat(words: o, ans: o.indexOf(d));
      case 'lt':
        return transOpts(d, 0.8);
      case 'lj':
        final x = R() < 0.5 ? swapFor(d) : null;
        return QMat(words: [x ?? d], ans: x == null ? 0 : 1);
      case 'wh':
        final seen = <String>{d.h};
        final o = <Word>[d];
        for (final x in [...shuf(soundAlikes(d)), ...wordOpts(d, 'f', 1)]) {
          if (o.length == 4) break;
          if (seen.add(x.h)) o.add(x);
        }
        final s = shuf(o);
        return QMat(words: s, ans: s.indexOf(d));
      case 'wo':
        final p = pieces(d, piecesMax(d.l))!;
        var s = shuf(p);
        for (var k = 0; k < 4 && s.join() == p.join(); k++) {
          s = shuf(p);
        }
        return QMat(parts: s);
    }
    return question(d, q, 0.8);
  }

  Mock mockExam(int l, {bool short = false}) {
    final L = math.min(l, 6);
    final paper = mockPaper[L]!;
    final own = shuf(data.where((d) => d.l == l).toList());
    final low = shuf(data.where((d) => d.l < l).toList());
    final used = <String>{};
    Word? take(bool Function(Word) ok) {
      final first = R() < 0.7 || low.isEmpty ? own : low;
      for (final src in [first, identical(first, own) ? low : own]) {
        for (final x in src) {
          if (!used.contains(x.id) && ok(x)) {
            used.add(x.id);
            return x;
          }
        }
      }
      return null;
    }

    final fit = <String, bool Function(Word)>{
      'l': (_) => true,
      'm': (_) => true,
      'c': clozeOK,
      't': clozeOK,
      'ls': clozeOK,
      'lt': clozeOK,
      'lj': (d) => clozeOK(d) && charLen(d.z) <= 24,
      'wh': (d) => clozeOK(d) && charLen(d.h) <= 2 && soundAlikes(d).isNotEmpty,
      'wo': (d) => pieces(d, piecesMax(d.l)) != null,
    };
    final parts = <({String k, int n, int sec})>[];
    final items = <Item>[];
    for (var s = 0; s < 3; s++) {
      final part = mockSections[s];
      var n = paper.n[s];
      if (n == 0 || (part == 'listen' && !ttsReady())) continue;
      var sec = paper.min[s] * 60;
      if (short) {
        final m = math.max(3, (n / 3).round());
        sec = math.max(180, (sec * m / n / 60).round() * 60);
        n = m;
      }
      final mine = <Item>[];
      split(n, mockMix(part, L)).forEach((q, k) {
        for (var i = 0; i < k; i++) {
          var d = take(fit[q]!);
          var qq = q;
          if (d == null && q != 'l' && q != 'm') {
            qq = part == 'listen' ? 'l' : (part == 'read' ? 'm' : 'wh');
            d = take(fit[qq]!);
          }
          if (d != null) mine.add(Item.q(d, qq, part: part));
        }
      });
      if (mine.isEmpty) continue;
      items.addAll(mine);
      parts.add((k: part, n: mine.length, sec: sec));
    }
    return Mock(l, parts, items, parts.fold<int>(0, (a, p) => a + p.sec), !ttsReady(), short);
  }

  MockScore mockScore(Mock m) {
    final parts = <MockPart>[];
    for (final p in m.parts) {
      final its = m.items.where((it) => it.part == p.k).toList();
      final right = its.where((it) => it.ok == true).length;
      parts.add(MockPart(p.k, its.length, right, jsRound((right / math.max(1, its.length)) * 100)));
    }
    final total = parts.fold<int>(0, (a, p) => a + p.score), max = parts.length * 100;
    return MockScore(parts, total, max, jsRound(max * 0.6), total >= max * 0.6);
  }

  List<List<dynamic>> mocks = [];

  /// history: [time, level, total, max, [listen, read, write scores or null], seconds used, 1 = the short paper]
  void mockSave(Mock m, MockScore r, num used) {
    int? by(String k) {
      for (final p in r.parts) {
        if (p.k == k) return p.score;
      }
      return null;
    }

    mocks = [
      ...mocks,
      [now(), m.L, r.total, r.max, [for (final k in const ['listen', 'read', 'write']) by(k)], jsRound(used), if (m.short) 1],
    ];
    if (mocks.length > 50) mocks = mocks.sublist(mocks.length - 50);
    ls.set('xc_mock', mocks);
  }

  // ---------------------------------------------------------------- realms and the placement test
  Json? lvInfo;

  int realm() {
    final i = lvInfo;
    if (i == null) return 0;
    if (isInt(i['r'])) return (i['r'] as num).toInt();
    if (i['src'] == 'manual') return 0;
    if (i['m'] == 6) return 7;
    return (i['lv'] as num).toInt();
  }

  bool gateOpen() => lvInfo != null && _truthy(lvInfo!['gate']);
  int topLevel() => levels.last;
  int realmLevel(int r) => math.max(1, math.min(topLevel(), r));
  bool isFinal(int r) => r >= 10 || (r >= 7 && !gateOpen()) || r > topLevel();
  int baseLevel() {
    final r = realm();
    return r < 1 ? (lvInfo != null && lvInfo!['src'] == 'manual' ? (lvInfo!['lv'] as num).toInt() : 1) : realmLevel(r);
  }

  int curLevel() {
    final top = topLevel();
    for (var l = baseLevel(); l <= top; l++) {
      if (by(l).any((d) => !mem.containsKey(d.id))) return l;
    }
    return top;
  }

  static bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

  /// history entries: [realm, time, 'test'|'bt', quality 1–4]
  void setRealm(int r, String src, [Json? extra]) {
    final e = <Object>[r, now(), src];
    if (extra != null && _truthy(extra['grade'])) e.add(extra['grade']);
    final old = lvInfo?['hist'];
    var hist = [...(old is List ? old : const []), e];
    if (hist.length > 30) hist = hist.sublist(hist.length - 30);
    final x = Map<String, dynamic>.from(extra ?? {});
    x.remove('grade');
    lvInfo = {
      ...?lvInfo,
      ...x,
      'r': r,
      'lv': math.max(1, math.min(9, r)),
      'src': src,
      'at': now(),
      'hist': hist,
    };
    ls.set('xc_lvl', lvInfo);
  }

  static bool okHist(Object? h) =>
      h is List &&
      h.length >= 2 &&
      h.length <= 4 &&
      isInt(h[0]) &&
      (h[0] as num) >= 0 &&
      (h[0] as num) <= 10 &&
      isFin(h[1]) &&
      (h.length < 3 || h[2] == 'test' || h[2] == 'bt') &&
      (h.length < 4 || const [1, 2, 3, 4].contains(h[3]));

  void restoreLevel(Object? o) {
    if (o is! Map) return;
    final lv = o['lv'], src = o['src'];
    if (!(lv is num && lv >= 1 && lv <= 9 && const ['test', 'manual', 'bt'].contains(src))) return;
    int? num_(Object? x) => isFin(x) ? jsRound(x as num) : null;
    final r = o['r'], m = o['m'], per = o['per'], th = o['th'], pt = o['pt'], hist = o['hist'];
    final info = <String, dynamic>{
      'lv': lv,
      'src': src,
      'at': isFin(o['at']) ? o['at'] : now(),
      'r': isInt(r) && (r as num) >= 0 && r <= 10 ? r : null,
      'hist': hist is List ? (() {
        final l = hist.where(okHist).toList();
        return l.length > 30 ? l.sublist(l.length - 30) : l;
      })() : null,
      'm': isInt(m) && (m as num) >= 0 && m <= 6 ? m : null,
      'per': per is List && per.length == 6 && per.every(isFin) ? per : null,
      'th': th is List && th.length == 2 && th.every(isFin) && (th[1] as num) > 0 ? th : null,
      'pt': pt is List ? (() {
        final l = pt.where(isFin).toList();
        return l.length > 5 ? l.sublist(l.length - 5) : l;
      })() : null,
      'gate': num_(o['gate']),
      'gs': _truthy(o['gs']) ? 1 : null,
      'stab': num_(o['stab']),
    };
    info.removeWhere((k, v) => v == null);
    lvInfo = info;
    if (_truthy(info['gate'])) info['gs'] = 1;
    ls.set('xc_lvl', lvInfo);
  }

  void gateSeen() {
    if (lvInfo != null) {
      lvInfo!['gs'] = 1;
      ls.set('xc_lvl', lvInfo);
    }
  }

  static const ptN = 50, ptK = 2.4, ptG = 0.25, ptSlip = 0.04, ptIdk = 0.6;
  static const ptDQ = {'m': -0.3, 'f': 0.0, 's': 0.1, 'c': 0.2};
  static const ptTypes = {1: 'mfs', 2: 'mfs', 3: 'mfsc', 4: 'mfsc', 5: 'fsc', 6: 'fsc'};
  static final List<double> grid = List.generate(71, (i) => i / 10);
  static const plv = [1, 2, 3, 4, 5, 6];
  Map<int, List<Word>>? _pb;

  Map<int, List<Word>> placementBank() {
    if (_pb != null) return _pb!;
    final pb = <int, List<Word>>{};
    final seen = <String>{};
    for (final l in plv) {
      pb[l] = by(l).where((d) {
        final c = chars(d.h);
        return c.length <= 4 && (l < 3 || c.length >= 2) && (l == 1 || c.any((x) => !seen.contains(x))) && d.pm != 0 && clozeOK(d);
      }).toList();
      for (final d in by(l)) {
        seen.addAll(chars(d.h));
      }
    }
    return _pb = pb;
  }

  static double pKnow(double th, double b) => 1 / (1 + math.exp(-ptK * (th - b)));
  /// how hard a placement question is; a sentence gap up to HSK 4 shows its translation, so it counts as easier
  double itemB(int l, String q, Word? d) =>
      l - 0.5 + (q == 'c' && l <= 4 ? 0.0 : ptDQ[q]!) + (l >= 5 ? 0.15 : 0) + (d != null ? wdiff(d) * 0.8 : 0);

  static double likelihood(String r, double pk, double idk) {
    final nk = 1 - pk;
    return r == 'ok'
        ? pk * (1 - ptSlip) + nk * (1 - idk) * ptG
        : r == 'idk'
        ? pk * 0.01 + nk * idk
        : pk * (ptSlip - 0.01) + nk * (1 - idk) * (1 - ptG);
  }

  List<double> posterior(PtState st) {
    int n(String r) => st.items.where((x) => x.r == r).length;
    final a = n('idk') * (1 - ptG);
    final idk = cl((a + ptIdk * 2) / (a + n('ng') + 2), 0.03, 0.95);
    var post = [for (final t in grid) -t / 3.5];
    for (final it in st.items) {
      final b = itemB(it.l!, it.q!, it.d);
      post = [for (var i = 0; i < post.length; i++) post[i] + math.log(likelihood(it.r!, pKnow(grid[i], b), idk))];
    }
    final mx = maxOf(post);
    post = [for (final p in post) math.exp(p - mx)];
    final s = sumOf(post);
    return [for (final p in post) p / s];
  }

  ({double mean, double sd}) ptStats(PtState st) {
    final post = st.post = posterior(st);
    var m = 0.0, v = 0.0;
    for (var i = 0; i < grid.length; i++) {
      m += grid[i] * post[i];
    }
    for (var i = 0; i < grid.length; i++) {
      v += (grid[i] - m) * (grid[i] - m) * post[i];
    }
    return (mean: m, sd: math.sqrt(v));
  }

  PtState ptStart() {
    placementBank();
    return PtState();
  }

  /// the next question: three warm-ups (HSK 1, 2, 3), then aimed at the estimate, with a little spread
  Item? ptNext(PtState st) {
    final n = st.items.length;
    if (n >= ptN) return null;
    final s = ptStats(st);
    var l = n < 3 ? n + 1 : jsRound(s.mean + 0.5 + (R() - 0.5) * math.min(1.2, s.sd));
    l = cli(l, 1, 6);
    if (n >= 3 && s.mean >= 4.3) {
      final c5 = st.items.where((x) => x.l == 5).length, c6 = st.items.where((x) => x.l == 6).length;
      l = c5 == c6 ? (s.mean >= 5.5 ? 6 : 5) : (c5 < c6 ? 5 : 6);
    }
    final types = chars(ptTypes[l]!);
    int cnt(String q) => st.items.where((x) => x.q == q).length;
    jsSort(types, (a, b) => cnt(a) - cnt(b) + (R() - 0.5) * 0.5);
    final q = types[0];
    final pool = _pb![l]!.where((d) => !st.used.contains(d.id) && !(q == 'c' && !clozeOK(d))).toList();
    final fresh = pool.where((d) => !chars(d.h).any(st.chars.contains)).toList();
    final src = fresh.isNotEmpty ? fresh : pool;
    final d = src[(R() * src.length).floor()];
    st.used.add(d.id);
    st.chars.addAll(chars(d.h));
    final it = Item.q(d, q, l: l);
    it.apply(question(d, q, l >= 4 ? 0.85 : 0.5));
    return it;
  }

  void ptAnswer(PtState st, Item it, String r) {
    it.r = r;
    st.items.add(it);
  }

  PtResult ptResult(PtState st) {
    final s = ptStats(st);
    double ge(int l) {
      var a = 0.0;
      for (var i = 0; i < grid.length; i++) {
        a += grid[i] >= l - 1e-9 ? st.post![i] : 0;
      }
      return a;
    }

    bool pass(int l) {
      if (ge(l) < (l >= 5 ? 0.9 : 0.8)) return false;
      if (l < 5) return true;
      final it = st.items.where((x) => x.l == l).toList();
      final ok = it.where((x) => x.r == 'ok').length;
      return it.length >= 5 && ok / it.length >= 0.7;
    }

    var m = 0;
    for (final l in plv) {
      if (pass(l)) {
        m = l;
      } else {
        break;
      }
    }
    final per = [
      for (final l in plv)
        jsRound(
          () {
            var a = 0.0;
            for (var i = 0; i < grid.length; i++) {
              a += st.post![i] * pKnow(grid[i], l - 0.5);
            }
            return a;
          }() *
              100,
        ),
    ];
    final right = st.items.where((x) => x.r == 'ok').length, idk = st.items.where((x) => x.r == 'idk').length;
    return PtResult(m, math.min(6, m + 1), s.mean, s.sd, per, right, idk, st.items.length);
  }

  // ---------------------------------------------------------------- weekly test, stages
  static const week = 7 * 1440;
  List<int> tests = [];

  void restoreExtra(Json? o) {
    if (o == null) return;
    final t = o['tests'];
    if (t is List) {
      final l = t.where(isFin).map((x) => jsRound(x as num)).toList();
      tests = l.length > 30 ? l.sublist(l.length - 30) : l;
      ls.set('xc_tests', tests);
    }
    if (o['rest'] is List) setRest((o['rest'] as List).toList());
    if (o['days'] is List) {
      final l = (o['days'] as List).where(isInt).map((x) => (x as num).toInt()).toList();
      days0 = l.length > 730 ? l.sublist(l.length - 730) : l;
      ls.set('xc_days', days0);
    }
    if (o['mock'] is List) {
      final l = (o['mock'] as List)
          .where((x) => x is List && x.length >= 5 && isFin(x[0]) && x[1] is num && x[1] >= 1 && x[1] <= 9)
          .map((x) => x as List<dynamic>)
          .toList();
      mocks = l.length > 50 ? l.sublist(l.length - 50) : l;
      ls.set('xc_mock', mocks);
    }
  }

  int nextTestAt() => tests.isNotEmpty ? tests.reduce(math.max) + week : 0;
  bool canTest() => now() >= nextTestAt();
  void noteTest() {
    tests = [...tests, now()];
    if (tests.length > 30) tests = tests.sublist(tests.length - 30);
    ls.set('xc_tests', tests);
  }

  /// stage share = (solid words + ½ × the test's estimate for the words not solid yet) ÷ the level's words
  Float32List credit(int l) {
    final w = by(l);
    final p = testP(l);
    final c = Float32List(w.length);
    for (var j = 0; j < w.length; j++) {
      final e = mem[w[j].id];
      if (solid(e)) {
        c[j] = 1;
        continue;
      }
      if (p == null) continue;
      final ok = e != null ? lastOk(e) : null;
      if (ok == false) continue;
      c[j] = 0.5 * (ok == true ? math.max(p[j], 0.9) : p[j]);
    }
    return c;
  }

  Stage? stage([int? r0]) {
    final r = r0 ?? realm();
    if (r < 1) return null;
    final l = realmLevel(r), w = by(l);
    if (isFinal(r)) {
      return Stage(i: 3, share: 1, solid: w.length, test: 0, testShare: 0, total: w.length, need: 0, fin: true);
    }
    final c = credit(l);
    var n = 0;
    var sum = 0.0, est = 0.0;
    for (var j = 0; j < c.length; j++) {
      sum += c[j];
      if (c[j] == 1) {
        n++;
      } else {
        est += c[j] * 2;
      }
    }
    final share = sum / w.length;
    final need = math.max(0, (w.length * 0.8 - sum).ceil());
    return Stage(
      i: share >= 0.8 ? 3 : (share >= 0.5 ? 2 : (share >= 0.25 ? 1 : 0)),
      share: share,
      solid: n,
      test: jsRound(est),
      testShare: (sum - n) / w.length,
      total: w.length,
      need: need,
    );
  }

  // ---------------------------------------------------------------- a stable realm
  Stab stability([int? r0]) {
    final r = r0 ?? realm();
    if (r < 2) return const Stab(ok: true);
    final p = realmLevel(r - 1), t = now(), t0 = t - 30 * 1440, pre = '$p:';
    final stab = lvInfo?['stab'];
    if (lvInfo != null && _truthy(stab) && t - (stab as num) < 30 * 1440) {
      return _stabCheck(p, pre, math.max(t0, stab.toInt()), t, true);
    }
    return _stabCheck(p, pre, t0, t, false);
  }

  Stab _stabCheck(int p, String pre, int t0, int t, bool after) {
    final l = allLog();
    final seen = <String>{};
    var n = 0, c = 0;
    for (var i = l.length - 1; i >= 0; i--) {
      final e = l[i];
      if (e.t < t0 || (after && e.t == t0)) break;
      if (!e.id.startsWith(pre) || e.f & 48 != 0 || !quiz.contains(e.q)) continue;
      final k = '${e.id}@${dayOf(e.t)}';
      final m = mem[e.id];
      if (seen.contains(k) || m == null || dayOf(m.i) >= dayOf(e.t)) continue;
      seen.add(k);
      n++;
      if (e.g > 1) c++;
    }
    var rs = 0.0;
    var rn = 0;
    for (final d in by(p)) {
      final e = mem[d.id];
      if (e == null) continue;
      rs += rNowE(e, t);
      rn++;
    }
    final double? acc = n > 0 ? c / n : null;
    final double? rec = rn > 0 ? rs / rn : null;
    final badAcc = n >= 15 && acc! < 0.7, badRec = !after && rn >= 20 && rec! < 0.6;
    return Stab(
      ok: !(badAcc || badRec),
      P: p,
      n: n,
      acc: acc,
      rn: rn,
      rec: rec,
      why: badAcc ? 'acc' : (badRec ? 'rec' : null),
    );
  }

  List<Word> stabWords([int n = 15]) {
    final s = stability();
    if (s.ok) return [];
    final t = now();
    final l = <(double, Word)>[for (final d in by(s.P!)) if (mem.containsKey(d.id)) (rNowE(mem[d.id], t), d)];
    jsSort(l, (a, b) => a.$1 - b.$1);
    return l.take(n).map((p) => p.$2).toList();
  }

  bool stabDone(int right, int total) {
    if (total == 0 || right / total < 0.8) return false;
    lvInfo = {...?lvInfo, 'stab': now()};
    ls.set('xc_lvl', lvInfo);
    return true;
  }

  // ---------------------------------------------------------------- the tribulation
  static const strikes = [
    Strike('shi', '识', 'shí', 'm', 5),
    Strike('yi', '忆', 'yì', 'p', 5),
    Strike('ting', '听', 'tīng', 'l', 5, tts: true),
    Strike('du', '读', 'dú', 'c', 5),
    Strike('su', '速', 'sù', 'm', 8, timed: true),
    Strike('fan', '译', 'yì', 't', 5, band: true),
  ];
  static double cutOf(int l) => l >= 7 ? 0.85 : (l >= 5 ? 0.8 : 0.75);
  static int limitOf(int l) => l <= 3 ? 6 : (l <= 6 ? 5 : 4);
  static const gradeNames = ['', '下品', '中品', '上品', '完美'];

  bool btReady() {
    final r = realm();
    return r >= 1 && !isFinal(r) && stage(r)!.i == 3 && stability(r).ok;
  }

  bool btOpen() => btReady() || makeupOpen();
  bool makeupOpen() => realm() == 7 && !gateOpen() && levels.contains(6);

  Trib btStart() {
    placementBank();
    final r = realm(), makeup = makeupOpen(), l = makeup ? 6 : realmLevel(r);
    final hard = l >= 4 ? 0.85 : 0.6;
    final base = (l <= 6 && _pb![l] != null && _pb![l]!.length >= 40 ? _pb![l]! : by(l)).where(clozeOK).toList();
    final pool = shuf(base.length >= 40 ? base : by(l));
    final used = <String>{};
    final items = <Item>[];
    final sts = <StrikeRes>[];
    Word? take(bool Function(Word) ok) {
      Word? d;
      for (final x in pool) {
        if (!used.contains(x.id) && ok(x)) {
          d = x;
          break;
        }
      }
      if (d == null) {
        for (final x in shuf(by(l))) {
          if (!used.contains(x.id) && ok(x)) {
            d = x;
            break;
          }
        }
      }
      if (d != null) used.add(d.id);
      return d;
    }

    for (final s in strikes) {
      if (s.band && l < 7) continue;
      if (s.tts && !ttsReady()) {
        sts.add(StrikeRes(s.k, s.hz, s.py, 0, skipped: true));
        continue;
      }
      var n = 0;
      for (var i = 0; i < s.n; i++) {
        final d = take((x) => s.q == 'c' || s.q == 't' ? clozeOK(x) : true);
        if (d == null) break;
        final it = Item.q(d, s.q, l: l, strike: s.k);
        if (s.timed) it.limit = limitOf(l);
        it.apply(question(d, s.q, hard));
        items.add(it);
        n++;
      }
      sts.add(StrikeRes(s.k, s.hz, s.py, n, timed: s.timed));
    }
    return Trib(r, l, makeup, items, sts);
  }

  TribResult btFinish(Trib st) {
    final cut = cutOf(st.L);
    final res = <StrikeRes>[];
    for (final s in st.strikes) {
      if (s.skipped) {
        res.add(StrikeRes(s.k, s.hz, s.py, s.n, timed: s.timed, skipped: true, right: 0, pass: true));
        continue;
      }
      final its = st.items.where((x) => x.strike == s.k).toList();
      final right = its.where((x) => x.r == 'ok').length;
      res.add(StrikeRes(s.k, s.hz, s.py, s.n, timed: s.timed, right: right, pass: right >= (its.length * 0.7).ceil()));
    }
    final n = st.items.length, right = st.items.where((x) => x.r == 'ok').length;
    final acc = n > 0 ? right / n : 0.0;
    final pass = res.every((x) => x.pass) && acc >= cut;
    noteTest();
    var grade = 0;
    var gate = false;
    if (pass) {
      grade = right == n && !res.any((x) => x.skipped)
          ? 4
          : (acc >= math.min(cut + 0.15, 0.97) ? 3 : (acc >= math.min(cut + 0.08, 0.93) ? 2 : 1));
      final th = testTh();
      final x = <String, dynamic>{'grade': grade};
      if (th != null && st.L <= 6) x['th'] = [r2(math.max(th[0], st.L.toDouble())), r2(math.min(th[1], 0.6))];
      if (st.makeup) {
        x['gate'] = now();
        setRealm(7, 'bt', x);
        gate = true;
      } else {
        if (st.r + 1 == 7) x['gate'] = now();
        setRealm(st.r + 1, 'bt', x);
        gate = st.r + 1 == 7;
      }
    }
    return TribResult(
      pass: pass,
      need: cut,
      acc: acc,
      right: right,
      n: n,
      grade: grade,
      gate: gate,
      strikes: res,
      r: realm(),
      makeup: st.makeup,
      weak: st.items.where((x) => x.r != 'ok').map((x) => x.d).toList(),
    );
  }

  /// the quality of each realm reached by a breakthrough: {realm: 1–4} (best kept)
  Map<int, int> grades() {
    final g = <int, int>{};
    final h = lvInfo?['hist'];
    if (h is List) {
      for (final e in h) {
        if (e is List && e.length > 3 && e[2] == 'bt' && _truthy(e[3])) {
          final r = (e[0] as num).toInt();
          g[r] = math.max(g[r] ?? 0, (e[3] as num).toInt());
        }
      }
    }
    return g;
  }

  // ---------------------------------------------------------------- the placement test is the way in
  List<num> ptTimes() {
    final i = lvInfo;
    if (i == null) return [];
    if (i['pt'] is List) return (i['pt'] as List).whereType<num>().toList();
    final hist = i['hist'];
    return i['src'] == 'test' || (hist is List && hist.any((h) => h is List && h.length > 2 && h[2] == 'test'))
        ? [(i['at'] as num?) ?? 0]
        : [];
  }

  String? ptOpen() {
    final t = ptTimes();
    if (t.isEmpty) return realm() == 0 ? (canTest() ? 'first' : 'wait') : null;
    if (t.length == 1 && now() - t[0] <= 14 * 1440 && lvInfo != null && lvInfo!['src'] == 'test') return 'retake';
    return null;
  }

  num ptRetakeUntil() {
    final t = ptTimes();
    return t.length == 1 ? t[0] + 14 * 1440 : 0;
  }

  void placementDone(PtResult res) {
    final t = ptTimes();
    noteTest();
    var pt = [...t, now()];
    if (pt.length > 5) pt = pt.sublist(pt.length - 5);
    setRealm(math.min(6, res.m + 1), 'test', {
      'm': res.m,
      'per': res.per,
      'th': [r2(res.mean), r2(math.max(0.15, res.sd))],
      'pt': pt,
    });
  }

  // ---------------------------------------------------------------- what the placement test says about words
  List<double>? testTh() {
    final i = lvInfo;
    if (i == null) return null;
    if (i['th'] is List) return (i['th'] as List).map((x) => (x as num).toDouble()).toList();
    final per = i['per'];
    if (per is! List || i['src'] == 'manual') return null;
    var best = 0.0, err = 1e9;
    for (final t in grid) {
      var e = 0.0;
      for (var k = 0; k < plv.length; k++) {
        final d = pKnow(t, plv[k] - 0.5) - (per[k] as num) / 100;
        e += d * d;
      }
      if (e < err) {
        err = e;
        best = t;
      }
    }
    return [best, 0.5];
  }

  ({String key, Float32List p})? _tp;
  Float32List? testP(int l) {
    final th = testTh();
    if (th == null || l > 6) return null;
    final key = '$l:${th.join(',')}';
    if (_tp != null && _tp!.key == key) return _tp!.p;
    final m = th[0], sd = th[1];
    final w = [
      for (final t in grid)
        math.exp(-0.5 * ((t - m) / sd) * ((t - m) / sd)),
    ];
    final ws = sumOf(w);
    final words = by(l);
    final p = Float32List(words.length);
    for (var j = 0; j < words.length; j++) {
      final b = itemB(l, 'f', words[j]);
      var s = 0.0;
      for (var i = 0; i < grid.length; i++) {
        if (w[i] > 1e-6) s += w[i] * pKnow(grid[i], b);
      }
      p[j] = s / ws;
    }
    _tp = (key: key, p: p);
    return p;
  }

  /// the most recent skill answer of a word: true right, false wrong, null none
  static bool? lastOk(Mem e) {
    var t = -1.0, g = 0.0;
    for (final k in const ['m', 'f', 's']) {
      final se = e.sk(k);
      if (se != null && se[2] > t) {
        t = se[2];
        g = se[3];
      }
    }
    return t < 0 ? null : g > 1;
  }

  // ---------------------------------------------------------------- cultivation days, meditation days, challenge
  List<int> rest = [];
  /// JS new Date((day·1440 + TZ)·6e4 + EPOCH).getDay(): the weekday of that local day (1 Jan 2026 was a Thursday)
  int weekday(int day) => (day + 4) % 7;

  bool isRest(int day) => rest.contains(weekday(day));
  void setRest(List a) {
    final l = a.where((x) => isInt(x) && (x as num) >= 0 && x <= 6).map((x) => (x as num).toInt()).toList();
    rest = l.length > 2 ? l.sublist(0, 2) : l;
    ls.set('xc_rest', rest);
  }

  List<int> days0 = [];

  /// days with practice: from the answer log, plus the days a restored backup code brought
  Set<int> studyDays() {
    final s = <int>{...days0};
    for (final e in allLog()) {
      if (e.f & 16 == 0) s.add(dayOf(e.t));
    }
    return s;
  }

  /// consecutive days of cultivation: a practice day counts; a meditation day and one free day a week keep the run
  ({int days, bool today}) streak() {
    final s = studyDays();
    if (s.isEmpty) return (days: 0, today: false);
    final today = dayOf(now());
    var d = s.contains(today) ? today : today - 1;
    var n = 0, grace = -99;
    for (var k = 0; k < 3650; k++, d--) {
      if (s.contains(d)) {
        n++;
        continue;
      }
      if (isRest(d)) {
        n++;
        continue;
      }
      if (grace - d >= 7 || grace == -99) {
        grace = d;
        n++;
        continue;
      }
      break;
    }
    while (n > 0 && !s.contains(d + 1) && d + 1 < today) {
      d++;
      n--;
    }
    return (days: n, today: s.contains(today));
  }

  Json game = {};
  static const skq = {
    'm': ['m', 'cm'],
    'f': ['f', 'c'],
    's': ['s', 'l', 'cs'],
  };

  /// today's challenge: the weakest skill, a target a bit above the last 7 days (answers ×1.15, accuracy +10)
  Json challenge() {
    final today = dayOf(now());
    final ch = game['chal'];
    if (ch is! Map || ch['day'] != today) {
      final l = allLog();
      final cnt = {'m': 0, 'f': 0, 's': 0}, ok = {'m': 0, 'f': 0, 's': 0};
      final days = <int>{};
      for (var i = l.length - 1; i >= 0; i--) {
        final e = l[i], d = dayOf(e.t);
        if (d >= today) continue;
        if (today - d > 7) break;
        if (e.f & 24 != 0) continue;
        for (final k in skq.keys) {
          if (skq[k]!.contains(e.q)) {
            cnt[k] = cnt[k]! + 1;
            if (e.g > 1) ok[k] = ok[k]! + 1;
            days.add(d);
          }
        }
      }
      double? acc(String k) => cnt[k]! >= 8 ? ok[k]! / cnt[k]! : null;
      var k = 'm';
      final cand = sorted(['s', 'f', 'm'].where((x) => acc(x) != null), (a, b) => acc(a)! - acc(b)!);
      if (cand.isNotEmpty) {
        k = cand[0];
      } else if (cnt['m']! >= 8) {
        k = 'f';
      }
      final perDay = days.isNotEmpty ? cnt[k]! / days.length : 0.0;
      final nn = jsRound((perDay * 1.15) / 5) * 5;
      game['chal'] = {
        'day': today,
        'k': k,
        'n': cl(nn == 0 ? 10 : nn, 10, 30).toInt(),
        'a': acc(k) == null ? 75 : cl(jsRound((acc(k)! * 100 + 10) / 5) * 5, 70, 95).toInt(),
        'done': false,
      };
      ls.set('xc_game', game);
    }
    final c = game['chal'] as Map;
    final l = allLog();
    var n = 0, o = 0;
    for (var i = l.length - 1; i >= 0; i--) {
      final e = l[i];
      if (dayOf(e.t) != today) break;
      if (e.f & 24 != 0) continue;
      if (skq[c['k']]!.contains(e.q)) {
        n++;
        if (e.g > 1) o++;
      }
    }
    final acc = n > 0 ? jsRound((o / n) * 100) : 0;
    final done = n >= (c['n'] as num) && acc >= (c['a'] as num);
    if (done && c['done'] != true) {
      c['done'] = true;
      game['chalN'] = ((game['chalN'] as num?) ?? 0) + 1;
      ls.set('xc_game', game);
    }
    return {...c, 'cnt': n, 'acc': acc, 'done': c['done'] == true || done, 'total': (game['chalN'] as num?) ?? 0};
  }

  // ---------------------------------------------------------------- rest: the memory model's own numbers
  /// what one more right answer adds to a word's memory now vs after a night's sleep vs after 2 days (in days)
  ({double now, double day, double two, double S})? restGain() {
    final e = mem.values.where((x) => x.w[1] >= 1).toList();
    if (e.isEmpty) return null;
    double med(List<double> a) {
      final b = sorted(a, byNum);
      return b[b.length >> 1];
    }

    final d = med(e.map((x) => x.w[0]).toList()), s = med(e.map((x) => x.w[1]).toList());
    const t0 = 1000000;
    double g(int dt) => step([d, s, t0.toDouble()], 3, t0 + dt)[1] - s;
    return (now: g(10), day: g(1440), two: g(2880), S: s);
  }

  ({int n, double now, double later}) gainList(Iterable<Word> words) {
    var a = 0.0, b = 0.0;
    var n = 0;
    final t = now();
    for (final d in words) {
      final e = mem[d.id];
      if (e == null || dayOf(e.w[2].toInt()) != dayOf(t)) continue;
      n++;
      a += step(e.w, 3, t)[1] - e.w[1];
      b += step(e.w, 3, e.w[2] + 1440 * 1.5)[1] - e.w[1];
    }
    return (n: n, now: a, later: b);
  }

  /// days since the last practice and how much is still remembered
  ({int gap, int? recall})? sinceLast() {
    final l = allLog();
    for (var i = l.length - 1; i >= 0; i--) {
      if (l[i].f & 16 == 0) {
        final gap = dayOf(now()) - dayOf(l[i].t);
        var rs = 0.0;
        var rn = 0;
        final t = now();
        for (final e in mem.values) {
          rs += rNowE(e, t);
          rn++;
        }
        return (gap: gap, recall: rn > 0 ? jsRound((rs / rn) * 100) : null);
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- the five elements
  static const daoA = 20;
  ({int n, int c, double score}) daoStat() {
    final l = allLog(), t0 = now() - 90 * 1440;
    final open = <String, int>{};
    var n = 0, c = 0;
    for (final e in l) {
      if (e.t < t0 || e.f & 16 != 0) continue;
      final id = e.id, q = e.q, f = e.f;
      if (f & 2 != 0 && (q == 'cm' || q == 'cs')) {
        n++;
        if (e.g > 1) c++;
        open.remove(id);
        continue;
      }
      if (f & 2 != 0 && f & 1 != 0) {
        open.remove(id);
        open[id] = e.t;
        continue;
      }
      if (open.containsKey(id) && (quiz.contains(q) || q == 'cn') && f & 32 == 0) {
        final t = open.remove(id)!;
        if (e.t - t <= 14 * 1440) {
          n++;
          if (e.g > 1) c++;
        }
      }
    }
    return (n: n, c: c, score: (c + daoA / 2) / (n + daoA));
  }

  Json soul() {
    final t = now(), r = realm();
    final l = r < 1 ? baseLevel() : realmLevel(r);
    final st = stage(r < 1 ? l : r);
    final es = mem.values.toList();
    var x = 0.0;
    for (final e in es) {
      x += math.min(e.w[1], 365);
    }
    var rs = 0.0;
    for (final d in by(l)) {
      final e = mem[d.id];
      if (e != null) rs += rNowE(e, t);
    }
    final ks = sorted(
      es.where((e) => (e.k ?? 0) != 0 && e.i != 0).map((e) => (e.k! - e.i) / 1440).where((v) => v >= 0),
      byNum,
    );
    final dao = daoStat();
    int? v(num? y) => y == null ? null : jsRound(cl(y, 0, 100));
    return {
      'L': l,
      'root': v(st != null ? st.share * 100 : (es.isNotEmpty ? 0 : null)),
      'cult': v((100 * math.log(1 + x / 100)) / math.log(1 + (data.length * 120) / 100)),
      'cultDays': jsRound(x),
      'sense': v(es.isNotEmpty ? (rs / by(l).length) * 100 : null),
      'senseN': jsRound(rs),
      'senseOf': by(l).length,
      'dao': v(dao.n >= 5 ? dao.score * 100 : null),
      'daoN': dao.n,
      'daoOk': dao.c,
      'insight': v(ks.length >= 10 ? (100 * (30 - ks[ks.length >> 1])) / 26 : null),
      'insightDays': ks.length >= 10 ? jsRound(ks[ks.length >> 1]) : null,
      'words': es.length,
    };
  }

  // ---------------------------------------------------------------- guidance
  static final double solidS = math.pow(121, 0.5) - 1;
  double daysToSolid(Mem e, int t) {
    var d = e.w[0], s = e.w[1];
    var days = math.max(0.0, (e.w[2] + fsrs.ivl(s, 0.9) * 1440 - t) / 1440);
    var n = 0;
    while (s < solidS && n < 30) {
      final gap = math.max(1.0, fsrs.ivl(s, 0.9));
      final st = fsrs.step(W, [d, s, 0], 3, gap * 1440, tz, 0, 0);
      d = st[0];
      s = st[1];
      if (s >= solidS) break;
      days += gap;
      n++;
    }
    return math.min(365, days);
  }

  ({int L, List<Json> items}) advice() {
    final t = now(), r = realm();
    final l = r < 1 ? baseLevel() : realmLevel(r);
    final wd = by(l);
    final r0 = dr();
    final out = <Json>[];
    final neu = <Word>[], young = <Mem>[], needF = <Word>[], needS = <Word>[], due = <Word>[];
    for (final d in wd) {
      final e = mem[d.id];
      if (e == null) {
        neu.add(d);
        continue;
      }
      if (rNowE(e, t) < r0) due.add(d);
      if (solid(e)) continue;
      if (levelOf(e) >= 10 || e.w[1] >= solidS) {
        if (!okS(e.f)) {
          needF.add(d);
        } else if (!okS(e.s)) {
          needS.add(d);
        }
      } else {
        young.add(e);
      }
    }
    final pt = ptOpen();
    if (r < 1 && pt == 'first') out.add({'k': 'test'});
    final sb = stability(r);
    if (!sb.ok) out.insert(0, {'k': 'unstable', 'P': sb.P, 'acc': sb.acc, 'rec': sb.rec, 'why': sb.why});
    if (makeupOpen()) out.add({'k': 'makeup'});
    if (needF.isNotEmpty) out.add({'k': 'f', 'n': needF.length, 'words': needF.take(12).toList(), 'L': l});
    if (needS.isNotEmpty) out.add({'k': 's', 'n': needS.length, 'words': needS.take(12).toList(), 'L': l});
    if (due.isNotEmpty) out.add({'k': 'due', 'n': due.length, 'L': l});
    final ins = insights();
    if (ins['weak'] != null) {
      out.add({'k': 'skill', 'q': ins['weak'], 'p': (ins['skills'] as Map)[ins['weak']]['p']});
    }
    if (young.isNotEmpty) {
      final ds = sorted(young.take(300).map((e) => daysToSolid(e, t)), byNum);
      out.add({'k': 'young', 'n': young.length, 'days': math.max(1, jsRound(ds[ds.length >> 1])), 'L': l});
    }
    if (neu.isNotEmpty) out.add({'k': 'new', 'n': neu.length, 'L': l});
    final prs = sorted(confs().entries.where((p) => p.value >= 2), (a, b) => b.value - a.value);
    if (prs.isNotEmpty) {
      final ab = prs[0].key.split('|');
      if (idx.containsKey(ab[0]) && idx.containsKey(ab[1])) {
        out.add({'k': 'conf', 'a': idx[ab[0]], 'b': idx[ab[1]], 'n': prs[0].value});
      }
    }
    final c = calib();
    if (c.n >= 8 && c.acc < 0.75) out.add({'k': 'dao', 'p': jsRound(c.acc * 100)});
    return (L: l, items: out);
  }

  /// when the next stage (and 圆满) is likely: new solid words of the level over the last 14 days
  Json? forecast() {
    final r = realm();
    final l = r < 1 ? baseLevel() : realmLevel(r);
    final st = stage(r < 1 ? l : r);
    if (st == null || st.fin) return null;
    final t = now(), p = testP(l);
    var n = 0.0;
    final w = by(l);
    for (var j = 0; j < w.length; j++) {
      final e = mem[w[j].id];
      if (e != null && e.k != null && t - e.k! < 14 * 1440 && solid(e)) n += p != null ? 1 - 0.5 * p[j] : 1;
    }
    final done = st.share * st.total, rate = n / 14;
    const tt = [0.25, 0.5, 0.8];
    final next = st.i < 3 ? math.max(0, (st.total * tt[st.i] - done).ceil()) : 0;
    return {
      'rate': rate,
      'week': jsRound(rate * 7),
      'next': next,
      'need': st.need,
      'dNext': rate > 0 && next != 0 ? (next / rate).ceil() : null,
      'dFull': rate > 0 && st.need != 0 ? (st.need / rate).ceil() : null,
    };
  }

  /// chance to pass the tribulation now (each word right with its recall chance, plus a little guessing)
  int? btChance() {
    final r = realm(), makeup = makeupOpen();
    if (r < 1 || (isFinal(r) && !makeup)) return null;
    placementBank();
    final l = makeup ? 6 : realmLevel(r), t = now();
    final bank = l <= 6 && _pb![l] != null && _pb![l]!.length >= 20 ? _pb![l]! : by(l);
    final hard = l >= 4 ? 0.9 : 0.95;
    var ch = 0.0, ty = 0.0;
    for (final d in bank) {
      final e = mem[d.id];
      final rr = e != null ? rNowE(e, t) : 0.0;
      ch += math.min(0.99, rr * hard + (1 - rr * hard) * 0.12);
      ty += math.min(0.97, rr * (e != null && okS(e.f) ? 0.85 : 0.6));
    }
    final pc = ch / bank.length, pt = ty / bank.length;
    double binomGE(int n, double p, int k) {
      var s = 0.0;
      for (var i = k; i <= n; i++) {
        var c = 1.0;
        for (var j = 0; j < i; j++) {
          c = (c * (n - j)) / (j + 1);
        }
        s += c * math.pow(p, i) * math.pow(1 - p, n - i);
      }
      return s;
    }

    var prod = 1.0, mean = 0.0, vr = 0.0;
    var nn = 0;
    for (final s in strikes) {
      if ((s.band && l < 7) || (s.tts && !ttsReady())) continue;
      final p = s.q == 'p' ? pt : (s.timed ? pc * 0.93 : pc);
      prod *= binomGE(s.n, p, (s.n * 0.7).ceil());
      nn += s.n;
      mean += s.n * p;
      vr += s.n * p * (1 - p);
    }
    final need = (nn * cutOf(l)).ceil();
    final z = (need - 0.5 - mean) / math.sqrt(math.max(0.25, vr));
    double phi(double x) {
      final k = 1 / (1 + 0.2316419 * x.abs());
      final y =
          0.3989423 *
          math.exp((-x * x) / 2) *
          k *
          (0.3193815 + k * (-0.3565638 + k * (1.781478 + k * (-1.821256 + k * 1.330274))));
      return x > 0 ? 1 - y : y;
    }

    return jsRound(100 * (1 - phi(z)) * prod);
  }

  // ---------------------------------------------------------------- goals and the daily plan
  bool validGoal(Object? g) {
    if (g is! Map) return false;
    final t = g['t'], pace = g['pace'];
    if (!const ['level', 'exam', 'none'].contains(t)) return false;
    if (t != 'none') {
      if (!levels.contains(g['lv'])) return false;
      final d = g['date'];
      if (d is! String || !RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(d)) return false;
    }
    if (!const ['min', 'new', 'auto'].contains(pace)) return false;
    return pace == 'auto' || (g['n'] is num && (g['n'] as num) > 0);
  }

  /// the calendar date (local) of a day number
  DateTime dayDate(int day) => DateTime.utc(2026, 1, 1).add(Duration(days: day));
  int dayNumberOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026, 1, 1)).inDays;

  int daysTo(String date) {
    final p = date.split('-').map(int.parse).toList();
    return dayNumberOf(DateTime.utc(p[0], p[1], p[2])) - dayOf(now());
  }

  /// the date n days from today
  DateTime dayAfter(num n) => dayDate(dayOf(now()) + jsRound(n));
  static String isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// seconds per review / per new word, learned from your own answering speed
  ({double rev, double neu}) pace() {
    final l = allLog();
    final a = <double>[], c = <double>[];
    for (var i = l.length - 1; i >= 0 && i > l.length - 600; i--) {
      final e = l[i];
      if (quiz.contains(e.q)) {
        a.add(e.ms / 10);
      } else if (e.q.startsWith('c')) {
        c.add(e.ms / 10);
      }
    }
    double med(List<double> x) {
      jsSort(x, byNum);
      return x[x.length >> 1];
    }

    return (rev: a.length >= 15 ? cl(med(a) + 4, 5, 30) : 10.0, neu: c.length >= 10 ? cl(med(c) + 24, 18, 60) : 30.0);
  }

  /// days until every target word has been introduced (with a minutes budget the reviews take a growing share)
  int? finishDays(Json g, int nd, int remaining, double load, ({double rev, double neu}) sp) {
    if (g['pace'] != 'min') return nd > 0 ? (remaining / nd).ceil() : null;
    final perNew = sp.neu + 2.5 * sp.rev;
    var rem = remaining;
    var l = load;
    var d = 0;
    final gn = (g['n'] as num).toDouble();
    while (rem > 0 && d < 1500) {
      final n = cl(((gn * 60 - l * sp.rev) / perNew).floor(), 0, 40).toInt();
      if (n <= 0) return null;
      rem -= n;
      l += n * 0.08;
      d++;
    }
    return rem > 0 ? null : d;
  }

  /// the fewest minutes a day that still introduce every target word in time (null if even 4 hours can't)
  int? minutesFor(int remaining, double load, ({double rev, double neu}) sp, int limit) {
    int? fd(int m) => finishDays({'pace': 'min', 'n': m}, 0, remaining, load, sp);
    bool ok(int m) {
      final d = fd(m);
      return d != null && d <= limit;
    }

    if (!ok(240)) return null;
    var lo = 1, hi = 240;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (ok(m)) {
        hi = m;
      } else {
        lo = m + 1;
      }
    }
    return lo;
  }

  Plan plan([Json? g0, bool useGoal = true]) {
    final g = useGoal ? (g0 ?? goal) : g0;
    final t = now(), today = dayOf(t), r = dr(g, false), sp = pace();
    var due = 0;
    var load = 0.0;
    var introT = 0;
    final pre = isRest(today + 1) ? 1440 : 0;
    for (final e in mem.values) {
      if (rNowE(e, t + pre) < r) due++;
      load += 1 / math.max(1, fsrs.ivl(e.w[1], r));
      if (e.i != 0 && e.p == null && dayOf(e.i) == today) introT++;
    }
    var ansT = 0;
    var secT = 0.0;
    final l = allLog();
    for (var i = l.length - 1; i >= 0; i--) {
      final e = l[i];
      if (dayOf(e.t) != today) break;
      ansT++;
      secT += e.ms / 10 + 4;
    }
    final p = Plan()
      ..t = g != null ? g['t'] as String : 'none'
      ..due = due
      ..introT = introT
      ..ansT = ansT
      ..minT = jsRound(secT / 60)
      ..sp = sp;
    int? remaining;
    var need = 0;
    int? days;
    var buffer = 0;
    if (g != null && g['t'] != 'none') {
      final lo = baseLevel(), glv = (g['lv'] as num).toInt();
      final tw = glv >= lo ? data.where((d) => d.l <= glv && d.l >= lo).toList() : <Word>[];
      remaining = tw.where((d) => !mem.containsKey(d.id)).length;
      days = daysTo(g['date']);
      buffer = g['t'] == 'exam' ? math.min(7, (math.max(0, days) / 4).floor()) : math.min(3, (math.max(0, days) / 5).floor());
      need = remaining > 0 ? (remaining / math.max(1, days - buffer)).ceil() : 0;
      p.lv = glv;
      p.date = g['date'];
    }
    p.remaining = remaining;
    p.need = need;
    p.days = days;
    final perNew = sp.neu + 2.5 * sp.rev;
    int nd;
    if (g != null && g['pace'] == 'min') {
      nd = cl((((g['n'] as num) * 60 - load * sp.rev) / perNew).floor(), 0, 40).toInt();
    } else if (g != null && g['pace'] == 'new') {
      nd = (g['n'] as num).toInt();
    } else {
      nd = remaining != null ? cl(need, 3, 40).toInt() : 10;
    }
    if (remaining == 0) nd = 0;
    if (g != null && g['t'] == 'exam' && days != null && days <= 7) nd = 0;
    if (remaining != null && remaining > 0) nd = math.min(nd, remaining);
    p.newPerDay = nd;
    p.revPerDay = jsRound(load + nd * 2.5);
    p.minutes = math.max(1, jsRound((p.revPerDay * sp.rev + nd * sp.neu) / 60));
    p.needMin = remaining != null && remaining > 0 ? minutesFor(remaining, load, sp, math.max(1, days! - buffer)) : null;
    p.newToday = math.max(0, nd - introT);
    var cap = math.max(0, math.max(20, jsRound(p.revPerDay * 1.5)) - ansT);
    if (g != null && g['pace'] == 'min') {
      cap = math.max(0, (((g['n'] as num) * 60 - secT - p.newToday * sp.neu) / sp.rev).floor());
    }
    p.revToday = math.min(due, cap);
    if (g == null || g['t'] == 'none') {
      p.status = 'free';
    } else if (days! < 0) {
      p.status = 'past';
    } else if (remaining == 0) {
      p.status = 'review';
    } else if (g['t'] == 'exam' && days <= 7) {
      p.status = 'examweek';
    } else {
      final fd = finishDays(g, nd, remaining!, load, sp);
      p.finish = fd == null ? null : dayAfter(fd);
      p.status = fd != null && fd <= days - buffer ? 'ok' : 'behind';
      if (p.status == 'behind') {
        final fdays = fd == null ? (remaining / 20).ceil() + buffer : fd + buffer;
        p.fixDate = fdays > days ? dayAfter(fdays) : null;
      }
    }
    if (isRest(today)) {
      p.rest = true;
      p.newToday = 0;
      p.revToday = 0;
    }
    p.todayLeft = p.newToday * 2 + p.revToday;
    return p;
  }

  /// today's session: due reviews (most at risk first), up to three old green words to confirm, new words as cards
  List<Item> session(bool extra) {
    final p = plan(), t = now(), r = dr();
    final lo = curLevel();
    final g = goal;
    final src = tsort(
      data.where((d) => d.l >= lo && (g == null || g['t'] == 'none' || d.l <= math.max((g['lv'] as num).toInt(), lo))),
    );
    var rev = <Word>[], conf = <Word>[];
    final all = <(double, Word, Mem)>[];
    mem.forEach((id, e) {
      final d = idx[id];
      if (d != null) all.add((rNowE(e, t), d, e));
    });
    jsSort(all, (a, b) => a.$1 - b.$1);
    if (extra) {
      final td = dayOf(t);
      rev = all.where((p) => dayOf(p.$3.w[2].toInt()) != td).take(12).map((p) => p.$2).toList();
    } else {
      final pre = isRest(dayOf(t) + 1) ? 1440 : 0;
      rev = all.where((x) => rNowE(x.$3, t + pre) < r).take(p.revToday).map((x) => x.$2).toList();
      final cf = all.where((x) => x.$3.L == 1 && levelOf(x.$3) > 13 && !rev.contains(x.$2)).toList();
      jsSort(cf, (a, b) => levelOf(b.$3) - levelOf(a.$3));
      conf = cf.take(3).map((x) => x.$2).toList();
    }
    final fresh = pickNew(extra ? 5 : p.newToday, src);
    final q = <Item>[for (final d in rev) Item.q(d, pickType(d))];
    for (final d in conf) {
      final e = mem[d.id]!;
      if (e.f == null) q.add(Item.q(d, 'f'));
      if (e.s == null) q.add(Item.q(d, 's'));
    }
    final items = shuf(q);
    final out = <Item>[];
    var k = 0;
    for (final d in fresh) {
      final take = math.min(k != 0 ? 3 : 1, items.length);
      out.addAll(items.sublist(0, take));
      items.removeRange(0, take);
      out.add(Item.card(d, isNew: true));
      k++;
    }
    return [...out, ...items];
  }

  // ---------------------------------------------------------------- insights for Stats
  Json insights() {
    final t = now(), l = allLog();
    final acc = <String, int>{}, cnt = <String, int>{};
    var n7 = 0, ver = 0;
    for (var i = l.length - 1; i >= 0; i--) {
      final e = l[i];
      if (t - e.t < 7 * 1440) n7++;
      if (e.f & 1 == 0) ver++;
      final q = e.q;
      if (quiz.contains(q) && (cnt[q] ?? 0) < 150) {
        cnt[q] = (cnt[q] ?? 0) + 1;
        acc[q] = (acc[q] ?? 0) + (e.g > 1 ? 1 : 0);
      }
    }
    final skills = <String, Map<String, int>>{};
    for (final q in const ['m', 'f', 's', 'l', 'c']) {
      if ((cnt[q] ?? 0) > 0) skills[q] = {'n': cnt[q]!, 'p': jsRound((acc[q]! / cnt[q]!) * 100)};
    }
    var rs = 0.0;
    var rn = 0;
    for (final e in mem.values) {
      rs += rNowE(e, t);
      rn++;
    }
    final prs = sorted(confs().entries.where((p) => p.value >= 1), (a, b) => b.value - a.value).take(3).map((e) {
      final ab = e.key.split('|');
      return [idx[ab[0]], idx[ab[1]], e.value];
    }).toList();
    final weakL = sorted(skills.entries.where((p) => p.value['n']! >= 10), (a, b) => a.value['p']! - b.value['p']!);
    final weak = weakL.isNotEmpty ? weakL[0] : null;
    final c = calib();
    return {
      'recall': rn > 0 ? jsRound((rs / rn) * 100) : null,
      'n7': n7,
      'cal': {'n': c.n, 'acc': c.acc},
      'skills': skills,
      'weak': weak != null && weak.value['p']! < 85 ? weak.key : null,
      'pairs': prs,
      'verified': ver,
      'total': l.length,
      'spaced': fsrs.lossOf(W, seqs(), tz).n,
      'model': wMeta != null ? {'n': wMeta!['n'], 'at': wMeta!['at']} : null,
      'need': minFit,
    };
  }

  void updWeak() {
    final s = insights()['skills'] as Map<String, Map<String, int>>;
    double? a(String k) {
      final q = k == 'm' ? ['m'] : (k == 'f' ? ['f', 'c'] : ['s', 'l']);
      var n = 0;
      var p = 0.0;
      for (final x in q) {
        final v = s[x];
        if (v != null) {
          n += v['n']!;
          p += v['p']! * v['n']!;
        }
      }
      return n >= 10 ? p / n / 100 : null;
    }

    for (final k in const ['m', 'f', 's']) {
      final v = a(k);
      skillW[k] = v == null ? 0 : cl((0.9 - v) * 0.6, 0, 0.25);
    }
  }

  // ---------------------------------------------------------------- personalising the model
  static const minFit = 100;
  List<List<List<int>>> seqs() {
    final by = <String, List<List<int>>>{};
    final l = allLog();
    for (final e in l.length > 12000 ? l.sublist(l.length - 12000) : l) {
      if (e.f & 1 != 0) continue;
      final m = mem[e.id];
      if (m != null && m.L != null) continue;
      (by[e.id] ??= []).add([e.t, e.g]);
    }
    return by.values.toList();
  }

  bool _fitting = false;

  /// [runner] runs the fit (the app passes Isolate.run, so the screen stays smooth)
  Future<Json?> optimize(
    bool force, {
    Future<({List<double> w, double ll, double ll0, int n})> Function(
      ({List<double> w, double ll, double ll0, int n}) Function(),
    )?
    runner,
  }) async {
    if (_fitting) return null;
    final s = seqs();
    final base = fsrs.lossOf(fsrs.w0, s, tz);
    if (base.n < minFit && !force) return null;
    if (base.n == 0) return null;
    _fitting = true;
    try {
      final tzz = tz;
      ({List<double> w, double ll, double ll0, int n}) job() => fsrs.fitParams(s, tzz);
      final res = runner != null ? await runner(job) : job();
      ls.set('xc_fit', {'at': now(), 'len': allLog().length});
      final used = res.ll < res.ll0 - 0.002;
      if (used) {
        W = res.w.map((x) => jsRound(x * 1e4) / 1e4).toList();
        wMeta = {'w': W, 'n': res.n, 'at': now(), 'll': r3(res.ll), 'll0': r3(res.ll0)};
        ls.set('xc_w', wMeta);
      }
      return {'ll': res.ll, 'll0': res.ll0, 'n': res.n, 'used': used};
    } finally {
      _fitting = false;
    }
  }

  /// how good the memory model is for this learner: predicted vs real recall of every spaced review
  Json modelCheck() {
    final bands = [
      [0.0, 0.5],
      [0.5, 0.7],
      [0.7, 0.8],
      [0.8, 0.9],
      [0.9, 1.01],
    ].map((x) => {'a': x[0], 'b': x[1], 'n': 0, 'p': 0.0, 'y': 0}).toList();
    var n = 0;
    var pp = 0.0;
    var yy = 0;
    var ll = 0.0;
    for (final q in seqs()) {
      List<double>? st;
      for (final a in q) {
        final t = a[0], g = a[1];
        if (st != null && !sameDay(t, st[2])) {
          final p = cl(fsrs.rt((t - st[2]) / 1440, st[1]), 1e-4, 1 - 1e-4);
          final y = g > 1 ? 1 : 0;
          n++;
          pp += p;
          yy += y;
          ll -= y == 1 ? math.log(p) : math.log(1 - p);
          final b = bands.firstWhere((x) => p >= (x['a'] as double) && p < (x['b'] as double));
          b['n'] = (b['n'] as int) + 1;
          b['p'] = (b['p'] as double) + p;
          b['y'] = (b['y'] as int) + y;
        }
        st = step(st, g, t, 0);
      }
    }
    if (n == 0) return {'n': 0};
    return {
      'n': n,
      'pred': pp / n,
      'real': yy / n,
      'ece': bands.fold<double>(0, (s, b) => s + ((b['p'] as double) - (b['y'] as int)).abs()) / n,
      'll': ll / n,
      'own': wMeta != null,
      'bins': [
        for (final b in bands)
          if ((b['n'] as int) >= 10)
            {
              'a': b['a'],
              'b': math.min(1.0, b['b'] as double),
              'n': b['n'],
              'p': (b['p'] as double) / (b['n'] as int),
              'y': (b['y'] as int) / (b['n'] as int),
            },
      ],
    };
  }

  void maybeOptimize({
    Future<({List<double> w, double ll, double ll0, int n})> Function(
      ({List<double> w, double ll, double ll0, int n}) Function(),
    )?
    runner,
  }) {
    final o = ls.get('xc_fit', null);
    final l = allLog().length;
    if (o is Map && (now() - ((o['at'] as num?) ?? 0) < 1440 || l - ((o['len'] as num?) ?? 0) < 100)) return;
    optimize(false, runner: runner).catchError((_) => null);
  }

  /// the gate opened and the sealed words joined the word list: drop everything built from it
  void bandAdded() {
    _wd = null;
    _pb = null;
    _ix = null;
    _tp = null;
    _charS = null;
    _byPk = null;
  }

  // ---------------------------------------------------------------- backup, reset, history
  Map<String, Mem> exportMem() {
    flush();
    return mem;
  }

  /// extra: ids of sealed words that are not loaded yet (a code from a learner past the gate)
  Map<String, Mem>? importMem(Object? o, [Set<String>? extra]) {
    if (o is! Map) return null;
    final out = <String, Mem>{};
    o.forEach((id, v) {
      if (!idx.containsKey(id) && !(extra != null && extra.contains(id))) return;
      final c = cleanEntry(v);
      if (c != null) out['$id'] = c;
    });
    return out;
  }

  void replace(Map<String, Mem>? m, {Object? goal_ = const _Missing(), Object? w}) {
    mem = m ?? {};
    if (goal_ is! _Missing) {
      goal = validGoal(goal_) ? Map<String, dynamic>.from(goal_ as Map) : null;
      ls.set('xc_goal', goal);
    }
    if (w is List &&
        w.length == 19 &&
        [for (var i = 0; i < 19; i++) isFin(w[i]) && (w[i] as num) >= lb(i) && (w[i] as num) <= ub(i)].every((x) => x)) {
      W = w.map((x) => (x as num).toDouble()).toList();
      wMeta = {'w': W, 'n': 0, 'at': now()};
      ls.set('xc_w', wMeta);
    }
    _confMap = null;
    _charS = null;
    _last = null;
    sync();
  }

  static double lb(int i) => fsrs.lb[i];
  static double ub(int i) => fsrs.ub[i];

  void forget(String id) {
    mem.remove(id);
    _charS = null;
    _saveMem();
  }

  void clearLog() {
    logR = [];
    logA = [];
    _logCache = null;
    _confMap = null;
    _last = null;
    ls.set('xc_log', []);
    ls.set('xc_logA', []);
    W = List.of(fsrs.w0);
    wMeta = null;
    ls.remove('xc_w');
    ls.remove('xc_fit');
    days0 = [];
    ls.remove('xc_days');
    skillW = {'m': 0, 'f': 0, 's': 0};
  }

  void setGoal(Object? g) {
    goal = validGoal(g) ? Map<String, dynamic>.from(g as Map) : null;
    ls.set('xc_goal', goal);
  }

  void testsReset() {
    tests = [];
    ls.set('xc_tests', tests);
  }

  Mem? memOf(String id) => mem[id];
  bool has(String id) => mem.containsKey(id);
  double rNow(String id) => rNowE(mem[id], now());
  double? nextDue(String id) {
    final e = mem[id];
    if (e == null) return null;
    return (e.w[2] + fsrs.ivl(e.w[1], dr()) * 1440 - now()) / 1440;
  }

  List<double>? get params => wMeta != null ? W : null;
  int today() => dayOf(now());

  // ---------------------------------------------------------------- start
  void _init() {
    final o = ls.get('xc_w', null);
    if (o is Map && o['w'] is List && (o['w'] as List).length == 19 && (o['w'] as List).every(isFin)) {
      W = (o['w'] as List).map((x) => (x as num).toDouble()).toList();
      wMeta = Map<String, dynamic>.from(o);
    }
    final m = ls.get('xc_mem', null);
    final raw = m is Map ? m : const {};
    final g = ls.get('xc_goal', null);
    goal = validGoal(g) ? Map<String, dynamic>.from(g as Map) : null;
    final lr = ls.get('xc_log', []), la = ls.get('xc_logA', []);
    logR = lr is List ? lr.map(LogE.fromJson).whereType<LogE>().toList() : [];
    logA = la is List ? la.map(LogE.fromJson).whereType<LogE>().toList() : [];
    mem = {};
    raw.forEach((id, e) {
      final c = idx.containsKey(id) ? cleanEntry(e) : null;
      if (c != null) mem['$id'] = c;
    });
    final a = ls.get('xc_amb', []);
    amb = a is List ? a.map((x) => '$x').toSet() : {};
    _loadStats();
    final mk = ls.get('xc_mock', []);
    mocks = mk is List ? mk.whereType<List<dynamic>>().toList() : [];
    final li = ls.get('xc_lvl', null);
    lvInfo = li is Map && li['lv'] is num && li['lv'] >= 1 && li['lv'] <= 9 ? Map<String, dynamic>.from(li) : null;
    if (lvInfo != null && realm() == 7 && lvInfo!['src'] == 'bt' && !_truthy(lvInfo!['gate'])) {
      lvInfo!['gate'] = now();
      ls.set('xc_lvl', lvInfo);
    }
    final ts = ls.get('xc_tests', []);
    tests = ts is List ? ts.whereType<num>().map((x) => x.toInt()).toList() : [];
    if (tests.isEmpty && lvInfo != null && lvInfo!['src'] == 'test' && isFin(lvInfo!['at'])) {
      tests = [(lvInfo!['at'] as num).toInt()];
    }
    final rs = ls.get('xc_rest', []);
    final rl = rs is List ? rs.where((x) => isInt(x) && (x as num) >= 0 && x <= 6).map((x) => (x as num).toInt()).toList() : <int>[];
    rest = rl.length > 2 ? rl.sublist(0, 2) : rl;
    final ds = ls.get('xc_days', []);
    days0 = ds is List ? ds.where(isInt).map((x) => (x as num).toInt()).toList() : [];
    final gm = ls.get('xc_game', {});
    game = gm is Map ? Map<String, dynamic>.from(gm) : {};
    sync();
    updWeak();
  }
}

class _Missing {
  const _Missing();
}

/// typed pinyin in decomposed form (a vowel followed by a combining tone mark) → the composed letters (JS NFC)
String composePinyin(String s) {
  if (!s.runes.any((r) => r >= 0x300 && r <= 0x36F)) return s;
  const comb = {0x304: 0, 0x301: 1, 0x30C: 2, 0x300: 3};
  const vow = {
    'a': 'āáǎà', 'e': 'ēéěè', 'i': 'īíǐì', 'o': 'ōóǒò', 'u': 'ūúǔù', 'ü': 'ǖǘǚǜ', //
    'A': 'ĀÁǍÀ', 'E': 'ĒÉĚÈ', 'I': 'ĪÍǏÌ', 'O': 'ŌÓǑÒ', 'U': 'ŪÚǓÙ', 'Ü': 'ǕǗǙǛ',
  };
  final out = <String>[];
  for (final r in s.runes) {
    if (r == 0x308 && out.isNotEmpty && (out.last == 'u' || out.last == 'U')) {
      out[out.length - 1] = out.last == 'u' ? 'ü' : 'Ü';
      continue;
    }
    final c = comb[r];
    if (c != null && out.isNotEmpty && vow.containsKey(out.last)) {
      out[out.length - 1] = vow[out.last]![c];
      continue;
    }
    out.add(String.fromCharCode(r));
  }
  return out.join();
}
