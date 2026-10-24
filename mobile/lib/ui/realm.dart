/// The realm sheet and the pieces the Soul Sea shares with it: the realm's name, the path
/// of the realms, progress inside the realm, the tests, the stabilising trial and the guidance (指点).
/// The realm changes only through a test: the placement test, or a breakthrough (突破) once the stage is 圆满.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/runner.dart';
import '../engine/learn.dart';
import '../engine/model.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'run_view.dart' show tName;
import 'sheet.dart';
import 'theme.dart';
import 'widgets.dart';

Color rcol(BuildContext c, int r) => Th.pal(c).realm(r, band: app.band);

/// 筑基 zhùjī · Foundation · HSK 2
class RealmHead extends StatelessWidget {
  final int r;
  final bool big;
  const RealmHead(this.r, {super.key, this.big = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final lc = rcol(context, r);
    return Semantics(
      container: true,
      label: '${app.rn[r]} ${app.rpy[r]}, ${L10.text(t.realmM[r])}${r > 0 ? ', ${app.realmHSK(r)}' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(left: (big ? 46 : 36) * .1),
                child: Text(
                  app.rn[r],
                  style: F.s(big ? 46 : 36, w: FontWeight.w900, family: F.hz, c: lc, h: 1.15, ls: (big ? 46 : 36) * .1),
                ),
              ),
              Text(app.rpy[r], style: F.s(12.5, c: p.soft, ls: 1)),
              const SizedBox(height: 1),
              Text(
                '${L10.text(t.realmM[r])}${r > 0 ? ' · ${app.realmHSK(r)}' : ''}',
                textAlign: TextAlign.center,
                style: F.s(14, w: FontWeight.w800, c: p.fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// how a passed realm was reached: broken through (with the foundation's quality) or recognised by the placement test
Widget? realmHow(BuildContext context, int i, int r) {
  if (i < 1 || i > r) return null;
  final p = Th.pal(context);
  final t = app.t;
  final g = app.lm.grades()[i] ?? 0;
  if (g > 0) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [GradeBadge(g), Text(L10.text(t.gradeM[g]), style: F.s(12.5, c: p.soft))],
    );
  }
  final h = app.lm.lvInfo?['hist'];
  final hist = h is List ? h.whereType<List>().toList() : const <List>[];
  final byTest = hist.any((e) => e.length > 2 && e[2] == 'test' && (e[0] as num) >= i) &&
      !hist.any((e) => e.length > 2 && e[2] == 'bt' && e[0] == i);
  if (!byTest) return null;
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    children: [const Recog(), Text(t.recog, style: F.s(12.5, c: p.soft))],
  );
}

/// 认定: a realm recognised by the placement test
class Recog extends StatelessWidget {
  const Recog({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return CustomPaint(
      painter: _Dashed(p.line, 999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Text('认定', style: F.s(12.5, w: FontWeight.w900, family: F.hz, c: p.soft)),
      ),
    );
  }
}

class _Dashed extends CustomPainter {
  final Color c;
  final double r;
  final double width;
  _Dashed(this.c, this.r, {this.width = 1});
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r.clamp(0, s.shortestSide / 2)));
    final path = Path()..addRRect(rr.deflate(width / 2));
    final paint = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed o) => o.c != c || o.r != r || o.width != width;
}

