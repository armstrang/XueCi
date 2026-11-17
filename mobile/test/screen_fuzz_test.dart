// Home, Stats and the Soul Sea drawn from a store with rubbish in one key: no exception.
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';
import 'package:flutter/widgets.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
  const keys = [
    'mm_stats', 'hsk16_ui', 'xc_mem', 'xc_log', 'xc_goal', 'xc_w', 'xc_lvl', 'xc_tests', 'xc_rest', 'xc_game',
    'xc_note', 'xc_days', 'xc_mock', 'xc_spk',
  ];
  const bad = ['{', '[]', '"x"', '7', '{"a":"b"}'];
  for (final k in keys) {
    testWidgets('screens with rubbish in $k', (t) async {
      t.view.physicalSize = const Size(412, 892) * 2.625;
      t.view.devicePixelRatio = 2.625;
      for (final v in bad) {
        await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1', k: v}));
        app.deviceCores = 8;
        for (final s in ['home', 'stats', 'soul', 'exam']) {
          app.go(s);
          await t.pumpWidget(const XueCiApp());
          await t.pump(const Duration(milliseconds: 500));
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 6));
        }
      }
    });
  }
}
