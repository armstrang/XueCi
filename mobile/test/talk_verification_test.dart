import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final model = File('../content/talk/model/talk_model.json').readAsStringSync();
  final nlu = TalkNlu(model: TalkModel.fromJson(model, soundFrom, soundTo));
  final cases = (jsonDecode(File('test/talk/verification_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  for (final example in cases) {
    final text = example['text'] as String;
    test(text, () {
      final keys = nlu.said([text]).map((f) => f.key).toSet();
      expect(keys, containsAll(example['expected'] as List? ?? const []));
      expect(keys.intersection((example['forbidden'] as List? ?? const []).cast<String>().toSet()), isEmpty);
    });
  }

  test('the dialogue does not turn an unconfirmed discount into compensation', () {
    final dialog = TalkDialog(lateDelivery)..open();
    const quote = '现在给您打八折，这样可以吗？';
    dialog.reply(quote, nlu.said([quote]));
    expect(dialog.st.offeredPct, isNull);
    expect(dialog.st.compensation, isFalse);
    const commit = '我们已经确定给您打九折，您觉得合适吗？';
    dialog.reply(commit, nlu.said([commit]));
    expect(dialog.st.offeredPct, 10);
  });
}
