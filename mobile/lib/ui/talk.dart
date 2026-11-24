/// Bicara BCT: answer an angry business client with voice notes. The phone's recognizer writes what was said, the
/// talk engine (app/talk/) reads it, the client answers from what he still needs, and at the end a coach scores it.
/// All on the device; nothing here changes the realm, the plan or the memory states.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/native.dart';
import '../app/talk/coach.dart';
import '../app/talk/dialog.dart';
import '../app/talk/model.dart';
import '../app/talk/nlu.dart';
import '../app/talk/practice.dart';
import '../app/talk/recognition.dart';
import '../app/talk/sound.g.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

/// a fixed seed for the client's lines (tests); null = a new talk each time
int? talkSeed;

@visibleForTesting
Scenario? talkScenarioOverride;

/// in tests: stands in for the phone's recognizer
Future<List<String>?> Function({void Function(Map ev)? onEvent, int limitMs})? talkListen;

String _actName(String a) {
  final t = app.t;
  return switch (a) {
    'greet' => t.talkA_greet,
    'apologize' => t.talkA_apologize,
    'acknowledge' => t.talkA_acknowledge,
    'cause' => t.talkA_cause,
    'deny_fault' => t.talkA_deny_fault,
    'resend' => t.talkA_resend,
    'expedite' => t.talkA_expedite,
    'promise_time' => t.talkA_promise_time,
    'discount' => t.talkA_discount,
    'compensate' => t.talkA_compensate,
    'ask_deadline' => t.talkA_ask_deadline,
    'ask_order' => t.talkA_ask_order,
    'agree' => t.talkA_agree,
    'refuse' => t.talkA_refuse,
    'thanks' => t.talkA_thanks,
    'closing' => t.talkA_closing,
    _ => a,
  };
}

/// one message in the thread: the client's voice note (left) or the learner's reply (right)
class _Msg {
  final bool mine;
  final String zh, id;
  final int? score;
  const _Msg.client(this.zh, this.id) : mine = false, score = null;
  const _Msg.mine(this.zh, this.score) : mine = true, id = '';
}

class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key});
  @override
  State<TalkScreen> createState() => _TalkState();
}

class _TalkState extends State<TalkScreen> with WidgetsBindingObserver {
  TalkNlu _nlu = TalkNlu();
  late TalkDialog _d;
  PracticeLevel? _level;
  late final Random _random = Random(talkSeed);
  final _decks = <PracticeLevel, List<String>>{};
  final _lastByLevel = <PracticeLevel, String>{};
  String _hint = '';
  int _session = 0;
  static const _answerLimit = Duration(seconds: 30);

  String get _answerTimeNote => switch (app.lang) {
    'id' => 'Ketuk Bicara untuk mulai, lalu ketuk lagi untuk berhenti. Maksimal 30 detik per jawaban.',
    'th' => 'แตะพูดเพื่อเริ่ม แล้วแตะอีกครั้งเพื่อหยุด ตอบได้ไม่เกิน 30 วินาทีต่อครั้ง',
    'vi' => 'Chạm để bắt đầu nói và chạm lần nữa để dừng. Tối đa 30 giây cho mỗi câu trả lời.',
    _ => 'Tap Speak to start, then tap again to stop. Up to 30 seconds per answer.',
  };
  final _msgs = <_Msg>[];
  final _scroll = ScrollController();
  bool _listening = false, _noMic = false;
  String _live = '';
  Report? _rep;
  bool _audioReview = false, _playing = false, _sending = false, _audioUnavailable = false;
  int _recordedMs = 0, _positionMs = 0;
  List<int> _peaks = const [];
  Timer? _playClock;


  /// the engine was only half sure of one act: ask before counting it
  ({String text, Frame f})? _pending;
  TalkRecognition? _choice;

  @override
  void initState() {
    super.initState();
    app.backHook = _back;
    WidgetsBinding.instance.addObserver(this);
    _load();
    if (talkListen == null) {
      Native.I.talkAudioSupported().then((supported) {
        if (mounted) setState(() => _audioReview = supported);
      });
    }
    if (talkScenarioOverride != null) {
      _level = PracticeLevel.a;
      _start();
    }
  }

