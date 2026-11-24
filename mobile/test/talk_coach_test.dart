import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/talk/coach.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/nlu.dart';

void main() {
  test('report scores known expressions and flags corrected wording', () {
    final dialog = TalkDialog(lateDelivery);
    dialog.reply('很抱歉的。', [const Frame('apologize', '+', 1)]);
    dialog.reply('谢谢您的理解。', [const Frame('thanks', '+', 1)]);
    expect({for (final term in coach(dialog).terms) term.term: term.score}, {'抱歉': 5, '谢谢': 10});
  });

  test('common slips get the better wording', () {
    String fix(String s) => slipsOf(s).map((x) => '${x.said}→${x.better}').join(' ');
    expect(fix('我们道歉您'), '道歉您→向您道歉');
    expect(fix('我们送到明天'), '送到明天→明天送到');
    expect(fix('给您打折九'), '打折九→打九折');
    expect(fix('优惠百分十'), '百分十→百分之十');
    expect(fix('我们在明天发货'), '在明天→明天');
    expect(fix('我们很抱歉的'), '很抱歉的→很抱歉');
    expect(slipsOf('非常抱歉，我们明天送到，给您打九折，优惠百分之十。'), isEmpty);
  });
}
