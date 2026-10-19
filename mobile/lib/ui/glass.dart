/// Liquid Glass, as in the WebView app (glass.css.html): light from the top left; clear panels with a bright rim
/// (strongest top-left and bottom-right), a glossy highlight along the top and a soft shadow. Real frosting (blur)
/// only on layers that float over scrolling content: the tab bar, sheets, menus, toasts.
library;

import 'dart:math' as math;
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

/// How deep a glass layer sits: 0 = on the background, 1+ = inside a panel or a sheet.
class GlassDepth extends InheritedWidget {
  final int d;
  const GlassDepth({super.key, required this.d, required super.child});
  static int of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<GlassDepth>()?.d ?? 0;
  @override
  bool updateShouldNotify(GlassDepth o) => o.d != d;
}

/// Inside a grouped list (iOS settings style) the rows share one glass: the next Glass below this scope is drawn
/// flat (no fill, no rim), and glass inside that row is normal again.
class GlassFlat extends InheritedWidget {
  final bool on;
  const GlassFlat({super.key, this.on = true, required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<GlassFlat>()?.on ?? false;
  @override
  bool updateShouldNotify(GlassFlat o) => o.on != on;
}

/// the kinds of glass: a panel on the background, an element inside one, a floating frosted layer, a lens
enum GK { panel, inner, frost, lens }

/// Paints glass into [path] (bounds [b]): milky fill, a tint, the light from the top left, a soft white glow inside
/// the edge (Galaxy's fluid glass) and a bright rim strongest at the top-left and bottom-right (Liquid Glass).
/// A rounded rectangle ([rr]) takes the fast paths (clipRRect, drawRRect); other shapes use [path].
void paintGlass(Canvas c, Path path, Rect b, Pal p, GK k, {Color? tint, bool low = false, bool rim = true, RRect? rr}) {
  final w = b.width, h = b.height;
  if (w <= 0 || h <= 0) return;
  void draw(Paint pt) => rr != null ? c.drawRRect(rr, pt) : c.drawPath(path, pt);
  void clip() => rr != null ? c.clipRRect(rr) : c.clipPath(path);
  final fill = switch (k) {
    GK.panel => [p.glassA, p.glassB],
    GK.inner => [p.innerA, p.innerB],
    GK.frost => [low ? p.surface : p.frostC, low ? p.surface : p.frostC],
    GK.lens => [Colors.white.withValues(alpha: p.dark ? .05 : .34), Colors.white.withValues(alpha: p.dark ? .02 : .16)],
  };
  // without effects the glass needs body to read on the background
  final lowBoost = low && k != GK.frost && k != GK.lens ? (p.dark ? .05 : .22) : 0.0;
  draw(
    Paint()
      ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [
        fill[0].withValues(alpha: (fill[0].a + lowBoost).clamp(0, 1)),
        fill[1].withValues(alpha: (fill[1].a + lowBoost).clamp(0, 1)),
      ]),
  );
  if (tint != null) draw(Paint()..color = tint);
  c.save();
  clip();
  // the light from the top left
  // small pieces (chips, pills) stay clear: less light inside them, so their text keeps its contrast
  final small = k == GK.inner && p.dark ? ((h - 24) / 64).clamp(.1, 1.0) : 1.0;
  final sheen = k == GK.lens ? (p.dark ? .22 : .6) : (k == GK.inner ? p.sheen * .6 * small : p.sheen);
  if (sheen > 0) {
    final ctr = Offset(b.left + w * .15, b.top - h * .35);
    final rx = math.max(w, h) * 1.2;
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.scale(1, math.min(1, (h * 1.1) / rx));
    c.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, rx, [Colors.white.withValues(alpha: sheen), Colors.white.withValues(alpha: 0)], [0, .6]),
    );
    c.restore();
  }
  // the glow inside the edge: strokes of growing width, so the light is strongest at the rim and fades inwards
  if (!low) {
    final reach = switch (k) {
      GK.panel => 16.0,
      GK.frost => 12.0,
      GK.lens => 10.0,
      GK.inner => 9.0,
    };
    final a = switch (k) {
      GK.lens => p.dark ? .22 : 1.0,
      GK.inner => p.glowIn * (p.dark ? .5 * small : .75),
      _ => p.glowIn,
    };
    const n = 4;
    // on dark glass the light comes from above: the glow is strong along the top and fades towards the bottom
    final gp = Paint()
      ..style = PaintingStyle.stroke
      ..shader = ui.Gradient.linear(b.topCenter, Offset(b.center.dx, b.top + math.min(h * .55, 160.0)), [
        Colors.white.withValues(alpha: a / n),
        Colors.white.withValues(alpha: p.dark ? a / n * .12 : a / n * .8),
      ]);
    for (var i = 1; i <= n; i++) {
      draw(gp..strokeWidth = 2 * reach * i / n);
    }
  }
  c.restore();
  if (rim) {
    final hi = k == GK.lens ? 1.0 : p.rimHi, lo = k == GK.lens ? (p.dark ? .2 : .5) : p.rimLo;
    // the light falls from above: the rim shines along the top, fades down the sides and glints again at the bottom
    final top = b.top, span = math.min(b.height * .6, 90.0);
    draw(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = k == GK.lens ? 1.5 : 1.2
        ..shader = ui.Gradient.linear(Offset(b.left, top), Offset(b.left, top + span), [
          Colors.white.withValues(alpha: hi),
          Colors.white.withValues(alpha: hi * .3),
          Colors.white.withValues(alpha: lo),
        ], const [0, .35, 1]),
    );
    if (b.height > 24) {
      draw(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = ui.Gradient.radial(b.bottomRight, math.min(math.max(b.width, b.height) * .35, 90.0), [
            Colors.white.withValues(alpha: hi * .5),
            Colors.white.withValues(alpha: 0),
          ]),
      );
    }
  }
}

