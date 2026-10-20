/// The screens other than Home (filled in by their own files).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../i18n/l10.dart' show jsTruthy;
import 'dart:async';

import 'donate.dart';
import 'focus.dart';
import 'fx.dart';
import 'goal.dart';
import 'info.dart';
import 'settings.dart';
import 'shell.dart' show navKey;
import 'realm.dart';
import 'run_view.dart';
import 'share.dart';
import 'soul.dart';
import 'stats.dart';
import 'tests.dart';

class StatsScreenHost extends StatelessWidget {
  const StatsScreenHost({super.key});
  @override
  Widget build(BuildContext context) => const StatsScreen();
}

class SoulScreenHost extends StatelessWidget {
  const SoulScreenHost({super.key});
  @override
  Widget build(BuildContext context) => const SoulScreen();
}

class FocusScreenHost extends StatelessWidget {
  final String mode;
  const FocusScreenHost({super.key, required this.mode});
  @override
  Widget build(BuildContext context) => switch (mode) {
    'list' => const ListScreen(),
    'card' || 'quiz' || 'session' => RunScreen(mode: mode),
    'placement' => const PlacementScreen(),
    'bt' => const TribScreen(),
    _ => const SizedBox(),
  };
}

void unused() => app;

/// the sheets Home and the other screens open, and the work after the first frame (registered once)
void wireSheets() {
  app.openRealm = openRealmSheet;
  app.openShare = openShareSheet;
  app.openSettings = openSettings;
  app.openStreak = openStreak;
  app.openDonate = openDonate;
  app.openInfo = (c, topic) => openInfo(c, topic);
  app.openGoal = (c, first, [focus]) => openGoal(c, first, focus);
  app.onWordmark = () {
    final c = navKey.currentContext;
    if (c != null) eggTap(c);
  };
  if (app.startHooks.isNotEmpty) return; // once per App (tests boot several)
  app.beforeShow.add(leaveTest);
  app.beforeShow.add(watchFrames);
  app.startHooks.add((context) {
    app.syncRest();
    // back after two or more days off: how much is still remembered (once a day)
    final s = app.lm.sinceLast();
    final day = app.lm.today();
    if (s != null && s.gap >= 2 && s.recall != null && app.note['back'] != day) {
      app.note['back'] = day;
      app.saveNote();
      Timer(const Duration(milliseconds: 900), () => app.toast(app.t.backMsg(s.gap, s.recall), 6500));
    }
    // the gate: its ceremony was not finished (or a v1.x breakthrough to 飞升 opened it)
    final lv = app.lm.lvInfo;
    if (app.band && lv != null && !jsTruthy(lv['gs'])) {
      Timer(const Duration(milliseconds: 700), () {
        final c = navKey.currentContext;
        if (c != null) gateShow(c);
      });
    }
    // first start: the short tour, which ends in the goal sheet
    if (app.lm.goal == null && !jsTruthy(app.store.get('xc_onb', 0))) {
      Timer(const Duration(milliseconds: 500), () {
        final c = navKey.currentContext;
        if (c != null && app.screen == 'home' && ModalRoute.of(c)?.isCurrent != false) openTour(c, true);
      });
    }
  });
}
