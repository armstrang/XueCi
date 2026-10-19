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
  final Color cardC; // the content cards' colour (One UI): the glass fills are this colour at gFill* / gSolid
  final List<BoxShadow> drop;
  final double insetTop; // the bright line inside the top edge
  // the glass material (Galaxy-style milky glass + Liquid Glass rims): panels on the background, elements inside a
  // panel, floating frosted layers; each with a soft white glow inside its edge and a bright rim
  final Color glassA, glassB; // panel fill, top-left → bottom-right
  final Color innerA, innerB; // an element inside a panel
  final Color frostC; // floating layers (over a real blur)
  final double glowIn; // the white glow inside the edge
  final double rimHi, rimLo; // the rim's bright corners and its quiet middle
  final double sheen; // the light from the top left
  // the aurora behind everything: the realm/level tone, a warm and a cool light
  final double auroraTone;
  final Color auroraWarm, auroraCool;
  final List<BoxShadow> dropIn; // the small shadow of an element inside a panel

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
    required this.cardC,
    required this.drop,
    required this.insetTop,
    required this.glassA,
    required this.glassB,
    required this.innerA,
    required this.innerB,
    required this.frostC,
    required this.glowIn,
    required this.rimHi,
    required this.rimLo,
    required this.sheen,
    required this.auroraTone,
    required this.auroraWarm,
    required this.auroraCool,
    required this.dropIn,
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

  /// text on a coloured fill: near-black or white, whichever reads better
  static Color on(Color bg) {
    final l = bg.computeLuminance();
    return (l + .05) / .05 >= 1.05 / (l + .05) ? const Color(0xff0f1218) : Colors.white;
  }

  static final lightP = Pal(
    brightness: Brightness.light,
    bg: _c(0xffeceef1),
    surface: _c(0xfff6f7f9),
    sunk: _c(0xffe0e3e8),
    line: _c(0xffd6dae0),
    fg: _c(0xff161a22),
    soft: _c(0xff464e5d),
    mute: _c(0xff515866),
    mark: _c(0xffffe1a8),
    onAcc: _c(0xffffffff),
    bgTop: _c(0xfff6eee7),
    bgBot: _c(0xffe8e4f3),
    glowO: .30,
    lv: [
      _c(0xff297742), _c(0xff0e747d), _c(0xff1c6ea5), _c(0xff3c4fb8), _c(0xff7a46b8), _c(0xffa3386f), //
      _c(0xff8c600c), _c(0xffb23a2a), _c(0xff3d4766),
    ],
    tone: [_c(0xffb53127), _c(0xff945206), _c(0xff1a7045), _c(0xff295fbb), _c(0xff5e6461)],
    sRed: _c(0xffe5484d),
    sYellow: _c(0xfff0bf26),
    sGreen: _c(0xff3fae4c),
    sNone: _c(0xffcfd3da),
    good: _c(0xff1d784c),
    bad: _c(0xffba3e2b),
    gold: _c(0xff8c6110),
    elWood: _c(0xff226f3e),
    elFire: _c(0xffb33427),
    elEarth: _c(0xff7e5c16),
    elMetal: _c(0xff596372),
    elWater: _c(0xff2464a9),
    gFillTop: .55,
    gFillA: .86,
    gFillB: .76,
    gFillC: .80,
    gSolidTop: .5,
    gSolid: .84,
    gHead: const Color.fromRGBO(248, 249, 251, .74),
    gBar: _w(.58),
    gEdge: _w(.45),
    f0: .90,
    f1: .80,
    r0: .98,
    r1: .22,
    r2: .75,
    card: .96,
    warm: const Color.fromRGBO(255, 190, 140, .26),
    cardC: const Color(0xffffffff),
    drop: const [
      BoxShadow(color: Color.fromRGBO(60, 40, 90, .20), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -14),
      BoxShadow(color: Color.fromRGBO(60, 40, 90, .06), offset: Offset(0, 2), blurRadius: 6, spreadRadius: -2),
    ],
    insetTop: .95,
    glassA: _w(.50),
    glassB: _w(.30),
    innerA: _w(.74),
    innerB: _w(.52),
    frostC: _w(.46),
    glowIn: 1,
    rimHi: 1,
    rimLo: .3,
    sheen: .6,
    auroraTone: .55,
    auroraWarm: const Color.fromRGBO(255, 138, 88, .58),
    auroraCool: const Color.fromRGBO(128, 136, 255, .46),
    dropIn: const [BoxShadow(color: Color.fromRGBO(60, 40, 90, .10), offset: Offset(0, 6), blurRadius: 16, spreadRadius: -6)],
  );

  static final darkP = Pal(
    brightness: Brightness.dark,
    bg: _c(0xff23262c),
    surface: _c(0xff2a2d34),
    sunk: _c(0xff353840),
    line: _c(0xff3a3e46),
    fg: _c(0xffeceef2),
    soft: _c(0xffd6dae0),
    mute: _c(0xffc6cad2),
    mark: _c(0xff5a4515),
    onAcc: _c(0xff0f1218),
    bgTop: _c(0xff171a22),
    bgBot: _c(0xff08090d),
    glowO: .32,
    lv: [
      _c(0xff85d7a0), _c(0xff74d0d6), _c(0xff83c5ed), _c(0xffa4b1f6), _c(0xffc9a9f2), _c(0xffef9ec7), //
      _c(0xffebc770), _c(0xffffa08c), _c(0xffb4bfe1),
    ],
    tone: [_c(0xffff7a66), _c(0xfff2a64a), _c(0xff5fd38f), _c(0xff86aeff), _c(0xffb7bfba)],
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
    gFillTop: .10,
    gFillA: .86,
    gFillB: .80,
    gFillC: .84,
    gSolidTop: .08,
    gSolid: .88,
    gHead: const Color.fromRGBO(38, 41, 48, .76),
    gBar: const Color.fromRGBO(52, 55, 63, .56),
    gEdge: _w(.07),
    f0: .88,
    f1: .82,
    r0: .4,
    r1: .05,
    r2: .2,
    card: .06,
    warm: _c(0xffebc277).withValues(alpha: .12),
    cardC: const Color(0xff2a2d35),
    drop: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .55), offset: Offset(0, 20), blurRadius: 44, spreadRadius: -16)],
    insetTop: .18,
    glassA: _w(.065),
    glassB: _w(.03),
    innerA: _w(.035),
    innerB: _w(.01),
    frostC: const Color.fromRGBO(24, 26, 34, .58),
    glowIn: .09,
    rimHi: .5,
    rimLo: 0,
    sheen: .06,
    auroraTone: .34,
    auroraWarm: const Color.fromRGBO(255, 112, 50, .18),
    auroraCool: const Color.fromRGBO(110, 90, 255, .32),
    dropIn: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .35), offset: Offset(0, 6), blurRadius: 16, spreadRadius: -8)],
  );

  static final blackP = Pal(
    brightness: Brightness.dark,
    black: true,
    bg: _c(0xff000000),
    surface: _c(0xff0b0b0c),
    sunk: _c(0xff1a1a1d),
    line: _c(0xff26262a),
    fg: _c(0xfff4f4f6),
    soft: _c(0xffc4c4cb),
    mute: _c(0xffa0a0a7),
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
    gFillTop: .08,
    gFillA: .92,
    gFillB: .88,
    gFillC: .90,
    gSolidTop: .06,
    gSolid: .92,
    gHead: const Color.fromRGBO(0, 0, 0, .6),
    gBar: const Color.fromRGBO(30, 30, 33, .62),
    gEdge: _w(.06),
    f0: .94,
    f1: .90,
    r0: .34,
    r1: .04,
    r2: .16,
    card: .06,
    warm: _c(0xffebc277).withValues(alpha: .10),
    cardC: const Color(0xff141417),
    drop: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .9), offset: Offset(0, 20), blurRadius: 40, spreadRadius: -18)],
    insetTop: .14,
    glassA: _w(.085),
    glassB: _w(.035),
    innerA: _w(.05),
    innerB: _w(.015),
    frostC: const Color.fromRGBO(8, 8, 10, .62),
    glowIn: .09,
    rimHi: .45,
    rimLo: 0,
    sheen: .09,
    auroraTone: .22,
    auroraWarm: const Color.fromRGBO(255, 120, 60, .12),
    auroraCool: const Color.fromRGBO(110, 95, 255, .16),
    dropIn: const [],
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
