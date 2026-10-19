/// The two tests that move the realm (placement.js, breakthrough.js) and the gate after 飞升 (gate.js).
/// Placement test: 50 questions that adapt to the answers. Tribulation (雷劫): the breakthrough as a series of strikes,
/// one per skill, with no feedback until the end; each strike opens with a bolt of lightning, a pass ends in gold.
/// One test a week; leaving a test after 10 answers still uses it (leaveTest).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/runner.dart';
import '../engine/learn.dart';
import '../engine/model.dart';
import '../i18n/l10.dart';
import 'focus.dart';
import 'goal.dart';
import 'glass.dart';
import 'icons.dart';
import 'realm.dart';
import 'shell.dart' show navKey;
import 'run_view.dart' show OptBtn, DottedBox, qPrompt, qOptLabel;
import 'soul.dart' show PerBars;
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

PtState? _pt;
Item? _ptIt;
PtResult? _ptRes;
Trib? _bt;
TribResult? _btRes;

/// called before every screen change (App.beforeShow): leaving a test after 10 answers counts as this week's test
void leaveTest() {
  final lm = app.lm;
  if (app.screen == 'placement' && _pt != null && _ptRes == null && _pt!.items.length >= 10) lm.noteTest();
  if (app.screen == 'bt' && _bt != null && _btRes == null && _bt!.i >= 10) lm.noteTest();
  _btTimer?.cancel();
  _pt = null;
  _ptIt = null;
  _ptRes = null;
  _bt = null;
  _btRes = null;
}

Timer? _btTimer;
App? _owner;

/// the test state belongs to one App (tests boot several)
void _own() {
  if (identical(_owner, app)) return;
  _owner = app;
  _btTimer?.cancel();
  _pt = null;
  _ptIt = null;
  _ptRes = null;
  _bt = null;
  _btRes = null;
}

// ---------------------------------------------------------------- shared pieces
class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ScrollController? scroll;
  const _Page({required this.title, required this.children, this.scroll});
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return SingleChildScrollView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, pad.bottom + 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Capsule(title: title), const SizedBox(height: 12), ...children],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment cross;
  const _Card(this.children, {this.cross = CrossAxisAlignment.center});
  @override
  Widget build(BuildContext context) => Glass(
    solid: true,
    radius: 30,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
    child: Column(crossAxisAlignment: cross, children: children),
  );
}

Widget _big(BuildContext context, String hz, {Color? c}) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(hz, style: F.s(60, w: FontWeight.w900, family: F.hz, c: c ?? Th.of(context).p.t(5), h: 1.1)),
);
Widget _h3(BuildContext context, String s) => Padding(
  padding: const EdgeInsets.only(top: 4, bottom: 8),
  child: Semantics(
    header: true,
    child: Text(s, textAlign: TextAlign.center, style: F.s(19, w: FontWeight.w800, c: Th.pal(context).fg, h: 1.3)),
  ),
);
Widget _note(BuildContext context, String s, {TextAlign align = TextAlign.center}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Rich(s, align: align, style: F.s(13, c: Th.pal(context).soft, h: 1.45), boldColor: Th.pal(context).fg),
);

Widget _head(BuildContext context, int i, int n) {
  final th = Th.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(app.t.qN(i, n), style: F.s(12.5, c: th.p.soft, feat: F.tab)),
        const Spacer(),
        SizedBox(width: 120, child: StackBar([((i - 1) / math.max(1, n)).clamp(0.0, 1.0)].map((x) => (x, th.acc)).toList(), height: 5)),
      ],
    ),
  );
}

/// the screen a test shows while this week's test is used
Widget lockedCard(BuildContext context) {
  final t = app.t;
  return _Card([
    _big(context, '静'),
    _h3(context, t.testLocked),
    _note(context, t.testNext(app.dateS(app.tDate(app.lm.nextTestAt())))),
    _note(context, t.testWhy),
    const SizedBox(height: 12),
    MainBtn(t.sumHome, wide: true, onTap: () => app.go('home')),
  ]);
}