/// a dashed rounded box (the unstable-realm card, the weakest element's badge)
class DashedBox extends StatelessWidget {
  final Color color;
  final double radius;
  final double width;
  final Widget child;
  const DashedBox({super.key, required this.color, required this.radius, this.width = 1.5, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Dashed(color, radius, width: width), child: child);
}

/// the path of the realms: passed ones filled, the current one ringed; tap any to read its name, pinyin and meaning.
/// Before the gate is open the path simply ends at 飞升: nothing hints that there is more.
class RealmPath extends StatefulWidget {
  final int r;
  const RealmPath(this.r, {super.key});
  @override
  State<RealmPath> createState() => _RealmPathState();
}

class _RealmPathState extends State<RealmPath> {
  int? pick;
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final th = Th.of(context);
    final t = app.t;
    final r = widget.r;
    final top = app.topR;
    final long = top > 7;
    final sz = long ? 22.0 : 28.0;
    final grades = app.lm.grades();
    final row = <Widget>[];
    for (var i = 0; i <= top; i++) {
      final lc = rcol(context, i);
      if (i > 0) {
        row.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: i <= r ? th.acc.withValues(alpha: .6) : p.line,
            ),
          ),
        );
      }
      final done = i < r, cur = i == r, pressed = (pick ?? r) == i;
      Widget node = Container(
        width: sz,
        height: sz,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cur ? lc : (p.dark ? Colors.black.withValues(alpha: .35) : (done ? lc.withValues(alpha: .07) : Colors.transparent)),
          border: Border.all(color: cur || done ? lc : Color.lerp(p.line, lc, .45)!, width: 1.5),
          boxShadow: [
            if (cur) BoxShadow(color: lc.withValues(alpha: .25), spreadRadius: 3),
            if (grades[i] == 4) BoxShadow(color: p.gold.withValues(alpha: .7), spreadRadius: 2),
          ],
        ),
        child: Text(
          app.rs[i],
          style: F.s(long ? 11 : 13, w: FontWeight.w900, family: F.hz, c: cur ? Pal.on(lc) : (done ? (p.dark ? Color.lerp(lc, Colors.white, .25)! : lc) : p.soft), h: 1),
        ),
      );
      if (cur) node = Transform.scale(scale: long ? 1.12 : 1.16, child: node);
      if (pressed && !cur) {
        node = Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: lc, width: 2)),
          child: node,
        );
      }
      row.add(
        Semantics(
          button: true,
          selected: pressed,
          label: '${app.rn[i]} ${app.rpy[i]}, ${L10.text(t.realmM[i])}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => pick = i),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: ExcludeSemantics(child: node)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Row(children: row)),
        Semantics(liveRegion: true, child: _info(context, pick ?? r, r, pick == null)),
      ],
    );
  }

  Widget _info(BuildContext context, int i, int r, bool brief) {
    final p = Th.pal(context);
    final th = Th.of(context);
    final t = app.t;
    final how = realmHow(context, i, r);
    final desc = Text(L10.text(t.realmD[i]), style: F.s(12.5, c: p.soft, h: 1.5));
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: brief
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [?how, desc])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: F.s(13, c: p.fg, h: 1.5),
                    children: [
                      TextSpan(text: app.rn[i], style: F.s(16, w: FontWeight.w900, family: F.hz, c: rcol(context, i))),
                      TextSpan(text: ' ${app.rpy[i]}', style: F.s(12.5, c: p.soft)),
                      TextSpan(text: ' · ${L10.text(t.realmM[i])} · ${i > 0 ? (app.realmHSK(i).isEmpty ? 'HSK $i' : app.realmHSK(i)) : t.notTested}'),
                      if (i == r) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(text: t.youHere, style: TextStyle(fontWeight: FontWeight.w800, color: th.acc)),
                      ],
                    ],
                  ),
                ),
                ?how,
                desc,
              ],
            ),
    );
  }
}

