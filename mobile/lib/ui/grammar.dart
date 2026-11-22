/// The grammar book (v1.6): a page per level with its points grouped by kind, a point's page (formula, a short
/// explanation, examples with the grammar word marked) and practice: fill the gap with the grammar word, or put a
/// sentence's pieces in order. Answers are judged at once; progress per point lives in xc_gram (app/grammar.dart).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/grammar.dart';
import '../data/words.dart';
import 'focus.dart';
import 'glass.dart';
import 'icons.dart';
import 'run_view.dart' show OptBtn, OrderPad;
import 'settings.dart' show SGroup, Seg;
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart' show Spk;

const _zh = Locale('zh', 'CN');

/// the level's name in the book (the advanced band is one level, shown with its span)
String gramLvName(int l) => l >= 7 ? 'HSK $l–${l + 2}' : 'HSK $l';

class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});
  @override
  State<GrammarScreen> createState() => _GrammarState();
}

class _GrammarState extends State<GrammarScreen> {
  final _scroll = ScrollController();
  double _keep = 0; // where the list was when a point or a run opened (Josh: back must not start at the top)
  late int lv;
  GPoint? pt; // a point's page
  List<GItem>? run; // practice
  bool review = false; // the run mixes the level's points
  int i = 0, right = 0;

  @override
  void initState() {
    super.initState();
    // a link from elsewhere (tests, advice) names an HSK 3.0 level
    if (app.gramLevel != null || app.gramPoint != null) app.gramBook = 'h3';
    lv = _near(app.gramLevel ?? app.gramLvBy[app.gramBook] ?? (app.gramBook == 'h3' ? app.level : 1));
    app.gramLevel = null;
    app.gramLvBy[app.gramBook] = lv;
    if (app.gramPoint != null) pt = app.gram?.byId[app.gramPoint];
    app.gramPoint = null;
    app.backHook = _back;
  }

  @override
  void dispose() {
    if (app.backHook == _back) app.backHook = null;
    _scroll.dispose();
    super.dispose();
  }

  /// the book's level nearest to [want] (at or below it, else its first)
  int _near(int want) {
    final ls = app.gramLevels;
    return ls.contains(want) ? want : (ls.isEmpty ? 1 : ls.where((l) => l <= want).fold(ls.first, (a, b) => b));
  }

