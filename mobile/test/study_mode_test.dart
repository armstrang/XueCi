// The HSK | BCT switch: Home and the study screens follow it, HSKK goes away and Tests stays; the drop of water
// in the tab bar is filmed in a few frames (test/goldens/mode-*.png, look at them).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/bct_rank.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });

  testWidgets('BCT mode: HSKK merges away, Tests stays, back to HSK', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"dark"', 'xc_onb': '1'}, lang: 'id'));
    t.view.physicalSize = const Size(412, 892) * 2.625;
    t.view.devicePixelRatio = 2.625;
    app.deviceCores = 8;
    await t.pumpWidget(const XueCiApp());
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('HSKK'), findsOneWidget);
    await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/mode-0-hsk.png'));
    app.toastV.value = null;
    app.setStudy('bct');
    await t.pump(const Duration(milliseconds: 20));
    for (var i = 1; i <= 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
      await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/mode-1-mid$i.png'));
    }
    await t.pump(const Duration(milliseconds: 900));
    await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/mode-2-bct.png'));
    expect(app.bctMode, isTrue);
    expect(app.screen, 'home');
    app.go('hskk'); // no HSKK in BCT mode: it lands on Home
    await t.pump(const Duration(milliseconds: 300));
    expect(app.screen, 'home');
    app.go('exam');
    await t.pump(const Duration(milliseconds: 900));
    expect(app.screen, 'exam');
    app.setStudy('hsk');
    await t.pump(const Duration(milliseconds: 250));
    await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/mode-3-back.png'));
    await t.pump(const Duration(milliseconds: 900));
    expect(app.bctMode, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 8));
  });

  testWidgets('BCT rank: words and a passed paper, one rank after another', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"dark"', 'xc_onb': '1'}, lang: 'id'));
    final a = app.lm.bct!.wordsOf('a'), b = app.lm.bct!.wordsOf('b');
    expect(a.length, greaterThan(500));
    expect(b.length, 4000);
    BctRankInfo info() => bctRankInfo(app.bprog, app.lm.bct, app.lm.mocks);
    expect(info().rank, 0);
    void solid(List<dynamic> ws, int n) {
      for (final w in ws.take(n)) {
        app.bprog.j[w.h as String] = [1, 30.0, 0, 5, 5];
      }
    }
    solid(a, 130);
    expect(info().rank, 0);
    expect(info().waitExam, isTrue);
    expect(info().examBook, 'a');
    app.lm.mocks = [
      [1, 101, 50, 100, [], 600], // under 60 %
    ];
    expect(info().rank, 0);
    app.lm.mocks = [
      [1, 101, 72, 100, [], 600],
    ];
    expect(info().rank, 1);
    // many words but no paper for B: stays at 主管 at most, and a rank is never skipped
    solid(b, 1500);
    expect(info().rank, 2);
    expect(info().waitExam, isTrue);
    expect(info().examBook, 'b');
    app.lm.mocks = [
      [1, 101, 72, 100, [], 600],
      [2, 102, 80, 100, [], 600],
    ];
    expect(info().rank, 3);
    expect(info().stage, inInclusiveRange(0, 3));
    // the screens draw with it
    app.setStudy('bct');
    t.view.physicalSize = const Size(412, 892) * 2.625;
    t.view.devicePixelRatio = 2.625;
    app.deviceCores = 8;
    app.toastV.value = null;
    await t.pumpWidget(const XueCiApp());
    await t.pump(const Duration(milliseconds: 900));
    await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/bct-rank-home.png'));
    app.go('bctstats');
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 900));
    await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/bct-rank-stats.png'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 8));
  });
}
