/// Soul Sea (识海, soul.js + soul-page.js): the realm, the soul orb, the five elements (五行), today's trial,
/// cultivation days, rest numbers, the realm history. Every number comes from the memory model and the answer log on
/// this phone (LM.soul, LM.challenge, LM.streak, LM.restGain).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/app.dart';
import '../app/runner.dart';
import '../data/words.dart';
import '../engine/fsrs.dart' as fsrs;
import '../engine/learn.dart';
import '../i18n/l10.dart';
import 'focus.dart';
import 'glass.dart';
import 'icons.dart';
import 'realm.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

// ---------------------------------------------------------------- the five elements
/// [element, hanzi, attribute] in the order of the rows (earth first: the realm's root)
const el5 = [
  ('earth', '土', 'root'),
  ('wood', '木', 'cult'),
  ('water', '水', 'sense'),
  ('metal', '金', 'dao'),
  ('fire', '火', 'insight'),
];

/// the wheel: clockwise from the top, along the generating cycle 木→火→土→金→水
const elWheel = [
  ('wood', '木', 'cult'),
  ('fire', '火', 'insight'),
  ('earth', '土', 'root'),
  ('metal', '金', 'dao'),
  ('water', '水', 'sense'),
];
const atz = {
  'root': ('根基', 'gēnjī'),
  'cult': ('修为', 'xiūwéi'),
  'sense': ('神识', 'shénshí'),
  'dao': ('道心', 'dàoxīn'),
  'insight': ('悟性', 'wùxìng'),
};
const ttl = {
  'root': ('磐石', 'pánshí'),
  'cult': ('苦修', 'kǔxiū'),
  'sense': ('明镜', 'míngjìng'),
  'dao': ('剑心', 'jiànxīn'),
  'insight': ('慧根', 'huìgēn'),
};
const elp = {'earth': 'tǔ', 'wood': 'mù', 'water': 'shuǐ', 'metal': 'jīn', 'fire': 'huǒ'};

Color elColor(Pal p, String k) => switch (k) {
  'wood' => p.elWood,
  'fire' => p.elFire,
  'earth' => p.elEarth,
  'metal' => p.elMetal,
  _ => p.elWater,
};

/// the weakest and the strongest element (none when fewer than two are known or all are equal)
(String?, String?) weakStrong(Json s) {
  final known = el5.where((e) => s[e.$3] != null).toList();
  if (known.length < 2) return (null, null);
  var lo = known[0], hi = known[0];
  for (final e in known.skip(1)) {
    if ((s[e.$3] as num) < (s[lo.$3] as num)) lo = e;
    if ((s[e.$3] as num) > (s[hi.$3] as num)) hi = e;
  }
  if (s[lo.$3] == s[hi.$3]) return (null, null);
  return (lo.$3, hi.$3);
}

/// the wheel's own order picks its weakest/strongest the same way (first found wins ties)
(String?, String?) weakStrongWheel(Json s) {
  final known = elWheel.where((e) => s[e.$3] != null).toList();
  if (known.length < 2) return (null, null);
  var lo = known[0], hi = known[0];
  for (final e in known.skip(1)) {
    if ((s[e.$3] as num) < (s[lo.$3] as num)) lo = e;
    if ((s[e.$3] as num) > (s[hi.$3] as num)) hi = e;
  }
  if (s[lo.$3] == s[hi.$3]) return (null, null);
  return (lo.$3, hi.$3);
}

