// Speaking practice: each hanzi of the target is marked from what the phone heard.
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/speech.dart';
import 'package:xueci/data/words.dart';

Word w(String h, List<String> s) => Word(l: 1, n: 1, u: 1, h: h, p: s.join(), s: s, z: '');

void main() {
  final cs = CharSounds([
    w('出来', ['chū', 'lai']),
    w('初', ['chū']),
    w('除', ['chú']),
    w('来', ['lái']),
    w('我', ['wǒ']),
    w('喜欢', ['xǐ', 'huan']),
    w('你', ['nǐ']),
  ]);

  test('the same characters are all right', () {
    final r = scoreSpeech('出来', ['出来'], 'n', cs);
    expect(r.ok, [true, true]);
    expect(r.all, isTrue);
  });

  test('a homophone with the same tone counts on normal, any tone only on easy', () {
    expect(scoreSpeech('出来', ['初来'], 'n', cs).ok, [true, true]);
    expect(scoreSpeech('出来', ['除来'], 'n', cs).ok, [false, true]);
    expect(scoreSpeech('出来', ['除来'], 'e', cs).ok, [true, true]);
  });

  test('a missing character is marked, the rest stay aligned', () {
    final r = scoreSpeech('我喜欢你', ['我欢你'], 'n', cs);
    expect(r.ok, [true, false, true, true]);
    expect(r.share('我喜欢你'), .75);
  });

  test('punctuation is never wrong', () {
    final r = scoreSpeech('我喜欢你。', ['我喜欢你'], 'n', cs);
    expect(r.ok, [true, true, true, true, true]);
  });

  test('normal takes the best guess, hard only the first', () {
    expect(scoreSpeech('出来', ['除了', '出来'], 'n', cs).all, isTrue);
    expect(scoreSpeech('出来', ['除了', '出来'], 'h', cs).all, isFalse);
  });

  test('nothing heard: every hanzi wrong', () {
    final r = scoreSpeech('出来', [], 'n', cs);
    expect(r.ok, [false, false]);
    expect(r.heard, '');
  });
}
