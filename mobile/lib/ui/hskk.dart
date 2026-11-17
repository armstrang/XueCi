/// HSKK (v1.4): the speaking tab and its runs.
///
/// The tab: the level as a glass lens (Dasar, Menengah, Lanjutan; a level opens with the learner's HSK level), the
/// practice path (three or four stations joined by a line) and the mock test as one card. A run (screen 'hkrun', no
/// tab bar) is practice of one part or a whole mock test: listen (the phone's TTS) or get ready, then speak (the
/// phone's recognizer, offline first), then the marks: per hanzi for a repeat or a text read aloud, keywords,
/// length and the level's words for a retell or an answer. A repeat can be checked for tones (tone.dart). In a mock
/// test nothing is marked until the end, every item has its own clock, and the music is off.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/hskk.dart';
import '../app/native.dart';
import '../app/speech.dart';
import '../app/tone.dart';
import 'glass.dart';
import 'icons.dart';
import 'lens.dart';
import 'sheet.dart';
import 'splash.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

String hkName(int lv) => switch (lv) {
  1 => app.t.hkL1,
  2 => app.t.hkL2,
  _ => app.t.hkL3,
};

String hkKindName(String k) => switch (k) {
  'r' || 'x' => app.t.hkKr,
  's' => app.t.hkKs,
  't' => app.t.hkKt,
  _ => app.t.hkKq,
};

String hkKindShort(String k) => switch (k) {
  'r' || 'x' => app.t.hkSr,
  's' => app.t.hkSs,
  't' => app.t.hkSt,
  _ => app.t.hkSq,
};

String _kindHan(String k) => const {'r': '听', 'x': '听', 's': '述', 't': '读', 'q': '答'}[k] ?? '说';

/// about how long a mock test takes, in minutes
int hkMockMin(int lv) => const [0, 13, 16, 20][lv];

int hkMockN(int lv) => hkPaper(lv).fold(0, (a, p) => a + p.$2);