/// A glass panel: fill, glow, rim, shadow. Inside another panel (or a sheet) it becomes the brighter inner glass.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool solid;
  final bool frost; // real blur (floating layers only)
  final Color? color; // a tint over the glass (a chosen or marked state)
  final List<BoxShadow>? shadow;
  final bool rim;
  final bool? inner; // force panel (false) or inner (true) glass
  final double? width, height;
  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.borderRadius,
    this.padding,
    this.solid = false,
    this.frost = false,
    this.color,
    this.shadow,
    this.rim = true,
    this.inner,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final depth = GlassDepth.of(context);
    final br = borderRadius ?? BorderRadius.circular(radius);
    if (!frost && GlassFlat.of(context)) {
      Widget body = Padding(padding: padding ?? EdgeInsets.zero, child: child);
      if (color != null) body = DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: br), child: body);
      return SizedBox(
        width: width,
        height: height,
        child: GlassFlat(on: false, child: GlassDepth(d: depth + 1, child: body)),
      );
    }
    final k = frost ? GK.frost : ((inner ?? depth > 0) ? GK.inner : GK.panel);
    Widget box = CustomPaint(
      painter: _GlassPainter(p, k, br, color, th.low, rim, solid),
      child: GlassDepth(
        d: depth + 1,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
    if (frost && !th.low) {
      // the floating layers of a screen (tab bar, header) share one backdrop read (BackdropGroup in the shell)
      final f = ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16, tileMode: TileMode.clamp);
      box = ClipRRect(
        borderRadius: br,
        child: BackdropGroup.of(context) != null ? BackdropFilter.grouped(filter: f, child: box) : BackdropFilter(filter: f, child: box),
      );
    }
    final shd = shadow ?? (th.low && frost ? const <BoxShadow>[] : (k == GK.inner ? p.dropIn : p.drop));
    final list = sh(shd);
    return SizedBox(
      width: width,
      height: height,
      child: list == null || list.isEmpty ? box : CustomPaint(painter: OuterShadow(list, radius, br: br, clip: k != GK.inner), child: box),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final Pal p;
  final GK k;
  final BorderRadius br;
  final Color? tint;
  final bool low, rim, solid;
  _GlassPainter(this.p, this.k, this.br, this.tint, this.low, this.rim, this.solid);
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    final rr = br.toRRect(r).deflate(.6);
    final path = Path()..addRRect(rr);
    if (solid && k != GK.frost) {
      // a little more body: text-heavy pieces (answers, lists)
      if (!p.dark) c.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: .14));
    }
    paintGlass(c, path, r, p, k, tint: tint, low: low, rim: rim, rr: rr);
  }

  @override
  bool shouldRepaint(_GlassPainter o) =>
      o.p != p || o.k != k || o.br != br || o.tint != tint || o.low != low || o.rim != rim || o.solid != solid;
}

