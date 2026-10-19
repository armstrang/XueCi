/// FSRS-5, the memory model (same numbers as learn.js). A memory state is [difficulty 1–10, stability in days,
/// last answer in minutes since 1 Jan 2026 UTC]; the chance of still recalling after t days is
/// R = (1 + 19/81·t/S)^-0.5, so R = 90 % when t = S.
library;

import 'dart:math' as math;

import 'js.dart';

const List<double> w0 = [
  0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, //
  2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
];
const List<double> lb = [0.01, 0.01, 0.01, 0.01, 1, 0.001, 0.001, 0.001, 0, 0, 0.001, 0.001, 0.001, 0.001, 0, 0, 1, 0, 0];
const List<double> ub = [100, 100, 100, 100, 10, 4, 4, 0.75, 4.5, 0.8, 3.5, 5, 0.25, 0.9, 4, 1, 6, 2, 2];
const double decay = -0.5;
const double factor = 19 / 81;

/// minutes since 1 Jan 2026 00:00 UTC
final int epochMs = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

double rt(double days, double s) => math.pow(1 + (factor * math.max(0, days)) / s, decay).toDouble();
double ivl(double s, double r) => (s / factor) * (math.pow(r, 1 / decay) - 1);
double d0(List<double> w, int g) => cl(w[4] - math.exp(w[5] * (g - 1)) + 1, 1, 10);

/// The day of a time: [tz] is JS getTimezoneOffset() (minutes, positive west of UTC).
int dayOfTz(num t, int tz) => ((t - tz) / 1440).floor();
bool sameDayTz(num t, num t0, int tz) => t - t0 < 240 || dayOfTz(t, tz) == dayOfTz(t0, tz);

/// st = [d, s, t] or null for a first answer; prior = share of the word's characters already known (0–1);
/// dd = the word's own difficulty within its level (−0.6 easy … +0.6 hard)
List<double> step(List<double> w, List<double>? st, int g, num t, int tz, [double prior = 0, double dd = 0]) {
  if (st == null) {
    final k = prior, x = dd;
    return [
      cl(d0(w, g) - (g > 1 ? 1.2 * k : 0) + 1.5 * x, 1, 10),
      math.max(0.1, w[g - 1] * (g > 2 ? 1 + 0.6 * k : 1) * (1 - 0.35 * x)),
      t.toDouble(),
    ];
  }
  final d = st[0], s = st[1], el = (t - st[2]) / 1440;
  final d2 = cl(w[7] * d0(w, 4) + (1 - w[7]) * (d - (w[6] * (g - 3) * (10 - d)) / 9), 1, 10);
  double s2;
  if (sameDayTz(t, st[2], tz)) {
    final inc = math.exp(w[17] * (g - 3 + w[18]));
    s2 = g > 2 ? math.min(s * inc, s + 0.5) : s * inc;
  } else {
    final r = rt(el, s);
    s2 = g == 1
        ? math.min(
            w[11] * math.pow(d, -w[12]) * (math.pow(s + 1, w[13]) - 1) * math.exp(w[14] * (1 - r)),
            s / math.exp(w[17] * w[18]),
          )
        : s *
              (1 +
                  math.exp(w[8]) *
                      (11 - d) *
                      math.pow(s, -w[9]) *
                      (math.exp(w[10] * (1 - r)) - 1) *
                      (g == 2 ? w[15] : 1) *
                      (g == 4 ? w[16] : 1));
  }
  return [d2, cl(s2, 0.1, 36500), t.toDouble()];
}

/// log loss of the spaced reviews in [seqs] (per word: [[time, grade], ...]) under parameters [w]
({double ll, int n}) lossOf(List<double> w, List<List<List<int>>> seqs, int tz) {
  var ll = 0.0;
  var n = 0;
  for (final q in seqs) {
    List<double>? st;
    for (final a in q) {
      final t = a[0], g = a[1];
      if (st != null && !sameDayTz(t, st[2], tz)) {
        final p = cl(rt((t - st[2]) / 1440, st[1]), 1e-4, 1 - 1e-4);
        ll -= g > 1 ? math.log(p) : math.log(1 - p);
        n++;
      }
      st = step(w, st, g, t, tz, 0);
    }
  }
  return (ll: ll, n: n);
}

/// Fit the 19 parameters to a learner's own spaced reviews (Adam on finite differences, 50 rounds, a pull towards
/// the defaults that fades with more data). Pure, so it can run in a background isolate.
({List<double> w, double ll, double ll0, int n}) fitParams(List<List<List<int>>> seqs, int tz) {
  final base = lossOf(w0, seqs, tz);
  final sc = w0.map((x) => math.max(0.05, x.abs() * 0.5)).toList();
  final nn = base.n;
  List<double> toW(List<double> z) => [for (var i = 0; i < z.length; i++) cl(w0[i] + z[i] * sc[i], lb[i], ub[i])];
  double f(List<double> z) => lossOf(toW(z), seqs, tz).ll / nn + (30 / nn) * z.fold<double>(0, (s, v) => s + v * v);
  var z = List<double>.filled(19, 0);
  final m = List<double>.filled(19, 0), v = List<double>.filled(19, 0);
  var fz = f(z);
  const lr = 0.06, eps = 0.01;
  for (var it = 1; it <= 50; it++) {
    final g = <double>[];
    for (var i = 0; i < 19; i++) {
      final z2 = List<double>.of(z);
      z2[i] += eps;
      g.add((f(z2) - fz) / eps);
    }
    z = [
      for (var i = 0; i < 19; i++)
        () {
          m[i] = 0.9 * m[i] + 0.1 * g[i];
          v[i] = 0.999 * v[i] + 0.001 * g[i] * g[i];
          final mh = m[i] / (1 - math.pow(0.9, it)), vh = v[i] / (1 - math.pow(0.999, it));
          return z[i] - (lr * mh) / (math.sqrt(vh) + 1e-8);
        }(),
    ];
    final ww = toW(z);
    z = [for (var i = 0; i < 19; i++) (ww[i] - w0[i]) / sc[i]];
    fz = f(z);
  }
  final w = toW(z);
  return (w: w, ll: lossOf(w, seqs, tz).ll / nn, ll0: base.ll / nn, n: nn);
}
