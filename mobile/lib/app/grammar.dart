/// The grammar book (v1.6, Josh: a page and practice for the grammar of every level, in step with the tests).
/// The points follow the official HSK 3.0 grammar syllabus (content/grammar, made into assets/data/grammar.json by
/// tool/make_grammar.py); the advanced band's points are sealed in s0.bin and join when the gate opens.
/// Each point: a formula, one line of explanation per language, examples (sentences of the words that show the
/// point, or its own), and sentences to practise on. Progress per point is an FSRS state like a word's, kept in
/// `xc_gram` {id: [d, s, t, n, right]}; a point is "held" once its stability reaches 10 days after 3+ answers.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle;

import '../data/store.dart';
import '../data/words.dart';
import '../engine/fsrs.dart' as fsrs;
import '../engine/js.dart';
import '../engine/learn.dart';
import '../engine/model.dart';

/// categories, in the order the page shows them (v1.6.1: the everyday ones first)
const gramCats = ['S', 'U', 'P', 'N', 'A', 'R', 'C', 'V', 'K', 'F', 'W', 'E'];

/// the books (v1.8, Josh: one button each): HSK 3.0 (the points' own level), HSK 2.0, BCT (A, B), YCT; a point of
/// several books shows in each, with its level there
const gramBooks = ['h3', 'h2', 'bct', 'yct'];

/// a book's level as people say it: HSK 2.0 levels are HSK n, BCT A/B, YCT n
String gramBookLv(String b, int l) => switch (b) {
  'bct' => 'BCT ${l == 1 ? 'A' : 'B'}',
  'yct' => 'YCT $l',
  _ => l >= 7 ? 'HSK $l–${l + 2}' : 'HSK $l',
};

/// a book's name on its button
String gramBookName(String b) => const {'h3': 'HSK 3.0', 'h2': 'HSK 2.0', 'bct': 'BCT', 'yct': 'YCT'}[b] ?? b;

Map<String, String>? _m(Object? o) => o is Map ? o.map((k, v) => MapEntry('$k', '$v')) : null;

/// one part of a formula: the grammar word itself (key) or a slot (主语, 名词, A) with its meaning
class GPart {
  final String t, py;
  final Map<String, String>? g;
  final bool key;
  GPart(this.t, this.py, this.g, this.key);
}

/// one word of an example: hanzi, pinyin, the formula part it fills (0: none) and its meaning
class GTok {
  final String h, py;
  final int slot;
  final Map<String, String>? g;
  GTok(this.h, this.py, this.slot, this.g);
  bool get punct => py.isEmpty && g == null;
}

/// an example written word by word
class GEx {
  final String z, py;
  final Map<String, String> tr;
  final List<GTok> w;
  String c = ''; // v1.8: where it lives: d everyday, s study, w work, y children
  GEx(this.z, this.py, this.tr, this.w);
}

class GOwn {
  final String zh, py;
  final Map<String, String> tr;
  GOwn(this.zh, this.py, this.tr);
}

class GPoint {
  final String id, cat, zh, formula;
  final int l;
  final List<String> keys;
  final RegExp? m;
  final Map<String, String> x;
  final List<Word> ex, pool;
  final List<GOwn> own;
  GPoint(this.id, this.l, this.cat, this.zh, this.formula, this.keys, this.m, this.x, this.ex, this.pool, this.own);

  // v1.6.1 (Josh: "as if everyone were a native speaker"): a name in the learner's language, the formula part by
  // part with meanings, a warning about the usual mistake, examples word by word
  Map<String, String> n = const {};
  String npy = '';
  int t = 10; // the learning stage (1 sentence basics … 10 tone and expressions): the list's order
  Map<String, int> v = const {}; // the other books and the point's level there (h2, bct, yct)
  bool nh = false; // only in other books, not in the HSK 3.0 one
  int ord = 0; // place in the book's files

  /// the point's level in a book (null: not in it)
  int? lvIn(String b) => b == 'h3' ? (nh ? null : l) : v[b];
  List<GPart> parts = const [];
  List<String> seps = const [];
  Map<String, String>? warn;
  Map<String, String>? use; // when and how to use it
  List<GEx> eg = const [];

  String text(String lang) => x[lang] ?? x['en'] ?? '';
  String title(String lang) => n[lang] ?? n['en'] ?? zh;