/// A shadow drawn only outside a shape (CSS box-shadow): Flutter's BoxShadow also paints under the box, which shows
/// through translucent glass and makes it look murky.
class OuterShadow extends CustomPainter {
  final List<BoxShadow> shadows;
  final double radius;
  final BorderRadius? br;
  final Path Function(Size)? shape;
  final bool clip; // false: a faint shadow may sit under the glass too (cheaper: no clip)
  OuterShadow(this.shadows, this.radius, {this.shape, this.br, this.clip = true});
  @override
  void paint(Canvas c, Size s) {
    RRect rr(Rect r) => br != null ? br!.toRRect(r) : RRect.fromRectAndRadius(r, Radius.circular(radius));
    final path = shape != null ? shape!(s) : (Path()..addRRect(rr(Offset.zero & s)));
    c.save();
    if (clip) c.clipPath(Path.combine(PathOperation.difference, Path()..addRect((Offset.zero & s).inflate(400)), path));
    for (final b in shadows) {
      final paint = Paint()
        ..color = b.color
        ..maskFilter = b.blurRadius > 0 ? MaskFilter.blur(BlurStyle.normal, b.blurSigma) : null;
      if (shape == null) {
        // a blurred rounded rectangle is drawn analytically (cheap); a blurred path needs an offscreen pass
        c.drawRRect(rr(Offset.zero & s).inflate(b.spreadRadius).shift(b.offset), paint);
      } else {
        c.drawPath(path.shift(b.offset), paint);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(OuterShadow o) => o.shadows != shadows || o.radius != radius || o.br != br;
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
    final hi = p.rimHi, lo = p.rimLo;
    c.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = ui.Gradient.linear(Offset.zero, Offset(s.width, s.height), [
          for (final x in [hi, hi * .35, lo, lo, hi * .3, hi * .75]) Colors.white.withValues(alpha: x),
        ], const [0, .14, .32, .72, .9, 1]),
    );
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
    // the spring repaints only this piece, not the whole screen around it
    Widget w = RepaintBoundary(
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 120 : 260),
        curve: _down ? Curves.easeOut : const Cubic(.34, 1.4, .64, 1),
        child: widget.child,
      ),
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

/// a static background: an aurora (Galaxy's fluid colour) of the level's tone high on the left, a warm light low on
/// the right and a cool one on the left, over a soft gradient; it fades to a new colour when the level changes
class GlowBackground extends StatelessWidget {
  final Color tone;
  const GlowBackground({super.key, required this.tone});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: tone),
        duration: const Duration(milliseconds: 600),
        builder: (c, col, _) => CustomPaint(painter: _BgPainter(th.p, col ?? tone, th.low), size: Size.infinite, isComplex: true),
      ),
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
    c.drawRect(r, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), [p.bgTop, p.bgBot]));
    final vmax = math.max(s.width, s.height);
    // the tone, lightened on light themes so the glass above it stays milky
    final tn = p.dark ? Color.lerp(tone, Colors.black, .3)! : Color.lerp(tone, Colors.white, .42)!;
    void blob(Offset ctr, double rad, Color col, double a, {double sy = 1}) {
      if (a <= 0) return;
      c.save();
      c.translate(ctr.dx, ctr.dy);
      c.scale(1, sy);
      c.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, rad, [
            col.withValues(alpha: a),
            col.withValues(alpha: a * .45),
            col.withValues(alpha: 0),
          ], const [0, .45, 1]),
      );
      c.restore();
    }

    blob(Offset(s.width * .18, s.height * .06), vmax * .62, tn, p.auroraTone, sy: .8);
    blob(Offset(s.width * 1.02, s.height * .66), vmax * .55, p.auroraWarm, low ? p.auroraWarm.a * .6 : p.auroraWarm.a, sy: .75);
    if (!low) {
      blob(Offset(-s.width * .05, s.height * .42), vmax * .42, p.auroraCool, p.auroraCool.a, sy: .9);
      blob(Offset(s.width * .78, s.height * .2), vmax * .3, tn, p.auroraTone * .5);
      blob(Offset(s.width * .3, s.height * 1.02), vmax * .45, tn, p.auroraTone * .6, sy: .6);
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
