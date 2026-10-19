/// The progress store. Same keys and values as the WebView app (v1.x): JSON text under the old key names, which must
/// never be renamed (a backup code, the Android backup and the move from v1.x all rely on them).
///
/// Everything is kept in memory; each change is written to a file per key in the app's own files folder (written
/// to a temporary file first, then renamed, so a crash never leaves half a file). Writes of one moment go out
/// together; when the app goes to the background everything waiting is written at once.
///
/// Schema versions (xc_schema), as in store.js:
///   1  up to v1.7   mm_stats {id: [right, wrong] or [right, wrong, level]}, hsk16_known, mm_lang, hsk16_ui, hsk16_theme
///   2  v1.8–v1.11   + xc_mem, xc_log, xc_logA, xc_goal, xc_w, xc_fit, xc_onb, xc_lvl, xc_rem, xc_tests, xc_rest,
///                   xc_game, xc_amb, xc_note
///   3  v1.12        everything in IndexedDB; new: xc_days, xc_bk (later versions only added keys)
/// Migrations run in order, once, on the data in memory, and never delete a key.
library;

import 'dart:async';
import 'dart:io';

import '../engine/js.dart';

abstract class KvBackend {
  Map<String, String> loadAll();
  void write(Map<String, String?> changes);
}

/// in memory only (tests)
class MemoryBackend implements KvBackend {
  final Map<String, String> box;
  MemoryBackend([Map<String, String>? init]) : box = init ?? {};
  @override
  Map<String, String> loadAll() => Map.of(box);
  @override
  void write(Map<String, String?> changes) {
    changes.forEach((k, v) => v == null ? box.remove(k) : box[k] = v);
  }
}

/// one file per key: `<dir>/<key>.json` (keys are plain names like xc_mem)
class FileBackend implements KvBackend {
  final Directory dir;
  FileBackend(this.dir);
  static final _ok = RegExp(r'^[A-Za-z0-9_.-]+$');

  @override
  Map<String, String> loadAll() {
    final out = <String, String>{};
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final name = f.uri.pathSegments.last;
      final k = name.substring(0, name.length - 5);
      try {
        out[k] = f.readAsStringSync();
      } catch (_) {}
    }
    return out;
  }

  @override
  void write(Map<String, String?> changes) {
    if (!dir.existsSync()) dir.createSync(recursive: true);
    changes.forEach((k, v) {
      if (!_ok.hasMatch(k)) return;
      final f = File('${dir.path}/$k.json');
      if (v == null) {
        if (f.existsSync()) f.deleteSync();
        return;
      }
      final tmp = File('${dir.path}/$k.json.tmp');
      tmp.writeAsStringSync(v, flush: true);
      tmp.renameSync(f.path);
    });
  }
}

class Store {
  static const schema = 3;
  final KvBackend backend;
  final Map<String, String> _mem = {};
  final Set<String> _dirty = {};
  bool _queued = false;
  int from = schema;
  String mode = 'file';
  int _fails = 0;

  Store(this.backend);

  /// load everything; [legacy] = the data of the WebView app (v1.x), used when this store is still empty, or —
  /// [adopt] — when an earlier move failed and only a near-empty start was made since (v1.x's progress wins)
  void open({Map<String, String>? legacy, bool adopt = false}) {
    Map<String, String> saved;
    try {
      saved = backend.loadAll();
    } catch (_) {
      saved = {};
      mode = 'memory';
    }
    _mem.addAll(saved);
    if (legacy == null || legacy.isEmpty) return;
    if (saved.containsKey('xc_schema') && !adopt) return;
    if (adopt) {
      // v1.x's data replaces the near-empty start (its own keys decide which migrations run)
      _dirty.addAll(_mem.keys);
      _mem.clear();
    }
    legacy.forEach((k, v) {
      _mem[k] = v;
      _dirty.add(k);
    });
  }

  Object? _j(String k) => jsonOrNull(_mem[k]);

  /// the schema version of the data in memory: stored, or recognised from the keys an older version wrote
  int version() {
    final v = _j('xc_schema');
    final n = v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
    if (n != 0) return n;
    if (_mem.keys.any((k) => k.startsWith('xc_'))) return 2;
    if (_mem.containsKey('mm_stats') || _mem.containsKey('hsk16_known')) return 1;
    return schema;
  }

  /// 1 → 2: per-word records become [right, wrong, level]; the oldest list of known words becomes records
  void _m1(Set<String> ids) {
    var st = _j('mm_stats');
    if (st is! Map) {
      st = <String, dynamic>{};
      final known = _j('hsk16_known');
      if (known is List) {
        for (final id in known) {
          if (id is String && ids.contains(id)) st[id] = [1, 0];
        }
      }
    }
    final out = <String, dynamic>{};
    st.forEach((k, e) {
      if (e is! List) return;
      final l = List<dynamic>.of(e);
      if (l.length < 3) {
        while (l.length < 2) {
          l.add(null);
        }
        l.add(cli(i32(l[0]) - i32(l[1]), 0, 20));
      }
      out['$k'] = l;
    });
    put('mm_stats', jsJson(out));
  }

  void migrate(Set<String> ids) {
    from = version();
    for (var v = from; v < schema; v++) {
      if (v == 1) _m1(ids);
      // 2 → 3: the move to IndexedDB, nothing to convert
    }
    if (_j('xc_schema') != schema) put('xc_schema', '$schema');
    flush();
  }

  void put(String k, String? v) {
    if (v == null) {
      _mem.remove(k);
    } else {
      _mem[k] = v;
    }
    _dirty.add(k);
    if (!_queued) {
      _queued = true;
      scheduleMicrotask(() => Timer.run(flush));
    }
  }

  /// write everything waiting (also called when the app goes to the background)
  void flush() {
    _queued = false;
    if (_dirty.isEmpty || mode == 'memory') return;
    final ch = {for (final k in _dirty) k: _mem[k]};
    _dirty.clear();
    try {
      backend.write(ch);
      _fails = 0;
    } catch (_) {
      _dirty.addAll(ch.keys);
      if (++_fails >= 3) {
        mode = 'memory';
        return;
      }
      Timer(const Duration(milliseconds: 1500), flush);
    }
  }

  String? raw(String k) => _mem[k];
  Iterable<String> get keys => _mem.keys;
  Map<String, Object> info() => {'mode': mode, 'from': from, 'schema': schema, 'keys': _mem.length};

  /// ls.get: the JSON value, or [fallback] when missing or broken
  Object? get(String k, [Object? fallback]) {
    final v = _mem[k];
    if (v == null) return fallback;
    try {
      return jsonOrNullStrict(v);
    } on FormatException {
      return fallback;
    }
  }

  /// ls.set
  void set(String k, Object? v) => put(k, jsJson(v));

  /// ls.remove
  void remove(String k) => put(k, null);
}

Object? jsonOrNullStrict(String s) {
  final v = jsonOrNull(s);
  if (v == null && s.trim() != 'null') throw const FormatException();
  return v;
}