  /// the examples in a book's order (v1.8): BCT shows work sentences only, children's and study first in YCT, else as written
  List<GEx> egFor(String book) {
    const first = {'bct': 'w', 'yct': 'y'};
    final f = first[book];
    if (f == null) return eg;
    // BCT shows work sentences only (a point without any keeps what it has)
    if (book == 'bct') {
      final w = eg.where((e) => e.c == 'w').toList();
      return w.isEmpty ? eg : w;
    }
    final out = [...eg.where((e) => e.c == f), ...eg.where((e) => e.c != f)];
    return out;
  }
  bool get practisable => pool.isNotEmpty || own.isNotEmpty;

  /// the sentence shows this point
  bool fits(String z) {
    if (keys.isEmpty && m == null) return false;
    if (keys.isNotEmpty && !keys.any(z.contains)) return false;
    return m == null || m!.hasMatch(z);
  }

  /// the key found in a sentence (the gap), longest first so 没有 wins over 没
  String? keyIn(String z) {
    final ks = [...keys]..sort((a, b) => b.length - a.length);
    for (final k in ks) {
      if (z.contains(k)) return k;
    }
    return null;
  }
}

class GBook {
  final List<GPoint> pts = [];
  final Map<String, GPoint> byId = {};

  /// the HSK 3.0 book's points of a level (the tests and the engine use these)
  List<GPoint> level(int l) => pts.where((p) => p.l == l && !p.nh).toList();
  List<int> get levels => (pts.where((p) => !p.nh).map((p) => p.l).toSet().toList()..sort());

  /// a book's points of a level, in learning order (stage, then the book's own order)
  List<GPoint> inBook(String b, int l) {
    final out = pts.where((p) => p.lvIn(b) == l).toList();
    jsSort(out, (a, c) => a.t != c.t ? a.t - c.t : a.ord - c.ord);
    return out;
  }

  /// the levels a book has
  List<int> levelsOf(String b) => b == 'h3' ? levels : (pts.map((p) => p.v[b]).whereType<int>().toSet().toList()..sort());

