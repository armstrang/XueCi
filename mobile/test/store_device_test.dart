// Screenshots as the real devices show the app: Galaxy S26 (1080 wide, at Play's longest 2:1), a Samsung Galaxy Tab
// (1600×2560, landscape too) and an OPPO Pad Mini (1680×2520, landscape too), with the phone's status and gesture
// bar room; written to store/device/<device>-<lang>/ by
//   STORE=1 flutter test --no-pub --update-goldens test/store_device_test.dart
// then art/make_device_bars.py draws the status bar (time, signal, Wi-Fi, battery) into them.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/speech.dart';
import 'package:xueci/ui/glass.dart';

import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

class Dev {
  final String name;
  final Size px;
  final double dpr, top, bottom; // status bar and gesture bar, in dp
  const Dev(this.name, this.px, this.dpr, this.top, this.bottom);
}

const devices = [
  Dev('s26', Size(1080, 2160), 2.625, 34, 18),
  Dev('galaxytab', Size(1600, 2560), 2.0, 28, 18),
  Dev('galaxytab-land', Size(2560, 1600), 2.0, 28, 18),
  Dev('oppopadmini', Size(1680, 2520), 2.1, 28, 18),
  Dev('oppopadmini-land', Size(2520, 1680), 2.1, 28, 18),
];

Future<void> _shot(WidgetTester t, Dev d, String path, {void Function()? before, void Function()? after}) async {
  t.view.physicalSize = d.px;
  t.view.devicePixelRatio = d.dpr;
  t.view.padding = FakeViewPadding(top: d.top * d.dpr, bottom: d.bottom * d.dpr);
  t.view.viewPadding = FakeViewPadding(top: d.top * d.dpr, bottom: d.bottom * d.dpr);
  t.platformDispatcher.textScaleFactorTestValue = 1;
  before?.call();
  await t.pumpWidget(const XueCiApp());
  await t.pump(const Duration(milliseconds: 600));
  if (after != null) {
    after();
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pump(const Duration(milliseconds: 1500));
  await expectLater(find.byType(XueCiApp), matchesGoldenFile('../../store/device/$path.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
  t.view.reset();
}

void main() {
  final on = Platform.environment['STORE'] == '1';
  setUpAll(() async {
    noBlur = false;
    await loadFonts();
  });
  for (final lang in ['id', 'en']) {
    Map<String, String> s([Map<String, String> more = const {}]) => {...sample(), 'hsk16_theme': '"light"', 'xc_onb': '1', ...more};
    for (final d in devices) {
      final dir = '${d.name}-$lang';
      testWidgets('$dir home', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s(), lang: lang));
        await _shot(t, d, '$dir/1-home');
      });
      testWidgets('$dir card', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s(), lang: lang));
        await _shot(t, d, '$dir/2-card', before: () => app.go('card'));
      });
      testWidgets('$dir quiz', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":2,"qt":"c"}'}), lang: lang));
        await _shot(t, d, '$dir/3-quiz', before: () => app.go('quiz'));
      });
      testWidgets('$dir speak', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":2,"qt":"u"}'}), lang: lang));
        await _shot(t, d, '$dir/4-speak', before: () {
          app.canListen = true;
          app.go('quiz');
        }, after: () {
          final it = app.runner.run!.cur!;
          app.runner.qPrepare(it);
          final n = it.d.h.runes.length;
          app.runner.qSpoken(it, SpeakResult([for (var i = 0; i < n; i++) true], it.d.h));
        });
      });
      testWidgets('$dir tones', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s({'hsk16_ui': '{"level":1,"qt":"s"}'}), lang: lang));
        await _shot(t, d, '$dir/5-tones', before: () => app.go('quiz'));
      });
      testWidgets('$dir list', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s(), lang: lang));
        await _shot(t, d, '$dir/6-list', before: () => app.go('list'));
      });
      testWidgets('$dir soul', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s(), lang: lang));
        await _shot(t, d, '$dir/7-soul', before: () => app.go('soul'));
      });
      testWidgets('$dir stats', skip: !on, (t) async {
        await t.runAsync(() => bootApp(s(), lang: lang));
        await _shot(t, d, '$dir/8-stats', before: () => app.go('stats'));
      });
    }
  }
}
