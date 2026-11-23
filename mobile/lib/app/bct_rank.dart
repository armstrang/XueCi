/// The BCT rank (v1.12, Josh: BCT gets its own rank and statistics, apart from the HSK realms). Worked out from the
/// words that are solid in `xc_bct` and the BCT practice papers in `xc_mock`; nothing of its own is stored, so a
/// backup code that carries those two carries the rank.
///
/// Ranks (hanzi, with the meaning in L10 `br0`…`br4`): 实习 → 职员 → 主管 → 经理 → 董事. A rank needs enough solid words
/// ([thr]) and, from the second one, a passed practice paper (BCT A up to 主管 … see [paper]).
library;

import '../data/bct.dart';
import 'bct_prog.dart';

class BctRank {
  static const names = ['实习', '职员', '主管', '经理', '董事'];
  static const pinyin = ['shíxí', 'zhíyuán', 'zhǔguǎn', 'jīnglǐ', 'dǒngshì'];

  /// solid words needed to stand at each rank, and the end of the last one
  static const thr = [0, 120, 400, 1200, 2800, 4000];

  /// the practice paper that opens each rank (0: none) and the share needed to pass it
  static const paper = ['', 'a', 'a', 'b', 'b'];
  static const cut = [0.0, .6, .6, .65, .7];
}

class BctRankInfo {
  final int rank, stage; // stage 0–3: awal, tengah, akhir, penuh
  final double prog; // 0..1 inside the rank
  final int solid, solidA, solidB, total, totalA, totalB, seen, due, answers, right;
  final int toNext; // solid words still missing for the next rank (0 when enough)
  final bool waitExam; // enough words, the practice paper is not passed yet
  final String examBook; // which one ('a' / 'b'), when waitExam
  final double examCut;
  const BctRankInfo({
    required this.rank,
    required this.stage,
    required this.prog,
    required this.solid,
    required this.solidA,
    required this.solidB,
    required this.total,
    required this.totalA,
    required this.totalB,
    required this.seen,
    required this.due,
    required this.answers,
    required this.right,
    required this.toNext,
    required this.waitExam,
    required this.examBook,
    required this.examCut,
  });
  bool get top => rank >= BctRank.names.length - 1;
}

BctRankInfo bctRankInfo(BProg bp, BctBank? bank, List<List<dynamic>> mocks) {
  final a = bank?.wordsOf('a') ?? const <BctW>[];
  final b = bank?.wordsOf('b') ?? const <BctW>[];
  int solid(List<BctW> ws) => ws.where((w) => bp.held(w.h)).length;
  final sa = solid(a), sb = solid(b), s = sa + sb;
  var seen = 0, due = 0, ans = 0, right = 0;
  for (final w in [...a, ...b]) {
    if (bp.seen(w.h)) {
      seen++;
      if (bp.due(w.h)) due++;
      ans += bp.n(w.h);
      right += (bp.j[w.h]?[4] ?? 0).toInt();
    }
  }
  bool passed(String book, double cut) {
    final lv = bctLevel(book);
    for (final m in mocks) {
      if (m.length > 3 && m[1] == lv && (m[3] as num) > 0 && (m[2] as num) / (m[3] as num) >= cut) return true;
    }
    return false;
  }

  // the highest rank whose words and paper are both there (a rank can only be reached one after another)
  var r = 0;
  while (r + 1 < BctRank.names.length && s >= BctRank.thr[r + 1] && passed(BctRank.paper[r + 1], BctRank.cut[r + 1])) {
    r++;
  }
  final lo = BctRank.thr[r], hi = BctRank.thr[r + 1];
  final prog = ((s - lo) / (hi - lo)).clamp(0.0, 1.0);
  final stage = prog < .25 ? 0 : (prog < .5 ? 1 : (prog < .8 ? 2 : 3));
  final next = r + 1 < BctRank.names.length ? r + 1 : -1;
  final enough = next >= 0 && s >= BctRank.thr[next];
  return BctRankInfo(
    rank: r,
    stage: stage,
    prog: prog,
    solid: s,
    solidA: sa,
    solidB: sb,
    total: a.length + b.length,
    totalA: a.length,
    totalB: b.length,
    seen: seen,
    due: due,
    answers: ans,
    right: right,
    toNext: next < 0 ? 0 : (BctRank.thr[next] - s).clamp(0, 1 << 30),
    waitExam: enough,
    examBook: next < 0 ? 'a' : BctRank.paper[next],
    examCut: next < 0 ? 0 : BctRank.cut[next],
  );
}
