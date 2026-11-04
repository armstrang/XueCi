/// The opening (Josh, Nov 2026: no app icon, the icon may change): on the app's background a drop of gold ink opens,
/// XueCi comes in letter by letter over a gold line and MANDARIN, 天外有天 shows small in the bottom-right corner,
/// then the wordmark moves into Home's corner and Home rises in, piece by piece (about 1.7 s in all).
/// Only on a cold start that opens on Home; a tap jumps to the end; with "remove animations" it is a short fade.
/// Transform and opacity only, every piece 180–320 ms.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme.dart';

/// false in tests and when a start opens on another screen
bool splashOn = true;

/// the splash clock in seconds; [splashDone] once it is over (Home then draws as always)
final splashT = ValueNotifier<double>(splashDone);
const splashDone = 99.0;
const _end = 1.76;

/// Home's wordmark and its MANDARIN line: where the splash's lockup lands
final markKey = GlobalKey(debugLabel: 'mark');
final markSubKey = GlobalKey(debugLabel: 'markSub');

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
double _eo(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _eio(double x) => x < .5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;
double _sp(double x) => 1 - math.exp(-7 * x) * math.cos(6 * x); // a soft spring, a small overshoot

/// a piece of Home that rises in after the splash (index = its place in the order, 40 ms apart)
class Rise extends StatelessWidget {
  final int i;
  final Widget child;
  const Rise(this.i, {super.key, required this.child});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: splashT,
    child: child,
    builder: (c, t, child) {
      if (t >= _end) return child!;
      final a = 1.34 + i * .04;
      final o = _eo(_seg(t, a, a + .22));
      if (o <= 0) return Opacity(opacity: 0, child: child);
      return Opacity(
        opacity: o,
        child: Transform.translate(offset: Offset(0, (1 - _sp(_seg(t, a, a + .30))) * 16), child: child),
      );
    },
  );
}

