// v1.4 the word widget's words (App.wordsPayload → XueciWordWidget.kt)
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';

import 'screens_test.dart' show bootApp, sample;

void main() {
  testWidgets('the widget gets every word of the realm level, in list order, with tones and meanings', (t) async {
    await t.runAsync(() => bootApp(sample(), lang: 'id'));
    final p = app.wordsPayload();
    final l = p['l'] as int;
    expect(l, app.widgetLevel);
    final w = p['w'] as List;
    expect(w.length, app.by(l).length);
    var lastU = 0;
    for (final x in w.cast<List>()) {
      final u = x[0] as int;
      expect(u >= lastU, isTrue, reason: 'units in order');
      lastU = u;
      final syl = (x[2] as String).split(' ');
      expect((x[3] as String).length, syl.length, reason: '${x[1]}: one tone per syllable');
      expect(RegExp(r'^[1-5]+$').hasMatch(x[3] as String), isTrue);
      expect((x[4] as String).isNotEmpty, isTrue, reason: '${x[1]} has a meaning');
    }
    expect((p['lb'] as List).length, 4);
    // 凡人 and the first realms study HSK 1; nothing past the open levels
    expect(l >= 1 && l <= 6, isTrue);
  });
}
