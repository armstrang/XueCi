/// Home (v1.14 Fluid Glass, Josh picked it): header pills (wordmark · cultivation days · Settings), the realm orb
/// flowing into the panel with the realm line and today's plan, then word mastery with the HSK picker. Fits one
/// screen above the tab bar.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'lens.dart';
import 'sheet.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final mq = MediaQuery.of(context);
    final bottom = mq.padding.bottom + 10 + 54 + 12; // above the tab bar
    final size = mq.size;
    if (size.width >= 900 && size.height >= 540 && size.width > size.height) return const _HomeWide();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
        child: LayoutBuilder(
          builder: (c, bc) {
            final maxFluid = 214 + 330 * th.fsd;
            final short = size.height <= 760;
            const keys = false; // the counts live behind the small ? next to the bar
            return Column(
              children: [
                HomeHeader(short: short),
                SizedBox(height: short ? 9 : 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (c, bc2) {
                      final mast = _Mastery(keys: keys, short: short);
                      return Column(
                        children: [
                          const Spacer(),
                          SizedBox(
                            height: math.min(maxFluid, math.max(260, bc2.maxHeight - _mastH(th, keys, short) - 12)),
                            child: const Fluid(),
                          ),
                          SizedBox(height: short ? 9 : 12),
                          mast,
                          const Spacer(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// the mastery panel's height (header, picker, bar, counts), for the room the realm panel gets
  static double _mastH(Th th, bool keys, bool short) =>
      (short ? 18 : 22) + 36 * th.fsd + (th.fs >= 1.15 ? 56 : 66) * th.fsd + 34 * th.fsd + (keys ? 44 * th.fsd : 0);
}

/// tablets in landscape: the realm on the left, word mastery (with its counts) on the right
class _HomeWide extends StatelessWidget {
  const _HomeWide();
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, mq.padding.bottom + 80),
        child: Column(
          children: [
            const HomeHeader(short: false),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: Fluid()),
                  const SizedBox(width: 20),
                  Expanded(child: Center(child: _Mastery(keys: false, short: false))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- header
class HomeHeader extends StatelessWidget {
  final bool short;
  const HomeHeader({super.key, required this.short});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final h = short ? 40.0 : 42.0;
    final s = app.memo('streak', app.lm.streak);
    final narrow = MediaQuery.sizeOf(context).width / Th.of(context).fs.clamp(1.0, 1.6) < 400; // the coin and Settings need the room
    return Compact(
      child: Row(
        children: [
          Press(
            onTap: app.onWordmark,
            scale: 1.06,
            label: 'XueCi Mandarin',
            child: Glass(
              frost: true,
              radius: h / 2,
              height: h,
              padding: EdgeInsets.fromLTRB(narrow ? 12 : 16, 0, narrow ? 12 : 18, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Xue'),
                        TextSpan(
                          text: 'Ci',
                          style: TextStyle(color: th.acc),
                        ),
                      ],
                    ),
                    style: F.s(narrow ? 16.5 : 18, w: FontWeight.w800, c: p.fg, ls: -.8, h: 1),
                  ),
                  if (th.fs < 1.15) ...[
                    const SizedBox(height: 4),
                    Text(
                      'MANDARIN',
                      style: F.s(8, w: FontWeight.w800, c: p.soft, ls: 2.9, h: 1),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          Press(
            onTap: () => app.openStreak?.call(context),
            scale: 1.06,
            label: L10.text(t.v('streakAria'), [app.fmt(s.days), s.today]),
            child: Glass(
              frost: true,
              radius: h / 2,
              height: h,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TaiJi(lit: s.today, size: 17),
                  const SizedBox(height: 2),
                  Text(
                    app.fmt(s.days),
                    textScaler: TextScaler.noScaling,
                    style: F.s(10.5, w: FontWeight.w800, c: s.today ? p.fg : p.soft, h: 1, feat: F.tab),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Press(
            onTap: () => app.openDonate?.call(context),
            scale: 1.06,
            label: t.dnAria,
            child: Glass(
              frost: true,
              radius: h / 2,
              width: h,
              height: h,
              child: Center(child: Icon2(I.coin, size: 21, color: p.gold)),
            ),
          ),
          const SizedBox(width: 8),
          Press(
            onTap: () => app.openSettings?.call(context),
            scale: 1.06,
            label: t.setT,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Glass(
                  frost: true,
                  radius: h / 2,
                  width: h,
                  height: h,
                  child: Center(child: Icon2(I.gear, size: 19, color: p.fg)),
                ),
                if (app.bkDue())
                  Positioned(
                    top: 7,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.sYellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.bgTop, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// the incense stick of the cultivation days: lit (with smoke) once today has some practice
class Incense extends StatelessWidget {
  final bool lit;
  final double size;
  const Incense({super.key, required this.lit, this.size = 32});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? null : p.fgA(.07),
        gradient: lit
            ? const LinearGradient(
                begin: Alignment(-.3, -1),
                end: Alignment(.3, 1),
                colors: [Color(0xfff2a15c), Color(0xffd9573a)],
              )
            : null,
        boxShadow: sh(
          lit
              ? const [BoxShadow(color: Color(0xffd9573a), offset: Offset(0, 6), blurRadius: 14, spreadRadius: -6)]
              : null,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: size * .53,
          height: size * .6,
          child: Stack(
            children: [
              Positioned.fill(
                child: Icon2(I.incense, size: size * .6, color: lit ? Colors.white : p.mute),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: lit ? 1 : .35,
                  child: Icon2(I.smoke, size: size * .6, color: lit ? Colors.white : p.mute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 太极 for the cultivation days: black and white once today has some practice, faint grey before
class TaiJi extends StatelessWidget {
  final bool lit;
  final double size;
  const TaiJi({super.key, required this.lit, this.size = 18});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return CustomPaint(size: Size.square(size), painter: _TaiJiPainter(lit, p.dark, p.fgA(.28), p.fgA(.10)));
  }
}

class _TaiJiPainter extends CustomPainter {
  final bool lit, dark;
  final Color dim, faint;
  _TaiJiPainter(this.lit, this.dark, this.dim, this.faint);
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final o = Offset(r, r);
    final yin = lit ? const Color(0xff15161b) : dim;
    final yang = lit ? Colors.white : faint;
    final edge = lit ? (dark ? Colors.white.withValues(alpha: .85) : const Color(0xff15161b)) : dim;
    c.drawCircle(o, r, Paint()..color = yang);
    // the dark half: the right half circle, swelling into the top small circle, carved by the bottom one
    final half = Path()..addArc(Rect.fromCircle(center: o, radius: r), -math.pi / 2, math.pi);
    final top = Path()..addOval(Rect.fromCircle(center: Offset(r, r / 2), radius: r / 2));
    final bot = Path()..addOval(Rect.fromCircle(center: Offset(r, r * 1.5), radius: r / 2));
    final shape = Path.combine(PathOperation.difference, Path.combine(PathOperation.union, half..close(), top), bot);
    c.drawPath(shape, Paint()..color = yin);
    c.drawCircle(Offset(r, r * .5), r * .16, Paint()..color = yang);
    c.drawCircle(Offset(r, r * 1.5), r * .16, Paint()..color = yin);
    c.drawCircle(o, r - .6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = edge);
  }

  @override
  bool shouldRepaint(_TaiJiPainter o) => o.lit != lit || o.dark != dark || o.dim != dim;
}

// ---------------------------------------------------------------- the realm orb and its panel
class Fluid extends StatelessWidget {
  const Fluid({super.key});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final r = app.lm.realm();
    final lc = p.realm(r, band: app.band);
    final geom = _Geom();
    return LayoutBuilder(
      builder: (c, bc) {
        final h = bc.maxHeight;
        final big = th.fs >= 1.15;
        final lines = (h > 400 && !big) ? 3 : (h > 340 ? 2 : (h > 300 ? 1 : 0));
        return CustomMultiChildLayout(
          delegate: _FluidLayout(geom, th.fsd, big),
          children: [
            LayoutId(
              id: 's',
              child: CustomPaint(painter: _FluidPainter(geom, p, lc, th.acc, th.low)),
            ),
            LayoutId(
              id: 'o',
              child: _Orb(geom: geom),
            ),
            LayoutId(
              id: 'q',
              child: _RingQ(small: h <= 300),
            ),
            LayoutId(
              id: 't',
              child: _RealmText(lines: lines, big: big),
            ),
            LayoutId(id: 'p', child: const PlanCard()),
          ],
        );
      },
    );
  }
}

class _Geom {
  double cx = 0, cy = 0, ob = 120, w = 0, h = 0;
}

class _FluidLayout extends MultiChildLayoutDelegate {
  final _Geom g;
  final double fsd;
  final bool big;
  _FluidLayout(this.g, this.fsd, this.big);
  @override
  void performLayout(Size size) {
    final w = size.width, h = size.height;
    final ps = layoutChild('p', BoxConstraints(maxWidth: w - 24, minWidth: w - 24));
    final ts = layoutChild('t', BoxConstraints(maxWidth: w - 40, minWidth: w - 40));
    var ob = big
        ? math.min(w * .48, h - 300 * fsd).clamp(72, 200).toDouble()
        : math.min(w * .52, h - 250 * fsd).clamp(76, 214).toDouble();
    var free = h - 12 - ps.height - ob - ts.height;
    if (free < 0) {
      ob = math.max(56, ob + free);
      free = h - 12 - ps.height - ob - ts.height;
    }
    // the realm text sits close above the plan; spare room goes above the orb, where the aurora shows
    final gap = math.min(math.max(0.0, free / 2), 22.0);
    final top = math.max(0.0, free - gap);
    layoutChild('o', BoxConstraints.tight(Size.square(ob)));
    positionChild('o', Offset((w - ob) / 2, top));
    final qs = layoutChild('q', const BoxConstraints());
    positionChild('q', Offset(w - qs.width - 4, 2));
    positionChild('t', Offset(20, top + ob));
    positionChild('p', Offset(12, h - 12 - ps.height));
    g
      ..cx = w / 2
      ..cy = top + ob / 2
      ..ob = ob
      ..w = w
      ..h = h;
    layoutChild('s', BoxConstraints.tight(size));
    positionChild('s', Offset.zero);
    assert(qs.width >= 0);
  }

  @override
  bool shouldRelayout(_FluidLayout o) => !identical(o.g, g) || o.fsd != fsd || o.big != big;
}

/// the fluid glass shape: a circle around the orb flowing into the rounded panel below it, with soft fillets where
/// they meet (fluidShape() in home.js)
Path fluidPath(double w, double h, double cx, double cy, double ob) {
  final R = ob / 2 + 9;
  final y = math.min(h - 60, cy + R * .6);
  final r = math.min(34.0, (h - y) / 2);
  const k = 26.0;
  final hh = math.sqrt(math.max(1, R * R - (y - cy) * (y - cy)));
  final y1 = y - k * .5;
  final x1 = math.sqrt(math.max(1, R * R - (y1 - cy) * (y1 - cy)));
  return Path()
    ..moveTo(0, y + r)
    ..arcToPoint(Offset(r, y), radius: Radius.circular(r))
    ..lineTo(cx - hh - k, y)
    ..quadraticBezierTo(cx - hh, y, cx - x1, y1)
    ..arcToPoint(Offset(cx + x1, y1), radius: Radius.circular(R), largeArc: true)
    ..quadraticBezierTo(cx + hh, y, cx + hh + k, y)
    ..lineTo(w - r, y)
    ..arcToPoint(Offset(w, y + r), radius: Radius.circular(r))
    ..lineTo(w, h - r)
    ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
    ..lineTo(r, h)
    ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
    ..close();
}

class _FluidPainter extends CustomPainter {
  final _Geom g;
  final Pal p;
  final Color lc, acc;
  final bool low;
  _FluidPainter(this.g, this.p, this.lc, this.acc, this.low);
  @override
  void paint(Canvas c, Size s) {
    final path = fluidPath(s.width, s.height, g.cx, g.cy, g.ob);
    if (!low) {
      // a soft coloured glow under the panel (.fglow)
      final gr = Rect.fromLTWH(s.width * .12, s.height - 104, s.width * .76, 110);
      c.drawRRect(
        RRect.fromRectXY(gr, gr.width / 2, gr.height / 2),
        Paint()
          ..shader = ui.Gradient.linear(
            gr.centerLeft,
            gr.centerRight,
            [
              p.gold.withValues(alpha: .7 * .32),
              acc.withValues(alpha: .32),
              Pal.mix(lc, .6, const Color(0xffe89ab0)).withValues(alpha: .32),
            ],
            [0, .5, 1],
          )
          ..maskFilter = blur(BlurStyle.normal, 30),
      );
      // the shadow only outside the glass, never under it; drawn as a blurred circle (the orb) and a blurred rounded
      // rectangle (the panel): both are cheap analytic blurs, a blurred path would need an offscreen pass every frame
      if (!noBlur) {
        final R = g.ob / 2 + 9;
        final y = math.min(s.height - 60, g.cy + R * .6);
        c.save();
        c.clipPath(Path.combine(PathOperation.difference, Path()..addRect((Offset.zero & s).inflate(200)), path));
        for (final b in p.drop) {
          final pt = Paint()
            ..color = b.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.blurSigma);
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(0, y, s.width, s.height).inflate(b.spreadRadius).shift(b.offset),
              const Radius.circular(34),
            ),
            pt,
          );
          c.drawCircle(Offset(g.cx, g.cy) + b.offset, R + b.spreadRadius, pt);
        }
        c.restore();
      }
    }
    paintGlass(c, path, Offset.zero & s, p, GK.panel, low: low);
  }

  @override
  bool shouldRepaint(_FluidPainter o) => true;
}

class _Orb extends StatefulWidget {
  final _Geom geom;
  const _Orb({required this.geom});
  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final lm = app.lm;
    final t = app.t;
    final r = lm.realm();
    final lc = p.realm(r, band: app.band);
    final pct = app.realmPct(r);
    final open = lm.btOpen() && lm.canTest();
    final unst = !app.memo('stability', lm.stability).ok;
    final st = app.realmStage(r);
    if (open && !th.low && !MediaQuery.of(context).disableAnimations) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _glow.stop();
    }
    return LayoutBuilder(
      builder: (c, bc) {
        final ob = bc.maxWidth;
        final label =
            '${t.realmL}: ${app.rn[r]} ${app.rpy[r]}, ${L10.text(t.realmM[r])}${r > 0 && st != null ? ', ${App.sn[st.i]} ${L10.text(t.stageM[st.i])}' : ''}${r > 0 ? ', ${app.realmHSK(r)}' : ''}, ${t.chipProg(pct)}${unst ? '. ${t.unstT}' : (open ? '. ${t.stOpen}' : '')}';
        return Press(
          onTap: () => app.openRealm?.call(context),
          scale: .96,
          label: label,
          child: AnimatedBuilder(
            animation: _glow,
            builder: (c, child) => DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: sh(
                  open
                      ? [
                          BoxShadow(
                            color: p.gold.withValues(alpha: th.low ? .55 : .45 * _glow.value),
                            blurRadius: th.low ? 0 : 34 * _glow.value,
                            spreadRadius: th.low ? 3 : 6 * _glow.value,
                          ),
                        ]
                      : null,
                ),
              ),
              child: child,
            ),
            // the ring fills up when Home appears and glides to a new value (only the orb redraws)
            child: RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct / 100),
                duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (c, v, child) => CustomPaint(painter: _OrbRing(p, lc, v, unst, ob), child: child),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        app.rn[r],
                        style: F
                            .s(
                              ob * .3,
                              w: FontWeight.w900,
                              family: F.hz,
                              c: r == 0 ? p.soft : lc,
                              h: 1.05,
                              ls: ob * .3 * .04,
                            )
                            .copyWith(
                              shadows: r == 0 || th.low
                                  ? null
                                  : [Shadow(color: lc.withValues(alpha: .3), blurRadius: 22)],
                            ),
                        textScaler: TextScaler.noScaling,
                      ),
                      if (ob > 110) Text(app.rpy[r], style: F.s(11.5, c: p.soft)),
                      Text(
                        r > 0 ? '$pct%' : t.chipTest,
                        style: r > 0 ? F.s(ob * .125, c: p.fg, feat: F.tab) : F.s(12, w: FontWeight.w800, c: th.acc),
                        textScaler: r > 0 ? TextScaler.noScaling : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbRing extends CustomPainter {
  final Pal p;
  final Color lc;
  final double frac;
  final bool unstable;
  final double ob;
  _OrbRing(this.p, this.lc, this.frac, this.unstable, this.ob);
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 120;
    final ctr = s.center(Offset.zero);
    final rad = 56 * k;
    // the orb's own gloss
    c.drawCircle(
      ctr,
      s.width / 2,
      Paint()
        ..shader = ui.Gradient.radial(Offset(s.width * .34, s.height * .16), s.width * 1.1 * .52, [
          Colors.white.withValues(alpha: p.dark ? .13 : .55),
          Colors.white.withValues(alpha: 0),
        ]),
    );
    c.drawCircle(
      ctr,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * k
        ..color = p.fgA(.10),
    );
    if (frac <= 0) return;
    final rect = Rect.fromCircle(center: ctr, radius: rad);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * k
      ..strokeCap = StrokeCap.round;
    if (unstable) {
      paint
        ..color = p.sRed
        ..strokeCap = StrokeCap.butt;
      final total = math.pi * 2 * frac.clamp(0, 1);
      final dash = 3 * k / rad, gap = 6 * k / rad;
      for (var a = 0.0; a < total; a += dash + gap) {
        c.drawArc(rect, -math.pi / 2 + a, math.min(dash, total - a), false, paint);
      }
      return;
    }
    // the SVG's gradient runs from the top-left (gold) to the bottom-right (the realm's colour), in the ring rotated −90°
    paint.shader = ui.Gradient.linear(Offset(s.width, 0), Offset(0, s.height), [p.gold, lc]);
    c.drawArc(rect, -math.pi / 2, math.pi * 2 * frac.clamp(0, 1), false, paint);
  }

  @override
  bool shouldRepaint(_OrbRing o) => o.p != p || o.lc != lc || o.frac != frac || o.unstable != unstable;
}

class _RingQ extends StatelessWidget {
  final bool small;
  const _RingQ({required this.small});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final s = small ? 24.0 : 28.0;
    return Press(
      onTap: () => app.openInfo?.call(context, 'realm'),
      scale: 1.08,
      label: app.t.realmQ,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.bg.withValues(alpha: .3),
          border: Border.all(color: p.dark ? Colors.white.withValues(alpha: .7) : Colors.white, width: 1.6),
          boxShadow: sh([BoxShadow(color: Colors.black.withValues(alpha: p.dark ? .25 : .08), blurRadius: 8, offset: const Offset(0, 2))]),
        ),
        child: Center(
          child: Compact(
            child: Text(
              '?',
              style: F.s(12.5, w: FontWeight.w800, c: p.soft),
            ),
          ),
        ),
      ),
    );
  }
}

class _RealmText extends StatelessWidget {
  final int lines;
  final bool big;
  const _RealmText({required this.lines, required this.big});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final lm = app.lm;
    final t = app.t;
    final r = lm.realm();
    final lc = p.realm(r, band: app.band);
    final st = app.realmStage(r);
    final open = lm.btOpen() && lm.canTest();
    final unst = !app.memo('stability', lm.stability).ok;
    final pct = app.realmPct(r);
    final g = r > 0 ? (lm.grades()[r] ?? 0) : 0;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final nameSize = big ? 15.0 : (narrow ? 16.5 : 19.0);
    Widget line;
    if (r == 0) {
      line = Text(
        t.rLine0,
        textAlign: TextAlign.center,
        style: F.s(13.5, c: p.soft, h: 1.4),
      );
    } else if (unst) {
      line = Text(
        t.unstT,
        textAlign: TextAlign.center,
        style: F.s(13.5, w: FontWeight.w800, c: p.sRed, h: 1.4),
      );
    } else if (open) {
      line = Text(
        t.stOpen,
        textAlign: TextAlign.center,
        style: F.s(13.5, w: FontWeight.w800, c: p.gold, h: 1.4),
      );
    } else {
      line = Text(
        '${st != null ? '${L10.text(t.stageS[st.i])} · ' : ''}${t.toNext(pct)}',
        textAlign: TextAlign.center,
        style: F.s(13.5, c: p.soft, h: 1.4),
      );
    }
    final sh = st?.share ?? 0;
    const seg = [(0.0, .25), (.25, .5), (.5, .8), (.8, .8001)];
    return Padding(
      padding: EdgeInsets.only(top: lines >= 3 ? 14 : 4, bottom: lines >= 3 ? 14 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: L10.text(t.realmM[r])),
                if (r > 0)
                  TextSpan(
                    text: ' · ${app.realmHSK(r)}',
                    style: TextStyle(fontWeight: FontWeight.w500, color: p.soft),
                  ),
                if (g > 0) ...[
                  const TextSpan(text: ' '),
                  WidgetSpan(alignment: PlaceholderAlignment.middle, child: GradeBadge(g)),
                ],
              ],
            ),
            textAlign: TextAlign.center,
            style: F.s(nameSize, w: FontWeight.w800, c: p.fg, h: 1.25, ls: -.2),
          ),
          if (lines >= 3 && !big) ...[const SizedBox(height: 3), line],
          if (r > 0 && lines >= 1 && !(big && MediaQuery.sizeOf(context).height <= 700)) ...[
            SizedBox(height: lines >= 3 ? 10 : 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              height: 5,
                              color: p.fgA(.10),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: ((sh - seg[i].$1) / (seg[i].$2 - seg[i].$1)).clamp(0, 1).toDouble(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    gradient: LinearGradient(colors: [p.gold, lc]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (lines >= 2 && !big) ...[
                            const SizedBox(height: 4),
                            Text(
                              L10.text(t.stageS[i]),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: F.s(
                                11,
                                w: st?.i == i ? FontWeight.w800 : FontWeight.w400,
                                c: st?.i == i ? p.fg : p.mute,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- today's plan
class PlanCard extends StatelessWidget {
  const PlanCard({super.key});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final big = th.fs >= 1.15;
    final short = MediaQuery.sizeOf(context).height <= 760;
    // the plan is the brighter glass inside the panel
    Widget card({required EdgeInsets padding, required Widget child}) =>
        Glass(inner: true, solid: true, radius: 26, padding: padding, child: child);
    final chip = app.goalChip();
    final pad = big
        ? const EdgeInsets.fromLTRB(12, 9, 12, 11)
        : (short ? const EdgeInsets.fromLTRB(12, 10, 12, 12) : const EdgeInsets.fromLTRB(14, 12, 14, 14));
    if (app.isNewbie()) {
      return card(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      t.nbT,
                      style: F.s(17 * 1.0, w: FontWeight.w800, c: p.fg, ls: -.3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: _GoalChip(chip)),
              ],
            ),
            const SizedBox(height: 8),
            _NbOpt(pri: true, title: t.nbZero, sub: t.nbZeroS, onTap: () => app.startSession(false)),
            const SizedBox(height: 6),
            _NbOpt(pri: false, title: t.nbTest, sub: t.nbTestS, onTap: () => app.go('placement')),
          ],
        ),
      );
    }
    final P = app.memo('plan', () => lm.plan());
    final c = app.memo('challenge', lm.challenge);
    var todo = P.newToday + P.revToday > 0;
    final min = math.max(1, ((P.revToday * P.sp.rev + P.newToday * P.sp.neu) / 60).round());
    late Widget line;
    String stK, stT;
    final sts = t.stS;
    switch (P.status) {
      case 'free':
        (stK, stT) = ('none', t.stFree(P.newPerDay));
      case 'ok':
        (stK, stT) = ('green', t.stOk(P.finish != null ? app.dateS(P.finish!) : '–'));
      case 'behind':
        (stK, stT) = (
          'red',
          P.needMin != null ? t.stBehind(P.needMin) : t.stBehindDate(P.fixDate != null ? app.dateS(P.fixDate!) : '–'),
        );
      case 'review':
        (stK, stT) = ('green', t.stReview);
      case 'examweek':
        (stK, stT) = ('yellow', t.stExamWeek);
      default:
        (stK, stT) = ('red', t.stPast);
    }
    final lineStyle = F.s(15, w: FontWeight.w700, c: p.fg, h: 1.35, feat: F.tab);
    if (P.rest) {
      todo = false;
      line = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '闭关 ',
              style: F.s(15, w: FontWeight.w900, family: F.hz, c: p.elWater),
            ),
            TextSpan(text: t.planRestT),
          ],
        ),
        style: lineStyle,
      );
      (stK, stT) = ('none', '${sts['rest'] ?? t.planRest}');
    } else if (todo) {
      final parts = [
        if (P.revToday > 0) t.planRev(app.fmt(P.revToday)),
        if (P.newToday > 0) t.planNew(app.fmt(P.newToday)),
      ];
      line = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: parts.map(plainText).join(' · ')),
            TextSpan(
              text: '${parts.isEmpty ? '' : ' · '}${t.planMin(min)}',
              style: TextStyle(color: p.soft, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        style: lineStyle,
      );
    } else {
      line = Text('${t.planDone} ✓', style: lineStyle);
    }
    app.syncWidget(todo ? '${P.revToday}·${P.newToday}' : t.planDone);
    app.syncReminder();
    final cc = math.min(c['cnt'] as int, c['n'] as int);
    final cDone = c['done'] == true;
    final cl =
        '${t.chalT}: ${cDone ? t.chalDone : '${t.chalTxt(app.skName(c['k'] as String), c['n'], c['a'])} · $cc/${c['n']}'}';
    final btnLabel = todo ? (P.ansT > 0 ? t.planContS : t.planGoS) : t.planExtraS;
    final btn = MainBtn(
      btnLabel,
      icon: I.play,
      semantics: todo ? (P.ansT > 0 ? t.planCont : t.planGo) : t.planExtra,
      onTap: () => app.startSession(!todo),
    );
    // the status in a few words (the full sentence lives in the goal sheet)
    if (!P.rest) stT = '${sts[P.status == 'free' || P.status == 'ok' || P.status == 'behind' || P.status == 'review' || P.status == 'examweek' ? P.status : 'past'] ?? stT}';
    final showSt = !short || !big;
    return card(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  t.planT,
                  style: F.s(17, w: FontWeight.w800, c: p.fg, ls: -.3),
                ),
              ),
              GChip(
                label: cl,
                onTap: () => app.go('soul'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '试',
                      style: F.s(14, w: FontWeight.w900, family: F.hz, c: p.dark ? p.fg : th.acc),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cDone ? '✓' : '$cc/${c['n']}',
                      style: F.s(12.5, w: FontWeight.w800, c: cDone ? p.good : p.fg, feat: F.tab),
                    ),
                  ],
                ),
              ),
              _GoalChip(chip),
            ],
          ),
          SizedBox(height: short ? 4 : 6),
          if (big)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [line, const SizedBox(height: 8), btn])
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line,
                      if (showSt) ...[
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Dot(p.band(stK)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                plainText(stT),
                                style: F.s(12.5, c: p.soft, h: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // a short way in on a slow day: about two minutes of today's practice
                if (todo && min >= 4) ...[
                  GChip(
                    label: t.quickL,
                    onTap: () => app.startSession(false, quick: true),
                    child: Text('2′', style: F.s(14, w: FontWeight.w800, c: p.dark ? p.fg : th.acc, feat: F.tab)),
                  ),
                  const SizedBox(width: 8),
                ],
                btn,
              ],
            ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String text;
  const _GoalChip(this.text);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return GChip(
      onTap: () => app.openGoal?.call(context, false),
      label: text,
      child: Text(
        '$text ›',
        style: F.s(12.5, w: FontWeight.w800, c: th.acc),
      ),
    );
  }
}

class _NbOpt extends StatelessWidget {
  final bool pri;
  final String title, sub;
  final VoidCallback onTap;
  const _NbOpt({required this.pri, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final fg = pri ? p.onAcc : p.fg;
    final child = Row(
      children: [
        if (pri) ...[Icon2(I.play, size: 18, color: fg), const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: F.s(15.5, w: FontWeight.w800, c: fg),
              ),
              Text(sub, style: F.s(12.5, c: pri ? fg : p.soft)),
            ],
          ),
        ),
        if (!pri) Text('›', style: F.s(18, c: p.soft)),
      ],
    );
    return Press(
      onTap: onTap,
      scale: .98,
      label: '$title. $sub',
      child: pri
          ? Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: th.acc,
                gradient: RadialGradient(
                  center: const Alignment(-.4, -1.5),
                  radius: 1.3,
                  colors: [Color.lerp(th.acc, Colors.white, .3)!, th.acc],
                  stops: const [0, .52],
                ),
                boxShadow: sh([
                  BoxShadow(
                    color: th.acc.withValues(alpha: .6),
                    offset: const Offset(0, 10),
                    blurRadius: 22,
                    spreadRadius: -10,
                  ),
                ]),
              ),
              child: child,
            )
          : Glass(
              solid: true,
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 38), child: child),
            ),
    );
  }
}

// ---------------------------------------------------------------- word mastery
/// what the colours mean, with this level's counts (behind the small ? next to the bar)
void _bandSheet(BuildContext context, int level, List<(String, int)> rows) {
  openSheet(context, name: 'bands', (c) {
    final p = Th.pal(c);
    final t = app.t;
    return SheetBody(
      title: '${t.masT} · HSK $level',
      children: [
        Lead(t.masHelp),
        for (final (b, n) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Dot(p.band(b), size: 10),
                const SizedBox(width: 10),
                Expanded(child: Text(L10.text(t.band[b]), style: F.s(15, w: FontWeight.w700, c: p.fg))),
                Text(app.fmt(n), style: F.s(15, w: FontWeight.w800, c: p.fg, feat: F.tab)),
              ],
            ),
          ),
      ],
    );
  });
}

class _Mastery extends StatelessWidget {
  final bool keys, short;
  const _Mastery({required this.keys, required this.short});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final L = app.level;
    final S = app.summary(app.by(L));
    final pc = app.pctTxt(S.p);
    final big = th.fs >= 1.15;
    if (app.isNewbie() && short) return const SizedBox.shrink();
    return Glass(
      radius: 30,
      padding: short ? const EdgeInsets.fromLTRB(12, 8, 12, 10) : const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                header: true,
                child: Text(
                  t.masT,
                  style: F.s(15 * th.fsd / th.fs, w: FontWeight.w800, c: p.fg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: big
                    ? const SizedBox()
                    : Text(
                        'HSK $L · ${t.words(app.fmt(S.n))}',
                        style: F.s(12.5, c: p.soft),
                      ),
              ),
              Press(
                onTap: () => app.go('stats'),
                scale: 1.05,
                label: '${t.stTitle} · HSK $L · $pc',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${t.statsShort} ›',
                      style: F.s(13, w: FontWeight.w800, c: th.acc),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LevelLens(level: L, onPick: app.setLevel, showPct: !big, compact: short),
          SizedBox(height: short ? 4 : 6),
          Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  pc,
                  style: F.s(19, w: FontWeight.w700, c: p.fg, feat: F.tab),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StackBar([
                  for (final b in const ['green', 'yellow', 'red']) (S.band(b) / math.max(1, S.n), p.band(b)),
                ]),
              ),
              const SizedBox(width: 8),
              Press(
                onTap: () => _bandSheet(context, L, [for (final b in const ['green', 'yellow', 'red', 'none']) (b, S.band(b))]),
                scale: 1.1,
                label: '${t.masT}: ${t.masHelp}',
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.fgA(.25), width: 1.4)),
                      child: Text('?', textScaler: TextScaler.noScaling, style: F.s(12, w: FontWeight.w800, c: p.soft, h: 1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (keys) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                for (final b in const ['green', 'yellow', 'red', 'none'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.fmt(S.band(b)),
                            style: F.s(14, w: FontWeight.w800, c: p.fg, h: 1.2, feat: F.tab),
                          ),
                          Row(
                            children: [
                              Dot(p.band(b), size: 7),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  L10.text(t.band[b]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: F.s(11, c: p.soft),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// the HSK picker (Home and Stats): six levels, or nine past the gate (then just the numbers)
class LevelLens extends StatelessWidget {
  final int level;
  final ValueChanged<int> onPick;
  final bool showPct;
  final bool compact;
  const LevelLens({super.key, required this.level, required this.onPick, this.showPct = true, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lv = app.vocab.levels;
    final nine = lv.length > 6;
    final h = (compact ? 52.0 : 60.0) * th.fsd - (showPct ? 0 : 14);
    return Compact(
      child: LensRow(
        count: lv.length,
        selected: lv.indexOf(level),
        height: h,
        padding: const EdgeInsets.all(2),
        onSelect: (i) => onPick(lv[i]),
        lens: (c, sel, drag) => HskLens(lc: p.l(lv[sel])),
        item: (c, i, on) {
          final l = lv[i];
          final pc = app.pctTxt(app.summary(app.by(l)).p);
          return Press(
            onTap: on ? null : () => onPick(l),
            scale: .95,
            label: 'HSK $l, ${t.memoWord} $pc',
            selected: on,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!nine)
                  Text(
                    'HSK',
                    style: F.s(9.5, w: FontWeight.w700, c: on ? p.fg : p.soft, ls: .2, h: 1.1),
                  ),
                Text(
                  '$l',
                  style: F.s(nine ? 16 : 20, w: on ? FontWeight.w800 : FontWeight.w500, c: on ? p.l(l) : p.fg, h: 1.05),
                ),
                if (showPct)
                  Text(
                    pc,
                    style: F.s(10, w: FontWeight.w700, c: on ? p.fg : p.soft, feat: F.tab, h: 1.2),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
