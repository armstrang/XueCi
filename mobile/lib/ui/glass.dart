/// Liquid Glass, as in the WebView app (glass.css.html): light from the top left; clear panels with a bright rim
/// (strongest top-left and bottom-right), a glossy highlight along the top and a soft shadow. Real frosting (blur)
/// only on layers that float over scrolling content: the tab bar, sheets, menus, toasts.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import 'theme.dart';

/// Tests: Flutter's test renderer draws blurred shadows sharp, so screenshots leave them out.
bool noBlur = false;
List<BoxShadow>? sh(List<BoxShadow>? s) => noBlur ? null : s;
MaskFilter? blur(BlurStyle st, double sigma) => noBlur ? const MaskFilter.blur(BlurStyle.normal, 0.01) : MaskFilter.blur(st, sigma);

/// The palette and accent of the moment, for every widget below the shell.
class Th extends InheritedWidget {
  final Pal p;
  final Color acc; // the chosen HSK level's colour
  final Color rc; // the realm's colour
  final bool low; // visual effects: low (no blur, no glow)
  final bool full;
  final double fs; // the phone's text size (0.85–1.6)
  final int tick; // App.tick: any change of the app's state
  const Th({
    super.key,
    required this.p,
    required this.acc,
    required this.rc,
    required this.low,
    required this.full,
    required this.fs,
    this.tick = 0,
    required super.child,
  });

  static Th of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Th>()!;
  static Pal pal(BuildContext c) => of(c).p;

  /// display text grows half as much as body text (the web app's --fsd)
  double get fsd => 1 + (fs - 1) / 2;

  @override
  bool updateShouldNotify(Th o) =>
      o.p != p || o.acc != acc || o.rc != rc || o.low != low || o.full != full || o.fs != fs || o.tick != tick;
}

/// A glass panel: fill, highlight, rim, shadow.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool solid;
  final bool frost; // real blur (floating layers only)
  final Color? color; // a solid colour instead of glass (e.g. --card)
  final List<BoxShadow>? shadow;
  final bool rim;
  final double? width, height;
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.solid = false,
    this.frost = false,
    this.color,
    this.shadow,
    this.rim = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final r = BorderRadius.circular(radius);
    Widget inner = CustomPaint(
      foregroundPainter: rim ? GlassRim(p, radius) : null,
      painter: color == null ? _Highlight(p, radius, solid) : null,
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    BoxDecoration deco;
    if (frost) {
      deco = BoxDecoration(color: th.low ? p.surface : p.gHead, borderRadius: r);
    } else if (color != null) {
      deco = BoxDecoration(color: color, borderRadius: r);
    } else {
      deco = BoxDecoration(
        borderRadius: r,
        color: solid ? p.cardC.withValues(alpha: p.gSolid) : null,
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  p.cardC.withValues(alpha: p.gFillA),
                  p.cardC.withValues(alpha: p.gFillB),
                  p.cardC.withValues(alpha: p.gFillC),
                ],
                stops: const [0, .55, 1],
              ),
      );
    }
    Widget box = DecoratedBox(decoration: deco, child: inner);
    if (frost && !th.low) {
      box = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: box),
      );
    }
    final shd = shadow ?? (th.low && frost ? const <BoxShadow>[] : p.drop);
    final list = sh(shd);
    return SizedBox(
      width: width,
      height: height,
      child: list == null || list.isEmpty ? box : CustomPaint(painter: OuterShadow(list, radius), child: box),
    );
  }
}

/// A shadow drawn only outside a shape (CSS box-shadow): Flutter's BoxShadow also paints under the box, which shows
/// through translucent glass and makes it look murky.
class OuterShadow extends CustomPainter {
  final List<BoxShadow> shadows;
  final double radius;
  final Path Function(Size)? shape;
  OuterShadow(this.shadows, this.radius, {this.shape});
  @override
  void paint(Canvas c, Size s) {
    final path = shape != null ? shape!(s) : (Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius))));
    c.save();
    c.clipPath(Path.combine(PathOperation.difference, Path()..addRect((Offset.zero & s).inflate(400)), path));
    for (final b in shadows) {
      final grown = b.spreadRadius == 0
          ? path
          : (shape == null
                ? (Path()
                    ..addRRect(
                      RRect.fromRectAndRadius(
                        (Offset.zero & s).inflate(b.spreadRadius),
                        Radius.circular((radius + b.spreadRadius).clamp(0, double.infinity)),
                      ),
                    ))
                : path);
      c.drawPath(grown.shift(b.offset), Paint()
        ..color = b.color
        ..maskFilter = b.blurRadius > 0 ? MaskFilter.blur(BlurStyle.normal, b.blurSigma) : null);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(OuterShadow o) => o.shadows != shadows || o.radius != radius;
}

