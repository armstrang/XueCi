/// Cards, Quiz and today's session on screen (cards.js, quiz.js, summary.js, runner.js, mock.js): the card that turns
/// over, the question card, the end of a run, the rest break, the HSK simulation.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/runner.dart';
import '../data/words.dart';
import '../engine/learn.dart';
import '../engine/model.dart';
import '../i18n/l10.dart';
import 'focus.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

const partHz = {
  'listen': ('听力', 'tīnglì'),
  'read': ('阅读', 'yuèdú'),
  'write': ('书写', 'shūxiě'),
};

String _mmss(num s) => '${s ~/ 60}:${(s.round() % 60).toString().padLeft(2, '0')}';

Map<String, (String, String, String)> qtNames() {
  final t = app.t;
  return {
    'm': (t.tMean, t.dMean, '汉→a'),
    'f': (t.tHz, t.dHz, 'a→汉'),
    's': (t.tTone, t.dTone, 'mā'),
    if (app.canSpeak()) 'l': (t.tListen, t.dListen, '♪→汉'),
    'c': (t.tCloze, t.dCloze, '汉＿'),
    'p': (t.tPy, t.dPy, 'pīn'),
    't': (t.tTrans, t.dTrans, '句→a'),
    'mock': (t.tMock, t.dMock, '模'),
  };
}

String tName(String q) => switch (q) {
  'm' => app.t.tMean,
  'f' => app.t.tHz,
  's' => app.t.tTone,
  'l' => app.t.tListen,
  'c' => app.t.tCloze,
  'p' => app.t.tPy,
  'ls' => app.t.qtLs,
  'lt' => app.t.qtLt,
  'lj' => app.t.qtLj,
  'wo' => app.t.qtWo,
  'wh' => app.t.qtWh,
  _ => app.t.tTrans,
};

/// how much help a sentence gap gets. The word's HSK level sets it: 1–2 the meaning and pinyin, 3–4 the meaning,
/// 5 up the sentence alone. In practice a word getting strong lets it go (pinyin from level 7, the meaning from 14).
/// Tests keep the level's help; the HSK simulation prints pinyin up to HSK 2, like the real paper.
({bool py, bool tr}) clozeAid(Word d, String aid) {
  if (aid == 'mock') return (py: d.l <= 2, tr: false);
  var py = d.l <= 2, tr = d.l <= 4;
  if (aid == 'practice') {
    final v = app.lvl(d);
    if (v >= 7) py = false;
    if (v >= 14) tr = false;
  }
  return (py: py, tr: tr);
}

/// pinyin syllables written as one word (an apostrophe before a, e, o)
String pyOpt(List<String> a) {
  final b = StringBuffer();
  for (var i = 0; i < a.length; i++) {
    if (i > 0 && RegExp(r'^[aeoāáǎàēéěèōóǒò]', caseSensitive: false).hasMatch(a[i])) b.write("'");
    b.write(a[i]);
  }
  return b.toString();
}

class RunScreen extends StatefulWidget {
  final String mode;
  const RunScreen({super.key, required this.mode});
  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final _scroll = ScrollController();
  int _lastI = -1;
  int _top = app.scrollTop;

  @override
  void dispose() {
    _scroll.dispose();
    if (app.backHook == _back) app.backHook = null;
    super.dispose();
  }

  bool _back() {
    final r = app.runner.run;
    final m = r?.mock;
    if (app.screen == 'quiz' && m != null && m.started && m.r == null) {
      if (nowMs() - m.warned > 3500) {
        m.warned = nowMs();
        app.toast(app.t.mkLeave);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    app.backHook = _back;
    final R = app.runner;
    final r = R.ensure(widget.mode);
    R.prepare();
    final t = app.t;
    if (r.i != _lastI || _top != app.scrollTop) {
      _lastI = r.i;
      _top = app.scrollTop;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    final title = switch (widget.mode) {
      'card' => t.card,
      'quiz' => t.quiz,
      _ => t.session,
    };
    final it = r.cur;
    final m = r.mock;
    Widget body;
    if (m != null && !m.started) {
      body = _MockIntro(r);
    } else if (r.brk != null) {
      body = _BreakView(r);
    } else if (it == null) {
      body = m != null ? _MockResult(r) : _Summary(r);
    } else if (m != null && !m.shown.contains(it.part)) {
      body = _MockPart(r, it.part!);
    } else if (it.k == 'card') {
      body = _CardView(r, it, key: ValueKey(it));
    } else {
      body = _QView(r, it, key: ValueKey(it));
    }
    final tabs = !['session'].contains(widget.mode) && !app.inExam;
    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        MediaQuery.paddingOf(context).bottom + (tabs ? 90 : 24),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Capsule(title: title, pickers: widget.mode != 'session'),
              const SizedBox(height: 12),
              if (!(m != null && it == null)) _RunHead(r),
              // the next card or question comes in alone (the old one leaves at once): one glass card drawn, not two
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                reverseDuration: Duration.zero,
                layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (w, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, .015), end: Offset.zero).animate(a), child: w),
                ),
                child: RepaintBoundary(key: ValueKey('${r.hashCode}:${r.i}:${r.brk != null}:${it?.st}'), child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- the head of a run
class _RunHead extends StatelessWidget {
  final Run r;
  const _RunHead(this.r);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final n = r.items.length;
    final i = math.min(r.i + 1, n);
    final it = r.cur;
    Widget prog() => SizedBox(
      width: 120,
      child: StackBar([((r.i / math.max(1, n)).clamp(0, 1).toDouble(), th.acc)], height: 5),
    );
    final small = F.s(12.5, c: p.soft, feat: F.tab);
    if (r.mode == 'card') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [Text(t.cardN(i, n), style: small), const Spacer(), prog()]),
      );
    }
    if (r.mode == 'session') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(t.qN(i, n), style: small),
            const Spacer(),
            if (it != null && it.k == 'q') Text(tName(it.q!), style: F.s(12.5, w: FontWeight.w800, c: th.acc)),
            const SizedBox(width: 10),
            prog(),
          ],
        ),
      );
    }
    final m = r.mock;
    if (m != null && m.started && it != null) {
      final k = it.part!;
      final its = m.m.items.where((x) => x.part == k).toList();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(partHz[k]!.$1, style: F.s(16, w: FontWeight.w900, family: F.hz, c: th.acc)),
            const SizedBox(width: 6),
            Flexible(child: Text(L10.text(t.partN[k]), style: F.s(13, w: FontWeight.w700, c: p.fg))),
            const SizedBox(width: 6),
            Text('${its.indexOf(it) + 1}/${its.length}', style: small),
            const Spacer(),
            if (m.sec == k) ...[const _Clock(), const SizedBox(width: 12)],
            Text(t.qN(r.i + 1, n), style: small),
          ],
        ),
      );
    }
    final qt = qtNames();
    final cur = qt[app.qType] ?? qt['m']!;
    final clockOn = r.exam && !(m != null && (!m.started || m.r != null));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Press(
            onTap: () => _openQType(context),
            scale: 1.06,
            label: '${t.qTypeL}: ${cur.$1}',
            child: Glass(
              radius: 999,
              height: 40,
              padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Qti(cur.$3, on: false),
                  const SizedBox(width: 8),
                  Text(cur.$1, style: F.s(13, w: FontWeight.w800, c: p.fg)),
                  const SizedBox(width: 6),
                  Icon2(I.chev, size: 14, color: p.mute),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (m != null && !clockOn)
            Text(t.qN(m.r != null ? n : 0, n), style: small)
          else if (r.exam) ...[
            const _Clock(),
            const SizedBox(width: 12),
            Text(t.qN(i, n), style: small),
          ] else ...[
            Text(t.qN(i, n), style: small),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${t.right} '),
                  TextSpan(text: '${r.ok}', style: F.s(14, w: FontWeight.w800, c: p.fg)),
                  TextSpan(text: '/${r.tot}'),
                ],
              ),
              style: small,
            ),
          ],
        ],
      ),
    );
  }

  void _openQType(BuildContext context) {
    final qt = qtNames();
    app.menuOpen = true;
    app.changed();
    openMenu(context, (c) {
      final p = Th.pal(c);
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in qt.entries)
              Press(
                onTap: () {
                  Navigator.pop(c);
                  if (e.key != app.qType) {
                    app.qType = e.key;
                    app.saveUI();
                    app.runner.reset();
                  }
                  app.changed();
                },
                scale: .97,
                selected: e.key == app.qType,
                label: '${e.value.$1}. ${e.value.$2}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: e.key == app.qType ? Th.of(c).acc.withValues(alpha: .14) : null,
                  ),
                  child: Row(
                    children: [
                      _Qti(e.value.$3, on: e.key == app.qType),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value.$1, style: F.s(14.5, w: FontWeight.w700, c: p.fg)),
                            Text(e.value.$2, style: F.s(12, c: p.soft, h: 1.3)),
                          ],
                        ),
                      ),
                      if (e.key == app.qType) Icon2(I.check, size: 16, color: Th.of(c).acc),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }).then((_) {
      app.menuOpen = false;
      app.changed();
    });
  }
}

