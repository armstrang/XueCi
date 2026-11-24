// The talk engine against its labelled corpus (content/talk/corpus) and against cases that must never break.
// The thresholds are the measured results (Nov 2026, blind_final measured once: P 87.5 %, R 75.5 %; with slips
// R 70.3 %) less a small margin: a change that makes the engine worse fails here. They are not the goal (see
// content/talk/REPORT.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/nlu.dart';

import 'talk/eval.dart';

void main() {
  final nlu = TalkNlu();
  List<String> said(String t) => nlu.said([t]).map((f) => f.key).toList();

  group('cases', () {
    test('a denial about price does not cancel an apology in an unpunctuated transcript', () {
      expect(said('我们不给您打折真的很抱歉'), containsAll(['apologize+', 'discount-']));
      expect(said('我们并不觉得抱歉'), isNot(contains('apologize+')));
    });
    test('several acts in one voice note', () {
      expect(said('对不起，货物在路上耽误了，我们马上重新发货。'), ['apologize+', 'cause+', 'resend+']);
    });
    test('negation, double negation, after the word', () {
      expect(said('我们不会给您打折'), ['discount-']);
      expect(said('我们不是不想道歉'), ['apologize+']);
      expect(said('折扣是不可能的'), ['discount-']);
      expect(said('运费我们不能承担'), ['compensate-']);
    });
    test('questions, quotes, conditions, plans given up are not offers', () {
      expect(said('要不要给您打九折？'), isEmpty);
      expect(said('经理说可以给您打九折'), isEmpty);
      expect(said('本来想给您八折，但是不行'), ['discount-']);
      expect(said('如果我们给您九折，您能接受吗？'), isEmpty);
    });
    test('A-not-A and 要不 are not negations', () {
      expect(said('能不能告诉我您最晚哪天要？'), ['ask_deadline+']);
      expect(said('要不我们给您换成顺丰空运吧'), contains('expedite+'));
    });
    test('the trigger word in another sense', () {
      expect(said('折扣店今天关门了'), isEmpty);
      expect(said('发货单在桌上'), isEmpty);
      expect(said('道歉信已经寄给别的客户了'), isEmpty);
    });
    test('blame put elsewhere hides the apology inside it', () {
      expect(said('这不是我们的错，是快递公司的问题'), ['cause+', 'deny_fault+']);
    });
    test('a homophone slip is still understood; a real word is not a slip', () {
      expect(said('到歉，我们马上重新发货'), ['apologize+', 'resend+']);
      expect(said('我们锺新发一个新的给你'), contains('resend+'));
      expect(said('我没办法给你退全款'), isNot(contains('resend-')));
      expect(said('之前一定到'), isNot(contains('apologize+')));
    });
    test('slots', () {
      final f = nlu.said(['给您打个八五折，周五之前送到']);
      expect(f.firstWhere((x) => x.act == 'discount').pct, 15);
      expect(f.firstWhere((x) => x.act == 'promise_time').when, 'friday');
      expect(TalkNlu.readPct('优惠百分之二十'), 20);
      expect(TalkNlu.readPct('打对折'), 50);
      expect(TalkNlu.readPct('打五五折'), 45);
      expect(TalkNlu.readPct('打5.5折'), 45);
      expect(TalkNlu.readWhen('三个工作日内送到'), '3_days');
      expect(TalkNlu.repair('给您打久折'), '给您打九折');
      expect(TalkNlu.repair('对不其'), '对不起');
    });
  });

  group('corpus', () {
    // dev: written while building the engine; blind_final: written by separate authors, never used to tune it
    test('dev', () {
      final s = evaluate(nlu, loadCorpus('../content/talk/corpus/dev.jsonl'));
      expect(s.p, greaterThanOrEqualTo(.97));
      expect(s.r, greaterThanOrEqualTo(.97));
    });
    test('blind_final', () {
      final s = evaluate(nlu, loadCorpus('../content/talk/corpus/blind_final.jsonl'));
      // ignore: avoid_print
      print(s.report('blind_final'));
      expect(s.p, greaterThanOrEqualTo(.86));
      expect(s.r, greaterThanOrEqualTo(.74));
    });
    test('blind_final with recognizer slips', () {
      final s = evaluate(nlu, loadCorpus('../content/talk/corpus/blind_final.jsonl'), noise: noiser(7));
      // ignore: avoid_print
      print(s.report('blind_final + slips'));
      expect(s.r, greaterThanOrEqualTo(.69));
    });
    test('fast enough', () {
      final items = loadCorpus('../content/talk/corpus/blind_val.jsonl');
      final sw = Stopwatch()..start();
      for (final it in items) {
        nlu.parse([it.text]);
      }
      expect(sw.elapsedMicroseconds / items.length / 1000, lessThan(15));
    });
  });
}
