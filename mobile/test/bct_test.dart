// The BCT-style practice (v1.9): own sentence bank, papers built from it, nothing recorded in the learner's memory,
// results kept under their own levels (101 / 102) and in backup codes.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/backup.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/bct.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';

final clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

Future<App> boot([Map<String, String> saved = const {}]) {
  Native.off = true;
  return App.boot(backend: MemoryBackend(Map.of(saved)), random: LcgRandom(7), clock: () => clockMin, tzOffset: -420, sysLang: 'id');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bank loads; every gap has four different words, the right one is in the sentence', () async {
    final a = await boot();
    final bank = a.lm.bct!;
    expect(bank.of('a').length, greaterThan(50));
    for (final s in bank.of('a')) {
      expect({s.g, ...s.d}.length, 4, reason: s.id);
      expect(s.z.contains(s.g), isTrue, reason: s.id);
      for (final l in ['id', 'en', 'th', 'vi']) {
        expect((s.t[l] ?? '').trim(), isNotEmpty, reason: '${s.id} $l');
      }
    }
  });

  test('a paper has its sections and one right answer per question', () async {
    final a = await boot();
    final lm = a.lm;
    lm.ttsReady = () => true;
    for (final short in [false, true]) {
      final m = lm.bctExam('a', short: short);
      expect(m.L, bctA);
      expect(m.book, 'a');
      expect(m.parts.map((p) => p.k).toList(), ['listen', 'read', 'write']);
      expect(m.items, isNotEmpty);
      for (final it in m.items) {
        if (it.q == 'wo') {
          expect(it.parts, isNotEmpty);
        } else if (it.q == 'lj') {
          expect(it.ans, anyOf(0, 1));
        } else {
          expect(it.words!.length, 4, reason: '${it.q}');
          expect({...it.words!.map((w) => w.h + w.z)}.length, 4);
        }
      }
    }
    final one = lm.bctExam('a', only: 'read');
    expect(one.parts.map((p) => p.k).toList(), ['read']);
  });

  test('results sit under level 101 / 102 and a backup code keeps them', () async {
    final a = await boot();
    final lm = a.lm;
    lm.ttsReady = () => true;
    final m = lm.bctExam('b', short: true);
    for (final it in m.items) {
      it.ok = true;
    }
    final r = lm.mockScore(m);
    lm.mockSave(m, r, 600);
    expect(lm.mocks.last[1], bctB);
    final code = makeCode(a);
    final b = await boot();
    final x = await readCode(b, code);
    expect(x, isNotNull);
    await applyCode(b, x!);
    expect(b.lm.mocks.last[1], bctB);
    expect(jsonEncode(b.lm.mocks.last), jsonEncode(lm.mocks.last));
  });
}
