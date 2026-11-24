import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final cases = jsonDecode(File('test/talk/decisions_v7.json').readAsStringSync()) as List;
  final nlu = TalkNlu(model: TalkModel.fromJson(
    File('../content/talk/model/talk_model.json').readAsStringSync(),
    soundFrom,
    soundTo,
  ));
  for (final example in cases.cast<Map<String, dynamic>>()) {
    test(example['name'] as String, () {
      final d = TalkDialog(example['case'] == 'wrongBatch' ? wrongBatch : lateDelivery)..open();
      for (final text in [...?example['before'] as List?, example['reply']].cast<String>()) {
        d.reply(text, nlu.said([text]));
      }
      final actual = {
        'dispatch': d.st.dispatchDays,
        'arrival': d.st.offeredDays,
        'delivery': d.st.delivery,
        'replacement': d.st.replacement,
      };
      final checked = actual.keys.where(example.containsKey);
      expect({for (final key in checked) key: actual[key]}, {for (final key in checked) key: example[key]},
          reason: '${example['reply']}');
    });
  }

  test('quote punctuation does not promote a courier estimate to the seller’s promise', () {
    for (final text in ['承运人说：周四送到。', '司机的原话是“周四送到”。']) {
      final d = TalkDialog(lateDelivery)..open();
      d.reply(text, nlu.said([text]));
      expect(d.st.delivery, isFalse, reason: text);
      expect(d.st.offeredDays, isNull, reason: text);
    }
  });
}
