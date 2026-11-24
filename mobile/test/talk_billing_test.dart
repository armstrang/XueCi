import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/coach.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/recognition.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final cases = (jsonDecode(
    File('test/talk/billing_cases.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  final nlu = TalkNlu(
    model: TalkModel.fromJson(
      File('../content/talk/model/talk_model.json').readAsStringSync(),
      soundFrom,
      soundTo,
    ),
  );

  for (final item in cases) {
    test(item['name'] as String, () {
      final d = TalkDialog(invoiceMismatch)..open();
      for (final text in [
        ...?item['before'] as List?,
        item['text'],
      ].cast<String>()) {
        final frames = readTalkSpeech(nlu, d, [text]).primary.frames;
        d.reply(text, frames);
      }
      expect(
        d.st.invoiceCorrected,
        item['corrected'],
        reason: '${item['text']}',
      );
      expect(d.st.refundCents, item['refund'], reason: '${item['text']}');
      expect(d.turns.last.situation, item['next'], reason: '${item['text']}');
    });
  }

  test('two amounts in alternate transcripts need confirmation', () {
    final d = TalkDialog(invoiceMismatch)..open();
    final reading = readTalkSpeech(nlu, d, ['给您退二百元。', '给您退一百元。']);
    expect(reading.alternative?.text, '给您退一百元。');
    expect(d.st.refundCents, isNull);
  });

  test('coaching checks each obligation and keeps a score out of 100', () {
    final d = TalkDialog(invoiceMismatch)..open();
    const text = '我为这次账单错误道歉，会重开发票，多扣的两百原路退。';
    final frames = nlu.said([text]);
    expect(d.turnScore(text, frames), inInclusiveRange(9, 10));
    d.reply(text, frames);
    d.reply('谢谢您的理解。', nlu.said(['谢谢您的理解。']));
    final r = coach(d);
    expect(d.over, isTrue);
    expect(r.parts.fold(0, (sum, p) => sum + p.max), 100);
    expect(r.parts.firstWhere((p) => p.name == 'Pengembalian uang').got, 30);
    expect(r.parts.firstWhere((p) => p.name == 'Faktur').got, 25);
  });
}
