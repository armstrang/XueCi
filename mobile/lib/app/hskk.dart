/// HSKK, speaking practice and mock tests (v1.4): the bank (assets/data/speak.json, made by tool/make_speak.py from
/// content/speak/), the levels, the limits, how an answer is marked and what is kept (xc_spk).
///
/// Three levels, each following the HSK 3.0 speaking paper of its band: Dasar (HSK 3: repeat sentences, a text
/// read aloud, two questions), Menengah (HSK 4) and Lanjutan (HSK 5–6) (retell two texts heard, a text read aloud,
/// two questions). The paper's picture part is replaced by reading aloud (Josh). The phone's recognizer hears the
/// learner; a repeat can also be checked for tones (tone.dart). Marks are a guide, never an examiner's.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../data/words.dart';
import 'speech.dart';

/// the levels: 1 Dasar, 2 Menengah, 3 Lanjutan
const hkLevels = [1, 2, 3];

/// the parts of each level, in the paper's order
List<String> hkKinds(int lv) => lv == 1 ? const ['r', 't', 'q'] : const ['s', 't', 'q'];

/// the mock test: how many of each part
List<(String, int)> hkPaper(int lv) => lv == 1 ? const [('r', 8), ('t', 1), ('q', 2)] : const [('s', 2), ('t', 1), ('q', 2)];

/// the HSK band each level follows (what the learner's realm opens)
String hkBand(int lv) => const ['', 'HSK 3', 'HSK 4', 'HSK 5–6'][lv];

/// a learner at HSK 1–3 opens Dasar; HSK 4 adds Menengah; HSK 5 and up, Lanjutan
int hkOpen(int hskLevel) => hskLevel <= 3 ? 1 : (hskLevel == 4 ? 2 : 3);

/// seconds to answer one item (a text read aloud: by its length, about 1.6 characters a second plus a margin)
int hkAnswerSec(String k, int lv, {int chars = 0}) => switch (k) {
  'r' => 15,
  's' => lv == 2 ? 45 : 90,
  't' => math.max(45, (chars / 1.6).round() + 20),
  _ => const [0, 90, 120, 150][lv],
};

/// seconds to get ready before answering a question (the paper's); a retell plays its text first instead
int hkPrepSec(String k, int lv) => k == 'q' ? (lv == 1 ? 180 : 210) : (k == 't' ? 30 : 0);

/// one item of the bank
class SpkItem {
  final int lv;
  final String k; // r repeat, s retell, t read aloud, q question, x extra repeat practice
  final int i;
  final String zh;
  final String py;
  final List<String> kw;
  final Map<String, String> tr; // the question in each study language (sentences from the word list: their own)
  final Word? w;
  const SpkItem(this.lv, this.k, this.i, this.zh, this.py, this.kw, this.tr, this.w);
  String get id => '$lv$k$i';
  int get chars => zh.runes.map(String.fromCharCode).where(isHan).length;
  String trIn(String lang) => w != null ? (w!.t[lang] ?? w!.t['id'] ?? '') : (tr[lang] ?? tr['en'] ?? '');
}

class SpkBank {
  final Map<int, Map<String, List<SpkItem>>> by;
  SpkBank(this.by);

  List<SpkItem> of(int lv, String k) => by[lv]?[k] ?? const [];

  static Future<SpkBank> load(AssetBundle bundle, Vocab v) async =>
      parse(json.decode(await bundle.loadString('assets/data/speak.json')) as Map, v);