class _Qti extends StatelessWidget {
  final String s;
  final bool on;
  const _Qti(this.s, {required this.on});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return Container(
      width: 48,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? th.acc : th.acc.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(s, style: F.s(11.5, w: FontWeight.w800, family: F.zh, c: on ? th.p.onAcc : th.p.fg)),
    );
  }
}

class _Clock extends StatefulWidget {
  const _Clock();
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = app.runner.secondsLeft();
    return Semantics(
      liveRegion: false,
      child: Text(_mmss(s), style: F.s(14, w: FontWeight.w800, c: s <= 30 ? Th.pal(context).bad : Th.pal(context).fg, feat: F.tab)),
    );
  }
}

// ---------------------------------------------------------------- a card
class _CardView extends StatelessWidget {
  final Run r;
  final Item it;
  const _CardView(this.r, this.it, {super.key});
  @override
  Widget build(BuildContext context) {
    final R = app.runner;
    R.cardStart(it);
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final d = it.d;
    final back = it.st == 'back';
    final checking = it.st == 'check';
    final narrow = MediaQuery.sizeOf(context).width <= 520;
    final h = checking ? 230.0 : (narrow ? 380.0 : 340.0);
    final front = _Face(
      top: true,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: Align(
              alignment: Alignment.topRight,
              child: R.fresh(it)
                  ? Text(t.newWord, style: F.s(12.5, w: FontWeight.w800, c: th.acc))
                  : LevelLine(d),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  d.h,
                  style: F.s(math.min(92, math.max(56, MediaQuery.sizeOf(context).width * .16)), w: FontWeight.w900, family: F.hz, c: p.fg, h: 1),
                  locale: const Locale('zh', 'CN'),
                  textScaler: TextScaler.linear(th.fsd),
                ),
                const SizedBox(height: 10),
                Spk(d.h, size: 46, onSpoken: () {
                  if (it.st == 'front') it.heard = true;
                }),
              ],
            ),
          ),
          if (!checking)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Text(t.fcHint, textAlign: TextAlign.center, style: F.s(12, c: p.mute)),
            ),
        ],
      ),
    );
    final backFace = _Face(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WordHead(d, hz: 34),
          const SizedBox(height: 4),
          WordBody(d, mean: 16),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: h,
          child: _Flip(on: back, front: front, back: backFace),
        ),
        const SizedBox(height: 12),
        _cardAct(context),
      ],
    );
  }

  Widget _cardAct(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final R = app.runner;
    if (it.st == 'front') {
      return Row(
        children: [
          Expanded(
            child: _BigBtn(t.fcDont, color: p.cardC, fg: p.bad, onTap: () => R.cardDont(it)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BigBtn(t.fcKnow, color: th.acc, fg: p.onAcc, onTap: () => R.cardKnow(it)),
          ),
        ],
      );
    }
    if (it.st == 'check') {
      final c = it.check!;
      final tone = it.checkQ == 'cs';
      return Glass(
        radius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tone ? t.chkTone : t.chkMean, textAlign: TextAlign.center, style: F.s(13, w: FontWeight.w800, c: th.acc)),
            const SizedBox(height: 8),
            for (var i = 0; i < (tone ? c.tones!.length : c.words!.length); i++) ...[
              if (i > 0) const SizedBox(height: 8),
              OptBtn(
                n: i + 1,
                label: Text(
                  tone ? pyOpt(c.tones![i]) : app.m1(c.words![i]),
                  style: F.s(15, w: FontWeight.w600, c: p.fg),
                ),
                onTap: () => R.cardCheck(it, i),
              ),
            ],
          ],
        ),
      );
    }
    final msg = switch (it.res) {
      'ok' => t.resOk,
      'over' => t.resOver,
      'no' => t.resNo,
      _ => t.resTrust,
    };
    final (bg, fg) = switch (it.res) {
      'ok' => (p.good.withValues(alpha: .13), p.good),
      'over' => (p.bad.withValues(alpha: .12), p.bad),
      _ => (p.fgA(.06), p.soft),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Rich(msg, style: F.s(13.5, w: FontWeight.w700, c: fg, h: 1.4)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (it.res == 'trust') ...[
              Expanded(child: _BigBtn(t.oops, color: p.cardC, fg: p.bad, onTap: () => R.cardOops(it))),
              const SizedBox(width: 10),
            ],
            Expanded(child: _BigBtn(t.next, color: th.acc, fg: p.onAcc, onTap: R.next, autofocus: true)),
          ],
        ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool scroll;
  const _Face({required this.child, this.top = false, this.scroll = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: Glass(
            solid: true,
            radius: 30,
            padding: const EdgeInsets.all(22),
            child: scroll ? SingleChildScrollView(child: child) : child,
          ),
        ),
        if (top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FractionallySizedBox(
              widthFactor: .4,
              child: Container(
                height: 3,
                decoration: BoxDecoration(color: th.acc, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4))),
              ),
            ),
          ),
      ],
    );
  }
}