  Future<void> _load() async {
    try {
      final j = await app.bundle.loadString('assets/data/talk_model.json');
      final m = TalkModel.fromJson(j, soundFrom, soundTo);
      if (mounted) _nlu = TalkNlu(model: m);
    } catch (_) {
      // the rules alone still work
    }
  }

  @override
  void dispose() {
    if (app.backHook == _back) app.backHook = null;
    WidgetsBinding.instance.removeObserver(this);
    if (_audioReview) _clearAudio();
    if (_listening && !_audioReview) Native.I.listenStop();
    _scroll.dispose();
    super.dispose();
  }

  bool _back() {
    if (_level == null) {
      app.go('home');
      return true;
    }
    if (_listening && !_audioReview) Native.I.listenStop();
    if (_audioReview) _clearAudio();
    setState(() {
      _session++;
      _level = null;
      _listening = false;
    });
    return true;
  }

  void _start() {
    final level = _level!;
    final override = talkScenarioOverride;
    final pool = override == null ? practicePool(level, _random) : [(override, '')];
    final deck = _decks.putIfAbsent(level, () => []);
    if (deck.isEmpty) {
      deck.addAll(pool.map((entry) => entry.$1.id));
      deck.shuffle(_random);
      if (deck.length > 1 && deck.first == _lastByLevel[level]) deck.add(deck.removeAt(0));
    }
    final id = deck.removeAt(0);
    _lastByLevel[level] = id;
    final (scenario, hint) = pool.firstWhere((entry) => entry.$1.id == id);
    _hint = hint;
    _d = TalkDialog(scenario, seed: talkSeed ?? _random.nextInt(100000));
    final l = _d.open();
    _msgs
      ..clear()
      ..add(_Msg.client(l.zh, l.id));
    _rep = null;
    _pending = null;
    _choice = null;
    _live = '';
  }

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_audioReview && state == AppLifecycleState.paused) {
      setState(() {
        _session++;
        _listening = false;
        _sending = false;
        _clearAudio();
      });
    }
  }

  void _clearAudio() {
    _playClock?.cancel();
    _playClock = null;
    _recordedMs = 0;
    _positionMs = 0;
    _playing = false;
    _audioUnavailable = false;
    _peaks = const [];
    unawaited(Native.I.talkAudioClear());
  }

  Future<void> _recordAnswer() async {
    if (_sending) return;
    if (_listening) {
      await Native.I.talkRecordStop();
      return;
    }
    setState(() {
      _clearAudio();
      _listening = true;
    });
    final session = _session;
    final recording = await Native.I.talkRecord();
    if (!mounted || _session != session) return;
    setState(() {
      _listening = false;
      _recordedMs = (recording?['ms'] as num?)?.toInt() ?? 0;
      _peaks = (recording?['peaks'] as List?)?.whereType<int>().toList() ?? const [];
    });
    if (_recordedMs == 0) app.toast(app.t.talkNoHear, 2500);
  }

  Future<void> _toggleAudioPlayback() async {
    if (_sending || _recordedMs == 0) return;
    if (_playing) {
      _playClock?.cancel();
      await Native.I.talkAudioPause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final session = _session;
    if (_positionMs >= _recordedMs - 100) await Native.I.talkAudioSeek(0);
    final started = await Native.I.talkAudioPlay();
    if (!mounted || session != _session || _recordedMs == 0 || _sending) return;
    if (!started) {
      app.toast(app.t.talkNoHear, 2500);
      return;
    }
    setState(() => _playing = true);
    _playClock?.cancel();
    _playClock = Timer.periodic(const Duration(milliseconds: 125), (timer) async {
      final position = await Native.I.talkAudioPosition();
      if (!mounted || !timer.isActive || _recordedMs == 0) return;
      setState(() {
        _positionMs = position.clamp(0, _recordedMs);
        if (_positionMs >= _recordedMs - 100) {
          _playing = false;
          _positionMs = _recordedMs;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendAudio() async {
    if (_sending || _recordedMs == 0) return;
    final session = _session;
    _playClock?.cancel();
    setState(() {
      _sending = true;
      _playing = false;
    });
    final heard = await Native.I.talkAudioSend();
    if (!mounted || session != _session) return;
    setState(() => _sending = false);
    if (heard == null || heard.isEmpty || heard.first.trim().isEmpty) {
      if (heard == null) setState(() => _audioUnavailable = true);
      app.toast(heard == null ? _reviewLabel('unavailable') : app.t.talkNoHear, 4000);
      return;
    }
    setState(_clearAudio);
    _submit(heard);
  }

  Future<void> _listen() async {
    if (_audioReview && talkListen == null) {
      await _recordAnswer();
      return;
    }
    if (_listening) {
      Native.I.listenStop();
      return;
    }
    setState(() {
      _listening = true;
      _live = '';
    });
    final session = _session;
    void onEvent(Map ev) {
      if (!mounted || session != _session || ev['t'] != 'partial') return;
      setState(() => _live = '${ev['v']}');
    }

    final heard = await (talkListen ?? ({onEvent, limitMs = 30000}) => app.listenRaw(onEvent: onEvent, limitMs: limitMs, conversation: true))(
      onEvent: onEvent,
      limitMs: _answerLimit.inMilliseconds,
    );
    if (!mounted || session != _session) return;
    setState(() {
      _listening = false;
      _live = '';
    });
    if (heard == null) {
      setState(() => _noMic = true);
      return;
    }
    if (heard.isEmpty || heard.first.trim().isEmpty) {
      app.toast(app.t.talkNoHear, 2500);
      return;
    }
    _submit(heard);
  }

  void _submit(List<String> heard) {
    final recognition = readTalkSpeech(_nlu, _d, heard);
    final primary = recognition.primary;
    final tentative = recognition.tentative;
    setState(() {
      if (recognition.alternative != null) {
        _choice = recognition;
      } else if (tentative != null) {
        _msgs.add(_Msg.mine(primary.text, null));
        _pending = (text: primary.text, f: tentative);
      } else {
        _submitReading(primary);
      }
    });
    _down();
  }

  void _submitReading(TalkReading reading) {
    if (!_d.understandsReply(reading.text, reading.frames)) {
      app.toast(app.t.talkNoHear, 2500);
      return;
    }
    _reply(reading.text, reading.frames);
  }

  void _resolveChoice(TalkReading? reading) {
    setState(() {
      _choice = null;
      if (reading != null) _submitReading(reading);
    });
    _down();
  }

  void _reply(String text, List<Frame> frames, {bool replacePending = false}) {
    final answer = _Msg.mine(text, _d.turnScore(text, frames));
    if (replacePending) {
      _msgs[_msgs.length - 1] = answer;
    } else {
      _msgs.add(answer);
    }
    final l = _d.reply(text, frames);
    _msgs.add(_Msg.client(l.zh, l.id));
    if (_d.over) _rep = coach(_d);
  }

  void _confirm(bool yes) {
    final p = _pending;
    if (p == null) return;
    setState(() {
      _pending = null;
      if (yes) {
        _reply(p.text, [p.f], replacePending: true);
      } else {
        app.toast(app.t.talkNoHear, 2500);
      }
    });
    _down();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
            child: Row(
              children: [
                Press(
                  onTap: _back,
                  label: t.back,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: RotatedBox(quarterTurns: 1, child: Icon2(I.chev, size: 18, color: p.fg, width: 2.2))),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(t.talkTitle, style: F.s(24, w: FontWeight.w800, c: p.fg, ls: -.4))),
                      if (_level != null)
                        Text(_level == PracticeLevel.a ? 'BCT A' : 'BCT B', style: F.s(12.5, c: p.soft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_level == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_answerTimeNote, style: F.s(13, c: p.soft, h: 1.4)),
                  const SizedBox(height: 12),
                  for (final level in PracticeLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GhostBtn(
                        level == PracticeLevel.a ? 'BCT A' : 'BCT B',
                        wide: true,
                        lead: Icon2(I.mic, size: 18, color: th.acc, width: 1.9),
                        onTap: () => setState(() {
                          _level = level;
                          _start();
                        }),
                      ),
                    ),
                ],
              ),
            )
          else ...[
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                for (final m in _msgs) _bubble(m, th),
                if (_pending != null) _confirmCard(th),
                if (_choice != null) _choiceCard(th, _choice!),
                if (_level == PracticeLevel.a && _rep == null && _hint.isNotEmpty)
                  Text(_hint, style: F.s(12, c: p.soft, h: 1.4)),
                if (_rep != null) _report(_rep!, th),
                const SizedBox(height: 6),
                Text(t.talkNote, style: F.s(12, c: p.mute, h: 1.4)),
              ],
            ),
          ),
          _controls(th, bottom),
          ],
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, Th th) {
    final p = th.p;
    if (!m.mine) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 40),
          child: Glass(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Spk(m.zh),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.zh, style: F.s(17, family: F.hz, c: p.fg, h: 1.4)),
                      // the client's lines are translated into Indonesian only
                      if (_level == PracticeLevel.a && app.lang == 'id' && m.id.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(m.id, style: F.s(13, c: p.soft, h: 1.35)),
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
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Glass(
              radius: 20,
              color: th.acc.withValues(alpha: .16),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Text(m.zh, style: F.s(17, family: F.hz, c: p.fg, h: 1.4)),
            ),
            if (m.score != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${m.score}/10', style: F.s(13, w: FontWeight.w800, c: p.soft)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceCard(Th th, TalkRecognition choice) {
    final t = app.t;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.talkChooseSpeech, style: F.s(14, w: FontWeight.w700, c: th.p.fg)),
          for (final reading in [choice.primary, choice.alternative!]) ...[
            const SizedBox(height: 8),
            GhostBtn(reading.text, wide: true, onTap: () => _resolveChoice(reading)),
          ],
          const SizedBox(height: 8),
          GhostBtn(t.talkRetrySpeech, wide: true, onTap: () => _resolveChoice(null)),
        ],
      ),
    );
  }

  Widget _confirmCard(Th th) {
    final p = th.p;
    final t = app.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        radius: 20,
        color: p.gold.withValues(alpha: .12),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.talkAsk(_actName(_pending!.f.act)), style: F.s(15, w: FontWeight.w700, c: p.fg)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: MainBtn(t.talkYes, wide: true, onTap: () => _confirm(true))),
                const SizedBox(width: 8),
                Expanded(child: GhostBtn(t.talkNo, wide: true, onTap: () => _confirm(false))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(Report r, Th th) {
    final p = th.p;
    final t = app.t;
    final id = app.lang == 'id';
    final (label, color) = switch (r.end) {
      'good' => (t.talkEndGood, p.good),
      'lost' => (t.talkEndLost, p.bad),
      _ => (t.talkEndFair, p.gold),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.talkScore(r.total), style: F.s(24, w: FontWeight.w800, c: p.fg, ls: -.4))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                  child: Text(label, style: F.s(12.5, w: FontWeight.w800, c: color)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(t.talkGuide, style: F.s(12.5, c: p.mute)),
            // the coach's explanations are written in Indonesian only
            if (id) ...[
              const SizedBox(height: 12),
              for (final x in r.parts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${x.name}  ${x.got}/${x.max}', style: F.s(13.5, w: FontWeight.w800, c: p.fg)),
                        TextSpan(text: '  ${x.why}', style: F.s(13, c: p.soft)),
                      ],
                    ),
                  ),
                ),
            ],
            if (r.terms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(switch (app.lang) {
                'id' => 'Kosakata & ungkapan',
                'th' => 'คำศัพท์และสำนวน',
                'vi' => 'Từ vựng và cách diễn đạt',
                _ => 'Words & phrases',
              }, style: F.s(12.5, w: FontWeight.w800, c: p.mute)),
              for (final term in r.terms)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(term.term, style: F.s(16, family: F.hz, c: p.fg))),
                    Text('${term.score}/10', style: F.s(13, w: FontWeight.w800, c: th.acc)),
                  ]),
                ),
            ],
            if (r.slips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.talkFix, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.1)),
              const SizedBox(height: 4),
              for (final s in r.slips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${s.said} → ${s.better}${id ? '  ${s.why}' : ''}', style: F.s(14, family: F.hz, c: p.fg, h: 1.4)),
                ),
            ],
            if (r.models.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(t.talkModels, style: F.s(12.5, w: FontWeight.w800, c: p.mute, ls: 1.1)),
              const SizedBox(height: 4),
              for (final m in r.models)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spk(m.zh, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.zh, style: F.s(15, family: F.hz, c: p.fg, h: 1.4)),
                            if (id) Text(m.id, style: F.s(12.5, c: p.soft, h: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _reviewLabel(String name) {
    final labels = switch (app.lang) {
      'id' => ('Putar', 'Jeda', 'Rekam ulang', 'Kirim', 'Memproses rekaman…', 'Pengenal di perangkat ini belum bisa membaca rekaman.'),
      'th' => ('เล่น', 'หยุดชั่วคราว', 'บันทึกใหม่', 'ส่ง', 'กำลังประมวลผล…', 'อุปกรณ์นี้ไม่รองรับการถอดเสียงจากไฟล์บันทึก'),
      'vi' => ('Phát', 'Tạm dừng', 'Thu lại', 'Gửi', 'Đang xử lý…', 'Thiết bị này chưa hỗ trợ nhận dạng bản ghi.'),
      _ => ('Play', 'Pause', 'Record again', 'Send', 'Processing recording…', 'This device cannot transcribe the recording.'),
    };
    return switch (name) {
      'play' => labels.$1, 'pause' => labels.$2, 'redo' => labels.$3,
      'send' => labels.$4, 'sending' => labels.$5, _ => labels.$6,
    };
  }

  String _audioTime(int ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _recordingReview(Th th, EdgeInsets pad) => Padding(
    padding: pad,
    child: Glass(
      radius: 22, padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(children: [
        SizedBox(height: 28, child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (final peak in _peaks)
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Align(child: Container(height: 2 + peak * .25, color: th.acc, width: 2)),
            )),
        ])),
        Slider(
          value: _positionMs.toDouble(), max: _recordedMs.toDouble(),
          activeColor: th.acc,
          onChanged: _sending ? null : (value) => setState(() => _positionMs = value.round()),
          onChangeEnd: _sending ? null : (value) => unawaited(Native.I.talkAudioSeek(value.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_audioTime(_positionMs), style: F.s(12, c: th.p.soft)),
            Text(_audioTime(_recordedMs), style: F.s(12, c: th.p.soft)),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(
            tooltip: _reviewLabel(_playing ? 'pause' : 'play'),
            icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: th.p.fg),
            onPressed: _sending ? null : _toggleAudioPlayback,
          ),
          IconButton(
            tooltip: _reviewLabel('redo'),
            icon: Icon(Icons.replay_rounded, color: th.p.fg),
            onPressed: _sending ? null : _recordAnswer,
          ),
          IconButton.filled(
            tooltip: _reviewLabel('send'),
            icon: const Icon(Icons.send_outlined),
            onPressed: _sending ? null : _sendAudio,
          ),
        ]),
        if (_sending) Text(_reviewLabel('sending'), style: F.s(12, c: th.p.soft)),
        if (_audioUnavailable)
          GhostBtn(switch (app.lang) {
            'id' => 'Bicara langsung',
            'th' => 'พูดโดยตรง',
            'vi' => 'Nói trực tiếp',
            _ => 'Speak live',
          }, wide: true, onTap: () => setState(() {
            _clearAudio();
            _audioReview = false;
          })),
      ]),
    ),
  );

  Widget _controls(Th th, double bottom) {
    final p = th.p;
    final t = app.t;
    final pad = EdgeInsets.fromLTRB(16, 10, 16, 14 + bottom);
    if (_rep != null) {
      return Padding(
        padding: pad,
        child: Row(
          children: [
            Expanded(child: MainBtn(t.talkAgain, big: true, wide: true, onTap: () => setState(_start))),
            const SizedBox(width: 10),
            Expanded(child: GhostBtn(t.talkDone, wide: true, onTap: _back)),
          ],
        ),
      );
    }
    if (_pending != null || _choice != null) return const SizedBox.shrink();
    if (_recordedMs > 0) return _recordingReview(th, pad);
    // the practice is spoken: without a recognizer there is nothing to do here but say so
    if ((!app.canListen && !_audioReview) || _noMic) {
      return Padding(
        padding: pad,
        child: Glass(
          radius: 20,
          color: p.gold.withValues(alpha: .12),
          padding: const EdgeInsets.all(14),
          child: Text(t.talkNoMic, style: F.s(14, c: p.fg, h: 1.4)),
        ),
      );
    }
    return Padding(
      padding: pad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_listening && _live.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_live, style: F.s(15, family: F.hz, c: p.soft, h: 1.4))),
          MainBtn(_listening ? t.talkStop : t.talkSpeak, big: true, wide: true, icon: I.mic, onTap: _listen),
        ],
      ),
    );
  }
}
