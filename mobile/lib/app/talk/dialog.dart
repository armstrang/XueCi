/// A client who reasons: what the learner said (frames from TalkNlu) changes what the client still needs, how the
/// client feels and how much patience is left, and the client's next line follows from that, never from a fixed
/// script. The client wants, in this order: an apology, a reason, a delivery no later than the deadline, and
/// something for the trouble (a discount of at least [Scenario.minPct], or another compensation). Being rude (blaming
/// others, refusing) costs mood; apologizing, understanding and politeness win it back. Every run ends: well, fair,
/// or with the client gone.
library;

import 'dart:math';

import 'nlu.dart';

/// days from "today" (the scenario's day) for each `when` the engine reads
int? daysOf(String? when, {int today = 1}) {
  if (when == null) return null;
  const week = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  switch (when) {
    case 'today':
      return 0;
    case 'tomorrow':
      return 1;
    case 'dayafter':
      return 2;
  }
  final w = week.indexOf(when);
  if (w >= 0) return (w - today + 7) % 7;
  final m = RegExp(r'^(\d+)_days$').firstMatch(when);
  return m == null ? null : int.parse(m[1]!);
}

class Line {
  final String zh, id;
  const Line(this.zh, this.id);
}

class Scenario {
  final String id, title, client;

  /// today's weekday (0 Monday) and the day the goods must be there (days from today)
  final int today, deadline;
  final String deadlineZh, deadlineId;

  /// the smallest discount (percent) the client takes
  final int minPct;
  final int patience;

  /// what the client says, by situation; {d} = the deadline, {p} = the discount offered, {m} = the minimum
  final Map<String, List<Line>> lines;
  const Scenario({
    required this.id,
    required this.title,
    required this.client,
    required this.today,
    required this.deadline,
    required this.deadlineZh,
    required this.deadlineId,
    required this.minPct,
    required this.patience,
    required this.lines,
  });
}

/// what the client still wants
enum Need { apology, reason, delivery, compensation, close }

class Turn {
  final String said;
  final List<Frame> frames;
  final Line reply;
  final String situation;
  final int mood;
  Turn(this.said, this.frames, this.reply, this.situation, this.mood);
}

class ClientState {
  int mood = 0, patience, turns = 0, refusals = 0, denials = 0;
  bool apology = false, reason = false, delivery = false, compensation = false, closed = false;
  bool askedWhen = false, gaveUpCompensation = false;
  int? offeredDays, offeredPct;
  String? end; // good, fair, lost
  final Set<String> heard = {};
  ClientState(this.patience);
}

class TalkDialog {
  final Scenario sc;
  final ClientState st;
  final Random _rnd;
  final List<Turn> turns = [];
  TalkDialog(this.sc, {int seed = 1})
      : st = ClientState(sc.patience),
        _rnd = Random(seed);

  bool get over => st.end != null;

  Line _say(String situation) {
    final l = sc.lines[situation]!;
    final x = l[_rnd.nextInt(l.length)];
    String f(String s, bool zh) => s
        .replaceAll('{d}', zh ? sc.deadlineZh : sc.deadlineId)
        .replaceAll('{p}', st.offeredPct == null ? '' : (zh ? _zhe(st.offeredPct!) : '${st.offeredPct}%'))
        .replaceAll('{m}', zh ? _zhe(sc.minPct) : '${sc.minPct}%');
    return Line(f(x.zh, true), f(x.id, false));
  }

  static String _zhe(int pct) {
    const n = '零一二三四五六七八九';
    final paid = 100 - pct;
    if (paid % 10 == 0) return '${n[paid ~/ 10]}折';
    return '${n[paid ~/ 10]}${n[paid % 10]}折';
  }

  /// the client's opening line
  Line open() => _say('open');

  /// what the client needs next
  Need get next {
    if (!st.apology) return Need.apology;
    if (!st.reason) return Need.reason;
    if (!st.delivery) return Need.delivery;
    if (!st.compensation && !st.gaveUpCompensation) return Need.compensation;
    return Need.close;
  }

