/// After a talk: a score with its reasons, the slips a learner of Chinese often makes (with the better wording), and
/// model sentences for what was missing. Scores are a guide, not an examiner's mark.
library;

import 'dialog.dart';
import 'nlu.dart';

class Slip {
  /// what was said, the better wording, why (Indonesian)
  final String said, better, why;
  const Slip(this.said, this.better, this.why);
}

class _Rule {
  final RegExp re;
  final String Function(Match m) fix;
  final String why;
  _Rule(String re, this.fix, this.why) : re = RegExp(re);
}

final _rules = <_Rule>[
  _Rule('道歉(您|你)', (m) => '向${m[1]}道歉', 'Minta maaf kepada seseorang: 向您道歉, bukan 道歉您.'),
  _Rule('(送到|发货|到货|发出|寄出)(今天|明天|后天|星期[一二三四五六日天]|周[一二三四五六日])', (m) => '${m[2]}${m[1]}',
      'Waktu diletakkan sebelum kata kerja: 明天送到, bukan 送到明天.'),
  _Rule('打折(扣)?([一二三四五六七八九\\d])(?!折)', (m) => '打${m[2]}折', 'Diskon ditulis 打九折: angka di antara 打 dan 折.'),
  _Rule('折扣([一二三四五六七八九])(?!折)', (m) => '打${m[1]}折', 'Diskon ditulis 打九折, bukan 折扣九.'),
  _Rule('百分([一二三四五六七八九十]+)', (m) => '百分之${m[1]}', 'Persen ditulis 百分之十, dengan 之.'),
  _Rule('在(今天|明天|后天|星期[一二三四五六日天]|周[一二三四五六日])', (m) => m[1]!, 'Hari tidak memakai 在: 明天送到, bukan 在明天送到.'),
  _Rule('很抱歉的', (m) => '很抱歉', 'Cukup 很抱歉, tanpa 的.'),
  _Rule('一个货', (m) => '一批货', 'Barang dagangan dihitung 一批货.'),
  _Rule('(我们|我)是(道歉|抱歉)', (m) => '${m[1]}很抱歉', 'Tanpa 是: 我们很抱歉.'),
  _Rule('谢谢(你|您)的(理解|耐心)(你|您)', (m) => '谢谢${m[1]}的${m[2]}', 'Cukup sekali: 谢谢您的理解.'),
];

/// common slips in what was said
List<Slip> slipsOf(String text) {
  final out = <Slip>[];
  for (final r in _rules) {
    for (final m in r.re.allMatches(text)) {
      out.add(Slip(m[0]!, r.fix(m), r.why));
    }
  }
  return out;
}

class Part {
  final String name;
  final int got, max;
  final String why;
  const Part(this.name, this.got, this.max, this.why);
}

class TermScore {
  final String term;
  final int score;
  const TermScore(this.term, this.score);
}

// Only score explicit practice terms and phrases with a defined usage cue.
const _termCues = <String, String>{
  '抱歉': 'apologize+', '不好意思': 'apologize+', '道歉': 'apologize+',
  '送到': 'promise_time+', '发货': 'resend+', '打折': 'discount+',
  '补偿': 'compensate+', '谢谢': 'thanks+',
};

List<TermScore> reportTerms(TalkDialog dialog) {
  final scores = <String, int>{};
  final goal = dialog.sc.practice;
  final target = goal?.hint.split(' · ').first.trim() ?? '';
  for (final turn in dialog.turns) {
    for (final cue in _termCues.entries) {
      if (!turn.said.contains(cue.key)) continue;
      final valid = turn.frames.any((frame) => frame.key == cue.value);
      final corrected = slipsOf(turn.said).any((slip) => slip.said.contains(cue.key));
      final score = valid && !corrected ? 10 : 5;
      scores.update(cue.key, (prev) => prev > score ? prev : score, ifAbsent: () => score);
    }
    if (target.isNotEmpty && turn.said.contains(target)) {
      final score = dialog.practiceAccepted(turn.said) ? 10 : 5;
      scores.update(target, (prev) => prev > score ? prev : score, ifAbsent: () => score);
    }
  }
  return [for (final e in scores.entries) TermScore(e.key, e.value)];
}

class Report {
  final int total;
  final List<Part> parts;
  final List<Slip> slips;

  /// for what was missing: model sentences (Chinese, Indonesian)
  final List<Line> models;
  final String end;
  final List<TermScore> terms;
  const Report(this.total, this.parts, this.slips, this.models, this.end, {this.terms = const []});
}

const _models = <String, List<Line>>{
  'apology': [Line('真的很抱歉，给您添麻烦了。', 'Saya sungguh minta maaf telah merepotkan Anda.')],
  'reason': [Line('因为海关查验，货晚了三天。', 'Karena pemeriksaan bea cukai, barang terlambat tiga hari.')],
  'replacement': [Line('我们给您换成蓝色款，后天送到。', 'Kami ganti dengan yang biru dan kirim sampai lusa.')],
  'invoice': [Line('我会按合同金额重开发票。', 'Saya akan menerbitkan ulang faktur sesuai nilai kontrak.')],
  'refund': [Line('多扣的两百元会原路退回。', 'Kelebihan bayar 200 yuan akan dikembalikan lewat metode pembayaran awal.')],
  'delivery': [Line('我们今天就重新发货，星期四之前一定送到。', 'Kami kirim ulang hari ini, pasti tiba sebelum Kamis.')],
  'compensation': [Line('这次给您打九折，作为补偿。', 'Kali ini kami beri diskon 10% sebagai kompensasi.')],
  'polite': [Line('谢谢您的理解，期待我们继续合作。', 'Terima kasih atas pengertian Anda, kami berharap kerja sama terus berlanjut.')],
  'you': [Line('请您放心，我们会负责到底。', 'Bapak tidak perlu khawatir, kami akan bertanggung jawab sampai tuntas.')],
};

