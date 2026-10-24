/// The app's icons, drawn from SVG path data (24×24 viewBox, round strokes).
library;

import 'package:flutter/widgets.dart';

/// SVG path data → a Flutter Path (M L H V C S Q T A Z, absolute and relative)
Path svgPath(String d) {
  final p = Path();
  final re = RegExp(
    r'([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)',
  );
  final toks = re.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  double x = 0, y = 0, sx = 0, sy = 0; // current point, subpath start
  double? cx2, cy2; // last control point (for S/T)
  String last = '';
  bool isNum(String t) => !RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(toks[i++]);
  bool flag() {
    // flags may be written without separators ("0 1 1" or "011"); our data always separates them
    return n() != 0;
  }

  while (i < toks.length) {
    if (!isNum(toks[i])) {
      cmd = toks[i++];
    } else if (cmd == 'M') {
      cmd = 'L';
    } else if (cmd == 'm') {
      cmd = 'l';
    }
    final rel = cmd == cmd.toLowerCase() && cmd != 'z' ? true : false;
    final c = cmd.toUpperCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (c) {
      case 'M':
        x = ox + n();
        y = oy + n();
        p.moveTo(x, y);
        sx = x;
        sy = y;
        cx2 = null;
        break;
      case 'L':
        x = ox + n();
        y = oy + n();
        p.lineTo(x, y);
        cx2 = null;
        break;
      case 'H':
        x = ox + n();
        p.lineTo(x, y);
        cx2 = null;
        break;
      case 'V':
        y = oy + n();
        p.lineTo(x, y);
        cx2 = null;
        break;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        p.cubicTo(x1, y1, x2, y2, x, y);
        cx2 = x2;
        cy2 = y2;
        break;
      case 'S':
        final x1 = (last == 'C' || last == 'S') && cx2 != null
            ? 2 * x - cx2
            : x;
        final y1 = (last == 'C' || last == 'S') && cy2 != null
            ? 2 * y - cy2
            : y;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        p.cubicTo(x1, y1, x2, y2, x, y);
        cx2 = x2;
        cy2 = y2;
        break;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        p.quadraticBezierTo(x1, y1, x, y);
        cx2 = x1;
        cy2 = y1;
        break;
      case 'T':
        final x1 = (last == 'Q' || last == 'T') && cx2 != null
            ? 2 * x - cx2
            : x;
        final y1 = (last == 'Q' || last == 'T') && cy2 != null
            ? 2 * y - cy2
            : y;
        x = ox + n();
        y = oy + n();
        p.quadraticBezierTo(x1, y1, x, y);
        cx2 = x1;
        cy2 = y1;
        break;
      case 'A':
        final rx = n(), ry = n(), rot = n();
        final large = flag(), sweep = flag();
        x = ox + n();
        y = oy + n();
        p.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        cx2 = null;
        break;
      case 'Z':
        if (i < toks.length && isNum(toks[i])) i++;
        p.close();
        x = sx;
        y = sy;
        cx2 = null;
        break;
    }
    last = c;
  }
  return p;
}

/// one icon: stroked and/or filled paths, plus circles and rounded rects, in a 24×24 box
class Ic {
  final List<String> stroke;
  final List<String> fill;
  final List<(double, double, double)> circles; // cx, cy, r (stroked)
  final List<(double, double, double)> dots; // filled circles
  final List<(double, double, double, double, double)>
  rects; // x, y, w, h, rx (stroked)
  final double width;
  final double vb;
  const Ic({
    this.stroke = const [],
    this.fill = const [],
    this.circles = const [],
    this.dots = const [],
    this.rects = const [],
    this.width = 1.9,
    this.vb = 24,
  });

  static final _cache = <String, Path>{};
  Path path(String d) => _cache[d] ??= svgPath(d);
}

class Icon2 extends StatelessWidget {
  final Ic icon;
  final double size;
  final Color color;
  final double? width;
  const Icon2(
    this.icon, {
    super.key,
    this.size = 22,
    required this.color,
    this.width,
  });
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IcPainter(icon, color, width),
    ),
  );
}

class _IcPainter extends CustomPainter {
  final Ic ic;
  final Color color;
  final double? width;
  _IcPainter(this.ic, this.color, this.width);
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / ic.vb;
    c.scale(k, s.height / ic.vb);
    final st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width ?? ic.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fl = Paint()..color = color;
    for (final d in ic.fill) {
      c.drawPath(ic.path(d), fl);
    }
    for (final d in ic.stroke) {
      c.drawPath(ic.path(d), st);
    }
    for (final (x, y, r) in ic.circles) {
      c.drawCircle(Offset(x, y), r, st);
    }
    for (final (x, y, r) in ic.dots) {
      c.drawCircle(Offset(x, y), r, fl);
    }
    for (final (x, y, w, h, r) in ic.rects) {
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        st,
      );
    }
  }

  @override
  bool shouldRepaint(_IcPainter o) =>
      o.ic != ic || o.color != color || o.width != width;
}

