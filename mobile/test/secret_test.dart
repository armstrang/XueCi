// HSK 7–9 stay a secret until the gate opens (Josh: a real surprise): nothing the app ships may name what lies past
// 飞升 outside the sealed files, and no screen may show it before the gate.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

const secret = ['真仙', '玄仙', '大罗', '仙门', 'HSK 7', 'HSK 8', 'HSK 9', '7–9', '7-9', 'xiānmén', 'zhēnxiān', 'xuánxiān', 'dàluó'];

void main() {
  test('the shipped sources and data name nothing past the gate', () {
    final found = <String>[];
    final roots = ['lib', 'android/app/src/main', 'assets/i18n', 'assets/data'];
    for (final r in roots) {
      final d = Directory(r);
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        final p = f.path;
        if (p.endsWith('.bin') || p.endsWith('.png') || p.endsWith('.webp') || p.endsWith('.jks')) continue;
        String s;
        try {
          s = f.readAsStringSync();
        } catch (_) {
          continue;
        }
        for (final w in secret) {
          if (s.contains(w)) found.add('$p: $w');
        }
      }
    }
    expect(found, isEmpty);
  });

  group('screens before the gate', () {
    setUpAll(() async {
      noBlur = true;
      await loadFonts();
    });
    // a learner at 飞升 by the placement test (the gate still closed): the most there is to see before it
    Map<String, String> at7() {
      final s = sample(strong: true);
      s['xc_lvl'] = s['xc_lvl']!.replaceFirst('"r":2', '"r":7');
      return s;
    }

    Future<List<String>> texts(WidgetTester t) async {
      await t.pump(const Duration(milliseconds: 700));
      return [
        for (final e in find.byWidgetPredicate((w) => w is Text || w is RichText).evaluate())
          e.widget is Text ? ((e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '') : (e.widget as RichText).text.toPlainText(),
      ];
    }

    for (final s in ['home', 'soul', 'stats', 'list']) {
      testWidgets('no leak: $s', (t) async {
        await t.runAsync(() => bootApp(at7()));
        expect(app.lm.realm(), 7);
        expect(app.band, isFalse);
        t.view.physicalSize = const Size(412, 3000) * 2.625;
        t.view.devicePixelRatio = 2.625;
        app.go(s);
        await t.pumpWidget(const XueCiApp());
        final all = (await texts(t)).join('\n');
        for (final w in secret) {
          expect(all.contains(w), isFalse, reason: '$s shows $w');
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 8));
      });
    }

    for (final (name, open) in <(String, void Function(BuildContext))>[
      ('realm sheet', (c) => app.openRealm!(c)),
      ('help', (c) => app.openInfo!(c, 'realm')),
      ('glossary', (c) => app.openInfo!(c, 'gloss')),
    ]) {
      testWidgets('no leak: $name', (t) async {
        await t.runAsync(() => bootApp(at7()));
        t.view.physicalSize = const Size(412, 3000) * 2.625;
        t.view.devicePixelRatio = 2.625;
        await t.pumpWidget(const XueCiApp());
        await t.pump(const Duration(milliseconds: 600));
        open(navKey.currentContext!);
        final all = (await texts(t)).join('\n');
        for (final w in secret) {
          expect(all.contains(w), isFalse, reason: '$name shows $w');
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 8));
      });
    }
  });
}
