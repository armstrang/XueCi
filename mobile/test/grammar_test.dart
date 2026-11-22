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

  test('every point has a name in four languages, three examples written word by word, and formula parts that exist', () async {
    final a = await boot();
    final open = await boot({
      'xc_lvl': jsonEncode({'r': 7, 'gate': clockMin, 'gs': clockMin, 'hist': []}),
    });
    for (final app in [a, open]) {
      for (final x in app.gram!.pts) {
        for (final l in ['id', 'en', 'th', 'vi']) {
          expect(x.title(l).trim(), isNotEmpty, reason: '${x.id} title $l');
        }
        expect(x.eg.length, greaterThanOrEqualTo(3), reason: '${x.id} has too few examples');
        for (final e in x.eg) {
          expect(e.z, isNotEmpty, reason: x.id);
          for (final l in ['id', 'en', 'th', 'vi']) {
            expect((e.tr[l] ?? '').trim(), isNotEmpty, reason: '${x.id} translation $l: ${e.z}');
          }
          for (final w in e.w.where((w) => !w.punct)) {
            expect(w.py, isNotEmpty, reason: '${x.id} ${w.h} has no pinyin');
            expect(w.g, isNotNull, reason: '${x.id} ${w.h} has no meaning');
            expect(w.slot, lessThanOrEqualTo(x.parts.length), reason: '${x.id}: slot of ${w.h} is not in the formula');
          }
        }
      }
    }
  });

  test('v1.8: the list follows the learning stages, mixed practice changes from one round to the next', () async {
    final a = await boot();
    final b = a.gram!;
    for (final l in b.levels) {
      final pts = b.inBook('h3', l);
      expect(pts.length, b.level(l).length);
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i].t >= pts[i - 1].t, isTrue, reason: '${pts[i].id} before ${pts[i - 1].id}');
      }
    }
    // three rounds of the same level: different points and sentences, not the same ten every time
    final r1 = a.gpr.review('h3', 2, a.gprog), r2 = a.gpr.review('h3', 2, a.gprog), r3 = a.gpr.review('h3', 2, a.gprog);
    expect(r1.length, 10);
    final z1 = r1.map((x) => x.d.z).toSet(), z2 = r2.map((x) => x.d.z).toSet(), z3 = r3.map((x) => x.d.z).toSet();
    expect(z1.intersection(z2).length, lessThan(5));
    expect(z2.intersection(z3).length, lessThan(5));
    // after answers, fading points come back more often than strong ones, but not alone
    for (final it in r1) {
      a.gprog.answer(it.p.id, false);
    }
    final r4 = a.gpr.review('h3', 2, a.gprog);
    final weak = r1.map((x) => x.p.id).toSet();
    final back = r4.where((x) => weak.contains(x.p.id)).length;
    expect(back, greaterThanOrEqualTo(4));
    expect(back, lessThan(r4.length));
  });

  test('v1.8: the books: HSK 2.0 1–6, YCT 1–4, BCT A/B; their own points stay out of the HSK 3.0 book and the tests', () async {
    final a = await boot();
    final b = a.gram!;
    expect(b.levelsOf('h3'), [1, 2, 3, 4, 5, 6]);
    expect(b.levelsOf('h2'), [1, 2, 3, 4, 5, 6]);
    expect(b.levelsOf('yct'), [1, 2, 3, 4]);
    expect(b.levelsOf('bct'), [1, 2]);
    final own = b.pts.where((p) => p.nh).toList();
    expect(own, isNotEmpty);
    for (final p in own) {
      expect(p.id, startsWith('x-'));
      expect(p.v, isNotEmpty);
      expect(b.level(p.l), isNot(contains(p)), reason: p.id);
      expect(p.lvIn('h3'), isNull);
    }
    // a point of several books shows in each, with the same progress
    final p = b.byId['4-055']!; // 既然……就……
    expect(b.inBook('h3', 4), contains(p));
    expect(b.inBook('h2', p.v['h2']!), contains(p));
    expect(b.inBook('bct', p.v['bct']!), contains(p));
    for (final bk in gramBooks) {
      for (final l in b.levelsOf(bk)) {
        final ps = b.inBook(bk, l);
        for (var i = 1; i < ps.length; i++) {
          expect(ps[i].t >= ps[i - 1].t, isTrue);
        }
        expect(a.gpr.review(bk, l, a.gprog), isNotEmpty, reason: '$bk $l');
      }
    }
    // a book's level is remembered in the UI settings
    a.gramBook = 'bct';
    a.saveUI();
    final again = await boot({'hsk16_ui': jsonEncode(a.store.get('hsk16_ui', {}))});
    expect(again.gramBook, 'bct');
  });
  test('BCT shows work sentences only, and every BCT point has at least three of them', () async {
    final a = await boot();
    final b = a.gram!;
    var n = 0;
    for (final p in b.pts.where((p) => p.v.containsKey('bct'))) {
      final w = p.egFor('bct');
      n++;
      expect(w.where((e) => e.c == 'w').length, greaterThanOrEqualTo(3), reason: p.id);
      expect(w.every((e) => e.c == 'w'), isTrue, reason: p.id);
    }
    expect(n, greaterThan(200));
  });
}