/// the icons of app.html and the screens' scripts
class I {
  static const home = Ic(
    stroke: [
      'M3.5 10.5 12 3.8l8.5 6.7V19a1.5 1.5 0 0 1-1.5 1.5h-4v-6h-6v6H5A1.5 1.5 0 0 1 3.5 19z',
    ],
  );
  static const list = Ic(
    stroke: ['M9 6h11M9 12h11M9 18h11', 'M4 6h1M4 12h1M4 18h1'],
  );
  static const cards = Ic(
    stroke: ['M8 3h10.5A2.5 2.5 0 0 1 21 5.5V17'],
    rects: [(3, 7, 13, 14, 2.5)],
  );
  static const star = Ic(
    stroke: [
      'M12 3l2.6 5.6 6.1.7-4.5 4.2 1.2 6L12 16.6 6.6 19.5l1.2-6L3.3 9.3l6.1-.7z',
    ],
  );
  // ---- the quiz types (Josh: icons only, black and white)
  /// a rounded square for a glyph inside (Recognise: 汉)
  static const qBox = Ic(rects: [(3, 3, 18, 18, 5)], width: 1.8);

  /// write the hanzi: a pencil
  static const qWrite = Ic(stroke: ['M4.5 19.5l1-4.2L15.8 5a2 2 0 0 1 2.9 0l.3.3a2 2 0 0 1 0 2.9L8.7 18.5z', 'M13.8 7l3.2 3.2', 'M4.5 19.5h15'], width: 1.8);

  /// tones: the four marks rising and falling
  static const qTones = Ic(stroke: ['M2 10h3.6', 'M7.4 13.5l3-5', 'M12.2 8.5l1.8 4 1.8-4', 'M18 8.5l3 5'], dots: [(3.8, 17, 1.1), (8.9, 17, 1.1), (14, 17, 1.1), (19.5, 17, 1.1)], width: 2);

  /// a sentence with a gap
  static const qGap = Ic(stroke: ['M3 6.5h18', 'M3 12h4', 'M17 12h4', 'M3 17.5h11'], rects: [(8.5, 9, 7, 6, 1.6)], width: 1.9);

  /// type the pinyin: a keyboard
  static const qKeys = Ic(rects: [(2.5, 6, 19, 12.5, 3)], dots: [(7, 10, 1), (10.3, 10, 1), (13.7, 10, 1), (17, 10, 1)], stroke: ['M8 14.6h8'], width: 1.8);

  /// translate (Bing Translator's two boxes, black and white): A in one, 文 drawn in the other
  static const qTrans = Ic(
    stroke: ['M5 11l2.75-6.5 2.75 6.5', 'M6 9h3.5', 'M16.2 12.4v1.2', 'M13.3 14h5.8', 'M14.4 14.4c.8 2.4 2.4 3.9 4.4 4.5', 'M18.1 14.4c-.8 2.4-2.4 3.9-4.4 4.5'],
    rects: [(2, 2, 11.5, 11.5, 3), (10.5, 10.5, 11.5, 11.5, 3)],
    width: 1.6,
  );

  /// the HSK mock exam: a paper with a tick
  static const qExam = Ic(stroke: ['M8.5 8h7', 'M8.5 11.6h7', 'M8.6 16.2l1.7 1.7 3.4-3.4'], rects: [(4.5, 2.5, 15, 19, 3)], width: 1.8);

  /// speaking: a microphone
  static const mic = Ic(
    stroke: ['M5.5 11a6.5 6.5 0 0 0 13 0', 'M12 17.5V21'],
    rects: [(9, 3, 6, 11, 3)],
    width: 2,
  );

  /// the quiz tab: a question in a rounded square
  static const quiz = Ic(
    stroke: ['M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .8-1 1.5V14'],
    rects: [(3.5, 3.5, 17, 17, 4.5)],
    dots: [(12, 17.2, 1.15)],
  );

