/// The screens other than Home (filled in by their own files).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import 'focus.dart';
import 'glass.dart';
import 'realm.dart';
import 'run_view.dart';
import 'share.dart';
import 'soul.dart';
import 'stats.dart';
import 'theme.dart';

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
    _ => _Todo(mode),
  };
}

class _Todo extends StatelessWidget {
  final String name;
  const _Todo(this.name);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(child: Text(name, style: F.s(20, c: Th.pal(context).fg))),
  );
}

void unused() => app;

/// the sheets Home and the other screens open (registered once, before the first frame)
void wireSheets() {
  app.openRealm = openRealmSheet;
  app.openShare = openShareSheet;
}
