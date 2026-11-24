import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/coach.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final model = TalkModel.fromJson(
    File('../content/talk/model/talk_model.json').readAsStringSync(),
    soundFrom,
    soundTo,
  );
  final nlu = TalkNlu(model: model);

  TalkDialog play(List<String> lines) {
    final dialog = TalkDialog(wrongBatch)..open();
    for (final text in lines) {
      dialog.reply(text, nlu.said([text]));
    }
    return dialog;
  }

  test('the correct replacement and on-time arrival can settle the case without a discount', () {
    final d = play(['我们给您换成蓝色款，周四送到。', '谢谢您的理解。']);
    expect(d.st.replacement, isTrue);
    expect(d.st.delivery, isTrue);
    expect(d.st.compensation, isFalse);
    expect(d.st.end, isNotNull);
    expect(coach(d).parts.map((p) => p.name), contains('Barang pengganti'));
    expect(coach(d).parts.map((p) => p.name), isNot(contains('Kompensasi')));
  });

  test('an apology, refund, or timeline for the wrong color cannot settle the case', () {
    for (final text in ['非常抱歉。', '我们会给您退款。', '给您换成红色款，周四到。']) {
      final d = play([text]);
      expect(d.st.replacement, isFalse, reason: text);
      expect(d.st.end, isNull);
      expect(d.turns.last.situation, 'whichItem', reason: text);
    }
  });

  test('an item in a quote or a question cannot settle the case', () {
    final d = play(['您说要换成蓝色款。', '能不能给您换成蓝色款？']);
    expect(d.st.replacement, isFalse);
    expect(d.turns.last.situation, 'whichItem');
  });

  test('a short answer to the color question can complete the earlier schedule', () {
    final d = play(['这批货周四到。', '蓝色的。']);
    expect(d.st.replacement, isTrue);
    expect(d.st.offeredDays, 2);
    expect(d.turns.last.situation, 'settled');
  });

  test('a withdrawal clears the promise and a later offer can repair it', () {
    final d = play(['给您换成蓝色款，周四送到。', '不好意思，蓝色没有库存。']);
    expect(d.st.replacement, isFalse);
    expect(d.st.delivery, isFalse);
    expect(d.turns.last.situation, 'whichItem');
    const retry = '我们给您补发蓝色款，周四下午送到。';
    d.reply(retry, nlu.said([retry]));
    expect(d.st.replacement, isTrue);
    expect(d.st.delivery, isTrue);
  });

  test('the correct item arriving too late is still rejected', () {
    final d = play(['给您换成蓝色款，周五才能送到。']);
    expect(d.st.replacement, isTrue);
    expect(d.st.delivery, isFalse);
    expect(d.turns.last.situation, 'tooLate');
  });
}
