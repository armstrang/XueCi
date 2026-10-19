/// Visual effects (glass.js): the drifting light behind everything in "full" effects, and the frame watcher that
/// steps "automatic" down to light effects once when screen changes keep running slowly on this phone.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app.dart';
import 'glass.dart';

/// a touch anywhere wakes the light for 10 s (Shell's Listener bumps it)
final fxWake = ValueNotifier<int>(0);

/// Three soft lights (the level colour, the realm gold, a warm one) drifting slowly, ≤30 fps, still 10 s after the
/// last touch, asleep on the test and session screens. Reduced motion: one still frame.
class DriftGlow extends StatefulWidget {
  const DriftGlow({super.key});
  @override
  State<DriftGlow> createState() => _DriftGlowState();
}

class _DriftGlowState extends State<DriftGlow> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final t = ValueNotifier<double>(0);
  double get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds / 1000;
  double _last = -1, _awake = 0;

  @override
  void initState() {
    super.initState();
    fxWake.addListener(_wake);
    WidgetsBinding.instance.addPostFrameCallback((_) => _wake());
  }

  void _wake() {
    if (!mounted || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
    _awake = _now + 10000.0;
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    final now = _now;
    if (now - _last >= 33) {
      _last = now;
      t.value = now / 1000;
    }
    if (now > _awake) _ticker.stop();
  }

  @override
  void dispose() {
    fxWake.removeListener(_wake);
    _ticker.dispose();
    t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final k = p.black ? .32 : (p.dark ? .42 : .7);
    final c3 = p.dark ? p.l(5) : const Color(0xFFFFB07A);
    return IgnorePointer(
      child: RepaintBoundary(child: CustomPaint(painter: _GlowPainter(t, th.acc, p.gold, c3, k), size: Size.infinite)),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final ValueNotifier<double> t;
  final Color c1, c2, c3;
  final double k;
  _GlowPainter(this.t, this.c1, this.c2, this.c3, this.k) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size s) {
    final tt = t.value, a = s.width / s.height, h = s.height;
    // the shader's coordinates: x 0…aspect, y 0…1 from the bottom; a light's strength exp(−d²/σ)
    void blob(double x, double y, double sigma, Color c, double w) {
      final ctr = Offset(x / a * s.width, (1 - y) * h);
      final r = math.sqrt(sigma * 4.6) * h;
      final al = (w * k).clamp(0.0, 1.0);
      canvas.drawCircle(
        ctr,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(ctr, r, [
            for (final f in const [0.0, .25, .5, .75, 1.0]) c.withValues(alpha: al * math.exp(-4.6 * f * f)),
          ], const [0, .25, .5, .75, 1]),
      );
    }

    blob(a * (.18 + .10 * math.sin(tt * .07)), .86 + .06 * math.cos(tt * .09), .16, c1, .62);
    blob(a * (.92 + .06 * math.cos(tt * .05 + 1)), .42 + .12 * math.sin(tt * .06 + 2), .12, c2, .42);
    blob(a * (.30 + .16 * math.sin(tt * .045 + 4)), .10 + .08 * math.cos(tt * .08 + 1), .14, c3, .40);
  }

  @override
  bool shouldRepaint(_GlowPainter o) => o.c1 != c1 || o.c2 != c2 || o.c3 != c3 || o.k != k;
}

// ---------------------------------------------------------------- the frame watcher
final _fw = (spans: <double>[], n: <int>[0], done: <bool>[false]);

/// called on every screen change: watches the frames of the next 320 ms
void watchFrames() {
  if (_fw.done[0] || app.fxPref != 'auto' || app.fx == 'low' || app.fxDown) return;
  final start = DateTime.now();
  late final TimingsCallback cb;
  cb = (List<FrameTiming> ts) {
    for (final f in ts) {
      _fw.spans.add(f.totalSpan.inMicroseconds / 1000);
    }
    if (DateTime.now().difference(start).inMilliseconds < 320) return;
    SchedulerBinding.instance.removeTimingsCallback(cb);
    if (++_fw.n[0] >= 4 && _fw.spans.length >= 30) {
      final s = [..._fw.spans]..sort();
      if (s[s.length >> 1] > 30) {
        _fw.done[0] = true;
        app.fxDown = true;
        app.store.set('xc_fxd', 1);
        app.changed();
        app.toast(app.t.fxDown);
      } else if (_fw.n[0] >= 12) {
        _fw.done[0] = true; // it ran well: stop watching for this session
      }
    }
  };
  SchedulerBinding.instance.addTimingsCallback(cb);
}
