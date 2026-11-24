import 'dart:io';
import 'package:xueci/app/talk/model.dart';
import 'package:xueci/app/talk/nlu.dart';
import 'package:xueci/app/talk/sound.g.dart';
import '../test/talk/eval.dart';

// ignore_for_file: avoid_print

/// dart run tool/talk_eval.dart CORPUS.jsonl [fails] [noise] [model=PATH] [target=.95] [false-max=.05]
void main(List<String> a) {
  final items = loadCorpus(a[0]);
  String? arg(String k) {
    for (final x in a) {
      if (x.startsWith('$k=')) return x.substring(k.length + 1);
    }
    return null;
  }

  final mp = arg('model');
  final model = mp == null ? null : TalkModel.fromJson(File(mp).readAsStringSync(), soundFrom, soundTo);
  final ig = (arg('ignore') ?? '').split(',').where((x) => x.isNotEmpty).toSet();
  final n = _N(ig,
      
      model: model,
      wRule: double.tryParse(arg('w') ?? '') ?? .5,
      boost: double.tryParse(arg('boost') ?? '') ?? 1.4,
      only: double.tryParse(arg('only') ?? '') ?? .9);
  final s = evaluate(n, items, noise: a.contains('noise') ? noiser(7) : null);
  print(s.report(a[0].split('/').last + (a.contains('noise') ? ' + gangguan' : '')));
  if (a.contains('fails')) s.fails.forEach(print);
  final target = double.tryParse(arg('target') ?? '');
  if (target != null && s.f1 < target) {
    stderr.writeln('F1 ${(100 * s.f1).toStringAsFixed(2)}% masih di bawah target ${(100 * target).toStringAsFixed(2)}%.');
    exitCode = 1;
  }
  final falseMax = double.tryParse(arg('false-max') ?? '');
  if (falseMax != null) {
    final falseRate = s.falseAcceptance;
    if (falseRate == null || falseRate >= falseMax) {
      final actual = falseRate == null ? 'tanpa sampel' : '${(100 * falseRate).toStringAsFixed(2)}%';
      stderr.writeln('Salah terima $actual. Target di bawah ${(100 * falseMax).toStringAsFixed(2)}%.');
      exitCode = 1;
    }
  }
}

class _N extends TalkNlu {
  final Set<String> ig;
  _N(this.ig, {super.model, super.wRule, super.boost, super.only});
  @override
  List<Frame> parse(List<String> hyps) => super.parse(hyps).where((f) => !ig.contains(f.act)).toList();
}
