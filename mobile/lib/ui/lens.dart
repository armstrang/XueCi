/// A row of choices with a glass lens under the chosen one (the HSK pickers and the tab bar, glass.js makeLens):
/// the lens slides with a little stretch when the choice changes, and can be dragged along the row; letting go
/// over another choice picks it.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';
import 'theme.dart';

class LensRow extends StatefulWidget {
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget Function(BuildContext c, int i, bool on) item;

  /// the width of each item for a chosen index (default: all equal)
  final List<double> Function(double total, int sel)? widths;
  final Widget Function(BuildContext c, int sel, bool drag) lens;
  final double height;
  final EdgeInsets padding;
  const LensRow({
    super.key,
    required this.count,
    required this.selected,
    required this.onSelect,
    required this.item,
    required this.lens,
    this.widths,
    this.height = 56,
    this.padding = const EdgeInsets.all(4),
  });

  @override
  State<LensRow> createState() => _LensRowState();
}

class _LensRowState extends State<LensRow> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  int _from = 0, _to = 0;
  double? _dragL; // the lens's left edge while dragged
  double _dragStart = 0, _x0 = 0;
  bool _moved = false;
  double _fromLeft = 0; // where the lens started this move (after a drag: where it was let go)
  bool _fromDrag = false;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.selected;
    _a.value = 1;
  }

  @override
  void didUpdateWidget(LensRow o) {
    super.didUpdateWidget(o);
    if (widget.selected != _to) {
      _from = _to;
      _to = widget.selected;
      if (MediaQuery.of(context).disableAnimations) {
        _a.value = 1;
      } else {
        _a.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  List<double> _w(double total, int sel) =>
      widget.widths?.call(total, sel) ?? List.filled(widget.count, total / widget.count);

  (double, double) _rect(List<double> w, int i) {
    var l = 0.0;
    for (var k = 0; k < i; k++) {
      l += w[k];
    }
    return (l, w[i]);
  }

  int _nearest(List<double> w, double center) {
    var best = 0;
    var bd = double.infinity, x = 0.0;
    for (var k = 0; k < w.length; k++) {
      final m = x + w[k] / 2;
      if ((m - center).abs() < bd) {
        bd = (m - center).abs();
        best = k;
      }
      x += w[k];
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (c, bc) {
        final total = bc.maxWidth - widget.padding.horizontal;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (d) {
            final w = _w(total, _to);
            _dragStart = _rect(w, _to).$1;
            _x0 = d.localPosition.dx;
            _moved = false;
          },
          onHorizontalDragUpdate: (d) {
            final dx = d.localPosition.dx - _x0;
            if (!_moved && dx.abs() < 7) return;
            _moved = true;
            final w = _w(total, _to);
            final lw = w[_to];
            setState(() => _dragL = (_dragStart + dx).clamp(0, total - lw));
          },
          onHorizontalDragEnd: (_) => _end(total),
          onHorizontalDragCancel: () => _end(total),
          child: AnimatedBuilder(
            animation: _a,
            builder: (c, _) {
              final t = _a.value;
              final e = const Cubic(.3, 1.2, .5, 1).transform(t);
              final wFrom = _w(total, _from), wTo = _w(total, _to);
              final w = [for (var k = 0; k < widget.count; k++) ui.lerpDouble(wFrom[k], wTo[k], Curves.easeOutCubic.transform(t))!];
              final rTo = _rect(wTo, _to);
              final rFrom = _fromDrag ? (_fromLeft, wFrom[_from]) : _rect(wFrom, _from);
              double left, width;
              if (_dragL != null) {
                left = _dragL!;
                width = wTo[_to];
              } else {
                left = ui.lerpDouble(rFrom.$1, rTo.$1, e)!;
                width = ui.lerpDouble(rFrom.$2, rTo.$2, e)!;
              }
              // the stretch of a moving drop: wider and flatter half-way
              final bump = _dragL != null ? 1.0 : math.sin(math.pi * (t / .9).clamp(0, 1)) * (_from == _to ? 0 : 1);
              final sx = _dragL != null ? 1.1 : 1 + .18 * bump, sy = _dragL != null ? 1.16 : 1 - .1 * bump;
              return SizedBox(
                height: widget.height,
                child: Padding(
                  padding: widget.padding,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: left,
                        width: width,
                        top: 0,
                        bottom: 0,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(sx, sy, 1),
                          child: widget.lens(c, _to, _dragL != null),
                        ),
                      ),
                      Row(
                        children: [
                          for (var k = 0; k < widget.count; k++)
                            SizedBox(
                              width: w[k],
                              height: double.infinity,
                              child: widget.item(c, k, k == _to),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _end(double total) {
    if (_dragL == null) return;
    final w = _w(total, _to);
    final c = _dragL! + w[_to] / 2;
    final best = _nearest(w, c);
    _fromLeft = _dragL!;
    _fromDrag = true;
    setState(() => _dragL = null);
    if (best != _to) {
      HapticFeedback.selectionClick();
      widget.onSelect(best);
    } else {
      _from = _to;
      _a.forward(from: 0);
    }
    Future.delayed(const Duration(milliseconds: 400), () => _fromDrag = false);
  }
}

/// the HSK lens (v1.16): clear glass with a breath of the level's colour, the realm's qi glowing inside, a rim
/// through the five elements and a thin gold line on top
class HskLens extends StatelessWidget {
  final Color lc;
  final double radius;
  const HskLens({super.key, required this.lc, this.radius = 20});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return CustomPaint(painter: _HskLensPainter(th.p, lc, th.rc, radius, th.low));
  }
}

class _HskLensPainter extends CustomPainter {
  final Pal p;
  final Color lc, rc;
  final double radius;
  final bool low;
  _HskLensPainter(this.p, this.lc, this.rc, this.radius, this.low);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    final dark = p.dark;
    if (!low) {
      // 0 10px 24px -12px lc 85%, 0 0 22px -6px rc 60%
      c.drawRRect(
        rr.shift(const Offset(0, 8)).deflate(4),
        Paint()
          ..color = lc.withValues(alpha: dark ? .25 : .55)
          ..maskFilter = blur(BlurStyle.normal, 9),
      );
      c.drawRRect(
        rr.deflate(2),
        Paint()
          ..color = rc.withValues(alpha: .45)
          ..maskFilter = blur(BlurStyle.normal, 8),
      );
    }
    c.save();
    c.clipRRect(rr);
    // body: the level's colour at 12–16 % over a little white
    c.drawRect(r, Paint()..color = Pal.mix(lc, dark ? .16 : .12, Colors.white.withValues(alpha: dark ? .04 : .10)));
    // the realm's qi from below
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset(s.width * .7, s.height * 1.2), s.width * .9, [
          rc.withValues(alpha: dark ? .34 : .30),
          rc.withValues(alpha: 0),
        ], [0, .7]),
    );
    // highlight from the top left
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset(s.width * .28, -s.height * .1), s.width * 1.2, [
          Colors.white.withValues(alpha: dark ? .22 : .5),
          Colors.white.withValues(alpha: 0),
        ], [0, .58]),
    );
    c.restore();
    // the rim through the five elements (conic, from 210°)
    final el = [p.elWood, p.elFire, p.elEarth, p.elMetal, p.elWater, p.elWood];
    c.drawRRect(
      rr.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = ui.Gradient.sweep(r.center, el, const [0, .2, .4, .6, .8, 1], TileMode.clamp, 0, math.pi * 2, Matrix4.rotationZ(math.pi * (210 - 90) / 180).storage)
        ..color = Colors.white.withValues(alpha: .95),
    );
    // inset top light
    c.save();
    c.clipRRect(rr);
    c.drawLine(
      Offset(radius * .6, 1.2),
      Offset(s.width - radius * .6, 1.2),
      Paint()
        ..color = Colors.white.withValues(alpha: dark ? .28 : .7)
        ..strokeWidth = 1,
    );
    c.restore();
    // a thin gold line on top
    if (!low) {
      final gl = Rect.fromLTWH(s.width * .22, -1, s.width * .56, 2);
      c.drawRRect(
        RRect.fromRectAndRadius(gl, const Radius.circular(2)),
        Paint()
          ..shader = ui.Gradient.linear(gl.centerLeft, gl.centerRight, [
            p.gold.withValues(alpha: 0),
            p.gold.withValues(alpha: .85),
            p.gold.withValues(alpha: 0),
          ], [0, .5, 1]),
      );
    }
  }

  @override
  bool shouldRepaint(_HskLensPainter o) => o.p != p || o.lc != lc || o.rc != rc || o.low != low;
}

/// the tab bar's lens: quieter glass in the tab's colour
class TabLens extends StatelessWidget {
  final Color lc;
  const TabLens({super.key, required this.lc});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Pal.mix(lc, .14, Colors.white.withValues(alpha: .08)),
        gradient: RadialGradient(
          center: const Alignment(-.4, -1.4),
          radius: 1.2,
          colors: [Colors.white.withValues(alpha: p.dark ? .22 : .45), Colors.white.withValues(alpha: 0)],
          stops: const [0, .6],
        ),
        border: Border.all(color: lc.withValues(alpha: .26)),
        boxShadow: sh([BoxShadow(color: lc.withValues(alpha: .5), offset: const Offset(0, 6), blurRadius: 16, spreadRadius: -10)]),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Pal.mix(lc, .14, Colors.white.withValues(alpha: .08)),
        ),
      ),
    );
  }
}
