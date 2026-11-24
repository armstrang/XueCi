import 'package:flutter/material.dart' show Slider, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/app/native.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/ui/qi.dart' show qiOn;
import 'package:xueci/ui/shell.dart';
import 'package:xueci/ui/talk.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

Future<void> openTalk(WidgetTester tester, {Scenario? scenario = lateDelivery}) async {
  await tester.runAsync(() => bootApp({...sample(), 'hsk16_theme': '"light"'}, lang: 'id'));
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  talkSeed = 5;
  talkScenarioOverride = scenario;
  app.canListen = true;
  app.go('talk');
  await tester.pumpWidget(const XueCiApp());
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(seconds: 8));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
}

void main() {
  setUpAll(() async {
    qiOn = false;
    await loadFonts();
  });
  tearDown(() {
    talkSeed = null;
    talkScenarioOverride = null;
    Native.talkAudioTest = null;
    talkListen = null;
  });

  testWidgets('recording can be played, replaced and then scored only on send', (t) async {
    final commands = <String>[];
    final seekPoints = <int>[];
    Native.talkAudioTest = (method, argument) async {
      commands.add(method);
      if (method == 'talkAudioSeek') seekPoints.add(argument as int);
      return switch (method) {
        'talkAudioSupported' || 'talkAudioPlay' => true,
        'talkRecord' => <Object?, Object?>{'ms': 1500, 'peaks': [20, 45]},
        'talkAudioSend' => '["因为海关查验。"]',
        'talkAudioPosition' => 500,
        _ => null,
      };
    };
    await openTalk(t);
    await t.tap(find.text('Bicara'));
    await t.pump();
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('8/10'), findsNothing);
    t.widget<Slider>(find.byType(Slider)).onChangeEnd!(750);
    await t.pump();
    expect(seekPoints, [750]);
    await t.tap(find.byIcon(Icons.play_arrow_rounded));
    await t.pump(const Duration(milliseconds: 130));
    expect(commands, contains('talkAudioPlay'));
    await t.tap(find.byIcon(Icons.replay_rounded));
    await t.pump();
    expect(commands.where((name) => name == 'talkRecord'), hasLength(2));
    await t.tap(find.byIcon(Icons.send_outlined));
    await t.pump(const Duration(milliseconds: 500));
    expect(commands.where((name) => name == 'talkAudioSend'), hasLength(1));
    expect(find.text('8/10'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('level selection shows the recording limit before a scenario opens', (t) async {
    await openTalk(t, scenario: null);
    expect(find.text('BCT A'), findsOneWidget);
    expect(find.text('BCT B'), findsOneWidget);
    expect(find.text('Acak'), findsNothing);
    expect(find.textContaining('Maksimal 30 detik'), findsOneWidget);
    expect(find.text('Bicara'), findsNothing);
    await t.tap(find.text('BCT A'));
    await t.pump();
    expect(find.text('BCT B'), findsNothing);
    expect(find.textContaining(' · '), findsOneWidget);
    var milliseconds = 0;
    talkListen = ({onEvent, limitMs = 0}) async {
      milliseconds = limitMs;
      return [];
    };
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(seconds: 8));
    expect(milliseconds, 30000);
  });

  testWidgets('conflicting dates wait for transcript selection or retry', (t) async {
    await openTalk(t);
    talkListen = ({onEvent, limitMs = 0}) async => ['周四送到。', '周六送到。'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Mana yang kamu ucapkan?'), findsOneWidget);
    expect(find.text('3/10'), findsNothing);
    expect(find.text('Bicara'), findsNothing);
    await t.ensureVisible(find.text('Ucapkan lagi'));
    await t.tap(find.text('Ucapkan lagi'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Mana yang kamu ucapkan?'), findsNothing);
    expect(find.text('Bicara'), findsOneWidget);
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    await t.ensureVisible(find.text('周六送到。'));
    await t.tap(find.text('周六送到。'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Mana yang kamu ucapkan?'), findsNothing);
  });

  testWidgets('an incoherent recognition has no score and can be retried', (t) async {
    await openTalk(t);
    talkListen = ({onEvent, limitMs = 0}) async => ['你好玩学校每个是在路上'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('1/10'), findsNothing);
    expect(find.text('Bicara'), findsOneWidget);
    expect(find.text('Belum terdengar jelas. Coba lagi.'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 300));
    talkListen = ({onEvent, limitMs = 0}) async => ['因为海关查验。'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('8/10'), findsOneWidget);
  });

  testWidgets('the wrong item scenario is accessible from the BCT screen', (t) async {
    await openTalk(t, scenario: wrongBatch);
    expect(find.textContaining('pesan yang biru'), findsOneWidget);
    talkListen = ({onEvent, limitMs = 0}) async => ['我们给您换成蓝色款，周四送到。'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('9/10'), findsOneWidget);
    expect(find.text('Barang salah'), findsNothing);
  });

  testWidgets('billing confirms an amount before showing the numeric score', (t) async {
    await openTalk(t, scenario: invoiceMismatch);
    expect(find.textContaining('didebit 1.200'), findsOneWidget);
    const correct = '给您原路退二百元，发票我会重开。';
    talkListen = ({onEvent, limitMs = 0}) async => ['给您原路退一百元，发票我会重开。', correct];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Mana yang kamu ucapkan?'), findsOneWidget);
    expect(find.text('9/10'), findsNothing);
    await t.ensureVisible(find.text(correct));
    await t.tap(find.text(correct));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('9/10'), findsOneWidget);
    expect(find.textContaining('faktur yang sudah dibetulkan'), findsOneWidget);
  });
}
