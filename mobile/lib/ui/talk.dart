/// Bicara BCT: answer an angry business client with voice notes. The phone's recognizer writes what was said, the
/// talk engine (app/talk/) reads it, the client answers from what he still needs, and at the end a coach scores it.
/// All on the device; nothing here changes the realm, the plan or the memory states.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/native.dart';
import '../app/talk/coach.dart';
import '../app/talk/dialog.dart';
import '../app/talk/model.dart';
import '../app/talk/nlu.dart';
import '../app/talk/sound.g.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

/// a fixed seed for the client's lines (tests); null = a new talk each time
int? talkSeed;

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
  final List<Frame> frames;
  const _Msg.client(this.zh, this.id) : mine = false, frames = const [];
  const _Msg.mine(this.zh, this.frames) : mine = true, id = '';
}

class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key});
  @override
  State<TalkScreen> createState() => _TalkState();
}

class _TalkState extends State<TalkScreen> {
  TalkNlu _nlu = TalkNlu();
  late TalkDialog _d;
  final _msgs = <_Msg>[];
  final _scroll = ScrollController();
  bool _listening = false, _noMic = false;
  String _live = '';
  Report? _rep;

  /// the engine was only half sure of one act: ask before counting it
  ({String text, Frame f})? _pending;

  @override
  void initState() {
    super.initState();
    app.backHook = _back;
    _load();
    _start();
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
    if (_listening) Native.I.listenStop();
    _scroll.dispose();
    super.dispose();
  }

  bool _back() {
    app.go('home');
    return true;
  }

  void _start() {
    _d = TalkDialog(lateDelivery, seed: talkSeed ?? DateTime.now().millisecondsSinceEpoch % 100000);
    final l = _d.open();
    _msgs
      ..clear()
      ..add(_Msg.client(l.zh, l.id));
    _rep = null;
    _pending = null;
    _live = '';
  }

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _listen() async {
    if (_listening) {
      Native.I.listenStop();
      return;
    }
    setState(() {
      _listening = true;
      _live = '';
    });
    void onEvent(Map ev) {
      if (!mounted || ev['t'] != 'partial') return;
      setState(() => _live = '${ev['v']}');
    }

    final heard = await (talkListen ?? ({onEvent, limitMs = 30000}) => app.listenRaw(onEvent: onEvent, limitMs: limitMs))(
      onEvent: onEvent,
      limitMs: 30000,
    );
    if (!mounted) return;
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
    final text = heard.first.trim();
    final all = _nlu.parse(heard);
    final ok = all.where((f) => f.conf >= TalkNlu.ok).toList();
    final ask = all.where((f) => f.conf >= TalkNlu.ask && f.conf < TalkNlu.ok).toList()..sort((a, b) => b.conf.compareTo(a.conf));
    setState(() {
      _msgs.add(_Msg.mine(text, ok));
      if (ok.isEmpty && ask.isNotEmpty) {
        _pending = (text: text, f: ask.first);
      } else {
        _reply(text, ok);
      }
    });
    _down();
  }

  void _reply(String text, List<Frame> frames) {
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
        _reply(p.text, [p.f]);
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
                      Text(t.talkSit, style: F.s(12.5, c: p.soft, h: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                for (final m in _msgs) _bubble(m, th),
                if (_pending != null) _confirmCard(th),
                if (_rep != null) _report(_rep!, th),
                const SizedBox(height: 6),
                Text(t.talkNote, style: F.s(12, c: p.mute, h: 1.4)),
              ],
            ),
          ),
          _controls(th, bottom),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m, Th th) {
    final p = th.p;
    final t = app.t;
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
                      if (app.lang == 'id' && m.id.isNotEmpty) ...[
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
            if (m.frames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final f in m.frames)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: (f.pol == '+' ? p.good : p.bad).withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_actName(f.act)}${f.pol == '-' ? ' (−)' : ''}',
                        style: F.s(12, w: FontWeight.w700, c: f.pol == '+' ? p.good : p.bad),
                      ),
                    ),
                ],
              ),
            ] else
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(t.talkNoHear, style: F.s(12, c: p.mute))),
          ],
        ),
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
    if (_pending != null) return const SizedBox.shrink();
    // the practice is spoken: without a recognizer there is nothing to do here but say so
    if (!app.canListen || _noMic) {
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
