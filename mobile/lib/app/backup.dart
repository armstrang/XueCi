/// Progress backup codes (backup.js): one line of text, "XUECI1:" + base64url(deflate-raw(JSON)) or "XUECI0:" +
/// base64url(JSON). Codes from v1.x and from this app read the same; a code can be copied, shared and pasted into
/// another install.
library;

import 'dart:convert';
import 'dart:io' show ZLibCodec;

import '../engine/js.dart';
import '../data/words.dart' show langs;
import '../engine/model.dart';
import '../i18n/l10.dart' show jsTruthy;
import 'app.dart';
import 'mastery.dart';

String _b64(List<int> u) => base64Url.encode(u).replaceAll('=', '');
List<int> _unb64(String t) {
  var s = t;
  while (s.length % 4 != 0) {
    s += '=';
  }
  return base64Url.decode(s);
}

final _raw = ZLibCodec(raw: true);

/// the code for this phone's progress
String makeCode(App a) {
  final lm = a.lm;
  final mem = lm.exportMem();
  final days = lm.studyDays().toList()..sort();
  final o = {
    'app': 'xueci',
    'v': 2,
    'at': a.nowMs(),
    'stats': lm.stats,
    'mem': {for (final e in mem.entries) e.key: e.value.toJson()},
    'goal': lm.goal,
    'w': lm.params,
    'lvl': lm.lvInfo,
    'rest': lm.rest,
    'tests': lm.tests,
    'mock': lm.mocks,
    'days': days.length > 730 ? days.sublist(days.length - 730) : days,
    'ui': {
      'level': a.level,
      'unitBy': {for (final e in a.unitBy.entries) '${e.key}': e.value},
      'qt': a.qType,
    },
    'lang': a.langPref,
    'theme': a.theme,
  };
  return 'XUECI1:${_b64(_raw.encode(utf8.encode(jsJson(o))))}';
}

/// a checked code, ready to apply
class Restore {
  final Map<String, List<num>> stats;
  final int at;
  final Object? ui, lang, theme, w, lvl, rest, tests, mock, days;
  final Map<String, Mem>? mem;
  final bool hasGoal;
  final Object? goal;
  Restore({
    required this.stats,
    required this.at,
    this.ui,
    this.lang,
    this.theme,
    this.mem,
    required this.hasGoal,
    this.goal,
    this.w,
    this.lvl,
    this.rest,
    this.tests,
    this.mock,
    this.days,
  });
  bool get gate => lvl is Map && jsTruthy((lvl as Map)['gate']);
}

/// finds a code inside any pasted text and checks every entry; null when there is none or it is broken
Future<Restore?> readCode(App a, String text) async {
  final m = RegExp(r'XUECI([01]):([A-Za-z0-9_-]+)').firstMatch(text.replaceAll(RegExp(r'\s+'), ''));
  if (m == null) return null;
  try {
    var u = _unb64(m.group(2)!);
    if (m.group(1) == '1') u = _raw.decode(u);
    final o = json.decode(utf8.decode(u));
    if (o is! Map || o['app'] != 'xueci' || o['stats'] is! Map) return null;
    var lvl = o['lvl'];
    // the gate past 飞升 comes back only with what it took to open it: a breakthrough to 飞升 in the realm history
    // and HSK 6 words that are actually solid in the code (half of them)
    if (lvl is Map && jsTruthy(lvl['gate'])) {
      final h = lvl['hist'] is List ? lvl['hist'] as List : const [];
      final bt = h.any((e) => e is List && e.length > 2 && e[0] is num && (e[0] as num) >= 7 && e[2] == 'bt');
      final mm = o['mem'] is Map ? o['mem'] as Map : const {};
      final six = a.by(6);
      final solid6 = six.where((d) {
        final e = mm[d.id];
        return e is Map && e['w'] is List && (e['w'] as List).length > 1 && e['w'][1] is num && (e['w'][1] as num) >= 10;
      }).length;
      if (!bt || solid6 < six.length * .5) {
        lvl = Map<String, dynamic>.from(lvl)
          ..remove('gate')
          ..remove('gs');
      }
    }
    final extra = lvl is Map && jsTruthy(lvl['gate']) && !a.band ? await a.bandIds() : null;
    bool known(String k) => a.vocab.idx.containsKey(k) || (extra != null && extra.contains(k));
    final st = <String, List<num>>{};
    (o['stats'] as Map).forEach((k, e) {
      if (!known('$k') || e is! List || e.length < 2 || !e.every((x) => x is num && x.isFinite && x >= 0)) return;
      final r = (e[0] as num).floor(), w = (e[1] as num).floor();
      st['$k'] = [r, w, ((e.length > 2 ? e[2] as num : r - w).floor()).clamp(0, maxL)];
    });
    return Restore(
      stats: st,
      at: o['at'] is num && (o['at'] as num) > 0 ? (o['at'] as num).toInt() : a.nowMs(),
      ui: o['ui'],
      lang: o['lang'],
      theme: o['theme'],
      mem: o['mem'] != null ? a.lm.importMem(o['mem'], extra) : null,
      hasGoal: o.containsKey('goal'),
      goal: o['goal'],
      w: o['w'],
      lvl: lvl,
      rest: o['rest'],
      tests: o['tests'],
      mock: o['mock'],
      days: o['days'],
    );
  } catch (_) {
    return null;
  }
}

/// applies a checked code in place (no restart): progress, level and unit, language, theme
Future<bool> applyCode(App a, Restore b) async {
  if (b.gate && !a.band) {
    try {
      await a.openBand();
    } catch (_) {
      a.toast(a.t.dataFail);
      return false;
    }
  }
  final lm = a.lm;
  lm.stats = b.stats;
  lm.saveStats();
  if (b.hasGoal) {
    lm.replace(b.mem ?? {}, goal_: b.goal, w: b.w);
  } else {
    lm.replace(b.mem ?? {}, w: b.w);
  }
  lm.restoreLevel(b.lvl);
  lm.restoreExtra({'tests': b.tests, 'rest': b.rest, 'days': b.days, 'mock': b.mock});
  a.syncRest();
  final ui = b.ui;
  if (ui is Map && ui['level'] is num && a.vocab.levels.contains((ui['level'] as num).toInt())) {
    final ub = ui['unitBy'] is Map ? ui['unitBy'] as Map : const {};
    for (final l in a.vocab.levels) {
      final u = ub['$l'];
      a.unitBy[l] = u is int && u >= 0 && u <= (a.vocab.units[l] ?? 1) ? u : 1;
    }
    a.level = (ui['level'] as num).toInt();
    if (qTypes.contains(ui['qt'])) a.qType = ui['qt'] as String;
  }
  if ((b.lang == 'auto' || langs.contains(b.lang)) && b.lang != a.langPref) await a.setLang(b.lang as String, silent: true);
  if (themes.contains(b.theme) && b.theme != a.theme) a.setTheme(b.theme as String);
  a.setLevel(a.level);
  return true;
}
