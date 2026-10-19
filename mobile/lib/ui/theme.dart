/// Colours and type, from the WebView app's CSS (base.css.html + glass.css.html): the light, dark and true-black
/// themes, level colours, tone colours, the five elements, and the Liquid Glass materials.
library;

import 'package:flutter/material.dart';

Color _c(int v) => Color(v);
Color _w(double a) => Color.fromRGBO(255, 255, 255, a);

class Pal {
  final Brightness brightness;
  final bool black;
  final Color bg, surface, sunk, line, fg, soft, mute, mark, onAcc;
  final Color bgTop, bgBot;
  final double glowO;
  final List<Color> lv; // HSK 1–9 (index 0 = HSK 1)
  final List<Color> tone; // tones 1–5
  final Color sRed, sYellow, sGreen, sNone, good, bad, gold;
  final Color elWood, elFire, elEarth, elMetal, elWater;
  // glass
  final double gFillTop, gFillA, gFillB, gFillC; // radial highlight, then the 135° gradient stops
  final double gSolidTop, gSolid;
  final Color gHead, gBar, gEdge;
  final double f0, f1, r0, r1, r2, card;
  final Color warm;
  final List<BoxShadow> drop;
  final double insetTop; // the bright line inside the top edge

  const Pal({
    required this.brightness,
    this.black = false,
    required this.bg,
    required this.surface,
    required this.sunk,
    required this.line,
    required this.fg,
    required this.soft,
    required this.mute,
    required this.mark,
    required this.onAcc,
    required this.bgTop,
    required this.bgBot,
    required this.glowO,
    required this.lv,
    required this.tone,
    required this.sRed,
    required this.sYellow,
    required this.sGreen,
    required this.sNone,
    required this.good,
    required this.bad,
    required this.gold,
    required this.elWood,
    required this.elFire,
    required this.elEarth,
    required this.elMetal,
    required this.elWater,
    required this.gFillTop,
    required this.gFillA,
    required this.gFillB,
    required this.gFillC,
    required this.gSolidTop,
    required this.gSolid,
    required this.gHead,
    required this.gBar,
    required this.gEdge,
    required this.f0,
    required this.f1,
    required this.r0,
    required this.r1,
    required this.r2,
    required this.card,
    required this.warm,
    required this.drop,
    required this.insetTop,
  });

  bool get dark => brightness == Brightness.dark;

  /// the colour of an HSK level (1–9)
  Color l(int level) => lv[(level.clamp(1, 9)) - 1];

  /// the colour of a realm (0 凡人 = mute, past the last level = gold)
  Color realm(int r, {bool band = false}) =>
      r < 1 ? mute : (r > 9 || (r > 6 && !band) ? gold : l(r));

  Color t(int n) => tone[(n.clamp(1, 5)) - 1];

  /// green / yellow / red / none: how well a word is known
  Color band(String b) => switch (b) {
    'green' => sGreen,
    'yellow' => sYellow,
    'red' => sRed,
    _ => sNone,
  };

  Color element(String e) => switch (e) {
    'wood' => elWood,
    'fire' => elFire,
    'earth' => elEarth,
    'metal' => elMetal,
    _ => elWater,
  };

  /// color-mix(in srgb, a p%, b)
  static Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;
  Color fgA(double a) => fg.withValues(alpha: a);

  static final lightP = Pal(
    brightness: Brightness.light,
    bg: _c(0xffeceef1),
    surface: _c(0xfff6f7f9),
    sunk: _c(0xffe0e3e8),
    line: _c(0xffd6dae0),
    fg: _c(0xff161a22),
    soft: _c(0xff4f5767),
    mute: _c(0xff636a78),
    mark: _c(0xffffe1a8),
    onAcc: _c(0xffffffff),
    bgTop: _c(0xfff5f6f8),
    bgBot: _c(0xffe1e4e9),
    glowO: .55,
    lv: [
      _c(0xff2f8a4c), _c(0xff0f7f88), _c(0xff1f78b4), _c(0xff3c4fb8), _c(0xff7a46b8), _c(0xffa3386f), //
      _c(0xffa8730f), _c(0xffb23a2a), _c(0xff3d4766),
    ],
    tone: [_c(0xffc4362a), _c(0xffa85c06), _c(0xff1d7d4d), _c(0xff2a62c0), _c(0xff6a716d)],
    sRed: _c(0xffe5484d),
    sYellow: _c(0xfff0bf26),
    sGreen: _c(0xff3fae4c),
    sNone: _c(0xffcfd3da),
    good: _c(0xff1d7a4d),
    bad: _c(0xffc2412d),
    gold: _c(0xff9a6a12),
    elWood: _c(0xff2f9a55),
    elFire: _c(0xffd4483a),
    elEarth: _c(0xffa87a1c),
    elMetal: _c(0xff7c8799),
    elWater: _c(0xff2a74c4),
    gFillTop: .62,
    gFillA: .34,
    gFillB: .10,
    gFillC: .18,
    gSolidTop: .5,
    gSolid: .46,
    gHead: const Color.fromRGBO(246, 247, 249, .60),
    gBar: _w(.58),
    gEdge: _w(.45),
    f0: .66,
    f1: .36,
    r0: .98,
    r1: .22,
    r2: .75,
    card: .88,
    warm: const Color.fromRGBO(255, 190, 140, .42),
    drop: const [
      BoxShadow(color: Color.fromRGBO(25, 35, 60, .45), offset: Offset(0, 20), blurRadius: 40, spreadRadius: -24),
      BoxShadow(color: Color.fromRGBO(25, 35, 60, .14), offset: Offset(0, 3), blurRadius: 8, spreadRadius: -4),
    ],
    insetTop: .95,
  );

