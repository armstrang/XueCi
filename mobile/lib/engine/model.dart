/// The engine's records: a word's memory states (xc_mem), the answer log (xc_log/xc_logA) and the items of a run.
library;

import '../data/words.dart';
import 'js.dart';

/// xc_mem entry: {w:[d,s,t], m|f|s:[d,s,t,lastGrade,timesRight], i:firstSeen, L:1 legacy unconfirmed|2 confirmed,
/// p:1 first seen in exam practice, k: first time solid}
class Mem {
  List<double> w; // empty only while a first answer is being recorded
  int i;
  int? L;
  int? p;
  int? k;
  List<double>? m, f, s;

  Mem({List<double>? w, required this.i, this.L, this.p, this.k, this.m, this.f, this.s}) : w = w ?? [];

  List<double>? sk(String key) => key == 'm' ? m : (key == 'f' ? f : (key == 's' ? s : null));
  void setSk(String key, List<double> v) {
    if (key == 'm') {
      m = v;
    } else if (key == 'f') {
      f = v;
    } else if (key == 's') {
      s = v;
    }
  }

  Mem clone() => Mem(
    w: List.of(w),
    i: i,
    L: L,
    p: p,
    k: k,
    m: m == null ? null : List.of(m!),
    f: f == null ? null : List.of(f!),
    s: s == null ? null : List.of(s!),
  );

  Map<String, Object?> toJson() => {
    'w': w,
    'i': i,
    'm': ?m,
    'f': ?f,
    's': ?s,
    'L': ?L,
    'p': ?p,
    'k': ?k,
  };
}

/// one answer: [t, id, type, grade 1–4, tenths of a second, wrong pick id|0, flags]
/// flags: 1 unchecked claim, 2 said "I know", 4 sure but wrong, 8 exam practice or breakthrough, 16 placement test,
/// 32 translation shown before answering
class LogE {
  final int t;
  final String id;
  final String q;
  final int g;
  final int ms;
  final String? x;
  final int f;
  const LogE(this.t, this.id, this.q, this.g, this.ms, this.x, this.f);

  static LogE? fromJson(Object? a) {
    if (a is! List || a.length < 5) return null;
    final t = a[0], id = a[1], q = a[2];
    if (t is! num || id is! String || q is! String) return null;
    final x = a.length > 5 ? a[5] : null;
    return LogE(
      t.toInt(),
      id,
      q,
      i32(a[3]),
      i32(a[4]),
      x is String && x.isNotEmpty ? x : null,
      a.length > 6 ? i32(a[6]) : 0,
    );
  }

  List<Object> toJson() => [t, id, q, g, ms, x ?? 0, f];
}

/// the material of one question: options (words, or tone variants of the pinyin) and the right one
class QMat {
  final List<Word>? words;
  final List<List<String>>? tones;
  final int ans;
  final bool typed;
  const QMat({this.words, this.tones, this.ans = -1, this.typed = false});
}

/// One step of a run (Cards, Quiz, today's session, a test). The engine fills in what it chooses; the screens keep
/// their own state of the item in the fields after the divider.
class Item {
  final String k; // 'card' or 'q'
  final Word d;
  String? q; // m f s l c p t (cm cs for card checks)
  bool isNew;
  String? part; // HSK simulation part: listen / read / write
  String? strike; // tribulation strike
  int? limit; // seconds (timed strike)
  int? l; // level the question tests (placement, tribulation)
  List<Word>? words;
  List<List<String>>? tones;
  int ans = -1;
  bool typed = false;
  String? r; // test answer: ok / ng / idk
  bool? ok;

  // ---- screen state ----
  String? st; // card: front / check / back
  String? res; // card result
  bool done = false;
  bool hint = false;
  int? pick;
  int t0 = 0;
  int ms = 0;
  String? typedText;
  Object? extra;
  QMat? check; // card quick check
  String? checkQ;
  bool again = false;
  bool heard = false;
  bool timedOut = false;
  Object? alt;

  Item.card(this.d, {this.isNew = false}) : k = 'card';
  Item.q(this.d, String this.q, {this.part, this.strike, this.l, this.limit}) : k = 'q', isNew = false;

  void apply(QMat m) {
    words = m.words;
    tones = m.tones;
    ans = m.ans;
    typed = m.typed;
  }

  /// a fresh copy for asking the same word again later in the run
  Item copy() {
    final c = k == 'card' ? Item.card(d, isNew: isNew) : Item.q(d, q!, part: part, strike: strike, l: l, limit: limit);
    c.again = true;
    return c;
  }
}
