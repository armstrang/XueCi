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
import 'donate.dart';
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
/// a note: a short line sits centred, a paragraph reads from the left (centred lines are hard to follow)
Widget _note(BuildContext context, String s, {TextAlign? align}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: SizedBox(
    width: double.infinity,
    child: Rich(
      s,
      align: align ?? (plainText(s).length > 72 ? TextAlign.start : TextAlign.center),
      style: F.s(14.5, c: Th.pal(context).soft, h: 1.45),
      boldColor: Th.pal(context).fg,
    ),
  ),
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
        Padding(padding: const EdgeInsets.fromLTRB(2, 6, 2, 0), child: Rich(t.pyHelp, style: F.s(13.5, c: p.soft, h: 1.45))),
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
                if (!app.ttsOK) ...[const SizedBox(height: 6), Rich(t.strikeNoTts, style: F.s(13.5, c: p.soft, h: 1.45))],
                const SizedBox(height: 6),
                Rich(t.btIntro2, style: F.s(13.5, c: p.soft, h: 1.45)),
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
        // each strike: its name and score on one line, the bar under them at full width (no squeezed label)
        for (final s in x.strikes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: s.hz, style: F.s(15, w: FontWeight.w900, family: F.hz)),
                            TextSpan(text: ' ${L10.text(t.strike[s.k])}'),
                          ],
                        ),
                        style: F.s(14, w: FontWeight.w600, c: !s.skipped && !s.pass ? p.bad : p.fg),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s.skipped ? t.strikeSkip : '${s.right}/${s.n}',
                      style: F.s(14, w: FontWeight.w800, c: !s.skipped && !s.pass ? p.bad : p.fg, feat: F.tab),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 6,
                    color: p.sunk,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (s.skipped || s.n == 0 ? 0 : s.right / s.n).clamp(0, 1).toDouble(),
                      heightFactor: 1,
                      child: ColoredBox(color: s.skipped ? p.mute : (s.pass ? p.good : p.bad)),
                    ),
                  ),
                ),
              ],
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
        if (!x.gate && !x.makeup) DonateAsk(to),
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