/// a question card: the prompt, the options (or the typing box), "Don't know"
class _QCard extends StatefulWidget {
  final Item it;
  final int? pick; // -1 don't know
  final void Function(int i) onPick;
  final void Function(String typed)? onTyped;
  const _QCard({super.key, required this.it, required this.pick, required this.onPick, this.onTyped});
  @override
  State<_QCard> createState() => _QCardState();
}

class _QCardState extends State<_QCard> {
  final _in = TextEditingController();
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    final it = widget.it;
    if (it.q == 'l' && app.ttsOK) {
      Timer(const Duration(milliseconds: 250), () {
        if (mounted && widget.pick == null) speak(it.d.h);
      });
    }
    if (it.q == 'p') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_in.text.trim().isEmpty || widget.pick != null) return;
    widget.onTyped?.call(_in.text);
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final it = widget.it;
    final busy = widget.pick != null;
    final c = <Widget>[qPrompt(context, it, aid: 'test')];
    if (it.q == 'p') {
      c.addAll([
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Glass(
                solid: true,
                radius: 14,
                child: TextField(
                  controller: _in,
                  focusNode: _focus,
                  readOnly: busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: F.s(18, w: FontWeight.w700, c: p.fg),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: t.pyPh,
                    hintStyle: F.s(16, c: p.mute),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            MainBtn(t.pyCheck, onTap: busy ? null : _submit, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          ],
        ),
        Padding(padding: const EdgeInsets.fromLTRB(2, 6, 2, 0), child: Rich(t.pyHelp, style: F.s(12, c: p.soft, h: 1.4))),
      ]);
    } else {
      final n = it.words?.length ?? it.tones!.length;
      c.add(const SizedBox(height: 14));
      for (var i = 0; i < n; i++) {
        if (i > 0) c.add(const SizedBox(height: 8));
        c.add(OptBtn(n: i + 1, label: qOptLabel(context, it, i), selected: widget.pick == i, onTap: busy ? null : () => widget.onPick(i)));
      }
    }
    c.add(const SizedBox(height: 10));
    c.add(
      Press(
        onTap: busy ? null : () => widget.onPick(-1),
        scale: .97,
        label: t.idk,
        child: Container(
          decoration: BoxDecoration(
            color: widget.pick == -1 ? th.acc.withValues(alpha: .14) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DottedBox(
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Text(t.idk, textAlign: TextAlign.center, style: F.s(14, w: FontWeight.w700, c: p.soft)),
            ),
          ),
        ),
      ),
    );
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c),
    );
  }
}

