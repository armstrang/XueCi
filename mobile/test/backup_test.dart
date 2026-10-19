// Backup codes: this app's codes restore, and codes made by the WebView app (deflate-raw + base64url) read the same.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/backup.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';

final clockMin = jsRound((DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch - fsrs.epochMs) / 6e4);

Future<App> boot(Map<String, String> saved) async {
  Native.off = true;
  return App.boot(backend: MemoryBackend(Map.of(saved)), random: LcgRandom(3), clock: () => clockMin, tzOffset: -420, sysLang: 'en');
}

/// made by Node's CompressionStream('deflate-raw'), as backup.js does
const jsCode =
    'XUECI1:bZCxTsNADIbf5Z9d6XxtqPDIa5xuODVHiZq0obkUquhGJBZ2Bh4ACTGw8UBEvAYyQQikerJ-2_9ne0BoWwhu-7iqQDhALCEkCC_PzG8QuhRSBxnA8nn_BnEFMbH1BJbx7gXiLBmae8K5fLw_jK-P49MzxLG2-UxoYvNnfMANxC1obqiwSvCE5r9Cc1L7y5Nqd1KtIMXPvhvIVMqZsN6FWpkJgjoeYg1CPZ1ahhQhsMYuZ4ZnhkFow0q10KcdMmEfuwRxumKKnX7BeR08asbGEBv2hL5SxGQvTOi3Vbo4ft8MsZlwrfhGHeuwXUNQlSCkq9gorQz7DfIX';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a code from the WebView app reads and applies', () async {
    app = await boot({});
    final b = await readCode(app, 'Backup XueCi:\n$jsCode\n— thanks');
    expect(b, isNotNull);
    expect(b!.stats.keys.toSet(), {'1:爱', '1:八'}); // unknown ids are dropped
    expect(b.stats['1:爱'], [5, 1, 12]);
    expect(b.mem!.keys, ['1:爱']);
    expect(await applyCode(app, b), isTrue);
    expect(app.lm.stats['1:爱']!.sublist(0, 2), [5, 1]);
    expect(app.lm.stats['1:八'], [2, 0, 3]);
    expect(app.lm.mem['1:爱']!.w[1], 30);
    expect(app.lm.goal!['lv'], 2);
    expect(app.lm.rest, [0]);
    expect(app.level, 1);
    expect(app.unitBy[1], 2);
    expect(app.qType, 'm');
    expect(app.langPref, 'id');
    expect(app.theme, 'dark');
  });

  test('this app\'s code round-trips', () async {
    app = await boot({});
    await applyCode(app, (await readCode(app, jsCode))!);
    final code = makeCode(app);
    expect(code, startsWith('XUECI1:'));
    // the JSON inside is what backup.js writes
    final raw = utf8.decode(ZLibCodec(raw: true).decode(base64Url.decode(base64Url.normalize(code.substring(7)))));
    final o = json.decode(raw) as Map;
    expect(o['app'], 'xueci');
    expect(o['v'], 2);
    expect((o['ui'] as Map)['unitBy'], containsPair('1', 2));
    final other = await boot({});
    app = other;
    final b = await readCode(other, code);
    expect(b, isNotNull);
    await applyCode(other, b!);
    expect(other.lm.stats['1:爱']!.sublist(0, 2), [5, 1]); // the level comes from the memory state
    expect(other.lm.mem['1:爱']!.w[1], 30);
  });

  test('an edited code that only adds the gate loses it', () async {
    app = await boot({});
    final o = {
      'app': 'xueci',
      'v': 2,
      'at': 1760000000000,
      'stats': {'1:爱': [1, 0, 1]},
      'lvl': {'lv': 6, 'src': 'bt', 'at': 1000, 'r': 7, 'gate': 2000, 'hist': [[7, 2000, 'bt', 3]]},
    };
    final code = 'XUECI0:${base64Url.encode(utf8.encode(json.encode(o))).replaceAll('=', '')}';
    final b = await readCode(app, code);
    expect(b, isNotNull);
    expect(b!.gate, isFalse);
  });

  test('broken codes are refused', () async {
    app = await boot({});
    expect(await readCode(app, 'nothing here'), isNull);
    expect(await readCode(app, 'XUECI1:AAAA'), isNull);
  });
}
