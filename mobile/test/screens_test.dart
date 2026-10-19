// The screens drawn with the real fonts and data, at phone sizes, in each theme: screenshots for review
// (test/goldens/*.png, written with --update-goldens) and a check that nothing overflows.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/backup_sheet.dart';
import 'package:xueci/ui/settings.dart';
import 'package:xueci/ui/share.dart';
import 'package:xueci/ui/shell.dart';

Future<void> loadFonts() async {
  final fams = {
    'Jakarta': ['pjs-400', 'pjs-500', 'pjs-600', 'pjs-700', 'pjs-800', 'pjs-italic-500'],
    'NotoSansThai': ['thai-400', 'thai-600', 'thai-700'],
    'NotoSansSC': ['sans-sc-400', 'sans-sc-700'],
    'NotoSerifSC': ['serif-sc-700', 'serif-sc-900'],
  };
  for (final e in fams.entries) {
    final l = FontLoader(e.key);
    for (final f in e.value) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f.ttf').readAsBytesSync())));
    }
    await l.load();
  }
}

int clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

Future<void> bootApp(Map<String, String> saved, {String lang = 'en'}) async {
  Native.off = true;
  app = await App.boot(
    backend: MemoryBackend(Map.of(saved)),
    random: LcgRandom(3),
    clock: () => clockMin,
    tzOffset: -420,
    sysLang: lang,
  );
}

Future<void> shot(
  WidgetTester t,
  String name, {
  Size size = const Size(412, 892),
  double fs = 1,
  void Function()? before,
  void Function()? after,
}) async {
  t.view.physicalSize = size * 2.625;
  t.view.devicePixelRatio = 2.625;
  t.platformDispatcher.textScaleFactorTestValue = fs;
  before?.call();
  await t.pumpWidget(const XueCiApp());
  await t.pump(const Duration(milliseconds: 600));
  if (after != null) {
    after();
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pump(const Duration(milliseconds: 700));
  await expectLater(find.byType(XueCiApp), matchesGoldenFile('goldens/$name.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 8));
}

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
  tearDown(() {});

  testWidgets('home: new learner, light', (t) async {
    await t.runAsync(() => bootApp({'hsk16_theme': '"light"'}));
    await shot(t, 'home-new-light');
  });

  testWidgets('home: progress, dark', (t) async {
    await t.runAsync(() => bootApp(sample(), lang: 'id'));
    await shot(t, 'home-progress-dark');
  });

  testWidgets('home: small phone, black, Thai', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"black"'}, lang: 'th'));
    await shot(t, 'home-small-black', size: const Size(360, 680));
  });

  runs();

  testWidgets('home: large text, Vietnamese', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"light"'}, lang: 'vi'));
    await shot(t, 'home-bigtext', size: const Size(360, 760), fs: 1.6);
  });
}

