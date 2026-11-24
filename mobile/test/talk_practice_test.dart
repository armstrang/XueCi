import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/practice.dart';

void main() {
  test('both levels offer ten distinct cases and two facts for each added case', () {
    final variants = <String, Set<String>>{};
    for (final level in PracticeLevel.values) {
      for (var seed = 0; seed < 20; seed++) {
        final pool = practicePool(level, Random(seed));
        expect(pool.map((item) => item.$1.id).toSet(), hasLength(10));
        for (final (scenario, hint) in pool) {
          expect(hint.isNotEmpty, level == PracticeLevel.a);
          final goal = scenario.practice;
          if (goal == null) continue;
          final prompts = variants.putIfAbsent(scenario.id, () => {});
          if (!prompts.add(goal.prompt.zh)) continue;
          final dialog = TalkDialog(scenario);
          expect(dialog.turnScore(goal.example.zh, []), greaterThanOrEqualTo(8), reason: goal.example.zh);
          expect(dialog.practiceAccepted('学校。'), isFalse);
          dialog.reply(goal.example.zh, []);
          expect(dialog.over, isTrue);
        }
      }
    }
    expect(variants, hasLength(17));
    expect(variants.values.every((prompts) => prompts.length == 2), isTrue);
  });
}
