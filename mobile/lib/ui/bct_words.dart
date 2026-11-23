/// The business word list of BCT B (data/bct.dart `BctW`): a sheet with a search field and the topics as chips.
/// It only shows words (hanzi, pinyin, meaning in the study language); nothing here touches the learner's memory.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/bct.dart';
import 'glass.dart';
import 'sheet.dart';
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
    final topics = <String>[];
    for (final w in all) {
      if (w.s.isNotEmpty && !topics.contains(w.s)) topics.add(w.s);
    }
    final query = q.text.trim().toLowerCase();
    final shown = [
      for (final w in all)
        if (query.isEmpty
            ? (topic.isEmpty || w.s == topic)
            : (w.h.contains(query) || w.p.toLowerCase().contains(query) || _m(w).toLowerCase().contains(query)))
          w,
    ];
    final cap = shown.length > 120 ? 120 : shown.length;
    Widget chip(String label, bool on, VoidCallback f) => Press(
      onTap: f,
      scale: .96,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? th.acc.withValues(alpha: .16) : p.sunk,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? th.acc : p.gEdge),
        ),
        child: Text(label, style: F.s(13, w: FontWeight.w700, c: on ? th.acc : p.soft)),
      ),
    );
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(t.bwAll, topic.isEmpty, () => setState(() => topic = '')),
            for (final s in topics) chip(s, topic == s, () => setState(() => topic = s)),
          ],
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
                  Expanded(child: Text(_m(shown[i]), style: F.s(14.5, c: p.soft, h: 1.4))),
                ],
              ),
            ),
      ],
    );
  }
}
