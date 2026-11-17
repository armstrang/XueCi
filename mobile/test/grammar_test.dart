// The grammar book (v1.6): every point loads with its texts, practice questions have one right answer, progress is
// kept and travels in a backup code, the tests take the levels' grammar sentences first, and the advanced band's
// points only exist once the gate is open.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/backup.dart';
import 'package:xueci/app/grammar.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';

final clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

Future<App> boot([Map<String, String> saved = const {}, int Function()? clock]) {
  Native.off = true;
  return App.boot(backend: MemoryBackend(Map.of(saved)), random: LcgRandom(7), clock: clock ?? () => clockMin, tzOffset: -420, sysLang: 'id');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every point of HSK 1–6 loads, with its texts in four languages', () async {
    final a = await boot();
    final b = a.gram!;
    expect(b.levels, [1, 2, 3, 4, 5, 6]);
    expect(b.pts.length, greaterThan(400));
    for (final p in b.pts) {
      for (final l in ['id', 'en', 'th', 'vi']) {
        expect(p.text(l).trim(), isNotEmpty, reason: '${p.id} $l');
      }
      expect(gramCats, contains(p.cat), reason: p.id);
      expect(p.formula, isNotEmpty, reason: p.id);
      for (final d in p.ex) {
        expect(p.fits(d.z) || p.keys.isEmpty, isTrue, reason: '${p.id}: example ${d.z} does not show the point');
      }
    }
    // most points can be practised
    expect(b.pts.where((p) => p.practisable).length / b.pts.length, greaterThan(.75));
  });

  test('practice: a gap has one right choice, an order puts the sentence back together', () async {
    final a = await boot();
    final b = a.gram!;
    var gaps = 0, orders = 0;
    for (final p in b.pts.where((p) => p.practisable)) {
      for (final it in a.gpr.run(p, n: 6)) {
        if (it.kind == 'gap') {
          gaps++;
          expect(it.opts.toSet().length, 4, reason: '${p.id} ${it.opts}');
          final k = it.opts[it.ans];
          expect(it.gapText.replaceFirst('＿＿', k), it.d.z, reason: p.id);
          // no other choice makes the very same sentence
          for (var i = 0; i < 4; i++) {
            if (i != it.ans) expect(it.gapText.replaceFirst('＿＿', it.opts[i]) == it.d.z, isFalse);
          }
        } else {
          orders++;
          expect(it.opts.join() == it.right.join() || it.opts.length < 2, isFalse, reason: '${p.id}: shuffled into the answer');
          expect([...it.opts]..sort(), [...it.right]..sort());
          final plain = it.d.z.replaceAll(RegExp(r'[。！？!?.]+$'), '');
          expect(it.right.join(), plain, reason: p.id);
          expect(gOrderOk(it, it.right), isTrue);
        }
      }
    }
    expect(gaps, greaterThan(300));
    expect(orders, greaterThan(300));
    // every point that says it can be practised gives at least a few questions
    final thin = [for (final p in b.pts.where((p) => p.practisable)) if (a.gpr.run(p).length < 2) p.id];
    expect(thin.length, lessThan(b.pts.length * .05), reason: '$thin');
  });

  test('progress per point: FSRS, held after three right answers spaced out, kept in xc_gram and the backup', () async {
    var now = clockMin;
    final a = await boot({}, () => now);
    final p = a.gram!.level(1).firstWhere((p) => p.practisable);
    expect(a.gprog.n(p.id), 0);
    for (var i = 0; i < 4; i++) {
      a.gprog.answer(p.id, true);
      now += 1440 * math.pow(3, i).toInt();
    }
    expect(a.gprog.n(p.id), 4);
    expect(a.gprog.held(p.id), isTrue);
    a.gprog.answer(p.id, false);
    expect(a.gprog.stab(p.id), lessThan(10));
    final saved = a.store.get('xc_gram', null) as Map;
    expect(saved[p.id], hasLength(5));

    final code = makeCode(a);
    final b = await boot();
    final r = await readCode(b, code);
    expect(r, isNotNull);
    await applyCode(b, r!);
    expect(b.gprog.n(p.id), 5);
    expect(jsonEncode(b.store.get('xc_gram', null)), jsonEncode(saved));
  });

  test('the tests take sentences that show their level grammar first', () async {
    final a = await boot();
    final b = a.gram!;
    for (final l in [2, 4, 6]) {
      final pool = a.lm.by(l).where((d) => a.lm.ptPieces(d) != null).toList();
      final first = gramFirst(b, pool, l).take(20);
      expect(first.every((d) => b.pointsIn(d.z, l).isNotEmpty), isTrue, reason: 'HSK $l');
    }
  });

  test('the advanced points are sealed: none before the gate, all of them after it', () async {
    final a = await boot();
    expect(a.gram!.levels.contains(7), isFalse);
    final open = await boot({
      'xc_lvl': jsonEncode({'r': 7, 'gate': clockMin, 'gs': clockMin, 'hist': []}),
    });
    expect(open.band, isTrue);
    final adv = open.gram!.level(7);
    expect(adv.length, greaterThan(140));
    expect(adv.where((p) => p.practisable).length, greaterThan(100));
  });
}