/// the card turns over (a 3D turn around the vertical axis, .5 s)
class _Flip extends StatelessWidget {
  final bool on;
  final Widget front, back;
  const _Flip({required this.on, required this.front, required this.back});
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1 : 0),
      duration: Duration(milliseconds: reduce ? 0 : 500),
      curve: const Cubic(.2, .7, .2, 1),
      builder: (c, v, _) {
        final showBack = v > .5;
        final a = v * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 1 / 1400)
            ..rotateY(a),
          child: showBack
              ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: back)
              : front,
        );
      },
    );
  }
}

class _BigBtn extends StatelessWidget {
  final String label;
  final Color color, fg;
  final VoidCallback onTap;
  final bool autofocus;
  const _BigBtn(this.label, {required this.color, required this.fg, required this.onTap, this.autofocus = false});
  @override
  Widget build(BuildContext context) => Press(
    onTap: onTap,
    scale: .97,
    label: label,
    child: Builder(
      builder: (c) {
        final th = Th.of(c);
        final tinted = color != th.p.cardC;
        final text = Text(label, textAlign: TextAlign.center, style: F.s(15, w: FontWeight.w800, c: tinted && th.p.dark ? th.p.fg : fg));
        const pad = EdgeInsets.symmetric(vertical: 14, horizontal: 10);
        // the quiet choice is glass, the coloured one a lit drop of colour (MainBtn)
        if (color == th.p.cardC) {
          return Glass(radius: 22, solid: true, padding: pad, child: Center(heightFactor: 1, child: text));
        }
        // the coloured one: tinted liquid glass (as MainBtn)
        return CustomPaint(
          painter: OuterShadow(
            th.low ? const [] : [BoxShadow(color: color.withValues(alpha: .36), offset: const Offset(0, 10), blurRadius: 24, spreadRadius: -10)],
            22,
          ),
          child: Glass(
            inner: true,
            radius: 22,
            padding: pad,
            shadow: const [],
            color: Color.lerp(color, Colors.black, th.p.dark ? .35 : .2)!.withValues(alpha: th.p.dark ? .5 : .78),
            child: Center(heightFactor: 1, child: text),
          ),
        );
      },
    ),
  );
}

/// an answer option: glass, green when right, red when the wrong pick
class OptBtn extends StatefulWidget {
  final int n;
  final Widget label;
  final VoidCallback? onTap;
  final bool? state; // true right, false the wrong pick, null neutral
  final bool selected;
  const OptBtn({super.key, required this.n, required this.label, this.onTap, this.state, this.selected = false});
  @override
  State<OptBtn> createState() => _OptBtnState();
}

