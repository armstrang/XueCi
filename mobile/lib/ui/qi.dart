/// The living layer (Josh, Nov 2026: "like a cultivation game, many things move"): qi in the air behind every screen
/// (motes of light rising, mist drifting; storm clouds during a tribulation), the aura of the realm orb (it breathes,
/// qi spirals into it), sparks of qi from a right answer and an ink blot from a wrong one, a wash of ink when the
/// screen changes, a light that crosses the main button, smoke from the incense.
///
/// One clock ([qiT]) drives all of it: a single ticker in [QiField], 30 frames a second (every frame while a burst
/// plays), asleep 90 s after the last touch. Everything is drawn on canvases in their own repaint boundaries;
/// nothing is laid out again. With light effects, "remove animations" or [qiOn] false the clock stands still: the
/// air and the aura are then a still picture and the bursts are left out.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'fx.dart';
import 'glass.dart';
import 'theme.dart';

/// the clock, in seconds
final qiT = ValueNotifier<double>(0);

/// false in the tests that measure pictures (contrast, secrets, speed)
bool qiOn = true;
bool _running = false;

class _Burst {
  final int kind; // 0 qi (right), 1 ink (wrong), 2 the wash of ink across the screen
  final Offset at;
  final double t0;
  final Color c;
  final int seed;
  _Burst(this.kind, this.at, this.t0, this.c, this.seed);
  double get life => kind == 0 ? .95 : (kind == 1 ? .6 : .42);
}

final _bursts = <_Burst>[];
int _seed = 0;

/// a right answer gives off qi, a wrong one leaves a blot of ink, at the middle of [context]'s widget
void qiBurst(BuildContext context, {required bool ok}) {
  if (!_running) return;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return;
  final p = Th.pal(context);
  final at = box.localToGlobal(box.size.center(Offset.zero));
  _bursts.add(_Burst(ok ? 0 : 1, at, qiT.value, ok ? (p.dark ? p.gold : const Color(0xffc8922a)) : (p.dark ? const Color(0xff000000) : const Color(0xff1b1d27)), _seed++));
}

/// ink washes across as a new screen comes in
void qiSweep(Color c) {
  if (!_running) return;
  _bursts.removeWhere((b) => b.kind == 2);
  _bursts.add(_Burst(2, Offset.zero, qiT.value, c, _seed++));
}

double _h(int i, int k) {
  final x = math.sin(i * 127.1 + k * 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

double _eo(double x) => 1 - math.pow(1 - x, 3).toDouble();

/// The air behind a screen, and the one ticker. [storm]: a tribulation is on.
class QiField extends StatefulWidget {
  final bool storm;
  const QiField({super.key, this.storm = false});
  @override
  State<QiField> createState() => _QiFieldState();
}

class _QiFieldState extends State<QiField> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  double _base = qiT.value, _last = -1, _awake = 0;
  Duration _from = Duration.zero;

  @override
  void initState() {
    super.initState();
    fxWake.addListener(_wake);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wake();
  }

  bool get _may => qiOn && mounted && !Th.of(context).low && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _wake() {
    if (!_may) {
      if (_ticker.isActive) _ticker.stop();
      _running = false;
      _bursts.clear();
      return;
    }
    _awake = qiT.value + 90;
    if (!_ticker.isActive) {
      _base = qiT.value;
      _from = Duration.zero;
      _last = -1;
      _ticker.start();
      _running = true;
    }
  }

  void _tick(Duration d) {
    if (_from == Duration.zero) _from = d;
    final now = _base + (d - _from).inMicroseconds / 1e6;
    if (_bursts.isNotEmpty) {
      _bursts.removeWhere((b) => now - b.t0 > b.life);
      qiT.value = now;
      _last = now;
    } else if (now - _last >= 1 / 30) {
      qiT.value = now;
      _last = now;
    }
    if (now > _awake && _bursts.isEmpty) {
      _ticker.stop();
      _running = false;
    }
  }

  @override
  void dispose() {
    fxWake.removeListener(_wake);
    _ticker.dispose();
    _running = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _AirPainter(th.p, th.rc, widget.storm, th.low), size: Size.infinite),
      ),
    );
  }
}

class _AirPainter extends CustomPainter {
  final Pal p;
  final Color rc;
  final bool storm, low;
  _AirPainter(this.p, this.rc, this.storm, this.low) : super(repaint: qiT);

