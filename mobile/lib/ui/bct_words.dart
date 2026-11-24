/// The business word list of BCT B (data/bct.dart `BctW`): a sheet with a search field and the topics as chips.
/// It only shows words (hanzi, pinyin, meaning in the study language); nothing here touches the learner's memory.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/bct.dart';
import 'glass.dart';
import 'icons.dart';
import 'sheet.dart';
import 'word_ui.dart' show Spk;
import 'theme.dart';

void openBctWords(BuildContext context, [String book = 'b']) => openSheet(context, name: 'bctwords', (c) => _Words(book));

class _Words extends StatefulWidget {
  final String book;
  const _Words(this.book);
  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> {
  final q = TextEditingController();
  String topic = '';

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  String _m(BctW w) => w.t[app.lang] ?? w.t['en'] ?? w.t['id'] ?? '';

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final all = app.lm.bct?.wordsOf(widget.book) ?? const <BctW>[];
    final topics = {for (final w in all) if (w.s.isNotEmpty) w.s}.toList()..sort();
    final query = q.text.trim().toLowerCase();
    final shown = [
      for (final w in all)
        if ((topic.isEmpty || w.s == topic) &&
            (query.isEmpty || w.h.contains(query) || w.p.toLowerCase().contains(query) || _m(w).toLowerCase().contains(query))) w,
    ];
    final cap = shown.length > 120 ? 120 : shown.length;
    return SheetBody(
      titleW: Text('${t.exBctW} · BCT ${widget.book.toUpperCase()}', style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25)),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t.exBctWD, style: F.s(13.5, c: p.soft, h: 1.45)),
        ),
        Container(
          decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.gEdge)),
          child: TextField(
            controller: q,
            autocorrect: false,
            enableSuggestions: false,
            style: F.s(15, c: p.fg),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: t.bwSearch,
              hintStyle: F.s(15, c: p.mute),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 10),
        if (topics.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.sunk, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.gEdge)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, value: topic, dropdownColor: p.bg, style: F.s(14, w: FontWeight.w700, c: p.fg),
                icon: RotatedBox(quarterTurns: 1, child: Icon2(I.chev, size: 16, color: p.soft, width: 2)),
                onChanged: (value) { if (value != null) setState(() => topic = value); },
                items: [
                  DropdownMenuItem(value: '', child: Text(t.bwAll)),
                  for (final name in topics) DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Text(t.bwCount(app.fmt(shown.length)), style: F.s(12.5, c: p.mute)),
        ),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(t.bwNone, style: F.s(14, c: p.soft)))
        else
          for (var i = 0; i < cap; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.gEdge.withValues(alpha: .5)))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shown[i].h, style: F.s(20, w: FontWeight.w800, c: p.fg, h: 1.2)),
                        Text(shown[i].p, style: F.s(12.5, c: p.mute, h: 1.3)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_m(shown[i]), style: F.s(14.5, c: p.soft, h: 1.4)),
                        if (shown[i].z != null) ...[const SizedBox(height: 6), BctExample(shown[i], small: true)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// the example sentence of a BCT word: the sentence (the word in the accent colour), its pinyin and the
/// translation in the study language, with a speaker
class BctExample extends StatelessWidget {
  final BctW w;
  final bool small;
  const BctExample(this.w, {super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final z = w.z;
    if (z == null) return const SizedBox.shrink();
    final i = z.indexOf(w.h);
    final tr = w.x?[app.lang] ?? w.x?['en'] ?? w.x?['id'] ?? '';
    final zs = small ? 15.0 : 19.0;
    final base = F.s(zs, family: F.hz, w: FontWeight.w600, c: p.fg, h: 1.45);
    return Column(
      crossAxisAlignment: small ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: i < 0 ? z : z.substring(0, i)),
                    if (i >= 0) TextSpan(text: w.h, style: TextStyle(color: th.acc, fontWeight: FontWeight.w800)),
                    if (i >= 0) TextSpan(text: z.substring(i + w.h.length)),
                  ],
                ),
                textAlign: small ? TextAlign.start : TextAlign.center,
                style: base,
              ),
            ),
            const SizedBox(width: 6),
            Spk(z, size: small ? 26 : 32),
          ],
        ),
        if (w.zp != null) ...[
          const SizedBox(height: 2),
          Text(
            w.zp!.replaceAll(RegExp('[{}]'), ''),
            textAlign: small ? TextAlign.start : TextAlign.center,
            style: F.s(small ? 12 : 13.5, c: p.mute, h: 1.35),
          ),
        ],
        if (tr.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(tr, textAlign: small ? TextAlign.start : TextAlign.center, style: F.s(small ? 13 : 15, c: p.soft, h: 1.4)),
        ],
      ],
    );
  }
}
