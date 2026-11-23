import 'dart:convert';
import 'dart:io';
import 'package:xueci/app/talk/nlu.dart';

// ignore_for_file: avoid_print

/// dart run tool/talk_rules_dump.dart IN.jsonl OUT.jsonl : the rules' frames (key -> confidence) for every line
void main(List<String> a) {
  final n = TalkNlu();
  final out = File(a[1]).openWrite();
  for (final l in File(a[0]).readAsLinesSync()) {
    if (l.trim().isEmpty) continue;
    final o = jsonDecode(l) as Map<String, dynamic>;
    final t = o['text'] as String;
    final r = {for (final f in n.ruleFrames([t])) f.key: double.parse(f.conf.toStringAsFixed(3))};
    out.writeln(jsonEncode({'text': t, 'r': r}));
  }
  out.close();
}
