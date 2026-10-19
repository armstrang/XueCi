/// The cultivation card (share.js): a picture of where the learner is, to share. 1080 × 1350 (4:5, shown whole by
/// most apps), always the dark ink look with the realm's colour and gold. Only the learner's own realm is drawn. The
/// picture is made on the phone and goes only to the app the learner picks (Android's share sheet).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app/app.dart';
import '../app/native.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'sheet.dart';
import 'soul.dart' show el5;
import 'theme.dart';
import 'widgets.dart';

Color _hex(String h) => Color(int.parse('ff${h.substring(1)}', radix: 16));

const _ink = Color(0xFFF4F6FA);
const _gold = Color(0xFFE6C36A);

/// paints the card; returns PNG bytes
Future<Uint8List> drawCard() async {
  const w = 1080.0, h = 1350.0;
  final t = app.t;
  final lm = app.lm;
  final r = lm.realm();
  final lv = r < 1 ? lm.baseLevel() : lm.realmLevel(r);
  final st = lm.stage(r < 1 ? lv : r);
  final s = lm.soul();
  final k = lm.streak();
  final p = app.realmPct(r);
  final col = _hex(app.cardColour(r));
  final rec = ui.PictureRecorder();
  final g = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));

  g.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), const [Color(0xFF121B29), Color(0xFF06090E)]),
  );
  void glow(double x, double y, double rad, Color c, double a) => g.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.radial(Offset(x, y), rad, [c.withValues(alpha: a), c.withValues(alpha: 0)]),
  );
  glow(540, 560, 620, col, .3);
  glow(120, 1240, 520, _gold, .12);
  final faint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color.fromRGBO(255, 255, 255, .05);
  for (final rad in [330.0, 400.0, 480.0]) {
    g.drawCircle(const Offset(540, 560), rad, faint);
  }

  TextPainter tp(String s, TextStyle st) => TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
  /// draws text with its baseline at y; align: -1 left, 0 centre, 1 right; returns the width
  double text(String s, TextStyle st, double x, double y, {int align = 0}) {
    final q = tp(s, st);
    final base = q.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = align < 0 ? x : (align == 0 ? x - q.width / 2 : x - q.width);
    q.paint(g, Offset(dx, y - base));
    return q.width;
  }

  TextStyle tx(double size, FontWeight wt, Color c, {double? ls}) => F.s(size, w: wt, c: c, ls: ls, h: 1);
  TextStyle hz(double size, Color c, {List<Shadow>? sh}) =>
      F.s(size, w: FontWeight.w900, family: F.hz, c: c, h: 1).copyWith(shadows: sh);
  TextStyle fit(String s, FontWeight wt, double size, double max, Color c) {
    var z = size;
    var st = tx(z, wt, c);
    while (tp(s, st).width > max && (z -= 2) > 24) {
      st = tx(z, wt, c);
    }
    return st;
  }

  // the wordmark and the date
  final xw = text('Xue', tx(54, FontWeight.w800, _ink), 80, 120, align: -1);
  text('Ci', tx(54, FontWeight.w800, const Color(0xFF6DBBEA)), 80 + xw, 120, align: -1);
  text('MANDARIN', tx(20, FontWeight.w800, _gold, ls: 7), 82, 154, align: -1);
  final today = lm.dayDate(lm.today());
  text(DateFormat.yMMMd(app.intlLoc).format(today), tx(26, FontWeight.w500, _ink.withValues(alpha: .62)), w - 80, 120, align: 1);

  // the ring: track, then the realm's progress from gold into the realm's colour
  const cx = 540.0, cy = 560.0, rr = 250.0;
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 22
    ..strokeCap = StrokeCap.round
    ..color = const Color.fromRGBO(255, 255, 255, .1);
  g.drawCircle(const Offset(cx, cy), rr, ring);
  if (r > 0 && p > 0) {
    final a1 = math.pi * 2 * math.min(100, p) / 100;
    final rect = Rect.fromCircle(center: const Offset(cx, cy), radius: rr);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(const Offset(cx - rr, cy + rr), const Offset(cx + rr, cy - rr), [_gold, col]);
    g.drawArc(
      rect,
      -math.pi / 2,
      a1,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..color = col.withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    g.drawArc(rect, -math.pi / 2, a1, false, arc);
  }

  // inside the ring: the realm in hanzi, its pinyin, the progress
  final name = app.rn[r];
  text(name, hz(name.length > 2 ? 120 : 150, col, sh: [Shadow(color: col, blurRadius: 30)]), cx, cy + 20);
  text(app.rpy[r], tx(34, FontWeight.w500, _ink.withValues(alpha: .72)), cx, cy + 82);
  text(r > 0 ? '$p%' : t.chipTest, tx(58, FontWeight.w400, _ink), cx, cy + 160);

  // under the ring: what the realm means, its level and the stage
  final mean = L10.text(t.realmM[r]) + (r > 0 ? ' · ${app.realmHSK(r)}' : '');
  text(mean, fit(mean, FontWeight.w800, 54, w - 140, _ink), cx, 905);
  if (st != null && r > 0) {
    final sn = App.sn[st.i], nm = L10.text(t.stageM[st.i]);
    final w1 = tp(sn, hz(34, col)).width;
    final nmSt = fit(nm, FontWeight.w500, 34, w - 220 - w1, _ink.withValues(alpha: .72));
    final w2 = tp(nm, nmSt).width;
    final x0 = cx - (w1 + 14 + w2) / 2;
    text(sn, hz(34, col), x0, 960, align: -1);
    text(nm, nmSt, x0 + w1 + 14, 960, align: -1);
  }

  // three numbers
  final nums = [
    (app.fmt(k.days), t.cardDays),
    (st != null ? '${app.fmt(st.solid)}/${app.fmt(st.total)}' : '–', t.cardSolid(lv)),
    (app.fmt(s['words'] as num), t.cardWords),
  ];
  for (var i = 0; i < 3; i++) {
    final x = 200.0 + i * 340;
    text(nums[i].$1, fit(nums[i].$1, FontWeight.w800, 64, 300, i == 1 ? col : _ink), x, 1105);
    text(nums[i].$2, fit(nums[i].$2, FontWeight.w500, 26, 300, _ink.withValues(alpha: .62)), x, 1148);
  }
  final sep = Paint()..color = const Color.fromRGBO(255, 255, 255, .08);
  g.drawRect(const Rect.fromLTWH(370, 1060, 2, 100), sep);
  g.drawRect(const Rect.fromLTWH(710, 1060, 2, 100), sep);

  // the five elements as five small seals along the bottom
  const ec = {'wood': '#62c983', 'fire': '#ff7a66', 'earth': '#e2b75a', 'metal': '#c3cad6', 'water': '#6aa8f0'};
  for (var i = 0; i < 5; i++) {
    final (k2, h2, a) = el5[i];
    final x = cx + (i - 2) * 76, y = 1250.0;
    final v = s[a] as num?;
    final al = v == null ? .35 : .35 + .65 * (v / 100);
    final c = _hex(ec[k2]!).withValues(alpha: al);
    g.drawCircle(
      Offset(x, y),
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c,
    );
    text(h2, hz(26, c), x, y + 9);
  }
  text('XueCi Mandarin', tx(22, FontWeight.w500, _ink.withValues(alpha: .45)), cx, 1318);

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

void openShareSheet(BuildContext context) {
  final png = drawCard();
  openSheet(context, name: 'share', (c) {
    final p = Th.pal(c);
    final t = app.t;
    final r = app.lm.realm();
    return SheetBody(
      title: t.shareT,
      children: [
        FutureBuilder<Uint8List>(
          future: png,
          builder: (c, snap) => AspectRatio(
            aspectRatio: 1080 / 1350,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: snap.hasData
                  ? Image.memory(
                      snap.data!,
                      fit: BoxFit.contain,
                      semanticLabel: '${app.rn[r]} ${app.rpy[r]} · ${L10.text(t.realmM[r])}',
                    )
                  : ColoredBox(color: const Color(0xFF0C121C), child: Center(child: CircularProgressIndicator(color: _gold.withValues(alpha: .7)))),
            ),
          ),
        ),
        const SizedBox(height: 14),
        MainBtn(
          t.shareGo,
          wide: true,
          onTap: () async {
            final bytes = await png;
            final ok = await Native.I.shareImage(bytes, t.shareTxt(app.rn[r], L10.text(t.realmM[r]), app.realmHSK(r)));
            if (!ok) app.toast(t.shareFail);
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 10), child: Text(t.shareNote, style: F.s(12, c: p.soft, h: 1.45))),
      ],
    );
  });
}
