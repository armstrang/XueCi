/// Progress on the BCT words (`xc_bct`: word → [d, s, t, n, right], the same memory model as the grammar points).
/// Extra practice only: nothing here touches the realm, the plan or the word list's mastery.
library;

import 'dart:math' as math;

import '../data/store.dart';
import '../engine/fsrs.dart' as fsrs;
import '../engine/js.dart';
import '../engine/learn.dart';

class BProg {
  final Store ls;
  final LM lm;
  Map<String, List<num>> j = {};
  BProg(this.ls, this.lm) {
    restore(ls.get('xc_bct', null), save: false);
  }

  int n(String id) => (j[id]?[3] ?? 0).toInt();
  double stab(String id) => (j[id]?[1] ?? 0).toDouble();

  void answer(String id, bool ok) {
    final t = lm.now();
    final cur = j[id];
    final st = cur == null ? null : [cur[0].toDouble(), cur[1].toDouble(), cur[2].toDouble()];
    final s = lm.step(st, ok ? 3 : 1, t);
    j[id] = [s[0], s[1], s[2], (cur?[3] ?? 0) + 1, (cur?[4] ?? 0) + (ok ? 1 : 0)];
    ls.set('xc_bct', j);
  }

  /// the chance of recalling the word now, 0 for a word never practised
  double recall(String id) {
    final v = j[id];
    if (v == null) return 0;
    return fsrs.rt((lm.now() - v[2]) / 1440, v[1].toDouble());
  }

  bool held(String id) => n(id) >= 3 && stab(id) >= 10;
  bool seen(String id) => j.containsKey(id);
  bool due(String id) => j.containsKey(id) && recall(id) < 0.85;

  /// 0–20 like a word's level
  int level(String id) {
    final s = stab(id);
    return s <= 0 ? 0 : math.min(20, jsRound(20 * math.log(1 + s) / math.log(121)));
  }

  /// from a backup code or the store: entries checked one by one
  void restore(Object? o, {bool save = true}) {
    if (o is! Map) return;
    final out = <String, List<num>>{};
    o.forEach((k, v) {
      if (k is String && v is List && v.length == 5 && v.every((x) => x is num && x.isFinite)) out[k] = v.cast<num>();
    });
    j = out;
    if (save) ls.set('xc_bct', j);
  }
}
