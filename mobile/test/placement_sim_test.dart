// The placement test against simulated learners who guess like real people (v1.6, Josh: the old test put learners
// between HSK 4 and 5 into 渡劫). A learner knows a word of each level with some chance; a word they don't know is
// guessed, cleverly: half the wrong options ruled out on a 4-option question, a third on 6; typing and sentence
// building can't be guessed.
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';
import 'package:xueci/engine/learn.dart';

final clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

Future<Map<int, int>> run(Map<int, double> know, int trials, {bool tts = true}) async {
  final hist = <int, int>{};
  final rnd = math.Random(11);
  final a = await App.boot(backend: MemoryBackend({}), random: LcgRandom(5), clock: () => clockMin, tzOffset: -420, sysLang: 'id');
  final lm = a.lm;
  lm.ptTts = tts;
  for (var t = 0; t < trials; t++) {
    final st = lm.ptStart();
    while (true) {
      final it = lm.ptNext(st);
      if (it == null) break;
      final k = rnd.nextDouble() < know[it.l!]!;
      bool ok;
      if (k) {
        ok = rnd.nextDouble() < .96;
      } else if (it.q == 'p' || it.q == 'pm' || it.q == 'wo') {
        ok = rnd.nextDouble() < .02;
      } else {
        final n = it.words?.length ?? it.tones?.length ?? 4;
        ok = rnd.nextDouble() < (n <= 4 ? 1 / 2 : 1 / 4); // clever: half (or a third) of the wrong ones ruled out
      }
      lm.ptAnswer(st, it, ok ? 'ok' : 'ng');
    }
    final m = lm.ptResult(st).m;
    hist[m] = (hist[m] ?? 0) + 1;
  }
  return hist;
}

double share(Map<int, int> h, bool Function(int m) f) => h.entries.where((e) => f(e.key)).fold(0, (s, e) => s + e.value) / h.values.fold(0, (s, v) => s + v);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Native.off = true);

  test('between HSK 4 and 5, guessing cleverly: hardly ever 渡劫', () async {
    final h = await run({1: .98, 2: .97, 3: .95, 4: .9, 5: .5, 6: .2}, 60);
    expect(share(h, (m) => m >= 5), lessThanOrEqualTo(.05), reason: '$h');
    expect(share(h, (m) => m == 4), greaterThanOrEqualTo(.6), reason: '$h');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('HSK 5 really mastered: still 渡劫', () async {
    final h = await run({1: .99, 2: .99, 3: .98, 4: .97, 5: .93, 6: .3}, 40);
    expect(share(h, (m) => m == 5), greaterThanOrEqualTo(.75), reason: '$h');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('a pure guesser stays at the start', () async {
    final h = await run({1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}, 40);
    expect(share(h, (m) => m == 0), greaterThanOrEqualTo(.9), reason: '$h');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('HSK 3 solid, HSK 4 half: HSK 3', () async {
    final h = await run({1: .98, 2: .96, 3: .9, 4: .5, 5: .15, 6: .05}, 40);
    expect(share(h, (m) => m == 3), greaterThanOrEqualTo(.6), reason: '$h');
    expect(share(h, (m) => m >= 4), lessThanOrEqualTo(.1), reason: '$h');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('without a voice: listening becomes typing, the result holds', () async {
    final h = await run({1: .98, 2: .97, 3: .95, 4: .9, 5: .5, 6: .2}, 30, tts: false);
    expect(share(h, (m) => m >= 5), lessThanOrEqualTo(.07), reason: '$h');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('the test is blind and complete: 60 questions, every one with a clock, sentences built from HSK 3 up', () async {
    final a = await App.boot(backend: MemoryBackend({}), random: LcgRandom(9), clock: () => clockMin, tzOffset: -420, sysLang: 'id');
    final lm = a.lm;
    final st = lm.ptStart();
    final kinds = <String>{};
    while (true) {
      final it = lm.ptNext(st);
      if (it == null) break;
      expect(it.limit, isNotNull);
      kinds.add(it.q!);
      if (it.q == 'wo') {
        expect(it.l, greaterThanOrEqualTo(3));
        expect(it.parts!.length, greaterThanOrEqualTo(LM.ptMinPieces(it.l!)));
      }
      lm.ptAnswer(st, it, 'ok');
    }
    expect(st.items.length, LM.ptN);
    expect(kinds, containsAll(['pm', 'wo', 'lm']));
  });
}
