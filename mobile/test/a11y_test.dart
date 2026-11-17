// TalkBack check: on every main screen each tappable element has a name, and a tap target is at least 24 dp each way
// (the word grid in Stats is dense on purpose: one square per word). A nameless button or a tiny target fails.
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

void walk(SemanticsNode n, Matrix4 m, List<String> nameless, List<String> small, String screen) {
  final mm = m.clone();
  if (n.transform != null) mm.multiply(n.transform!);
  final d = n.getSemanticsData();
  final hidden = d.flagsCollection.isHidden;
  if (!hidden && d.hasAction(SemanticsAction.tap)) {
    final sc = mm.getMaxScaleOnAxis() / 2.625; // physical px → dp
    final w = n.rect.width * sc, h = n.rect.height * sc;
    final name = (d.label.isNotEmpty ? d.label : d.tooltip).trim();
    if (name.isEmpty) nameless.add('$screen: nameless tap at ${n.rect.size}');
    if ((w < 24 || h < 24) && w > 0 && h > 0 && screen != 'stats') small.add('$screen: "${name.replaceAll('\n', ' ')}" ${w.toStringAsFixed(0)}×${h.toStringAsFixed(0)} dp');
  }
  n.visitChildren((c) {
    walk(c, mm, nameless, small, screen);
    return true;
  });
}

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });
  final screens = <String, void Function()>{
    'home': () => app.go('home'),
    'list': () => app.go('list'),
    'card': () => app.go('card'),
    'quiz': () => app.go('quiz'),
    'stats': () => app.go('stats'),
    'soul': () => app.go('soul'),
    'hskk': () => app.go('hskk'),
    'exam': () => app.go('exam'),
  };
  final nameless = <String>[], small = <String>[];
  for (final e in screens.entries) {
    testWidgets('a11y: ${e.key}', (t) async {
      final h = t.ensureSemantics();
      await t.runAsync(() => bootApp({...sample(), 'xc_onb': '1'}, lang: 'id'));
      t.view.physicalSize = const Size(412, 892) * 2.625;
      t.view.devicePixelRatio = 2.625;
      app.deviceCores = 8;
      e.value();
      await t.pumpWidget(const XueCiApp());
      await t.pump(const Duration(milliseconds: 800));
      final root = t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
      walk(root, Matrix4.identity(), nameless, small, e.key);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 8));
      h.dispose();
    });
  }
  tearDownAll(() {
    expect({...nameless}, isEmpty, reason: 'tappable elements without a name');
    expect({...small}, isEmpty, reason: 'tap targets under 24 dp');
  });
}
