// HSKK: the bank (levels, secrets, pinyin lines up with the hanzi), the marking of a talk, the tone check.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/hskk.dart';
import 'package:xueci/app/speech.dart';
import 'package:xueci/app/tone.dart';
import 'package:xueci/data/words.dart';

Vocab _vocab() {
  final core = json.decode(File('assets/data/core.json').readAsStringSync()) as Map;
  final cols = (core['cols'] as List).cast<String>();
  final words = [for (final r in core['rows'] as List) Word.row(cols, r as List)];
  final v = Vocab(words);
  final id = json.decode(File('assets/data/id.json').readAsStringSync()) as Map;
  final rows = id['rows'] as List;
  for (var i = 0; i < words.length; i++) {
    words[i].m['id'] = '${(rows[i] as List)[0]}';
    words[i].t['id'] = '${(rows[i] as List)[1]}';
  }
  return v;
}

Uint8List _tone(List<double Function(double)> sylHz, {double dur = .28, double gap = .06}) {
  final out = <int>[];
  for (final f in sylHz) {
    final n = (dur * toneRate).round();
    var ph = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      ph += 2 * math.pi * f(t) / toneRate;
      final env = math.min(1.0, math.min(t, 1 - t) * 12);
      final v = (math.sin(ph) * .5 + math.sin(2 * ph) * .25) * env * 12000;
      out.add(v.round());
    }
    out.addAll(List.filled((gap * toneRate).round(), 0));
  }
  final b = ByteData(out.length * 2);
  for (var i = 0; i < out.length; i++) {
    b.setInt16(i * 2, out[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  final v = _vocab();
  final bank = SpkBank.parse(json.decode(File('assets/data/speak.json').readAsStringSync()) as Map, v);
  final cs = CharSounds(v.data);

  test('every level has its parts, enough for many mock tests', () {
    for (final lv in hkLevels) {
      for (final (k, n) in hkPaper(lv)) {
        expect(bank.of(lv, k).length, greaterThanOrEqualTo(n * 10), reason: 'level $lv part $k');
      }
    }
    expect(bank.of(1, 'q').every((q) => q.kw.length == 3 && q.tr.length == 4), isTrue);
    expect(bank.of(2, 's').every((s) => s.kw.isNotEmpty), isTrue);
  });

  test('the pinyin lines up with the hanzi (tone check and marking need it)', () {
    var bad = <String>[];
    for (final lv in hkLevels) {
      for (final k in ['r', 's', 't', 'q']) {
        for (final it in bank.of(lv, k)) {
          if (hanTones(it.zh, it.py) == null) bad.add('${it.id} ${it.zh} | ${it.py}');
        }
      }
    }
    expect(bad.length, lessThan(5), reason: bad.take(5).join('\n'));
  });

  test('nothing in the bank names what lies past the gate', () {
    final raw = File('assets/data/speak.json').readAsStringSync();
    for (final w in ['真仙', '玄仙', '大罗', '仙门', 'HSK 7', 'HSK 8', 'HSK 9', '7–9', '7-9']) {
      expect(raw.contains(w), isFalse, reason: w);
    }
  });

  test('a talk: keywords (homophones too), length, the band words', () {
    final it = bank.of(2, 's').first;
    final all = scoreTalk(it.zh, it, 40, cs, v);
    expect(all.hit.length, it.kw.length);
    expect(all.score, greaterThan(80));
    final none = scoreTalk('我不知道', it, 10, cs, v);
    expect(none.score, lessThan(25));
    expect(saysWord('他非常紧章', '紧张', cs), isTrue); // the recognizer wrote a homophone
  });

  test('tones from pinyin, with 一 and 不 as spoken and erhua', () {
    expect(hanTones('我不去学校', 'Wǒ bú qù xuéxiào'), [3, 2, 4, 2, 4]);
    expect(hanTones('一点儿', 'yìdiǎnr'), [4, 3, 5]);
    expect(spokenTones([3, 3, 4]), [2, 3, 4]);
  });

  test('the tone check reads four clear tones', () {
    final pcm = _tone([
      (t) => 220, // 1 level
      (t) => 170 + 90 * t, // 2 rising
      (t) => 160 - 60 * math.sin(math.pi * t), // 3 dipping
      (t) => 260 - 130 * t, // 4 falling
    ]);
    final r = checkTones(pcm, [1, 2, 3, 4]);
    expect(r.heard, isTrue);
    expect([for (final s in r.syl) s.got], [1, 2, 3, 4]);
  });

  test('the log walks the bank without repeats and survives a backup', () {
    final log = SpkLog(null);
    final list = bank.of(1, 'r');
    final a = log.take(list, 8), b = log.take(list, 8);
    expect({...a.map((x) => x.id), ...b.map((x) => x.id)}.length, 16);
    final m = log.take(list, 3, mock: true);
    expect(m.any((x) => a.contains(x)), isFalse);
    final mock = HkMock(1, [for (final x in m) HkTask(x)..score = 80], 0);
    log.saveMock(mock, 1000);
    final back = SpkLog(SpkLog.clean(json.decode(json.encode(log.j))));
    expect(back.mocks.single[2], 80);
    expect(SpkLog.clean({'m': [['x']]})!['m'], isEmpty);
  });
}
