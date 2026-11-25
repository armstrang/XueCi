/// BCT study (v1.12): the business words as a path like HSK's: the list, cards and a quiz, for BCT A or B.
/// Extra practice only: progress is kept in `xc_bct` (app/bct_prog.dart) and never changes the realm or the plan.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/bct.dart';
import 'bct_stats.dart';
import 'bct_words.dart';
import 'focus.dart';
import 'glass.dart';
import 'home.dart' show HomeHeader;
import 'icons.dart';
import 'run_view.dart' show OptBtn, qtIcon;
import 'splash.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

@visibleForTesting
int? bctStudySeed;

/// the HSK | BCT switch at the top of Home and of the BCT screen
class StudyPick extends StatelessWidget {
  final bool bct;
  const StudyPick({super.key, required this.bct});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    Widget seg(String label, bool on, VoidCallback f) => Press(
      onTap: on ? () {} : f,
      scale: .95,
      selected: on,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? th.acc.withValues(alpha: .2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: F.s(13.5, w: FontWeight.w800, c: p.fg),
        ),
      ),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: splashPlaying,
      builder: (_, playing, child) => Visibility(
        visible: !playing,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child!,
      ),
      child: Glass(
        frost: true,
        radius: 999,
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('HSK', !bct, () => app.setStudy('hsk')),
            seg('BCT', bct, () => app.setStudy('bct')),
          ],
        ),
      ),
    );
  }
}

class BctStudyScreen extends StatefulWidget {
  const BctStudyScreen({super.key});
  @override
  State<BctStudyScreen> createState() => _BctStudyState();
}

enum _QuizKind { meaning, recall, listen, tone, sentence }

class _Q {
  final BctW w;
  final _QuizKind kind;
  final List<String> opts;
  final int ans;
  int? pick;
  _Q(this.w, this.kind, this.opts, this.ans);
}

class _BctStudyState extends State<BctStudyScreen> {
  String mode = 'home'; // home | cards | quiz | done
  List<BctW> deck = [];
  int i = 0, right = 0;
  _Q? _cardCheck;
  String? _cardResult;
  bool _cardHeard = false;
  final Set<String> _requeued = {};
  List<_Q> qs = [];
  String kind = 'cards';
  _QuizKind? _quizKind;
  final _rnd = math.Random(bctStudySeed);

