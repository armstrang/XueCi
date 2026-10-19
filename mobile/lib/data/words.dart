/// The word list: HSK 1–6 from assets/data/core.json + the meanings of each study language (`assets/data/<lang>.json`),
/// the levels past the gate from the sealed part once it opens (seal.dart). Same fields as web/data/vocab.json.
library;

import 'dart:math' as math;

import 'pinyin.dart';

const langs = ['id', 'en', 'th', 'vi'];

class Word {
  final int l; // HSK level
  final int n; // number inside the level
  final int u; // unit
  final String h; // hanzi
  final String p; // pinyin
  final List<String> s; // pinyin per character
  final String z; // example sentence
  final String? zp; // its pinyin, the learned word in {braces}
  final double? f; // Zipf frequency
  final String? g; // part of speech (jieba)
  final int pm; // short first meaning: usable in the placement test
  final String id;
  final String pk; // plain pinyin
  final Map<String, String> m = {}; // meaning per study language
  final Map<String, String> t = {}; // sentence translation per study language
  String key = ''; // search key

  Word({
    required this.l,
    required this.n,
    required this.u,
    required this.h,
    required this.p,
    required this.s,
    required this.z,
    this.zp,
    this.f,
    this.g,
    this.pm = 0,
  }) : id = '$l:$h',
       pk = plain(p);

  /// one row of core.json: the columns are named in cols
  factory Word.row(List<String> cols, List<dynamic> r) {
    Object? v(String k) {
      final i = cols.indexOf(k);
      return i < 0 || i >= r.length ? null : r[i];
    }

    return Word(
      l: (v('l') as num).toInt(),
      n: (v('n') as num?)?.toInt() ?? 0,
      u: (v('u') as num?)?.toInt() ?? 1,
      h: v('h') as String,
      p: v('p') as String,
      s: (v('s') as List).cast<String>(),
      z: (v('z') as String?) ?? '',
      zp: v('zp') as String?,
      f: (v('f') as num?)?.toDouble(),
      g: v('g') as String?,
      pm: (v('pm') as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => id;
}

class Vocab {
  final List<Word> data = [];
  final Map<String, Word> idx = {};
  final Map<int, List<Word>> by = {};
  final Map<int, int> units = {};
  final List<int> levels = [];
  String lang;
  bool band = false; // the sealed words are loaded (the gate is open)
  final Set<String> loaded = {}; // study languages whose meanings are loaded

  Vocab(List<Word> words, {this.lang = 'id'}) {
    add(words);
  }

  void add(List<Word> words) {
    for (final d in words) {
      data.add(d);
      idx[d.id] = d;
    }
    final ls = data.map((d) => d.l).toSet().toList()..sort();
    for (final l in ls) {
      if (!levels.contains(l)) levels.add(l);
      by[l] = data.where((d) => d.l == l).toList();
      units[l] = by[l]!.map((d) => d.u).fold(0, math.max);
    }
    buildKeys();
  }

  String mOf(Word d) => d.m[lang] ?? d.m['id'] ?? '';
  String trOf(Word d) => d.t[lang] ?? d.t['id'] ?? '';
  String m1(Word d) => mOf(d).split(';')[0].trim();

  void buildKeys() {
    for (final d in data) {
      final m = mOf(d).toLowerCase();
      d.key = '${d.h} ${d.pk} $m${lang == 'vi' ? ' ${unmark(m)}' : ''}';
    }
  }

  void setLang(String l) {
    lang = l;
    buildKeys();
  }
}
