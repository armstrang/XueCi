// The learning engine against recorded runs: every trace in test/fixtures/engine (calls and their results, recorded
// from the reference engine the Dart one was ported from) is replayed call by call, and each result must match.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/data/store.dart';
import 'package:xueci/data/words.dart';
import 'package:xueci/engine/fsrs.dart' as fsrs;
import 'package:xueci/engine/js.dart';
import 'package:xueci/engine/learn.dart';
import 'package:xueci/engine/model.dart';

List<Word> loadVocab({bool band = false}) {
  final raw = json.decode(File('../content/vocab.json').readAsStringSync()) as List;
  final out = <Word>[];
  for (final r in raw.cast<Map<String, dynamic>>()) {
    final l = (r['l'] as num).toInt();
    if (!band && l > 6) continue;
    final w = Word(
      l: l,
      n: (r['n'] as num).toInt(),
      u: (r['u'] as num).toInt(),
      h: r['h'],
      p: r['p'],
      s: (r['s'] as List).cast<String>(),
      z: r['z'] ?? '',
      zp: r['zp'],
      f: (r['f'] as num?)?.toDouble(),
      g: r['g'],
      pm: l <= 6 && (r['m'] as String).split(';')[0].length <= 28 ? 1 : 0,
    );
    w.m['id'] = r['m'];
    w.t['id'] = r['t'];
    out.add(w);
  }
  return out;
}

/// deep comparison of JSON values: numbers within a tiny tolerance, a missing key equals null
String? diff(Object? a, Object? b, [String at = '']) {
  if (a == null && b == null) return null;
  if (a is num && b is num) {
    if (a == b) return null;
    final tol = 1e-9 * [1.0, a.abs().toDouble(), b.abs().toDouble()].reduce((x, y) => x > y ? x : y);
    return (a - b).abs() <= tol ? null : '$at: js $a, dart $b';
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$at: js length ${a.length}, dart ${b.length}  js=${_s(a)} dart=${_s(b)}';
    for (var i = 0; i < a.length; i++) {
      final d = diff(a[i], b[i], '$at[$i]');
      if (d != null) return d;
    }
    return null;
  }
  if (a is Map && b is Map) {
    final keys = {...a.keys.map((k) => '$k'), ...b.keys.map((k) => '$k')};
    for (final k in keys) {
      final d = diff(a[k], b[k], '$at.$k');
      if (d != null) return d;
    }
    return null;
  }
  return a == b ? null : '$at: js ${_s(a)}, dart ${_s(b)}';
}

String _s(Object? v) {
  final t = jsonEncode(v);
  return t.length > 300 ? '${t.substring(0, 300)}…' : t;
}

List<List<Object?>> itemsJ(List<Item> l) => [for (final it in l) [it.k, it.d.id, it.q, it.isNew ? 1 : 0, it.part]];
Object qmatJ(QMat m) => m.typed
    ? {'typed': 1}
    : {
        'o': m.words != null ? m.words!.map((w) => w.id).toList() : m.tones!.map((t) => t.join(' ')).toList(),
        'ans': m.ans,
      };
Object qmatI(Item it) => it.typed
    ? {'typed': 1}
    : {
        'o': it.words != null ? it.words!.map((w) => w.id).toList() : it.tones!.map((t) => t.join(' ')).toList(),
        'ans': it.ans,
      };

Object? memJ(Map<String, Mem> m) => json.decode(jsJson(m.map((k, v) => MapEntry(k, v.toJson()))));

class Replay {
  final Map<String, dynamic> tr;
  late int ms;
  late LM lm;
  late Vocab v;
  bool tts = false;
  PtState? pt;
  Item? ptItem;
  PtResult? ptRes;
  Trib? trib;
  Mock? mock;
  MockScore? mockSc;

  Replay(this.tr) {
    ms = (tr['time'] as num).toInt();
    v = Vocab(loadVocab(band: tr['band'] == true));
    final saved = (tr['saved'] as Map).map((k, x) => MapEntry('$k', '$x'));
    final st = Store(MemoryBackend(saved));
    st.open();
    st.migrate(v.data.map((d) => d.id).toSet().union(loadVocab(band: true).map((d) => d.id).toSet()));
    lm = LM(
      st,
      v,
      random: LcgRandom((tr['seed'] as num).toInt()),
      clock: () => jsRound((ms - fsrs.epochMs) / 6e4),
      tzOffset: 0,
    );
    lm.ttsReady = () => tts;
  }

