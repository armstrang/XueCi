/// BCT study (v1.12): the business words as a path like HSK's: the list, cards and a quiz, for BCT A or B.
/// Extra practice only: progress is kept in `xc_bct` (app/bct_prog.dart) and never changes the realm or the plan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/bct.dart';
import 'bct_stats.dart';
import 'bct_words.dart';
import 'focus.dart';
import 'glass.dart';
import 'home.dart' show HomeHeader;
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

/// the HSK | BCT switch at the top of Home and of the BCT screen
class StudyPick extends StatelessWidget {
  final bool bct;
  const StudyPick({super.key, required this.bct});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    Widget seg(String label, bool on, VoidCallback f) => Press(
      onTap: on ? () {} : f,
      scale: .95,
      selected: on,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? th.acc.withValues(alpha: .2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: F.s(13.5, w: FontWeight.w800, c: p.fg)),
      ),
    );
    return Glass(
      frost: true,
      radius: 999,
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('HSK', !bct, () => app.setStudy('hsk')),
          seg('BCT', bct, () => app.setStudy('bct')),
        ],
      ),
    );
  }
}

class BctStudyScreen extends StatefulWidget {
  const BctStudyScreen({super.key});
  @override
  State<BctStudyScreen> createState() => _BctStudyState();
}

class _Q {
  final BctW w;
  final bool toMeaning; // word → meaning, else meaning → word
  final List<BctW> opts;
  final int ans;
  int? pick;
  _Q(this.w, this.toMeaning, this.opts, this.ans);
}

