// The talk engine for the browser mock (dart compile js): the same code as in the app, nothing re-written.
import 'dart:convert';
import 'dart:js_interop';

import 'package:xueci/app/talk/coach.dart';
import 'package:xueci/app/talk/dialog.dart';
import 'package:xueci/app/talk/nlu.dart';

import '../test/talk/eval.dart' show noiser;

@JS('talkParse')
external set _parse(JSFunction f);
@JS('talkNew')
external set _new(JSFunction f);
@JS('talkSay')
external set _say(JSFunction f);
@JS('talkNoise')
external set _noise(JSFunction f);

Map<String, Object?> _f(Frame f) => {
      'act': f.act, 'pol': f.pol, 'conf': f.conf, 'pct': f.pct, 'when': f.when, 'reason': f.reason, 'span': f.span, //
    };

void main() {
  final nlu = TalkNlu();
  TalkDialog? d;
  var seedN = 1;
  Map<String, Object?> state() => {
        'mood': d!.st.mood,
        'patience': d!.st.patience,
        'apology': d!.st.apology,
        'reason': d!.st.reason,
        'delivery': d!.st.delivery,
        'compensation': d!.st.compensation,
        'gaveUp': d!.st.gaveUpCompensation,
        'offeredDays': d!.st.offeredDays,
        'offeredPct': d!.st.offeredPct,
        'end': d!.st.end,
        'turns': d!.st.turns,
      };
  _parse = ((JSString t) => jsonEncode({
        'repaired': TalkNlu.repair(t.toDart),
        'clauses': TalkNlu.splitClauses(TalkNlu.repair(t.toDart)).map((c) => c.toString()).toList(),
        'frames': nlu.parse([t.toDart]).map(_f).toList(),
      }).toJS).toJS;
  _new = ((JSNumber seed) {
    d = TalkDialog(lateDelivery, seed: seed.toDartInt);
    final l = d!.open();
    return jsonEncode({'zh': l.zh, 'id': l.id, 'state': state()}).toJS;
  }).toJS;
  _say = ((JSString t, JSString extra) {
    final text = t.toDart;
    final all = nlu.parse([text]);
    final frames = all.where((f) => f.conf >= TalkNlu.ok).toList();
    final ex = extra.toDart;
    if (ex.isNotEmpty) {
      for (final f in all) {
        if (f.key == ex && !frames.contains(f)) frames.add(f);
      }
    }
    final l = d!.reply(text, frames);
    final out = <String, Object?>{
      'zh': l.zh,
      'id': l.id,
      'situation': d!.turns.last.situation,
      'frames': frames.map(_f).toList(),
      'state': state(),
    };
    if (d!.over) {
      final r = coach(d!);
      out['report'] = {
        'total': r.total,
        'end': r.end,
        'parts': [for (final p in r.parts) {'name': p.name, 'got': p.got, 'max': p.max, 'why': p.why}],
        'slips': [for (final s in r.slips) {'said': s.said, 'better': s.better, 'why': s.why}],
        'models': [for (final m in r.models) {'zh': m.zh, 'id': m.id}],
      };
    }
    return jsonEncode(out).toJS;
  }).toJS;
  _noise = ((JSString t) => noiser(seedN++)(t.toDart).toJS).toJS;
}