// =================================================================== the tab
class HskkScreen extends StatelessWidget {
  const HskkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lv = app.hkLv.clamp(1, 3);
    final open = app.hkOpenTo;
    final locked = lv > open;
    final bottom = MediaQuery.paddingOf(context).bottom + 10 + 64 + 18;
    final kinds = [...hkKinds(lv), if (lv > 1) 'x'];
    final hist = [for (final m in app.spkLog.mocks) if (m[1] == lv) m];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottom),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(t.hkTitle, style: F.s(31, w: FontWeight.w800, c: p.fg, ls: -.6))),
                    const SizedBox(height: 2),
                    Text(t.hkSub, style: F.s(14, c: p.soft)),
                  ],
                ),
              ),
              const _Seal('声', size: 46),
            ],
          ),
          if (!app.canListen) ...[
            const SizedBox(height: 12),
            _Note(t.hkNoListen, warn: true),
          ],
          const SizedBox(height: 16),
          Rise(1, child: _LevelLens(lv: lv, open: open)),
          const SizedBox(height: 8),
          Text(
            locked ? t.hkLocked(hkBand(lv)) : t.hkFollows(hkBand(lv)),
            style: F.s(12.5, c: locked ? p.bad : p.mute, h: 1.4),
          ),
          const SizedBox(height: 18),
          Text(t.hkPath, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.2)),
          const SizedBox(height: 10),
          Rise(2,
            child: Stack(
              children: [
                Positioned(
                  left: 21,
                  top: 28,
                  bottom: 28,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [th.acc, p.line]),
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (var i = 0; i < kinds.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _Station(lv: lv, k: kinds[i], first: i == 0, locked: locked),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Rise(3, child: _MockCard(lv: lv, locked: locked, last: hist.isEmpty ? null : (hist.last[2] as num).toInt())),
          const SizedBox(height: 12),
          Text(t.hkNote, style: F.s(12, c: p.mute, h: 1.4)),
        ],
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  final String ch;
  final double size;
  const _Seal(this.ch, {this.size = 44});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: -.07,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xffd9482b),
          borderRadius: BorderRadius.circular(size * .22),
          boxShadow: const [BoxShadow(color: Color(0x55d9482b), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Text(ch, style: F.s(size * .56, family: F.hz, w: FontWeight.w600, c: const Color(0xfffbe9dd), h: 1)),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;
  final bool warn;
  const _Note(this.text, {this.warn = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: (warn ? p.gold : p.good).withValues(alpha: .12),
      child: Text(text, style: F.s(13.5, c: p.fg, h: 1.4)),
    );
  }
}

class _LevelLens extends StatelessWidget {
  final int lv, open;
  const _LevelLens({required this.lv, required this.open});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    const hz = ['初', '中', '高'];
    return Glass(
      radius: 999,
      child: LensRow(
        count: 3,
        selected: lv - 1,
        height: 52,
        onSelect: (i) => _pick(i + 1),
        lens: (c, sel, drag) => HskLens(lc: th.acc, radius: 22),
        item: (c, i, on) {
          final l = i + 1;
          final shut = l > open;
          return Press(
            onTap: () => _pick(l),
            label: '${hkName(l)}, ${hkBand(l)}',
            selected: on,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shut) ...[Icon2(I.lock, size: 13, color: p.mute), const SizedBox(width: 4)],
                    Text(hz[i], style: F.s(13, family: F.hz, w: FontWeight.w600, c: on ? p.fg : p.soft)),
                    const SizedBox(width: 4),
                    Text(hkName(l), style: F.s(14, w: on ? FontWeight.w800 : FontWeight.w600, c: shut ? p.mute : (on ? p.fg : p.soft))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _pick(int l) {
    HapticFeedback.selectionClick();
    app.hkLv = l;
    app.saveUI();
    app.changed();
  }
}

class _Station extends StatelessWidget {
  final int lv;
  final String k;
  final bool first, locked;
  const _Station({required this.lv, required this.k, required this.first, required this.locked});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final n = app.spkLog.count(lv, k);
    final desc = switch (k) {
      'r' || 'x' => t.hkDr,
      's' => t.hkDs,
      't' => t.hkDt,
      _ => t.hkDq,
    };
    return Press(
      onTap: locked ? () => app.toast(t.hkLocked(hkBand(lv))) : () => app.startHk(lv, k: k),
      label: '${hkKindName(k)}. $desc',
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: first ? th.acc : p.bg,
              border: Border.all(color: first ? th.acc : p.line, width: 1.5),
              boxShadow: first ? [BoxShadow(color: th.acc.withValues(alpha: .25), spreadRadius: 5)] : null,
            ),
            child: Text(_kindHan(k), style: F.s(20, family: F.hz, w: FontWeight.w600, c: first ? p.onAcc : p.fg, h: 1)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Glass(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hkKindName(k), style: F.s(15.5, w: FontWeight.w800, c: p.fg)),
                        const SizedBox(height: 2),
                        Text(desc, style: F.s(12.5, c: p.soft, h: 1.3)),
                      ],
                    ),
                  ),
                  if (n > 0) Text(t.hkDone(n), style: F.s(12, w: FontWeight.w700, c: th.acc)),
                  const SizedBox(width: 4),
                  RotatedBox(quarterTurns: 3, child: Icon2(I.chev, size: 14, color: p.mute, width: 2.2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final int lv;
  final bool locked;
  final int? last;
  const _MockCard({required this.lv, required this.locked, required this.last});
  @override
  Widget build(BuildContext context) {
    final t = app.t;
    final sub = '${t.hkMockS(hkMockN(lv), hkMockMin(lv))}${last == null ? '' : ' · ${t.hkLast('$last')}'}';
    return Press(
      onTap: locked ? () => app.toast(t.hkLocked(hkBand(lv))) : () => app.startHk(lv, mock: true),
      label: '${t.hkMockTitle}, ${hkName(lv)}. $sub',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xffa23a2c), Color(0xff5b3f9e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -6,
                top: -26,
                child: ExcludeSemantics(child: Opacity(opacity: .1, child: Text('考', style: F.s(96, family: F.hz, c: Colors.white, h: 1)))),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.hkMockT, style: F.s(12, w: FontWeight.w800, c: Colors.white.withValues(alpha: .78), ls: 1.2)),
                  const SizedBox(height: 4),
                  Text('HSKK ${hkName(lv)}', style: F.s(20, w: FontWeight.w800, c: Colors.white)),
                  const SizedBox(height: 2),
                  Text(sub, style: F.s(13, c: Colors.white.withValues(alpha: .86))),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    child: Text(t.hkStart, style: F.s(15, w: FontWeight.w800, c: const Color(0xff1b1330))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================== a run: practice or a mock test
class HkRunScreen extends StatefulWidget {
  const HkRunScreen({super.key});
  @override
  State<HkRunScreen> createState() => _HkRunState();
}

/// what the screen shows: the mock's opening, a part's card, listening to the text, getting ready, speaking, the
/// marks of one item, the tone check, the end of a practice round, the mock's result
enum _Ph { load, intro, part, listen, prep, speak, result, tone, end, mockEnd }

/// screenshots: a finished mock test to show
@visibleForTesting
HkMock? hkTestMock;

class _HkRunState extends State<HkRunScreen> {
  late final ({int lv, String k, bool mock}) run = app.hkRun ?? (lv: app.hkLv, k: hkKinds(app.hkLv).first, mock: false);
  _Ph ph = _Ph.load;
  List<HkTask> tasks = [];
  int i = 0;
  HkMock? mock;

  // the clock of the moment (getting ready, speaking); a played text
  Timer? _tick;
  int left = 0, total = 0;
  int played = 0;
  bool showText = false, showPy = false, showTr = false;
  int? _speakStart;

  // listening
  bool busy = false;
  final level = ValueNotifier<double>(0);
  String partial = '';
  SpeakResult? live; // a text read aloud: what has been read so far
  bool noListen = false;

  // the tone check
  bool toneBusy = false;
  ToneResult? tone;

  HkTask get task => tasks[i];
  SpkItem get it => task.it;

  @override
  void initState() {
    super.initState();
    app.backHook = _back;
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    Native.I.ttsDone = null;
    if (busy) Native.I.listenStop();
    if (toneBusy) Native.I.recStop();
    Native.I.stopSpeaking();
    Native.I.listenEv = null;
    level.dispose();
    if (app.backHook == _back) app.backHook = null;
    if (app.inExam) {
      app.inExam = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => app.changed());
    }
    super.dispose();
  }

  Future<void> _load() async {
    final bank = await app.loadSpk();
    if (!mounted) return;
    final log = app.spkLog;
    if (run.mock && hkTestMock != null) {
      tasks = hkTestMock!.tasks;
      mock = hkTestMock;
      setState(() => ph = _Ph.mockEnd);
      return;
    }
    if (run.mock) {
      final ts = <HkTask>[];
      for (final (k, n) in hkPaper(run.lv)) {
        for (final x in log.take(bank.of(run.lv, k), n, mock: true)) {
          ts.add(HkTask(x));
        }
      }
      tasks = ts;
      mock = HkMock(run.lv, ts, app.lm.now());
      app.saveSpk();
      setState(() => ph = _Ph.intro);
    } else {
      _practiceRound(bank);
    }
  }

  void _practiceRound(SpkBank bank) {
    final n = switch (run.k) {
      'r' || 'x' => 5,
      's' || 'q' => 2,
      _ => 1,
    };
    tasks = [for (final x in app.spkLog.take(bank.of(run.lv, run.k), n)) HkTask(x)];
    app.saveSpk();
    i = 0;
    if (tasks.isEmpty) {
      app.go(app.hkFrom);
      return;
    }
    _enter();
  }

  // ------------------------------------------------------------ flow
  void _enter() {
    _tick?.cancel();
    tone = null;
    live = null;
    partial = '';
    played = 0;
    showText = false;
    showTr = false;
    showPy = it.lv == 1 && !run.mock;
    noListen = false;
    final k = it.k;
    if (k == 'r' || k == 'x' || k == 's') {
      setState(() => ph = _Ph.listen);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && ph == _Ph.listen && played == 0) _play();
      });
    } else {
      _countdown(_Ph.prep, run.mock || k == 't' ? hkPrepSec(k, it.lv) : hkPrepSec(k, it.lv), then: _speak);
    }
  }

  void _countdown(_Ph phase, int secs, {required VoidCallback then}) {
    _tick?.cancel();
    setState(() {
      ph = phase;
      left = secs;
      total = secs;
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return tm.cancel();
      setState(() => left = math.max(0, left - 1));
      if (left <= 0) {
        tm.cancel();
        then();
      }
    });
  }

  /// reads the text out (TTS); a mock test then listens by itself
  Future<void> _play({bool slow = false}) async {
    if (!app.ttsOK) {
      await speak(it.zh); // opens the guide when the voice is missing
      return;
    }
    final maxPlays = it.k == 's' ? (run.mock ? 1 : 2) : (run.mock ? 1 : 99);
    if (played >= maxPlays) return;
    setState(() => played++);
    final done = Completer<void>();
    Native.I.ttsDone = () {
      if (!done.isCompleted) done.complete();
    };
    // whatever the engine reports, go on after a generous estimate of the reading time
    final est = Duration(milliseconds: (it.chars / (slow ? 2.4 : 3.4) * 1000).round() + 1500);
    Future.delayed(est, () {
      if (!done.isCompleted) done.complete();
    });
    await Native.I.speak(it.zh, rate: slow ? .65 : .9);
    await done.future;
    Native.I.ttsDone = null;
    if (!mounted || ph != _Ph.listen) return;
    if (run.mock && played >= maxPlays) _speak();
  }

  Future<void> _speak() async {
    _tick?.cancel();
    Native.I.stopSpeaking();
    if (!app.canListen) {
      setState(() {
        noListen = true;
        ph = _Ph.speak;
      });
      return;
    }
    final secs = hkAnswerSec(it.k, it.lv, chars: it.chars);
    setState(() {
      ph = _Ph.speak;
      busy = true;
      partial = '';
      left = secs;
      total = secs;
    });
    _speakStart = DateTime.now().millisecondsSinceEpoch;
    _tick = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return tm.cancel();
      setState(() => left = math.max(0, left - 1));
    });
    level.value = 0;
    final heard = await app.listenRaw(
      limitMs: secs * 1000 + 600,
      onEvent: (ev) {
        if (!mounted) return;
        switch (ev['t']) {
          case 'rms':
            level.value = (((ev['v'] as num).toDouble() + 2) / 12).clamp(0.0, 1.0);
          case 'partial':
            final v = '${ev['v']}';
            setState(() {
              partial = v;
              if (it.k == 't') live = scoreSpeech(it.zh, [v], 'e', app.sounds);
            });
            // a text read aloud: done when its last characters were read
            if (it.k == 't' && _readToEnd(live)) Native.I.listenStop();
        }
      },
    );
    _tick?.cancel();
    if (!mounted) return;
    final used = ((DateTime.now().millisecondsSinceEpoch - (_speakStart ?? 0)) / 1000).round();
    busy = false;
    if (heard == null) {
      setState(() => noListen = true);
      return;
    }
    _mark(heard, used);
  }

  bool _readToEnd(SpeakResult? r) {
    if (r == null) return false;
    final idx = [for (var k = 0; k < r.ok.length; k++) if (isHan(String.fromCharCode(it.zh.runes.elementAt(k)))) k];
    if (idx.length < 4) return false;
    final last = idx.sublist(idx.length - 3);
    return last.every((k) => r.ok[k]) && r.share(it.zh) > .6;
  }

  void _mark(List<String> heard, int secs) {
    final t = task;
    t.secs = secs;
    t.heard = heard.isEmpty ? '' : heard.first;
    if (it.k == 's' || it.k == 'q') {
      final ts = scoreTalk(t.heard, it, secs, app.sounds, app.vocab);
      t.talk = ts;
      t.score = ts.score;
    } else {
      final r = scoreSpeech(it.zh, heard, app.spk, app.sounds);
      t.said = r;
      t.score = heard.isEmpty ? 0 : (r.share(it.zh) * 100).round();
      if (r.heard.isNotEmpty) t.heard = r.heard;
    }
    t.done = true;
    app.spkLog.counted(it.lv, it.k);
    app.saveSpk();
    if (run.mock) {
      _nextMock();
    } else {
      t.score >= 76 ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
      setState(() => ph = _Ph.result);
    }
  }

  void _nextMock() {
    if (i + 1 >= tasks.length) {
      _endMock();
      return;
    }
    final partChange = tasks[i + 1].it.k != it.k;
    i++;
    if (partChange) {
      setState(() => ph = _Ph.part);
    } else {
      _enter();
    }
  }

  void _endMock() {
    final m = mock!;
    app.spkLog.saveMock(m, app.lm.now());
    app.saveSpk();
    app.inExam = false;
    app.changed();
    setState(() => ph = _Ph.mockEnd);
  }

  void _next() {
    if (i + 1 < tasks.length) {
      i++;
      _enter();
    } else {
      setState(() => ph = _Ph.end);
    }
  }

  void _retry() {
    final t = task;
    t
      ..done = false
      ..heard = ''
      ..score = 0
      ..said = null
      ..talk = null;
    _enter();
  }

  void _startMock() {
    app.inExam = true;
    app.changed();
    i = 0;
    setState(() => ph = _Ph.part);
  }

  Future<void> _toneTap() async {
    if (toneBusy) {
      HapticFeedback.selectionClick();
      final pcm = await Native.I.recStop();
      if (!mounted) return;
      final tones = hanTones(it.zh, it.py);
      setState(() => toneBusy = false);
      if (pcm == null || tones == null) {
        setState(() => tone = const ToneResult([], false));
        return;
      }
      final res = await Isolate.run(() => checkTones(pcm, tones));
      if (mounted) setState(() => tone = res);
      return;
    }
    HapticFeedback.lightImpact();
    Native.I.bgmHush(true);
    final ok = await Native.I.recStart(15000);
    Native.I.bgmHush(false);
    if (!mounted) return;
    if (!ok) {
      app.toast(app.t.spkDenied, 4000);
      return;
    }
    setState(() {
      tone = null;
      toneBusy = true;
    });
  }

  bool _back() {
    if (busy) {
      Native.I.listenStop();
      return true;
    }
    if (run.mock && mock != null && ph != _Ph.intro && ph != _Ph.mockEnd) {
      _askLeave();
      return true;
    }
    app.go(app.hkFrom);
    return true;
  }

  Future<void> _askLeave() async {
    final t = app.t;
    final yes = await openSheet<bool>(
      context,
      (c) => SheetBody(
        title: t.hkMockTitle,
        children: [
          Lead(t.hkLeave),
          const SizedBox(height: 6),
          MainBtn(t.hkLeaveYes, big: true, wide: true, onTap: () => Navigator.of(c).pop(true)),
          const SizedBox(height: 10),
          GhostBtn(t.back, wide: true, onTap: () => Navigator.of(c).pop(false)),
        ],
      ),
    );
    if (yes == true && mounted) {
      Native.I.stopSpeaking();
      app.go(app.hkFrom);
    }
  }

  // ------------------------------------------------------------ view
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final title = run.mock ? '${t.hkMockTitle} · ${hkName(run.lv)}' : hkKindName(run.k);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
            child: Row(
              children: [
                Press(
                  onTap: _back,
                  scale: .9,
                  label: app.t.close,
                  child: SizedBox(width: 48, height: 48, child: Center(child: Icon2(I.close, size: 20, color: p.fg, width: 2.2))),
                ),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(16, w: FontWeight.w800, c: p.fg)),
                ),
                if (tasks.isNotEmpty && ph != _Ph.intro && ph != _Ph.mockEnd && ph != _Ph.end)
                  Text('${i + 1}/${tasks.length}', style: F.s(13.5, w: FontWeight.w700, c: p.soft, feat: F.tab)),
              ],
            ),
          ),
          if (tasks.isNotEmpty && ph != _Ph.intro && ph != _Ph.mockEnd && ph != _Ph.end)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _Segments(n: tasks.length, done: i + (task.done ? 1 : 0)),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
              reverseDuration: Duration.zero,
              layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: KeyedSubtree(key: ValueKey('$ph$i'), child: _body(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) => switch (ph) {
    _Ph.load => const SizedBox(),
    _Ph.intro => _intro(context),
    _Ph.part => _partCard(context),
    _Ph.end => _practiceEnd(context),
    _Ph.mockEnd => _HkResult(mock: mock!, onTrain: (k) => app.startHk(run.lv, k: k), onDone: () => app.go(app.hkFrom)),
    _ => _item(context),
  };

  Widget _scroll(List<Widget> children, {Widget? bottom}) => Column(
    children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), children: children),
      ),
      if (bottom != null) Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 14), child: bottom),
    ],
  );

  // the mock's opening: its parts, a check before starting, how it works
  Widget _intro(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final checks = [(app.micOK, t.hkChkMic), (app.ttsOK, t.hkChkTts), (null, t.hkChkQuiet)];
    return _scroll(
      [
        _MockHead(lv: run.lv),
        const SizedBox(height: 18),
        Text(t.hkParts, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.2)),
        const SizedBox(height: 10),
        for (final (k, n) in hkPaper(run.lv)) ...[
          Glass(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                _KindDot(k),
                const SizedBox(width: 12),
                Expanded(child: Text(hkKindName(k), style: F.s(15, w: FontWeight.w700, c: p.fg))),
                Text('$n', style: F.s(14, w: FontWeight.w800, c: p.soft)),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        Text(t.hkBefore, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.2)),
        const SizedBox(height: 8),
        for (final (ok, label) in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok == true ? p.good : Colors.transparent,
                    border: Border.all(color: ok == true ? p.good : p.line, width: 1.5),
                  ),
                  child: ok == true ? Icon2(I.check, size: 13, color: p.onAcc, width: 3) : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: F.s(14.5, c: p.fg))),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(t.hkMockRule(hkBand(run.lv)), style: F.s(13, c: p.soft, h: 1.45)),
      ],
      bottom: MainBtn(t.hkStart, big: true, wide: true, icon: I.play, onTap: tasks.isEmpty ? null : _startMock),
    );
  }

  Widget _partCard(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final k = it.k;
    final n = tasks.where((x) => x.it.k == k).length;
    final how = switch (k) {
      'r' || 'x' => t.hkRepeatHow,
      's' => t.hkRetellHow,
      't' => t.hkReadHow,
      _ => t.hkAnswerHow,
    };
    return _scroll(
      [
        const SizedBox(height: 40),
        Center(child: _KindDot(k, size: 72)),
        const SizedBox(height: 16),
        Text(hkKindName(k), textAlign: TextAlign.center, style: F.s(22, w: FontWeight.w800, c: p.fg)),
        const SizedBox(height: 6),
        Text('$n', textAlign: TextAlign.center, style: F.s(14, w: FontWeight.w700, c: p.soft)),
        const SizedBox(height: 14),
        Text(how, textAlign: TextAlign.center, style: F.s(15, c: p.soft, h: 1.45)),
      ],
      bottom: MainBtn(t.next, big: true, wide: true, onTap: _enter),
    );
  }

  // one item: the prompt, then listening, then (practice) the marks
  Widget _item(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final k = it.k;
    final result = ph == _Ph.result || ph == _Ph.tone;
    final kids = <Widget>[];
    final how = switch (k) {
      'r' || 'x' => t.hkRepeatHow,
      's' => t.hkRetellHow,
      't' => t.hkReadHow,
      _ => t.hkAnswerHow,
    };
    kids.add(Text(how, style: F.s(14, c: p.soft, h: 1.4)));
    kids.add(const SizedBox(height: 12));

    // ---- the prompt
    if (k == 'r' || k == 'x' || k == 's') {
      final visible = result || showText;
      kids.add(Glass(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    k == 's' ? t.hkPlayed(played, run.mock ? 1 : 2) : '',
                    style: F.s(13, w: FontWeight.w700, c: p.soft),
                  ),
                ),
                if (!run.mock && ph != _Ph.speak) ...[
                  GhostBtn(t.hkSlow, fontSize: 13, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () {
                    if (k == 's' && played >= 2) return;
                    _play(slow: true);
                  }),
                  const SizedBox(width: 8),
                  GhostBtn(
                    t.hkPlay,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    lead: Icon2(I.speaker, size: 15, color: p.fg),
                    onTap: k == 's' && played >= 2 ? null : () => _play(),
                  ),
                ],
              ],
            ),
            if (visible) ...[
              const SizedBox(height: 12),
              if (task.said != null && result)
                _MarkedText(it: it, ok: task.said!.ok)
              else
                Text(it.zh, style: F.s(k == 's' ? 19 : 24, family: F.hz, w: FontWeight.w600, c: p.fg, h: 1.6)),
              const SizedBox(height: 6),
              Text(it.py, style: F.s(13.5, c: p.soft, h: 1.45)),
            ] else if (!run.mock && ph != _Ph.speak) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => showText = true), child: Text(t.hkShowText, style: F.s(14, w: FontWeight.w700, c: th.acc))),
              ),
            ],
          ],
        ),
      ));
    } else if (k == 't') {
      kids.add(Glass(
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result && task.said != null)
              _MarkedText(it: it, ok: task.said!.ok, size: 21)
            else if (live != null)
              _MarkedText(it: it, ok: live!.ok, size: 21, live: true)
            else
              Text(it.zh, style: F.s(21, family: F.hz, w: FontWeight.w600, c: p.fg, h: 1.75)),
            if (showPy || result) ...[const SizedBox(height: 10), Text(it.py, style: F.s(13.5, c: p.soft, h: 1.45))],
            if (!run.mock && !result)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => showPy = !showPy),
                  child: Text(t.hkPinyin, style: F.s(14, w: FontWeight.w700, c: showPy ? th.acc : p.soft)),
                ),
              ),
          ],
        ),
      ));
    } else {
      // a question: its text (pinyin at Dasar), the study language in practice, the keywords
      kids.add(Glass(
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Seal('师', size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.zh, style: F.s(21, family: F.hz, w: FontWeight.w600, c: p.fg, h: 1.5)),
                      if (it.lv == 1 || showPy || result) ...[const SizedBox(height: 4), Text(it.py, style: F.s(13.5, c: p.soft, h: 1.4))],
                      if (!run.mock || result) ...[const SizedBox(height: 6), Text(it.trIn(app.lang), style: F.s(13.5, c: p.mute, h: 1.4))],
                    ],
                  ),
                ),
                Spk(it.zh, size: 30),
              ],
            ),
            if (it.lv > 1 && !showPy && !result)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => showPy = true), child: Text(t.hkPinyin, style: F.s(14, w: FontWeight.w700, c: th.acc))),
              ),
          ],
        ),
      ));
    }

    // ---- keywords (a retell after listening, a question always)
    if ((k == 's' && (ph == _Ph.speak || result)) || k == 'q') {
      final said = task.talk?.hit ?? [for (final w in it.kw) if (partial.isNotEmpty && saysWord(partial, w, app.sounds)) w];
      kids.addAll([
        const SizedBox(height: 14),
        Text(k == 'q' ? t.hkKwQ : t.hkKw, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.1)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final w in it.kw) _KwChip(w, said.contains(w))]),
      ]);
    }

    // ---- what is being heard
    if (ph == _Ph.speak && partial.isNotEmpty && k != 't') {
      kids.addAll([
        const SizedBox(height: 14),
        Text(t.hkHeard, style: F.s(12.5, w: FontWeight.w700, c: p.mute)),
        const SizedBox(height: 4),
        Text(partial, style: F.s(17, family: F.zh, c: p.fg, h: 1.5)),
      ]);
    }
    if (noListen) kids.addAll([const SizedBox(height: 14), _Note(t.hkNoListen, warn: true)]);

    // ---- the marks (practice)
    if (result) kids.addAll(_marks(context));

    // ---- the bottom: the clock and the main action
    Widget bottom;
    if (ph == _Ph.listen) {
      bottom = run.mock
          ? _Clock(label: t.hkPlay, left: 0, total: 0)
          : MainBtn(t.hkSpeak, big: true, wide: true, icon: I.mic, onTap: _speak);
    } else if (ph == _Ph.prep) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Clock(label: t.hkPrep, left: left, total: total),
          const SizedBox(height: 10),
          MainBtn(t.hkReady, big: true, wide: true, icon: I.mic, onTap: _speak),
        ],
      );
    } else if (ph == _Ph.speak) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Clock(label: t.hkLeft, left: left, total: total),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: level,
            builder: (c, v, _) => BigMic(onTap: busy ? () => Native.I.listenStop() : (noListen ? null : _speak), busy: busy, level: v, seconds: math.max(1, total)),
          ),
          Text(busy ? t.hkListening : '', textAlign: TextAlign.center, style: F.s(13, c: p.soft)),
          if (noListen) ...[const SizedBox(height: 8), GhostBtn(t.next, wide: true, onTap: () => _mark(const [], 0))],
        ],
      );
    } else {
      // the marks: try again, check the tones (a repeat), next
      bottom = Row(
        children: [
          Expanded(child: GhostBtn(t.hkRetry, wide: true, onTap: _retry)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: MainBtn(t.next, big: true, wide: true, onTap: _next)),
        ],
      );
    }
    return _scroll(kids, bottom: bottom);
  }

  List<Widget> _marks(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final tk = task;
    final out = <Widget>[const SizedBox(height: 16)];
    out.add(Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScoreRing(tk.score),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.hkHeard, style: F.s(12.5, w: FontWeight.w700, c: p.mute)),
              const SizedBox(height: 2),
              Text(tk.heard.isEmpty ? t.hkNothing : tk.heard, style: F.s(tk.heard.isEmpty ? 14 : 16, family: tk.heard.isEmpty ? F.ui : F.zh, c: p.fg, h: 1.45)),
              if (tk.talk != null) ...[
                const SizedBox(height: 6),
                Text(t.hkSaid(tk.talk!.chars, tk.talk!.cpm), style: F.s(12.5, c: p.soft)),
                Text(t.hkBandN(tk.talk!.band, hkBand(it.lv)), style: F.s(12.5, c: p.soft)),
              ],
            ],
          ),
        ),
      ],
    ));
    if (it.k == 's' || it.k == 't') {
      out.addAll([
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => showTr = !showTr),
            child: Text(t.hkMeaning, style: F.s(14, w: FontWeight.w700, c: th.acc)),
          ),
        ),
        if (showTr && it.trIn(app.lang).isNotEmpty) Text(it.trIn(app.lang), style: F.s(14, c: p.soft, h: 1.45)),
      ]);
    }
    if ((it.k == 'r' || it.k == 'x') && hanTones(it.zh, it.py) != null) {
      out.addAll([const SizedBox(height: 16), _toneBox(context)]);
    }
    if (it.k == 'r' || it.k == 'x') {
      final tr = it.trIn(app.lang);
      if (tr.isNotEmpty) out.addAll([const SizedBox(height: 10), Text(tr, style: F.s(13.5, c: p.mute, h: 1.4))]);
    }
    return out;
  }

  Widget _toneBox(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final r = tone;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.hkTone, style: F.s(15, w: FontWeight.w800, c: p.fg))),
              GhostBtn(
                toneBusy ? t.hkStop : t.hkTone,
                fontSize: 13,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                lead: Icon2(I.mic, size: 15, color: toneBusy ? p.bad : p.fg),
                onTap: _toneTap,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (r == null) Text(toneBusy ? t.hkListening : t.hkToneHow, style: F.s(13, c: p.soft, h: 1.4)),
          if (r != null && !r.heard) Text(t.hkToneNo, style: F.s(13, c: p.soft, h: 1.4)),
          if (r != null && r.heard) ...[
            Text(t.hkToneRes(r.right, r.syl.length), style: F.s(14, w: FontWeight.w800, c: r.share >= .8 ? p.good : p.fg)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var k = 0; k < r.syl.length; k++) _ToneCell(han: _hanAt(k), syl: r.syl[k]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Legend(color: p.good, label: t.hkToneWant),
                const SizedBox(width: 14),
                _Legend(color: th.acc, label: t.hkToneGot),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.hkToneNote, style: F.s(11.5, c: p.mute, h: 1.35)),
          ],
        ],
      ),
    );
  }

  String _hanAt(int k) {
    final h = it.zh.runes.map(String.fromCharCode).where(isHan).toList();
    return k < h.length ? h[k] : '';
  }

  Widget _practiceEnd(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final avg = tasks.isEmpty ? 0 : (tasks.fold<int>(0, (a, x) => a + x.score) / tasks.length).round();
    return _scroll(
      [
        const SizedBox(height: 30),
        Center(child: _KindDot(run.k, size: 64)),
        const SizedBox(height: 14),
        Text(hkKindName(run.k), textAlign: TextAlign.center, style: F.s(20, w: FontWeight.w800, c: p.fg)),
        const SizedBox(height: 16),
        Center(child: ScoreRing(avg)),
        const SizedBox(height: 16),
        for (final x in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Glass(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(x.it.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(15, family: F.zh, c: p.fg))),
                  const SizedBox(width: 10),
                  Text('${x.score}', style: F.s(15, w: FontWeight.w800, c: x.score >= 76 ? p.good : (x.score > 50 ? p.sYellow : p.bad))),
                ],
              ),
            ),
          ),
      ],
      bottom: Row(
        children: [
          Expanded(child: GhostBtn(t.back, wide: true, onTap: () => app.go(app.hkFrom))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: MainBtn(t.hkRetry, big: true, wide: true, onTap: () {
              final b = app.spkBank;
              if (b != null) _practiceRound(b);
            }),
          ),
        ],
      ),
    );
  }
}