  static final darkP = Pal(
    brightness: Brightness.dark,
    bg: _c(0xff23262c),
    surface: _c(0xff2a2d34),
    sunk: _c(0xff353840),
    line: _c(0xff3a3e46),
    fg: _c(0xffeceef2),
    soft: _c(0xffc0c5ce),
    mute: _c(0xffa3a9b3),
    mark: _c(0xff5a4515),
    onAcc: _c(0xff0f1218),
    bgTop: _c(0xff2f3238),
    bgBot: _c(0xff15171b),
    glowO: .46,
    lv: [
      _c(0xff6fd08f), _c(0xff5cc8cf), _c(0xff6dbbea), _c(0xff94a3f5), _c(0xffbf9af0), _c(0xffec8dbd), //
      _c(0xffe8bd57), _c(0xffff8f78), _c(0xffa7b4dc),
    ],
    tone: [_c(0xffff7a66), _c(0xfff2a64a), _c(0xff5fd38f), _c(0xff79a6ff), _c(0xff9aa39e)],
    sRed: _c(0xffff6b6b),
    sYellow: _c(0xfff5d04a),
    sGreen: _c(0xff62d26f),
    sNone: _c(0xff454952),
    good: _c(0xff5fd38f),
    bad: _c(0xffff7a66),
    gold: _c(0xffebc277),
    elWood: _c(0xff62c983),
    elFire: _c(0xffff7a66),
    elEarth: _c(0xffe2b75a),
    elMetal: _c(0xffc3cad6),
    elWater: _c(0xff6aa8f0),
    gFillTop: .17,
    gFillA: .10,
    gFillB: .03,
    gFillC: .05,
    gSolidTop: .10,
    gSolid: .05,
    gHead: const Color.fromRGBO(40, 43, 50, .62),
    gBar: const Color.fromRGBO(52, 55, 63, .56),
    gEdge: _w(.07),
    f0: .115,
    f1: .045,
    r0: .4,
    r1: .05,
    r2: .2,
    card: .075,
    warm: _c(0xffebc277).withValues(alpha: .16),
    drop: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .85), offset: Offset(0, 22), blurRadius: 40, spreadRadius: -22)],
    insetTop: .18,
  );

  static final blackP = Pal(
    brightness: Brightness.dark,
    black: true,
    bg: _c(0xff000000),
    surface: _c(0xff0b0b0c),
    sunk: _c(0xff1a1a1d),
    line: _c(0xff26262a),
    fg: _c(0xfff4f4f6),
    soft: _c(0xffb4b4bb),
    mute: _c(0xff8d8d94),
    mark: _c(0xff4a3a10),
    onAcc: _c(0xff000000),
    bgTop: _c(0xff000000),
    bgBot: _c(0xff000000),
    glowO: .34,
    lv: darkP.lv,
    tone: darkP.tone,
    sRed: darkP.sRed,
    sYellow: darkP.sYellow,
    sGreen: darkP.sGreen,
    sNone: _c(0xff2b2b2f),
    good: darkP.good,
    bad: darkP.bad,
    gold: _c(0xffebc277),
    elWood: darkP.elWood,
    elFire: darkP.elFire,
    elEarth: darkP.elEarth,
    elMetal: darkP.elMetal,
    elWater: darkP.elWater,
    gFillTop: .14,
    gFillA: .08,
    gFillB: .02,
    gFillC: .04,
    gSolidTop: .08,
    gSolid: .04,
    gHead: const Color.fromRGBO(0, 0, 0, .6),
    gBar: const Color.fromRGBO(30, 30, 33, .62),
    gEdge: _w(.06),
    f0: .09,
    f1: .03,
    r0: .34,
    r1: .04,
    r2: .16,
    card: .06,
    warm: _c(0xffebc277).withValues(alpha: .10),
    drop: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .95), offset: Offset(0, 20), blurRadius: 36, spreadRadius: -22)],
    insetTop: .14,
  );
}

/// Fonts bundled in assets/fonts (tool/make_fonts.py): Plus Jakarta Sans for the interface (Thai and Chinese fall
/// back to Noto Sans Thai / Noto Sans SC), Noto Serif SC for big hanzi.
class F {
  static const ui = 'Jakarta';
  static const fallback = ['NotoSansThai', 'NotoSansSC'];
  static const zh = 'NotoSansSC';
  static const hz = 'NotoSerifSC';

  static TextStyle s(
    double size, {
    FontWeight w = FontWeight.w400,
    Color? c,
    double? h,
    double? ls,
    String family = ui,
    FontStyle? style,
    List<FontFeature>? feat,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: family == ui ? fallback : const ['NotoSansSC', 'Jakarta'],
    fontSize: size,
    fontWeight: w,
    color: c,
    height: h,
    letterSpacing: ls,
    fontStyle: style,
    fontFeatures: feat,
  );

  static const tab = [FontFeature.tabularFigures()];
}