  /// back: out of a run, then out of a point, then off the screen; back on the list, it is where it was
  bool _back() {
    if (run != null) {
      setState(() => run = null);
    } else if (pt != null) {
      setState(() => pt = null);
    } else {
      return false;
    }
    if (run == null && pt == null) {
      final o = _keep;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(o.clamp(0, _scroll.position.maxScrollExtent).toDouble());
      });
    } else {
      _top();
    }
    return true;
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// leaving the list: remember where it was
  void _leaveList() {
    if (run == null && pt == null && _scroll.hasClients) _keep = _scroll.offset;
  }

  void _start(List<GItem> items, {bool mixed = false}) {
    if (items.isEmpty) return;
    _leaveList();
    setState(() {
      run = items;
      review = mixed;
      i = 0;
      right = 0;
    });
    _top();
  }

  void _judge(GItem it, bool ok, [int? pick]) {
    if (it.ok != null) return;
    it.pick = pick;
    it.ok = ok;
    it.item.done = true;
    if (ok) right++;
    app.gprog.answer(it.p.id, ok);
    app.runner.studied();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = app.t;
    final b = app.gram;
    final bottom = MediaQuery.paddingOf(context).bottom + 96;
    final title = run != null ? (review ? t.gram : run![0].p.title(app.vocab.lang)) : (pt?.title(app.vocab.lang) ?? t.gram);
    Widget body;
    if (b == null) {
      body = Padding(padding: const EdgeInsets.all(24), child: Text(t.dataFail));
    } else if (run != null) {
      body = _run(context);
    } else if (pt != null) {
      body = _point(context, pt!);
    } else {
      body = _list(context, b);
    }
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Capsule(
                    title: title,
                    onBack: () {
                      if (!_back()) backFrom(context);
                    },
                    lead: run == null && pt == null && b != null ? [_lvPill(context)] : const [],
                  ),
                  body,
                ],
              ),
            ),
          ),
        ),
        FloatTitle(controller: _scroll, title: title),
      ],
    );
  }

  Widget _lvPill(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    return HeadPill(
      label: '${t.pickLv}: ${gramBookLv(app.gramBook, lv)}',
      onTap: () => openMenu(context, (c) {
        final pp = Th.pal(c);
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in app.gramLevels)
                Builder(
                  builder: (c) {
                    final pts = app.gram!.inBook(app.gramBook, l);
                    final held = pts.where((x) => app.gprog.held(x.id)).length;
                    final on = l == lv;
                    return Press(
                      onTap: () {
                        Navigator.pop(c);
                        setState(() => lv = l);
                        app.gramLvBy[app.gramBook] = l;
                        _keep = 0;
                        _top();
                      },
                      scale: .97,
                      selected: on,
                      label: '${gramBookLv(app.gramBook, l)}, ${t.gramHeld(held, pts.length)}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: on ? pp.l(l).withValues(alpha: .12) : null),
                        child: Row(
                          children: [
                            Dot(pp.l(l), size: 10),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                gramBookLv(app.gramBook, l),
                                style: F.s(14.5, w: FontWeight.w700, c: pp.fg),
                              ),
                            ),
                            Text(
                              '$held/${pts.length}',
                              style: F.s(12.5, w: FontWeight.w700, c: pp.soft, feat: F.tab),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      }, width: 320),
      child: Text(
        gramBookLv(app.gramBook, lv),
        style: F.s(15, w: FontWeight.w800, c: p.dark ? Color.lerp(th.acc, Colors.white, .45)! : th.acc),
      ),
    );
  }

  // ------------------------------------------------------------------ the level's list
  Widget _list(BuildContext context, GBook b) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final bk = app.gramBook;
    final books = [
      for (final g in gramBooks)
        if (b.levelsOf(g).isNotEmpty) g,
    ];
    final pts = b.inBook(bk, lv);
    final held = pts.where((x) => app.gprog.held(x.id)).length;
    final canMix = pts.any((x) => x.practisable);
    // v1.8 (Josh: not jumbled): grouped by learning stage, from sentence basics to tone and expressions
    final groups = <Widget>[];
    for (var st = 1; st <= 10; st++) {
      final inSt = pts.where((x) => x.t == st).toList();
      if (inSt.isEmpty) continue;
      groups.add(SGroup('${app.t.gramStage['$st'] ?? st}', [for (final x in inSt) _row(context, x)]));
    }
    final sub = switch (bk) {
      'h2' => t.gramSubH2('$lv'),
      'bct' => t.gramSubBct(lv == 1 ? 'A' : 'B'),
      'yct' => t.gramSubYct('$lv'),
      _ => t.gramSub(gramLvName(lv).substring(4)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (books.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 10),
            child: Seg(
              options: [for (final g in books) (g, gramBookName(g), null)],
              value: bk,
              label: t.gram,
              onPick: (g) {
                if (g == app.gramBook) return;
                app.gramBook = g;
                app.saveUI();
                setState(() => lv = _near(app.gramLvBy[g] ?? lv));
                app.gramLvBy[g] = lv;
                _keep = 0;
                _top();
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(sub, style: F.s(13.5, c: p.soft, h: 1.4)),
        ),
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.gramHeld(held, pts.length),
                      style: F.s(14.5, w: FontWeight.w700, c: p.fg),
                    ),
                  ),
                  Text(
                    app.pctTxt(pts.isEmpty ? 0 : held / pts.length),
                    style: F.s(14.5, w: FontWeight.w800, c: p.fg, feat: F.tab),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: p.fgA(.08))),
                      FractionallySizedBox(
                        widthFactor: pts.isEmpty ? 0 : (held / pts.length).clamp(0, 1).toDouble(),
                        heightFactor: 1,
                        child: ColoredBox(color: p.l(lv)),
                      ),
                    ],
                  ),
                ),
              ),
              if (canMix) ...[
                const SizedBox(height: 12),
                MainBtn(t.gramReview, wide: true, icon: I.quiz, onTap: () => _start(app.gpr.review(app.gramBook, lv, app.gprog), mixed: true)),
              ],
            ],
          ),
        ),
        ...groups,
      ],
    );
  }

  Widget _row(BuildContext context, GPoint x) {
    final th = Th.of(context);
    final p = th.p;
    final lang = app.vocab.lang;
    final st = _status(x);
    final e = x.eg.isEmpty ? null : x.eg.first;
    final keySlots = {
      for (var i = 0; i < x.parts.length; i++)
        if (x.parts[i].key) i + 1,
    };
    return Press(
      onTap: () {
        _leaveList();
        setState(() => pt = x);
        _top();
      },
      scale: .985,
      label: '${x.title(lang)}, ${x.zh}${st.$1.isEmpty ? '' : ', ${st.$1}'}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    x.title(lang),
                    style: F.s(15.5, w: FontWeight.w800, c: p.fg, h: 1.3),
                  ),
                  if (e != null) ...[
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final w in e.w)
                            TextSpan(
                              text: w.h,
                              style: TextStyle(fontFamily: F.zh, color: keySlots.contains(w.slot) ? _acc(th) : p.fg, fontWeight: FontWeight.w700),
                            ),
                          TextSpan(
                            text: '  ${e.tr[lang] ?? e.tr['en'] ?? ''}',
                            style: TextStyle(color: p.soft, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      locale: _zh,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: F.s(13.5, h: 1.4),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    '${x.zh}${x.npy.isEmpty ? '' : ' · ${x.npy}'}',
                    locale: _zh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: F.s(11.5, c: p.mute, h: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (st.$2 != null) ...[Dot(st.$2!, size: 9), const SizedBox(width: 8)],
            Text('›', style: F.s(18, c: p.mute, h: 1)),
          ],
        ),
      ),
    );
  }

  /// the books a point is in, with its level in each (v1.8, Josh: the same pattern shows in every book that has it)
  Widget _books(Th th, GPoint x) {
    final p = th.p;
    final ins = [
      for (final b in gramBooks)
        if (x.lvIn(b) != null) (b, x.lvIn(b)!),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Semantics(
        container: true,
        label: '${app.t.gramIn} ${ins.map((e) => '${gramBookName(e.$1)} ${gramBookLv(e.$1, e.$2)}').join(', ')}',
        child: ExcludeSemantics(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                app.t.gramIn,
                style: F.s(12, c: p.soft, w: FontWeight.w600),
              ),
              for (final (b, l) in ins)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: b == app.gramBook ? p.l(x.l).withValues(alpha: p.dark ? .22 : .14) : p.fgA(.06),
                    border: Border.all(color: b == app.gramBook ? p.l(x.l).withValues(alpha: .55) : p.fgA(.12)),
                  ),
                  child: Text(
                    b == 'h3' || b == 'h2' ? '${gramBookName(b)} · ${l >= 7 ? gramBookLv(b, l) : l}' : gramBookLv(b, l),
                    style: F.s(12, w: FontWeight.w700, c: p.fg),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _acc(Th th) => th.p.dark ? Color.lerp(th.acc, Colors.white, .4)! : th.acc;

  /// the colour of a formula part: the grammar word takes the accent, the slots take their own colours in turn
  Color _partColor(Th th, GPoint x, int slot) {
    if (slot < 1 || slot > x.parts.length) return th.p.fgA(.18);
    if (x.parts[slot - 1].key) return _acc(th);
    var k = 0;
    for (var i = 0; i < slot - 1; i++) {
      if (!x.parts[i].key) k++;
    }
    const dark = [Color(0xFF8CC8FF), Color(0xFF7FE0B0), Color(0xFFFFB86B), Color(0xFFFF9EC7), Color(0xFF7FD9E0)];
    const light = [Color(0xFF1D63B0), Color(0xFF16774A), Color(0xFFA2540A), Color(0xFFB02A63), Color(0xFF0B6E77)];
    return (th.p.dark ? dark : light)[k % 5];
  }

  /// a point's state: words and a colour (null: not practised)
  (String, Color?) _status(GPoint x) {
    final p = Th.pal(context);
    final t = app.t;
    final g = app.gprog;
    if (g.n(x.id) == 0) return (x.practisable ? t.gramNew : '', null);
    if (g.held(x.id) && !g.due(x.id)) return (t.gramOk, p.good);
    if (g.due(x.id)) return (t.gramDue, p.bad);
    return (t.gramGrow, p.sYellow);
  }

  // ------------------------------------------------------------------ a point
  Widget _point(BuildContext context, GPoint x) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lang = app.vocab.lang;
    final st = _status(x);
    final w = x.warn?[lang] ?? x.warn?['en'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            [x.zh, if (x.npy.isNotEmpty) x.npy, '${t.gramStage['${x.t}'] ?? ''}'].join(' · '),
            locale: _zh,
            style: F.s(12.5, c: p.soft, h: 1.4),
          ),
        ),
        _books(th, x),
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t.gramFormula.toUpperCase(),
                    style: F.s(11.5, w: FontWeight.w800, c: p.soft, ls: .8),
                  ),
                  const Spacer(),
                  if (st.$2 != null) ...[
                    Dot(st.$2!, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      st.$1,
                      style: F.s(12, w: FontWeight.w700, c: p.soft),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (x.parts.isEmpty)
                Text(
                  x.formula,
                  locale: _zh,
                  style: F.s(19, w: FontWeight.w800, c: _acc(th), family: F.zh, h: 1.4),
                )
              else
                _formula(th, x, lang),
              const SizedBox(height: 12),
              Rich(x.text(lang), style: F.s(14.5, c: p.fg, h: 1.5)),
              if (w != null && w.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: p.sYellow.withValues(alpha: p.dark ? .1 : .12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.sYellow.withValues(alpha: .4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '!',
                        style: F.s(14, w: FontWeight.w900, c: p.dark ? p.sYellow : const Color(0xFF7A5200), h: 1.35),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          w,
                          locale: _zh,
                          style: F.s(13.5, c: p.dark ? const Color(0xFFF3D58C) : const Color(0xFF6B4700), h: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // the practice button sits above the examples so it is never below the fold
        const SizedBox(height: 14),
        if (x.practisable)
          MainBtn(t.gramPractice, wide: true, big: true, icon: I.quiz, onTap: () => _start(app.gpr.run(x)))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              t.gramRead,
              textAlign: TextAlign.center,
              style: F.s(13.5, c: p.soft, h: 1.45),
            ),
          ),
        if (x.eg.isNotEmpty) ...[
          const SizedBox(height: 14),
          SGroup(t.gramEx, [for (final e in x.eg) _example(th, x, e, lang)]),
        ],
      ],
    );
  }

  /// the formula: a box per part (hanzi, meaning, pinyin) in the part's colour, the signs between them
  Widget _formula(Th th, GPoint x, String lang) {
    final p = th.p;
    final kids = <Widget>[];
    for (var i = 0; i < x.parts.length; i++) {
      final q = x.parts[i];
      final c = _partColor(th, x, i + 1);
      if (i > 0) {
        final sep = i - 1 < x.seps.length ? x.seps[i - 1] : '+';
        kids.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              sep,
              style: F.s(17, w: FontWeight.w600, c: p.mute),
            ),
          ),
        );
      }
      final g = q.g?[lang] ?? q.g?['en'];
      kids.add(
        MergeSemantics(
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, maxWidth: 220),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: c.withValues(alpha: p.dark ? .14 : .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withValues(alpha: .45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  q.t,
                  locale: _zh,
                  textAlign: TextAlign.center,
                  style: F.s(19, w: FontWeight.w800, c: c, family: F.zh, h: 1.25),
                ),
                if (g != null && g.isNotEmpty)
                  Text(
                    g,
                    textAlign: TextAlign.center,
                    style: F.s(12, w: FontWeight.w700, c: c, h: 1.3),
                  ),
                if (q.py.isNotEmpty)
                  Text(
                    q.py,
                    textAlign: TextAlign.center,
                    style: F.s(10.5, c: p.soft, h: 1.3),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.start, children: kids);
  }

  /// an example word by word: hanzi over a line in its part's colour, then pinyin and meaning, then the sentence
  Widget _example(Th th, GPoint x, GEx e, String lang) {
    final p = th.p;
    final tr = e.tr[lang] ?? e.tr['en'] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '${e.z}. ${e.py}. ${_glosses(e, lang)}',
                  excludeSemantics: true,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final w in e.w)
                        if (w.punct)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              w.h,
                              locale: _zh,
                              style: F.s(19, w: FontWeight.w700, c: p.soft, family: F.zh),
                            ),
                          )
                        else
                          _tok(th, x, w, lang),
                    ],
                  ),
                ),
                if (tr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(tr, style: F.s(13.5, c: p.soft, h: 1.4)),
                  ),
              ],
            ),
          ),
          Spk(e.z, size: 34),
        ],
      ),
    );
  }

  /// what a screen reader says for the words of an example: "hanzi: meaning; …"
  String _glosses(GEx e, String lang) => [
    for (final w in e.w)
      if (!w.punct && (w.g?[lang] ?? w.g?['en'] ?? '').isNotEmpty) '${w.h}: ${w.g?[lang] ?? w.g?['en']}',
  ].join('; ');

  Widget _tok(Th th, GPoint x, GTok w, String lang) {
    final p = th.p;
    final c = _partColor(th, x, w.slot);
    final key = w.slot > 0 && w.slot <= x.parts.length && x.parts[w.slot - 1].key;
    final g = w.g?[lang] ?? w.g?['en'] ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              w.h,
              locale: _zh,
              style: F.s(20, w: FontWeight.w700, c: key ? _acc(th) : p.fg, family: F.zh, h: 1.3),
            ),
            Container(
              height: 3,
              margin: const EdgeInsets.only(top: 2, bottom: 3),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
            ),
            if (w.py.isNotEmpty) Text(w.py, style: F.s(11.5, c: p.soft, h: 1.25)),
            if (g.isNotEmpty) Text(g, style: F.s(11.5, c: p.fg.withValues(alpha: .85), h: 1.25)),
          ],
        ),
      ),
    );
  }

  /// a sentence with the point's word in the accent colour
  Widget _marked(String z, GPoint x, TextStyle st, Color acc) {
    final k = x.keyIn(z);
    if (k == null) return Text(z, locale: _zh, style: st);
    final i = z.indexOf(k);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: z.substring(0, i)),
          TextSpan(
            text: k,
            style: TextStyle(color: acc, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: z.substring(i + k.length)),
        ],
      ),
      locale: _zh,
      style: st,
    );
  }

  // ------------------------------------------------------------------ practice
  Widget _run(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final items = run!;
    if (i >= items.length) return _end(context, items);
    final it = items[i];
    final judged = it.ok != null;
    final hz = F.s(22, w: FontWeight.w600, c: p.fg, family: F.zh, h: 1.5);
    final c = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                review ? it.p.title(app.vocab.lang) : '${it.p.zh} · ${it.p.formula}',
                locale: _zh,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.s(13, c: p.soft, family: F.zh),
              ),
            ),
            Text(
              '${i + 1}/${items.length}',
              style: F.s(13, w: FontWeight.w800, c: p.soft, feat: F.tab),
            ),
          ],
        ),
      ),
      Glass(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              it.kind == 'gap' ? t.gramGap : t.gramOrder,
              style: F.s(13.5, w: FontWeight.w700, c: p.soft),
            ),
            const SizedBox(height: 10),
            if (it.kind == 'gap')
              judged ? _marked(it.d.z, it.p, hz, it.ok! ? p.good : th.acc) : Text(it.gapText, locale: _zh, style: hz)
            else if (judged)
              _marked(it.d.z, it.p, hz, th.acc)
            else if (_tr(it.d).isNotEmpty)
              // the meaning as the guide: the pieces have to say this
              Text(
                _tr(it.d),
                style: F.s(16, w: FontWeight.w600, c: p.fg, h: 1.45),
              ),
            if (judged) ...[
              const SizedBox(height: 4),
              if ((it.d.zp ?? '').isNotEmpty) Text(it.d.zp!.replaceAll(RegExp(r'[{}]'), ''), style: F.s(13, c: p.soft, h: 1.4)),
              if (_tr(it.d).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(_tr(it.d), style: F.s(13.5, c: p.fg.withValues(alpha: .8), h: 1.4)),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (it.kind == 'gap')
        for (var k = 0; k < it.opts.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OptBtn(
              n: k + 1,
              label: Text(
                it.opts[k],
                locale: _zh,
                style: F.s(19, w: FontWeight.w700, c: p.fg, family: F.zh),
              ),
              state: !judged ? null : (k == it.ans ? true : (k == it.pick ? false : null)),
              picked: k == it.pick,
              onTap: judged ? null : () => _judge(it, k == it.ans, k),
            ),
          )
      else if (!judged)
        OrderPad(it.item, key: ValueKey(it), onDone: (o) => _judge(it, gOrderOk(it, o)))
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in it.right)
                Tile(
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  child: Text(
                    s,
                    locale: _zh,
                    style: F.s(17, w: FontWeight.w700, c: p.fg, family: F.zh),
                  ),
                ),
            ],
          ),
        ),
      if (judged) ...[
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon2(it.ok! ? I.check : I.close, size: 18, color: it.ok! ? p.good : p.bad, width: 2.4),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  it.ok! ? t.gramRight : (it.kind == 'gap' ? '${t.gramWrong} ${it.opts[it.ans]}' : t.gramWrong),
                  style: F.s(14.5, w: FontWeight.w800, c: it.ok! ? p.good : p.bad),
                ),
              ),
              Spk(it.d.z, size: 34),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MainBtn(
          t.ptNext,
          wide: true,
          big: true,
          onTap: () {
            setState(() => i++);
            _top();
          },
        ),
      ],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c);
  }

  String _tr(Word d) => d.t[app.vocab.lang] ?? d.t['en'] ?? d.t['id'] ?? '';

  Widget _end(BuildContext context, List<GItem> items) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final pts = {for (final it in items) it.p.id: it.p}.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            children: [
              Text(
                '$right/${items.length}',
                style: F.s(40, w: FontWeight.w800, c: right >= items.length * .8 ? p.good : p.fg, feat: F.tab, h: 1.1),
              ),
              const SizedBox(height: 6),
              Text(t.gramDone(right, items.length), style: F.s(15, c: p.soft)),
            ],
          ),
        ),
        SGroup(t.gram, [
          for (final x in pts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      x.title(app.vocab.lang),
                      style: F.s(15, w: FontWeight.w700, c: p.fg),
                    ),
                  ),
                  if (_status(x).$2 != null) ...[Dot(_status(x).$2!, size: 8), const SizedBox(width: 6)],
                  Text(_status(x).$1, style: F.s(12.5, c: p.soft)),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 18),
        MainBtn(
          t.gramAgain,
          wide: true,
          big: true,
          onTap: () => _start(review ? app.gpr.review(app.gramBook, lv, app.gprog) : app.gpr.run(items[0].p), mixed: review),
        ),
        const SizedBox(height: 10),
        GhostBtn(
          t.gramList,
          wide: true,
          onTap: () {
            setState(() {
              run = null;
              pt = null;
            });
            _top();
          },
        ),
      ],
    );
  }
}

/// the category names (a map in the texts)
class L10t {
  static String cat(String c) {
    return '${app.t.gramCat[c] ?? c}';
  }
}
