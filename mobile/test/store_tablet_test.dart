// Play Store tablet screenshots (7" 1200×1920, 10" 1600×2560), Indonesian, written to store/shots/tab7|tab10/ by
//   STORE=1 flutter test --no-pub --update-goldens test/store_tablet_test.dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

Future<void> _shot(WidgetTester t, String path, Size px, {void Function()? before}) async {
  t.view.physicalSize = px;
  t.view.devicePixelRatio = px.width / 460; // about 460 dp wide: the app's phone layout, filled out
  t.platformDispatcher.textScaleFactorTestValue = 1;
  before?.call();
  await t.pumpWidget(const XueCiApp());
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 1500));
  await expectLater(find.byType(XueCiApp), matchesGoldenFile('../../store/shots/$path.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
}

void main() {
  final on = Platform.environment['STORE'] == '1';
  setUpAll(() async {
    noBlur = false;
    await loadFonts();
  });
  const sizes = {'tab7': Size(1200, 1920), 'tab10': Size(1600, 2560)};
  Map<String, String> s([Map<String, String> more = const {}]) => {...sample(), 'hsk16_theme': '"light"', 'xc_onb': '1', ...more};
  for (final lang in ['id', 'en']) sizes.forEach((d0, px) {
    final dir = lang == 'id' ? d0 : '$d0-en';
    testWidgets('$dir home', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$dir/1-home', px);
    });
    testWidgets('$dir soul', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$dir/2-soul', px, before: () => app.go('soul'));
    });
    testWidgets('$dir card', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$dir/3-card', px, before: () => app.go('card'));
    });
    testWidgets('$dir quiz', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":2,"qt":"c"}'}), lang: lang));
      await _shot(t, '$dir/4-quiz', px, before: () => app.go('quiz'));
    });
    testWidgets('$dir mock', skip: !on, (t) async {
      Native.I.ttsTest = 'ready';
      await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":3,"qt":"mock"}'}), lang: lang));
      await _shot(t, '$dir/5-mock', px, before: () => app.go('quiz'));
      Native.I.ttsTest = 'missing';
    });
  });
}