  /// one turn: [frames] are what the engine took as said (conf >= ok); [text] is what was heard
  Line reply(String text, List<Frame> frames) {
    if (over) return _say('bye');
    st.turns++;
    final has = {for (final f in frames) f.key};
    st.heard.addAll(has);
    String situation;

    // mood
    final polite = RegExp('(您|请|麻烦|贵公司|不好意思|谢谢|感谢)').allMatches(text).length;
    if (has.contains('apologize+') && !st.apology) st.mood += 1;
    if (has.contains('acknowledge+')) st.mood += 1;
    if (polite >= 2) st.mood += 1;
    if (has.contains('deny_fault+')) {
      st.mood -= 2;
      st.denials++;
    }
    if (has.contains('apologize-')) st.mood -= 2;
    st.mood = st.mood.clamp(-4, 3);

    // needs
    if (has.contains('apologize+') || (has.contains('acknowledge+') && st.turns > 1)) st.apology = true;
    if (frames.any((f) => f.act == 'cause' && f.pol == '+')) st.reason = true;
    var late = false, noDay = false;
    for (final f in frames.where((f) => f.pol == '+' && (f.act == 'resend' || f.act == 'promise_time' || f.act == 'expedite'))) {
      final d = daysOf(f.when, today: sc.today);
      if (d != null) {
        st.offeredDays = st.offeredDays == null ? d : min(st.offeredDays!, d);
      }
    }
    final offeredDelivery = frames.any((f) => f.pol == '+' && (f.act == 'resend' || f.act == 'promise_time' || f.act == 'expedite'));
    if (offeredDelivery || (st.askedWhen && st.offeredDays != null)) {
      if (st.offeredDays == null) {
        noDay = true;
      } else if (st.offeredDays! > sc.deadline) {
        late = true;
      } else {
        st.delivery = true;
      }
    }
    var lowPct = false, pctUnknown = false;
    for (final f in frames.where((f) => f.pol == '+' && f.act == 'discount')) {
      if (f.pct == null) {
        pctUnknown = true;
      } else {
        st.offeredPct = f.pct;
        if (f.pct! >= sc.minPct) {
          st.compensation = true;
        } else {
          lowPct = true;
        }
      }
    }
    if (has.contains('compensate+')) st.compensation = true;
    final refused = has.contains('refuse+') || has.contains('discount-') || has.contains('compensate-');
    if (refused && !st.compensation) {
      st.refusals++;
      st.mood -= 1;
    }
    final closing = has.contains('thanks+') || has.contains('closing+');

    // the end
    if (st.mood <= -3 || st.denials >= 2 || (frames.isEmpty && st.patience <= 1)) {
      st.end = 'lost';
      return _record(text, frames, 'lost');
    }
    if (st.turns >= 12) {
      st.end = st.delivery ? 'fair' : 'lost';
      return _record(text, frames, st.end == 'fair' ? 'fair' : 'lost');
    }
    if (frames.isEmpty) {
      st.patience--;
      return _record(text, frames, 'unclear');
    }

    if (has.contains('deny_fault+')) {
      situation = 'deny';
    } else if (refused && !st.compensation && st.apology && st.delivery) {
      if (st.refusals >= 2) {
        st.gaveUpCompensation = true;
        st.mood -= 1;
        situation = st.mood <= -2 ? 'lost' : 'grudge';
        if (situation == 'lost') st.end = 'lost';
      } else {
        situation = 'pushComp';
      }
    } else if (late) {
      st.patience--;
      situation = 'tooLate';
    } else if (noDay && !st.delivery) {
      st.askedWhen = true;
      situation = 'whichDay';
    } else if (lowPct) {
      situation = 'lowPct';
    } else if (pctUnknown && !st.compensation) {
      situation = 'howMuch';
    } else {
      switch (next) {
        case Need.apology:
          st.patience--;
          situation = st.turns >= 2 ? 'wantSorry2' : 'wantSorry';
        case Need.reason:
          situation = 'why';
        case Need.delivery:
          situation = st.askedWhen ? 'whenAgain' : 'when';
          st.askedWhen = true;
        case Need.compensation:
          situation = st.mood >= 2 ? 'compSoft' : 'comp';
        case Need.close:
          if (closing || st.closed) {
            st.end = st.mood >= 1 ? 'good' : 'fair';
            situation = st.end == 'good' ? 'byeGood' : 'byeFair';
          } else {
            st.closed = true;
            situation = 'settled';
          }
      }
    }
    if (situation == 'settled' && closing) {
      st.end = st.mood >= 1 ? 'good' : 'fair';
      situation = st.end == 'good' ? 'byeGood' : 'byeFair';
    }
    if (st.patience <= 0 && st.end == null) {
      st.end = 'lost';
      situation = 'lost';
    }
    return _record(text, frames, situation);
  }

  Line _record(String text, List<Frame> frames, String situation) {
    final l = _say(situation);
    turns.add(Turn(text, frames, l, situation, st.mood));
    return l;
  }
}