  /// the Soul Sea tab: an orb with its core and four rays
  static const orb = Ic(
    stroke: ['M12 2.8v2.6M12 18.6v2.6M2.8 12h2.6M18.6 12h2.6'],
    circles: [(12, 12, 7.6), (12, 12, 3)],
  );
  static const flame = Ic(
    stroke: [
      'M12 21c-3.9 0-6.5-2.6-6.5-6.2 0-3.3 2.2-5.4 3.6-7.6.3 1.7 1.2 2.9 2.3 3.4C11.2 7.5 12.6 4.6 15 3c-.3 3 .9 4.8 2.1 6.6 1 1.5 1.4 3 1.4 4.6C18.5 18.4 15.9 21 12 21z',
      'M12 21c-1.7 0-2.9-1.2-2.9-2.9 0-1.6 1.2-2.6 2.1-3.9.3 1 .9 1.6 1.6 1.8.2-.9.7-1.7 1.4-2.3.4 1.2 1.6 2.2 1.6 4 0 2-1.6 3.3-3.8 3.3z',
    ],
  );
  static const gear = Ic(
    stroke: [
      'M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
    ],
    circles: [(12, 12, 3)],
  );
  static const back = Ic(stroke: ['M15 5l-7 7 7 7'], width: 2.4);
  static const chev = Ic(stroke: ['m6 9 6 6 6-6'], width: 2.4);
  static const check = Ic(stroke: ['m5 12.5 4.5 4.5L19 7.5'], width: 2.6);
  static const play = Ic(
    fill: [
      'M8 5.5v13a1 1 0 0 0 1.5.86l10.6-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5z',
    ],
  );
  static const share = Ic(
    stroke: [
      'M12 15V3.5M7.5 8 12 3.5 16.5 8',
      'M5 12.5V18a2.5 2.5 0 0 0 2.5 2.5h9A2.5 2.5 0 0 0 19 18v-5.5',
    ],
    width: 2.2,
  );
  static const search = Ic(
    stroke: ['m20 20-3.5-3.5'],
    circles: [(11, 11, 7)],
    width: 2.4,
  );
  static const eyeOff = Ic(
    stroke: [
      'M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c5 0 9 4.5 10 7a13 13 0 0 1-3.2 4.2M6.2 6.2A13 13 0 0 0 2 12c1 2.5 5 7 10 7a9.8 9.8 0 0 0 4.3-1',
    ],
    width: 2.2,
  );
  static const lock = Ic(
    stroke: ['M8 11V8a4 4 0 0 1 8 0v3'],
    rects: [(5, 11, 14, 9.5, 2)],
    width: 2.2,
  );
  static const device = Ic(
    stroke: ['M11 18.5h2'],
    rects: [(6.5, 2.5, 11, 19, 2.5)],
    width: 2.2,
  );
  static const incense = Ic(
    stroke: ['M10 20.5V10.2', 'M5.4 20.5h9.2'],
    width: 2.4,
    vb: 20,
  );
  static const smoke = Ic(
    stroke: ['M10 7.6c-2.6-2 1.4-3.6 0-6.4'],
    width: 2.4,
    vb: 20,
  );
  static const speaker = Ic(
    stroke: ['M15.5 9a4 4 0 0 1 0 6', 'M18 6.5a7.5 7.5 0 0 1 0 11'],
    fill: ['M4 9.5v5h3.5L12 19V5L7.5 9.5z'],
    width: 2.2,
  );
  static const themeAuto = Ic(
    stroke: [],
    circles: [(12, 12, 8.5)],
    fill: ['M12 3.5v17A8.5 8.5 0 0 0 12 3.5z'],
    width: 2.2,
  );
  static const themeLight = Ic(
    stroke: [
      'M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8',
    ],
    circles: [(12, 12, 4.5)],
    width: 2.2,
  );
  static const themeDark = Ic(
    stroke: ['M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z'],
    width: 2.2,
  );
  static const themeBlack = Ic(
    fill: ['M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z'],
    dots: [(18.5, 4.5, 1.3), (21.2, 8.6, .85)],
  );
  static const close = Ic(stroke: ['M6 6l12 12M18 6 6 18'], width: 2.4);

  // settings rows
  static const globe = Ic(
    stroke: [
      'M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9M12 3C9.5 5.6 8.2 8.6 8.2 12s1.3 6.4 3.8 9',
    ],
    circles: [(12, 12, 9)],
    width: 2,
  );
  static const target = Ic(circles: [(12, 12, 9), (12, 12, 4.5)], width: 2);
  static const sync = Ic(
    stroke: [
      'M20 11a8 8 0 0 0-14.6-4.5L4 8',
      'M4 3.5V8h4.5',
      'M4 13a8 8 0 0 0 14.6 4.5L20 16',
      'M20 20.5V16h-4.5',
    ],
    width: 2.1,
  );
  static const flask = Ic(
    stroke: ['M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3'],
    width: 2,
  );
  static const tour = Ic(
    stroke: ['m10 8 5 4-5 4z'],
    circles: [(12, 12, 9)],
    width: 2,
  );

  /// a cash coin (铜钱): the 护法 donation button
  static const coin = Ic(
    fill: [
      'M2 12A10 10 0 1 1 22 12A10 10 0 1 1 2 12Z M3.6 12A8.4 8.4 0 1 0 20.4 12A8.4 8.4 0 1 0 3.6 12Z M4.6 12A7.4 7.4 0 1 1 19.4 12A7.4 7.4 0 1 1 4.6 12Z M9.2 9.2V14.8H14.8V9.2Z',
    ],
  );
  static const shield = Ic(
    stroke: ['M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6z'],
    width: 2,
  );
  static const upload = Ic(
    stroke: [
      'M12 15V4',
      'M7.5 8.5 12 4l4.5 4.5',
      'M5 14v4.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V14',
    ],
    width: 2.3,
  );
  static const download = Ic(
    stroke: [
      'M12 4v11',
      'M7.5 10.5 12 15l4.5-4.5',
      'M5 14v4.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V14',
    ],
    width: 2.3,
  );
  static const github = Ic(
    fill: [
      'M12 .5a11.5 11.5 0 0 0-3.64 22.41c.58.1.79-.25.79-.56v-2c-3.2.7-3.88-1.37-3.88-1.37-.53-1.33-1.28-1.69-1.28-1.69-1.05-.71.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.68 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.41-2.69 5.38-5.25 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .5z',
    ],
  );
}