  void _add(List raw, Vocab v) {
    for (final o in raw.cast<Map>()) {
      Word? w(Object? id) => v.idx[id as String];
      final p = GPoint(
        o['id'] as String,
        (o['l'] as num).toInt(),
        o['c'] as String,
        o['zh'] as String,
        o['f'] as String,
        (o['k'] as List).cast<String>(),
        o['m'] == null ? null : RegExp(o['m'] as String),
        (o['x'] as Map).cast<String, String>(),
        [for (final id in o['ex'] as List) ?w(id)],
        [for (final id in o['pool'] as List) ?w(id)],
        [
          for (final e in (o['own'] as List?) ?? const [])
            GOwn((e as List)[0] as String, e[1] as String, {'id': e[2] as String, 'en': e[3] as String, 'th': e[4] as String, 'vi': e[5] as String}),
        ],
      );
      final nm = _m(o['n']);
      if (nm != null) {
        p.npy = nm.remove('py') ?? '';
        p.n = nm;
      }
      p.parts = [for (final q in (o['fp'] as List?) ?? const []) GPart('${(q as Map)['t']}', '${q['py'] ?? ''}', _m(q['g']), q['k'] == true)];
      p.seps = ((o['fx'] as List?) ?? const []).cast<String>();
      p.warn = _m(o['w']);
      p.use = _m(o['u']);
      p.t = (o['t'] as num?)?.toInt() ?? 10;
      p.v = {for (final e in ((o['v'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()};
      p.nh = o['nh'] == 1;
      p.eg = [
        for (final e in (o['eg'] as List?) ?? const [])
          GEx('${(e as Map)['z']}', '${e['py']}', _m(e['tr']) ?? const {}, [
            for (final w in e['w'] as List) GTok('${(w as List)[0]}', '${w[1]}', (w[2] as num).toInt(), _m(w[3])),
          ])..c = '${e['c'] ?? ''}',
      ];
      if (byId.containsKey(p.id)) continue;
      p.ord = pts.length;
      pts.add(p);
      byId[p.id] = p;
    }
  }

  static Future<GBook> load(AssetBundle bundle, Vocab v) async {
    final b = GBook();
    b._add((json.decode(await bundle.loadString('assets/data/grammar.json')) as Map)['pts'] as List, v);
    return b;
  }

  /// the gate opened: the advanced band's points (from the sealed part) join
  void addBand(List? raw, Vocab v) {
    if (raw != null) _add(raw, v);
  }

  /// the points a sentence shows, of one level
  List<GPoint> pointsIn(String z, int l) => [
    for (final p in level(l))
      if (p.fits(z)) p,
  ];
}

/// progress per point (xc_gram)
class GProg {
  final Store ls;
  final LM lm;
  Map<String, List<num>> j = {};
  int now() => lm.now();
  GProg(this.ls, this.lm) {
    final o = ls.get('xc_gram', null);
    if (o is Map) {
      o.forEach((k, v) {
        if (k is String && v is List && v.length == 5 && v.every((x) => x is num && x.isFinite)) j[k] = v.cast<num>();
      });
    }
  }

  void answer(String id, bool ok) {
    final t = now();
    final cur = j[id];
    final st = cur == null ? null : [cur[0].toDouble(), cur[1].toDouble(), cur[2].toDouble()];
    final s = lm.step(st, ok ? 3 : 1, t);
    j[id] = [s[0], s[1], s[2], (cur?[3] ?? 0) + 1, (cur?[4] ?? 0) + (ok ? 1 : 0)];
    ls.set('xc_gram', j);
  }

  int n(String id) => (j[id]?[3] ?? 0).toInt();
  double stab(String id) => (j[id]?[1] ?? 0).toDouble();

  /// recall now, 0 for a point never practised
  double recall(String id) {
    final v = j[id];
    if (v == null) return 0;
    return fsrs.rt((now() - v[2]) / 1440, v[1].toDouble());
  }

  /// 0–20 like a word's level
  int level(String id) {
    final s = stab(id);
    return s <= 0 ? 0 : math.min(20, jsRound(20 * math.log(1 + s) / math.log(121)));
  }

  bool held(String id) => n(id) >= 3 && stab(id) >= 10;
  bool due(String id) => j.containsKey(id) && recall(id) < 0.85;

  /// restore from a backup code: entries checked like the store's own
  void restore(Object? o) {
    if (o is! Map) return;
    final out = <String, List<num>>{};
    o.forEach((k, v) {
      if (k is String && v is List && v.length == 5 && v.every((x) => x is num && x.isFinite)) out[k] = v.cast<num>();
    });
    j = out;
    ls.set('xc_gram', j);
  }
}

/// one practice question: fill the gap with the grammar word, or put the sentence's pieces in order
class GItem {
  final GPoint p;
  final String kind; // 'gap' or 'order'
  final Word d; // the sentence (a word's, or a stand-in for an own example)
  final List<String> opts; // gap: the choices; order: the pieces, shuffled
  final int ans; // gap: the right choice
  final String gapText; // the sentence with ＿＿ where the grammar word was
  final List<String> right; // order: the pieces in the right order
  int? pick;
  bool? ok;
  GItem(this.p, this.kind, this.d, this.opts, this.ans, this.gapText, this.right);

  /// the order question as a run item (the order pad works on one)
  late final Item item = Item.q(d, 'wo')..apply(QMat(parts: opts));
}

/// a stand-in word for a point's own example (so it shows and splits like a word's sentence)
Word gOwnWord(GPoint p, GOwn e) {
  final k = p.keyIn(e.zh) ?? (e.zh.isNotEmpty ? e.zh.substring(0, 1) : '');
  final w = Word(l: p.l, n: 0, u: 0, h: k, p: '', s: const [], z: e.zh, zp: e.py);
  w.t.addAll(e.tr);
  return w;
}

class GPractice {
  final LM lm;
  final GBook book;
  GPractice(this.lm, this.book);

  /// the sentences a point can use: its pool, then its own examples
  List<Word> sentences(GPoint p) => [...p.pool, for (final e in p.own) gOwnWord(p, e)];

  /// a gap: the point's word blanked, three other grammar words of the level (same kind first) as distractors
  GItem? gap(GPoint p, Word d) {
    final k = p.keyIn(d.z);
    if (k == null) return null;
    final others = <String>[];
    void take(Iterable<GPoint> src) {
      for (final q in lm.shuf(src.toList())) {
        if (q.id == p.id) continue;
        for (final x in lm.shuf(q.keys)) {
          if (others.length >= 3) return;
          if (x == k || others.contains(x) || p.keys.contains(x) || x.length != k.length && others.length < 2 && k.length > 1) continue;
          // a distractor that also makes the sentence read the same way is no distractor
          if (d.z.replaceFirst(k, x) == d.z) continue;
          others.add(x);
        }
      }
    }

    final lv = book.level(p.l);
    take(lv.where((q) => q.cat == p.cat));
    take(lv);
    take(book.pts.where((q) => (q.l - p.l).abs() <= 1));
    if (others.length < 3) return null;
    final opts = lm.shuf([k, ...others]);
    return GItem(p, 'gap', d, opts, opts.indexOf(k), d.z.replaceFirst(k, '＿＿'), const []);
  }

  /// an order question: the sentence cut into pieces
  GItem? order(GPoint p, Word d) {
    final pc = lm.pieces(d, d.l <= 3 ? 4 : (d.l == 4 ? 5 : 6), commas: true);
    if (pc == null || pc.length < 3) return null;
    var sh = lm.shuf(pc);
    for (var i = 0; i < 6 && sh.join() == pc.join(); i++) {
      sh = lm.shuf(pc);
    }
    return GItem(p, 'order', d, sh, -1, d.z, pc);
  }

  /// a run of [n] questions on one point, gaps and order mixed
  List<GItem> run(GPoint p, {int n = 8}) {
    final src = _fresh(p);
    final out = <GItem>[];
    final second = <GItem>[];
    var i = 0;
    for (final d in src) {
      if (out.length >= n) break;
      final g = gap(p, d), o = order(p, d);
      final it = i.isEven ? (g ?? o) : (o ?? g);
      if (it != null) {
        _used(d);
        out.add(it);
        i++;
        // few sentences (the low levels have few that show a point): the same sentence the other way, later
        final other = identical(it, g) ? o : g;
        if (other != null) second.add(other);
      }
    }
    for (final it in second) {
      if (out.length >= math.min(n, 6)) break;
      out.add(it);
    }
    return out;
  }

  /// sentences used lately (mixed practice and point runs prefer others), the last 80
  final List<String> _recent = [];
  void _used(Word d) {
    _recent.remove(d.z);
    _recent.add(d.z);
    if (_recent.length > 80) _recent.removeAt(0);
  }

  /// a point's sentences, fresh ones first (shuffled), the ones used lately last
  List<Word> _fresh(GPoint p) {
    final ss = lm.shuf(sentences(p));
    return [...ss.where((d) => !_recent.contains(d.z)), ...ss.where((d) => _recent.contains(d.z))];
  }

  /// mixed practice over a book's level (v1.8, Josh: "always the same questions"): mostly points that are fading,
  /// some never practised (in learning order), one or two strong ones, drawn at random; one question per point,
  /// sentences not used lately first, gaps and order mixed, then shuffled
  List<GItem> review(String book, int l, GProg prog, {int n = 10}) {
    final pts = this.book.inBook(book, l).where((p) => p.practisable).toList();
    final weak = pts.where((p) => prog.j.containsKey(p.id) && !prog.held(p.id) || prog.due(p.id)).toList();
    jsSort(weak, (a, b) => prog.recall(a.id) - prog.recall(b.id));
    final fresh = pts.where((p) => !prog.j.containsKey(p.id)).toList();
    final strong = pts.where((p) => !weak.contains(p) && !fresh.contains(p)).toList();
    final pick = <GPoint>[];
    void take(List<GPoint> src, int k) {
      for (final p in src) {
        if (k <= 0 || pick.length >= n) return;
        if (pick.contains(p)) continue;
        pick.add(p);
        k--;
      }
    }

    take(lm.shuf(weak.take(12).toList()), (n * .6).round());
    take(lm.shuf(fresh.take(6).toList()), (n * .3).round());
    take(lm.shuf(strong), 2);
    take(lm.shuf(pts), n); // a level with few points of one kind: fill from all
    final out = <GItem>[];
    for (final p in pick) {
      for (final d in _fresh(p)) {
        final it = lm.R() < .5 ? (gap(p, d) ?? order(p, d)) : (order(p, d) ?? gap(p, d));
        if (it != null) {
          _used(d);
          out.add(it);
          break;
        }
      }
    }
    return lm.shuf(out);
  }
}

/// the order of an item's answer: right only when the whole order is right
bool gOrderOk(GItem it, List<String> o) => o.join() == it.right.join();

/// the grammar points of a test's level first: sentences that show one come first (placement, tribulation, mock)
List<Word> gramFirst(GBook? book, List<Word> pool, int l) {
  if (book == null || pool.isEmpty) return pool;
  final pts = book.level(l);
  if (pts.isEmpty) return pool;
  final yes = <Word>[], no = <Word>[];
  for (final d in pool) {
    (pts.any((p) => p.fits(d.z)) ? yes : no).add(d);
  }
  return [...yes, ...no];
}