// =================================================================== small pieces
class _Segments extends StatelessWidget {
  final int n, done;
  const _Segments({required this.n, required this.done});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return Row(
      children: [
        for (var k = 0; k < n; k++) ...[
          if (k > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: k < done ? th.acc : th.p.line,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KindDot extends StatelessWidget {
  final String k;
  final double size;
  const _KindDot(this.k, {this.size = 36});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .16), border: Border.all(color: th.acc.withValues(alpha: .5))),
        child: Text(_kindHan(k), style: F.s(size * .5, family: F.hz, w: FontWeight.w600, c: th.p.fg, h: 1)),
      ),
    );
  }
}

class _KwChip extends StatelessWidget {
  final String w;
  final bool on;
  const _KwChip(this.w, this.on);
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: on ? p.good.withValues(alpha: .16) : Colors.transparent,
        border: Border.all(color: on ? p.good : p.line, width: on ? 1.4 : 1),
      ),
      child: Text(on ? '$w ✓' : w, style: F.s(16, family: F.zh, w: FontWeight.w600, c: on ? p.fg : p.soft)),
    );
  }
}

/// the text with every hanzi marked: right (the text's colour), missed or wrong (red, underlined); [live] while
/// reading: what is still ahead stays faint
class _MarkedText extends StatelessWidget {
  final SpkItem it;
  final List<bool> ok;
  final double size;
  final bool live;
  const _MarkedText({required this.it, required this.ok, this.size = 24, this.live = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final ch = it.zh.runes.map(String.fromCharCode).toList();
    var lastOk = -1;
    for (var k = 0; k < ch.length && k < ok.length; k++) {
      if (ok[k] && isHan(ch[k])) lastOk = k;
    }
    final base = F.s(size, family: F.hz, w: FontWeight.w600, h: 1.75);
    return Text.rich(
      TextSpan(children: [
        for (var k = 0; k < ch.length; k++)
          TextSpan(
            text: ch[k],
            style: base.copyWith(
              color: !isHan(ch[k])
                  ? p.soft
                  : (k < ok.length && ok[k])
                  ? (live ? p.good : p.fg)
                  : (live && k > lastOk ? p.mute : p.bad),
              decoration: !live && isHan(ch[k]) && k < ok.length && !ok[k] ? TextDecoration.underline : null,
              decorationColor: p.bad,
            ),
          ),
      ]),
      locale: const Locale('zh', 'CN'),
    );
  }
}

class _Clock extends StatelessWidget {
  final String label;
  final int left, total;
  const _Clock({required this.label, required this.left, required this.total});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    String mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Glass(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: F.s(13, c: p.soft)),
          if (total > 0) ...[
            const SizedBox(width: 10),
            Text(mmss(left), style: F.s(16, w: FontWeight.w800, c: left <= 10 ? p.gold : p.fg, feat: F.tab)),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 5),
      Text(label, style: F.s(12, w: FontWeight.w600, c: Th.pal(context).soft)),
    ],
  );
}