  static SpkBank parse(Map j, Vocab v) {
    final out = <int, Map<String, List<SpkItem>>>{};
    final L = j['L'] as List;
    for (var li = 0; li < L.length; li++) {
      final lv = li + 1;
      final m = <String, List<SpkItem>>{};
      (L[li] as Map).forEach((k, items) {
        final list = <SpkItem>[];
        for (final raw in items as List) {
          final o = raw as Map;
          final i = list.length;
          if (o['w'] != null) {
            final w = v.idx[o['w']];
            if (w == null || w.z.isEmpty) continue;
            final py = (w.zp ?? '').replaceAll(RegExp(r'[{}]'), '');
            list.add(SpkItem(lv, k as String, i, w.z, py, const [], const {}, w));
          } else {
            list.add(SpkItem(
              lv,
              k as String,
              i,
              o['zh'] as String,
              (o['py'] as String?) ?? '',
              [for (final x in (o['kw'] as List?) ?? const []) '$x'],
              {for (final e in ((o['tr'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
              null,
            ));
          }
        }
        m[k as String] = list;
      });
      out[lv] = m;
    }
    return SpkBank(out);
  }
}

/// the written tone of each hanzi of [zh], from its pinyin (1–4, 5 neutral); null when they don't line up
List<int>? hanTones(String zh, String py) {
  final words = py.split(RegExp(r"[\s,.?!:;\u0022…—()'-]+")).where((w) => w.isNotEmpty);
  final syls = [for (final w in words) ..._splitWord(w)];
  final han = zh.runes.map(String.fromCharCode).where(isHan).length;
  if (syls.length != han) return null;
  return [for (final s in syls) _toneOf(s)];
}

int _toneOf(String s) {
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if ('āēīōūǖĀĒĪŌŪ'.contains(c)) return 1;
    if ('áéíóúǘÁÉÍÓÚ'.contains(c)) return 2;
    if ('ǎěǐǒǔǚǍĚǏǑǓ'.contains(c)) return 3;
    if ('àèìòùǜÀÈÌÒÙ'.contains(c)) return 4;
  }
  return 5;
}

const _vowels = 'aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜAEIOUĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙ';
const _initials = [
  'zh', 'ch', 'sh', 'b', 'p', 'm', 'f', 'd', 't', 'n', 'l', 'g', 'k', 'h', 'j', 'q', 'x', 'r', 'z', 'c', 's', 'y', 'w', //
];

/// a written pinyin word cut into syllables (xuéxiào → xué xiào, Xī'ān)
List<String> _splitWord(String w) {
  final s = w.toLowerCase();
  final out = <String>[];
  var i = 0;
  while (i < s.length) {
    var j = i;
    // initial
    for (final ini in _initials) {
      if (s.startsWith(ini, i)) {
        j = i + ini.length;
        break;
      }
    }
    // vowels
    var k = j;
    while (k < s.length && _vowels.contains(s[k])) {
      k++;
    }
    if (k == j) {
      // the erhua r of 儿 at the end of a word is a syllable of its own here (一点儿 = yì diǎn r)
      if (s.substring(i) == 'r' && out.isNotEmpty) {
        out.add('r');
        break;
      }
      // no vowel (a stray letter): keep it with what came before
      if (out.isNotEmpty) {
        out[out.length - 1] += s.substring(i, k + 1);
      } else {
        out.add(s.substring(i, k + 1));
      }
      i = k + 1;
      continue;
    }
    // final consonants: n, ng, r — unless they start the next syllable (a vowel after them)
    var e = k;
    // 儿 (ér, èr) is a syllable of its own: e with an r
    if (j == i && k == j + 1 && 'eēéěè'.contains(s[j]) && e < s.length && s[e] == 'r' && (e + 1 >= s.length || !_vowels.contains(s[e + 1]))) {
      out.add(w.substring(i, e + 1));
      i = e + 1;
      continue;
    }
    if (s.startsWith('ng', e) && (e + 2 >= s.length || !_vowels.contains(s[e + 2]))) {
      e += 2;
    } else if (e < s.length && s[e] == 'n' && (e + 1 >= s.length || !_vowels.contains(s[e + 1]))) {
      e += 1;
    }
    out.add(w.substring(i, e));
    i = e;
  }
  return out;
}

// ------------------------------------------------------------------ marking an answer
/// a talk (retell, an answer): the keywords said, how much was said, how fast, the level's words used
class TalkScore {
  final int score; // 0–100
  final List<String> hit, miss;
  final int chars; // hanzi heard
  final int cpm; // hanzi a minute
  final int band; // different words of the level's band heard
  const TalkScore(this.score, this.hit, this.miss, this.chars, this.cpm, this.band);
}

/// does [heard] contain [word], allowing a character that sounds the same (the recognizer often writes a homophone)
bool saysWord(String heard, String word, CharSounds cs) {
  final h = heard.runes.map(String.fromCharCode).where(isHan).toList();
  final w = word.runes.map(String.fromCharCode).toList();
  if (w.isEmpty) return false;
  for (var i = 0; i + w.length <= h.length; i++) {
    var ok = true;
    for (var j = 0; j < w.length; j++) {
      if (!cs.same(w[j], h[i + j], 'n')) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

/// the words of the level's band in [heard] (the longest known words first)
int bandWords(String heard, int lv, Vocab v) {
  final lo = lv == 1 ? 3 : (lv == 2 ? 4 : 5), hi = lv == 3 ? 6 : lo;
  final h = heard.runes.map(String.fromCharCode).where(isHan).join();
  final found = <String>{};
  var i = 0;
  while (i < h.length) {
    var step = 1;
    for (var k = math.min(4, h.length - i); k >= 1; k--) {
      final w = h.substring(i, i + k);
      final l = v.levelOf(w);
      if (l != null) {
        if (l >= lo && l <= hi) found.add(w);
        step = k;
        break;
      }
    }
    i += step;
  }
  return found.length;
}

/// marks a retell or an answer: keywords, length and the level's own words (rules written out in the help)
TalkScore scoreTalk(String heard, SpkItem it, int secs, CharSounds cs, Vocab v) {
  final chars = heard.runes.map(String.fromCharCode).where(isHan).length;
  final hit = [for (final k in it.kw) if (saysWord(heard, k, cs)) k];
  final miss = [for (final k in it.kw) if (!hit.contains(k)) k];
  final band = bandWords(heard, it.lv, v);
  final want = it.k == 's' ? (it.lv == 2 ? 60 : 120) : const [0, 50, 100, 160][it.lv];
  final len = math.min(1.0, chars / want);
  final rich = math.min(1.0, band / const [0, 3, 4, 6][it.lv]);
  final kw = it.kw.isEmpty
      ? len
      : it.k == 'q'
      ? math.min(1.0, hit.length / 2)
      : hit.length / it.kw.length;
  final s = it.k == 's' ? .5 * kw + .35 * len + .15 * rich : .4 * len + .35 * kw + .25 * rich;
  final cpm = secs <= 0 ? 0 : (chars * 60 / secs).round();
  return TalkScore((s * 100).round().clamp(0, 100), hit, miss, chars, cpm, band);
}

// ------------------------------------------------------------------ the mock test
class HkTask {
  final SpkItem it;
  String heard = '';
  int score = 0;
  int secs = 0;
  SpeakResult? said; // a repeat or a text read aloud: character by character
  TalkScore? talk; // a retell or an answer
  bool done = false;
  HkTask(this.it);
}

class HkMock {
  final int lv;
  final List<HkTask> tasks;
  int i = 0;
  final int startedAt;
  HkMock(this.lv, this.tasks, this.startedAt);

  /// each part /100 (its tasks' mean) and the whole (the parts' mean)
  Map<String, int> partScores() {
    final out = <String, int>{};
    for (final (k, _) in hkPaper(lv)) {
      final ts = tasks.where((t) => t.it.k == k).toList();
      if (ts.isEmpty) continue;
      out[k] = (ts.fold<int>(0, (a, t) => a + t.score) / ts.length).round();
    }
    return out;
  }

  int total() {
    final p = partScores();
    return p.isEmpty ? 0 : (p.values.fold<int>(0, (a, b) => a + b) / p.length).round();
  }
}

/// what is kept (xc_spk): {m: mock history [[time, level, total, {part: score}]] ≤ 50, n: how far each list was
/// walked (practice and mocks take the next unused item, so nothing comes back soon), c: answers per level and part}
class SpkLog {
  Map<String, dynamic> j;
  SpkLog(Object? raw) : j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  List<List<dynamic>> get mocks => [for (final x in (j['m'] as List?) ?? const []) if (x is List) x];
  Map<String, dynamic> get _n => j['n'] is Map ? Map<String, dynamic>.from(j['n'] as Map) : <String, dynamic>{};
  Map<String, dynamic> get _c => j['c'] is Map ? Map<String, dynamic>.from(j['c'] as Map) : <String, dynamic>{};

  int count(int lv, String k) => ((_c['$lv$k'] as num?) ?? 0).toInt();
  int countLevel(int lv) => [for (final k in const ['r', 's', 't', 'q', 'x']) count(lv, k)].fold(0, (a, b) => a + b);

  void counted(int lv, String k) {
    final c = _c;
    c['$lv$k'] = count(lv, k) + 1;
    j['c'] = c;
  }

  /// the next [n] items of a list (mock tests walk it from the far end, practice from the start, in a fixed shuffle)
  List<SpkItem> take(List<SpkItem> list, int n, {bool mock = false}) {
    if (list.isEmpty) return const [];
    final key = '${mock ? 'm' : 'p'}${list.first.lv}${list.first.k}';
    final order = [for (var i = 0; i < list.length; i++) i]..shuffle(math.Random(list.length * 31 + list.first.lv));
    if (mock) order.setAll(0, order.reversed.toList());
    final nn = _n;
    var at = ((nn[key] as num?) ?? 0).toInt();
    final out = <SpkItem>[];
    for (var k = 0; k < math.min(n, list.length); k++) {
      out.add(list[order[at % list.length]]);
      at++;
    }
    nn[key] = at % list.length;
    j['n'] = nn;
    return out;
  }

  void saveMock(HkMock m, int now) {
    final list = [
      ...mocks,
      [now, m.lv, m.total(), m.partScores()],
    ];
    j['m'] = list.length > 50 ? list.sublist(list.length - 50) : list;
  }

  /// a backup's copy, checked: only well-formed entries come back
  static Map<String, dynamic>? clean(Object? raw) {
    if (raw is! Map) return null;
    final out = <String, dynamic>{};
    final m = raw['m'];
    if (m is List) {
      out['m'] = [
        for (final x in m)
          if (x is List && x.length >= 4 && x[0] is num && x[1] is num && hkLevels.contains(x[1]) && x[2] is num && x[3] is Map)
            [x[0], x[1], x[2], {for (final e in (x[3] as Map).entries) if (e.value is num) '${e.key}': e.value}],
      ];
    }
    for (final key in const ['n', 'c']) {
      final v = raw[key];
      if (v is Map) out[key] = {for (final e in v.entries) if (e.value is num) '${e.key}': (e.value as num).toInt()};
    }
    return out;
  }
}