/// The ceremony (the mockup Josh picked, Nov 2026), about 11 s, a tap goes straight to the end: the last strike of
/// the tribulation flashes, the 飞升 orb glows inside the five elements and rises, the gate comes out of the dark and
/// opens on a beam of light, 天外有天 gathers and the seal stamps 开, then the path goes on past 飞升 (each realm a
/// circle), what is new, and the way in. Drawn on a 412 × 892 stage scaled to the screen.
class _GateState extends State<_Gate> with SingleTickerProviderStateMixin {
  static const _len = 10.9;
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 10900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _a.value = 1;
    } else {
      _a.forward();
      Future.delayed(const Duration(milliseconds: 950), () {
        if (mounted && _a.value < .1) HapticFeedback.heavyImpact(); // the strike
      });
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  /// a tap: a quick glide to the last moment, then the way in comes up as usual
  void _tap() {
    if (_a.value * _len >= 10.2) return;
    _a.animateTo(10.2 / _len, duration: const Duration(milliseconds: 240), curve: Curves.easeOut).then((_) {
      if (mounted) _a.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = app.t;
    final g = (app.sealedX['gate'] as Map?) ?? const {};
    final door = (g['door'] as List?)?.cast<String>() ?? const ['', ''];
    final n = [7, 8, 9].map((l) => app.by(l).length).fold(0, (a, b) => a + b);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) Navigator.of(context).pop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: '${g['hz'] ?? ''} ${g['py'] ?? ''}',
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: _a,
              builder: (c, _) {
                final tt = _a.value * _len;
                return Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _GateBg(tt))),
                    Positioned.fill(
                      child: SafeArea(
                        child: FittedBox(
                          child: SizedBox(width: 412, height: 892, child: _stage(c, tt, door, n, t.gateSky, t.gateNew(app.fmt(n)), t.gateKeep, t.gateEnter)),
                        ),
                      ),
                    ),
                    // the flash of the strike over everything
                    if (tt > 1.0 && tt < 1.5)
                      Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.white.withValues(alpha: .85 * (1 - (tt - 1.0) / .4).clamp(0, 1))))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  static double _eo(double x) => 1 - math.pow(1 - x, 3).toDouble();
  static double _sp(double x) => 1 - math.exp(-6 * x) * math.cos(9 * x);

  Widget _stage(BuildContext c, double t, List<String> door, int n, String sky, String isNew, String keep, String enter) {
    const gold = Color(0xFFECC277), ink = Color(0xFFF2F4F7);
    Widget at(double l, double tp, double w, double h, Widget child) => Positioned(left: l, top: tp, width: w, height: h, child: child);
    final o = _sp(_seg(t, 1.4, 2.4));
    final rise = _eo(_seg(t, 2.6, 3.6));
    final glow = _seg(t, 1.2, 2.6);
    final op = _eo(_seg(t, 4.2, 5.6));
    final up = -90 * _eo(_seg(t, 7.6, 8.3));
    final title = _seg(t, 5.4, 6.2), spread = 1 - _eo(_seg(t, 5.4, 6.6));
    final st = _seg(t, 6.4, 6.75);
    final nodes = [app.rn[7], app.rn[8], app.rn[9], app.rn[10]];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // the last strike of the tribulation
        if (t > .95 && t < 1.4)
          Positioned.fill(child: Opacity(opacity: 1 - _seg(t, 1.2, 1.4), child: CustomPaint(painter: _Bolt()))),
        // the beam behind the opening doors
        at(
          6,
          120,
          400,
          520,
          Opacity(
            opacity: _seg(t, 4.2, 4.6) * (1 - .55 * _seg(t, 6.2, 7.2)),
            child: Transform.scale(
              scaleX: (20 + 380 * op) / 400,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xF2FFECBE), Color(0x59ECC277), Color(0x00ECC277)],
                    stops: [0, .4, .72],
                  ),
                ),
              ),
            ),
          ),
        ),
        // the gate: a plaque and two doors that swing open
        at(
          66,
          180,
          280,
          420,
          Opacity(
            opacity: _seg(t, 3.2, 3.9) * (1 - _seg(t, 6.4, 7.0)),
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _eo(_seg(t, 3.2, 4)))),
              child: Transform.scale(
                scale: .96 + .04 * _eo(_seg(t, 3.2, 4)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var k = 0; k < 2; k++)
                      Positioned(
                        left: k == 0 ? 0 : 140,
                        top: 0,
                        width: 140,
                        height: 420,
                        child: Transform(
                          alignment: k == 0 ? Alignment.centerLeft : Alignment.centerRight,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 1 / 900)
                            ..rotateY((k == 0 ? -1 : 1) * 78 * op * math.pi / 180),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: k == 0 ? Alignment.topLeft : Alignment.topRight,
                                end: k == 0 ? Alignment.bottomRight : Alignment.bottomLeft,
                                colors: const [Color(0xFF2A2033), Color(0xFF120E18)],
                              ),
                              border: Border.all(color: gold, width: 1.5),
                              borderRadius: k == 0
                                  ? const BorderRadius.horizontal(left: Radius.circular(10))
                                  : const BorderRadius.horizontal(right: Radius.circular(10)),
                            ),
                            alignment: k == 0 ? const Alignment(.8, 0) : const Alignment(-.8, 0),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: 2)),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: -20,
                      right: -20,
                      top: -34,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2A12), Color(0xFF1C140A)]),
                          border: Border.all(color: gold),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(door.join('  '), textScaler: TextScaler.noScaling, style: F.s(17, family: F.hz, w: FontWeight.w900, c: gold, ls: 6, h: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 飞升: the five elements close round the orb, it glows and rises, then fades into the light
        at(
          106,
          290,
          200,
          200,
          Opacity(
            opacity: _seg(t, 1.6, 2.2) * (1 - _seg(t, 4.0, 4.6)),
            child: Transform.translate(
              offset: Offset(0, 60 - 60 * rise),
              child: Transform.rotate(
                angle: (-90 + 120 * _eo(_seg(t, 1.6, 3.6))) * math.pi / 180,
                child: Transform.scale(scale: .7 + .3 * _eo(_seg(t, 1.6, 2.6)), child: CustomPaint(painter: _Elements())),
              ),
            ),
          ),
        ),
        at(
          146,
          330,
          120,
          120,
          Opacity(
            opacity: 1 - _seg(t, 4.3, 5.0),
            child: Transform.translate(
              offset: Offset(0, 60 - 60 * rise),
              child: Transform.scale(
                scale: .85 + .15 * o + .15 * _seg(t, 4.2, 5.0),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 3),
                    color: const Color(0x14ECC277),
                    boxShadow: [BoxShadow(color: gold.withValues(alpha: .3 + .4 * glow), blurRadius: 20 + 60 * glow)],
                  ),
                  alignment: Alignment.center,
                  child: Text(app.rn[7], textScaler: TextScaler.noScaling, style: F.s(34, family: F.hz, w: FontWeight.w900, c: gold, h: 1)),
                ),
              ),
            ),
          ),
        ),
        // 天外有天 gathers, the seal stamps 开, a line under it; then they move up for the path
        at(
          0,
          300 + up,
          412,
          80,
          Opacity(
            opacity: title,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  Transform.translate(
                    offset: Offset((i - 1.5) * 18 * spread, 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '天外有天'[i],
                        textScaler: TextScaler.noScaling,
                        style: F.s(60, family: F.hz, w: FontWeight.w900, c: Colors.white, h: 1.2).copyWith(shadows: [Shadow(color: gold.withValues(alpha: .8), blurRadius: 30)]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (st > 0)
          at(
            338,
            270 + up,
            52,
            52,
            Transform.rotate(
              angle: -8 * math.pi / 180,
              child: Transform.scale(
                scale: st < 1 ? 2.4 - 1.4 * _eo(st) : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x1FD8402E),
                    border: Border.all(color: const Color(0xFFD8402E), width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('开', textScaler: TextScaler.noScaling, style: F.s(30, family: F.hz, w: FontWeight.w900, c: const Color(0xFFD8402E), h: 1)),
                ),
              ),
            ),
          ),
        at(
          12,
          392 + up,
          388,
          60,
          Opacity(
            opacity: _seg(t, 6.8, 7.4),
            child: Semantics(
              liveRegion: true,
              child: Text(sky, textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: F.s(16, c: ink.withValues(alpha: .82), h: 1.5)),
            ),
          ),
        ),
        // the path goes on past 飞升: one circle per realm, a gold link between them
        for (var i = 0; i < 3; i++)
          at(
            20 + i * 96 + 72,
            530,
            36,
            2,
            Transform.scale(
              scaleX: _eo(_seg(t, 8.2 + i * .45, 8.6 + i * .45)),
              alignment: Alignment.centerLeft,
              child: const ColoredBox(color: gold),
            ),
          ),
        for (var i = 0; i < 4; i++)
          at(
            20 + i * 96.0,
            500,
            84,
            96,
            Opacity(
              opacity: _seg(t, 7.9 + i * .45, 8.2 + i * .45),
              child: Transform.translate(
                offset: Offset(0, (1 - _sp(_seg(t, 7.9 + i * .45, 8.5 + i * .45))) * 16),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold, width: 2),
                        color: i == 0 ? gold : const Color(0x14ECC277),
                        boxShadow: [BoxShadow(color: gold.withValues(alpha: i == 0 ? .6 : .25), blurRadius: 22)],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        nodes[i],
                        textScaler: TextScaler.noScaling,
                        style: F.s(19, family: F.hz, w: FontWeight.w900, c: i == 0 ? const Color(0xFF0B0C11) : gold, h: 1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('HSK ${6 + i}', textScaler: TextScaler.noScaling, style: F.s(12.5, w: FontWeight.w600, c: ink.withValues(alpha: .7))),
                  ],
                ),
              ),
            ),
          ),
        // what is new, and the way in
        at(
          24,
          622,
          364,
          86,
          Opacity(
            opacity: _seg(t, 9.6, 10.1),
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - _eo(_seg(t, 9.6, 10.2)))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x13FFFFFF), Color(0x09FFFFFF)]),
                  border: Border.all(color: const Color(0x26FFFFFF)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isNew, textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: F.s(15, w: FontWeight.w800, c: ink)),
                    const SizedBox(height: 4),
                    Text(keep, textAlign: TextAlign.center, textScaler: TextScaler.noScaling, style: F.s(13.5, c: ink.withValues(alpha: .66))),
                  ],
                ),
              ),
            ),
          ),
        ),
        at(
          24,
          730,
          364,
          58,
          Opacity(
            opacity: _seg(t, 10.2, 10.7),
            child: Transform.scale(
              scale: .94 + .06 * _sp(_seg(t, 10.2, 10.9)),
              child: Press(
                onTap: () => Navigator.of(context).pop(),
                scale: .97,
                label: enter,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(29),
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3D595), Color(0xFFD9A94E)]),
                    boxShadow: [BoxShadow(color: gold.withValues(alpha: .7), offset: const Offset(0, 14), blurRadius: 34, spreadRadius: -10)],
                  ),
                  alignment: Alignment.center,
                  child: Text(enter, textScaler: TextScaler.noScaling, style: F.s(18, w: FontWeight.w800, c: const Color(0xFF1B1406))),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// the night behind the ceremony: deep blue and violet, warmed by the gate's light as it opens
