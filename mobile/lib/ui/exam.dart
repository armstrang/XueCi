/// The Tests tab (v1.4): every test in one place. The HSK simulation (the written HSK 3.0 paper, run_view.dart),
/// the HSKK mock test (hskk.dart) and the realm tests (placement and the tribulation, behind the realm sheet).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/hskk.dart';
import 'glass.dart';
import 'icons.dart';
import 'splash.dart';
import 'theme.dart';

class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final bottom = MediaQuery.paddingOf(context).bottom + 10 + 64 + 18;
    // the last written simulation at this level, and the last HSKK mock
    final hsk = [
      for (final m in lm.mocks)
        if (m.length > 3 && m[1] == app.level) m,
    ];
    final hskLast = hsk.isEmpty ? null : '${hsk.last[2]}/${hsk.last[3]}';
    final hk = app.spkLog.mocks;
    final hkLast = hk.isEmpty ? null : '${hk.last[2]}/100';
    final r = lm.realm();
    // the latest results of both mock tests together, newest first
    final recent = <({num at, String name, String score})>[
      for (final m in lm.mocks)
        if (m.length > 3)
          (
            at: m[0] as num,
            name: m[1] >= 101
                ? (m[1] == 101 ? t.exBctA : t.exBctB)
                : '${t.exHsk} · HSK ${m[1]}',
            score: '${m[2]}/${m[3]}',
          ),
      for (final m in hk)
        (
          at: m[0] as num,
          name: '${t.exHskk} · ${_hkName((m[1] as num).toInt())}',
          score: '${m[2]}/100',
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));
    Widget section(String title) => Semantics(
      header: true,
      child: Text(
        title,
        style: F.s(15, w: FontWeight.w800, c: p.fg),
      ),
    );
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
        children: [
          Semantics(
            header: true,
            child: Text(
              t.exTitle,
              style: F.s(31, w: FontWeight.w800, c: p.fg, ls: -.6),
            ),
          ),
          const SizedBox(height: 18),
          section(t.exPracticeGroup),
          const SizedBox(height: 8),
          Rise(
            1,
            child: _ExamCard(
              seal: '考',
              title: t.exHsk,
              sub: '${t.exHskD} · HSK ${app.level}',
              foot: hskLast == null ? t.exNone : t.hkLast(hskLast),
              color: th.acc,
              onTap: () {
                app.mockMode = true;
                app.mockPick = 'hsk';
                app.go('quiz');
              },
            ),
          ),
          const SizedBox(height: 12),
          Rise(
            2,
            child: _ExamCard(
              seal: '说',
              title: t.exHskk,
              sub: '${t.exHskkD} · ${_hkName(app.hkLv)} (${hkBand(app.hkLv)})',
              foot: hkLast == null ? t.exNone : t.hkLast(hkLast),
              color: p.warm,
              onTap: () =>
                  app.startHk(app.hkLv.clamp(1, app.hkOpenTo), mock: true),
            ),
          ),
          if ((app.lm.bct?.of('a').length ?? 0) >= 70 ||
              (app.lm.bct?.of('b').length ?? 0) >= 150) ...[
            const SizedBox(height: 12),
            Rise(
              3,
              child: _ExamCard(
                seal: '商',
                title: t.exBct,
                sub: t.exBctD,
                foot: _bctLast() ?? t.exNone,
                color: p.good,
                onTap: () {
                  app.mockMode = true;
                  app.mockPick = 'bct';
                  app.mockSec = null;
                  app.go('quiz');
                },
              ),
            ),
          ],
          const SizedBox(height: 18),
          section(t.exRealmGroup),
          const SizedBox(height: 8),
          Rise(
            4,
            child: _ExamCard(
              seal: '境',
              title: t.exRealm,
              sub: t.exRealmD,
              foot: app.rn[r],
              color: th.rc,
              onTap: () => app.openRealm?.call(context),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              t.exHist.toUpperCase(),
              style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.2),
            ),
            const SizedBox(height: 8),
            Glass(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length && i < 5; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recent[i].name,
                                  style: F.s(14.5, w: FontWeight.w700, c: p.fg),
                                ),
                                Text(
                                  app.dateS(app.tDate(recent[i].at)),
                                  style: F.s(12.5, c: p.mute),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            recent[i].score,
                            style: F.s(
                              16,
                              w: FontWeight.w800,
                              c: p.fg,
                              feat: F.tab,
                            ),
                          ),
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

/// the latest BCT result, A or B
String? _bctLast() {
  final x = [
    for (final m in app.lm.mocks)
      if (m.length > 3 && m[1] >= 101) m,
  ]..sort((a, b) => (a[0] as num).compareTo(b[0] as num));
  return x.isEmpty ? null : app.t.hkLast('${x.last[2]}/${x.last[3]}');
}

String _hkName(int lv) => switch (lv) {
  1 => app.t.hkL1,
  2 => app.t.hkL2,
  _ => app.t.hkL3,
};

class _ExamCard extends StatelessWidget {
  final String seal, title, sub, foot;
  final Color color;
  final VoidCallback onTap;
  const _ExamCard({
    required this.seal,
    required this.title,
    required this.sub,
    required this.foot,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Press(
      onTap: onTap,
      label: '$title. $sub. $foot',
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: p.dark ? .22 : .16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: .45)),
              ),
              alignment: Alignment.center,
              child: Text(
                seal,
                style: F.s(26, family: F.hz, c: p.fg, w: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: F.s(16.5, w: FontWeight.w800, c: p.fg),
                  ),
                  const SizedBox(height: 3),
                  Text(sub, style: F.s(13, c: p.soft, h: 1.35)),
                  const SizedBox(height: 5),
                  Text(
                    foot,
                    style: F.s(12.5, w: FontWeight.w600, c: p.mute),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            RotatedBox(
              quarterTurns: 3,
              child: Icon2(I.chev, size: 16, color: p.mute, width: 2.2),
            ),
          ],
        ),
      ),
    );
  }
}
