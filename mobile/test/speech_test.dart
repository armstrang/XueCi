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

  test('numbers written as digits are read as hanzi', () {
    expect(hanDigits('请打开书看第10页'), '请打开书看第十页');
    expect(hanDigits('我有2个朋友'), '我有二个朋友');
    expect(hanDigits('21 105 1010 2000'), '二十一 一百零五 一千零一十 二千');
    expect(hanDigits('2026年'), '二零二六年');
    expect(hanDigits('没有数字'), '没有数字');
    expect(hanDigits('电话13800'), '电话一三八零零');
  });

  test('a spoken 10 counts for 十, and 两 for 二', () {
    final r = scoreSpeech('请打开书,看第十页。', ['请打开书看第10页'], 'n', cs);
    expect(r.all, isTrue);
    expect(r.heard, '请打开书看第十页');
    expect(cs.same('二', '两', 'n'), isTrue);
  });
}
