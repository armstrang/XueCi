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

Future<void> openTalk(
  WidgetTester tester, {
  Scenario? scenario = lateDelivery,
}) async {
  await tester.runAsync(
    () => bootApp({...sample(), 'hsk16_theme': '"light"'}, lang: 'id'),
  );
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
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 300)),
  );
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

  testWidgets(
    'recording can be played, replaced and then scored only on send',
    (t) async {
      final commands = <String>[];
      final seekPoints = <int>[];
      Native.talkAudioTest = (method, argument) async {
        commands.add(method);
        if (method == 'talkAudioSeek') seekPoints.add(argument as int);
        return switch (method) {
          'talkAudioSupported' || 'talkAudioPlay' => true,
          'talkRecord' => <Object?, Object?>{
            'ms': 1500,
            'peaks': [20, 45],
          },
          'talkAudioSend' => '["因为海关查验。"]',
          'talkAudioPosition' => 500,
          _ => null,
        };
      };
      await openTalk(t);
      await t.tap(find.text('Bicara'));
      await t.pump();
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('因为海关查验。'), findsOneWidget);
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
      expect(commands.where((name) => name == 'talkAudioSend'), hasLength(2));
      expect(find.text('8/10'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets(
    'an unsupported recording keeps send disabled and live speech requires review',
    (t) async {
      Native.talkAudioTest = (method, _) async => switch (method) {
        'talkAudioSupported' => true,
        'talkRecord' => <Object?, Object?>{
          'ms': 1500,
          'peaks': [20],
        },
        'talkAudioSend' => '!',
        _ => null,
      };
      await openTalk(t);
      await t.tap(find.text('Bicara'));
      await t.pump();
      expect(find.textContaining('belum bisa membaca rekaman'), findsOneWidget);
      expect(find.text('8/10'), findsNothing);
      await t.tap(find.text('Bicara langsung'));
      await t.pump();
      talkListen = ({onEvent, limitMs = 0}) async => ['因为海关查验。'];
      await t.tap(find.text('Bicara'));
      await t.pump();
      expect(find.text('因为海关查验。'), findsOneWidget);
      expect(find.text('8/10'), findsNothing);
      await t.tap(find.byIcon(Icons.send_outlined));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('8/10'), findsOneWidget);
    },
  );

  testWidgets(
    'level selection shows the recording limit before a scenario opens',
    (t) async {
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
    },
  );

  Future<void> send(WidgetTester t, List<String> heard) async {
    talkListen = ({onEvent, limitMs = 0}) async => heard;
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byIcon(Icons.send_outlined));
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'scores the previewed transcript even if another candidate disagrees',
    (t) async {
      await openTalk(t);
      await send(t, ['周六送到。', '周四送到。']);
      expect(find.text('周六送到。'), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('Mana yang kamu ucapkan?'), findsNothing);
      expect(find.text('Bicara'), findsOneWidget);
    },
  );

  testWidgets('the learner can change the transcript before sending', (
    t,
  ) async {
    await openTalk(t);
    talkListen = ({onEvent, limitMs = 0}) async => ['周六送到。', '周四送到。'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    final change = find.text(app.t.talkChooseSpeech);
    await t.tap(change);
    await t.pumpAndSettle();
    await t.tap(find.text('周四送到。'));
    await t.pumpAndSettle();
    expect(find.text('周四送到。'), findsOneWidget);
    expect(find.text('周六送到。'), findsNothing);
    await t.tap(find.byIcon(Icons.send_outlined));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('周四送到。'), findsOneWidget);
    expect(find.text('3/10'), findsNothing);
  });

  testWidgets(
    'off-topic speech scores zero and repeated misses finish the session',
    (t) async {
      await openTalk(t);
      for (var i = 0; i < lateDelivery.patience; i++) {
        await send(t, ['苹果香蕉']);
      }
      expect(find.text(app.t.talkResults), findsOneWidget);
      expect(find.text('Bicara'), findsNothing);
      expect(find.text('Selesai'), findsOneWidget);
      final history = find.text(app.t.talkViewThread);
      await t.ensureVisible(history);
      await t.tap(history);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('0/10'), findsWidgets);
      expect(find.text('苹果香蕉'), findsWidgets);
      await t.tap(find.text(app.t.talkBackResults));
      await t.pump();
      expect(find.text(app.t.talkResults), findsOneWidget);
    },
  );

  testWidgets('the wrong item scenario is accessible from the BCT screen', (
    t,
  ) async {
    await openTalk(t, scenario: wrongBatch);
    expect(find.textContaining('pesan yang biru'), findsOneWidget);
    talkListen = ({onEvent, limitMs = 0}) async => ['我们给您换成蓝色款，周四送到。'];
    await t.tap(find.text('Bicara'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.byIcon(Icons.send_outlined));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('9/10'), findsOneWidget);
    expect(find.text('Barang salah'), findsNothing);
  });

  testWidgets(
    'billing scores the submitted amount without an extra confirmation',
    (t) async {
      await openTalk(t, scenario: invoiceMismatch);
      await send(t, ['给您原路退二百元，发票我会重开。', '给您原路退一百元，发票我会重开。']);
      expect(find.text('9/10'), findsOneWidget);
      expect(find.text('Mana yang kamu ucapkan?'), findsNothing);
    },
  );
}