// ---------------------------------------------------------------- the placement test
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});
  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  int? pick;
  int t0 = 0;

  void _begin() {
    final o = app.lm.ptOpen();
    if (o == 'first' || o == 'retake') _pt = app.lm.ptStart();
    setState(() {});
  }

  void _pick(int i) {
    final it = _ptIt;
    if (it == null || pick != null) return;
    final lm = app.lm;
    final r = i < 0 ? 'idk' : (i == it.ans ? 'ok' : 'ng');
    final x = r == 'ng' && it.q != 's' && it.words != null ? it.words![i].id : null;
    lm.answer(it.d, Ans(it.q!, r == 'ok', ms: nowMs() - t0, x: x, placement: true));
    lm.ptAnswer(_pt!, it, r);
    app.runner.studied();
    setState(() => pick = i);
    Timer(const Duration(milliseconds: 160), () {
      if (!mounted || _ptIt != it) return;
      _ptIt = null;
      pick = null;
      if (_pt!.items.length >= LM.ptN) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _finish() {
    final lm = app.lm;
    final r = _ptRes = lm.ptResult(_pt!);
    lm.placementDone(r);
    app.runner.reset();
    final l = lm.baseLevel();
    if (l != app.level) {
      app.setLevel(l);
    } else {
      app.changed();
    }
    app.toast(app.t.ptDone(app.rn[lm.realm()]));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _own();
    final t = app.t;
    final lm = app.lm;
    final p = Th.pal(context);
    List<Widget> body;
    if (_ptRes != null) {
      final r = _ptRes!, rr = lm.realm();
      body = [
        _Card([
          Text(t.ptResT, style: F.s(14, w: FontWeight.w800, c: p.soft)),
          const SizedBox(height: 6),
          RealmHead(rr, big: true),
          _note(context, r.m > 0 ? t.ptResM(r.m) : t.ptRes0),
          if (rr >= 1 && rr <= 6) StageBox(rr),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(t.ptPer.toUpperCase(), style: F.s(11.5, w: FontWeight.w800, c: p.soft, ls: .6)),
            ),
          ),
          PerBars(r.per),
          _note(context, t.ptResN(r.right, r.n, r.idk)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: GhostBtn(t.sumHome, wide: true, onTap: () => app.go('home'))),
              const SizedBox(width: 10),
              Expanded(
                child: MainBtn(
                  t.ptGoal,
                  wide: true,
                  onTap: () {
                    final lv = lm.baseLevel();
                    app.go('home');
                    Timer(const Duration(milliseconds: 300), () {
                      final c = navKey.currentContext;
                      if (c != null) openGoal(c, false, null, lv);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SoulBtn(),
        ]),
      ];
    } else if (_pt == null) {
      final o = lm.ptOpen();
      if (o == 'wait') {
        body = [lockedCard(context)];
      } else if (o == null) {
        body = [
          _Card([
            _big(context, '门'),
            _h3(context, t.ptClosedT),
            _note(context, t.ptClosed),
            const SizedBox(height: 12),
            MainBtn(t.sumHome, wide: true, onTap: () => app.go('home')),
          ]),
        ];
      } else {
        body = [
          _Card([
            _big(context, '测', c: p.t(3)),
            _h3(context, t.ptIntroT),
            _note(context, t.ptIntro),
            _note(context, t.ptIntro2),
            _note(context, o == 'retake' ? t.ptRetakeNote(app.dateS(app.tDate(lm.ptRetakeUntil()))) : t.ptOnce),
            const SizedBox(height: 14),
            MainBtn(t.ptBegin, wide: true, onTap: _begin),
          ]),
        ];
      }
    } else {
      if (_ptIt == null) {
        _ptIt = lm.ptNext(_pt!);
        t0 = nowMs();
        if (_ptIt == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
          return const SizedBox();
        }
      }
      final n = _pt!.items.length;
      body = [
        _head(context, n + 1, LM.ptN),
        _QCard(key: ValueKey(_ptIt), it: _ptIt!, pick: pick, onPick: _pick),
      ];
    }
    return _Page(title: t.ptT, children: body);
  }
}

class _SoulBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GhostBtn(
    '${app.t.soulGo} ›',
    wide: true,
    lead: Text('识海', style: F.s(14, w: FontWeight.w900, family: F.hz, c: Th.of(context).acc)),
    onTap: () => app.go('soul'),
  );
}

// ---------------------------------------------------------------- the tribulation
/// a strike's lightning (or the golden light of a pass), over the whole screen
final ValueNotifier<({String? hz, bool gold, int seed})?> boltV = ValueNotifier(null);
void bolt(String? hz, {bool gold = false}) {
  boltV.value = (hz: hz, gold: gold, seed: DateTime.now().microsecondsSinceEpoch);
  HapticFeedback.heavyImpact();
}

class BoltLayer extends StatefulWidget {
  const BoltLayer({super.key});
  @override
  State<BoltLayer> createState() => _BoltLayerState();
}

class _BoltLayerState extends State<BoltLayer> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this);
  ({String? hz, bool gold, int seed})? cur;
  List<Offset> main = [], side = [];
  double bx = .5;

  @override
  void initState() {
    super.initState();
    boltV.addListener(_on);
  }

  void _on() {
    final v = boltV.value;
    if (v == null) return;
    final rnd = math.Random(v.seed);
    List<Offset> path(double x, double y, int steps, double dx, double dy) {
      final p = [Offset(x, y)];
      for (var k = 0; k < steps; k++) {
        y += dy * (.6 + rnd.nextDouble() * .8);
        x += (rnd.nextDouble() - .5) * dx;
        p.add(Offset(x, y));
      }
      return p;
    }

    final x0 = 22 + rnd.nextDouble() * 56;
    main = path(x0, -4, 7, 16, 9);
    final at = main[2 + rnd.nextInt(3)];
    side = path(at.dx, at.dy, 3, 12, 7);
    bx = x0 / 100;
    setState(() => cur = v);
    c.duration = Duration(milliseconds: v.gold ? 1050 : 620);
    c.forward(from: 0);
  }

  @override
  void dispose() {
    boltV.removeListener(_on);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = cur;
    if (v == null) return const SizedBox.shrink();
    final th = Th.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: c,
          builder: (ctx, _) {
            final x = c.value;
            if (!c.isAnimating && x >= 1) return const SizedBox.shrink();
            double op;
            if (reduce) {
              op = x < .35 ? x / .35 * .7 : .7 * (1 - (x - .35) / .65);
            } else if (v.gold) {
              op = x < .25 ? x / .25 : 1 - (x - .25) / .75;
            } else {
              // flash, dip, flash, fade
              op = x < .08 ? x / .08 : (x < .2 ? 1 - (x - .08) / .12 * .65 : (x < .3 ? .35 + (x - .2) / .1 * .65 : 1 - (x - .3) / .7));
            }
            final sc = v.gold || reduce ? 1.0 : 1 + .35 * math.pow(1 - math.min(1, x / .6), 3);
            return Opacity(
              opacity: op.clamp(0, 1).toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: v.gold
                          ? RadialGradient(
                              center: const Alignment(0, -.24),
                              radius: .75,
                              colors: [th.p.gold.withValues(alpha: .55), th.p.gold.withValues(alpha: 0)],
                            )
                          : RadialGradient(
                              center: Alignment(bx * 2 - 1, -1),
                              radius: .85,
                              colors: const [Color.fromRGBO(205, 225, 255, .7), Color.fromRGBO(150, 185, 255, .16), Color.fromRGBO(150, 185, 255, 0)],
                              stops: const [0, .48, .72],
                            ),
                    ),
                  ),
                  if (!v.gold && !reduce) CustomPaint(painter: _BoltPainter(main, side, th.low)),
                  if (!v.gold && v.hz != null)
                    Center(
                      child: Transform.scale(
                        scale: sc.toDouble(),
                        child: Text(
                          v.hz!,
                          style: F.s(128, w: FontWeight.w900, family: F.hz, c: Colors.white, h: 1).copyWith(
                            shadows: const [Shadow(color: Color(0xFF8FB6FF), blurRadius: 26), Shadow(color: Color(0xFF4F7FFF), blurRadius: 60)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoltPainter extends CustomPainter {
  final List<Offset> main, side;
  final bool low;
  _BoltPainter(this.main, this.side, this.low);
  @override
  void paint(Canvas canvas, Size s) {
    Path path(List<Offset> p) {
      final r = Path()..moveTo(p[0].dx / 100 * s.width, p[0].dy / 100 * s.height);
      for (final q in p.skip(1)) {
        r.lineTo(q.dx / 100 * s.width, q.dy / 100 * s.height);
      }
      return r;
    }

    void stroke(Path p, double w, double op) {
      if (!low) {
        for (final (c, b) in const [(Color(0xFF5F8FFF), 18.0), (Color(0xFF8FB4FF), 7.0), (Color(0xFF2E5BD8), 2.0)]) {
          canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = c.withValues(alpha: op)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, b / 2),
          );
        }
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFF6F9FF).withValues(alpha: op),
      );
    }

    stroke(path(main), 4.2, 1);
    stroke(path(side), 2, .85);
  }

  @override
  bool shouldRepaint(_BoltPainter o) => o.main != main;
}

class TribScreen extends StatefulWidget {
  const TribScreen({super.key});
  @override
  State<TribScreen> createState() => _TribScreenState();
}

class _TribScreenState extends State<TribScreen> {
  int? pick;
  int t0 = 0;
  Item? bolted;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _btTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _begin() {
    final lm = app.lm;
    if (lm.btOpen() && lm.canTest()) _bt = lm.btStart();
    setState(() {});
  }

  /// i: an option, −1 don't know, −2 typed right, −3 out of time, −4 typed wrong
  void _pick(int i) {
    final st = _bt;
    final it = st == null || st.i >= st.items.length ? null : st.items[st.i];
    if (it == null || pick != null) return;
    _btTimer?.cancel();
    final lm = app.lm;
    final ms = nowMs() - t0;
    final late = it.limit != null && ms > it.limit! * 1000 + 150;
    final r = late || i == -3 ? 'to' : (i == -1 ? 'idk' : (i == -2 || i == it.ans ? 'ok' : 'ng'));
    final x = r == 'ng' && i >= 0 && it.q != 's' && it.q != 't' && it.words != null ? it.words![i].id : null;
    it.r = r;
    if (r == 'ok') st!.right++;
    lm.answer(it.d, Ans(it.q!, r == 'ok', ms: ms, x: x, exam: true));
    app.runner.studied();
    setState(() => pick = i);
    Timer(const Duration(milliseconds: 160), () {
      if (!mounted || _bt != st) return;
      st!.i++;
      pick = null;
      if (st.i >= st.items.length) {
        _done();
      } else {
        setState(() {});
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    });
  }

  void _done() {
    _btTimer?.cancel();
    final lm = app.lm;
    final res = _btRes = lm.btFinish(_bt!);
    if (res.pass) {
      bolt(null, gold: true);
      if (!res.gate) {
        final l = lm.baseLevel();
        if (l != app.level) {
          app.setLevel(l);
        } else {
          app.changed();
        }
        app.toast(app.t.btToast(app.rn[res.r]));
      } else {
        app.changed();
      }
    } else {
      app.changed();
    }
    if (mounted) setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    _own();
    final t = app.t;
    return Stack(
      fit: StackFit.expand,
      children: [
        _Page(title: t.btT, scroll: _scroll, children: _body(context)),
        const Positioned.fill(child: BoltLayer()),
      ],
    );
  }

  List<Widget> _body(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final r = lm.realm();
    if (_btRes != null) return [_result(context, _btRes!)];
    if (_bt == null) {
      if (!lm.btOpen()) {
        return [
          _Card([
            RealmHead(r),
            StageBox(r),
            _note(context, app.memo('stability', lm.stability).ok ? t.btNotOpen : t.btUnstable),
            const SizedBox(height: 12),
            MainBtn(t.sumHome, wide: true, onTap: () => app.go('home')),
          ]),
        ];
      }
      if (!lm.canTest()) return [lockedCard(context)];
      final mk = lm.makeupOpen();
      final l = mk ? 6 : lm.realmLevel(r);
      final to = mk ? 7 : r + 1;
      final cut = (LM.cutOf(l) * 100).round();
      final list = LM.strikes.where((s) => (!s.band || l >= 7) && (!s.tts || app.ttsOK)).toList();
      return [
        _Card([
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(app.rn[r], style: F.s(34, w: FontWeight.w900, family: F.hz, c: rcol(context, r), ls: 2)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('→', style: F.s(22, c: p.soft))),
              Text(mk ? '补劫' : app.rn[to], style: F.s(34, w: FontWeight.w900, family: F.hz, c: rcol(context, to), ls: 2)),
            ],
          ),
          _h3(context, mk ? t.mkIntroT(null) : t.btIntroT(L10.text(t.realmM[to]))),
          const SizedBox(height: 4),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: th.acc.withValues(alpha: .5), width: 1.5)),
                    child: Text(s.hz, style: F.s(17, w: FontWeight.w900, family: F.hz, c: th.acc, h: 1)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(L10.text(t.strike[s.k]), style: F.s(14, w: FontWeight.w800, c: p.fg, h: 1.3)),
                        Text(
                          '${s.n} ${t.strikeQ}${s.timed ? ' · ${t.strikeTime(LM.limitOf(l))}' : ''}',
                          style: F.s(12, c: p.soft, h: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Tile(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Rich(t.btRule(cut), style: F.s(13, c: p.fg, h: 1.45)),
                const SizedBox(height: 6),
                Rich(t.btQuality, style: F.s(13, c: p.fg, h: 1.45)),
                if (!app.ttsOK) ...[const SizedBox(height: 6), Rich(t.strikeNoTts, style: F.s(12.5, c: p.soft, h: 1.45))],
                const SizedBox(height: 6),
                Rich(t.btIntro2, style: F.s(12.5, c: p.soft, h: 1.45)),
              ],
            ),
          ),
          MainBtn(t.btBegin, wide: true, onTap: _begin),
        ], cross: CrossAxisAlignment.stretch),
      ];
    }
    final st = _bt!;
    if (st.i >= st.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _done());
      return const [];
    }
    final it = st.items[st.i];
    final s = st.strikes.firstWhere((x) => x.k == it.strike);
    final first = st.items.indexWhere((x) => x.strike == it.strike) == st.i;
    if (!identical(bolted, it) && pick == null) {
      bolted = it;
      t0 = nowMs();
      if (first) WidgetsBinding.instance.addPostFrameCallback((_) => bolt(s.hz));
      _btTimer?.cancel();
      if (it.limit != null) {
        _btTimer = Timer(Duration(seconds: it.limit!), () {
          if (mounted && _bt == st && st.items[st.i] == it && pick == null) _pick(-3);
        });
      }
    }
    return [
      _head(context, st.i + 1, st.items.length),
      // the strikes as a row of seals: done, current, still to come
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final x in st.strikes.where((x) => !x.skipped && x.n > 0))
                Builder(
                  builder: (c) {
                    final a = st.items.indexWhere((y) => y.strike == x.k), z = a + x.n;
                    final done = st.i >= z, cur = !done && st.i >= a;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: cur ? 1.12 : 1,
                        child: Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done ? th.acc.withValues(alpha: .18) : null,
                            border: Border.all(color: cur ? th.acc : (done ? th.acc.withValues(alpha: .5) : p.line), width: 1.5),
                          ),
                          child: Text(x.hz, style: F.s(14, w: FontWeight.w900, family: F.hz, c: cur || done ? th.acc : p.mute, h: 1)),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: s.hz, style: F.s(16, w: FontWeight.w900, family: F.hz, c: th.acc)),
              TextSpan(text: ' ${L10.text(t.strike[s.k])}'),
            ],
          ),
          textAlign: TextAlign.center,
          style: F.s(13, w: FontWeight.w700, c: p.soft),
        ),
      ),
      if (it.limit != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 5,
              color: p.sunk,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(it),
                tween: Tween(begin: 1, end: 0),
                duration: Duration(seconds: it.limit!),
                builder: (c, v, _) => FractionallySizedBox(widthFactor: v, heightFactor: 1, child: ColoredBox(color: th.acc)),
              ),
            ),
          ),
        ),
      _QCard(
        key: ValueKey(it),
        it: it,
        pick: pick,
        onPick: _pick,
        onTyped: (v) => _pick(app.lm.pyCheck(it.d, v).ok ? -2 : -4),
      ),
    ];
  }

  Widget _result(BuildContext context, TribResult x) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final to = x.makeup ? 7 : x.r;
    final rows = Column(
      children: [
        for (final s in x.strikes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SkRow(
              label: Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: s.hz, style: F.s(14, w: FontWeight.w900, family: F.hz)),
                      TextSpan(text: ' ${L10.text(t.strike[s.k])}'),
                    ],
                  ),
                  style: F.s(12.5, c: !s.skipped && !s.pass ? p.bad : p.fg),
                ),
              ),
              frac: s.skipped || s.n == 0 ? 0 : s.right / s.n,
              color: s.skipped ? p.mute : (s.pass ? p.good : p.bad),
              value: s.skipped ? t.strikeSkip : '${s.right}/${s.n}',
              valueW: 64,
              valueColor: !s.skipped && !s.pass ? p.bad : null,
            ),
          ),
      ],
    );
    if (x.pass) {
      return _Card([
        Text('${x.makeup ? '补劫' : '突破'} · ${t.btPassT}', style: F.s(14, w: FontWeight.w800, c: p.soft)),
        const SizedBox(height: 6),
        RealmHead(to, big: true),
        if (x.grade > 0) BigGrade(x.grade, to),
        if (x.grade > 0) _note(context, L10.text(t.gradeM[x.grade])),
        _note(context, t.btPass(app.rn[to], L10.text(t.realmM[to]))),
        _note(context, t.btScore(x.right, x.n)),
        rows,
        TextButton(
          onPressed: () => app.openShare?.call(context),
          child: Text('${t.shareGo} · ${t.shareT} ›', style: F.s(12.5, w: FontWeight.w800, c: th.acc)),
        ),
        const SizedBox(height: 6),
        if (x.gate)
          MainBtn(t.gateGo, wide: true, onTap: () => openGate(context, true))
        else
          Row(
            children: [
              Expanded(child: GhostBtn(t.sumHome, wide: true, onTap: () => app.go('home'))),
              const SizedBox(width: 10),
              Expanded(child: MainBtn(t.soulGo, wide: true, onTap: () => app.go('soul'))),
            ],
          ),
      ]);
    }
    final failed = x.strikes.where((s) => !s.pass).map((s) => s.hz).join(' ');
    return _Card([
      _big(context, '未破'),
      _h3(context, t.btFailT),
      _note(context, t.btFail(x.right, x.n, (x.need * 100).round())),
      rows,
      _note(context, '${failed.isNotEmpty ? t.btFailStrike(failed) : ''} ${t.btGrow}'.trim()),
      if (x.weak.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(t.btWeak, style: F.s(12, w: FontWeight.w800, c: p.soft)),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in x.weak.take(12))
              Tile(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                radius: 999,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Hz(d, size: 16, weight: FontWeight.w900, family: F.hz),
                    const SizedBox(width: 6),
                    Flexible(child: Text(app.m1(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(12.5, c: p.fg))),
                  ],
                ),
              ),
          ],
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon2(I.lock, size: 14, color: p.soft),
            const SizedBox(width: 6),
            Flexible(child: Text(t.testNext(app.dateS(app.tDate(lm.nextTestAt()))), style: F.s(12, c: p.soft))),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: GhostBtn(t.sumHome, wide: true, onTap: () => app.go('home'))),
          const SizedBox(width: 10),
          Expanded(
            child: x.weak.isNotEmpty
                ? MainBtn(
                    t.btPractice,
                    wide: true,
                    onTap: () {
                      app.runner.pending = Pending('quiz', [for (final d in x.weak.take(12)) Item.q(d, lm.pickType(d))]);
                      app.go('quiz');
                    },
                  )
                : MainBtn(t.soulGo, wide: true, onTap: () => app.go('soul')),
          ),
        ],
      ),
    ]);
  }
}

