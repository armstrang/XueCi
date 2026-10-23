/// Home (v1.14 Fluid Glass, Josh picked it): header pills (wordmark · cultivation days · Settings), the realm orb
/// flowing into the panel with the realm line and today's plan, then word mastery with the HSK picker. Fits one
/// screen above the tab bar.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../engine/learn.dart' show Stage;
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
    final bottom = mq.padding.bottom + 10 + 64 + 14; // above the tab bar
    final size = mq.size;
    if (size.width >= 900 && size.height >= 540 && size.width > size.height) return const _HomeWide();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
        child: LayoutBuilder(
          builder: (c, bc) {
            // tight: a small phone or large text; the same order, smaller pieces
            final tight = bc.maxHeight < 640 * math.max(1.0, th.fsd * .92);
            final gap = tight ? 10.0 : 16.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeHeader(short: tight),
                SizedBox(height: gap),
                RealmRow(tight: tight),
                SizedBox(height: gap),
                PlanCard(tight: tight),
                const Spacer(),
                SizedBox(height: tight ? 8 : 12),
                _Mastery(keys: false, short: tight),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// tablets in landscape: the realm and today on the left, word mastery on the right
class _HomeWide extends StatelessWidget {
  const _HomeWide();
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, mq.padding.bottom + 88),
        child: Column(
          children: [
            const HomeHeader(short: false),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [RealmRow(tight: false), SizedBox(height: 16), PlanCard(tight: false)],
                    ),
                  ),
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
    // one button in the group: the same size for all three, the press springs inside it
    Widget btn({required String label, required VoidCallback onTap, required Widget child}) => Press(
      onTap: onTap,
      scale: 1.08,
      label: label,
      child: SizedBox(width: h + 2, height: h, child: Center(child: child)),
    );
    return Compact(
      child: Row(
        children: [
          // the wordmark sits right on the aurora: no pill
          Press(
            onTap: app.onWordmark,
            scale: 1.04,
            label: 'XueCi Mandarin',
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Xue'),
                        TextSpan(text: 'Ci', style: TextStyle(color: th.acc)),
                      ],
                    ),
                    style: F.s(22, w: FontWeight.w800, c: p.fg, ls: -.9, h: 1),
                  ),
                  if (th.fs < 1.15) ...[
                    const SizedBox(height: 3),
                    Text('MANDARIN', style: F.s(8, w: FontWeight.w800, c: p.soft, ls: 2.9, h: 1)),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          // cultivation days · 护法 · Settings in one glass capsule
          Glass(
            frost: true,
            radius: h / 2,
            height: h,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                btn(
                  label: L10.text(t.v('streakAria'), [app.fmt(s.days), s.today]),
                  onTap: () => app.openStreak?.call(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TaiJi(lit: s.today, size: 16),
                      const SizedBox(height: 1.5),
                      Text(
                        app.fmt(s.days),
                        textScaler: TextScaler.noScaling,
                        style: F.s(10, w: FontWeight.w800, c: s.today ? p.fg : p.soft, h: 1, feat: F.tab),
                      ),
                    ],
                  ),
                ),
                btn(
                  label: t.dnAria,
                  onTap: () => app.openDonate?.call(context),
                  child: Icon2(I.coin, size: 19, color: p.gold),
                ),
                btn(
                  label: t.setT,
                  onTap: () => app.openSettings?.call(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon2(I.gear, size: 19, color: p.fg),
                      if (app.bkDue())
                        Positioned(
                          top: -2,
                          right: -3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: p.sYellow, shape: BoxShape.circle),
                          ),
                        ),
                    ],
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

// ---------------------------------------------------------------- the realm: a small orb beside its line
/// the realm row: the orb (a tap opens the path), the realm's name, its stage bars; the ? sits at the top right
class RealmRow extends StatelessWidget {
  final bool tight;
  const RealmRow({super.key, required this.tight});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final r = lm.realm();
    final st = app.realmStage(r);
    final open = lm.btOpen() && lm.canTest();
    final unst = !app.memo('stability', lm.stability).ok;
    final pct = app.realmPct(r);
    final g = r > 0 ? (lm.grades()[r] ?? 0) : 0;
    final ob = tight ? 84.0 : 104.0;
    Widget? note;
    if (r == 0) {
      note = Text(t.rLine0, maxLines: 2, overflow: TextOverflow.ellipsis, style: F.s(13.5, c: p.soft, h: 1.35));
    } else if (unst) {
      note = Text(t.unstT, maxLines: 2, overflow: TextOverflow.ellipsis, style: F.s(13.5, w: FontWeight.w800, c: p.sRed, h: 1.35));
    } else if (open) {
      note = Text(t.stOpen, maxLines: 2, overflow: TextOverflow.ellipsis, style: F.s(13.5, w: FontWeight.w800, c: p.gold, h: 1.35));
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            SizedBox.square(dimension: ob, child: const _Orb()),
            SizedBox(width: tight ? 14 : 18),
            Expanded(
              child: Press(
                onTap: () => app.openRealm?.call(context),
                scale: .98,
                label: '${L10.text(t.realmM[r])}${r > 0 ? ', ${app.realmHSK(r)}' : ''}, ${t.chipProg(pct)}',
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r > 0)
                        Padding(padding: const EdgeInsets.only(right: 34), child: Row(
                          children: [
                            Flexible(child: Text('${t.realmL} · ${app.realmHSK(r)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(13, w: FontWeight.w600, c: p.soft))),
                            if (g > 0) ...[const SizedBox(width: 6), GradeBadge(g)],
                          ],
                        )),
                      Padding(padding: EdgeInsets.only(right: r > 0 ? 0 : 34), child: Text(
                        L10.text(t.realmM[r]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: F.s(tight ? 19 : 22, w: FontWeight.w800, c: p.fg, h: 1.2, ls: -.4),
                      )),
                      if (note != null) ...[const SizedBox(height: 4), note],
                      if (r > 0 && note == null) ...[SizedBox(height: tight ? 7 : 9), _Stages(stage: st, labels: !tight || th.fs < 1.15)],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const Positioned(top: 0, right: 0, child: _RingQ(small: false)),
      ],
    );
  }
}

/// the four stages of a realm as short bars, the current one named
class _Stages extends StatelessWidget {
  final Stage? stage;
  final bool labels;
  const _Stages({required this.stage, required this.labels});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final lc = p.realm(app.lm.realm(), band: app.band);
    final sh = stage?.share ?? 0;
    const seg = [(0.0, .25), (.25, .5), (.5, .8), (.8, .8001)];
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 5,
                    color: p.fgA(.10),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ((sh - seg[i].$1) / (seg[i].$2 - seg[i].$1)).clamp(0, 1).toDouble(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: LinearGradient(colors: [p.gold, lc])),
                      ),
                    ),
                  ),
                ),
                if (labels) ...[
                  const SizedBox(height: 4),
                  Text(
                    L10.text(t.stageS[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: F.s(11, w: stage?.i == i ? FontWeight.w800 : FontWeight.w600, c: stage?.i == i ? p.fg : p.soft),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Orb extends StatefulWidget {
  const _Orb();
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
                        style: r > 0 ? F.s(ob * .125, c: p.fg, feat: F.tab) : F.s(12, w: FontWeight.w800, c: p.dark ? th.acc : Color.lerp(th.acc, Colors.black, .3)!),
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
    final s = small ? 26.0 : 30.0;
    return Press(
      onTap: () => app.openInfo?.call(context, 'realm'),
      scale: 1.08,
      label: app.t.realmQ,
      child: Glass(
        frost: true,
        radius: s / 2,
        width: s,
        height: s,
        child: Center(
          child: Text('?', textScaler: TextScaler.noScaling, style: F.s(13, w: FontWeight.w800, c: p.soft, h: 1)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- today's plan
class PlanCard extends StatelessWidget {
  final bool tight;
  const PlanCard({super.key, this.tight = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    Widget card(Widget child) => Glass(
      solid: true,
      radius: 30,
      padding: tight ? const EdgeInsets.fromLTRB(16, 12, 16, 14) : const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: child,
    );
    final chip = app.goalChip();
    final goal = Press(
      onTap: () => app.openGoal?.call(context, false),
      scale: 1.04,
      label: chip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Center(
          child: Text('$chip ›', textAlign: TextAlign.center, style: F.s(13.5, w: FontWeight.w800, c: th.acc)),
        ),
      ),
    );
    if (app.isNewbie()) {
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(t.nbT, style: F.s(tight ? 19 : 22, w: FontWeight.w800, c: p.fg, ls: -.4))),
            const SizedBox(height: 10),
            _NbOpt(pri: true, title: t.nbZero, sub: t.nbZeroS, onTap: () => app.startSession(false)),
            const SizedBox(height: 8),
            _NbOpt(pri: false, title: t.nbTest, sub: t.nbTestS, onTap: () => app.go('placement')),
            goal,
          ],
        ),
      );
    }
    final P = app.memo('plan', () => lm.plan());
    final c = app.memo('challenge', lm.challenge);
    var todo = P.newToday + P.revToday > 0;
    final min = math.max(1, ((P.revToday * P.sp.rev + P.newToday * P.sp.neu) / 60).round());
    final sts = t.stS;
    final stK = switch (P.status) {
      'free' => 'none',
      'ok' || 'review' => 'green',
      'examweek' => 'yellow',
      _ => 'red',
    };
    var stT = '${sts[const ['free', 'ok', 'behind', 'review', 'examweek'].contains(P.status) ? P.status : 'past'] ?? ''}';
    final big = tight ? 22.0 : 30.0;
    final hStyle = F.s(big, w: FontWeight.w800, c: p.fg, h: 1.12, ls: -.9, feat: F.tab);
    late Widget head;
    if (P.rest) {
      todo = false;
      stT = '${sts['rest'] ?? t.planRest}';
      head = Text.rich(
        TextSpan(children: [
          TextSpan(text: '闭关 ', style: TextStyle(fontFamily: F.hz, fontWeight: FontWeight.w900, color: p.elWater)),
          TextSpan(text: t.planRestT),
        ]),
        style: hStyle.copyWith(fontSize: big * .75),
      );
    } else if (todo && tight) {
      head = Text.rich(
        TextSpan(children: [
          TextSpan(text: [if (P.revToday > 0) plainText(t.planRev(app.fmt(P.revToday))), if (P.newToday > 0) plainText(t.planNew(app.fmt(P.newToday)))].join(' + ')),
          TextSpan(text: '  ${t.planMin(min)}', style: F.s(14, w: FontWeight.w600, c: p.soft, ls: 0)),
        ]),
        style: hStyle.copyWith(fontSize: 20, letterSpacing: -.4),
      );
    } else if (todo) {
      head = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (P.revToday > 0) Text(plainText(t.planRev(app.fmt(P.revToday))), style: hStyle),
          if (P.newToday > 0)
            Text('${P.revToday > 0 ? '+ ' : ''}${plainText(t.planNew(app.fmt(P.newToday)))}', style: hStyle.copyWith(color: P.revToday > 0 ? p.soft : p.fg)),
          const SizedBox(height: 3),
          Text(t.planMin(min), style: F.s(15, c: p.soft)),
        ],
      );
    } else {
      head = Text('${t.planDone} ✓', style: hStyle.copyWith(fontSize: big * .8));
    }
    app.syncWidget(todo ? '${P.revToday}·${P.newToday}' : t.planDone);
    app.syncReminder();
    final cc = math.min(c['cnt'] as int, c['n'] as int);
    final cDone = c['done'] == true;
    final cl = '${t.chalT}: ${cDone ? t.chalDone : '${t.chalTxt(app.skName(c['k'] as String), c['n'], c['a'])} · $cc/${c['n']}'}';
    final btn = MainBtn(
      tight ? (todo ? (P.ansT > 0 ? t.planContS : t.planGoS) : t.planExtraS) : (todo ? (P.ansT > 0 ? t.planCont : t.planGo) : t.planExtra),
      semantics: todo ? (P.ansT > 0 ? t.planCont : t.planGo) : t.planExtra,
      icon: I.play,
      wide: true,
      big: true,
      radius: 28,
      onTap: () => app.startSession(!todo),
    );
    Widget sub({required String label, required VoidCallback onTap, required Widget child}) => Expanded(
      child: Press(
        onTap: onTap,
        scale: .97,
        label: label,
        child: Glass(inner: true, radius: 22, height: 44, child: Center(child: child)),
      ),
    );
    final quick = todo && min >= 4;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(header: true, child: Text(t.planT, style: F.s(15, w: FontWeight.w700, c: p.soft))),
              const Spacer(),
              if (stT.isNotEmpty) ...[
                Dot(p.band(stK), size: 8),
                const SizedBox(width: 6),
                Flexible(child: Text(plainText(stT), maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(13, w: FontWeight.w700, c: p.soft))),
              ],
            ],
          ),
          SizedBox(height: tight ? 4 : 8),
          head,
          SizedBox(height: tight ? 10 : 16),
          if (tight)
            Row(
              children: [
                Expanded(child: btn),
                const SizedBox(width: 8),
                SizedBox(width: quick ? 112 : 64, child: Row(children: [
                  if (quick) ...[
                    sub(label: t.quickL, onTap: () => app.startSession(false, quick: true), child: Text('2′', style: F.s(15, w: FontWeight.w800, c: p.fg, feat: F.tab))),
                    const SizedBox(width: 6),
                  ],
                  sub(label: cl, onTap: () => app.go('soul'), child: Text('试', style: F.s(16, w: FontWeight.w900, family: F.hz, c: cDone ? p.good : (p.dark ? p.fg : th.acc)))),
                ])),
              ],
            )
          else ...[
          btn,
          const SizedBox(height: 10),
          Row(
            children: [
              if (quick) ...[
                sub(
                  label: t.quickL,
                  onTap: () => app.startSession(false, quick: true),
                  child: Text(t.quickS, maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(14, w: FontWeight.w700, c: p.fg)),
                ),
                const SizedBox(width: 10),
              ],
              sub(
                label: cl,
                onTap: () => app.go('soul'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('试', style: F.s(15, w: FontWeight.w900, family: F.hz, c: p.dark ? p.fg : th.acc)),
                    const SizedBox(width: 6),
                    Text(cDone ? '✓' : '$cc/${c['n']}', style: F.s(14, w: FontWeight.w800, c: cDone ? p.good : p.fg, feat: F.tab)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ],
          goal,
        ],
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
    final fg = pri ? (p.dark ? p.fg : p.onAcc) : p.fg;
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
          ? CustomPaint(
              painter: OuterShadow(
                th.low ? const [] : [BoxShadow(color: th.acc.withValues(alpha: .38), offset: const Offset(0, 10), blurRadius: 24, spreadRadius: -10)],
                22,
              ),
              child: Glass(
                inner: true,
                radius: 22,
                shadow: const [],
                color: Color.lerp(th.acc, Colors.black, p.dark ? .35 : .2)!.withValues(alpha: p.dark ? .5 : .78),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 40), child: child),
              ),
            )
          : Glass(
              solid: true,
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 40), child: child),
            ),
    );
  }
}

// ---------------------------------------------------------------- word mastery
/// word mastery in a sheet: the HSK lens to change the level, what the colours mean, this level's counts
void _masterySheet(BuildContext context) {
  openSheet(context, name: 'bands', (c) {
    final p = Th.pal(c);
    final t = app.t;
    final L = app.level;
    final S = app.summary(app.by(L));
    return SheetBody(
      title: t.masT,
      children: [
        LevelLens(level: L, onPick: app.setLevel),
        const SizedBox(height: 14),
        Lead(t.masHelp),
        for (final b in const ['green', 'yellow', 'red', 'none'])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Dot(p.band(b), size: 10),
                const SizedBox(width: 10),
                Expanded(child: Text(L10.text(t.band[b]), style: F.s(15, w: FontWeight.w700, c: p.fg))),
                Text(app.fmt(S.band(b)), style: F.s(15, w: FontWeight.w800, c: p.fg, feat: F.tab)),
              ],
            ),
          ),
      ],
    );
  });
}