/// the answer reacts when it is judged: a small pop when right, a short shake when it was the wrong pick
class _OptBtnState extends State<OptBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));

  @override
  void didUpdateWidget(OptBtn o) {
    super.didUpdateWidget(o);
    if (o.state == null && widget.state != null && !MediaQuery.of(context).disableAnimations) {
      _a.forward(from: 0);
      if (widget.state == false) HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final state = widget.state;
    final Color? fill = state == true
        ? p.good.withValues(alpha: .16)
        : state == false
        ? p.bad.withValues(alpha: .13)
        : widget.selected
        ? th.acc.withValues(alpha: .14)
        : null;
    final Color? border = state == true ? p.good.withValues(alpha: .65) : (state == false ? p.bad.withValues(alpha: .65) : null);
    final body = Stack(
      children: [
        Glass(
          solid: true,
          inner: true,
          radius: 18,
          color: fill,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Text('${widget.n}. ', style: F.s(15, w: FontWeight.w600, c: p.fg)),
              Expanded(child: widget.label),
            ],
          ),
        ),
        if (border != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
    return Press(
      onTap: widget.onTap,
      scale: .97,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _a,
          child: body,
          builder: (c, child) {
            final t = _a.value;
            if (t == 0 || t == 1 || widget.state == null) return child!;
            if (widget.state == true) {
              return Transform.scale(scale: 1 + .035 * math.sin(t * math.pi), child: child);
            }
            return Transform.translate(offset: Offset(7 * math.sin(t * math.pi * 3) * (1 - t), 0), child: child);
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- a question
class _QView extends StatefulWidget {
  final Run r;
  final Item it;
  const _QView(this.r, this.it, {super.key});
  @override
  State<_QView> createState() => _QViewState();
}

class _QViewState extends State<_QView> {
  final _in = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final it = widget.it;
    if (it.q == 'l' && !it.heard && app.ttsOK && widget.r.mock == null) {
      it.heard = true;
      Timer(const Duration(milliseconds: 250), () {
        if (mounted && !it.done) speak(it.d.h);
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
    final v = _in.text;
    if (v.trim().isEmpty) return;
    app.runner.qTyped(widget.it, v);
  }

  @override
  Widget build(BuildContext context) {
    final R = app.runner;
    final it = widget.it;
    final r = widget.r;
    R.qPrepare(it);
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final q = it.q!;
    final ans = it.done && !r.exam;
    final ok = it.ok == true;
    final children = <Widget>[];
    // the prompt
    final aid = r.mock != null ? 'mock' : 'practice';
    children.add(qPrompt(context, it, aid: aid));
    // the options, the pieces of a sentence or the typing box
    if (q == 'wo') {
      children.add(const SizedBox(height: 14));
      children.add(_Order(it));
    } else if (q == 'p') {
      children.add(const SizedBox(height: 12));
      if (it.done) {
        children.add(
          Glass(
            solid: true,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              it.typedText ?? '',
              style: F.s(18, w: FontWeight.w700, c: ok ? p.good : p.bad).copyWith(decoration: ok ? null : TextDecoration.lineThrough),
            ),
          ),
        );
      } else {
        if (!_focus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !it.done) _focus.requestFocus();
          });
        }
        children.add(
          Row(
            children: [
              Expanded(
                child: Glass(
                  solid: true,
                  radius: 14,
                  child: TextField(
                    controller: _in,
                    focusNode: _focus,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.visiblePassword,
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
              MainBtn(t.pyCheck, onTap: _submit, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            ],
          ),
        );
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
          child: Rich(t.pyHelp, style: F.s(12, c: p.soft, h: 1.4)),
        ));
        children.add(const SizedBox(height: 10));
        children.add(
          Press(
            onTap: () => R.qTyped(it, null),
            scale: .97,
            label: t.idk,
            child: DottedBox(
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Text(t.idk, textAlign: TextAlign.center, style: F.s(14, w: FontWeight.w700, c: p.soft)),
              ),
            ),
          ),
        );
      }
    } else {
      final n = q == 'lj' ? 2 : (it.words?.length ?? it.tones!.length);
      children.add(const SizedBox(height: 14));
      for (var i = 0; i < n; i++) {
        if (i > 0) children.add(const SizedBox(height: 8));
        children.add(
          OptBtn(
            n: i + 1,
            label: qOptLabel(context, it, i, py: aid == 'mock' && it.d.l <= 2),
            state: !ans ? null : (i == it.ans ? true : (i == it.pick ? false : null)),
            selected: r.exam && it.done && i == it.pick,
            onTap: it.done ? null : () => R.qAnswer(it, i),
          ),
        );
      }
    }
    // the feedback
    if (ans) children.add(_feedback(context, it, ok));
    return Stack(
      children: [
        Glass(
          solid: true,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: th.acc, borderRadius: BorderRadius.circular(4))),
          ),
        ),
      ],
    );
  }

  Widget _feedback(BuildContext context, Item it, bool ok) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final R = app.runner;
    final d = it.d;
    final q = it.q;
    final picked = !ok && q != 's' && q != 'p' && q != 't' && it.words != null && (it.pick ?? -1) >= 0 ? it.words![it.pick!] : null;
    final amb = q == 'c' && !ok && picked != null && !it.heard && R.ambLeft() > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: it.heard && q == 'c'
                ? Text(t.ambDone, style: F.s(13.5, w: FontWeight.w700, c: p.soft))
                : Text(ok ? t.ok : t.ng, style: F.s(17, w: FontWeight.w800, c: ok ? p.good : p.bad)),
          ),
          if (q == 'p' && !ok && it.timedOut) Text(t.pyToneless, style: F.s(13, c: p.soft)),
          if (q == 'p' && ok && it.alt is Word) Rich(t.pyAlt((it.alt as Word).h), style: F.s(13, c: p.soft)),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${t.picked} '),
                    TextSpan(text: picked.h, style: F.s(16, w: FontWeight.w900, family: F.hz, c: p.fg)),
                    TextSpan(text: ' ${picked.p} · ${app.m1(picked)}'),
                  ],
                ),
                style: F.s(13, c: p.soft),
              ),
            ),
          if (amb)
            TextButton(
              onPressed: () => R.qAmbig(it),
              child: Text(t.ambBtn, style: F.s(13, w: FontWeight.w700, c: th.acc)),
            ),
          const SizedBox(height: 4),
          WordHead(d),
          const SizedBox(height: 4),
          WordBody(d),
          const SizedBox(height: 6),
          LevelLine(d),
          const SizedBox(height: 14),
          MainBtn(t.next, wide: true, radius: 20, onTap: R.next),
        ],
      ),
    );
  }
}

/// an option's label: a meaning, a translation, tones, same/different or hanzi ([py]: with pinyin under it, as the
/// HSK 1–2 paper prints it)
Widget qOptLabel(BuildContext context, Item it, int i, {bool py = false}) {
  final p = Th.pal(context);
  final q = it.q;
  if (q == 'lj') return Text(i == 0 ? app.t.jdSame : app.t.jdDiff, style: F.s(15, w: FontWeight.w700, c: p.fg));
  if (it.tones != null) return Text(pyOpt(it.tones![i]), style: F.s(15, w: FontWeight.w700, c: p.fg));
  final o = it.words![i];
  if (q == 'm') return Text(app.m1(o), style: F.s(15, w: FontWeight.w600, c: p.fg));
  if (q == 't' || q == 'lt') return Text(app.tr(o), style: F.s(14, w: FontWeight.w600, c: p.fg, h: 1.4));
  final hz = Text(o.h, style: F.s(20, w: FontWeight.w900, family: F.hz, c: p.fg), locale: const Locale('zh', 'CN'));
  if (!py || q == 'wh' || q == 'l') return hz;
  return Row(children: [hz, const SizedBox(width: 10), Text(o.p, style: F.s(13, c: p.soft))]);
}