/// the foundation's quality after a breakthrough: 上品筑基 shàngpǐn zhùjī
class BigGrade extends StatelessWidget {
  final int g, r;
  const BigGrade(this.g, this.r, {super.key});
  static const gpy = ['', 'xiàpǐn', 'zhōngpǐn', 'shàngpǐn', 'wánměi'];
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final gc = switch (g) {
      2 => p.l(3),
      3 => p.l(5),
      4 => p.gold,
      _ => p.mute,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: gc.withValues(alpha: .10),
        border: Border.all(color: gc, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: sh(g == 4 ? [BoxShadow(color: p.gold.withValues(alpha: .18), spreadRadius: 3)] : null),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${LMNames.grades[g]}${app.rn[r]}', style: F.s(24, w: FontWeight.w900, family: F.hz, c: gc, ls: 1)),
          Text('${gpy[g]} ${app.rpy[r]}', style: F.s(11.5, c: p.soft)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- the gate
/// The gate after 飞升 opens with a breakthrough to 飞升: the sealed words join (they ship inside the app) and a short
/// ceremony shows what lies behind it, one tap at a time. Restored on another phone: a welcome instead.
/// Everything it names comes from the sealed part.
Future<void> openGate(BuildContext context, bool ceremony) async {
  try {
    await app.openBand();
  } catch (_) {
    app.toast(app.t.dataFail);
    return;
  }
  app.changed();
  final gs = app.lm.lvInfo?['gs'];
  if (ceremony && !jsTruthy(gs)) {
    if (context.mounted) gateShow(context);
  } else {
    app.lm.gateSeen();
    app.toast(app.t.gateWelcome);
    if (app.screen == 'bt') app.go('home');
  }
}

void gateShow(BuildContext context) {
  final g = (app.sealedX['gate'] as Map?) ?? const {};
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '${g['hz'] ?? ''} ${g['py'] ?? ''}',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (c, a, _) => const _Gate(),
    transitionBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: child),
  ).then((_) {
    app.lm.gateSeen();
    app.go('soul');
  });
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  int step = 0;
  void next() {
    if (step >= 4) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => step++);
  }

  @override
  Widget build(BuildContext context) {
    final t = app.t;
    final g = (app.sealedX['gate'] as Map?) ?? const {};
    final door = (g['door'] as List?)?.cast<String>() ?? const ['', ''];
    const rr = [8, 9, 10];
    final n = [7, 8, 9].map((l) => app.by(l).length).fold(0, (a, b) => a + b);
    final txt = step == 0 ? L10.text(t.v('gate0')) : (step <= 3 ? L10.text(t.realmD[rr[step - 1]]) : t.gate4(app.fmt(n)));
    const ink = Color(0xFFF4ECD8), gold = Color(0xFFE6C36A);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) Navigator.of(context).pop();
      },
      child: GestureDetector(
        onTap: next,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: '${g['hz'] ?? ''} ${g['py'] ?? ''}',
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(center: Alignment(0, -.24), radius: 1, colors: [Color(0xFF2A2412), Color(0xFF06070B)], stops: [0, .7]),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var k = 0; k < 2; k++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              transform: Matrix4.translationValues(step >= 4 ? (k == 0 ? -14 : 14) : 0, 0, 0),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: step >= 4 ? .55 : 1,
                                child: Container(
                                  width: 64,
                                  height: 92,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: gold.withValues(alpha: .07),
                                    border: Border.all(color: gold.withValues(alpha: .65), width: 1.5),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(4)),
                                  ),
                                  child: Text(door.length > k ? door[k] : '', style: F.s(30, w: FontWeight.w900, family: F.hz, c: gold)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${g['hz'] ?? ''}', style: F.s(22, w: FontWeight.w900, family: F.hz, c: gold)),
                          TextSpan(text: '  ${g['py'] ?? ''}', style: F.s(13, c: ink.withValues(alpha: .6))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Flexible(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 280),
                              opacity: step > i ? 1 : 0,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 280),
                                scale: step > i ? 1 : .85,
                                child: Builder(
                                  builder: (c) {
                                    final lc = rcol(c, rr[i]);
                                    return Container(
                                      constraints: const BoxConstraints(maxWidth: 120),
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: lc.withValues(alpha: .14),
                                        border: Border.all(color: lc.withValues(alpha: .7), width: 1.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(app.rn[rr[i]], style: F.s(22, w: FontWeight.w900, family: F.hz, c: const Color(0xFFFFF6DC))),
                                          Text(app.rpy[rr[i]], style: F.s(11.5, c: ink.withValues(alpha: .7))),
                                          Text(
                                            L10.text(t.realmM[rr[i]]),
                                            textAlign: TextAlign.center,
                                            style: F.s(12, w: FontWeight.w700, c: ink),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 66),
                        child: Rich(txt, align: TextAlign.center, style: F.s(14.5, c: ink, h: 1.55)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    MainBtn(step >= 4 ? t.gateEnter : t.gateOn, wide: true, color: gold, onTap: next),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
