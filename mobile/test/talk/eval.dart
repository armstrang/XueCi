/// Measures the talk engine against a labelled corpus (content/talk/corpus/*.jsonl) under the rules of
/// content/talk/ADJUDICATION.md.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';

const offerActs = {'resend', 'expedite', 'discount', 'compensate', 'promise_time'};
final _admit = RegExp('(我们|我方|咱们|我)(自己)?的?(错|问题|责任|失误|疏忽|过失|不对)|没做好|没处理好|怪我们|责任在(我们|我方)|难辞其咎|锅');
final _sorry = RegExp('对不起|抱歉|道歉|歉意|不好意思|原谅|谅解|见谅|包涵');
final _condRe = RegExp('如果|要是|假如|假设|万一|只要|的话|前提|倘若|除非');
const whenVocab = {'today', 'tomorrow', 'dayafter', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'};
bool whenOk(String? w) => w != null && (whenVocab.contains(w) || RegExp(r'^\d+_days$').hasMatch(w));

class Item {
  final String text, set;
  final List<Map<String, dynamic>> frames;
  final List<String> tags;
  Item(this.text, this.frames, this.tags, this.set);
}

List<Item> loadCorpus(String path) => [
      for (final l in File(path).readAsLinesSync())
        if (l.trim().isNotEmpty)
          (() {
            final o = jsonDecode(l) as Map<String, dynamic>;
            return Item(o['text'] as String, (o['frames'] as List).cast<Map<String, dynamic>>(),
                ((o['tags'] ?? []) as List).cast<String>(), (o['set'] ?? '') as String);
          })()
    ];

class Score {
  int tp = 0, fp = 0, fn = 0, opt = 0, items = 0, exact = 0, confirm = 0;
  int negTot = 0, negHit = 0, advItems = 0, advFalse = 0;
  int pctN = 0, pctOk = 0, whenN = 0, whenOk2 = 0, reasonN = 0, reasonOk = 0;
  final Map<String, List<int>> perAct = {};
  final List<String> fails = [];
  double ms = 0;
  double get p => tp / max(1, tp + fp);
  double get r => tp / max(1, tp + fn);
  double get f1 => 2 * p * r / max(1e-9, p + r);
  String pc(double x) => '${(x * 100).toStringAsFixed(1)}%';
  String report(String name) {
    final b = StringBuffer();
    b.writeln('== $name: $items ucapan');
    b.writeln('presisi ${pc(p)}  perolehan ${pc(r)}  F1 ${pc(f1)}  (tp $tp fp $fp fn $fn, opsional $opt)');
    b.writeln('ucapan tepat seluruhnya ${pc(exact / max(1, items))}');
    b.writeln('negasi (bingkai -) tertangkap ${pc(negHit / max(1, negTot))} dari $negTot');
    b.writeln('salah terima di ucapan sulit ${pc(advFalse / max(1, advItems))} dari $advItems');
    b.writeln('slot pct ${pc(pctOk / max(1, pctN))} ($pctN)  when ${pc(whenOk2 / max(1, whenN))} ($whenN)  reason ${pc(reasonOk / max(1, reasonN))} ($reasonN)');
    b.writeln('zona konfirmasi $confirm bingkai; waktu ${(ms / max(1, items)).toStringAsFixed(2)} ms/ucapan');
    final acts = perAct.keys.toList()..sort();
    for (final a in acts) {
      final v = perAct[a]!;
      b.writeln('  ${a.padRight(14)} tp ${v[0].toString().padLeft(3)} fp ${v[1].toString().padLeft(3)} fn ${v[2].toString().padLeft(3)}');
    }
    return b.toString();
  }
}

Score evaluate(TalkNlu nlu, List<Item> items, {String Function(String)? noise}) {
  final s = Score();
  final sw = Stopwatch();
  for (final it in items) {
    s.items++;
    final text = noise == null ? it.text : noise(it.text);
    sw.start();
    final all = nlu.parse([text]);
    sw.stop();
    final pred = all.where((f) => f.conf >= TalkNlu.ok).toList();
    s.confirm += all.where((f) => f.conf >= TalkNlu.ask && f.conf < TalkNlu.ok).length;
    final gold = it.frames.where((f) => f['act'] != 'none').toList();
    final gk = {for (final g in gold) '${g['act']}${g['pol']}'};
    final pk = {for (final f in pred) f.key};
    final strict = Platform.environment['STRICT'] == '1';
    final cond = !strict && _condRe.hasMatch(it.text);
    final admit = !strict && _admit.hasMatch(it.text) && !_sorry.hasMatch(it.text);
    final hasNeg = gk.any((k) => k.endsWith('-'));
    final predNeg = pk.any((k) => k.endsWith('-') && !k.startsWith('cause'));
    bool optional(String k) {
      final act = k.substring(0, k.length - 1);
      if (cond && offerActs.contains(act)) return true;
      if (k == 'refuse+' && (hasNeg || predNeg)) return true;
      return false;
    }

    bool equiv(String a, Set<String> pool) {
      if (pool.contains(a)) return true;
      if (admit && (a == 'apologize+' && pool.contains('acknowledge+') || a == 'acknowledge+' && pool.contains('apologize+'))) {
        return true;
      }
      return false;
    }

    var exactOk = true;
    for (final k in gk) {
      final act = k.substring(0, k.length - 1);
      final v = s.perAct.putIfAbsent(act, () => [0, 0, 0]);
      if (k.endsWith('-')) s.negTot++;
      if (equiv(k, pk)) {
        s.tp++;
        v[0]++;
        if (k.endsWith('-')) s.negHit++;
      } else if (optional(k)) {
        s.opt++;
      } else {
        s.fn++;
        v[2]++;
        exactOk = false;
      }
    }
    for (final k in pk) {
      final act = k.substring(0, k.length - 1);
      final v = s.perAct.putIfAbsent(act, () => [0, 0, 0]);
      if (equiv(k, gk)) continue;
      if (optional(k)) {
        s.opt++;
        continue;
      }
      s.fp++;
      v[1]++;
      exactOk = false;
    }
    final adv = it.tags.any((t) => const {'negation', 'hypothetical', 'question', 'quote', 'offtopic'}.contains(t));
    if (adv) {
      s.advItems++;
      if (pk.any((k) => k.endsWith('+') && !equiv(k, gk) && !optional(k))) s.advFalse++;
    }
    // slots
    for (final g in gold) {
      final f = pred.where((x) => x.act == g['act'] && x.pol == g['pol']).firstOrNull;
      if (f == null) continue;
      if (g['act'] == 'discount' && g['pct'] is int) {
        s.pctN++;
        if (f.pct == g['pct']) s.pctOk++;
      }
      if ((g['act'] == 'resend' || g['act'] == 'promise_time') && whenOk(g['when'] as String?)) {
        s.whenN++;
        if (f.when == g['when']) s.whenOk2++;
      }
      if (g['act'] == 'cause' && g['pol'] == '+' && g['reason'] != null) {
        s.reasonN++;
        if (pred.any((x) => x.act == 'cause' && x.reason == g['reason'])) s.reasonOk++;
      }
    }
    if (exactOk) s.exact++;
    if (!exactOk) {
      final miss = gk.where((k) => !equiv(k, pk) && !optional(k)).join(',');
      final extra = pk.where((k) => !equiv(k, gk) && !optional(k)).join(',');
      s.fails.add('${it.set} ${it.text}${noise == null ? '' : ' ⟶ $text'}\n    kurang [$miss] lebih [$extra] mesin $pred');
    }
  }
  s.ms = sw.elapsedMicroseconds / 1000;
  return s;
}

/// the most common little words, which a recognizer's language model almost never writes wrong
const noiseKeep = '不没的了是我你您他她们这那一二两三四五六七八九十百个在有和就也都很再把被让给吗呢吧啊好要会能可以说';

/// a recognizer's slips: about [sub] of the other characters written as another of the same sound, [drop] left out
String Function(String) noiser(int seed, {double sub = .1, double drop = .02}) {
  final groups = <int, List<int>>{};
  final a = soundFrom.runes.toList(), b = soundTo.runes.toList();
  for (var i = 0; i < a.length; i++) {
    (groups[b[i]] ??= [b[i]]).add(a[i]);
  }
  final of = <int, List<int>>{};
  for (final g in groups.values) {
    for (final c in g) {
      of[c] = g;
    }
  }
  final rnd = Random(seed);
  return (t) {
    final out = StringBuffer();
    for (final r in t.runes) {
      final x = rnd.nextDouble();
      if (r >= 0x4e00 && r <= 0x9fff && x < drop) continue;
      final g = of[r];
      if (g != null && g.length > 1 && x < drop + sub && !noiseKeep.contains(String.fromCharCode(r))) {
        out.writeCharCode(g[rnd.nextInt(g.length)]);
      } else {
        out.writeCharCode(r);
      }
    }
    return out.toString();
  };
}
