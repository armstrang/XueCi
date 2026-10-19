/// Pinyin and diacritics helpers. JavaScript used Unicode normalization (NFD) for these; Dart has none, so the
/// letters the word data and the four languages use are listed here.
library;

const _toneMarks = {1: 'āēīōūǖĀĒĪŌŪǕ', 2: 'áéíóúǘÁÉÍÓÚǗ', 3: 'ǎěǐǒǔǚǍĚǏǑǓǙ', 4: 'àèìòùǜÀÈÌÒÙǛ'};

/// the tone of a syllable: 1–4 from its mark, 5 = neutral (no mark). Same order of checks as the JS (tone 1 marks first).
int tone(String s) {
  for (final t in const [1, 2, 3, 4]) {
    for (final c in _toneMarks[t]!.runes) {
      if (s.contains(String.fromCharCode(c))) return t;
    }
  }
  return 5;
}

/// toned vowel → [bare vowel, tone]; the bare vowels with ü keep the diaeresis (JS bareSyl removes only tone marks)
const Map<String, String> _bareTone = {
  'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
  'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
  'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
  'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
  'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
  'ǖ': 'ü', 'ǘ': 'ü', 'ǚ': 'ü', 'ǜ': 'ü',
  'Ā': 'A', 'Á': 'A', 'Ǎ': 'A', 'À': 'A',
  'Ē': 'E', 'É': 'E', 'Ě': 'E', 'È': 'E',
  'Ī': 'I', 'Í': 'I', 'Ǐ': 'I', 'Ì': 'I',
  'Ō': 'O', 'Ó': 'O', 'Ǒ': 'O', 'Ò': 'O',
  'Ū': 'U', 'Ú': 'U', 'Ǔ': 'U', 'Ù': 'U',
  'Ǖ': 'Ü', 'Ǘ': 'Ü', 'Ǚ': 'Ü', 'Ǜ': 'Ü',
  'ḿ': 'm', 'ń': 'n', 'ň': 'n', 'ǹ': 'n',
};

/// a syllable without its tone mark (ü stays ü): JS bareSyl
String bareSyl(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(_bareTone[c] ?? c);
  }
  return b.toString();
}

/// Latin letters with any diacritic → the base letter (JS: NFD, then every combining mark removed). Generated from
/// Unicode's decompositions of Latin-1 Supplement, Latin Extended-A/B and Latin Extended Additional (Python unicodedata).
final Map<int, String> _strip = () {
  const from =
      'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǢǣǦǧǨǩǪǫǬǭǮǯǰǴǵǸǹǺǻǼǽǾǿȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳḀḁḂḃḄḅḆḇḈḉḊḋḌḍḎḏḐḑḒḓḔḕḖḗḘḙḚḛḜḝḞḟḠḡḢḣḤḥḦḧḨḩḪḫḬḭḮḯḰḱḲḳḴḵḶḷḸḹḺḻḼḽḾḿṀṁṂṃṄṅṆṇṈṉṊṋṌṍṎṏṐṑṒṓṔṕṖṗṘṙṚṛṜṝṞṟṠṡṢṣṤṥṦṧṨṩṪṫṬṭṮṯṰṱṲṳṴṵṶṷṸṹṺṻṼṽṾṿẀẁẂẃẄẅẆẇẈẉẊẋẌẍẎẏẐẑẒẓẔẕẖẗẘẙẛẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ';
  const to =
      'AAAAAACEEEEIIIINOOOOOUUUUYaaaaaaceeeeiiiinooooouuuuyyAaAaAaCcCcCcCcDdEeEeEeEeEeGgGgGgGgHhIiIiIiIiIJjKkLlLlLlNnNnNnOoOoOoRrRrRrSsSsSsSsTtTtUuUuUuUuUuUuWwYyYZzZzZzOoUuAaIiOoUuUuUuUuUuAaAaÆæGgKkOoOoƷʒjGgNnAaÆæØøAaAaEeEeIiIiOoOoRrRrUuUuSsTtHhAaEeOoOoOoOoYyAaBbBbBbCcDdDdDdDdDdEeEeEeEeEeFfGgHhHhHhHhHhIiIiKkKkKkLlLlLlLlMmMmMmNnNnNnNnOoOoOoOoPpPpRrRrRrRrSsSsSsSsSsTtTtTtTtUuUuUuUuUuVvVvWwWwWwWwWwXxXxYyZzZzZzhtwyſAaAaAaAaAaAaAaAaAaAaAaAaEeEeEeEeEeEeEeEeIiIiOoOoOoOoOoOoOoOoOoOoOoOoUuUuUuUuUuUuUuYyYyYyYy';
  final f = from.runes.toList(), t = to.runes.toList();
  return {for (var i = 0; i < f.length; i++) f[i]: String.fromCharCode(t[i])};
}();

/// every diacritic removed (JS: s.normalize('NFD').replace(/\p{M}/gu, ''))
String stripMarks(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final x = _strip[r];
    if (x != null) {
      b.write(x);
    } else if (!_isMark(r)) {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

bool _isMark(int r) =>
    (r >= 0x0300 && r <= 0x036F) ||
    (r >= 0x1AB0 && r <= 0x1AFF) ||
    (r >= 0x1DC0 && r <= 0x1DFF) ||
    (r >= 0x20D0 && r <= 0x20FF) ||
    (r >= 0xFE20 && r <= 0xFE2F) ||
    // Thai combining vowels and tone marks (\p{M} in JS)
    r == 0x0E31 ||
    (r >= 0x0E34 && r <= 0x0E3A) ||
    (r >= 0x0E47 && r <= 0x0E4E);

/// the search key of pinyin: no tone marks, no spaces or apostrophes, lower case (JS plain(); ü loses its dots too)
String plain(String s) => stripMarks(s).replaceAll('ü', 'v').replaceAll(RegExp(r"['\s]"), '').toLowerCase();

/// Vietnamese without marks, for searching (JS unmark())
String unmark(String s) => stripMarks(s).replaceAll('đ', 'd').replaceAll('Đ', 'D');

const _marks = {'a': 'āáǎà', 'e': 'ēéěè', 'i': 'īíǐì', 'o': 'ōóǒò', 'u': 'ūúǔù', 'ü': 'ǖǘǚǜ'};

/// a bare syllable with tone t put on the right vowel (JS markTone)
String markTone(String p, int t) {
  if (t == 5) return p;
  final low = p.toLowerCase();
  var i = low.indexOf('a');
  if (i < 0) i = low.indexOf('e');
  if (i < 0 && low.contains('ou')) i = low.indexOf('o');
  if (i < 0) {
    for (var j = low.length - 1; j >= 0; j--) {
      if ('iouü'.contains(low[j])) {
        i = j;
        break;
      }
    }
  }
  if (i < 0) return p;
  final ch = low[i];
  final m = _marks[ch];
  if (m == null) return p;
  var r = m[t - 1];
  if (p[i] != ch) r = r.toUpperCase();
  return p.substring(0, i) + r + p.substring(i + 1);
}
