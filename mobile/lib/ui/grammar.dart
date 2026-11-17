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
import 'settings.dart' show SGroup;
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
  late int lv;
  GPoint? pt; // a point's page
  List<GItem>? run; // practice
  bool review = false; // the run mixes the level's points
  int i = 0, right = 0;

  @override
  void initState() {
    super.initState();
    final ls = app.gramLevels;
    final want = app.gramLevel ?? app.level;
    lv = ls.contains(want) ? want : (ls.isEmpty ? 1 : ls.where((l) => l <= want).fold(ls.first, (a, b) => b));
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

  /// back: out of a run, then out of a point, then off the screen
  bool _back() {
    if (run != null) {
      setState(() => run = null);
    } else if (pt != null) {
      setState(() => pt = null);
    } else {
      return false;
    }
    _top();
    return true;
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _start(List<GItem> items, {bool mixed = false}) {
    if (items.isEmpty) return;
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
    final title = run != null ? (review ? t.gram : run![0].p.zh) : (pt?.zh ?? t.gram);
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
      label: '${t.pickLv}: ${gramLvName(lv)}',
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
                    final pts = app.gram!.level(l);
                    final held = pts.where((x) => app.gprog.held(x.id)).length;
                    final on = l == lv;
                    return Press(
                      onTap: () {
                        Navigator.pop(c);
                        setState(() => lv = l);
                        app.gramLevel = l;
                      },
                      scale: .97,
                      selected: on,
                      label: '${gramLvName(l)}, ${t.gramHeld(held, pts.length)}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: on ? pp.l(l).withValues(alpha: .12) : null,
                        ),
                        child: Row(
                          children: [
                            Dot(pp.l(l), size: 10),
                            const SizedBox(width: 10),
                            Expanded(child: Text(gramLvName(l), style: F.s(14.5, w: FontWeight.w700, c: pp.fg))),
                            Text('$held/${pts.length}', style: F.s(12.5, w: FontWeight.w700, c: pp.soft, feat: F.tab)),
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
      child: Text(gramLvName(lv), style: F.s(15, w: FontWeight.w800, c: p.dark ? Color.lerp(th.acc, Colors.white, .45)! : th.acc)),
    );
  }

  // ------------------------------------------------------------------ the level's list
  Widget _list(BuildContext context, GBook b) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final pts = b.level(lv);
    final held = pts.where((x) => app.gprog.held(x.id)).length;
    final canMix = pts.any((x) => x.practisable);
    final groups = <Widget>[];
    for (final c in gramCats) {
      final inCat = pts.where((x) => x.cat == c).toList();
      if (inCat.isEmpty) continue;
      groups.add(SGroup(L10t.cat(c), [for (final x in inCat) _row(context, x)]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(t.gramSub(gramLvName(lv).substring(4)), style: F.s(13.5, c: p.soft, h: 1.4)),
        ),
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t.gramHeld(held, pts.length), style: F.s(14.5, w: FontWeight.w700, c: p.fg))),
                  Text(app.pctTxt(pts.isEmpty ? 0 : held / pts.length), style: F.s(14.5, w: FontWeight.w800, c: p.fg, feat: F.tab)),
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
                MainBtn(t.gramReview, wide: true, icon: I.quiz, onTap: () => _start(app.gpr.review(lv, app.gprog), mixed: true)),
              ],
            ],
          ),
        ),
        ...groups,
      ],
    );
  }

  Widget _row(BuildContext context, GPoint x) {
    final p = Th.pal(context);
    final t = app.t;
    final st = _status(x);
    return Press(
      onTap: () {
        setState(() => pt = x);
        _top();
      },
      scale: .985,
      label: '${x.zh}, ${x.formula}, ${st.$1}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.zh, locale: _zh, style: F.s(15.5, w: FontWeight.w700, c: p.fg, family: F.zh, h: 1.35)),
                  const SizedBox(height: 2),
                  Text(x.formula, locale: _zh, style: F.s(13, c: p.soft, family: F.zh, h: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (st.$2 != null) Dot(st.$2!, size: 9),
            if (x.practisable && app.gprog.n(x.id) == 0) Text(t.gramNew, style: F.s(11.5, c: p.mute)),
            const SizedBox(width: 8),
            Text('›', style: F.s(18, c: p.mute, h: 1)),
          ],
        ),
      ),
    );
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
    final ex = <({String zh, String py, String tr})>[
      for (final d in x.ex) (zh: d.z, py: (d.zp ?? '').replaceAll(RegExp(r'[{}]'), ''), tr: app.vocab.trOf(d)),
      for (final e in x.own) (zh: e.zh, py: e.py, tr: e.tr[lang] ?? e.tr['en'] ?? ''),
    ].take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Glass(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${gramLvName(x.l)} · ${L10t.cat(x.cat)}', style: F.s(12, w: FontWeight.w800, c: p.soft, ls: .4)),
                  const Spacer(),
                  if (st.$2 != null) ...[Dot(st.$2!, size: 8), const SizedBox(width: 6), Text(st.$1, style: F.s(12, w: FontWeight.w700, c: p.soft))],
                ],
              ),
              const SizedBox(height: 10),
              Text(x.formula, locale: _zh, style: F.s(21, w: FontWeight.w800, c: th.acc, family: F.zh, h: 1.4)),
              const SizedBox(height: 10),
              Rich(x.text(lang), style: F.s(15, c: p.fg, h: 1.5)),
            ],
          ),
        ),
        if (ex.isNotEmpty)
          SGroup(t.gramEx, [
            for (final e in ex)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _marked(e.zh, x, F.s(18, w: FontWeight.w600, c: p.fg, family: F.zh, h: 1.45), th.acc),
                          if (e.py.isNotEmpty) Text(e.py, style: F.s(13, c: p.soft, h: 1.4)),
                          if (e.tr.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(e.tr, style: F.s(13.5, c: p.fg.withValues(alpha: .8), h: 1.4))),
                        ],
                      ),
                    ),
                    Spk(e.zh, size: 34),
                  ],
                ),
              ),
          ]),
        const SizedBox(height: 18),
        if (x.practisable)
          MainBtn(t.gramPractice, wide: true, big: true, icon: I.quiz, onTap: () => _start(app.gpr.run(x)))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(t.gramRead, textAlign: TextAlign.center, style: F.s(13.5, c: p.soft, h: 1.45)),
          ),
      ],
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
          TextSpan(text: k, style: TextStyle(color: acc, fontWeight: FontWeight.w800)),
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
                review ? '${it.p.zh} · ${it.p.formula}' : it.p.formula,
                locale: _zh,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.s(13, c: p.soft, family: F.zh),
              ),
            ),
            Text('${i + 1}/${items.length}', style: F.s(13, w: FontWeight.w800, c: p.soft, feat: F.tab)),
          ],
        ),
      ),
      Glass(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(it.kind == 'gap' ? t.gramGap : t.gramOrder, style: F.s(13.5, w: FontWeight.w700, c: p.soft)),
            const SizedBox(height: 10),
            if (it.kind == 'gap')
              judged ? _marked(it.d.z, it.p, hz, it.ok! ? p.good : th.acc) : Text(it.gapText, locale: _zh, style: hz)
            else if (judged)
              _marked(it.d.z, it.p, hz, th.acc)
            else if (_tr(it.d).isNotEmpty)
              // the meaning as the guide: the pieces have to say this
              Text(_tr(it.d), style: F.s(16, w: FontWeight.w600, c: p.fg, h: 1.45)),
            if (judged) ...[
              const SizedBox(height: 4),
              if ((it.d.zp ?? '').isNotEmpty) Text(it.d.zp!.replaceAll(RegExp(r'[{}]'), ''), style: F.s(13, c: p.soft, h: 1.4)),
              if (_tr(it.d).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(_tr(it.d), style: F.s(13.5, c: p.fg.withValues(alpha: .8), h: 1.4))),
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
              label: Text(it.opts[k], locale: _zh, style: F.s(19, w: FontWeight.w700, c: p.fg, family: F.zh)),
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
                Tile(radius: 12, padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), child: Text(s, locale: _zh, style: F.s(17, w: FontWeight.w700, c: p.fg, family: F.zh))),
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
              Text('$right/${items.length}', style: F.s(40, w: FontWeight.w800, c: right >= items.length * .8 ? p.good : p.fg, feat: F.tab, h: 1.1)),
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
                  Expanded(child: Text(x.zh, locale: _zh, style: F.s(15, w: FontWeight.w700, c: p.fg, family: F.zh))),
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
          onTap: () => _start(review ? app.gpr.review(lv, app.gprog) : app.gpr.run(items[0].p), mixed: review),
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
