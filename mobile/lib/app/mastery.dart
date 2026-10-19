/// Word mastery (mastery.js): every word has a level 0–20 from the learning engine (stats[id] = [right, wrong,
/// level]); 0–6 red, 7–13 yellow, 14–20 green; inside each colour a light shade is young, a deep shade mature.
library;

import 'dart:ui';

import '../data/words.dart';
import '../ui/theme.dart';

const maxL = 20;

String lvBand(int s) => s >= 14 ? 'green' : (s >= 7 ? 'yellow' : 'red');
int lvAlpha(int s) {
  final (lo, hi) = s >= 14 ? (14, 20) : (s >= 7 ? (7, 13) : (0, 6));
  return (26 + (74 * (s - lo)) / (hi - lo)).round();
}

/// the colour of a level 0–20 (or "never practised" for -1)
Color levelColor(Pal p, int s) =>
    s < 0 ? p.sNone : Pal.mix(p.band(lvBand(s)), lvAlpha(s) / 100, p.surface);

class MSum {
  final List<int> lv;
  final int none, red, yellow, green, mature, n;
  final double p;
  const MSum(this.lv, this.none, this.red, this.yellow, this.green, this.mature, this.n, this.p);
  int band(String b) => switch (b) {
    'green' => green,
    'yellow' => yellow,
    'red' => red,
    _ => none,
  };
}

MSum summaryOf(Iterable<Word> arr, int Function(Word) lvl) {
  final lv = List<int>.filled(maxL + 1, 0);
  var none = 0, pts = 0, n = 0;
  for (final d in arr) {
    n++;
    final s = lvl(d);
    if (s < 0) {
      none++;
    } else {
      lv[s]++;
      pts += s;
    }
  }
  int sum(int a, int b) => lv.sublist(a, b).fold(0, (x, y) => x + y);
  return MSum(lv, none, sum(0, 7), sum(7, 14), sum(14, maxL + 1), lv[maxL], n, n == 0 ? 0 : (pts / (maxL * n)) * 100);
}