/// the late delivery: Mr Wang ordered a batch three days ago; he needs it by Friday (today is Tuesday)
const lateDelivery = Scenario(
  id: 'late',
  title: 'Pengiriman terlambat',
  client: 'Pak Wang, pembeli',
  today: 1,
  deadline: 3,
  deadlineZh: '星期五',
  deadlineId: 'Jumat',
  minPct: 10,
  patience: 5,
  lines: {
    'open': [
      Line('喂，你好。我订的货已经晚了三天，到底是怎么回事？', 'Halo. Pesanan saya sudah terlambat tiga hari, sebenarnya ada apa?'),
      Line('你好，我是王先生。我们的货怎么还没到？已经晚了三天了。', 'Halo, saya Pak Wang. Kenapa barang kami belum sampai? Sudah terlambat tiga hari.'),
    ],
    'wantSorry': [
      Line('你先别解释。货晚了三天，你们连一句道歉都没有吗？', 'Jangan menjelaskan dulu. Barang terlambat tiga hari, kalian tidak minta maaf sama sekali?'),
      Line('我现在很生气。你们至少应该先道个歉吧？', 'Saya sangat kesal. Setidaknya kalian minta maaf dulu, kan?'),
    ],
    'wantSorry2': [
      Line('我已经说了，你们到现在还没道歉。', 'Saya sudah bilang, sampai sekarang kalian belum minta maaf.'),
      Line('说了半天，一句对不起都没有？', 'Sudah bicara panjang, tidak ada satu pun permintaan maaf?'),
    ],
    'why': [
      Line('好吧。那到底是什么原因晚了？', 'Baiklah. Sebenarnya apa penyebab terlambatnya?'),
      Line('道歉我收到了。可是为什么会晚这么久？', 'Permintaan maafnya saya terima. Tapi kenapa bisa terlambat selama ini?'),
    ],
    'when': [
      Line('明白了。那你们什么时候能送到？我{d}之前一定要用。', 'Saya mengerti. Lalu kapan kalian bisa mengirimnya? Saya harus memakainya sebelum {d}.'),
      Line('原因我知道了。现在最重要的是，货什么时候到？我{d}就要用。', 'Penyebabnya sudah saya tahu. Yang penting sekarang, kapan barangnya tiba? Saya butuh hari {d}.'),
    ],
    'whenAgain': [
      Line('你还是没告诉我哪天能到。', 'Kamu masih belum bilang hari apa barangnya tiba.'),
    ],
    'whichDay': [
      Line('具体哪天能到？我{d}之前必须收到。', 'Tepatnya hari apa tiba? Saya harus menerimanya sebelum {d}.'),
      Line('你说会送，那是哪一天？', 'Katamu akan dikirim, itu hari apa?'),
    ],
    'tooLate': [
      Line('那太晚了。我{d}就要用，能不能快一点？', 'Itu terlalu lambat. Saya butuh hari {d}, bisa lebih cepat?'),
      Line('不行，{d}之后我就用不上了。你们得想想办法。', 'Tidak bisa, setelah {d} barangnya sudah tidak berguna. Kalian harus cari cara.'),
    ],
    'comp': [
      Line('时间可以。可是这次耽误了我们的生产，你们打算怎么补偿？', 'Waktunya bisa. Tapi ini mengganggu produksi kami, bagaimana kalian akan memberi kompensasi?'),
      Line('好，那就这么送。不过晚了这么久，总得给点补偿吧？', 'Baik, kirim begitu saja. Tapi terlambat selama ini, harus ada kompensasi, kan?'),
    ],
    'compSoft': [
      Line('你们的态度我很满意。不过价格上能不能表示一下？', 'Saya puas dengan sikap kalian. Tapi bisakah ada sedikit keringanan harga?'),
    ],
    'howMuch': [
      Line('优惠是多少？打几折？', 'Diskonnya berapa? Berapa persen?'),
    ],
    'lowPct': [
      Line('{p}太少了，至少{m}吧。', '{p} terlalu sedikit, paling tidak {m}.'),
      Line('{p}？这次的损失可不止这些。{m}怎么样？', '{p}? Kerugian kali ini jauh lebih besar. Bagaimana kalau {m}?'),
    ],
    'pushComp': [
      Line('一点补偿都没有？你们这样我很难跟老板交代。', 'Tidak ada kompensasi sama sekali? Kalau begini saya sulit menjelaskan ke atasan.'),
    ],
    'grudge': [
      Line('好吧，这次就算了。希望下次别再这样。', 'Baiklah, kali ini sudahlah. Semoga lain kali tidak begini lagi.'),
    ],
    'deny': [
      Line('我不管是谁的问题，我只要我的货。', 'Saya tidak peduli salah siapa, saya hanya mau barang saya.'),
      Line('推来推去有什么用？你们是卖方，你们负责。', 'Saling lempar tanggung jawab untuk apa? Kalian penjualnya, kalian yang bertanggung jawab.'),
    ],
    'settled': [
      Line('好，那就按你说的办。', 'Baik, kita lakukan seperti katamu.'),
      Line('行，这样我可以接受。', 'Oke, kalau begini saya bisa terima.'),
    ],
    'byeGood': [
      Line('谢谢你，处理得很好。我们以后继续合作。', 'Terima kasih, penanganannya bagus. Kita lanjutkan kerja sama.'),
      Line('好的，辛苦了。再见。', 'Baik, terima kasih atas kerja kerasnya. Sampai jumpa.'),
    ],
    'byeFair': [
      Line('好吧，先这样。再见。', 'Baiklah, sampai di sini dulu. Sampai jumpa.'),
    ],
    'unclear': [
      Line('不好意思，我没听清楚，请你再说一遍。', 'Maaf, saya kurang jelas, tolong ulangi.'),
      Line('你说什么？我没明白。', 'Kamu bilang apa? Saya tidak mengerti.'),
    ],
    'lost': [
      Line('算了，我直接找你们经理。', 'Sudahlah, saya langsung bicara dengan manajer kalian.'),
      Line('这样的话，我们以后就不合作了。', 'Kalau begini, kami tidak akan bekerja sama lagi.'),
    ],
    'fair': [
      Line('好吧，先这样吧。', 'Baiklah, begitu saja dulu.'),
    ],
    'bye': [
      Line('再见。', 'Sampai jumpa.'),
    ],
  },
);