/// one syllable of the tone check: the hanzi, the textbook shape and the learner's
class _ToneCell extends StatelessWidget {
  final String han;
  final ToneSyl syl;
  const _ToneCell({required this.han, required this.syl});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    return Semantics(
      label: '$han ${syl.ok ? '✓' : '✗'}',
      child: Container(
        width: 46,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: syl.ok ? p.good.withValues(alpha: .6) : p.bad.withValues(alpha: .7), width: 1.2),
          color: (syl.ok ? p.good : p.bad).withValues(alpha: .08),
        ),
        child: Column(
          children: [
            CustomPaint(size: const Size(34, 26), painter: _ToneCurve(toneTemplate(syl.want), syl.curve, p.good, th.acc, p.line)),
            const SizedBox(height: 3),
            Text(han, style: F.s(17, family: F.hz, w: FontWeight.w600, c: p.t(syl.want))),
          ],
        ),
      ),
    );
  }
}

class _ToneCurve extends CustomPainter {
  final List<double> want, got;
  final Color cw, cg, grid;
  _ToneCurve(this.want, this.got, this.cw, this.cg, this.grid);
  @override
  void paint(Canvas c, Size s) {
    double y(double st) => s.height / 2 - st.clamp(-6.0, 6.0) / 6 * (s.height / 2 - 2);
    void line(List<double> v, Color col, double w) {
      if (v.length < 2) return;
      final path = Path();
      for (var k = 0; k < v.length; k++) {
        final x = k / (v.length - 1) * s.width;
        k == 0 ? path.moveTo(x, y(v[k])) : path.lineTo(x, y(v[k]));
      }
      c.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = col);
    }