class _GateBg extends CustomPainter {
  final double t;
  _GateBg(this.t);
  @override
  void paint(Canvas c, Size s) {
    final warm = ((t - 3.6) / 2.4).clamp(0.0, 1.0);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF07080C));
    void glow(Offset at, double r, Color col) {
      final rect = Rect.fromCircle(center: at, radius: r);
      c.drawRect(rect, Paint()..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)], stops: const [0, .7]).createShader(rect));
    }

    glow(Offset(0, 0), s.width * 1.0, const Color(0xFF283C8C).withValues(alpha: .35));
    glow(Offset(s.width, s.height * .6), s.width * 1.0, const Color(0xFF6E50DC).withValues(alpha: .25 + .1 * warm));
    if (warm > 0) glow(Offset(s.width / 2, s.height * .34), s.width * 1.0, const Color(0xFFECC277).withValues(alpha: .35 * warm));
  }

  @override
  bool shouldRepaint(_GateBg o) => o.t != t;
}

/// the lightning of the last strike
class _Bolt extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(240, 0)
      ..lineTo(205, 210)
      ..lineTo(238, 214)
      ..lineTo(188, 420);
    c.drawPath(p, Paint()
      ..color = const Color(0x59D9D0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round);
    c.drawPath(p, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));
  }

  @override
  bool shouldRepaint(_Bolt o) => false;
}

/// the five elements round the orb: five arcs of the ring, wood fire earth metal water
class _Elements extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const cols = [Color(0xFF4CAF6E), Color(0xFFE0583A), Color(0xFFC9A24A), Color(0xFFC9CCD4), Color(0xFF5A9CF0)];
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: 92);
    for (var i = 0; i < 5; i++) {
      c.drawArc(
        r,
        i * 2 * math.pi / 5,
        2 * math.pi / 5 * .87,
        false,
        Paint()
          ..color = cols[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_Elements o) => false;
}
