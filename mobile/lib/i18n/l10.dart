/// Interface text in the four study languages. The text comes from the WebView app's sources (web/src/i18n*.js),
/// converted by tool/make_i18n.js: plain strings stay strings, text with numbers in it is a small expression tree
/// evaluated here with JavaScript's rules (so `${n}` prints 3, not 3.0). Only `<b>` is used as markup.
library;

import 'dart:convert';

import 'package:flutter/painting.dart';

part 'keys.g.dart';

class L10 with L10Keys {
  final String lang;
  final Map<String, dynamic> m;
  L10(this.lang, this.m);

  factory L10.fromJson(String lang, String text) => L10(lang, (json.decode(text) as Map).cast<String, dynamic>());

  /// the text that exists only past the gate (from the sealed part)
  void addSealed(Map<String, dynamic>? delta) {
    if (delta != null) m.addAll(delta);
  }

  @override
  String s(String k) => text(m[k]);

  @override
  String f(String k, List<Object?> a) => text(m[k], a);

  @override
  Object? v(String k) => m[k];

  /// any value: a string, or a function called with [a]
  static String text(Object? x, [List<Object?> a = const []]) {
    if (x is String) return x;
    if (x is Map && x.containsKey(r'$f')) return jsStr(Tpl.ev(x['b'] as List, a));
    if (x == null) return '';
    return jsStr(x);
  }

  String get locale => s('loc');
}

/// JavaScript's String(x) for the values the texts use
String jsStr(Object? x) {
  if (x == null) return '';
  if (x is String) return x;
  if (x is bool) return x ? 'true' : 'false';
  if (x is int) return '$x';
  if (x is double) {
    if (x.isNaN) return 'NaN';
    if (x.isInfinite) return x > 0 ? 'Infinity' : '-Infinity';
    if (x == x.truncateToDouble() && x.abs() < 1e21) return x.toInt().toString();
    return x.toString();
  }
  if (x is List) return x.map(jsStr).join(',');
  return x.toString();
}

bool jsTruthy(Object? x) =>
    x != null && x != false && x != 0 && x != '' && !(x is double && x.isNaN);

num _num(Object? x) {
  if (x is num) return x;
  if (x is bool) return x ? 1 : 0;
  if (x == null) return 0;
  if (x is String) return num.tryParse(x.trim()) ?? double.nan;
  return double.nan;
}

bool _eq(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  return a == b;
}

class Tpl {
  static Object? ev(List n, List<Object?> a) {
    switch (n[0] as String) {
      case 's':
      case 'n':
      case 'b':
        return n[1];
      case 'null':
        return null;
      case 'a':
        final i = (n[1] as num).toInt();
        return i < a.length ? a[i] : null;
      case 't':
        final parts = n[1] as List;
        final b = StringBuffer();
        for (var i = 0; i < parts.length; i++) {
          b.write(i.isEven ? parts[i] as String : jsStr(ev(parts[i] as List, a)));
        }
        return b.toString();
      case '?':
        return jsTruthy(ev(n[1] as List, a)) ? ev(n[2] as List, a) : ev(n[3] as List, a);
      case '&&':
        final l = ev(n[1] as List, a);
        return jsTruthy(l) ? ev(n[2] as List, a) : l;
      case '||':
        final l = ev(n[1] as List, a);
        return jsTruthy(l) ? l : ev(n[2] as List, a);
      case '!':
        return !jsTruthy(ev(n[1] as List, a));
      case 'neg':
        return -_num(ev(n[1] as List, a));
      case 'num':
        return _num(ev(n[1] as List, a));
      case '.':
        final o = ev(n[1] as List, a), k = ev(n[2] as List, a);
        if (o is List) {
          if (k == 'length') return o.length;
          final i = k is num ? k.toInt() : int.tryParse('$k');
          return i != null && i >= 0 && i < o.length ? o[i] : null;
        }
        if (o is Map) return o[jsStr(k)];
        if (o is String) {
          if (k == 'length') return o.length;
          final i = k is num ? k.toInt() : null;
          return i != null && i >= 0 && i < o.length ? o[i] : null;
        }
        return null;
      case 'op':
        final op = n[1] as String;
        final l = ev(n[2] as List, a), r = ev(n[3] as List, a);
        switch (op) {
          case '+':
            if (l is String || r is String || l is List || r is List) return jsStr(l) + jsStr(r);
            return _num(l) + _num(r);
          case '-':
            return _num(l) - _num(r);
          case '*':
            return _num(l) * _num(r);
          case '/':
            return _num(l) / _num(r);
          case '%':
            return _num(l).remainder(_num(r));
          case '===':
          case '==':
            return _eq(l, r);
          case '!==':
          case '!=':
            return !_eq(l, r);
          case '<':
          case '>':
          case '<=':
          case '>=':
            if (l is String && r is String) {
              final c = l.compareTo(r);
              return switch (op) { '<' => c < 0, '>' => c > 0, '<=' => c <= 0, _ => c >= 0 };
            }
            final x = _num(l), y = _num(r);
            return switch (op) { '<' => x < y, '>' => x > y, '<=' => x <= y, _ => x >= y };
        }
    }
    throw StateError('i18n: unknown node ${n[0]}');
  }
}

/// text with `<b>bold</b>` → spans (the only markup the texts use)
List<TextSpan> richSpans(String t, {TextStyle? bold}) {
  final out = <TextSpan>[];
  final re = RegExp(r'<b>(.*?)</b>', dotAll: true);
  var i = 0;
  for (final m in re.allMatches(t)) {
    if (m.start > i) out.add(TextSpan(text: t.substring(i, m.start)));
    out.add(TextSpan(text: m.group(1), style: bold ?? const TextStyle(fontWeight: FontWeight.w700)));
    i = m.end;
  }
  if (i < t.length) out.add(TextSpan(text: t.substring(i)));
  return out;
}

/// the same text without markup (for screen readers and plain labels)
String plainText(String t) => t.replaceAll(RegExp(r'</?b>'), '');
