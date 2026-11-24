import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/recognition.dart';
import 'package:xueci/app/talk/sound.g.dart';

void main() {
  final model = TalkModel.fromJson(
    File('../content/talk/model/talk_model.json').readAsStringSync(),
    soundFrom,
    soundTo,
  );
  final nlu = TalkNlu(model: model);
  final cases = jsonDecode(File('test/talk/recognition_cases.json').readAsStringSync()) as List;

  for (final item in cases.cast<Map<String, dynamic>>()) {
    test(item['name'] as String, () {
      final dialog = TalkDialog(lateDelivery);
      final hyp = (item['hyp'] as List).cast<String>();
      final result = readTalkSpeech(nlu, dialog, hyp);
      final first = hyp.map((h) => h.trim()).firstWhere((h) => h.isNotEmpty);
      expect(result.primary.text, first);
      expect(result.alternative != null, item['choose'], reason: '${result.primary.frames}; ${nlu.said([hyp.last])}');
      final pureFrames = dialog.contextualFrames(first, nlu.said([first])).map((f) => f.toString()).toList();
      expect(result.primary.frames.map((f) => f.toString()), pureFrames);
      if (item['slot'] case final String key) {
        final alternate = result.alternative!;
        final a = dialog.commitments(result.primary.text, result.primary.frames);
        final b = dialog.commitments(alternate.text, alternate.frames);
        expect(a[key], isNotNull);
        expect(b[key], isNotNull);
        expect(a[key], isNot(b[key]));
      }
      expect(dialog.st.turns, 0);
    });
  }
}