    c.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), Paint()..color = grid);
    line(want, cw, 2.6);
    line(got, cg, 2.2);
  }

  @override
  bool shouldRepaint(_ToneCurve o) => o.got != got || o.want != want;
}

class _MockHead extends StatelessWidget {
  final int lv;
  const _MockHead({required this.lv});
  @override
  Widget build(BuildContext context) {
    final t = app.t;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xffa23a2c), Color(0xff5b3f9e)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.hkMockT, style: F.s(12, w: FontWeight.w800, c: Colors.white.withValues(alpha: .78), ls: 1.2)),
          const SizedBox(height: 4),
          Text('HSKK ${hkName(lv)}', style: F.s(25, w: FontWeight.w800, c: Colors.white)),
          const SizedBox(height: 4),
          Text(t.hkMockS(hkMockN(lv), hkMockMin(lv)), style: F.s(14, c: Colors.white.withValues(alpha: .88))),
        ],
      ),
    );
  }
}

// =================================================================== the mock's result
class _HkResult extends StatelessWidget {
  final HkMock mock;
  final void Function(String k) onTrain;
  final VoidCallback onDone;
  const _HkResult({required this.mock, required this.onTrain, required this.onDone});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final parts = mock.partScores();
    final total = mock.total();
    final weak = parts.entries.isEmpty ? null : parts.entries.reduce((a, b) => b.value < a.value ? b : a);
    final hist = [for (final m in app.spkLog.mocks) if (m[1] == mock.lv) (m[2] as num).toInt()];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Row(
                children: [
                  Transform.rotate(
                    angle: -.05,
                    child: Container(
                      width: 78,
                      height: 78,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xffd9482b), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: F.s(32, w: FontWeight.w800, c: const Color(0xfffbe9dd), h: 1)),
                          Text('/100', style: F.s(11, w: FontWeight.w700, c: const Color(0xfffbe9dd))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(t.hkResult, style: F.s(19, w: FontWeight.w800, c: p.fg))),
                        const SizedBox(height: 3),
                        Text(total >= 60 ? t.hkAbove : t.hkBelow, style: F.s(14, w: FontWeight.w700, c: total >= 60 ? p.good : p.soft)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (parts.length >= 3)
                Glass(
                  radius: 24,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Semantics(
                    label: [for (final e in parts.entries) '${hkKindShort(e.key)} ${e.value}'].join(', '),
                    child: CustomPaint(size: const Size(double.infinity, 200), painter: _Radar(parts, th.acc, p)),
                  ),
                ),
              const SizedBox(height: 12),
              for (final e in parts.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    radius: 18,
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _KindDot(e.key, size: 26),
                            const SizedBox(width: 10),
                            Expanded(child: Text(hkKindName(e.key), style: F.s(14.5, w: FontWeight.w700, c: p.fg))),
                            Text('${e.value}', style: F.s(18, w: FontWeight.w800, c: e.value >= 60 ? p.good : p.gold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(value: e.value / 100, minHeight: 6, backgroundColor: p.line, color: e.value >= 60 ? p.good : p.gold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (weak != null) ...[
                const SizedBox(height: 6),
                _Note(t.hkWeak(hkKindShort(weak.key))),
                const SizedBox(height: 8),
                GhostBtn(t.hkTrain, wide: true, onTap: () => onTrain(weak.key)),
              ],
              const SizedBox(height: 16),
              Text(t.hkHeard, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.1)),
              const SizedBox(height: 8),
              for (final x in mock.tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(x.it.zh, maxLines: 2, overflow: TextOverflow.ellipsis, style: F.s(14.5, family: F.zh, c: p.fg, h: 1.4))),
                            const SizedBox(width: 10),
                            Text('${x.score}', style: F.s(15, w: FontWeight.w800, c: x.score >= 60 ? p.good : p.gold)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(x.heard.isEmpty ? t.hkNothing : x.heard, maxLines: 3, overflow: TextOverflow.ellipsis, style: F.s(13, family: x.heard.isEmpty ? F.ui : F.zh, c: p.soft, h: 1.4)),
                      ],
                    ),
                  ),
                ),
              if (hist.length > 1) ...[
                const SizedBox(height: 10),
                Text(t.hkHist, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.1)),
                const SizedBox(height: 6),
                Text(hist.reversed.take(8).join(' · '), style: F.s(14, w: FontWeight.w700, c: p.soft, feat: F.tab)),
              ],
              const SizedBox(height: 10),
              Text(t.hkNote, style: F.s(12, c: p.mute, h: 1.4)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 14),
          child: MainBtn(app.t.tourDone, big: true, wide: true, onTap: onDone),
        ),
      ],
    );
  }
}

