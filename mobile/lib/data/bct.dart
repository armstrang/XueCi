/// The BCT-style practice bank (assets/data/bct.json, made by content/tools/bct_build.py from content/bct/*.txt):
/// work sentences with a gap, three wrong words for it, pinyin, the pieces for sentence building and four
/// translations. Used only by the BCT practice papers; nothing here is a learned word, so the answers never touch
/// the learner's memory states.
library;

import 'dart:convert';
import 'package:flutter/services.dart';

import 'words.dart';

/// the "levels" the BCT papers use in the history (xc_mock) and in [Word.l]
const bctA = 101, bctB = 102;

int bctLevel(String book) => book == 'b' ? bctB : bctA;
String bctBook(int l) => l == bctB ? 'b' : 'a';
bool isBct(int l) => l >= 100;

class BctS {
  final String id, z, g, s;
  final List<String> d; // the three wrong words
  final String? zp;
  final List<String>? w; // pieces for sentence building (null: too short to build)
  final Map<String, String> t;
  late final Word word;
  late final List<Word> wrong;

  BctS(int lv, {required this.id, required this.z, required this.g, required this.s, required this.d, this.zp, this.w, required this.t}) {
    Word mk(String h, String zz, String? zzp) => Word(l: lv, n: 0, u: 1, h: h, p: '', s: const [], z: zz, zp: zzp);
    word = mk(g, z, zp)..t.addAll(t);
    wrong = [for (final x in d) mk(x, '', null)];
  }
}

/// a business word of the BCT B list (assets/data/bct_words.json): hanzi, pinyin, topic, four meanings
class BctW {
  final String h, p, s;
  final String b; // the book it belongs to: 'a' or 'b'
  final Map<String, String> t;
  const BctW(this.h, this.p, this.s, this.t, [this.b = 'b']);
}

class BctBank {
  final Map<String, List<BctS>> by;
  final List<BctW> words;
  BctBank(this.by, [this.words = const []]);

  List<BctS> of(String book) => by[book] ?? const [];
  List<BctW> wordsOf(String book) => [for (final w in words) if (w.b == book) w];

  static Future<BctBank> load(AssetBundle b) async {
    final raw = json.decode(await b.loadString('assets/data/bct.json')) as Map;
    final out = <String, List<BctS>>{};
    raw.forEach((k, v) {
      final lv = bctLevel(k as String);
      out[k] = [
        for (final r in v as List)
          BctS(
            lv,
            id: r['id'] as String,
            z: r['z'] as String,
            g: r['g'] as String,
            s: (r['s'] as String?) ?? '',
            d: (r['d'] as List).cast<String>(),
            zp: r['zp'] as String?,
            w: (r['w'] as List?)?.cast<String>(),
            t: (r['t'] as Map).cast<String, String>(),
          ),
      ];
    });
    var words = <BctW>[];
    try {
      final w = json.decode(await b.loadString('assets/data/bct_words.json')) as List;
      words = [for (final r in w) BctW(r['h'] as String, r['p'] as String, (r['s'] as String?) ?? '', (r['t'] as Map).cast<String, String>(), (r['b'] as String?) ?? 'b')];
    } catch (_) {}
    return BctBank(out, words);
  }
}
