/// The tone check (HSKK repeat practice): the app records the learner (Rec.kt, 16 kHz mono PCM, in memory only),
/// finds the pitch of every 10 ms (YIN), cuts the voiced sound into as many syllables as the sentence has, and
/// reads the shape of each one: level and high (1), rising (2), low or dipping (3), falling (4). The speech
/// recognizer can't do this: it guesses words from their context, so a wrong tone often still comes back as the
/// right character. A guide, not an examiner: noise, a cold or fast speech all move it.
library;

import 'dart:math' as math;
import 'dart:typed_data';

const toneRate = 16000;
const _frame = 640; // 40 ms window
const _hop = 160; // 10 ms step
const _minHz = 70.0, _maxHz = 420.0;

/// one syllable heard
class ToneSyl {
  final int want; // 1–4, 5 = neutral (always fine)
  final int got; // 1–4, 0 = not heard
  final List<double> curve; // its pitch in semitones around the speaker's middle, start to end (≤ 12 points)
  const ToneSyl(this.want, this.got, this.curve);
  bool get ok => want == 5 || want == got || (want == 3 && got == 0 && curve.isNotEmpty);
}

class ToneResult {
  final List<ToneSyl> syl;
  final bool heard; // enough voice to judge
  const ToneResult(this.syl, this.heard);
  int get right => syl.where((s) => s.ok).length;
  double get share => syl.isEmpty ? 0 : right / syl.length;
}

/// samples from 16-bit little-endian PCM
Float64List pcmSamples(Uint8List pcm) {
  final n = pcm.length ~/ 2;
  final bd = ByteData.sublistView(pcm);
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// the pitch of every 10 ms (0 = no voice there)
List<double> pitchTrack(Float64List x) {
  final out = <double>[];
  final tauMin = (toneRate / _maxHz).floor(), tauMax = (toneRate / _minHz).ceil();
  final half = _frame ~/ 2;
  // loudness gate: a fraction of the loudest frames, so quiet noise between words is not read as voice
  final rms = <double>[];
  for (var s = 0; s + _frame <= x.length; s += _hop) {
    var e = 0.0;
    for (var i = s; i < s + _frame; i++) {
      e += x[i] * x[i];
    }
    rms.add(math.sqrt(e / _frame));
  }
  if (rms.isEmpty) return out;
  final sorted = [...rms]..sort();
  final loud = sorted[(sorted.length * .95).floor().clamp(0, sorted.length - 1)];
  final gate = math.max(0.01, loud * .12);
  final d = Float64List(tauMax + 1);
  var f = 0;
  for (var s = 0; s + _frame <= x.length; s += _hop, f++) {
    if (rms[f] < gate || tauMax >= half) {
      out.add(0);
      continue;
    }
    // YIN: difference function, cumulative mean normalised, first dip under the threshold
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var i = 0; i < half; i++) {
        final v = x[s + i] - x[s + i + tau];
        sum += v * v;
      }
      d[tau] = sum;
    }
    var run = 0.0;
    var best = -1;
    for (var tau = 1; tau <= tauMax; tau++) {
      run += d[tau];
      final c = run == 0 ? 1.0 : d[tau] * tau / run;
      d[tau] = c;
    }
    for (var tau = tauMin; tau < tauMax; tau++) {
      if (d[tau] < .18) {
        while (tau + 1 < tauMax && d[tau + 1] < d[tau]) {
          tau++;
        }
        best = tau;
        break;
      }
    }
    if (best < 0) {
      out.add(0);
      continue;
    }
    // a parabola through the dip for a finer period
    final a = d[best - 1], b = d[best], c = d[best + 1];
    final den = a - 2 * b + c;
    final t = den == 0 ? best.toDouble() : best + (a - c) / (2 * den);
    out.add(toneRate / t);
  }
  return out;
}

/// the shape of a pitch curve (semitones around the speaker's middle): 1 level high, 2 rising, 3 low or dipping,
/// 4 falling, 0 not enough voice
int toneShape(List<double> st) {
  if (st.length < 4) return 0;
  final n = st.length;
  double avg(int a, int b) {
    var s = 0.0;
    for (var i = a; i < b; i++) {
      s += st[i];
    }
    return s / math.max(1, b - a);
  }

  final q = math.max(1, n ~/ 4);
  final start = avg(0, q), end = avg(n - q, n), mid = avg(q, n - q);
  var lo = st.first, loAt = 0;
  for (var i = 0; i < n; i++) {
    if (st[i] < lo) {
      lo = st[i];
      loAt = i;
    }
  }
  final mean = avg(0, n);
  final rise = end - start;
  // a dip: lower in the middle than at both ends; or simply low all through (the half third tone in speech)
  if (loAt > n * .2 && loAt < n * .8 && start - lo > 1.2 && end - lo > 1.2) return 3;
  if (rise <= -2.5) return 4;
  if (rise >= 2.0 && mid < end) return 2;
  if (mean < -1.8 && rise.abs() < 2.5) return 3;
  if (rise.abs() < 2.0) return mean > -1.8 ? 1 : 3;
  return rise > 0 ? 2 : 4;
}