  @override
  void paint(Canvas c, Size s) {
    if (low || !qiOn) return;
    final t = qiT.value;
    final w = s.width, h = s.height;
    // mist: wide, flat veils that drift sideways
    final mistC = storm
        ? (p.dark ? const Color(0xff000000) : const Color(0xff39415a))
        : (p.dark ? Colors.white : Color.lerp(rc, Colors.white, .55)!);
    final mistA = storm ? (p.dark ? .5 : .2) : (p.dark ? .045 : .30);
    final n = storm ? 6 : 4;
    for (var i = 0; i < n; i++) {
      final sp = (storm ? .020 : .008) * (.6 + _h(i, 1)) * (i.isEven ? 1 : -1);
      var x = (_h(i, 2) + t * sp) % 1.6;
      if (x < 0) x += 1.6;
      final ctr = Offset((x - .3) * w, storm ? h * (.02 + .16 * _h(i, 3)) : h * (.12 + .8 * _h(i, 3)));
      final rad = w * (.55 + .35 * _h(i, 4));
      c.save();
      c.translate(ctr.dx, ctr.dy);
      c.scale(1, storm ? .42 : .26);
      c.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, rad, [
            mistC.withValues(alpha: mistA),
            mistC.withValues(alpha: mistA * .5),
            mistC.withValues(alpha: 0),
          ], const [0, .5, 1]),
      );
      c.restore();
    }
    if (storm) {
      // sheet lightning far inside the clouds, now and then
      final k = (t * .23) % 1;
      if (k < .035 || (k > .07 && k < .09)) {
        final cx = w * _h((t * .23).floor(), 9);
        c.drawCircle(
          Offset(cx, h * .08),
          w * .7,
          Paint()
            ..blendMode = p.dark ? BlendMode.plus : BlendMode.srcOver
            ..shader = ui.Gradient.radial(Offset(cx, h * .08), w * .7, [
              const Color(0xffcfe0ff).withValues(alpha: p.dark ? .16 : .35),
              const Color(0x00cfe0ff),
            ]),
        );
      }
    }
    // motes of qi: they rise (in a storm they are driven slantwise), sway and glimmer
    final gold = p.dark ? p.gold : const Color(0xffb07a1e);
    final own = p.dark ? Color.lerp(rc, Colors.white, .35)! : Color.lerp(rc, Colors.black, .12)!;
    final spark = storm ? (p.dark ? const Color(0xffbcd4ff) : const Color(0xff4a63a8)) : gold;
    final count = storm ? 34 : 30;
    final core = Paint()..blendMode = p.dark ? BlendMode.plus : BlendMode.srcOver;
    final halo = Paint()..blendMode = p.dark ? BlendMode.plus : BlendMode.srcOver;
    for (var i = 0; i < count; i++) {
      final sp = (storm ? .11 : .022) * (.5 + _h(i, 5));
      final u = (_h(i, 6) + t * sp) % 1; // 0 at the bottom, 1 at the top
      final sway = math.sin(t * (.25 + .3 * _h(i, 7)) + i) * .025;
      final x = ((_h(i, 8) + sway + (storm ? u * .35 : 0)) % 1) * w;
      final y = (1.04 - 1.08 * u) * h;
      final tw = .55 + .45 * math.sin(t * (1.1 + 1.4 * _h(i, 10)) + i * 2.3);
      final edge = math.min(1.0, math.min(u, 1 - u) * 8);
      final a = (p.dark ? .75 : .5) * tw * edge * (i % 3 == 0 ? 1 : .6);
      final r = (1.0 + 1.5 * _h(i, 11)) * (i % 7 == 0 ? 1.5 : 1);
      final col = i % 4 == 1 ? own : spark;
      halo.color = col.withValues(alpha: a * .16);
      c.drawCircle(Offset(x, y), r * 3.6, halo);
      core.color = col.withValues(alpha: a);
      if (storm) {
        c.drawLine(Offset(x, y), Offset(x - 5, y + 9), core..strokeWidth = r * .8..strokeCap = StrokeCap.round);
      } else {
        c.drawCircle(Offset(x, y), r, core);
      }
    }
  }

  @override
  bool shouldRepaint(_AirPainter o) => o.p != p || o.rc != rc || o.storm != storm || o.low != low;
}

/// On top of everything: the bursts.
class QiOver extends StatelessWidget {
  const QiOver({super.key});
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _OverPainter(), size: Size.infinite)));
}