/// a question's prompt (shared by Quiz, the session, the placement test, the tribulation and the HSK simulation);
/// [aid]: practice, test or mock (how much a sentence gap is helped, see [clozeAid])
Widget qPrompt(BuildContext context, Item it, {String aid = 'practice'}) {
  final d = it.d;
  final q = it.q!;
  final th = Th.of(context);
  final p = th.p;
  final t = app.t;
  final big = math.min(72.0, math.max(48.0, MediaQuery.sizeOf(context).width * .13));
  Widget lead(String s) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Text(s, textAlign: TextAlign.center, style: F.s(13, c: p.soft)),
  );
  Widget rest() {
    final m = app.m(d).split(';').skip(1).map((x) => x.trim()).where((x) => x.isNotEmpty).join('; ');
    return m.isEmpty ? const SizedBox.shrink() : Text(m, textAlign: TextAlign.center, style: F.s(12.5, c: p.soft, style: FontStyle.italic));
  }

  Widget m1() => Text(app.m1(d), textAlign: TextAlign.center, style: F.s(22, w: FontWeight.w800, c: p.fg));
  final c = <Widget>[];
  switch (q) {
    case 'p':
      c.addAll([lead(t.qPy), m1(), rest()]);
      if (it.d.z.contains(it.d.h)) c.add(Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: ExampleText(d, gap: true))));
    case 't':
      c.addAll([
        lead(t.qTrans),
        Center(child: ExampleText(d, size: 20)),
        if (d.l <= (aid == 'mock' ? 2 : 3)) Center(child: ZpText(d, plainWord: true)),
      ]);
    case 'ls' || 'lt':
      c.addAll([lead(q == 'ls' ? t.qHeard : t.qHeardT), Center(child: _Play(it, d.z))]);
    case 'lj':
      final x = it.words?.first ?? d;
      c.addAll([
        lead(t.qJudge),
        Center(child: _Play(it, d.z)),
        const SizedBox(height: 10),
        Center(child: ExampleText(d, size: 20, fill: x.h, plainFill: true)),
        if (d.l <= 2) Center(child: ZpText(d, fill: x.p)),
      ]);
    case 'wh':
      c.addAll([lead(t.qPyHz), Center(child: ExampleText(d, size: 20, fill: '（${d.p}）'))]);
    case 'wo':
      c.add(lead(t.qOrder));
    case 'm':
      c.addAll([lead(t.qMean), Center(child: Hz(d, size: big, weight: FontWeight.w900, family: F.hz))]);
    case 'f':
      c.addAll([lead(t.qHz), m1(), rest()]);
    case 's':
      c.addAll([
        lead(t.qTone),
        Center(child: Text(d.h, style: F.s(big, w: FontWeight.w900, family: F.hz, c: p.fg, h: 1.1), locale: const Locale('zh', 'CN'))),
        Text(app.m1(d), textAlign: TextAlign.center, style: F.s(12.5, c: p.soft, style: FontStyle.italic)),
      ]);
    case 'l':
      c.addAll([lead(t.qListen), Center(child: aid == 'mock' ? _Play(it, d.h) : Spk(d.h, size: 76))]);
    default:
      final help = clozeAid(d, aid);
      c.addAll([
        lead(t.qCloze),
        Center(child: ExampleText(d, size: 20, gap: true)),
        if (help.py) Center(child: ZpText(d, gap: true)),
        if (help.tr || (it.hint && !it.done))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(app.tr(d), textAlign: TextAlign.center, style: F.s(13.5, c: p.soft, h: 1.4)),
          )
        else if (aid == 'practice' && !it.done)
          Center(
            child: TextButton(
              onPressed: () {
                it.hint = true;
                app.changed();
              },
              child: Text(t.showTr, style: F.s(13, w: FontWeight.w700, c: th.acc)),
            ),
          ),
      ]);
  }
  return Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c));
}

/// the simulation's listening: the sentence plays by itself, and once more on a tap (twice in all, like the paper)
class _Play extends StatefulWidget {
  final Item it;
  final String text;
  const _Play(this.it, this.text);
  @override
  State<_Play> createState() => _PlayState();
}

class _PlayState extends State<_Play> {
  @override
  void initState() {
    super.initState();
    final it = widget.it;
    if (it.plays == 0 && app.ttsOK) {
      it.plays = 1;
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && !it.done) speak(widget.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final it = widget.it;
    final left = math.max(0, 2 - it.plays);
    final on = left > 0 && !it.done && app.ttsOK;
    return Column(
      children: [
        Press(
          onTap: on
              ? () {
                  setState(() => it.plays++);
                  speak(widget.text);
                }
              : null,
          scale: .9,
          label: on ? t.playN(left) : t.playDone,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: on ? .15 : .07)),
            child: Center(child: Icon2(I.speaker, size: 36, color: on ? th.acc : p.mute)),
          ),
        ),
        const SizedBox(height: 6),
        Text(on ? t.playN(left) : t.playDone, style: F.s(12.5, w: FontWeight.w700, c: on ? p.soft : p.mute)),
      ],
    );
  }
}

/// sentence building: tap the pieces in order; a placed piece goes back on a tap
class _Order extends StatefulWidget {
  final Item it;
  const _Order(this.it);
  @override
  State<_Order> createState() => _OrderState();
}