  @override
  void initState() {
    super.initState();
    app.backHook = _back;
    // a new rank is told once (the first time only the rank is noted)
    final r = app.bctInfo.rank, seen = app.note['bctr'];
    if (seen is! num || seen != r) {
      app.note['bctr'] = r;
      app.saveNote();
      if (seen is num && r > seen) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => app.toast(app.t.brUp(rankMeaning(r)), 3200),
        );
      }
    }
  }

  @override
  void dispose() {
    if (app.backHook == _back) app.backHook = null;
    super.dispose();
  }

  String _beforeWords = 'home';

  void _openWords() {
    _beforeWords = mode;
    setState(() => mode = 'words');
  }

  bool _back() {
    if (mode == 'words') {
      setState(() => mode = _beforeWords);
      return true;
    }
    if (mode != 'home') {
      setState(() => mode = 'home');
      return true;
    }
    return false;
  }

  String _m(BctW w) => w.t[app.lang] ?? w.t['en'] ?? w.t['id'] ?? '';
  String _id(BctW w) => w.h;
  List<BctW> get _words => app.lm.bct?.wordsOf(app.bctBook) ?? const [];

  /// 12 words: the ones that have faded most first, then new ones
  List<BctW> _pick(int n) {
    final all = [..._words]..shuffle(_rnd);
    final seen = all.where((w) => app.bprog.seen(_id(w))).toList()
      ..sort(
        (a, b) => app.bprog.recall(_id(a)).compareTo(app.bprog.recall(_id(b))),
      );
    final fresh = all.where((w) => !app.bprog.seen(_id(w))).toList();
    final due = seen.where((w) => app.bprog.due(_id(w))).toList();
    final out = <BctW>[...due.take(n)];
    for (final w in fresh) {
      if (out.length >= n) break;
      out.add(w);
    }
    for (final w in seen) {
      if (out.length >= n) break;
      if (!out.contains(w)) out.add(w);
    }
    return out..shuffle(_rnd);
  }

  void _startCards() => _openCards(_pick(12), 'cards');

  void _startReview() {
    final due = [
      for (final word in _words)
        if (app.bprog.reviewAt(_id(word)) case final minute?)
          if (minute <= app.lm.now()) (word, minute),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    _openCards([for (final (word, _) in due) word], 'review');
  }

  void _openCards(List<BctW> words, String type) {
    deck = words;
    i = 0;
    right = 0;
    _resetCard();
    _requeued.clear();
    kind = type;
    setState(() => mode = deck.isEmpty ? 'home' : 'cards');
  }

  List<String> _toneChoices(String pinyin) {
    for (var i = 0; i < pinyin.length; i++) {
      for (final row in const [
        'āáǎà',
        'ēéěè',
        'īíǐì',
        'ōóǒò',
        'ūúǔù',
        'ǖǘǚǜ',
        'ĀÁǍÀ',
        'ĒÉĚÈ',
        'ĪÍǏÌ',
        'ŌÓǑÒ',
        'ŪÚǓÙ',
        'ǕǗǙǛ',
      ]) {
        if (row.contains(pinyin[i])) {
          return [
            for (final mark in row.split(''))
              pinyin.replaceRange(i, i + 1, mark),
          ];
        }
      }
    }
    return const [];
  }

  bool _supports(BctW word, _QuizKind kind) => switch (kind) {
    _QuizKind.tone => _toneChoices(word.p).isNotEmpty,
    _QuizKind.sentence => word.z?.contains(word.h) ?? false,
    _QuizKind.meaning => _m(word).isNotEmpty,
    _ => true,
  };

  List<_QuizKind> get _available => [
    _QuizKind.meaning,
    _QuizKind.recall,
    if (app.canSpeak()) _QuizKind.listen,
    if (_words.any((word) => _supports(word, _QuizKind.tone))) _QuizKind.tone,
    if (_words.any((word) => _supports(word, _QuizKind.sentence)))
      _QuizKind.sentence,
  ];

  void _startQuiz() {
    final available = _available;
    final selected = _quizKind;
    final modes = selected != null && available.contains(selected)
        ? [selected]
        : available;
    final preferred = _pick(10);
    final pool = [..._words]..shuffle(_rnd);
    final remaining = [
      ...preferred,
      ...pool.where((word) => !preferred.contains(word)),
    ];
    final planned = List.generate(
      preferred.length,
      (index) => modes[index % modes.length],
    )..shuffle(_rnd);
    qs = [];
    for (final kind in planned) {
      final index = remaining.indexWhere((word) => _supports(word, kind));
      if (index == -1) continue;
      final word = remaining.removeAt(index);
      final meaning = kind == _QuizKind.meaning;
      final answer = kind == _QuizKind.tone
          ? word.p
          : meaning
          ? _m(word)
          : word.h;
      final choices = kind == _QuizKind.tone
          ? _toneChoices(word.p)
          : [
              answer,
              ...pool
                  .map((other) => meaning ? _m(other) : other.h)
                  .where((value) => value.isNotEmpty && value != answer)
                  .toSet()
                  .take(3),
            ];
      choices.shuffle(_rnd);
      qs.add(_Q(word, kind, choices, choices.indexOf(answer)));
    }
    i = 0;
    right = 0;
    kind = 'quiz';
    setState(() => mode = qs.isEmpty ? 'home' : 'quiz');
  }

  String _label(_QuizKind? kind) => switch (kind) {
    null => switch (app.lang) {
      'id' => 'Campuran',
      'th' => 'รวม',
      'vi' => 'Hỗn hợp',
      _ => 'Mixed',
    },
    _QuizKind.meaning => app.t.tMean,
    _QuizKind.recall => app.t.tHz,
    _QuizKind.listen => app.t.tListen,
    _QuizKind.tone => app.t.tTone,
    _QuizKind.sentence => app.t.tCloze,
  };

  String _icon(_QuizKind? kind) => switch (kind) {
    _QuizKind.recall => 'f',
    _QuizKind.listen => 'l',
    _QuizKind.tone => 's',
    _QuizKind.sentence => 'c',
    _ => 'm',
  };

  Widget _quizPicker(Th th) => Press(
    label: '${app.t.qTypeL}: ${_label(_quizKind)}',
    onTap: () async {
      app.menuOpen = true;
      app.changed();
      try {
        final result = await openMenu<(_QuizKind?,)>(
          context,
          (menu) => SingleChildScrollView(
            child: Column(
              children: [
                for (final type in [null, ..._available])
                  Press(
                    label: _label(type),
                    selected: type == _quizKind,
                    onTap: () => Navigator.pop(menu, (type,)),
                    child: ListTile(
                      title: Text(_label(type), style: F.s(14, c: th.p.fg)),
                      leading: qtIcon(_icon(type), th.p.fg),
                      trailing: type == _quizKind
                          ? Icon2(I.check, size: 18, color: th.acc)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
        if (mounted && result != null && result.$1 != _quizKind) {
          _quizKind = result.$1;
          _startQuiz();
        }
      } finally {
        app.menuOpen = false;
        app.changed();
      }
    },
    child: Glass(
      radius: 22,
      width: 58,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          qtIcon(_icon(_quizKind), th.p.fg),
          const SizedBox(width: 2),
          Icon2(I.chev, size: 12, color: th.p.mute),
        ],
      ),
    ),
  );

  void _resetCard() {
    _cardCheck = null;
    _cardResult = null;
    _cardHeard = false;
  }

  void _claimCard(BctW word) {
    final seen = app.bprog.seen(_id(word));
    if (_rnd.nextDouble() < (seen ? .35 : .65)) {
      final tones = _cardHeard ? <String>[] : _toneChoices(word.p);
      final tone = tones.isNotEmpty && _rnd.nextBool();
      final answer = tone ? word.p : _m(word);
      final pool = [..._words]..shuffle(_rnd);
      final choices = tone
          ? tones
          : [
              answer,
              ...pool
                  .map(_m)
                  .where((x) => x.isNotEmpty && x != answer)
                  .toSet()
                  .take(3),
            ];
      if (answer.isNotEmpty && choices.length > 1) {
        choices.shuffle(_rnd);
        setState(
          () => _cardCheck = _Q(
            word,
            tone ? _QuizKind.tone : _QuizKind.meaning,
            choices,
            choices.indexOf(answer),
          ),
        );
        return;
      }
    }
    _cardAnswer('trust');
  }

  void _cardAnswer(String result) {
    if (_cardResult != null) return;
    final word = deck[i];
    final ok = result == 'ok' || result == 'trust';
    app.bprog.answer(_id(word), ok, verified: result != 'trust');
    setState(() {
      _cardResult = result;
      if (ok) {
        right++;
      } else if (_requeued.add(_id(word))) {
        deck.insert(math.min(i + 5, deck.length), word);
      }
    });
  }

  void _cardNext() {
    setState(() {
      if (i + 1 >= deck.length) {
        mode = 'done';
      } else {
        i++;
        _resetCard();
      }
    });
  }

  void _quizPick(int k) {
    final q = qs[i];
    if (q.pick != null) return;
    final ok = k == q.ans;
    app.bprog.answer(_id(q.w), ok);
    if (ok) right++;
    setState(() => q.pick = k);
  }

  void _quizNext() {
    if (i + 1 >= qs.length) {
      setState(() => mode = 'done');
    } else {
      setState(() => i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    app.backHook = _back;
    if (mode == 'words') {
      return BctWordsPage(app.bctBook, onBack: _back);
    }
    final bottom = MediaQuery.paddingOf(context).bottom + 98;
    Widget body = switch (mode) {
      'cards' => _cards(th),
      'quiz' => _quiz(th),
      'done' => _done(th),
      _ => _home(th),
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mode == 'home') ...[
                const HomeHeader(short: false),
                const SizedBox(height: 16),
                Rise(
                  1,
                  child: Semantics(
                    header: true,
                    child: Text(
                      t.bsTitle,
                      style: F.s(28, w: FontWeight.w800, c: p.fg, ls: -.5),
                    ),
                  ),
                ),
              ] else
                Capsule(
                  title: mode == 'cards'
                      ? t.card
                      : t.bsBook(app.bctBook.toUpperCase()),
                  lead: [
                    if (mode == 'quiz') _quizPicker(th),
                    if (mode == 'cards')
                      Glass(
                        radius: 999,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Text(
                          t.bsBook(app.bctBook.toUpperCase()),
                          style: F.s(15, w: FontWeight.w800, c: th.acc),
                        ),
                      ),
                  ],
                  onBack: () => setState(() => mode = 'home'),
                ),
              const SizedBox(height: 14),
              if (mode == 'home') Rise(2, child: body) else body,
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ home
  Widget _reviewSchedule(Th th) {
    final ids = _words.map(_id).toSet();
    final now = app.lm.now();
    final ready = ids
        .where((id) => (app.bprog.reviewAt(id) ?? double.infinity) <= now)
        .length;
    final counts = app.bprog.reviewDays(ids);
    final n = app.fmt(ready);
    final reviewLabel = switch (app.lang) {
      'id' => 'Ulangi $n kata',
      'th' => 'ทบทวน $n คำ',
      'vi' => 'Ôn $n từ',
      _ => 'Review $n ${ready == 1 ? 'word' : 'words'}',
    };
    final highest = counts.fold<int>(0, math.max);
    final (title, today, tomorrow, empty) = switch (app.lang) {
      'id' => (
        'Jadwal ulang',
        'Hari ini',
        'Besok',
        'Belum ada kata yang dijadwalkan dalam 7 hari.',
      ),
      'th' => (
        'กำหนดทบทวน',
        'วันนี้',
        'พรุ่งนี้',
        'ไม่มีคำที่กำหนดให้ทบทวนใน 7 วัน',
      ),
      'vi' => (
        'Lịch ôn tập',
        'Hôm nay',
        'Ngày mai',
        'Chưa có từ cần ôn trong 7 ngày tới.',
      ),
      _ => (
        'Review forecast',
        'Today',
        'Tomorrow',
        'No reviews scheduled in the next 7 days.',
      ),
    };
    final p = th.p;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: F.s(16, w: FontWeight.w800, c: p.fg),
          ),
          const SizedBox(height: 8),
          Text(
            '$today ${app.fmt(counts[0])}  ·  $tomorrow ${app.fmt(counts[1])}',
            style: F.s(13, c: p.soft),
          ),
          const SizedBox(height: 10),
          if (highest == 0)
            Text(empty, style: F.s(12.5, c: p.mute))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (day, count) in counts.indexed)
                  Expanded(
                    child: Semantics(
                      label:
                          '${day == 0
                              ? today
                              : day == 1
                              ? tomorrow
                              : '+$day'} · $count',
                      child: Column(
                        children: [
                          Text(app.fmt(count), style: F.s(11, c: p.soft)),
                          const SizedBox(height: 4),
                          Container(
                            width: 10,
                            height: count == 0 ? 2 : 4 + 40 * count / highest,
                            decoration: BoxDecoration(
                              color: count == 0 ? p.line : th.acc,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day == 0 ? '0' : '+$day',
                            style: F.s(11, c: p.mute),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (ready > 0) ...[
            const SizedBox(height: 12),
            MainBtn(reviewLabel, wide: true, radius: 16, onTap: _startReview),
          ],
        ],
      ),
    );
  }

  Widget _home(Th th) {
    final p = th.p;
    final t = app.t;
    final ws = _words;
    Widget book(String b) {
      final on = app.bctBook == b;
      final n = app.lm.bct?.wordsOf(b).length ?? 0;
      return Expanded(
        child: Press(
          onTap: () => setState(() => app.bctBook = b),
          scale: .96,
          selected: on,
          label: '${t.bsBook(b.toUpperCase())}, ${t.bwCount(app.fmt(n))}',
          child: Tile(
            radius: 20,
            color: on ? th.acc.withValues(alpha: .14) : null,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  t.bsBook(b.toUpperCase()),
                  style: F.s(17, w: FontWeight.w800, c: on ? th.acc : p.fg),
                ),
                Text(t.bwCount(app.fmt(n)), style: F.s(12.5, c: p.soft)),
              ],
            ),
          ),
        ),
      );
    }

    Widget tile(String label, Widget icon, VoidCallback f) => Expanded(
      child: Press(
        onTap: ws.isEmpty ? () {} : f,
        label: label,
        child: Glass(
          radius: 22,
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: F.s(13, w: FontWeight.w800, c: p.fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.bsSub, style: F.s(14, c: p.soft, h: 1.4)),
            const SizedBox(height: 14),
            Row(children: [book('a'), const SizedBox(width: 10), book('b')]),
            const SizedBox(height: 14),
            const BctRankCard(),
            const SizedBox(height: 14),
            _reviewSchedule(th),
            const SizedBox(height: 14),
          ],
        ),
        Column(
          children: [
            Row(
              children: [
                tile(
                  t.list,
                  Icon2(I.list, size: 22, color: th.acc, width: 1.9),
                  _openWords,
                ),
                const SizedBox(width: 10),
                tile(
                  t.card,
                  Icon2(I.cards, size: 22, color: th.acc, width: 1.9),
                  _startCards,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                tile(
                  t.quiz,
                  Icon2(I.quiz, size: 22, color: th.acc, width: 1.9),
                  _startQuiz,
                ),
                const SizedBox(width: 10),
                tile(
                  t.gram,
                  MediaQuery.withNoTextScaling(
                    child: Text(
                      '语',
                      locale: const Locale('zh', 'CN'),
                      style: F.s(
                        21,
                        w: FontWeight.w800,
                        c: th.acc,
                        family: F.zh,
                        h: 1.05,
                      ),
                    ),
                  ),
                  () {
                    app.gramBook = 'bct';
                    app.go('grammar');
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ cards
  Widget _count(Th th, int n, int total) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : n / total,
              minHeight: 6,
              backgroundColor: th.p.sunk,
              valueColor: AlwaysStoppedAnimation(th.acc),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${n + 1}/$total',
          style: F.s(13, w: FontWeight.w700, c: th.p.soft, feat: F.tab),
        ),
      ],
    ),
  );

  Widget _cards(Th th) {
    final p = th.p;
    final t = app.t;
    final word = deck[i];
    final result = _cardResult;
    final check = _cardCheck;
    final mq = MediaQuery.of(context);
    final height = result == null && check != null
        ? 228.0
        : (mq.size.height - mq.padding.vertical - 365).clamp(280.0, 520.0);
    final message = switch (result) {
      'ok' => t.resOk,
      'over' => t.resOver,
      'no' => t.resNo,
      _ => t.resTrust,
    };
    final color = switch (result) {
      'ok' => p.good,
      'over' => p.bad,
      _ => p.soft,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _count(th, i, deck.length),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: height,
          child: Glass(
            solid: true,
            radius: 32,
            padding: const EdgeInsets.all(22),
            child: result == null
                ? Stack(
                    children: [
                      if (!app.bprog.seen(_id(word)))
                        Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            t.newWord,
                            style: F.s(12.5, w: FontWeight.w800, c: th.acc),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                word.h,
                                locale: const Locale('zh', 'CN'),
                                style: F.s(
                                  word.h.length > 2 ? 82 : 120,
                                  family: F.hz,
                                  w: FontWeight.w900,
                                  h: 1,
                                  c: p.fg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Spk(
                              word.h,
                              size: 46,
                              onSpoken: () => _cardHeard = true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                word.h,
                                style: F.s(
                                  52,
                                  family: F.hz,
                                  w: FontWeight.w900,
                                  c: th.acc,
                                ),
                              ),
                              Text(
                                word.p,
                                style: F.s(16, w: FontWeight.w700, c: p.soft),
                              ),
                              Spk(word.h, size: 34),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _m(word),
                            style: F.s(20, w: FontWeight.w800, c: p.fg),
                          ),
                          if (word.z != null) ...[
                            const SizedBox(height: 10),
                            Divider(height: 1, color: p.line),
                            const SizedBox(height: 12),
                            BctExample(word, small: true),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (result != null) ...[
          Semantics(
            liveRegion: true,
            child: Glass(
              radius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              color: color.withValues(alpha: .10),
              child: Rich(
                message,
                style: F.s(13.5, w: FontWeight.w700, c: color),
              ),
            ),
          ),
          const SizedBox(height: 10),
          MainBtn(t.next, wide: true, big: true, onTap: _cardNext),
        ] else if (check != null)
          Glass(
            radius: 22,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  check.kind == _QuizKind.tone ? t.chkTone : t.chkMean,
                  textAlign: TextAlign.center,
                  style: F.s(13, w: FontWeight.w800, c: th.acc),
                ),
                for (final (index, option) in check.opts.indexed) ...[
                  const SizedBox(height: 8),
                  OptBtn(
                    n: index,
                    label: Text(option),
                    onTap: () =>
                        _cardAnswer(index == check.ans ? 'ok' : 'over'),
                  ),
                ],
              ],
            ),
          )
        else ...[
          Text(
            t.fcHint,
            textAlign: TextAlign.center,
            style: F.s(15, c: p.soft, h: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GhostBtn(
                  t.fcDont,
                  wide: true,
                  onTap: () => _cardAnswer('no'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MainBtn(
                  t.fcKnow,
                  wide: true,
                  big: true,
                  onTap: () => _claimCard(word),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ quiz
  Widget _quiz(Th th) {
    final p = th.p;
    final t = app.t;
    final q = qs[i];
    final done = q.pick != null;
    final tile =
        q.opts.length == 4 &&
        q.kind != _QuizKind.meaning &&
        q.kind != _QuizKind.sentence;
    Widget opt(int index) => OptBtn(
      key: ValueKey('bct-quiz-option-$index'),
      n: index + 1,
      tile: tile,
      label: Text(
        q.opts[index],
        textAlign: tile ? TextAlign.center : TextAlign.start,
        style: F.s(
          tile ? 22 : 16,
          family: q.kind == _QuizKind.meaning || q.kind == _QuizKind.tone
              ? F.ui
              : F.hz,
          w: FontWeight.w700,
          c: p.fg,
        ),
      ),
      state: !done
          ? null
          : index == q.ans
          ? true
          : index == q.pick
          ? false
          : null,
      picked: done && index == q.pick,
      onTap: done ? null : () => _quizPick(index),
    );
    final prompt = switch (q.kind) {
      _QuizKind.meaning => t.bsQM,
      _QuizKind.recall => t.bsQH,
      _QuizKind.listen => t.listen,
      _QuizKind.tone => t.qTone,
      _QuizKind.sentence => t.tCloze,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _count(th, i, qs.length),
        Glass(
          solid: true,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(
            children: [
              Text(
                prompt,
                style: F.s(13, w: FontWeight.w700, c: p.mute),
              ),
              const SizedBox(height: 10),
              if (q.kind == _QuizKind.meaning || q.kind == _QuizKind.tone) ...[
                Text(
                  q.w.h,
                  textAlign: TextAlign.center,
                  style: F.s(39, family: F.hz, c: p.fg),
                ),
                if (q.kind == _QuizKind.meaning || done)
                  Text(q.w.p, style: F.s(16, c: p.soft)),
                if (q.kind == _QuizKind.meaning) Spk(q.w.h, size: 36),
              ] else if (q.kind == _QuizKind.listen)
                Spk(q.w.h, size: 42)
              else ...[
                if (q.kind == _QuizKind.sentence) ...[
                  Text(
                    q.w.z!.replaceAll(q.w.h, '＿＿'),
                    textAlign: TextAlign.center,
                    style: F.s(23, family: F.hz, c: p.fg),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  _m(q.w),
                  textAlign: TextAlign.center,
                  style: F.s(19, c: p.fg),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (tile) ...[
          for (var k = 0; k < q.opts.length; k += 2) ...[
            Row(
              children: [
                Expanded(child: opt(k)),
                const SizedBox(width: 10),
                Expanded(child: opt(k + 1)),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ] else
          for (var k = 0; k < q.opts.length; k++) ...[
            opt(k),
            const SizedBox(height: 10),
          ],
        if (done)
          MainBtn(
            t.bsNext,
            wide: true,
            radius: 16,
            big: true,
            onTap: _quizNext,
          ),
      ],
    );
  }

  // ------------------------------------------------------------ end
  Widget _done(Th th) {
    final p = th.p;
    final t = app.t;
    final total = kind == 'quiz' ? qs.length : deck.length;
    return Glass(
      solid: true,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.bsDone,
            textAlign: TextAlign.center,
            style: F.s(22, w: FontWeight.w800, c: p.fg),
          ),
          const SizedBox(height: 8),
          Text(
            t.bsScore(right, total),
            textAlign: TextAlign.center,
            style: F.s(16, c: p.soft),
          ),
          const SizedBox(height: 20),
          MainBtn(
            kind == 'review' ? t.back : t.bsAgain,
            wide: true,
            radius: 16,
            onTap: switch (kind) {
              'review' => _back,
              'quiz' => _startQuiz,
              _ => _startCards,
            },
          ),
          const SizedBox(height: 10),
          GhostBtn(t.bsWordsBtn, wide: true, onTap: _openWords),
        ],
      ),
    );
  }
}