/// progress inside the realm: four stage segments (初期 <25 %, 中期 25–50 %, 后期 50–80 %, 圆满 ≥80 % of the level's words
/// solid), the next step, and the forecast (pace of the last 14 days) or, at 圆满, the chance to pass a breakthrough
class StageBox extends StatelessWidget {
  final int r;
  const StageBox(this.r, {super.key});
  static const th4 = [0.0, .25, .5, .8, 1.0];
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final lm = app.lm;
    final L = r < 1 ? lm.baseLevel() : r;
    final st = app.memo('stageL@$L', () => lm.stage(L));
    if (st == null) return const SizedBox();
    final lc = rcol(context, r < 1 ? L : r);
    final i = st.i;
    final pct = ((st.share / .8).clamp(0, 1) * 100).round();
    final fc = r >= 1 && !lm.isFinal(r) ? app.memo('forecast', lm.forecast) : null;
    final sol = st.share - st.testShare;
    double fill(double x, int k) => ((x - th4[k]) / (th4[k + 1] - th4[k])).clamp(0, 1).toDouble();
    String note;
    if (r < 1) {
      note = t.prepNote;
    } else if (lm.isFinal(r)) {
      note = r >= 10 ? t.stTop : t.stAll;
    } else if (i == 3) {
      final c = app.memo('btChance', lm.btChance);
      note = t.stOpen + (c == null ? '' : ' ${t.btChance(c < 5 ? '<5' : c > 95 ? '>95' : c)}');
    } else {
      note = t.stNext(app.fmt((fc?['next'] as num?) ?? 0), App.sn[i + 1]);
    }
    String? eta;
    if (fc != null && i < 3) {
      final dn = fc['dNext'] as num?, df = fc['dFull'] as num?;
      eta = dn != null && dn != 0
          ? '<b>${t.etaL}:</b> ${t.etaNext(app.dateS(lm.dayAfter(dn)))}${df != null && df > dn ? ' · ${t.etaFull(app.dateS(lm.dayAfter(df)))}' : ''} · ${t.perWeek(app.fmt(fc['week'] as num))}'
          : t.etaNone;
    }
    const flex = [25, 25, 30, 20];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  r < 1 ? t.prepT(app.rn[L], L) : t.progT,
                  style: F.s(13, w: FontWeight.w800, c: p.soft),
                ),
              ),
              Text('$pct%', style: F.s(22, w: FontWeight.w800, c: lc, feat: F.tab)),
            ],
          ),
          Semantics(
            label: '$pct%, ${App.sn[i]} ${L10.text(t.stageM[i])}',
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Row(
                children: [
                  for (var k = 0; k < 4; k++) ...[
                    if (k > 0) const SizedBox(width: 3),
                    Expanded(
                      flex: flex[k],
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          height: 9,
                          color: p.sunk,
                          child: Stack(
                            children: [
                              if (st.testShare > 0)
                                FractionallySizedBox(
                                  widthFactor: fill(st.share, k),
                                  heightFactor: 1,
                                  child: CustomPaint(painter: _Stripes(lc)),
                                ),
                              FractionallySizedBox(
                                widthFactor: fill(sol, k),
                                heightFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(color: lc, borderRadius: BorderRadius.circular(99)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var k = 0; k < 4; k++) ...[
                  if (k > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: flex[k],
                    child: Column(
                      children: [
                        Text(App.sn[k], style: F.s(13, w: FontWeight.w900, family: F.hz, c: k == i ? lc : p.mute, h: 1.15)),
                        Text(
                          App.spy[k],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: F.s(10, c: k == i ? lc : p.mute, h: 1.15),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text.rich(
            TextSpan(
              style: F.s(13.5, w: FontWeight.w700, c: p.fg, h: 1.4),
              children: [
                TextSpan(text: App.sn[i], style: F.s(13.5, w: FontWeight.w900, family: F.hz, c: lc)),
                TextSpan(text: ' ${L10.text(t.stageM[i])} · ${t.stShare(app.fmt(st.solid), app.fmt(st.total))}'),
              ],
            ),
          ),
          if (st.test > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(t.stTest(app.fmt(st.test)), style: F.s(12.5, c: p.soft, h: 1.4)),
            ),
          const SizedBox(height: 4),
          Rich(note, style: F.s(12.5, c: p.soft, h: 1.4)),
          if (eta != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Rich(eta, style: F.s(12.5, c: p.soft, h: 1.45), boldColor: p.fg),
            ),
        ],
      ),
    );
  }
}

class _Stripes extends CustomPainter {
  final Color c;
  _Stripes(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, Paint()..color = c.withValues(alpha: .25));
    final pn = Paint()
      ..color = c.withValues(alpha: .45)
      ..strokeWidth = 3 / 1.414;
    for (double x = -s.height; x < s.width + s.height; x += 6 / 1.414 * 1.414) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), pn);
    }
  }

  @override
  bool shouldRepaint(_Stripes o) => o.c != c;
}

/// the tests: a stabilising trial when the realm is unstable, the breakthrough at 圆满 (a make-up tribulation for a
/// 飞升 from the placement test), and the placement test only while it is the way in (first test, one retake in 14 days)
class TestBtns extends StatelessWidget {
  final bool note;
  final VoidCallback? before; // closes the sheet first
  const TestBtns({super.key, this.note = true, this.before});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final th = Th.of(context);
    final t = app.t;
    final lm = app.lm;
    final r = lm.realm();
    final can = lm.canTest();
    final sb = app.memo('stability', lm.stability);
    final pt = lm.ptOpen();
    void act(VoidCallback f) {
      before?.call();
      f();
    }

    final out = <Widget>[];
    if (!sb.ok) {
      out.add(
        DashedBox(
          color: p.bad,
          radius: 16,
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 10),
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            decoration: BoxDecoration(color: p.bad.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '境界不稳', style: F.s(17, w: FontWeight.w900, family: F.hz, c: p.bad)),
                      TextSpan(text: '  jìngjiè bù wěn', style: F.s(12, c: p.soft)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    sb.why == 'acc'
                        ? t.unstAcc(sb.P, ((sb.acc ?? 0) * 100).round())
                        : t.unstRec(sb.P, ((sb.rec ?? 0) * 100).round()),
                    style: F.s(13, c: p.soft, h: 1.45),
                  ),
                ),
                MainBtn(
                  t.stabGo,
                  wide: true,
                  lead: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text('试炼稳固', style: F.s(15, w: FontWeight.w900, family: F.hz, c: p.onAcc)),
                  ),
                  semantics: '试炼稳固 ${t.stabGo}',
                  onTap: () => act(stabRun),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (lm.btOpen()) {
      final mk = lm.makeupOpen();
      final lc = rcol(context, mk ? 7 : r + 1);
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BtButton(
            hz: mk ? '补劫' : '突破',
            label: mk ? t.mkGo : t.btGo(app.rn[r + 1]),
            lc: lc,
            acc: th.acc,
            onTap: can ? () => act(() => app.go('bt')) : null,
          ),
        ),
      );
    }
    if (pt == 'first' || pt == 'wait') {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MainBtn(t.ptStart, wide: true, icon: I.play, onTap: pt == 'first' ? () => act(() => app.go('placement')) : null),
        ),
      );
    } else if (pt == 'retake') {
      out.add(GhostBtn(t.ptRetake(app.dateS(app.tDate(lm.ptRetakeUntil()))), wide: true, onTap: () => act(() => app.go('placement'))));
    } else if (r > 0 && note) {
      out.add(Padding(padding: const EdgeInsets.only(top: 8), child: Rich(t.ptClosed, style: F.s(12, c: p.soft, h: 1.45))));
    }
    if (!can && (lm.btOpen() || pt == 'wait')) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2, right: 6), child: Icon2(I.lock, size: 14, color: p.soft)),
              Expanded(
                child: Text(t.testNext(app.dateS(app.tDate(lm.nextTestAt()))), style: F.s(12, c: p.soft, h: 1.45)),
              ),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }
}