class _BctStudyState extends State<BctStudyScreen> {
  String mode = 'home'; // home | cards | quiz | done
  List<BctW> deck = [];
  int i = 0, right = 0;
  bool flipped = false;
  List<_Q> qs = [];
  String kind = 'cards';
  final _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    app.backHook = _back;
    // a new rank is told once (the first time only the rank is noted)
    final r = app.bctInfo.rank, seen = app.note['bctr'];
    if (seen is! num || seen != r) {
      app.note['bctr'] = r;
      app.saveNote();
      if (seen is num && r > seen) {
        WidgetsBinding.instance.addPostFrameCallback((_) => app.toast(app.t.brUp(rankMeaning(r)), 3200));
      }
    }
  }

  @override
  void dispose() {
    if (app.backHook == _back) app.backHook = null;
    super.dispose();
  }

  bool _back() {
    if (mode != 'home') {
      setState(() => mode = 'home');
      return true;
    }
    return false;
  }

  String _m(BctW w) => w.t[app.lang] ?? w.t['en'] ?? w.t['id'] ?? '';
  String _id(BctW w) => w.h;
  List<BctW> get _words => app.lm.bct?.wordsOf(app.bctBook) ?? const [];

  /// 12 words: the ones that have faded most first, then new ones
  List<BctW> _pick(int n) {
    final all = [..._words]..shuffle(_rnd);
    final seen = all.where((w) => app.bprog.seen(_id(w))).toList()..sort((a, b) => app.bprog.recall(_id(a)).compareTo(app.bprog.recall(_id(b))));
    final fresh = all.where((w) => !app.bprog.seen(_id(w))).toList();
    final due = seen.where((w) => app.bprog.due(_id(w))).toList();
    final out = <BctW>[...due.take(n)];
    for (final w in fresh) {
      if (out.length >= n) break;
      out.add(w);
    }
    for (final w in seen) {
      if (out.length >= n) break;
      if (!out.contains(w)) out.add(w);
    }
    return out..shuffle(_rnd);
  }

  void _startCards() {
    deck = _pick(12);
    i = 0;
    right = 0;
    flipped = false;
    kind = 'cards';
    setState(() => mode = deck.isEmpty ? 'home' : 'cards');
  }

  void _startQuiz() {
    final ws = _pick(10);
    final pool = _words;
    qs = [];
    for (final w in ws) {
      final toM = _rnd.nextBool();
      final others = [...pool.where((x) => x.h != w.h && _m(x) != _m(w))]..shuffle(_rnd);
      final opts = [w, ...others.take(3)]..shuffle(_rnd);
      qs.add(_Q(w, toM, opts, opts.indexOf(w)));
    }
    i = 0;
    right = 0;
    kind = 'quiz';
    setState(() => mode = qs.isEmpty ? 'home' : 'quiz');
  }

  void _cardAnswer(bool ok) {
    app.bprog.answer(_id(deck[i]), ok);
    if (ok) right++;
    if (i + 1 >= deck.length) {
      setState(() => mode = 'done');
    } else {
      setState(() {
        i++;
        flipped = false;
      });
    }
  }

  void _quizPick(int k) {
    final q = qs[i];
    if (q.pick != null) return;
    final ok = k == q.ans;
    app.bprog.answer(_id(q.w), ok);
    if (ok) right++;
    setState(() => q.pick = k);
  }

  void _quizNext() {
    if (i + 1 >= qs.length) {
      setState(() => mode = 'done');
    } else {
      setState(() => i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    app.backHook = _back;
    final bottom = MediaQuery.paddingOf(context).bottom + 98;
    Widget body = switch (mode) {
      'cards' => _cards(th),
      'quiz' => _quiz(th),
      'done' => _done(th),
      _ => _home(th),
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mode == 'home') ...[
                const HomeHeader(short: false),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(t.bsTitle, style: F.s(28, w: FontWeight.w800, c: p.fg, ls: -.5)),
                ),
              ]
              else
                Capsule(title: t.bsBook(app.bctBook.toUpperCase()), onBack: () => setState(() => mode = 'home')),
              const SizedBox(height: 14),
              body,
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ home
  Widget _home(Th th) {
    final p = th.p;
    final t = app.t;
    final ws = _words;
    Widget book(String b) {
      final on = app.bctBook == b;
      final n = app.lm.bct?.wordsOf(b).length ?? 0;
      return Expanded(
        child: Press(
          onTap: () => setState(() => app.bctBook = b),
          scale: .96,
          selected: on,
          label: '${t.bsBook(b.toUpperCase())}, ${t.bwCount(app.fmt(n))}',
          child: Tile(
            radius: 20,
            color: on ? th.acc.withValues(alpha: .14) : null,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(t.bsBook(b.toUpperCase()), style: F.s(17, w: FontWeight.w800, c: on ? th.acc : p.fg)),
                Text(t.bwCount(app.fmt(n)), style: F.s(12.5, c: p.soft)),
              ],
            ),
          ),
        ),
      );
    }

    Widget tile(String label, Widget icon, VoidCallback f) => Expanded(
      child: Press(
        onTap: ws.isEmpty ? () {} : f,
        label: label,
        child: Glass(
          radius: 22,
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: F.s(13, w: FontWeight.w800, c: p.fg))),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.bsSub, style: F.s(14, c: p.soft, h: 1.4)),
        const SizedBox(height: 14),
        Row(children: [book('a'), const SizedBox(width: 10), book('b')]),
        const SizedBox(height: 14),
        const BctRankCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            tile(t.list, Icon2(I.list, size: 22, color: th.acc, width: 1.9), () => openBctWords(context, app.bctBook)),
            const SizedBox(width: 10),
            tile(t.card, Icon2(I.cards, size: 22, color: th.acc, width: 1.9), _startCards),
            const SizedBox(width: 10),
            tile(t.quiz, Icon2(I.quiz, size: 22, color: th.acc, width: 1.9), _startQuiz),
            const SizedBox(width: 10),
            tile(
              t.gram,
              MediaQuery.withNoTextScaling(
                child: Text('语', locale: const Locale('zh', 'CN'), style: F.s(21, w: FontWeight.w800, c: th.acc, family: F.zh, h: 1.05)),
              ),
              () {
                app.gramBook = 'bct';
                app.go('grammar');
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        GhostBtn(
          t.bsExam,
          wide: true,
          onTap: () {
            app.mockMode = true;
            app.mockPick = 'bct';
            app.mockSec = null;
            app.go('quiz');
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------ cards
  Widget _count(Th th, int n, int total) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: total == 0 ? 0 : n / total, minHeight: 6, backgroundColor: th.p.sunk, valueColor: AlwaysStoppedAnimation(th.acc)),
          ),
        ),
        const SizedBox(width: 10),
        Text('${n + 1}/$total', style: F.s(13, w: FontWeight.w700, c: th.p.soft, feat: F.tab)),
      ],
    ),
  );

  Widget _cards(Th th) {
    final p = th.p;
    final t = app.t;
    final w = deck[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _count(th, i, deck.length),
        Press(
          onTap: () => setState(() => flipped = !flipped),
          label: flipped ? _m(w) : '${w.h}. ${t.bsFlip}',
          child: Glass(
            solid: true,
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 30),
            child: Column(
              children: [
                Text(w.h, textAlign: TextAlign.center, style: F.s(w.h.length > 4 ? 40 : 54, family: F.hz, w: FontWeight.w700, c: p.fg, h: 1.15)),
                const SizedBox(height: 6),
                Text(w.p, style: F.s(18, c: p.soft)),
                const SizedBox(height: 10),
                Spk(w.h, size: 40),
                const SizedBox(height: 18),
                if (flipped) ...[
                  Text(_m(w), textAlign: TextAlign.center, style: F.s(21, w: FontWeight.w800, c: th.acc, h: 1.3)),
                  if (w.z != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, thickness: 1, color: p.line),
                    const SizedBox(height: 14),
                    BctExample(w),
                  ],
                ] else
                  Text(t.bsFlip, style: F.s(13.5, c: p.mute)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: GhostBtn(t.fcDont, wide: true, onTap: () => _cardAnswer(false))),
            const SizedBox(width: 10),
            Expanded(child: MainBtn(t.fcKnow, wide: true, radius: 16, onTap: () => _cardAnswer(true))),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ quiz
  Widget _quiz(Th th) {
    final p = th.p;
    final t = app.t;
    final q = qs[i];
    final done = q.pick != null;
    Widget opt(int k) {
      final o = q.opts[k];
      final good = done && k == q.ans, bad = done && k == q.pick && k != q.ans;
      final col = good ? p.good : (bad ? p.bad : null);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Press(
          onTap: () => _quizPick(k),
          label: q.toMeaning ? _m(o) : o.h,
          child: Glass(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: q.toMeaning
                      ? Text(_m(o), style: F.s(16, w: FontWeight.w700, c: col ?? p.fg, h: 1.3))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.h, style: F.s(22, family: F.hz, w: FontWeight.w700, c: col ?? p.fg)),
                            if (done) Text(o.p, style: F.s(12.5, c: p.soft)),
                          ],
                        ),
                ),
                if (good) Icon2(I.check, size: 20, color: p.good) else if (bad) Icon2(I.close, size: 20, color: p.bad),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _count(th, i, qs.length),
        Glass(
          solid: true,
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(
            children: [
              Text(q.toMeaning ? t.bsQM : t.bsQH, style: F.s(13, w: FontWeight.w700, c: p.mute)),
              const SizedBox(height: 10),
              if (q.toMeaning) ...[
                Text(q.w.h, textAlign: TextAlign.center, style: F.s(q.w.h.length > 4 ? 34 : 46, family: F.hz, w: FontWeight.w700, c: p.fg, h: 1.15)),
                Text(q.w.p, style: F.s(16, c: p.soft)),
                const SizedBox(height: 8),
                Spk(q.w.h, size: 36),
              ] else
                Text(_m(q.w), textAlign: TextAlign.center, style: F.s(21, w: FontWeight.w800, c: p.fg, h: 1.3)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var k = 0; k < q.opts.length; k++) opt(k),
        if (done) MainBtn(t.bsNext, wide: true, radius: 16, big: true, onTap: _quizNext),
      ],
    );
  }

  // ------------------------------------------------------------ end
  Widget _done(Th th) {
    final p = th.p;
    final t = app.t;
    final total = kind == 'quiz' ? qs.length : deck.length;
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.bsDone, textAlign: TextAlign.center, style: F.s(22, w: FontWeight.w800, c: p.fg)),
          const SizedBox(height: 8),
          Text(t.bsScore(right, total), textAlign: TextAlign.center, style: F.s(16, c: p.soft)),
          const SizedBox(height: 20),
          MainBtn(t.bsAgain, wide: true, radius: 16, onTap: kind == 'quiz' ? _startQuiz : _startCards),
          const SizedBox(height: 10),
          GhostBtn(t.bsWordsBtn, wide: true, onTap: () => openBctWords(context, app.bctBook)),
        ],
      ),
    );
  }
}
