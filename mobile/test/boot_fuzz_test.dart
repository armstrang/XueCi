// A damaged store must never keep the app from starting: each progress key holding rubbish (cut JSON, the wrong type,
// null) still boots, and the engine and the screens' numbers can be worked out from what is left.
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';

final clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const keys = [
    'mm_stats', 'mm_lang', 'hsk16_ui', 'hsk16_theme', 'xc_mem', 'xc_log', 'xc_logA', 'xc_goal', 'xc_w', 'xc_fit', 'xc_onb',
    'xc_lvl', 'xc_rem', 'xc_tests', 'xc_rest', 'xc_game', 'xc_amb', 'xc_note', 'xc_days', 'xc_bk', 'xc_res', 'xc_fx',
    'xc_fxd', 'xc_mock', 'xc_spk', 'xc_dn',
  ];
  const bad = ['', '{', '[1,', 'null', '7', '"x"', '[]', '{}', '{"a":"b"}', '[null,null]', '1e999', '{"1:爱":"x"}', '{"1:爱":[1]}'];
  for (final k in keys) {
    test('boots with rubbish in $k', () async {
      Native.off = true;
      for (final v in bad) {
        final a = await App.boot(
          backend: MemoryBackend({'xc_schema': '3', k: v}),
          random: LcgRandom(3),
          clock: () => clockMin,
          tzOffset: -420,
          sysLang: 'en',
        );
        a.lm.baseLevel();
        a.lm.plan();
        a.lm.streak();
        a.lm.studyDays();
      }
    });
  }
}
