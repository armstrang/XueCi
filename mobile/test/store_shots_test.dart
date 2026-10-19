// Play Store pictures: phone screenshots at 1080×1920 in Indonesian and English, written to store/shots/<lang>/ by
//   STORE=1 flutter test --no-pub --update-goldens test/store_shots_test.dart
// (skipped otherwise). art/make_banner.py builds the feature graphic from them.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

const _dpr = 2.625;
const _size = Size(1080 / _dpr, 1920 / _dpr);

Future<void> _shot(WidgetTester t, String path, {void Function()? before, void Function()? after, Future<void> Function()? act}) async {
  t.view.physicalSize = _size * _dpr;
  t.view.devicePixelRatio = _dpr;
  t.platformDispatcher.textScaleFactorTestValue = 1;
  before?.call();
  await t.pumpWidget(const XueCiApp());
  await t.pump(const Duration(milliseconds: 600));
  if (act != null) await act();
  if (after != null) {
    after();
    await t.pump(const Duration(milliseconds: 100));
  }
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
  for (final lang in ['id', 'en']) {
    Map<String, String> s([Map<String, String> more = const {}]) => {...sample(), 'hsk16_theme': '"light"', 'xc_onb': '1', ...more};
    testWidgets('$lang home', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/1-home');
    });
    testWidgets('$lang soul', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/2-soul', before: () => app.go('soul'));
    });
    testWidgets('$lang card', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/3-card', before: () => app.go('card'));
    });
    testWidgets('$lang quiz', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":2,"qt":"c"}'}), lang: lang));
      await _shot(t, '$lang/4-quiz', before: () => app.go('quiz'));
    });
    testWidgets('$lang list', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/5-list', before: () => app.go('list'));
    });
    testWidgets('$lang card back', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/6-card-back', before: () => app.go('card'), after: () => app.runner.cardDont(app.runner.run!.cur!));
    });
    testWidgets('$lang tones', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":1,"qt":"s"}'}), lang: lang));
      await _shot(t, '$lang/7-tones', before: () => app.go('quiz'));
    });
    testWidgets('$lang stats', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/8-stats', before: () => app.go('stats'));
    });
    testWidgets('$lang mock', skip: !on, (t) async {
      Native.I.ttsTest = 'ready';
      await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":3,"qt":"mock"}'}), lang: lang));
      await _shot(t, '$lang/9-mock', before: () => app.go('quiz'));
      Native.I.ttsTest = 'missing';
    });
    testWidgets('$lang placement', skip: !on, (t) async {
      await t.runAsync(() => bootApp({'hsk16_theme': '"light"', 'xc_onb': '1'}, lang: lang));
      await _shot(
        t,
        '$lang/10-placement',
        before: () => app.go('placement'),
        act: () async {
          await t.tap(find.text(app.t.ptBegin));
          await t.pump(const Duration(milliseconds: 300));
          for (var i = 0; i < 6; i++) {
            await t.tap(find.text(app.t.idk));
            await t.pump(const Duration(milliseconds: 300));
          }
        },
      );
    });
    testWidgets('$lang tribulation', skip: !on, (t) async {
      Native.I.ttsTest = 'ready';
      await t.runAsync(() => bootApp({...sample(strong: true), 'hsk16_theme': '"light"', 'xc_onb': '1'}, lang: lang));
      await _shot(t, '$lang/11-bt', before: () => app.go('bt'));
      Native.I.ttsTest = 'missing';
    });
    testWidgets('$lang realm', skip: !on, (t) async {
      await t.runAsync(() => bootApp(s(), lang: lang));
      await _shot(t, '$lang/12-realm', after: () => app.openRealm!(navKey.currentContext!));
    });
  }
}
