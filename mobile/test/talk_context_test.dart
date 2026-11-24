import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final cases = jsonDecode(File('test/talk/context_cases.json').readAsStringSync()) as List;
  final model = TalkModel.fromJson(
    File('../content/talk/model/talk_model.json').readAsStringSync(),
    soundFrom,
    soundTo,
  );
  final nlu = TalkNlu(model: model);

  for (final c in cases.cast<Map<String, dynamic>>()) {
    test(c['name'] as String, () {
      final d = TalkDialog(lateDelivery);
      d.open();
      for (final t in (c['turns'] as List).cast<Map<String, dynamic>>()) {
        final text = t['text'] as String;
        final frames = nlu.said([text]);
        final score = d.turnScore(text, frames);
        d.reply(text, frames);
        final actual = {
          'score': score,
          'arrival': d.st.offeredDays,
          'dispatch': d.st.dispatchDays,
          'apology': d.st.apology,
          'delivery': d.st.delivery,
          'compensation': d.st.compensation,
          'reply': d.turns.last.situation,
        };
        for (final key in actual.keys.where(t.containsKey)) {
          expect(actual[key], t[key], reason: '$key for $text ($frames)');
        }
      }
    });
  }
}
