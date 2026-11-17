// The main screens with the phone on its side (800×360) and on a very small phone (320×568): an overflowing row
// throws here. Screenshots go to test/goldens/rot-*.png.
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:flutter/material.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample, shot;

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
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
  final sizes = {'land': const Size(800, 360), 'tiny': const Size(320, 568)};
  for (final sz in sizes.entries) {
    for (final e in screens.entries) {
      testWidgets('${sz.key}: ${e.key}', (t) async {
        await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1'}, lang: 'id'));
        await shot(t, 'rot-${sz.key}-${e.key}', size: sz.value, before: e.value);
      });
    }
  }
}