/// the breakthrough button: the realm's gold
class BtButton extends StatelessWidget {
  final String hz, label;
  final Color lc, acc;
  final VoidCallback? onTap;
  const BtButton({super.key, required this.hz, required this.label, required this.lc, required this.acc, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Press(
        onTap: onTap,
        scale: .97,
        label: '$hz $label',
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 12, 18, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [acc, Color.lerp(lc, p.gold, .7)!],
            ),
            boxShadow: sh([BoxShadow(color: p.gold.withValues(alpha: .4), offset: const Offset(0, 10), blurRadius: 22, spreadRadius: -10)]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(hz, style: F.s(17, w: FontWeight.w900, family: F.hz, c: p.onAcc, ls: 1)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label, textAlign: TextAlign.center, style: F.s(15, w: FontWeight.w800, c: p.onAcc)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// a stabilising trial: the faded words of the level below, as a quiz round; 80 % right steadies the realm
bool stabRun() {
  final w = app.lm.stabWords(15);
  if (w.isEmpty) return false;
  app.runner.pending = Pending(
    'quiz',
    [for (final d in w) Item.q(d, app.lm.pickType(d))],
    after: (ok, tot) {
      final done = app.lm.stabDone(ok, tot);
      app.changed();
      app.toast(done ? app.t.stabOk : app.t.stabNo(((ok / (tot < 1 ? 1 : tot)) * 100).round()), 5000);
    },
  );
  app.go('quiz');
  return true;
}

/// guidance (指点): what to work on, ranked by LM.advice(); each with a button that starts the right practice
(String, String, String) advText(Json x) {
  final t = app.t;
  final h = 'HSK ${x['L']}';
  String n() => app.fmt(x['n'] as num);
  return switch (x['k']) {
    'test' => (t.advTest, t.advTestWhy, t.advStart),
    'f' => (t.advF(n(), h), t.advFWhy, t.advGo),
    's' => (t.advS(n(), h), t.advSWhy, t.advGo),
    'due' => (t.advDue(n(), h), t.advDueWhy, t.advStart),
    'skill' => (t.advSkill(tName(x['q'] as String), x['p']), t.advSkillWhy, t.advGo),
    'young' => (t.advYoung(n(), h), t.advYoungWhy(x['days']), ''),
    'new' => (t.advNew(n(), h), t.advNewWhy, t.advStart),
    'conf' => (t.advConf((x['a'] as dynamic).h, (x['b'] as dynamic).h, x['n']), t.advConfWhy, t.advGo),
    'unstable' => (t.advUnst(x['P']), t.advUnstWhy, t.stabGo),
    'makeup' => (t.advMk, t.advMkWhy, t.advStart),
    _ => (t.advDao(x['p']), t.advDaoWhy, ''),
  };
}

void advGo(Json x, int L) {
  switch (x['k']) {
    case 'test':
      app.go('placement');
    case 'unstable':
      stabRun();
    case 'makeup':
      app.go('bt');
    case 'f' || 's':
      final q = x['k'] as String;
      app.runner.pending = Pending('quiz', [for (final d in (x['words'] as List)) Item.q(d, q)]);
      app.go('quiz');
    case 'skill':
      app.runner.pending = Pending('quiz', app.lm.quizRound(app.by(L), roundQ, x['q'] as String));
      app.go('quiz');
    case 'conf':
      final a = x['a'], b = x['b'];
      app.runner.pending = Pending('quiz', [Item.q(a, 'm'), Item.q(b, 'm'), Item.q(a, 'f'), Item.q(b, 'f')]);
      app.go('quiz');
    default:
      app.startSession(app.lm.plan().todayLeft == 0);
  }
}

class AdviceList extends StatelessWidget {
  final int max;
  final VoidCallback? before;
  const AdviceList({super.key, required this.max, this.before});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final a = app.memo('advice', app.lm.advice);
    if (a.items.isEmpty) return Rich(app.t.advNone, style: F.s(12, c: p.soft, h: 1.45));
    final items = a.items.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Builder(
            builder: (c) {
              final (tt, why, btn) = advText(items[i]);
              return Padding(
                padding: EdgeInsets.only(top: i > 0 ? 8 : 0),
                child: Glass(
                inner: true,
                radius: 18,
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .10)),
                      child: Text('${i + 1}', style: F.s(11.5, w: FontWeight.w800, c: p.fg)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Rich(tt, style: F.s(13.5, w: FontWeight.w800, c: p.fg, h: 1.35)),
                          const SizedBox(height: 2),
                          Rich(why, style: F.s(12, c: p.soft, h: 1.4)),
                        ],
                      ),
                    ),
                    if (btn.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      GhostBtn(
                        btn,
                        fontSize: 13.5,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onTap: () {
                          before?.call();
                          advGo(items[i], a.L);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              );
            },
          ),
      ],
    );
  }
}

/// the realm sheet: opened by the realm orb on Home
void openRealmSheet(BuildContext context) {
  openSheet(context, name: 'realm', (c) {
    final p = Th.pal(c);
    final th = Th.of(c);
    final t = app.t;
    final lm = app.lm;
    final info = lm.lvInfo;
    final r = lm.realm();
    final cur = lm.curLevel();
    void close() => Navigator.of(c).pop();
    final src = info == null
        ? t.lvSrcDefault
        : r == 0 && info['src'] == 'manual'
        ? t.lvSrcOld(info['lv'])
        : info['src'] == 'bt'
        ? t.lvSrcBt(app.dateS(app.tDate(info['at'] as num)))
        : t.lvSrcTest(app.dateS(app.tDate(info['at'] as num)));
    final how = r >= 1 && (lm.grades()[r] ?? 0) > 0 ? realmHow(c, r, r) : null;
    final note = F.s(13, c: p.soft, h: 1.45);
    return SheetBody(
      title: t.lvT,
      children: [
        RealmHead(r, big: true),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$src${r > 0 && cur > app.realmLv(r) ? ' ${t.lvAhead(cur)}' : ''}', textAlign: TextAlign.center, style: note),
        ),
        if (how != null) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: how)),
        const SizedBox(height: 10),
        RealmPath(r),
        StageBox(r),
        TestBtns(before: close),
        Shd('指点', 'zhǐdiǎn', t.advM),
        AdviceList(max: 2, before: close),
        const SizedBox(height: 12),
        GhostBtn(
          '${t.soulMore} ›',
          wide: true,
          lead: Text('识海', style: F.s(14, w: FontWeight.w900, family: F.hz, c: th.acc)),
          onTap: () {
            close();
            app.go('soul');
          },
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Rich(t.lvNote, style: F.s(12, c: p.soft, h: 1.45))),
      ],
    );
  });
}
