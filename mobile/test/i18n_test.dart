// The converted interface text against the JS original: every text function, called with the same arguments,
// must give the same string (build/gen/i18n-probe.json, written by tool/make_i18n.js).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/i18n/l10.dart';

void main() {
  test('i18n functions give the same text as in JS', () {
    final probes = json.decode(File('build/gen/i18n-probe.json').readAsStringSync()) as List;
    final sealed = json.decode(File('build/gen/i18n-sealed.json').readAsStringSync()) as Map;
    final langs = <String, L10>{};
    for (final l in ['id', 'en', 'th', 'vi']) {
      langs[l] = L10.fromJson(l, File('build/gen/i18n-$l.json').readAsStringSync())
        ..addSealed((sealed[l] as Map).cast<String, dynamic>());
    }
    final bad = <String>[];
    for (final p in probes) {
      final l = langs[p[0]]!;
      Object? v = l.m;
      for (final k in p[1] as List) {
        v = v is Map ? v['$k'] : (v as List)[k as int];
      }
      final got = L10.text(v, p[2] as List);
      if (got != p[3]) bad.add('${p[0]} ${p[1]} ${p[2]}: js "${p[3]}" dart "$got"');
    }
    expect(bad, isEmpty, reason: '${bad.length} of ${probes.length} differ:\n${bad.take(10).join('\n')}');
    expect(probes.length, greaterThan(1000));
  });

  test('every key has a value in every language', () {
    final sealed = json.decode(File('build/gen/i18n-sealed.json').readAsStringSync()) as Map;
    final keys = (json.decode(File('build/gen/i18n-keys.json').readAsStringSync()) as Map).keys;
    for (final l in ['id', 'en', 'th', 'vi']) {
      final m = (json.decode(File('build/gen/i18n-$l.json').readAsStringSync()) as Map)..addAll(sealed[l] as Map);
      final missing = keys.where((k) => !m.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '$l lacks $missing');
    }
  });
}
