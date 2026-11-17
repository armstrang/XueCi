// The main screens with the phone's text at 160% on a small phone: an overflowing row or a cut-off label throws
// here, so a layout that breaks with large text fails the build. Screenshots go to test/goldens/big-*.png.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample, shot;

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
  const small = Size(360, 680);
  final screens = <String, void Function()>{
    'home': () => app.go('home'),
    'list': () => app.go('list'),
    'card': () => app.go('card'),
    'quiz': () => app.go('quiz'),
    'stats': () => app.go('stats'),
    'soul': () => app.go('soul'),
    'hskk': () => app.go('hskk'),
    'exam': () => app.go('exam'),
  };
  for (final lang in ['id', 'en', 'th', 'vi']) {
    for (final e in screens.entries) {
      testWidgets('large text, $lang: ${e.key}', (t) async {
        await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1'}, lang: lang));
        await shot(t, lang == 'id' ? 'big-${e.key}' : 'big-$lang-${e.key}', size: small, fs: 1.6, before: e.value);
      });
    }
  }
}