/// the expected tone of every syllable, with the change of a third tone before another third (你好: 2 3)
List<int> spokenTones(List<int> tones) {
  final t = [...tones];
  for (var i = t.length - 2; i >= 0; i--) {
    if (t[i] == 3 && t[i + 1] == 3) t[i] = 2;
  }
  return t;
}

/// cuts the voiced frames into [n] syllables: runs of voice split at gaps; too many runs → the smallest gaps close,
/// too few → the longest runs are halved
List<(int, int)> syllableSpans(List<double> hz, int n) {
  var runs = <(int, int)>[];
  int? s;
  var gap = 0;
  for (var i = 0; i <= hz.length; i++) {
    final v = i < hz.length && hz[i] > 0;
    if (v) {
      s ??= i;
      gap = 0;
    } else if (s != null) {
      gap++;
      if (gap >= 3 || i == hz.length) {
        final e = i - gap + 1;
        if (e - s >= 4) runs.add((s, e));
        s = null;
        gap = 0;
      }
    }
  }
  if (runs.isEmpty || n <= 0) return const [];
  while (runs.length > n) {
    var k = 0, g = 1 << 30;
    for (var i = 0; i < runs.length - 1; i++) {
      final gg = runs[i + 1].$1 - runs[i].$2;
      if (gg < g) {
        g = gg;
        k = i;
      }
    }
    runs = [...runs.sublist(0, k), (runs[k].$1, runs[k + 1].$2), ...runs.sublist(k + 2)];
  }
  while (runs.length < n) {
    var k = 0;
    for (var i = 1; i < runs.length; i++) {
      if (runs[i].$2 - runs[i].$1 > runs[k].$2 - runs[k].$1) k = i;
    }
    final r = runs[k];
    final len = r.$2 - r.$1;
    if (len < 8) break;
    final m = r.$1 + len ~/ 2;
    runs = [...runs.sublist(0, k), (r.$1, m), (m, r.$2), ...runs.sublist(k + 1)];
  }
  return runs;
}

/// the whole check: [tones] = the written tone of each syllable (1–4, 5 neutral)
ToneResult checkTones(Uint8List pcm, List<int> tones) {
  final hz = pitchTrack(pcmSamples(pcm));
  final voiced = hz.where((v) => v > 0).toList()..sort();
  if (voiced.length < 10 || tones.isEmpty) return ToneResult([for (final t in tones) ToneSyl(t, 0, const [])], false);
  final midHz = voiced[voiced.length ~/ 2];
  final want = spokenTones(tones);
  final spans = syllableSpans(hz, want.length);
  final out = <ToneSyl>[];
  for (var i = 0; i < want.length; i++) {
    if (i >= spans.length) {
      out.add(ToneSyl(want[i], 0, const []));
      continue;
    }
    final (a, b) = spans[i];
    final st = <double>[
      for (var k = a; k < b; k++)
        if (hz[k] > 0) 12 * math.log(hz[k] / midHz) / math.ln2,
    ];
    // a few points for the drawing (a running mean smooths the octave slips YIN sometimes makes)
    final sm = <double>[];
    for (var k = 0; k < st.length; k++) {
      var sum = 0.0, c = 0;
      for (var j = math.max(0, k - 2); j <= math.min(st.length - 1, k + 2); j++) {
        sum += st[j];
        c++;
      }
      sm.add(sum / c);
    }
    final pts = <double>[];
    if (sm.isNotEmpty) {
      final m = math.min(12, sm.length);
      for (var k = 0; k < m; k++) {
        pts.add(sm[(k * (sm.length - 1) / math.max(1, m - 1)).round()]);
      }
    }
    out.add(ToneSyl(want[i], toneShape(sm), pts));
  }
  return ToneResult(out, true);
}

/// the textbook shape of a tone, for drawing next to the learner's (semitones around the middle)
List<double> toneTemplate(int t) => switch (t) {
  1 => const [3, 3, 3, 3, 3],
  2 => const [-1, -0.5, 0.5, 2, 3.5],
  3 => const [-1, -3, -4, -3, -1],
  4 => const [4, 2.5, 0.5, -1.5, -3.5],
  _ => const [0, -0.5, -1, -1.5, -2],
};