/// the three parts as a triangle (each axis 0–100)
class _Radar extends CustomPainter {
  final Map<String, int> parts;
  final Color acc;
  final Pal p;
  _Radar(this.parts, this.acc, this.p);
  @override
  void paint(Canvas c, Size s) {
    final ks = parts.keys.toList();
    final o = Offset(s.width / 2, s.height / 2 + 12);
    final r = math.min(s.width, s.height) * .38;
    Offset at(int k, double f) {
      final a = -math.pi / 2 + k * 2 * math.pi / ks.length;
      return o + Offset(math.cos(a), math.sin(a)) * r * f;
    }

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..color = p.line
      ..strokeWidth = 1;
    for (final f in [.5, 1.0]) {
      final path = Path()..addPolygon([for (var k = 0; k < ks.length; k++) at(k, f)], true);
      c.drawPath(path, grid);
    }
    for (var k = 0; k < ks.length; k++) {
      c.drawLine(o, at(k, 1), grid);
    }
    final shape = Path()..addPolygon([for (var k = 0; k < ks.length; k++) at(k, (parts[ks[k]]! / 100).clamp(.03, 1.0))], true);
    c.drawPath(shape, Paint()..color = acc.withValues(alpha: .25));
    c.drawPath(shape, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = acc);
    for (var k = 0; k < ks.length; k++) {
      final tp = TextPainter(
        text: TextSpan(text: '${_kindHan(ks[k])} ${parts[ks[k]]}', style: F.s(15, family: F.hz, w: FontWeight.w600, c: p.fg)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = at(k, 1.22);
      tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_Radar o) => o.parts != parts || o.acc != acc;
}