class _OverPainter extends CustomPainter {
  _OverPainter() : super(repaint: qiT);
  @override
  void paint(Canvas c, Size s) {
    if (_bursts.isEmpty) return;
    final t = qiT.value;
    for (final b in _bursts) {
      final u = ((t - b.t0) / b.life).clamp(0.0, 1.0);
      switch (b.kind) {
        case 0:
          // qi: a ring opens, sparks fly out, then drift up and fade as if drawn in
          final e = _eo(u);
          c.drawCircle(
            b.at,
            10 + 54 * e,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2 * (1 - u)
              ..color = b.c.withValues(alpha: .7 * (1 - u)),
          );
          c.drawCircle(b.at, 34 * e, Paint()..blendMode = BlendMode.plus..color = b.c.withValues(alpha: .22 * (1 - u)));
          for (var i = 0; i < 16; i++) {
            final ang = i / 16 * math.pi * 2 + _h(b.seed + i, 1) * .6;
            final far = (34 + 62 * _h(b.seed + i, 2)) * e;
            final rise = 90 * u * u * (.5 + _h(b.seed + i, 3));
            final at = b.at + Offset(math.cos(ang) * far, math.sin(ang) * far * .8 - rise);
            final a = (1 - u) * (1 - u);
            final r = 1.4 + 1.8 * _h(b.seed + i, 4);
            c.drawCircle(at, r * 3.4, Paint()..blendMode = BlendMode.plus..color = b.c.withValues(alpha: .30 * a));
            c.drawCircle(at, r * 1.25, Paint()..color = Color.lerp(b.c, Colors.white, .55)!.withValues(alpha: a));
          }
        case 1:
          // ink: a blot spreads and soaks away
          final e = _eo(u);
          for (var i = 0; i < 3; i++) {
            c.drawCircle(
              b.at + Offset((_h(b.seed, i) - .5) * 16, (_h(b.seed, i + 5) - .5) * 10),
              (16 + 30 * _h(b.seed, i + 9)) * (.35 + .65 * e),
              Paint()..color = b.c.withValues(alpha: .34 * (1 - u)),
            );
          }
          for (var i = 0; i < 7; i++) {
            final ang = _h(b.seed + i, 12) * math.pi * 2;
            final far = (30 + 34 * _h(b.seed + i, 13)) * e;
            c.drawCircle(
              b.at + Offset(math.cos(ang) * far, math.sin(ang) * far * .7 + 14 * u * u),
              1.5 + 2.2 * _h(b.seed + i, 14),
              Paint()..color = b.c.withValues(alpha: .7 * (1 - u)),
            );
          }
        default:
          // a wash of ink: a soft slanted band crosses the screen once
          final x = (-.5 + 2.0 * _eo(u)) * s.width;
          final a = math.sin(u * math.pi) * .16;
          c.save();
          c.translate(x, 0);
          c.transform(Matrix4.skewX(-.32).storage);
          c.drawRect(
            Rect.fromLTWH(-s.width * .45, -20, s.width * .9, s.height + 40),
            Paint()
              ..shader = ui.Gradient.linear(Offset(-s.width * .45, 0), Offset(s.width * .45, 0), [
                b.c.withValues(alpha: 0),
                b.c.withValues(alpha: a),
                b.c.withValues(alpha: a * .5),
                b.c.withValues(alpha: 0),
              ], const [0, .55, .8, 1]),
          );
          c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_OverPainter o) => false;
}

/// The aura of the realm orb: a halo that breathes like a cultivator at rest, qi spiralling into the orb along
/// three arms, two thin arcs turning against each other. Painted around its child, beyond its box.
class QiAura extends StatelessWidget {
  final Color color;
  final bool strong; // a breakthrough is open: brighter, faster
  final bool dim; // not tested yet: only a faint breath
  final Widget child;
  const QiAura({super.key, required this.color, required this.child, this.strong = false, this.dim = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return CustomPaint(painter: th.low || !qiOn ? null : _AuraPainter(th.p, color, strong, dim), child: child);
  }
}

class _AuraPainter extends CustomPainter {
  final Pal p;
  final Color lc;
  final bool strong, dim;
  _AuraPainter(this.p, this.lc, this.strong, this.dim) : super(repaint: qiT);
  @override
  void paint(Canvas c, Size s) {
    final t = qiT.value;
    final o = s.center(Offset.zero);
    final R = s.width / 2;
    final breath = .5 + .5 * math.sin(t * math.pi * 2 / (strong ? 3.0 : 4.6));
    final gold = p.dark ? p.gold : const Color(0xffb07a1e);
    final col = strong ? gold : lc;
    final k = dim ? .45 : 1.0;
    final plus = p.dark ? BlendMode.plus : BlendMode.srcOver;
    // the halo
    final hr = R * (1.28 + .12 * breath);
    c.drawCircle(
      o,
      hr,
      Paint()
        ..blendMode = plus
        ..shader = ui.Gradient.radial(o, hr, [
          col.withValues(alpha: 0),
          col.withValues(alpha: (p.dark ? .30 : .22) * k * (.55 + .45 * breath)),
          col.withValues(alpha: 0),
        ], const [.62, .8, 1]),
    );
    if (dim) return;
    // two arcs turning against each other
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3;
    for (var i = 0; i < 2; i++) {
      final rr = R * (1.13 + .11 * i);
      final a0 = t * (i == 0 ? .35 : -.24) + i * 1.3;
      arc.color = (i == 0 ? gold : col).withValues(alpha: (p.dark ? .55 : .5) * (.6 + .4 * breath));
      for (var j = 0; j < 3; j++) {
        c.drawArc(Rect.fromCircle(center: o, radius: rr), a0 + j * math.pi * 2 / 3, .5 - .12 * i, false, arc);
      }
    }
    // qi drawn in along three spiral arms
    final dot = Paint()..blendMode = plus;
    final sp = strong ? .26 : .17;
    for (var arm = 0; arm < 3; arm++) {
      for (var j = 0; j < 6; j++) {
        final u = (t * sp + j / 6 + arm * .11) % 1;
        final rad = R * (1.46 - .50 * u);
        final ang = arm * math.pi * 2 / 3 + u * 2.6 + t * .12;
        final a = math.sin(u * math.pi) * (p.dark ? .9 : .7);
        final r = 1.1 + 1.5 * (1 - u);
        for (var tail = 0; tail < 3; tail++) {
          final at = o + Offset(math.cos(ang - tail * .07), math.sin(ang - tail * .07)) * (rad + tail * 1.6);
          dot.color = (j.isEven ? gold : col).withValues(alpha: a * (1 - tail * .34));
          c.drawCircle(at, r * (1 - tail * .22), dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AuraPainter o) => o.p != p || o.lc != lc || o.strong != strong || o.dim != dim;
}

/// a light crosses the child (the main button) every few seconds
class QiShimmer extends StatelessWidget {
  final double radius;
  final Widget child;
  const QiShimmer({super.key, required this.child, this.radius = 999});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(foregroundPainter: Th.of(context).low ? null : _ShimmerPainter(radius), child: child),
  );
}

class _ShimmerPainter extends CustomPainter {
  final double radius;
  _ShimmerPainter(this.radius) : super(repaint: qiT);
  @override
  void paint(Canvas c, Size s) {
    final u = (qiT.value / 4.8) % 1;
    if (u > .2 || qiT.value == 0) return;
    final k = u / .2;
    final x = (-.35 + 1.7 * k) * s.width;
    final bw = math.max(46.0, s.width * .22);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(math.min(radius, s.height / 2))));
    c.transform(Matrix4.skewX(-.4).storage);
    c.drawRect(
      Rect.fromLTWH(x, 0, bw, s.height),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x + bw, 0), [
          const Color(0x00ffffff),
          Colors.white.withValues(alpha: .28 * math.sin(k * math.pi)),
          const Color(0x00ffffff),
        ], const [0, .5, 1]),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) => false;
}

/// smoke curling up from the lit incense (drawn above its box)
class QiSmoke extends StatelessWidget {
  final double size;
  const QiSmoke({super.key, required this.size});
  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(size: Size.square(size), painter: _SmokePainter(Th.pal(context).dark)));
}

class _SmokePainter extends CustomPainter {
  final bool dark;
  _SmokePainter(this.dark) : super(repaint: qiT);
  @override
  void paint(Canvas c, Size s) {
    final t = qiT.value;
    if (t == 0) return;
    final col = dark ? Colors.white : const Color(0xff6b5a4e);
    for (var i = 0; i < 5; i++) {
      final u = (t * .28 + i / 5) % 1;
      final x = s.width * .5 + math.sin(u * 5 + i + t * .6) * s.width * .16 * u;
      final y = s.height * .12 - u * s.height * .62;
      c.drawCircle(Offset(x, y), 1.2 + 2.6 * u, Paint()..color = col.withValues(alpha: .34 * math.sin(u * math.pi) * (1 - u * .4)));
    }
  }

  @override
  bool shouldRepaint(_SmokePainter o) => o.dark != dark;
}

/// turns its child slowly (the 太极 of the cultivation days, once lit)
class QiSpin extends StatelessWidget {
  final bool on;
  final double secs;
  final Widget child;
  const QiSpin({super.key, required this.child, this.on = true, this.secs = 14});
  @override
  Widget build(BuildContext context) => !on
      ? child
      : RepaintBoundary(
          child: AnimatedBuilder(
            animation: qiT,
            child: child,
            builder: (c, child) => Transform.rotate(angle: qiT.value * math.pi * 2 / secs, child: child),
          ),
        );
}
