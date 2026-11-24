library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/bct.dart';
import 'focus.dart';
import 'glass.dart';
import 'icons.dart';
import 'sheet.dart';
import 'word_ui.dart' show Spk;
import 'theme.dart';

void openBctWords(BuildContext context, [String book = 'b']) =>
    openSheet(context, name: 'bctwords', (c) => BctWordsPage(book));

class BctWordsPage extends StatefulWidget {
  final String book;
  final VoidCallback? onBack;
  const BctWordsPage(this.book, {super.key, this.onBack});
  @override
  State<BctWordsPage> createState() => _WordsState();
}

class _WordsState extends State<BctWordsPage> {
  final q = TextEditingController();
  String topic = '';
  late String book = widget.book;

  Widget _picker(
    Th th,
    String value,
    Map<String, String> choices,
    ValueChanged<String> change, {
    bool expand = false,
  }) {
    return Glass(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: expand,
          value: value,
          dropdownColor: th.p.bg,
          menuMaxHeight: 360,
          style: F.s(14, w: FontWeight.w700, c: th.p.fg),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: th.p.soft,
          ),
          onChanged: (next) {
            if (next != null) change(next);
          },
          items: [
            for (final entry in choices.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }

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
    final all = app.lm.bct?.wordsOf(book) ?? const <BctW>[];
    final topics = {
      for (final w in all)
        if (w.s.isNotEmpty) w.s,
    }.toList()..sort();
    final query = q.text.trim().toLowerCase();
    final shown = [
      for (final w in all)
        if ((topic.isEmpty || w.s == topic) &&
            (query.isEmpty ||
                w.h.contains(query) ||
                w.p.toLowerCase().contains(query) ||
                _m(w).toLowerCase().contains(query)))
          w,
    ];
    final cap = shown.length > 120 ? 120 : shown.length;
    final onBack = widget.onBack;
    final title = '${t.exBctW} · BCT ${book.toUpperCase()}';
    final search = TextField(
      controller: q,
      autocorrect: false,
      enableSuggestions: false,
      style: F.s(15, c: p.fg),
      decoration: InputDecoration(
        border: InputBorder.none,
        prefixIcon: onBack == null
            ? null
            : Icon(Icons.search, size: 20, color: p.mute),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintText: t.bwSearch,
        hintStyle: F.s(15, c: p.mute),
      ),
      onChanged: (_) => setState(() {}),
    );
    final controls = <Widget>[
      if (onBack != null) ...[
        Capsule(title: t.list, onBack: onBack),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _picker(
                th,
                book,
                {'a': 'BCT A', 'b': 'BCT B'},
                (next) => setState(() {
                  book = next;
                  topic = '';
                }),
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width < 360
                        ? 180
                        : 220,
                  ),
                  child: _picker(
                    th,
                    topic,
                    {'': t.bwAll, for (final name in topics) name: name},
                    (next) => setState(() => topic = next),
                    expand: true,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ] else
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            t.exBctWD.replaceAll('BCT B', 'BCT ${book.toUpperCase()}'),
            style: F.s(13.5, c: p.soft, h: 1.45),
          ),
        ),
      if (onBack == null)
        Container(
          decoration: BoxDecoration(
            color: p.sunk,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.gEdge),
          ),
          child: search,
        )
      else
        Glass(radius: 999, child: search),
      const SizedBox(height: 10),
      if (onBack == null && topics.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: p.sunk,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.gEdge),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: topic,
              dropdownColor: p.bg,
              style: F.s(14, w: FontWeight.w700, c: p.fg),
              icon: RotatedBox(
                quarterTurns: 1,
                child: Icon2(I.chev, size: 16, color: p.soft, width: 2),
              ),
              onChanged: (value) {
                if (value != null) setState(() => topic = value);
              },
              items: [
                DropdownMenuItem(value: '', child: Text(t.bwAll)),
                for (final name in topics)
                  DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
        child: Text(
          t.bwCount(app.fmt(shown.length)),
          style: F.s(12.5, c: p.mute),
        ),
      ),
    ];
    final empty = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(t.bwNone, style: F.s(14, c: p.soft)),
    );
    Widget card(BctW word) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        word.h,
                        style: F.s(
                          24,
                          family: F.hz,
                          w: FontWeight.w800,
                          c: th.acc,
                        ),
                      ),
                      Text(
                        word.p,
                        style: F.s(14, w: FontWeight.w600, c: p.soft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Spk(word.h, size: 30),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _m(word),
              style: F.s(15, w: FontWeight.w700, c: p.fg),
            ),
            if (word.z != null) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: p.line),
              const SizedBox(height: 8),
              BctExample(word, small: true),
            ],
          ],
        ),
      ),
    );
    if (onBack == null) {
      return SheetBody(
        titleW: Text(
          title,
          style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25),
        ),
        children: [
          ...controls,
          if (cap == 0)
            empty
          else
            for (final word in shown.take(cap)) card(word),
        ],
      );
    }
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            media.padding.top + 10,
            16,
            keyboard > 0 ? keyboard + 16 : media.padding.bottom + 98,
          ),
          itemCount: 1 + (shown.isEmpty ? 1 : shown.length),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controls,
              );
            }
            return shown.isEmpty ? empty : card(shown[index - 1]);
          },
        ),
      ),
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
      crossAxisAlignment: small
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
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
                    if (i >= 0)
                      TextSpan(
                        text: w.h,
                        style: TextStyle(
                          color: th.acc,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
          Text(
            tr,
            textAlign: small ? TextAlign.start : TextAlign.center,
            style: F.s(small ? 13 : 15, c: p.soft, h: 1.4),
          ),
        ],
      ],
    );
  }
}
