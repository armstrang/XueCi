// A rough probe, skipped unless PERF=1 (debug mode is several times slower than a release build, so compare the
// numbers with each other, not with a phone): how long each screen takes to build, lay out and paint its first frame.
//   PERF=1 flutter test --no-pub test/perf_probe_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
  testWidgets('first frame per screen', skip: Platform.environment['PERF'] == null, (t) async {
    await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1', 'hsk16_theme': '"dark"'}));
    t.view.physicalSize = const Size(412, 892);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const XueCiApp());
    await t.pump(const Duration(seconds: 1));
    final out = <String>[];
    for (var round = 0; round < 3; round++) {
      for (final s in ['list', 'card', 'quiz', 'soul', 'stats', 'home']) {
        final sw = Stopwatch()..start();
        app.go(s);
        final b = t.binding;
        b.buildOwner!.buildScope(b.rootElement!);
        final tb = sw.elapsedMicroseconds;
        b.rootPipelineOwner.flushLayout();
        final tl = sw.elapsedMicroseconds;
        b.rootPipelineOwner.flushCompositingBits();
        b.rootPipelineOwner.flushPaint();
        final tp = sw.elapsedMicroseconds;
        await t.pump();
        final first = sw.elapsedMicroseconds;
        if (round == 2) out.add('$s: build ${tb ~/ 1000} layout ${(tl - tb) ~/ 1000} paint ${(tp - tl) ~/ 1000} ms');
        await t.pump(const Duration(milliseconds: 16));
        final second = sw.elapsedMicroseconds - first;
        await t.pump(const Duration(seconds: 1));
        if (round == 2) out.add('$s: first ${(first / 1000).toStringAsFixed(1)} ms, next ${(second / 1000).toStringAsFixed(1)} ms');
      }
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      app.changed();
      await t.pump();
    }
    out.add('home: app.changed() rebuild ${(sw.elapsedMicroseconds / 10000).toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print(out.join('\n'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 8));
  });
}
