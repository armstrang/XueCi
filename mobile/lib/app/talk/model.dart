/// The small classifier of the talk engine: one logistic regression per act and polarity (apologize+, discount-, …)
/// over the hanzi n-grams of the utterance and the n-grams of its toneless-syllable fold. Trained offline by
/// `mobile/tool/make_talk_model.py`, shipped as one JSON file of int8 weights. Reading takes well under a millisecond.
library;

import 'dart:convert';
import 'dart:math';

class TalkModel {
  final List<String> labels;
  final List<double> bias, scale;

  /// per label: how the rules' confidence and the model's logit are mixed ([a_rule, a_model, bias]), and the shift
  final Map<String, List<double>> stack;
  final double shift;

  /// n-gram -> flat list of (label index, weight) pairs
  final Map<String, List<int>> _w;
  final Map<int, int> _fold;

  TalkModel._(this.labels, this.bias, this.scale, this._w, this._fold, this.stack, this.shift);

  /// [foldFrom] / [foldTo]: the homophone fold (`soundFrom` / `soundTo`)
  factory TalkModel.fromJson(String json, String foldFrom, String foldTo) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final w = <String, List<int>>{};
    (m['w'] as Map<String, dynamic>).forEach((g, v) {
      final flat = <int>[];
      for (final e in v as List) {
        flat..add((e as List)[0] as int)..add(e[1] as int);
      }
      w[g] = flat;
    });
    final a = foldFrom.runes.toList(), b = foldTo.runes.toList();
    return TalkModel._(
      [for (final l in m['labels'] as List) l as String],
      [for (final x in m['bias'] as List) (x as num).toDouble()],
      [for (final x in m['scale'] as List) (x as num).toDouble()],
      w,
      {for (var i = 0; i < a.length; i++) a[i]: b[i]},
      {
        for (final e in ((m['stack'] ?? <String, dynamic>{}) as Map<String, dynamic>).entries)
          e.key: [for (final x in e.value as List) (x as num).toDouble()]
      },
      ((m['shift'] ?? 0) as num).toDouble(),
    );
  }

  static final _keep = RegExp('[一-鿿0-9]');

  Set<String> _feats(String text) {
    final t = _keep.allMatches(text).map((m) => m[0]!).join();
    final out = <String>{};
    final s = '^$t\$';
    for (var n = 1; n <= 4; n++) {
      for (var i = 0; i + n <= s.length; i++) {
        out.add(s.substring(i, i + n));
      }
    }
    final ft = String.fromCharCodes(t.runes.map((r) => _fold[r] ?? r));
    final sf = '^$ft\$';
    for (var n = 2; n <= 4; n++) {
      for (var i = 0; i + n <= sf.length; i++) {
        out.add('~${sf.substring(i, i + n)}');
      }
    }
    return out;
  }

  /// mixed confidence of [label] from the rules' [r] and the model's probability [p]; null where nothing was learned
  double? mix(String label, double r, double p) {
    final c = stack[label];
    if (c == null) return null;
    final q = p.clamp(1e-4, 1 - 1e-4);
    final z = c[0] * r + c[1] * log(q / (1 - q)) + c[2] + shift;
    return 1 / (1 + exp(-z));
  }

  /// probability of every label for one utterance
  Map<String, double> probs(String text) {
    final known = <List<int>>[];
    for (final g in _feats(text)) {
      final w = _w[g];
      if (w != null) known.add(w);
    }
    final z = List<double>.of(bias);
    if (known.isNotEmpty) {
      final norm = sqrt(known.length);
      final acc = List<double>.filled(labels.length, 0);
      for (final w in known) {
        for (var i = 0; i < w.length; i += 2) {
          acc[w[i]] += w[i + 1];
        }
      }
      for (var k = 0; k < z.length; k++) {
        z[k] += acc[k] * scale[k] / norm;
      }
    }
    return {for (var k = 0; k < labels.length; k++) labels[k]: 1 / (1 + exp(-z[k]))};
  }
}