/// the radial highlight from the top-left (part of --g-fill / --g-solid) and the bright line inside the top edge
class _Highlight extends CustomPainter {
  final Pal p;
  final double radius;
  final bool solid;
  _Highlight(this.p, this.radius, this.solid);
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius));
    c.save();
    c.clipRRect(rr);
    final a = solid ? p.gSolidTop : p.gFillTop;
    final center = Offset(s.width * .12, -s.height * .3);
    final rx = s.width * 1.4, ry = s.height * (solid ? .7 : .9);
    c.translate(center.dx, center.dy);
    c.scale(1, ry / rx);
    c.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, rx, [
          Colors.white.withValues(alpha: a),
          Colors.white.withValues(alpha: 0),
        ], [0, solid ? .6 : .58]),
    );
    c.restore();
    // inset 0 1px 0 rgba(255,255,255,insetTop)
    final top = Paint()
      ..color = Colors.white.withValues(alpha: p.insetTop)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    c.save();
    c.clipRRect(rr);
    final path = Path()..addRRect(rr.deflate(.5));
    c.clipRect(Rect.fromLTWH(0, 0, s.width, radius < s.height ? radius : s.height));
    c.drawPath(path, top..color = Colors.white.withValues(alpha: p.insetTop * .6));
    c.restore();
  }

  @override
  bool shouldRepaint(_Highlight o) => o.p != p || o.radius != radius || o.solid != solid;
}

/// the thin bright rim of glass: 135°, bright at the top-left and bottom-right corners
class GlassRim extends CustomPainter {
  final Pal p;
  final double radius;
  final double width;
  GlassRim(this.p, this.radius, {this.width = 1});
  @override
  void paint(Canvas c, Size s) {
    final rr = RRect.fromRectAndRadius((Offset.zero & s).deflate(width / 2), Radius.circular(radius));
    final light = !p.dark;
    final a = light
        ? const [1.0, .6, .06, .04, .55, 1.0]
        : (p.black ? const [.85, .2, .03, .03, .18, .55] : const [.9, .25, .03, .03, .22, .62]);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(Offset.zero, Offset(s.width, s.height), [
        for (final x in a) Colors.white.withValues(alpha: x),
      ], const [0, .15, .40, .62, .86, 1]);
    c.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(GlassRim o) => o.p != p || o.radius != radius;
}

/// a tap target that springs (transform only): shrinks a little while pressed
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final String? label;
  final bool button;
  final bool selected;
  final HitTestBehavior behavior;
  const Press({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .965,
    this.label,
    this.button = true,
    this.selected = false,
    this.behavior = HitTestBehavior.opaque,
  });
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    Widget w = AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: Duration(milliseconds: _down ? 120 : 320),
      curve: _down ? Curves.easeOut : const Cubic(.34, 1.56, .64, 1),
      child: widget.child,
    );
    w = GestureDetector(
      behavior: widget.behavior,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: on
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: w,
    );
    return Semantics(
      button: widget.button && on,
      selected: widget.selected,
      label: widget.label,
      enabled: on,
      excludeSemantics: widget.label != null,
      child: w,
    );
  }
}

/// a static background: a gradient top → bottom with a glow in the level's colour from the top-left corner and a
/// warm light low on the right (it fades to a new colour when the level changes)
class GlowBackground extends StatelessWidget {
  final Color tone;
  const GlowBackground({super.key, required this.tone});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tone),
      duration: const Duration(milliseconds: 900),
      builder: (c, col, _) => CustomPaint(painter: _BgPainter(th.p, col ?? tone, th.low), size: Size.infinite),
    );
  }
}

class _BgPainter extends CustomPainter {
  final Pal p;
  final Color tone;
  final bool low;
  _BgPainter(this.p, this.tone, this.low);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [p.bgTop, p.bgBot]),
    );
    final vmax = s.width > s.height ? s.width : s.height;
    final g = Offset(s.width / 2 - 280 < 16 ? 36 : s.width / 2 - 260, 36);
    c.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.radial(g, vmax * .9, [
          tone.withValues(alpha: p.glowO),
          tone.withValues(alpha: p.glowO * .4),
          tone.withValues(alpha: 0),
        ], [0, .36, .72]),
    );
    if (!low) {
      // a warm light low on the right: radial 70vmax × 55vmax at 105% 78%
      c.save();
      final ctr = Offset(s.width * 1.05, s.height * .78);
      c.translate(ctr.dx, ctr.dy);
      c.scale(1, .55 / .7);
      c.drawCircle(
        Offset.zero,
        vmax * .7,
        Paint()..shader = ui.Gradient.radial(Offset.zero, vmax * .7, [p.warm, p.warm.withValues(alpha: 0)], [0, .7]),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_BgPainter o) => o.p != p || o.tone != tone || o.low != low;
}

/// text that keeps the phone's text size only half-way (compact chrome)
class Compact extends StatelessWidget {
  final Widget child;
  final double max;
  const Compact({super.key, required this.child, this.max = 99});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final f = th.fsd < max ? th.fsd : max;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(f)),
      child: child,
    );
  }
}

/// a small round status dot (green / yellow / red / none)
class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot(this.color, {super.key, this.size = 9});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// app-wide: the current palette (theme setting + the phone's dark mode)
Pal palFor(String theme, Brightness platform) => switch (theme) {
  'light' => Pal.lightP,
  'dark' => Pal.darkP,
  'black' => Pal.blackP,
  _ => platform == Brightness.dark ? Pal.darkP : Pal.lightP,
};

bool get fxLow => app.fx == 'low';
