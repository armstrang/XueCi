/// BCT rank and statistics (v1.12, Josh: BCT has its own rank and numbers, apart from the HSK realms).
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/bct_rank.dart';
import '../data/bct.dart';
import 'focus.dart';
import 'glass.dart';
import 'theme.dart';
import 'widgets.dart';

const _gold = Color(0xFFB8801C);

String rankMeaning(int r) => switch (r) {
  0 => app.t.br0,
  1 => app.t.br1,
  2 => app.t.br2,
  3 => app.t.br3,
  _ => app.t.br4,
};

String stageName(int s) => switch (s) {
  0 => app.t.brSt0,
  1 => app.t.brSt1,
  2 => app.t.brSt2,
  _ => app.t.brSt3,
};

/// a small seal with the rank's hanzi (the same gold as the tab bar's)
class RankSeal extends StatelessWidget {
  final int rank;
  final double size;
  const RankSeal({super.key, required this.rank, this.size = 56});
  @override
  Widget build(BuildContext context) {
    final chars = BctRank.names[rank].characters.toList();
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -.045,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * .09),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .2),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9A6410), Color(0xFF724608)]),
          ),
          child: FittedBox(
            child: MediaQuery.withNoTextScaling(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in chars)
                    Text(c, locale: const Locale('zh', 'CN'), style: F.s(size * .34, w: FontWeight.w900, family: F.hz, c: const Color(0xFFFFF4EA), h: 1.02)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// the progress bar of a rank: four segments (awal, tengah, akhir, penuh)
class _Segs extends StatelessWidget {
  final double prog;
  final Color col;
  final Color track;
  const _Segs({required this.prog, required this.col, required this.track});
  @override
  Widget build(BuildContext context) {
    const cuts = [0.0, .25, .5, .8];
    const ends = [.25, .5, .8, 1.0];
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: ((ends[i] - cuts[i]) * 100).round(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ((prog - cuts[i]) / (ends[i] - cuts[i])).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(col),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// the rank card on the BCT home: the seal, the rank, the stage and what is missing for the next one
class BctRankCard extends StatelessWidget {
  const BctRankCard({super.key});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final i = app.bctInfo;
    final next = i.rank + 1;
    final String line;
    if (i.top) {
      line = t.brTop;
    } else if (i.waitExam) {
      line = t.brExam(i.examBook.toUpperCase());
    } else {
      line = t.brWords(app.fmt(i.solid), app.fmt(BctRank.thr[next]));
    }
    return Press(
      onTap: () => app.go('bctstats'),
      label: '${t.brTitle}: ${rankMeaning(i.rank)}, ${stageName(i.stage)}. $line',
      child: Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RankSeal(rank: i.rank),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: rankMeaning(i.rank), style: F.s(18, w: FontWeight.w800, c: p.fg)),
                        TextSpan(text: '  ${stageName(i.stage)}', style: F.s(13.5, w: FontWeight.w700, c: p.soft)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Segs(prog: i.prog, col: _gold, track: p.sunk),
                  const SizedBox(height: 8),
                  Text(line, style: F.s(12.5, c: p.soft, h: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BctStatsScreen extends StatefulWidget {
  const BctStatsScreen({super.key});
  @override
  State<BctStatsScreen> createState() => _BctStatsState();
}

class _BctStatsState extends State<BctStatsScreen> {
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final i = app.bctInfo;
    final bottom = MediaQuery.paddingOf(context).bottom + 98;
    Widget head(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(s.toUpperCase(), style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.2)),
    );
    Widget bar(String label, int a, int b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: F.s(15, w: FontWeight.w800, c: p.fg)),
              const SizedBox(width: 8),
              Expanded(child: Text(t.bstSolid(app.fmt(a), app.fmt(b)), textAlign: TextAlign.end, style: F.s(13, w: FontWeight.w600, c: p.soft, feat: F.tab))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: b == 0 ? 0 : a / b, minHeight: 8, backgroundColor: p.sunk, valueColor: const AlwaysStoppedAnimation(_gold)),
          ),
        ],
      ),
    );

    final pct = i.answers == 0 ? 0 : (100 * i.right / i.answers).round();
    final mocks = [
      for (final m in app.lm.mocks)
        if (m.length > 3 && (m[1] as num) >= 100) m,
    ].reversed.take(5).toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Capsule(title: t.bstTitle, onBack: () => app.go('home')),
              const SizedBox(height: 14),
              const BctRankCard(),
              head(t.bstBooks),
              Glass(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    bar(t.bsBook('A'), i.solidA, i.totalA),
                    bar(t.bsBook('B'), i.solidB, i.totalB),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.bstSeen(app.fmt(i.seen)),
                        style: F.s(13, c: p.soft, h: 1.4),
                      ),
                    ),
                    Align(alignment: Alignment.centerLeft, child: Text(
                      i.answers > 0 ? t.bstAcc(pct, app.fmt(i.answers)) : switch (app.lang) {
                        'id' => 'Belum ada jawaban kartu atau kuis.',
                        'th' => 'ยังไม่มีคำตอบจากบัตรคำหรือแบบทดสอบ',
                        'vi' => 'Chưa có câu trả lời từ thẻ hoặc câu đố.',
                        _ => 'No card or quiz answers yet.',
                      }, style: F.s(13, c: p.soft, h: 1.4),
                    )),
                    Align(alignment: Alignment.centerLeft, child: Text(
                      t.bsDue(app.fmt(i.due)), style: F.s(13, w: FontWeight.w600, c: p.mute),
                    )),
                  ],
                ),
              ),
              head(t.bstPath),
              Glass(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Row(
                  children: [
                    for (var r = 0; r < BctRank.names.length; r++)
                      Expanded(
                        child: Semantics(
                          label: '${rankMeaning(r)}${r == i.rank ? ', ✓' : ''}',
                          child: Opacity(
                            opacity: r <= i.rank ? 1 : .45,
                            child: Column(
                              children: [
                                RankSeal(rank: r, size: r == i.rank ? 50 : 40),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(rankMeaning(r), maxLines: 1, style: F.s(11.5, w: r == i.rank ? FontWeight.w800 : FontWeight.w600, c: p.fg)),
                                ),
                                Text(BctRank.pinyin[r], maxLines: 1, style: F.s(10, c: p.mute)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!i.top) ...[
                const SizedBox(height: 10),
                Text(
                  i.waitExam ? t.brExam(i.examBook.toUpperCase()) : t.bstNeed(app.fmt(i.toNext), rankMeaning(i.rank + 1)),
                  style: F.s(13.5, c: p.soft, h: 1.4),
                ),
                if (i.waitExam) ...[
                  const SizedBox(height: 10),
                  GhostBtn(
                    t.bsExam,
                    wide: true,
                    onTap: () {
                      app.mockMode = true;
                      app.mockPick = 'bct';
                      app.mockSec = null;
                      app.go('quiz');
                    },
                  ),
                ],
              ],
              head(t.bstMocks),
              Glass(
                radius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: mocks.isEmpty
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t.bstNoMock, style: F.s(14, c: p.soft)))
                    : Column(
                        children: [
                          for (var k = 0; k < mocks.length; k++) ...[
                            if (k > 0) Divider(height: 1, thickness: 1, color: p.line),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.bsBook(bctBook((mocks[k][1] as num).toInt()).toUpperCase()), style: F.s(14.5, w: FontWeight.w700, c: p.fg)),
                                        Text(app.dateS(app.tDate(mocks[k][0] as num)), style: F.s(12.5, c: p.mute)),
                                      ],
                                    ),
                                  ),
                                  Text('${mocks[k][2]}/${mocks[k][3]}', style: F.s(16, w: FontWeight.w800, c: p.fg, feat: F.tab)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