void runs() {
  testWidgets('list', (t) async {
    await t.runAsync(() => bootApp(sample()));
    await shot(t, 'list', before: () => app.go('list'));
  });
  testWidgets('card front', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"light"'}));
    await shot(t, 'card-front', before: () => app.go('card'));
  });
  testWidgets('card back', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"light"'}));
    await shot(t, 'card-back', before: () => app.go('card'), after: () {
      final it = app.runner.run!.cur!;
      app.runner.cardDont(it);
    });
  });
  for (final q in ['m', 's', 'c', 'p', 't', 'f']) {
    testWidgets('quiz $q', (t) async {
      await t.runAsync(() => bootApp({...sample(), 'hsk16_ui': '{"level":2,"qt":"$q"}'}, lang: 'id'));
      await shot(t, 'quiz-$q', before: () => app.go('quiz'));
    });
  }
  testWidgets('quiz feedback', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"light"', 'hsk16_ui': '{"level":1,"qt":"m"}'}));
    await shot(t, 'quiz-feedback', before: () => app.go('quiz'), after: () {
      final it = app.runner.run!.cur!;
      app.runner.qAnswer(it, (it.ans + 1) % 4);
    });
  });
  testWidgets('session summary', (t) async {
    await t.runAsync(() => bootApp(sample()));
    await shot(t, 'summary', before: () => app.go('quiz'), after: () {
      final r = app.runner.run!;
      for (final it in r.items.toList()) {
        if (r.cur == null) break;
        app.runner.qPrepare(r.cur!);
        final c = r.cur!;
        if (c.typed) {
          app.runner.qTyped(c, 'x');
        } else {
          app.runner.qAnswer(c, c.ans);
        }
        app.runner.next();
        it.hashCode;
      }
    });
  });
  testWidgets('stats', (t) async {
    await t.runAsync(() => bootApp(sample()));
    await shot(t, 'stats', before: () => app.go('stats'));
  });
  testWidgets('soul sea', (t) async {
    await t.runAsync(() => bootApp(sample()));
    await shot(t, 'soul', size: const Size(412, 2700), before: () => app.go('soul'));
  });
  testWidgets('realm sheet', (t) async {
    await t.runAsync(() => bootApp(sample(), lang: 'id'));
    await shot(t, 'realm-sheet', after: () => app.openRealm!(navKey.currentContext!));
  });
  testWidgets('share card', (t) async {
    await t.runAsync(() => bootApp(sample()));
    final png = (await t.runAsync(drawCard))!;
    Directory('test/goldens').createSync(recursive: true);
    File('test/goldens/share-card.png').writeAsBytesSync(png);
    expect(png.length, greaterThan(10000));
  });
  for (final (name, open) in <(String, void Function(BuildContext))>[
    ('settings', (c) => app.openSettings!(c)),
    ('streak', (c) => app.openStreak!(c)),
    ('goal', (c) => app.openGoal!(c, false)),
    ('backup', (c) => openBackup(c)),
    ('info', (c) => app.openInfo!(c, 'realm')),
    ('tour', (c) => openTour(c, false)),
  ]) {
    testWidgets('sheet $name', (t) async {
      await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1'}));
      await shot(t, 'sheet-$name', size: const Size(412, 1400), after: () => open(navKey.currentContext!));
    });
  }
  testWidgets('mock intro', (t) async {
    await t.runAsync(() => bootApp({...sample(), 'hsk16_ui': '{"level":3,"qt":"mock"}'}));
    await shot(t, 'mock-intro', before: () => app.go('quiz'));
  });
}

/// a learner at 筑基 (HSK 2) with progress on HSK 1–2
Map<String, String> sample() {
  final t = clockMin;
  final mem = <String, Object>{};
  final stats = <String, Object>{};
  final words = File('../web/data/vocab.json').readAsStringSync();
  final re = RegExp(r'"l":\s*([12]),\s*"n":\s*(\d+),.*?"h":\s*"([^"]+)"');
  var i = 0;
  for (final m in re.allMatches(words)) {
    final l = int.parse(m.group(1)!), n = int.parse(m.group(2)!);
    if (l == 2 && n > 120) continue;
    final s = l == 1 ? 20.0 + i % 40 : 2.0 + i % 9;
    final at = t - 1440 * (1 + i % 6);
    final sk = [4.0, s, at.toDouble(), 3.0, 2.0];
    mem['$l:${m.group(3)}'] = {'w': [4.0, s, at], 'm': sk, 'f': sk, 's': sk, 'i': at - 1440 * 20, 'k': at};
    stats['$l:${m.group(3)}'] = [5, 1, 0];
    i++;
  }
  final log = [
    for (var d = 0; d < 15; d++)
      for (var k = 0; k < 6; k++) [t - 1440 * d - k, '1:爱', 'm', 3, 40, 0, 0],
  ];
  return {
    'xc_mem': jsJson(mem),
    'mm_stats': jsJson(stats),
    'xc_log': jsJson(log),
    'xc_lvl': jsJson({'r': 2, 'lv': 2, 'src': 'test', 'at': t - 1440 * 30, 'm': 1, 'pt': [t - 1440 * 30], 'hist': [[2, t - 1440 * 30, 'test']]}),
    'xc_goal': jsJson({'t': 'exam', 'lv': 3, 'date': '2027-03-01', 'pace': 'auto'}),
    'hsk16_theme': '"dark"',
    'hsk16_ui': jsJson({'level': 2}),
  };
}