Report coach(TalkDialog d) {
  final st = d.st;
  final goal = d.sc.practice;
  if (goal != null) {
    final last = d.turns.lastOrNull;
    final complete = st.end == 'good';
    final polite = last != null && RegExp(r'您|请|谢谢').hasMatch(last.said);
    final parts = [
      Part('Tujuan latihan', complete ? 75 : 0, 75, complete ? 'Kebutuhan klien terpenuhi.' : 'Jawaban belum memenuhi rincian yang diminta.'),
      Part('Sopan santun', polite ? 15 : 0, 15, polite ? 'Kamu memakai ungkapan sopan.' : 'Gunakan sapaan atau ungkapan sopan.'),
      Part('Ringkas', complete ? (st.turns == 1 ? 10 : 5) : 0, 10, '${st.turns} giliran.'),
    ];
    return Report(parts.fold(0, (sum, part) => sum + part.got), parts,
        slipsOf(d.turns.map((turn) => turn.said).join('。')), [goal.example], st.end ?? 'open', terms: reportTerms(d));
  }
  final all = d.turns.map((t) => t.said).join('。');
  final understood = d.turns.where((t) => t.frames.isNotEmpty).map((t) => t.said).join('。');
  final parts = <Part>[];
  final models = <Line>[];
  void need(String name, bool ok, int max, String yes, String no, String model) {
    parts.add(Part(name, ok ? max : 0, max, ok ? yes : no));
    if (!ok) models.addAll(_models[model]!);
  }

  need('Minta maaf', st.apology, 20, 'Kamu minta maaf atau mengakui kesalahan.', 'Klien tidak mendengar permintaan maaf.', 'apology');
  final replacement = d.sc.requiresReplacement;
  if (d.sc.requiresBilling) {
    need('Pengembalian uang', st.refundCents == d.sc.overchargeCents, 30, 'Kamu mengonfirmasi pengembalian sesuai selisih tagihan.',
        st.refundCents == null ? 'Pastikan kamu menyebut pengembalian dan nominalnya.' : 'Nominal pengembalian belum sama dengan kelebihan bayar.', 'refund');
    need('Faktur', st.invoiceCorrected, 25, 'Kamu mengonfirmasi penerbitan faktur yang benar.',
        'Konfirmasi bahwa kamu akan memperbaiki faktur yang salah.', 'invoice');
  } else {
    if (replacement) {
      need('Barang pengganti', st.replacement, 30, 'Barang biru dikonfirmasi.',
          'Pastikan penggantinya model biru yang dipesan klien.', 'replacement');
    } else {
      need('Penyebab', st.reason, 15, 'Kamu menjelaskan penyebabnya.', 'Penyebab keterlambatan tidak disebut.', 'reason');
    }
    need('Waktu tiba', st.delivery, 25, 'Kamu memberi hari yang sesuai tenggat klien.',
        st.offeredDays != null ? 'Hari yang kamu tawarkan melewati tenggat klien.' : 'Kamu belum menyebut hari tiba yang jelas.',
        replacement ? 'replacement' : 'delivery');
    if (!replacement) {
      need('Kompensasi', st.compensation, 15, 'Kamu memberi kompensasi yang diterima klien.',
          st.offeredPct != null ? 'Diskonnya terlalu kecil untuk klien.' : 'Klien tidak mendapat kompensasi.', 'compensation');
    }
  }
  final polite = RegExp('(您|请|麻烦|贵公司|不好意思|谢谢|感谢|期待|合作)').allMatches(understood).length;
  final ni = RegExp('你').allMatches(understood).length;
  final pol = (polite >= 4 ? 15 : polite * 15 ~/ 4) - (ni > 2 && ni > polite ? 5 : 0);
  parts.add(Part('Sopan santun', pol.clamp(0, 15), 15,
      ni > 2 && ni > polite ? 'Kepada klien, pakai 您, bukan 你.' : (polite >= 4 ? 'Bahasamu sopan dan formal.' : 'Tambah ungkapan sopan: 您, 请, 谢谢您.')));
  if (polite < 4) models.addAll(_models['polite']!);
  if (ni > 2 && ni > polite) models.addAll(_models['you']!);
  final hasProgress = st.reason || st.delivery || st.compensation || st.replacement || st.invoiceCorrected || st.refundCents != null;
  final turnsPts = !hasProgress ? 0 : (d.turns.length <= 5 ? 10 : (d.turns.length <= 8 ? 6 : 3));
  parts.add(Part('Ringkas', turnsPts, 10, '${d.turns.length} giliran sampai selesai.'));
  final total = parts.fold<int>(0, (a, p) => a + p.got);
  return Report(total, parts, slipsOf(all), models, st.end ?? 'open', terms: reportTerms(d));
}

/// the frames a turn counts, for showing under a voice note
String framesLine(List<Frame> f) => f.map((x) => '${x.act}${x.pol}').join(' ');