  Word w(String id) => v.idx[id]!;
  List<Word> pool(Map a) => v.by[a['l']]!.where((d) => a['u'] == null || d.u == a['u']).toList();

  Object? run(String op, Map a) {
    switch (op) {
      case 'advance':
        ms += ((a['min'] as num) * 60000).round();
        return null;
      case 'tts':
        tts = a['on'] == true;
        return null;
      case 'question':
        return qmatJ(lm.question(w(a['id']), a['q'], (a['hard'] as num?)?.toDouble()));
      case 'answer':
        final r = lm.answer(
          w(a['id']),
          Ans(
            a['q'],
            a['ok'] == true,
            ms: a['ms'] ?? 0,
            x: a['x'],
            claim: a['claim'] == true,
            over: a['over'] == true,
            unchecked: a['unchecked'] == true,
          ),
        );
        return {'g': r.g, 'before': r.before, 'after': r.after};
      case 'checkP':
        return lm.checkP(w(a['id']));
      case 'checkType':
        return lm.checkType(w(a['id']));
      case 'session':
        return itemsJ(lm.session(a['extra'] == true));
      case 'cardDeck':
        return lm.cardDeck(pool(a), a['n']).map((d) => d.id).toList();
      case 'quizRound':
        return itemsJ(lm.quizRound(pool(a), a['n'], a['type']));
      case 'exam':
        return itemsJ(lm.exam(a['lv'], a['n']));
      case 'setGoal':
        lm.setGoal(a);
        return null;
      case 'setRest':
        lm.setRest(a['a']);
        return null;
      case 'updWeak':
        lm.updWeak();
        return null;
      case 'plan':
        return lm.plan().toJson();
      case 'stage':
        return lm.stage()?.toJson();
      case 'soul':
        return lm.soul();
      case 'streak':
        final s = lm.streak();
        return {'days': s.days, 'today': s.today};
      case 'challenge':
        return lm.challenge();
      case 'advice':
        final A = lm.advice();
        return {
          'L': A.L,
          'items': [
            for (final x in A.items)
              {
                ...x,
                if (x['words'] != null) 'words': (x['words'] as List<Word>).map((d) => d.id).toList(),
                if (x['a'] != null) 'a': (x['a'] as Word).id,
                if (x['b'] != null) 'b': (x['b'] as Word).id,
              },
          ],
        };
      case 'forecast':
        return lm.forecast();
      case 'btChance':
        return lm.btChance();
      case 'insights':
        final i = lm.insights();
        return {
          ...i,
          'pairs': [
            for (final p in i['pairs'] as List) [(p[0] as Word).id, (p[1] as Word).id, p[2]],
          ],
        };
      case 'restGain':
        final g = lm.restGain();
        return g == null ? null : {'now': g.now, 'day': g.day, 'two': g.two, 'S': g.S};
      case 'sinceLast':
        final s = lm.sinceLast();
        return s == null ? null : {'gap': s.gap, 'recall': s.recall};
      case 'stability':
        return lm.stability().toJson();
      case 'curLevel':
        return {
          'cur': lm.curLevel(),
          'base': lm.baseLevel(),
          'realm': lm.realm(),
          'ptOpen': lm.ptOpen(),
          'canTest': lm.canTest(),
        };
      case 'levels':
        return {for (final id in lm.stats.keys) id: lm.levelOf(lm.mem[id])};
      case 'modelCheck':
        return lm.modelCheck();
      case 'seqs':
        return lm.seqs().length;
      case 'mem':
        return memJ(lm.exportMem());
      case 'stats':
        return lm.stats;
      case 'ptNext':
        pt ??= lm.ptStart();
        final it = ptItem = lm.ptNext(pt!);
        if (it == null) return null;
        final m = qmatI(it) as Map;
        return {'id': it.d.id, 'l': it.l, 'q': it.q, ...m};
      case 'ptAnswer':
        lm.ptAnswer(pt!, ptItem!, a['r']);
        return null;
      case 'ptResult':
        ptRes = lm.ptResult(pt!);
        return ptRes!.toJson();
      case 'placementDone':
        lm.placementDone(ptRes!);
        return null;
      case 'btReady':
        return {'ready': lm.btReady(), 'open': lm.btOpen(), 'makeup': lm.makeupOpen()};
      case 'btStart':
        final st = trib = lm.btStart();
        return {
          'r': st.r,
          'L': st.L,
          'makeup': st.makeup,
          'strikes': st.strikes.map((s) => s.toJson()).toList(),
          'items': [
            for (final it in st.items)
              {'id': it.d.id, 'q': it.q, 'strike': it.strike, 'limit': it.limit, ...(qmatI(it) as Map)},
          ],
        };
      case 'btAnswers':
        final r = a['r'] as List;
        for (var i = 0; i < r.length; i++) {
          trib!.items[i].r = r[i];
        }
        return null;
      case 'btFinish':
        final res = lm.btFinish(trib!);
        return {
          'pass': res.pass,
          'need': res.need,
          'acc': res.acc,
          'right': res.right,
          'n': res.n,
          'grade': res.grade,
          'gate': res.gate,
          'strikes': res.strikes.map((s) => s.toJson(done: true)).toList(),
          'r': res.r,
          'makeup': res.makeup,
          'weak': res.weak.map((d) => d.id).toList(),
        };
      case 'grades':
        return lm.grades().map((k, x) => MapEntry('$k', x));
      case 'level':
        return lm.lvInfo;
      case 'stabWords':
        return lm.stabWords().map((d) => d.id).toList();
      case 'stabDone':
        return lm.stabDone(a['right'], a['total']);
      case 'mockExam':
        final m = mock = lm.mockExam(a['L']);
        return {
          'L': m.L,
          'parts': [for (final p in m.parts) {'k': p.k, 'n': p.n}],
          'sec': m.sec,
          'skipped': m.skipped,
          'items': itemsJ(m.items),
        };
      case 'mockOk':
        final ok = a['ok'] as List;
        for (var i = 0; i < ok.length; i++) {
          mock!.items[i].ok = ok[i] == true;
        }
        return null;
      case 'mockScore':
        final s = mockSc = lm.mockScore(mock!);
        return {
          'parts': [for (final p in s.parts) {'k': p.k, 'n': p.n, 'right': p.right, 'score': p.score}],
          'total': s.total,
          'max': s.max,
          'need': s.need,
          'pass': s.pass,
        };
      case 'mockSave':
        lm.mockSave(mock!, mockSc!, a['used']);
        return null;
      case 'mocks':
        return lm.mocks;
      case 'pyCheck':
        final r = lm.pyCheck(w(a['id']), a['t']);
        return {'ok': r.ok, 'empty': ?r.empty, 'toneless': ?r.toneless, 'alt': ?r.alt?.id};
      case 'wdiff':
        return [
          for (final d in v.data.indexed.where((p) => p.$1 % 13 == 0)) [d.$2.id, lm.wdiff(d.$2)],
        ];
      case 'optimize':
        throw StateError('async');
    }
    throw UnimplementedError(op);
  }
}

void main() {
  final dir = Directory('test/fixtures/engine');
  final files = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  test('traces exist', () => expect(files, isNotEmpty, reason: 'test/fixtures/engine is empty'));
  for (final f in files) {
    test('engine trace ${f.uri.pathSegments.last}', () async {
      final tr = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
      final r = Replay(tr);
      final ops = tr['ops'] as List;
      var fails = 0;
      final msgs = <String>[];
      for (var i = 0; i < ops.length; i++) {
        final o = ops[i] as Map<String, dynamic>;
        final op = o['op'] as String;
        Object? got;
        if (op == 'optimize') {
          final res = await r.lm.optimize(true);
          got = {...?res, 'W': r.lm.params};
        } else {
          got = json.decode(jsJson(r.run(op, (o['a'] as Map?) ?? {})));
        }
        final d = diff(o['o'], got, '#$i $op');
        if (d != null) {
          fails++;
          if (msgs.length < 8) msgs.add(d);
        }
      }
      expect(msgs, isEmpty, reason: '$fails of ${ops.length} calls differ:\n${msgs.join('\n')}');
    });
  }
}
