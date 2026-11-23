// The client of a talk: scripted runs end the way they should, and thousands of random runs always end.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/coach.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/nlu.dart';

void main() {
  final nlu = TalkNlu();
  TalkDialog run(List<String> says, {int seed = 1}) {
    final d = TalkDialog(lateDelivery, seed: seed);
    d.open();
    for (final s in says) {
      if (d.over) break;
      d.reply(s, nlu.said([s]));
    }
    return d;
  }

  test('a good seller: apology, reason, a day in time, a discount, thanks', () {
    final d = run([
      '王先生您好，真的非常抱歉。',
      '因为海关查验，所以晚了三天。',
      '我们今天就重新发货，星期四之前一定送到。',
      '这次给您打九折，作为补偿。',
      '谢谢您的理解，期待继续合作。',
    ]);
    expect(d.st.end, 'good');
    final r = coach(d);
    expect(r.total, greaterThanOrEqualTo(85));
  });

  test('all said at once is understood at once', () {
    final d = run(['真的对不起，因为海关查验晚了，我们明天就补发，后天送到，再给您打九折。', '谢谢您，合作愉快。']);
    expect(d.st.end, 'good');
    expect(d.turns.length, 2);
  });

  test('the client asks for what is missing, in order', () {
    final d = run(['我们明天发货。']);
    expect(d.turns.last.situation, 'wantSorry');
    final e = run(['对不起。', '因为下大雨。', '我们下周一送到。']);
    expect(e.turns.last.situation, 'tooLate');
    final f = run(['对不起。', '因为下大雨。', '我们会尽快送到。']);
    expect(f.turns.last.situation, 'whichDay');
    final g = run(['对不起。', '因为下大雨。', '明天送到。', '给您打九五折。']);
    expect(g.turns.last.situation, 'lowPct');
  });

  test('blaming others twice loses the client', () {
    final d = run(['这不是我们的错。', '跟我们没关系，是快递的问题。']);
    expect(d.st.end, 'lost');
  });

  test('saying nothing understandable wears patience out', () {
    final d = run(List.filled(10, '今天天气很好。'));
    expect(d.st.end, 'lost');
    expect(d.turns.length, lessThanOrEqualTo(6));
  });

  test('refusing any compensation twice ends fair or lost, never stuck', () {
    final d = run(['对不起。', '因为缺货。', '明天送到。', '我们不能打折。', '补偿我们给不了。', '谢谢。']);
    expect(d.over, isTrue);
    expect(d.st.compensation, isFalse);
  });

  test('random talks always end within 12 turns and reach every ending', () {
    const pool = [
      '对不起', '真的很抱歉，给您添麻烦了', '这不是我们的错', '因为海关查验耽误了', '仓库缺货了', '我们明天重新发货', '下周一送到',
      '我们会尽快', '星期四之前送到', '给您打九折', '给您打九五折', '运费我们承担', '我们不能打折', '补偿我们给不了', '谢谢您的理解',
      '期待下次合作', '好的', '今天天气很好', '嗯', '我理解您的心情', '您最晚什么时候要？',
    ];
    final ends = <String>{};
    for (var seed = 0; seed < 3000; seed++) {
      final rnd = Random(seed);
      final d = TalkDialog(lateDelivery, seed: seed)..open();
      var n = 0;
      while (!d.over) {
        final s = pool[rnd.nextInt(pool.length)];
        d.reply(s, nlu.said([s]));
        n++;
        expect(n, lessThanOrEqualTo(12));
      }
      ends.add(d.st.end!);
      final r = coach(d);
      expect(r.total, inInclusiveRange(0, 100));
    }
    expect(ends, containsAll(['good', 'fair', 'lost']));
  });
}
