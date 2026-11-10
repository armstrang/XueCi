// A film of the living layer for review (QI=1): frames into test/qi/ (not committed), joined with ffmpeg.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

void main() {
  final on = Platform.environment['QI'] == '1';
  setUpAll(() async {
    noBlur = false;
    await loadFonts();
  });
  var n = 0;
  Future<void> film(WidgetTester t, String th, double secs) async {
    for (var i = 0; i < (secs * 30).round(); i++) {
      await t.pump(const Duration(microseconds: 33333));
      await expectLater(find.byType(XueCiApp), matchesGoldenFile('qi/$th-${(n++).toString().padLeft(4, '0')}.png'));
    }
  }

  for (final th in ['dark', 'light']) {
    testWidgets('film $th', skip: !on, (t) async {
      n = 0;
      await t.runAsync(() => bootApp({...sample(strong: true), 'hsk16_theme': '"$th"', 'xc_onb': '1', 'hsk16_ui': '{"level":2,"qt":"m"}'}, lang: 'id'));
      app.deviceCores = 8;
      app.fxPref = 'full';
      t.view.physicalSize = const Size(412, 892) * 1.75;
      t.view.devicePixelRatio = 1.75;
      await t.pumpWidget(const XueCiApp());
      await t.pump(const Duration(milliseconds: 600));
      await film(t, th, 4.5);
      app.go('quiz');
      await film(t, th, 1.4);
      var it = app.runner.run!.cur!;
      app.runner.qAnswer(it, it.ans);
      await film(t, th, 1.6);
      app.runner.next();
      await film(t, th, .8);
      it = app.runner.run!.cur!;
      app.runner.qAnswer(it, (it.ans + 1) % 4);
      await film(t, th, 1.4);
      app.go('bt');
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text(app.t.btBegin));
      await film(t, th, 3.5);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 8));
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