/// word mastery on Home (the mockup): the share in big numbers beside the bar; a tap opens the sheet with the HSK
/// lens and the counts
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
    if (app.isNewbie() && short) return const SizedBox.shrink();
    return Press(
      onTap: () => _masterySheet(context),
      scale: .98,
      label: '${t.masT} · HSK $L · $pc',
      child: Glass(
        radius: 28,
        padding: short ? const EdgeInsets.fromLTRB(16, 10, 16, 12) : const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text(t.masT, maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(17, w: FontWeight.w800, c: p.fg))),
                ),
                Press(
                  onTap: () => app.go('stats'),
                  scale: 1.05,
                  label: '${t.stTitle} · HSK $L · $pc',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
                    child: Center(widthFactor: 1, child: Text('${t.statsShort} ›', style: F.s(15, w: FontWeight.w800, c: th.acc))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(pc, style: F.s(short ? 26 : 32, w: FontWeight.w700, c: p.fg, feat: F.tab, ls: -1, h: 1)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StackBar([
                        for (final b in const ['green', 'yellow', 'red']) (S.band(b) / math.max(1, S.n), p.band(b)),
                      ]),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(child: Text('HSK $L · ${t.words(app.fmt(S.n))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(14, c: p.soft))),
                          const SizedBox(width: 4),
                          Icon2(I.chev, size: 13, color: p.soft),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