class _OrderState extends State<_Order> {
  final List<int> _pick = [];

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final it = widget.it;
    final parts = it.parts ?? const <String>[];
    final end = RegExp(r'[。！？!?.]+$').firstMatch(it.d.z.trim())?.group(0) ?? '';
    final hz = F.s(19, w: FontWeight.w800, family: F.zh, c: p.fg);
    Widget piece(String s, VoidCallback? onTap, {bool placed = false}) => Press(
      onTap: onTap,
      scale: .94,
      label: s,
      child: Tile(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Text(s, style: placed ? hz.copyWith(color: th.acc) : hz, locale: const Locale('zh', 'CN')),
      ),
    );
    final done = _pick.length == parts.length && parts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the sentence so far
        Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line, width: 1.5))),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var k = 0; k < _pick.length; k++)
                piece(parts[_pick[k]], it.done ? null : () => setState(() => _pick.removeAt(k)), placed: true),
              if (done && end.isNotEmpty) Text(end, style: hz),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // the pieces left
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var k = 0; k < parts.length; k++)
              if (!_pick.contains(k)) piece(parts[k], it.done ? null : () => setState(() => _pick.add(k))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: GhostBtn(t.orderClear, wide: true, onTap: _pick.isEmpty || it.done ? null : () => setState(_pick.clear)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: MainBtn(
                t.orderDone,
                wide: true,
                radius: 16,
                onTap: done && !it.done ? () => app.runner.qOrder(it, [for (final k in _pick) parts[k]]) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// a dashed outline (the "Don't know" button)
class DottedBox extends StatelessWidget {
  final Widget child;
  const DottedBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Dash(Th.pal(context).line), child: child);
}

class _Dash extends CustomPainter {
  final Color c;
  _Dash(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(14)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dash o) => o.c != c;
}

// ---------------------------------------------------------------- the end of a run
class _Summary extends StatelessWidget {
  final Run r;
  const _Summary(this.r);
  @override
  Widget build(BuildContext context) {
    final R = app.runner;
    R.close();
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final n = r.tot, ok = r.ok;
    final pct = n > 0 ? (ok / n * 100).round() : 0;
    final up = r.before.entries.where((e) {
      final d = app.vocab.idx[e.key];
      return d != null && app.lvl(d) > math.max(e.value, 0);
    }).length;
    final wrong = r.wrong.values.toList();
    final seen = <String>{};
    final pairs = r.conf.where((c) {
      final k = c.$1.compareTo(c.$2) < 0 ? '${c.$1}${c.$2}' : '${c.$2}${c.$1}';
      return seen.add(k);
    }).take(3).toList();
    final kind = r.quick ? 'quick' : r.mode;
    final notes = <String>[];
    if (r.over > 0) notes.add(t.sumOver(r.over));
    Widget cell(String a, String b) => Expanded(
      child: Tile(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        radius: 14,
        child: Column(
          children: [
            Text(a, style: F.s(20, w: FontWeight.w800, c: p.fg, feat: F.tab)),
            Text(b, textAlign: TextAlign.center, style: F.s(11.5, c: p.soft)),
          ],
        ),
      ),
    );
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(n == 0 ? '好' : (pct >= 80 ? '好!' : '加油'), textAlign: TextAlign.center, style: F.s(48, w: FontWeight.w900, family: F.hz, c: p.t(3))),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(L10.text(t.sumT[kind]), textAlign: TextAlign.center, style: F.s(18, w: FontWeight.w800, c: p.fg)),
          ),
          if (n > 0)
            Row(children: [cell('$ok/$n', t.sumRight), const SizedBox(width: 8), cell('$up', t.sumUp), const SizedBox(width: 8), cell('${wrong.length}', t.sumAgain)])
          else
            _Note(t.sumEmpty),
          for (final x in notes) _Note(x),
          for (final x in r.notes) _Note(x, accent: true),
          if (pairs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(t.sumConf, style: F.s(12.5, c: p.soft)),
                for (final (a, b) in pairs)
                  Tile(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    radius: 999,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: app.vocab.idx[a]?.h ?? '', style: F.s(16, w: FontWeight.w900, family: F.hz)),
                          const TextSpan(text: '↔'),
                          TextSpan(text: app.vocab.idx[b]?.h ?? '', style: F.s(16, w: FontWeight.w900, family: F.hz)),
                        ],
                      ),
                      style: F.s(13, c: p.fg),
                    ),
                  ),
              ],
            ),
          ],
          if (wrong.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t.sumWrong, style: F.s(12.5, w: FontWeight.w700, c: p.soft)),
            const SizedBox(height: 6),
            WordChips(wrong.take(12).toList()),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(flex: 2, child: GhostBtn(t.sumHome, wide: true, onTap: () => app.go('home'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: MainBtn(
                  r.quick ? t.quickMore : (r.mode == 'session' ? t.sumSessionMore : t.sumMore),
                  wide: true,
                  radius: 16,
                  onTap: () {
                    if (r.quick) {
                      app.sessionQuick = false;
                    } else if (r.mode == 'session') {
                      app.sessionExtra = true;
                    }
                    R.reset();
                    app.changed();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final bool accent;
  const _Note(this.text, {this.accent = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Rich(text, style: F.s(13, c: accent ? p.fg : p.soft, h: 1.45), align: TextAlign.center),
    );
  }
}

// ---------------------------------------------------------------- rest (调息)
class _BreakView extends StatefulWidget {
  final Run r;
  const _BreakView(this.r);
  @override
  State<_BreakView> createState() => _BreakViewState();
}

class _BreakViewState extends State<_BreakView> with SingleTickerProviderStateMixin {
  late final AnimationController _b = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  Timer? _sec;

  @override
  void initState() {
    super.initState();
    // the countdown redraws only this view, once a second
    _sec = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.r.brk?.end != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _sec?.cancel();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final R = app.runner;
    final b = widget.r.brk!;
    final f = b.f;
    final left = b.end != null ? math.max(0, ((b.end! - nowMs()) / 1000).ceil()) : 300;
    final done = b.end != null && left <= 0;
    if (b.end != null && !done && !MediaQuery.of(context).disableAnimations) {
      if (!_b.isAnimating) _b.repeat();
    } else {
      _b.stop();
    }
    final why = f['k'] == 'acc' ? t.brAcc(f['a'], f['b']) : (f['k'] == 'slow' ? t.brSlow : t.brTime(f['m']));
    final cue = b.t0 != null && ((nowMs() - b.t0!) ~/ 4000).isOdd ? t.brOut : t.brIn;
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('调息', textAlign: TextAlign.center, style: F.s(52, w: FontWeight.w900, family: F.hz, c: p.t(4))),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(b.end != null ? (done ? t.brDone : t.brT2) : t.brT, textAlign: TextAlign.center, style: F.s(18, w: FontWeight.w800, c: p.fg)),
          ),
          if (b.end != null) ...[
            if (!done)
              Center(
                child: AnimatedBuilder(
                  animation: _b,
                  builder: (c, _) {
                    final v = _b.value < .5 ? Curves.easeInOut.transform(_b.value * 2) : Curves.easeInOut.transform(2 - _b.value * 2);
                    return Transform.scale(
                      scale: .62 + .38 * v,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [p.elWater.withValues(alpha: .42), p.elWater.withValues(alpha: .08)], stops: const [0, .72]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Text(_mmss(left), textAlign: TextAlign.center, style: F.s(24, w: FontWeight.w800, c: p.fg, feat: F.tab)),
            if (!done) Text(cue, textAlign: TextAlign.center, style: F.s(13.5, w: FontWeight.w700, c: p.soft)),
            if (!done) _Note(t.brHow),
          ] else ...[
            _Note(why),
            _Note(t.brWhy),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: GhostBtn(t.brStop, wide: true, fontSize: 13, onTap: () => R.breakEnd(true))),
              if (b.end == null) ...[
                const SizedBox(width: 8),
                Expanded(child: GhostBtn(t.brGo, wide: true, fontSize: 13, onTap: R.breakStart)),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: MainBtn(b.end != null ? t.brCont : t.brSkip, wide: true, radius: 16, fontSize: 13, onTap: () => R.breakEnd(false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- HSK simulation
class _MockIntro extends StatelessWidget {
  final Run r;
  const _MockIntro(this.r);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final m = r.mock!.m;
    final prev = app.lm.mocks.where((x) => x[1] == m.L).toList();
    ({int n, int min}) size(bool short) {
      final pp = LM.mockPaper[math.min(m.L, 6)]!;
      var n = 0, sec = 0;
      for (var i = 0; i < 3; i++) {
        var k = pp.n[i], s = pp.min[i] * 60;
        if (k == 0 || (i == 0 && m.skipped)) continue;
        if (short) {
          final j = math.max(3, (k / 3).round());
          s = math.max(180, (s * j / k / 60).round() * 60);
          k = j;
        }
        n += k;
        sec += s;
      }
      return (n: n, min: (sec / 60).round());
    }

    Widget len(bool short) {
      final z = size(short), on = m.short == short;
      return Expanded(
        child: Press(
          onTap: () => app.runner.mockLength(short),
          scale: .96,
          selected: on,
          label: '${short ? t.mkLenShort : t.mkLenFull}, ${t.mkRows(z.n, z.min)}',
          child: Tile(
            radius: 16,
            color: on ? th.acc.withValues(alpha: .14) : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Column(
              children: [
                Text(short ? t.mkLenShort : t.mkLenFull, style: F.s(14, w: FontWeight.w800, c: on ? th.acc : p.fg)),
                Text(t.mkRows(z.n, z.min), textAlign: TextAlign.center, style: F.s(11.5, c: p.soft)),
              ],
            ),
          ),
        ),
      );
    }

    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('模拟考试', textAlign: TextAlign.center, style: F.s(15, w: FontWeight.w900, family: F.hz, c: p.gold, ls: 2)),
          const SizedBox(height: 6),
          Text(t.mkIntroT(m.L), textAlign: TextAlign.center, style: F.s(18, w: FontWeight.w800, c: p.fg)),
          _Note(t.mkIntro),
          const SizedBox(height: 4),
          Row(children: [len(false), const SizedBox(width: 8), len(true)]),
          const SizedBox(height: 6),
          for (final pp in m.parts) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                _Seal(partHz[pp.k]!.$1.substring(0, 1)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${partHz[pp.k]!.$1} ${L10.text(t.partN[pp.k])}', style: F.s(14, w: FontWeight.w700, c: p.fg)),
                      Text(
                        t.mkRows(pp.n, (pp.sec / 60).round()),
                        style: F.s(12.5, c: p.soft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _Rules([
            '${t.mkTime((m.sec / 60).round())} · ${t.mkPass(m.parts.length * 60, m.parts.length * 100)}',
            if (m.L >= 5 && m.parts.any((x) => x.k == 'write')) t.mkWriteNote,
            if (m.skipped) t.mkNoTts,
            if (prev.isNotEmpty) t.mkLast(prev.last[2], prev.last[3], app.dateS(app.tDate(prev.last[0] as num))),
            t.mkNote,
          ]),
          const SizedBox(height: 14),
          MainBtn(t.mkStart, wide: true, radius: 16, onTap: app.runner.mockStart),
        ],
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  final String hz;
  const _Seal(this.hz);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final c = th.acc;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.withValues(alpha: .5), width: 1.5)),
      child: Text(hz, style: F.s(17, w: FontWeight.w900, family: F.hz, c: c)),
    );
  }
}

/// the rules of a test in one quiet box
class _Rules extends StatelessWidget {
  final List<String> lines;
  const _Rules(this.lines);
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Tile(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Text(lines[i], style: F.s(i == 0 ? 13 : 12.5, c: i == 0 ? p.fg : p.soft, h: 1.45)),
            ),
        ],
      ),
    );
  }
}

class _MockPart extends StatelessWidget {
  final Run r;
  final String k;
  const _MockPart(this.r, this.k);
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final m = r.mock!;
    final i = m.m.parts.indexWhere((x) => x.k == k);
    final pp = m.m.parts[i];
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(partHz[k]!.$1, textAlign: TextAlign.center, style: F.s(56, w: FontWeight.w900, family: F.hz, c: p.t(1))),
          Text(partHz[k]!.$2, textAlign: TextAlign.center, style: F.s(14, c: p.soft)),
          const SizedBox(height: 8),
          Text('${t.mkPartT(i + 1, m.m.parts.length)} · ${L10.text(t.partN[k])}', textAlign: TextAlign.center, style: F.s(18, w: FontWeight.w800, c: p.fg)),
          _Note(L10.text(t.mkPartD[k], [pp.n])),
          _Note(t.mkTime((pp.sec / 60).round())),
          const SizedBox(height: 10),
          MainBtn(t.mkPartGo, wide: true, radius: 16, onTap: () => app.runner.mockPart(k)),
        ],
      ),
    );
  }
}

class _MockResult extends StatelessWidget {
  final Run r;
  const _MockResult(this.r);
  @override
  Widget build(BuildContext context) {
    final R = app.runner;
    R.mockFinish();
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final m = r.mock!;
    final res = m.r!;
    final pass = res.pass;
    final vc = pass ? p.good : p.bad;
    var no = 0;
    final hist = app.lm.mocks.where((x) => x[1] == m.m.L).toList();
    final h6 = hist.length > 6 ? hist.sublist(hist.length - 6) : hist;
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('模拟考试 · HSK ${m.m.L}', textAlign: TextAlign.center, style: F.s(14, w: FontWeight.w900, family: F.hz, c: p.gold, ls: 1)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${res.total}', style: F.s(52, w: FontWeight.w800, c: vc, feat: F.tab)),
                TextSpan(text: '/${res.max}', style: F.s(18, c: p.soft)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          Text(pass ? t.mkPassY : t.mkPassN, textAlign: TextAlign.center, style: F.s(16, w: FontWeight.w800, c: vc)),
          _Note('${t.mkNeed(res.need, res.max)} · ${t.mkUsed(_mmss(m.used), _mmss(m.m.sec))}${r.timeUp ? ' · ${t.timeUp}' : ''}'),
          for (final pp in res.parts) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: partHz[pp.k]!.$1, style: F.s(14, w: FontWeight.w900, family: F.hz)),
                        TextSpan(text: ' ${L10.text(t.partN[pp.k])}'),
                      ],
                    ),
                    style: F.s(13, c: p.fg),
                  ),
                ),
                Expanded(child: StackBar([(pp.score / 100, pp.score >= 60 ? p.good : p.bad)], height: 6)),
                SizedBox(width: 44, child: Text('${pp.score}', textAlign: TextAlign.right, style: F.s(14, w: FontWeight.w800, c: p.fg, feat: F.tab))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(t.mkRight(pp.right, pp.n), style: F.s(11.5, c: p.soft)),
            ),
          ],
          if (m.prev != null) _Note(L10.text(t.mkA['cmp'], [res.total - (m.prev![2] as num), app.dateS(app.tDate(m.prev![0] as num))])),
          _H4(t.mkAdvT),
          for (var i = 0; i < m.adv.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: th.acc.withValues(alpha: .15), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: F.s(12, w: FontWeight.w800, c: th.acc)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.adv[i].t, style: F.s(13.5, c: p.fg, h: 1.45)),
                        if (m.adv[i].bk != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GhostBtn(m.adv[i].bl!, fontSize: 13, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () => _act(m.adv[i].bk!)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _H4(t.mkRevT),
          for (final pp in m.m.parts)
            Builder(
              builder: (c) {
                final its = m.m.items.where((it) => it.part == pp.k).toList();
                final bad = its.where((it) => it.ok != true).length;
                return Theme(
                  data: Theme.of(c).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: bad > 0,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: partHz[pp.k]!.$1, style: F.s(15, w: FontWeight.w900, family: F.hz)),
                          TextSpan(text: ' ${L10.text(t.partN[pp.k])} · ${bad > 0 ? t.mkWrongN(bad) : t.mkAllRight}'),
                        ],
                      ),
                      style: F.s(14, w: FontWeight.w700, c: p.fg),
                    ),
                    children: [for (final it in its) _MockRow(it, ++no)],
                  ),
                );
              },
            ),
          if (h6.isNotEmpty) ...[
            _H4(t.mkHistT),
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final x in h6)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: math.max(6, (x[2] as num) / (x[3] as num) * 48).toDouble(),
                              decoration: BoxDecoration(
                                color: (x[2] as num) >= (x[3] as num) * .6 ? p.good : p.bad,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Text('${x[2]}', style: F.s(11, c: p.soft, feat: F.tab)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          _Note(t.mkNote),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(flex: 2, child: GhostBtn(t.sumHome, wide: true, onTap: () => app.go('home'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: MainBtn(
                  t.mkAgain,
                  wide: true,
                  radius: 16,
                  onTap: () {
                    R.reset();
                    app.changed();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _act(String k) {
    final R = app.runner;
    final m = r.mock!;
    final wrong = m.m.items.where((it) => it.ok != true).toList();
    if (k == 'wrong') {
      R.mockPractice(wrong);
    } else if (k.startsWith('part:')) {
      R.mockPractice(wrong.where((it) => it.part == k.substring(5)).toList());
    } else if (k == 'next') {
      app.setLevel(m.m.L + 1);
      app.qType = 'mock';
      app.saveUI();
      R.reset();
      app.changed();
    } else if (k == 'plan') {
      app.go('home');
    }
  }
}

class _H4 extends StatelessWidget {
  final String t;
  const _H4(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Semantics(header: true, child: Text(t, style: F.s(14.5, w: FontWeight.w800, c: Th.pal(context).fg))),
  );
}

class _MockRow extends StatelessWidget {
  final Item it;
  final int no;
  const _MockRow(this.it, this.no);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final d = it.d;
    final q = it.q!;
    final ok = it.ok == true;
    final hz = F.s(15, w: FontWeight.w900, family: F.hz, c: p.fg);
    final shown = q == 'lj' ? (it.words?.first ?? d) : d;
    Widget ask = switch (q) {
      'l' => Row(mainAxisSize: MainAxisSize.min, children: [Spk(d.h, size: 26), Text(t.tListen, style: F.s(12, c: p.soft))]),
      'ls' || 'lt' => Row(mainAxisSize: MainAxisSize.min, children: [Spk(d.z, size: 26), Flexible(child: ExampleText(d, size: 14))]),
      'lj' => Row(mainAxisSize: MainAxisSize.min, children: [Spk(d.z, size: 26), Flexible(child: ExampleText(d, size: 14, fill: shown.h))]),
      'm' => Text(d.h, style: hz),
      'c' => ExampleText(d, size: 14, gap: true),
      'wh' => ExampleText(d, size: 14, fill: '（${d.p}）'),
      't' || 'wo' => ExampleText(d, size: 14),
      _ => Text(app.m1(d), style: F.s(13.5, c: p.fg)),
    };
    final end = RegExp(r'[。！？!?.]+$');
    final right = switch (q) {
      'm' => app.m1(d),
      't' || 'lt' => app.tr(d),
      'p' => d.p,
      'lj' => shown == d ? t.jdSame : '${t.jdDiff} (${d.h} ≠ ${shown.h})',
      'wo' => d.z.trim().replaceAll(end, ''),
      _ => d.h,
    };
    String mine;
    if (q == 'p' || q == 'wo') {
      mine = (it.typedText ?? '').isNotEmpty ? it.typedText! : (it.pick == -3 && it.typedText == '' ? t.mkIdk : t.mkNone);
    } else if (q == 'lj') {
      mine = (it.pick ?? -1) < 0 ? t.mkNone : (it.pick == 0 ? t.jdSame : t.jdDiff);
    } else {
      final o = it.words != null && (it.pick ?? -1) >= 0 ? it.words![it.pick!] : null;
      mine = o == null ? (it.pick == -1 ? t.mkIdk : t.mkNone) : (q == 'm' ? app.m1(o) : (q == 't' || q == 'lt' ? app.tr(o) : o.h));
      if (it.tones != null && (it.pick ?? -1) >= 0) mine = pyOpt(it.tones![it.pick!]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 26, child: Text('$no', style: F.s(12, w: FontWeight.w700, c: ok ? p.good : p.bad))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [Text(tName(q), style: F.s(11.5, c: p.soft)), ask],
                ),
                if (ok)
                  Text('✓ $right', style: F.s(13, w: FontWeight.w700, c: Pal.mix(p.good, .8, p.fg)))
                else ...[
                  Text('${t.mkYour}: $mine', style: F.s(13, c: Pal.mix(p.bad, .8, p.fg))),
                  Text('${t.mkAns}: $right', style: F.s(13, w: FontWeight.w700, c: Pal.mix(p.good, .8, p.fg))),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Hz(d, size: 16, weight: FontWeight.w900, family: F.hz),
                      Py(d, size: 12.5),
                      Text('· ${app.m1(d)}', style: F.s(12.5, c: p.soft)),
                      Spk(d.h, size: 26),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// keyboard: Android's hardware keys 1–4 pick an option (keys.js)
KeyEventResult runKey(KeyEvent e) {
  if (e is! KeyDownEvent) return KeyEventResult.ignored;
  final R = app.runner;
  final it = R.run?.cur;
  if (it == null) return KeyEventResult.ignored;
  final k = e.logicalKey;
  final n = k == LogicalKeyboardKey.digit1
      ? 0
      : k == LogicalKeyboardKey.digit2
      ? 1
      : k == LogicalKeyboardKey.digit3
      ? 2
      : k == LogicalKeyboardKey.digit4
      ? 3
      : -1;
  if (n >= 0 && it.k == 'q' && !it.done && it.q != 'p' && it.q != 'wo' && (it.q != 'lj' || n < 2)) {
    R.qAnswer(it, n);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}
