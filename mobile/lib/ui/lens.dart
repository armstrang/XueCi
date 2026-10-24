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
    if (i < 0 || i >= w.length) return (0, 0);
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
            if (_to < 0) return;
            final w = _w(total, _to);
            _dragStart = _rect(w, _to).$1;
            _x0 = d.localPosition.dx;
            _moved = false;
          },
          onHorizontalDragUpdate: (d) {
            final dx = d.localPosition.dx - _x0;
            if (_to < 0 || (!_moved && dx.abs() < 7)) return;
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
              final rFrom = _from < 0 ? rTo : (_fromDrag ? (_fromLeft, wFrom[_from]) : _rect(wFrom, _from));
              double left, width;
              if (_dragL != null && _to >= 0) {
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
                      if (_to >= 0)
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
      // a coloured glow around the lens, never under it
      OuterShadow([
        BoxShadow(color: lc.withValues(alpha: dark ? .30 : .40), offset: const Offset(0, 8), blurRadius: 18, spreadRadius: -6),
        BoxShadow(color: rc.withValues(alpha: .30), blurRadius: 14, spreadRadius: -4),
      ], radius).paint(c, s);
    }
    final path = Path()..addRRect(rr.deflate(.5));
    // clear liquid glass with a breath of the level's colour
    paintGlass(c, path, r, p, GK.lens, tint: lc.withValues(alpha: dark ? .10 : .12), low: low, rr: rr.deflate(.5));
    // the realm's qi from below
    c.save();
    c.clipRRect(rr);
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset(s.width * .7, s.height * 1.2), s.width * .9, [
          rc.withValues(alpha: dark ? .16 : .24),
          rc.withValues(alpha: 0),
        ], [0, .7]),
    );
    c.restore();
    // the rim through the five elements (conic, from 210°)
    // the five elements as a faint coloured ring just inside the clear rim
    final el = [for (final e in [p.elWood, p.elFire, p.elEarth, p.elMetal, p.elWater, p.elWood]) e.withValues(alpha: .6)];
    c.drawRRect(
      rr.deflate(2.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = ui.Gradient.sweep(r.center, el, const [0, .2, .4, .6, .8, 1], TileMode.clamp, 0, math.pi * 2, Matrix4.rotationZ(math.pi * (210 - 90) / 180).storage)
        ..color = Colors.white.withValues(alpha: .95),
    );
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
    final th = Th.of(context);
    return CustomPaint(painter: _TabLensPainter(th.p, lc, th.low));
  }
}

class _TabLensPainter extends CustomPainter {
  final Pal p;
  final Color lc;
  final bool low;
  _TabLensPainter(this.p, this.lc, this.low);
  @override
  void paint(Canvas c, Size s) {
    // the mockup: a soft pill of light under the open tab (white veil, a hairline, light on its top edge)
    final r = (Offset.zero & s).deflate(1);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(math.min(24, r.height / 2)));
    if (!low && !p.dark) {
      OuterShadow([const BoxShadow(color: Color.fromRGBO(40, 40, 80, .14), offset: Offset(0, 4), blurRadius: 12, spreadRadius: -4)], rr.tlRadiusX)
          .paint(c, s);
    }
    c.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: p.dark ? .10 : .58));
    c.drawRRect(rr, Paint()..color = lc.withValues(alpha: p.dark ? .06 : .05));
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: p.dark ? .14 : .8),
    );
    c.save();
    c.clipRRect(rr);
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = ui.Gradient.linear(r.topCenter, Offset(r.center.dx, r.top + 10), [
          Colors.white.withValues(alpha: p.dark ? .22 : .9),
          Colors.white.withValues(alpha: 0),
        ]),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_TabLensPainter o) => o.p != p || o.lc != lc || o.low != low;
}

/// a chosen segment or pill: a drop of clear liquid glass, lightly tinted
class LensPill extends StatelessWidget {
  final double radius;
  final Color? tint;
  const LensPill({super.key, this.radius = 11, this.tint});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return CustomPaint(painter: _PillPainter(th.p, radius, tint, th.low));
  }
}

class _PillPainter extends CustomPainter {
  final Pal p;
  final double radius;
  final Color? tint;
  final bool low;
  _PillPainter(this.p, this.radius, this.tint, this.low);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    final path = Path()..addRRect(RRect.fromRectAndRadius(r.deflate(.5), Radius.circular(radius)));
    if (!low) {
      OuterShadow([BoxShadow(color: Color.fromRGBO(0, 0, 0, p.dark ? .35 : .12), offset: const Offset(0, 3), blurRadius: 10, spreadRadius: -3)], radius)
          .paint(c, s);
    }
    // a little more body than the tab lens: the chosen label must read at once
    final rr = RRect.fromRectAndRadius(r.deflate(.5), Radius.circular(radius));
    c.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: p.dark ? .10 : .62));
    paintGlass(c, path, r, p, GK.lens, tint: tint, low: low, rr: rr);
  }

  @override
  bool shouldRepaint(_PillPainter o) => o.p != p || o.radius != radius || o.tint != tint || o.low != low;
}