/// Home's wordmark: hidden while the splash's lockup is on its way, there the moment it lands
class MarkSlot extends StatelessWidget {
  final Widget child;
  const MarkSlot({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: splashT,
    child: child,
    builder: (c, t, child) => t >= _end ? child! : Opacity(opacity: _seg(t, 1.50, 1.58), child: child),
  );
}

class Splash extends StatefulWidget {
  final VoidCallback onDone;
  const Splash({super.key, required this.onDone});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1760));
  final _word = GlobalKey(), _sub = GlobalKey();
  // the flight, measured once just before it starts: offset and scale of the word and of MANDARIN
  (Offset, double)? _fw, _fs;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _a.addListener(_tick);
    _a.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_a.isAnimating || _a.value > 0) return;
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      // no movement: the lockup stands, then everything fades over to Home
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) _a.animateTo(1, duration: const Duration(milliseconds: 200));
      });
    } else {
      _a.forward();
    }
  }

  void _tick() {
    final t = _reduce ? splashDone : _a.value * _end;
    if (!_reduce && t >= 1.18 && _fw == null) _measure();
    splashT.value = t >= _end ? splashDone : t;
  }

  (Offset, double)? _flight(GlobalKey from, GlobalKey to) {
    final a = from.currentContext?.findRenderObject() as RenderBox?;
    final b = to.currentContext?.findRenderObject() as RenderBox?;
    if (a == null || b == null || !a.hasSize || !b.hasSize || !b.attached) return null;
    final pa = a.localToGlobal(Offset.zero), pb = b.localToGlobal(Offset.zero);
    return (pb - pa, b.size.height / a.size.height);
  }

  void _measure() {
    _fw = _flight(_word, markKey) ?? (Offset.zero, 1);
    _fs = _flight(_sub, markSubKey);
  }

  bool _done = false;
  void _finish() {
    if (_done) return;
    _done = true;
    splashT.value = splashDone;
    widget.onDone();
  }

  /// a tap: straight to the flight
  void _skip() {
    if (_reduce || _done) return;
    final at = 1.18 / _end;
    if (_a.value < at) _a.forward(from: at);
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
    final gold = p.dark ? p.gold : const Color(0xffa07026);
    final w = Text.rich(
      key: _word,
      TextSpan(children: [const TextSpan(text: 'Xue'), TextSpan(text: 'Ci', style: TextStyle(color: th.acc))]),
      textScaler: TextScaler.noScaling,
      style: F.s(64, w: FontWeight.w800, c: p.fg, ls: -2.62, h: 1),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _a,
        builder: (c, _) {
          final t = _a.value * _end;
          if (_reduce) {
            // the lockup and the background, then one fade
            final o = 1 - _a.value;
            return Opacity(
              opacity: o,
              child: ColoredBox(color: p.bg, child: Center(child: _lockup(context, w, gold, 1, 1, 1, null))),
            );
          }
          final r = _eo(_seg(t, .05, .55));
          final fly = _eio(_seg(t, 1.22, 1.54));
          final hand = _seg(t, 1.50, 1.58);
          final fade = 1 - _seg(t, 1.16, 1.34);
          return Stack(
            children: [
              // the system splash's plain background, then the app's aurora behind it shows
              Positioned.fill(child: IgnorePointer(child: Opacity(opacity: 1 - _eo(_seg(t, .10, .70)), child: ColoredBox(color: p.bg)))),
              // the drop of ink: a soft glow and a thin ring that opens
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _seg(t, .05, .25) * (1 - _seg(t, .55, 1.05)),
                        child: Transform.scale(
                          scale: .4 + .6 * r,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [gold.withValues(alpha: p.dark ? .30 : .22), gold.withValues(alpha: 0)], stops: const [0, .65]),
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: t < .05 ? 0 : .8 * (1 - r),
                        child: Transform.scale(
                          scale: .08 + .92 * r,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withValues(alpha: .7), width: 1.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: 1 - hand,
                child: Center(child: _lockup(context, w, gold, t, fly, fade, _fw)),
              ),
              // the easter egg
              Positioned(
                right: 24,
                bottom: MediaQuery.paddingOf(context).bottom + 30,
                child: Opacity(
                  opacity: .55 * _eo(_seg(t, .62, .92)) * fade,
                  child: Text(
                    '天外有天',
                    textScaler: TextScaler.noScaling,
                    locale: const Locale('zh', 'CN'),
                    style: F.s(15, family: F.hz, c: gold, ls: 4, h: 1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// XueCi over the gold line and MANDARIN; [t] the clock (1 = all in), [fly] 0…1 on the way to Home's corner
  Widget _lockup(BuildContext context, Widget w, Color gold, double t, double fly, double fade, (Offset, double)? fw) {
    final p = Th.pal(context);
    final sq = _eo(_seg(t, .52, .80));
    Widget move(Widget child, (Offset, double)? f) {
      if (f == null || fly == 0) return child;
      return Transform(
        transform: Matrix4.identity()
          ..translateByDouble(f.$1.dx * fly, f.$1.dy * fly, 0, 1)
          ..scaleByDouble(1 + (f.$2 - 1) * fly, 1 + (f.$2 - 1) * fly, 1, 1),
        child: child,
      );
    }

    // the letters one by one: 260 ms each, 45 ms apart (the word is cut in its two colours for that)
    final letters = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Builder(
            builder: (c) {
              final q = t >= 1 ? 1.0 : _eo(_seg(t, .18 + i * .045, .44 + i * .045));
              return Opacity(
                opacity: q,
                child: Transform.translate(
                  offset: Offset(0, (1 - q) * 12),
                  child: Text(
                    'XueCi'[i],
                    textScaler: TextScaler.noScaling,
                    style: F.s(64, w: FontWeight.w800, c: i > 2 ? Th.of(c).acc : p.fg, ls: -2.62, h: 1),
                  ),
                ),
              );
            },
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // the word comes in letter by letter, then stands as one piece (the same text as Home's, for the handover)
        move(
          t >= .72
              ? w
              : Stack(children: [Opacity(opacity: 0, child: w), Positioned.fill(child: OverflowBox(maxWidth: double.infinity, child: letters))]),
          fw,
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: fade,
          child: Transform.scale(
            scaleX: t >= 1 ? 1 : _eo(_seg(t, .42, .72)),
            child: Container(
              width: 170,
              height: 1.5,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [gold.withValues(alpha: 0), gold, gold.withValues(alpha: 0)])),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: t >= 1 ? 1 : (_fs == null ? sq * (1 - fly) : sq),
          // the letter spacing trails after the last letter: the padding keeps the word itself centred
          child: Padding(
            padding: const EdgeInsets.only(left: 4.7),
            child: move(
              Text('MANDARIN', key: _sub, textScaler: TextScaler.noScaling, style: F.s(13, w: FontWeight.w800, c: p.soft, ls: 4.71, h: 1)),
              _fs,
            ),
          ),
        ),
      ],
    );
  }
}

/// a number on Home that counts up as Home rises in after the splash (once, on a cold start); otherwise it stands
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double) text;
  final TextStyle style;
  const CountUp(this.value, {super.key, required this.text, required this.style});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: splashT,
    builder: (c, t, _) {
      final k = t >= _end ? 1.0 : _eo(_seg(t, 1.42, 1.74));
      return Text(text(value * k), style: style);
    },
  );
}