// ---------------------------------------------------------------- the wheel
class WheelPainter extends CustomPainter {
  final Json s;
  final Pal p;
  WheelPainter(this.s, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, c = w / 2;
    final r = w * .405, tk = w * .09, gr = w * .056;
    final (lo, hi) = weakStrongWheel(s);
    final gap = math.asin((gr + w * .014) / r) * 180 / math.pi;
    final span = 72 - 2 * gap;
    final ro = r + tk / 2, ri = r - tk / 2;
    Offset pt(double a, double rr) => Offset(c + math.cos(a * math.pi / 180) * rr, c + math.sin(a * math.pi / 180) * rr);
    Path sector(double a0, double a1) {
      final rad = math.pi / 180;
      return Path()
        ..arcTo(Rect.fromCircle(center: Offset(c, c), radius: ro), a0 * rad, (a1 - a0) * rad, true)
        ..arcTo(Rect.fromCircle(center: Offset(c, c), radius: ri), a1 * rad, -(a1 - a0) * rad, false)
        ..close();
    }

    for (var i = 0; i < 5; i++) {
      final e = elWheel[i];
      final ec = elColor(p, e.$1);
      final v = s[e.$3] as num?;
      final a0 = -90 + i * 72 + gap, mid = a0 + span / 2;
      final trk = sector(a0, a0 + span);
      canvas.drawPath(trk, Paint()..color = ec.withValues(alpha: .13));
      if (v == null) {
        final dash = Paint()
          ..color = ec.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        _dashPath(canvas, trk, dash, 3, 3);
      }
      if (v != null && v > 0) {
        final val = sector(a0, a0 + span * math.max(.03, v / 100));
        canvas.drawPath(val, Paint()..color = ec.withValues(alpha: .82));
        canvas.drawPath(
          val,
          Paint()
            ..color = ec
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeJoin = StrokeJoin.round,
        );
      }
      final at = pt(mid, r);
      final txt = v == null ? '–' : '$v';
      final st = F.s(w * .042, w: FontWeight.w800);
      final outline = TextPainter(
        text: TextSpan(
          text: txt,
          style: st.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeJoin = StrokeJoin.round
              ..color = p.surface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fill = TextPainter(text: TextSpan(text: txt, style: st.copyWith(color: p.fg)), textDirection: TextDirection.ltr)..layout();
      final o = at - Offset(fill.width / 2, fill.height / 2);
      outline.paint(canvas, o);
      fill.paint(canvas, o);
    }
    for (var i = 0; i < 5; i++) {
      final e = elWheel[i];
      final ec = elColor(p, e.$1);
      final at = pt(-90.0 + i * 72, r);
      final weak = e.$3 == lo, strong = e.$3 == hi;
      final fillC = strong ? ec : (weak ? Color.alphaBlend(ec.withValues(alpha: .14), p.surface) : p.bg.withValues(alpha: .8));
      canvas.drawCircle(at, gr, Paint()..color = fillC);
      final stroke = Paint()
        ..color = ec
        ..style = PaintingStyle.stroke
        ..strokeWidth = weak ? 2.2 : 1.5;
      if (weak) {
        _dashPath(canvas, Path()..addOval(Rect.fromCircle(center: at, radius: gr)), stroke, 3, 2.5);
      } else {
        canvas.drawCircle(at, gr, stroke);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: e.$2,
          style: F.s(w * .052, w: FontWeight.w900, family: F.hz, c: strong ? p.surface : ec, h: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  static void _dashPath(Canvas c, Path path, Paint paint, double on, double off) {
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += on + off) {
        c.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(WheelPainter o) => o.p != p || !_same(o.s, s);
  static bool _same(Json a, Json b) => el5.every((e) => a[e.$3] == b[e.$3]);
}

// ---------------------------------------------------------------- the orb
/// The learner's word memory as a network on a sphere: one point per learned word (up to 900, the strongest), lines
/// between words that share a character, brightness = chance of recalling the word now, colour = its HSK level. The
/// core shows the realm (凡人 mist … 飞升 radiance), its size the stage. It turns slowly, can be spun with a finger
/// (it keeps the spin and slows down), eases to a stop after 10 s without a touch; reduced motion = still.
class SoulOrb extends StatefulWidget {
  final int realm, stage;
  final void Function(Word?) onPick;
  const SoulOrb({super.key, required this.realm, required this.stage, required this.onPick});
  @override
  State<SoulOrb> createState() => _SoulOrbState();
}

class _Node {
  final Word d;
  final double r, s;
  final int l;
  final bool flash;
  _Node(this.d, this.r, this.s, this.l, this.flash);
}

double _hash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 16777619) & 0xffffffff;
  }
  return h / 4294967296;
}

class _SoulOrbState extends State<SoulOrb> with SingleTickerProviderStateMixin {
  static const base = 0.00018;
  late final Ticker _ticker = createTicker(_frame);
  final _clock = Stopwatch()..start();
  final repaint = ValueNotifier<int>(0);
  List<_Node> nodes = [];
  late Float32List x, y, z, px, py, pz;
  Int32List edges = Int32List(0);
  double rot = 0, tilt = .38, vel = base, flash = 0;
  double? last;
  double idle = 0;
  bool dragging = false, moved = false;
  double vx = 0, lt = 0;
  double time = 0;
  List<Offset>? bolt;
  double boltUntil = 0;
  final rnd = math.Random();
  bool low = false;
  int built = -1;

  double get now => _clock.elapsedMicroseconds / 1000;

  void _build(bool lowFx) {
    final lm = app.lm;
    final t = lm.now();
    final list = <(Word, dynamic)>[];
    for (final d in app.vocab.data) {
      final e = lm.mem[d.id];
      if (e != null) list.add((d, e));
    }
    list.sort((a, b) => (b.$2.w[1] as double).compareTo(a.$2.w[1] as double));
    final keep = list.take(lowFx ? 450 : 900).toList()
      ..sort((a, b) => a.$1.l != b.$1.l ? a.$1.l - b.$1.l : a.$1.n - b.$1.n);
    final n = keep.length;
    final ga = math.pi * (3 - math.sqrt(5)), week = t - 7 * 1440;
    x = Float32List(n);
    y = Float32List(n);
    z = Float32List(n);
    px = Float32List(n);
    py = Float32List(n);
    pz = Float32List(n);
    nodes = [];
    for (var i = 0; i < n; i++) {
      final (d, e) = keep[i];
      final yy = n > 1 ? 1 - (2 * (i + .5)) / n : 0.0;
      final r = math.sqrt(1 - yy * yy);
      final th = i * ga + _hash(d.id) * .6;
      final mist = widget.realm == 0 ? .55 + .45 * _hash('${d.id}r') : 1.0;
      x[i] = math.cos(th) * r * mist;
      y[i] = yy * mist;
      z[i] = math.sin(th) * r * mist;
      final w = e.w as List<double>;
      final k = e.k as int?;
      nodes.add(
        _Node(
          d,
          fsrs.rt((t - w[2]) / 1440, w[1]),
          math.min(1, math.log(1 + w[1]) / math.log(121)),
          d.l,
          k != null && k > week,
        ),
      );
    }
    final byChar = <String, List<int>>{};
    for (var i = 0; i < n; i++) {
      for (final c in nodes[i].d.h.runes.map(String.fromCharCode).toSet()) {
        (byChar[c] ??= []).add(i);
      }
    }
    final deg = Uint8List(n);
    final e = <int>[];
    for (final a in byChar.values) {
      for (var k = 1; k < a.length && e.length < 1400; k++) {
        final i = a[k - 1], j = a[k];
        if (deg[i] < 3 && deg[j] < 3) {
          e
            ..add(i)
            ..add(j);
          deg[i]++;
          deg[j]++;
        }
      }
    }
    edges = Int32List.fromList(e);
    flash = nodes.any((q) => q.flash) ? 1 : 0;
    vel = base;
  }

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 330), () {
      if (mounted && !_reduce) _wake();
    });
  }

  @override
  void didUpdateWidget(SoulOrb o) {
    super.didUpdateWidget(o);
    if (o.realm != widget.realm) built = -1;
  }

  @override
  void dispose() {
    _ticker.dispose();
    repaint.dispose();
    super.dispose();
  }

  void _wake() {
    idle = now;
    if (!_ticker.isActive && !_reduce && mounted) {
      last = null;
      _ticker.start();
    }
  }

  void _frame(Duration _) {
    final t = now;
    final dt = last != null ? math.min(50.0, t - last!) : 16.0;
    last = t;
    final calm = dragging ? 0.0 : ((10000 - (t - idle)) / 2000).clamp(0.0, 1.0);
    if (!dragging) {
      vel += (base * calm - vel) * math.min(1, dt / 450);
      rot += vel * dt;
    }
    if (flash > 0) flash = math.max(0, flash - dt / 900);
    time = t;
    _bolt();
    repaint.value++;
    if (!(dragging || calm > 0 || vel.abs() > 2e-6 || flash > 0)) {
      _ticker.stop();
      last = null;
    }
  }

  Size _size = Size.zero;
  void _bolt() {
    if (widget.realm != 6 || _size.isEmpty) return;
    final cx = _size.width / 2, cy = _size.height / 2, r = _size.width * .44;
    if (bolt == null && rnd.nextDouble() < .006) {
      final a = rnd.nextDouble() * 6.28;
      var bx = cx + math.cos(a) * r * .95, by = cy + math.sin(a) * r * .95;
      final pts = <Offset>[];
      for (var k = 0; k < 7; k++) {
        pts.add(Offset(bx, by));
        bx += (cx - bx) * .18 + (rnd.nextDouble() - .5) * r * .18;
        by += (cy - by) * .18 + (rnd.nextDouble() - .5) * r * .18;
      }
      bolt = pts;
      boltUntil = time + 240;
    }
    if (bolt != null && time > boltUntil) bolt = null;
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    if (built != widget.realm * 2 + (th.low ? 1 : 0)) {
      built = widget.realm * 2 + (th.low ? 1 : 0);
      _build(th.low);
    }
    return LayoutBuilder(
      builder: (c, bc) {
        _size = Size(bc.maxWidth, bc.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (e) {
            dragging = true;
            moved = false;
            vx = 0;
            lt = now;
            _wake();
          },
          onPanUpdate: (e) {
            final dx = e.delta.dx, dy = e.delta.dy, t = now;
            if (dx.abs() + dy.abs() > 0) moved = true;
            rot += dx * .01;
            tilt = (tilt + dy * .006).clamp(-1.1, 1.1);
            vx = .7 * vx + .3 * ((dx * .01) / math.max(8, t - lt));
            lt = t;
            _wake();
            if (_reduce) repaint.value++;
          },
          onPanEnd: (e) {
            dragging = false;
            final v = (now - lt < 80 ? vx : 0.0).clamp(-.012, .012);
            vel = v == 0 ? base : v;
            _wake();
          },
          onPanCancel: () {
            dragging = false;
            vel = base;
            _wake();
          },
          onTapUp: (e) {
            dragging = false;
            vel = base;
            _wake();
            var best = -1;
            var bd = 16.0 * 16;
            for (var i = 0; i < nodes.length; i++) {
              if (pz[i] < 0) continue;
              final q = math.pow(px[i] - e.localPosition.dx, 2) + math.pow(py[i] - e.localPosition.dy, 2);
              if (q < bd) {
                bd = q.toDouble();
                best = i;
              }
            }
            widget.onPick(best >= 0 ? nodes[best].d : null);
          },
          child: Semantics(
            image: true,
            label: app.t.orbL(app.fmt(nodes.length)),
            child: RepaintBoundary(
              child: CustomPaint(
                size: _size,
                painter: _OrbPainter(this, th.p, th.acc, widget.realm, widget.stage),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final _SoulOrbState s;
  final Pal p;
  final Color acc;
  final int realm, stage;
  _OrbPainter(this.s, this.p, this.acc, this.realm, this.stage) : super(repaint: s.repaint);

  static const ab = [.14, .3, .5, .72, .95];

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, cx = w / 2, cy = size.height / 2, r = w * .44;
    final ca = math.cos(s.rot), sa = math.sin(s.rot), ct = math.cos(s.tilt), st = math.sin(s.tilt);
    final n = s.nodes.length;
    final alpha = Float32List(n);
    for (var i = 0; i < n; i++) {
      final x = s.x[i] * ca + s.z[i] * sa, z1 = -s.x[i] * sa + s.z[i] * ca;
      final y = s.y[i] * ct - z1 * st, z = s.y[i] * st + z1 * ct;
      s.px[i] = cx + x * r;
      s.py[i] = cy + y * r;
      s.pz[i] = z;
      final a = (.18 + .82 * s.nodes[i].r) * (.3 + (.7 * (z + 1)) / 2);
      var k = 0;
      while (k < ab.length - 1 && a > (ab[k] + ab[k + 1]) / 2) {
        k++;
      }
      alpha[i] = ab[k];
    }
    _half(c, false, alpha);
    _core(c, cx, cy, r);
    _half(c, true, alpha);
    if (s.flash > 0) {
      final pn = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var i = 0; i < n; i++) {
        if (!s.nodes[i].flash || s.pz[i] < 0) continue;
        pn.color = p.l(s.nodes[i].l).withValues(alpha: .6 * s.flash);
        c.drawCircle(Offset(s.px[i], s.py[i]), 3 + 5 * (1 - s.flash), pn);
      }
    }
    final b = s.bolt;
    if (realm == 6 && b != null) {
      c.drawPoints(
        ui.PointMode.polygon,
        b,
        Paint()
          ..color = const Color.fromRGBO(205, 190, 255, .85)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _half(Canvas c, bool front, Float32List alpha) {
    final e = s.edges;
    final pts = <Offset>[];
    for (var k = 0; k < e.length; k += 2) {
      final i = e[k], j = e[k + 1];
      if ((s.pz[i] + s.pz[j] >= 0) != front) continue;
      pts
        ..add(Offset(s.px[i], s.py[i]))
        ..add(Offset(s.px[j], s.py[j]));
    }
    if (pts.isNotEmpty) {
      c.drawPoints(
        ui.PointMode.lines,
        pts,
        Paint()
          ..color = p.fg.withValues(alpha: front ? (p.dark ? .16 : .12) : (p.dark ? .07 : .05))
          ..strokeWidth = .7,
      );
    }
    final pn = Paint();
    for (var i = 0; i < s.nodes.length; i++) {
      if ((s.pz[i] >= 0) != front) continue;
      final dep = (s.pz[i] + 1) / 2;
      final rr = (.9 + 1.9 * s.nodes[i].s) * (.7 + .5 * dep);
      pn.color = p.l(s.nodes[i].l).withValues(alpha: alpha[i]);
      c.drawCircle(Offset(s.px[i], s.py[i]), rr, pn);
    }
  }

  void _core(Canvas c, double cx, double cy, double r) {
    final k = .75 + .09 * stage;
    final o = Offset(cx, cy);
    final time = s.time;
    void glow(double r0, double r1, Color col, double a) {
      c.drawCircle(
        o,
        r1,
        Paint()
          ..shader = ui.Gradient.radial(o, r1, [col.withValues(alpha: a), col.withValues(alpha: 0)], [r0 / r1, 1]),
      );
    }

    if (realm == 0) {
      glow(0, r * .5, p.fg, .1);
      return;
    }
    if (realm >= 5) glow(r * .2, r * 1.35, acc, .22);
    if (realm >= 7) {
      final nr = 12 + 4 * (realm - 7);
      c.save();
      c.translate(cx, cy);
      c.rotate(time / 9000);
      final path = Path();
      for (var i = 0; i < nr; i++) {
        final a = 2 * math.pi * (i + 1) / nr;
        final ca = math.cos(a), sa = math.sin(a);
        Offset rt(double x, double y) => Offset(x * ca - y * sa, x * sa + y * ca);
        path
          ..moveTo(rt(0, -2).dx, rt(0, -2).dy)
          ..lineTo(rt(r * 1.3, -.5).dx, rt(r * 1.3, -.5).dy)
          ..lineTo(rt(r * 1.3, .5).dx, rt(r * 1.3, .5).dy)
          ..lineTo(rt(0, 2).dx, rt(0, 2).dy)
          ..close();
      }
      c.drawPath(path, Paint()..color = realm >= 10 ? const Color.fromRGBO(255, 236, 170, .3) : const Color.fromRGBO(255, 240, 190, .22));
      c.restore();
    }
    glow(0, r * .55 * k, realm >= 3 ? const Color(0xFFFFD76A) : acc, .55);
    if (realm >= 2) {
      c.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + r * .32), width: r * .84 * k, height: r * .18 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = realm >= 3 ? const Color.fromRGBO(214, 170, 70, .75) : acc.withValues(alpha: .6),
      );
    }
    if (realm >= 3) {
      final pulse = realm >= 4 ? 1 + .05 * math.sin(time / 500) : 1.0;
      final rr = r * .16 * k * pulse;
      c.drawCircle(
        o,
        rr,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx - rr * .3, cy - rr * .3),
            rr,
            const [Color(0xFFFFF3C4), Color(0xFFFFD76A), Color(0xFFC9922B)],
            const [.1, .45, 1],
            TileMode.clamp,
            null,
            o,
            rr * .1,
          ),
      );
    }
    if (realm >= 4) c.drawCircle(o, r * .055 * k, Paint()..color = const Color.fromRGBO(255, 255, 255, .9));
    if (realm == 1 || realm == 2) {
      final pn = Paint()..color = acc.withValues(alpha: .8);
      for (var i = 0; i < 3; i++) {
        final a = time / 1400 + i * 2.1, rr = r * (.3 + .06 * i);
        c.drawCircle(Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr * .45), 2.2, pn);
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter o) => o.p != p || o.acc != acc || o.realm != realm || o.stage != stage;
}

// ---------------------------------------------------------------- the page
class SoulScreen extends StatefulWidget {
  const SoulScreen({super.key});
  @override
  State<SoulScreen> createState() => _SoulScreenState();
}

class _SoulScreenState extends State<SoulScreen> {
  Word? picked;
  bool pickedAny = false;
  final _scroll = ScrollController();
  int _top = app.scrollTop;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    if (_top != app.scrollTop) {
      _top = app.scrollTop;
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    final r = lm.realm();
    final st = lm.stage();
    final s = lm.soul();
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900 && size.height >= 540 && size.width > size.height;
    final hero = _hero(context, r, st?.i ?? 0, s);
    final cards = <Widget>[
      _Card(
        children: [
          Shd('修炼之路', 'xiūliàn zhī lù', t.pathM, top: 0),
          RealmPath(r),
          StageBox(r),
          const TestBtns(note: false),
        ],
      ),
      _Card(
        children: [
          Shd('指点', 'zhǐdiǎn', t.advM, top: 0),
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Rich(t.advIntro, style: F.s(12, c: p.soft, h: 1.45))),
          const AdviceList(max: 6),
        ],
      ),
      _Card(children: [Shd('五行', 'wǔxíng', t.elM, top: 0), ..._elRows(context, s)]),
      _challenge(context),
      _streak(context),
      _rest(context),
      _history(context, r),
    ];
    final head = Capsule(
      title: t.soulT,
      onBack: () => app.go('home'),
      trailing: [
        CapBtn(label: t.shareL, onTap: () => app.openShare?.call(context), child: Icon2(I.share, size: 19, color: p.fg)),
        CapBtn(
          label: t.helpT,
          onTap: () => app.openInfo?.call(context, 'soul'),
          child: Text('?', style: F.s(17, w: FontWeight.w800, c: p.fg)),
        ),
      ],
    );
    final bottom = pad.bottom + 96;
    if (wide) {
      return Padding(
        padding: EdgeInsets.fromLTRB(22, pad.top + 10, 22, 0),
        child: Column(
          children: [
            head,
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(padding: EdgeInsets.only(bottom: bottom), child: hero)),
                  const SizedBox(width: 22),
                  Expanded(
                    child: ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.only(bottom: bottom),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => cards[i],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, bottom),
      children: [
        head,
        const SizedBox(height: 12),
        hero,
        for (final c in cards) ...[const SizedBox(height: 12), c],
      ],
    );
  }

  Widget _hero(BuildContext context, int r, int stage, Json s) {
    final p = Th.pal(context);
    final t = app.t;
    final lc = rcol(context, r);
    final d = picked;
    Widget pick;
    if (d != null) {
      pick = Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: [
          Hz(d, size: 18, weight: FontWeight.w900, family: F.hz),
          Py(d, size: 13),
          Text('· ${app.m1(d)} ·', style: F.s(13, c: p.soft)),
          LevelLine(d),
        ],
      );
    } else {
      pick = Text(
        (s['words'] as num) > 0 ? t.orbHint : t.orbEmpty,
        textAlign: TextAlign.center,
        style: F.s(13, c: p.soft, h: 1.5),
      );
    }
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (c, bc) {
                  final w = bc.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: w * .22,
                        top: w * .22,
                        width: w * .56,
                        height: w * .56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [lc.withValues(alpha: .18), lc.withValues(alpha: 0)], stops: const [0, .7]),
                          ),
                        ),
                      ),
                      Positioned.fill(child: ExcludeSemantics(child: CustomPaint(painter: WheelPainter(s, p)))),
                      Positioned(
                        left: w * .23,
                        top: w * .23,
                        width: w * .54,
                        height: w * .54,
                        child: ClipOval(
                          child: SoulOrb(
                            realm: r,
                            stage: stage,
                            onPick: (w) => setState(() => picked = w),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        RealmHead(r, big: true),
        Semantics(
          liveRegion: true,
          child: Padding(padding: const EdgeInsets.only(top: 4), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 20), child: pick)),
        ),
      ],
    );
  }

  List<Widget> _elRows(BuildContext context, Json s) {
    final p = Th.pal(context);
    final t = app.t;
    final (lo, hi) = weakStrong(s);
    final out = <Widget>[];
    for (var i = 0; i < el5.length; i++) {
      final (k, g, a) = el5[i];
      final ec = elColor(p, k);
      final v = s[a] as num?;
      final weak = a == lo, strong = a == hi && v != null && v >= 60;
      final val = v == null
          ? t.unknownV
          : a == 'cult'
          ? t.cultV(app.fmt(s['cultDays'] as num))
          : a == 'insight'
          ? t.insightV(s['insightDays'])
          : '$v%';
      final stg = a == 'root' ? app.lm.stage(s['L'] as int) : null;
      final x = v == null
          ? ''
          : a == 'root' && stg != null
          ? L10.text(t.attrX['root'], [app.fmt(stg.solid), app.fmt(stg.test), app.fmt(stg.total)])
          : a == 'sense'
          ? L10.text(t.attrX['sense'], [app.fmt(s['senseN'] as num), app.fmt(s['senseOf'] as num), s['L']])
          : a == 'dao'
          ? L10.text(t.attrX['dao'], [app.fmt(s['daoOk'] as num), app.fmt(s['daoN'] as num)])
          : '';
      final emC = Color.lerp(ec, p.fg, .28)!;
      out.add(
        Container(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 9, bottom: 9),
          decoration: i == 0 ? null : BoxDecoration(border: Border(top: BorderSide(color: p.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ec.withValues(alpha: .15)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(g, style: F.s(16, w: FontWeight.w900, family: F.hz, c: ec, h: 1)),
                      const SizedBox(height: 2),
                      Text(elp[k]!, style: F.s(9, w: FontWeight.w700, c: ec, h: 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(atz[a]!.$1, style: F.s(15, w: FontWeight.w900, family: F.hz, c: p.fg)),
                        const SizedBox(width: 5),
                        Text(atz[a]!.$2, style: F.s(11.5, w: FontWeight.w600, c: p.soft)),
                        const SizedBox(width: 7),
                        Expanded(child: Text(L10.text(t.attrN[a]), style: F.s(13, w: FontWeight.w700, c: p.fg))),
                        Text(
                          val,
                          style: v == null
                              ? F.s(12, w: FontWeight.w600, c: p.mute)
                              : F.s(13, w: FontWeight.w800, c: emC, feat: F.tab),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 6,
                          color: p.sunk,
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: v == null ? 0 : math.max(2, v.toDouble()) / 100,
                            heightFactor: 1,
                            child: DecoratedBox(decoration: BoxDecoration(color: ec, borderRadius: BorderRadius.circular(99))),
                          ),
                        ),
                      ),
                    ),
                    Text(L10.text(t.attrD[a]), style: F.s(12, c: p.soft, h: 1.4)),
                    if (x.isNotEmpty) Text(x, style: F.s(12, w: FontWeight.w700, c: p.fg, h: 1.4)),
                    if (weak)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(L10.text(t.attrTip[a]), style: F.s(12.5, w: FontWeight.w700, c: ec, h: 1.45)),
                      ),
                    if (strong)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Rich(
                          t.titleL('${ttl[a]!.$1} ${ttl[a]!.$2} · ${L10.text(t.attrTitle[a])}'),
                          style: F.s(12.5, w: FontWeight.w800, c: p.fg, h: 1.45),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  Widget _challenge(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final c = app.lm.challenge();
    final n = (c['n'] as num).toInt(), cnt = (c['cnt'] as num).toInt();
    final done = c['done'] == true;
    final total = (c['total'] as num?) ?? 0;
    return _Card(
      children: [
        DefaultTextStyle.merge(
          style: TextStyle(color: done ? p.good : null),
          child: Shd('今日试炼', 'jīnrì shìliàn', t.chalM, top: 0),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Rich(t.chalTxt(app.skName(c['k'] as String), n, c['a']), style: F.s(14, w: FontWeight.w700, c: p.fg, h: 1.4)),
        ),
        SkRow(
          label: Text('${math.min(cnt, n)}/$n', style: F.s(12.5, c: p.fg, feat: F.tab)),
          frac: cnt / n,
          color: th.acc,
          value: cnt > 0 ? '${c['acc']}%' : '–',
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Rich('${done ? t.chalDone : t.chalWhy}${total != 0 ? ' · ${t.chalTot(total)}' : ''}', style: F.s(12, c: p.soft, h: 1.45)),
        ),
        if (!done) ...[
          const SizedBox(height: 10),
          GhostBtn(
            t.chalGo,
            wide: true,
            onTap: () {
              app.runner.pending = Pending('quiz', app.lm.quizRound(app.pool(), roundQ, c['k'] as String));
              app.go('quiz');
            },
          ),
        ],
      ],
    );
  }

  Widget _streak(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final k = lm.streak();
    final days = lm.studyDays();
    final today = lm.dayOf(lm.now());
    final rest = lm.rest;
    return _Card(
      children: [
        Shd('修炼天数', 'xiūliàn tiānshù', t.strM, top: 0),
        Rich(t.strDays(k.days), style: F.s(22, w: FontWeight.w800, c: p.fg, feat: F.tab)),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              for (var d = today - 6; d <= today; d++)
                Expanded(child: _Day(lm.weekday(d), days.contains(d) ? 'on' : (lm.isRest(d) ? 'rest' : (d == today ? 'today' : 'off')))),
            ],
          ),
        ),
        Rich(t.strNote, style: F.s(12, c: p.soft, h: 1.45)),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              rest.isNotEmpty ? t.medDays(App.wk.where(rest.contains).map((w) => app.wkName(w, long: true)).join(', ')) : t.medNone,
              style: F.s(12, c: p.soft, h: 1.45),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => app.openGoal?.call(context, false, 'rest'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    t.medSet,
                    style: F.s(12, w: FontWeight.w800, c: th.acc).copyWith(decoration: TextDecoration.underline, decorationColor: th.acc),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rest(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final g = app.lm.restGain();
    String f(double x) => x < 10 ? app.fmt1(x) : app.fmt(x.round());
    if (g == null) {
      return _Card(children: [Shd('休息之道', 'xiūxi zhī dào', t.restM, top: 0), Rich(t.restEmpty, style: F.s(12, c: p.soft, h: 1.45))]);
    }
    final mx = [g.now, g.day, g.two].reduce(math.max);
    final m = mx == 0 ? 1.0 : mx;
    return _Card(
      children: [
        Shd('休息之道', 'xiūxi zhī dào', t.restM, top: 0),
        Rich(t.restWhy(f(g.S)), style: F.s(13, c: p.soft, h: 1.45)),
        const SizedBox(height: 8),
        for (final (n, v) in [(t.restNow, g.now), (t.restDay, g.day), (t.restTwo, g.two)])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SkRow(
              label: SizedBox(width: 92, child: Text(n, style: F.s(12.5, c: p.fg))),
              frac: math.max(.02, v / m),
              color: p.elWater,
              value: '+${f(v)}',
              valueW: 52,
            ),
          ),
        Rich(t.restNote, style: F.s(12, c: p.soft, h: 1.45)),
      ],
    );
  }

  Widget _history(BuildContext context, int r) {
    final p = Th.pal(context);
    final t = app.t;
    final info = app.lm.lvInfo;
    final h0 = info?['hist'];
    var hist = h0 is List ? h0.whereType<List>().toList() : <List>[];
    if (hist.isEmpty && info != null && info['src'] == 'test') {
      hist = [
        [r, info['at']],
      ];
    }
    hist = hist.reversed.toList();
    final per = info?['per'];
    return _Card(
      children: [
        Shd('境界历程', 'jìngjiè lìchéng', t.histM, top: 0),
        if (hist.isEmpty)
          Rich(t.histEmpty, style: F.s(12, c: p.soft, h: 1.45))
        else
          for (final e in hist)
            Builder(
              builder: (c) {
                final hr = (e[0] as num).toInt();
                final g = e.length > 3 && e[3] is num ? (e[3] as num).toInt() : 0;
                final how = e.length > 2 ? e[2] : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 42,
                        child: Text(app.rn[hr], style: F.s(17, w: FontWeight.w900, family: F.hz, c: rcol(c, hr))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            Text(app.rpy[hr], style: F.s(11.5, w: FontWeight.w600, c: p.soft)),
                            Text(L10.text(t.realmM[hr]), style: F.s(13, c: p.fg)),
                            if (g > 0) GradeBadge(g) else if (how == 'test') const Recog(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(app.dateS(app.tDate(e[1] as num)), style: F.s(12, c: p.soft)),
                    ],
                  ),
                );
              },
            ),
        if (per is List) ...[
          const SizedBox(height: 8),
          Text(t.ptPer.toUpperCase(), style: F.s(11.5, w: FontWeight.w800, c: p.soft, ls: .6)),
          const SizedBox(height: 6),
          PerBars(per),
        ],
      ],
    );
  }
}

/// the placement test's share known per HSK level
class PerBars extends StatelessWidget {
  final List per;
  const PerBars(this.per, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Column(
      children: [
        for (var i = 0; i < per.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SkRow(
              label: Text('HSK ${i + 1}', style: F.s(12.5, c: p.fg)),
              frac: (per[i] as num) / 100,
              color: p.l(i + 1),
              value: '${per[i]}%',
            ),
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  final int w;
  final String c; // on rest today off
  const _Day(this.w, this.c);
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final circle = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c == 'on' ? th.acc : (c == 'rest' ? p.elWater.withValues(alpha: .14) : null),
        border: c == 'today' ? null : Border.all(color: c == 'on' ? th.acc : (c == 'rest' ? p.elWater : p.line), width: 2),
      ),
      child: c == 'rest' ? Text('闭', style: F.s(11, w: FontWeight.w900, family: F.hz, c: p.elWater, h: 1)) : null,
    );
    return Column(
      children: [
        c == 'today' ? DashedBox(color: th.acc, radius: 12, width: 2, child: circle) : circle,
        const SizedBox(height: 3),
        Text(app.wkName(w), maxLines: 1, style: F.s(11, c: p.soft)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Glass(
    radius: 26,
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}
