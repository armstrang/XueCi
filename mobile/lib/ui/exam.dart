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
    final hsk = [for (final m in lm.mocks) if (m.length > 3 && m[1] == app.level) m];
    final hskLast = hsk.isEmpty ? null : '${hsk.last[2]}/${hsk.last[3]}';
    final hk = app.spkLog.mocks;
    final hkLast = hk.isEmpty ? null : '${hk.last[2]}/100';
    final r = lm.realm();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
        children: [
          Semantics(
            header: true,
            child: Text(t.exTitle, style: F.s(31, w: FontWeight.w800, c: p.fg, ls: -.6)),
          ),
          const SizedBox(height: 2),
          Text(t.exSub, style: F.s(14, c: p.soft)),
          const SizedBox(height: 18),
          Rise(1,
            child: _ExamCard(
              seal: '考',
              title: t.exHsk,
              sub: '${t.exHskD} · HSK ${app.level}',
              last: hskLast,
              color: th.acc,
              onTap: () {
                app.qType = 'mock';
                app.saveUI();
                app.go('quiz');
              },
            ),
          ),
          const SizedBox(height: 12),
          Rise(2,
            child: _ExamCard(
              seal: '说',
              title: t.exHskk,
              sub: '${t.exHskkD} · ${_hkName(app.hkLv)} (${hkBand(app.hkLv)})',
              last: hkLast,
              color: p.warm,
              onTap: () => app.startHk(app.hkLv.clamp(1, app.hkOpenTo), mock: true),
            ),
          ),
          const SizedBox(height: 12),
          Rise(3,
            child: _ExamCard(
              seal: '境',
              title: t.exRealm,
              sub: '${t.exRealmD} · ${app.rn[r]}',
              last: null,
              color: th.rc,
              onTap: () => app.openRealm?.call(context),
            ),
          ),
        ],
      ),
    );
  }
}

String _hkName(int lv) => switch (lv) {
  1 => app.t.hkL1,
  2 => app.t.hkL2,
  _ => app.t.hkL3,
};

class _ExamCard extends StatelessWidget {
  final String seal, title, sub;
  final String? last;
  final Color color;
  final VoidCallback onTap;
  const _ExamCard({required this.seal, required this.title, required this.sub, required this.last, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    return Press(
      onTap: onTap,
      label: '$title. $sub',
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
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
              child: Text(seal, style: F.s(26, family: F.hz, c: p.fg, w: FontWeight.w600)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: F.s(16.5, w: FontWeight.w800, c: p.fg)),
                  const SizedBox(height: 3),
                  Text(sub, style: F.s(13, c: p.soft, h: 1.35)),
                  const SizedBox(height: 5),
                  Text(last == null ? t.exNone : t.hkLast(last!), style: F.s(12.5, w: FontWeight.w700, c: p.mute)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            RotatedBox(quarterTurns: 3, child: Icon2(I.chev, size: 16, color: p.mute, width: 2.2)),
          ],
        ),
      ),
    );
  }
}
