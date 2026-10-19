/// Small helpers that make the Dart port behave exactly like the JavaScript engine it replaces (v1.x, learn.js):
/// JS rounding, JS integer conversion, V8's sort order, the same chance source in tests, JSON numbers written the
/// way JSON.stringify writes them. The engine's results must not change with the move to Flutter.
library;

import 'dart:convert';
import 'dart:math' as math;

/// Math.round: halves go up (towards +∞), unlike Dart's round() which goes away from zero.
int jsRound(num x) {
  final f = x.floorToDouble();
  return (x - f >= 0.5) ? f.toInt() + 1 : f.toInt();
}

/// x | 0 for the values the engine meets: numbers are truncated, anything else is 0.
int i32(Object? v) {
  if (v is int) return v.toSigned(32);
  if (v is double) {
    if (!v.isFinite) return 0;
    return v.truncate().toSigned(32);
  }
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final d = double.tryParse(v.trim());
    return d == null || !d.isFinite ? 0 : d.truncate().toSigned(32);
  }
  return 0;
}

/// Number.isFinite
bool isFin(Object? v) => v is num && v.isFinite;

/// Number.isInteger
bool isInt(Object? v) => v is int || (v is double && v.isFinite && v == v.truncateToDouble());

/// a JSON number as double (null when it is not a number)
double? numOrNull(Object? v) => v is num ? v.toDouble() : null;

double cl(num x, num a, num b) => math.min(b.toDouble(), math.max(a.toDouble(), x.toDouble()));
int cli(int x, int a, int b) => math.min(b, math.max(a, x));

/// The chance source. The app uses [JsRandom.system]; the tests use the same seeded generator as tests/engine.js,
/// so the Dart engine can be checked against traces of the JavaScript engine.
abstract class JsRandom {
  double next();

  static JsRandom system() => _SysRandom();
  static JsRandom lcg(int seed) => LcgRandom(seed);
}

class _SysRandom implements JsRandom {
  final _r = math.Random();
  @override
  double next() => _r.nextDouble();
}

/// seed = (seed · 1103515245 + 12345) mod 2^31, in double arithmetic like the JS stand-in for Math.random
class LcgRandom implements JsRandom {
  double seed;
  LcgRandom(int s) : seed = s.toDouble();
  @override
  double next() {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    return seed / 2147483648;
  }
}

/// The comparison order of V8's Array.prototype.sort (TimSort). For a consistent comparison any stable sort gives the
/// same order; one comparison draws chances (ptNext), so the exact calls of V8 matter there. Arrays under 64 items
/// are sorted exactly like V8 (one run + binary insertion); longer ones with a stable merge sort.
void jsSort<T>(List<T> a, num Function(T a, T b) cmp) {
  final n = a.length;
  if (n < 2) return;
  if (n >= 64) {
    _mergeSort(a, cmp);
    return;
  }
  // CountAndMakeRun(0, n)
  var run = 2;
  var order = cmp(a[1], a[0]);
  final desc = order < 0;
  var prev = a[1];
  for (var i = 2; i < n; i++) {
    final cur = a[i];
    order = cmp(cur, prev);
    if (desc) {
      if (order >= 0) break;
    } else {
      if (order < 0) break;
    }
    prev = cur;
    run++;
  }
  if (desc) {
    for (var lo = 0, hi = run - 1; lo < hi; lo++, hi--) {
      final t = a[lo];
      a[lo] = a[hi];
      a[hi] = t;
    }
  }
  if (run >= n) return;
  // BinaryInsertionSort(0, run, n)
  for (var start = run; start < n; start++) {
    var left = 0, right = start;
    final pivot = a[start];
    while (left < right) {
      final mid = left + ((right - left) >> 1);
      if (cmp(pivot, a[mid]) < 0) {
        right = mid;
      } else {
        left = mid + 1;
      }
    }
    for (var p = start; p > left; p--) {
      a[p] = a[p - 1];
    }
    a[left] = pivot;
  }
}

void _mergeSort<T>(List<T> a, num Function(T a, T b) cmp) {
  final tmp = List<T>.of(a);
  void sort(int lo, int hi) {
    if (hi - lo < 2) return;
    final mid = (lo + hi) >> 1;
    sort(lo, mid);
    sort(mid, hi);
    if (cmp(a[mid], a[mid - 1]) >= 0) return;
    var i = lo, j = mid, k = lo;
    while (i < mid && j < hi) {
      if (cmp(a[j], a[i]) < 0) {
        tmp[k++] = a[j++];
      } else {
        tmp[k++] = a[i++];
      }
    }
    while (i < mid) {
      tmp[k++] = a[i++];
    }
    while (j < hi) {
      tmp[k++] = a[j++];
    }
    for (var x = lo; x < hi; x++) {
      a[x] = tmp[x];
    }
  }

  sort(0, a.length);
}

/// a sorted copy (JS: a.slice().sort(cmp))
List<T> sorted<T>(Iterable<T> a, num Function(T a, T b) cmp) {
  final l = List<T>.of(a);
  jsSort(l, cmp);
  return l;
}

num byNum(num a, num b) => a - b;

/// the characters of a string (JS [...s]: code points)
List<String> chars(String s) => s.runes.map(String.fromCharCode).toList();
int charLen(String s) => s.runes.length;

/// JSON.stringify: numbers as JS writes them (3 not 3.0), no spaces
String jsJson(Object? v) => json.encode(_jsNums(v));

Object? _jsNums(Object? v) {
  if (v is double) {
    if (v.isFinite && v == v.truncateToDouble() && v.abs() < 9007199254740992) return v.toInt();
    if (!v.isFinite) return null;
    return v;
  }
  if (v is List) return v.map(_jsNums).toList();
  if (v is Map) return v.map((k, x) => MapEntry(k.toString(), _jsNums(x)));
  return v;
}

/// JSON.parse that never throws (null when the text is not JSON)
Object? jsonOrNull(String? s) {
  if (s == null) return null;
  try {
    return json.decode(s);
  } catch (_) {
    return null;
  }
}

/// a deep copy of JSON-like data
Object? deepCopy(Object? v) {
  if (v is List) return v.map(deepCopy).toList();
  if (v is Map) return v.map((k, x) => MapEntry(k, deepCopy(x)));
  return v;
}

double maxOf(Iterable<num> a) => a.fold<double>(double.negativeInfinity, (m, x) => x > m ? x.toDouble() : m);
double sumOf(Iterable<num> a) => a.fold<double>(0, (s, x) => s + x);
