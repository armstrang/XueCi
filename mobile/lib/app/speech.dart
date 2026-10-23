/// Speaking practice: the phone's own speech recognizer hears the learner (Native.listen) and every hanzi of the
/// target is marked right or wrong. A heard character counts when it is the same character, or one that sounds the
/// same: same syllable and tone (normal), same syllable in any tone (easy). Hard takes only the recognizer's first
/// guess, normal and easy the best of its guesses.
library;

import '../data/pinyin.dart';
import '../data/words.dart';

/// the levels of strictness (Settings): easy, normal, hard
const spkLevels = ['e', 'n', 'h'];

class SpeakResult {
  /// per character of the target (punctuation and spaces count as right)
  final List<bool> ok;

  /// what the phone heard (the guess that matched best)
  final String heard;
  const SpeakResult(this.ok, this.heard);
  int get right => ok.where((x) => x).length;
  bool get all => ok.every((x) => x);

  /// the share of characters said right (punctuation left out)
  double share(String target) {
    var n = 0, r = 0;
    final ch = target.runes.map(String.fromCharCode).toList();
    for (var i = 0; i < ch.length; i++) {
      if (!isHan(ch[i])) continue;
      n++;
      if (ok[i]) r++;
    }
    return n == 0 ? 1 : r / n;
  }
}

bool isHan(String c) {
  final r = c.runes.first;
  return (r >= 0x4e00 && r <= 0x9fff) || (r >= 0x3400 && r <= 0x4dbf);
}

/// the readings of each character, gathered from the words (one syllable per character)
class CharSounds {
  final Map<String, Set<String>> _toned = {};
  final Map<String, Set<String>> _bare = {};
  CharSounds(Iterable<Word> words) {
    for (final d in words) {
      final ch = d.h.runes.map(String.fromCharCode).toList();
      if (ch.length != d.s.length) continue;
      for (var i = 0; i < ch.length; i++) {
        final syl = plain(d.s[i]).replaceAll(RegExp('[^a-z]'), '');
        if (syl.isEmpty) continue;
        final t = tone(d.s[i]);
        (_toned[ch[i]] ??= {}).add('$syl$t');
        (_bare[ch[i]] ??= {}).add(syl);
      }
    }
  }

  bool same(String a, String b, String level) {
    if (a == b) return true;
    final m = level == 'e' ? _bare : _toned;
    final x = m[a], y = m[b];
    if (x == null || y == null) return false;
    return x.any(y.contains);
  }
}

/// marks each character of [target] against the guesses in [heard]
SpeakResult scoreSpeech(String target, List<String> heard, String level, CharSounds cs) {
  final tc = target.runes.map(String.fromCharCode).toList();
  if (heard.isEmpty) return SpeakResult([for (final c in tc) !isHan(c)], '');
  final guesses = level == 'h' ? heard.take(1) : heard;
  SpeakResult? best;
  for (final g in guesses) {
    final hc = g.runes.map(String.fromCharCode).where(isHan).toList();
    final ok = _align(tc, hc, level, cs);
    final r = SpeakResult(ok, g);
    if (best == null || r.right > best.right) best = r;
  }
  return best!;
}

/// edit-distance alignment of the target's hanzi with the heard hanzi; a target character is right when it is
/// paired with a character that matches
List<bool> _align(List<String> tc, List<String> hc, String level, CharSounds cs) {
  final idx = [for (var i = 0; i < tc.length; i++) if (isHan(tc[i])) i];
  final t = [for (final i in idx) tc[i]];
  final n = t.length, m = hc.length;
  final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final sub = d[i - 1][j - 1] + (cs.same(t[i - 1], hc[j - 1], level) ? 0 : 1);
      final del = d[i - 1][j] + 1, ins = d[i][j - 1] + 1;
      d[i][j] = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
    }
  }
  final hit = List<bool>.filled(n, false);
  var i = n, j = m;
  while (i > 0 && j > 0) {
    final match = cs.same(t[i - 1], hc[j - 1], level);
    if (d[i][j] == d[i - 1][j - 1] + (match ? 0 : 1)) {
      hit[i - 1] = match;
      i--;
      j--;
    } else if (d[i][j] == d[i - 1][j] + 1) {
      i--;
    } else {
      j--;
    }
  }
  final out = [for (final c in tc) !isHan(c)];
  for (var k = 0; k < idx.length; k++) {
    out[idx[k]] = hit[k];
  }
  return out;
}
