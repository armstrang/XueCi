/// The screens other than Home (filled in by their own files).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import 'glass.dart';
import 'theme.dart';

class StatsScreenHost extends StatelessWidget {
  const StatsScreenHost({super.key});
  @override
  Widget build(BuildContext context) => _Todo('stats');
}

class SoulScreenHost extends StatelessWidget {
  const SoulScreenHost({super.key});
  @override
  Widget build(BuildContext context) => _Todo('soul');
}

class FocusScreenHost extends StatelessWidget {
  final String mode;
  const FocusScreenHost({super.key, required this.mode});
  @override
  Widget build(BuildContext context) => _Todo(mode);
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
