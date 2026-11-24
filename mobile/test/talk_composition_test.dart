import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/recognition.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final cases = [
    for (final name in ['composed_cases', 'scope_cases'])
      ...(jsonDecode(File('test/talk/$name.json').readAsStringSync()) as List).cast<Map<String, dynamic>>(),
  ];
  final model = File('../content/talk/model/talk_model.json')
      .readAsStringSync();
  final nlu = TalkNlu(model: TalkModel.fromJson(model, soundFrom, soundTo));
  for (final item in cases) {
    final text = item['text'] as String;
    test(text, () {
      final scenario = switch (item['case']) {
        'billing' => invoiceMismatch,
        'replacement' => wrongBatch,
        _ => lateDelivery,
      };
      final d = TalkDialog(scenario)..open();
      for (final prior
          in (item['before'] as List? ?? const []).cast<String>()) {
        final reading = readTalkSpeech(nlu, d, [prior]).primary;
        d.reply(prior, reading.frames);
      }
      final reading = readTalkSpeech(nlu, d, [text]).primary;
      d.reply(text, reading.frames);
      final actual = {
        'reason': d.st.reason,
        'refund': d.st.refundCents,
        'invoice': d.st.invoiceCorrected,
        'arrival': d.st.offeredDays,
        'dispatch': d.st.dispatchDays,
        'replacement': d.st.replacement,
        'compensation': d.st.compensation,
        'discount': d.st.offeredPct,
      };
      final keys = actual.keys.where(item.containsKey);
      expect(
        {for (final key in keys) key: actual[key]},
        {for (final key in keys) key: item[key]},
        reason: '${reading.frames}',
      );
    });
  }
}
