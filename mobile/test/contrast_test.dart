// Readability: every piece of text on every main screen and sheet, in the light, dark and true-black themes, must
// stand out from what is really behind it (WCAG: 4.5:1 for normal text, 3:1 for large text). The screen is rendered,
// and for each text the background is measured from the pixels around the letters.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueci/app/app.dart';
import 'package:xueci/ui/backup_sheet.dart';
import 'package:xueci/ui/glass.dart';
import 'package:xueci/ui/shell.dart';

import 'screens_test.dart' show bootApp, loadFonts, sample;

double _lin(double c) => c <= .04045 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();
double lum(double r, double g, double b) => .2126 * _lin(r) + .7152 * _lin(g) + .0722 * _lin(b);
double ratio(double a, double b) => (math.max(a, b) + .05) / (math.min(a, b) + .05);

class Finding {
  final String text, where;
  final double ratio, need, size;
  Finding(this.text, this.where, this.ratio, this.need, this.size);
  @override
  String toString() => '$where: "${text.length > 40 ? '${text.substring(0, 40)}…' : text}" ${ratio.toStringAsFixed(2)} < $need (${size.toStringAsFixed(0)}px)';
}

/// the colour a span is drawn in (the longest piece of text decides)
Color? textColor(InlineSpan span, Color? inherited) {
  Color? best;
  var bestLen = -1;
  void walk(InlineSpan s, Color? c) {
    final col = s.style?.color ?? c;
    if (s is TextSpan) {
      final t = s.text ?? '';
      if (t.trim().isNotEmpty && t.length > bestLen && col != null) {
        best = col;
        bestLen = t.length;
      }
      for (final ch in s.children ?? const <InlineSpan>[]) {
        walk(ch, col);
      }
    }
  }

  walk(span, inherited);
  return best;
}

double fontSize(InlineSpan s) => s.style?.fontSize ?? ((s is TextSpan && (s.children?.isNotEmpty ?? false)) ? fontSize(s.children!.first) : 14);
bool bold(InlineSpan s) => (s.style?.fontWeight?.value ?? 400) >= 700;

bool hidden(RenderObject r) {
  RenderObject? o = r;
  while (o != null) {
    if (o is RenderOpacity && o.opacity < .99) return true;
    if (o is RenderAnimatedOpacity && o.opacity.value < .99) return true;
    if (o is RenderExcludeSemantics && o.excluding) return false;
    o = o.parent;
  }
  return false;
}

Future<List<Finding>> check(WidgetTester t, GlobalKey key, String where) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await t.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final data = (await t.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  if (Platform.environment['CDUMP'] != null) {
    final png = (await t.runAsync(() => img.toByteData(format: ui.ImageByteFormat.png)))!;
    Directory('test/cdump').createSync(recursive: true);
    File('test/cdump/${where.replaceAll('/', '-')}.png').writeAsBytesSync(png.buffer.asUint8List());
  }
  final px = data.buffer.asUint8List();
  final w = img.width, h = img.height;
  final out = <Finding>[];
  void visit(RenderObject r) {
    if (r is RenderParagraph) {
      final txt = r.text.toPlainText().trim();
      final col = textColor(r.text, null);
      if (txt.isNotEmpty && col != null && col.a > .05 && !hidden(r)) {
        final tl = r.localToGlobal(Offset.zero, ancestor: boundary);
        final rect = (tl & r.size).intersect(Offset.zero & Size(w.toDouble(), h.toDouble()));
        if (rect.width >= 4 && rect.height >= 4) {
          final ls = <double>[];
          for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
            for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
              final i = (y * w + x) * 4;
              ls.add(lum(px[i] / 255, px[i + 1] / 255, px[i + 2] / 255));
            }
          }
          if (ls.length > 20) {
            // the background: the half of the pixels farthest from the letters' colour
            final bgGuess = ls.toList()..sort();
            final lo = bgGuess[bgGuess.length ~/ 10], hi = bgGuess[bgGuess.length * 9 ~/ 10];
            final lt0 = lum(col.r, col.g, col.b);
            final bg = (lt0 - lo).abs() > (lt0 - hi).abs() ? lo : hi;
            // a see-through text colour shows the background through it
            final lt = col.a >= .99 ? lt0 : lt0 * col.a + bg * (1 - col.a);
            final fs = fontSize(r.text) * (r.textScaler.scale(1));
            final large = fs >= 24 || (fs >= 18.5 && bold(r.text));
            final need = large ? 3.0 : 4.5;
            final cr = ratio(lt, bg);
            if (cr < need) out.add(Finding(txt, where, cr, need, fs));
          }
        }
      }
    }
    r.visitChildren(visit);
  }

  boundary.visitChildren(visit);
  img.dispose();
  return out;
}

void main() {
  setUpAll(() async {
    noBlur = true;
    await loadFonts();
  });

  final all = <Finding>[];
  tearDownAll(() {
    // ignore: avoid_print
    print('CONTRAST ${all.length} findings\n${all.join('\n')}');
  });

  for (final theme in ['light', 'dark', 'black']) {
    for (final (name, go) in <(String, void Function())>[
      ('home', () => app.go('home')),
      ('home-new', () => app.go('home')),
      ('list', () => app.go('list')),
      ('quiz', () => app.go('quiz')),
      ('card', () => app.go('card')),
      ('stats', () => app.go('stats')),
      ('soul', () => app.go('soul')),
      ('settings', () {}),
      ('realm', () {}),
      ('goal', () {}),
      ('info', () {}),
      ('streak', () {}),
      ('backup', () {}),
      ('placement', () => app.go('placement')),
      ('bt', () => app.go('bt')),
    ]) {
      testWidgets('contrast $theme $name', (t) async {
        final saved = name == 'home-new' || name == 'placement' ? <String, String>{'xc_onb': '1'} : {...sample(strong: name == 'bt'), 'xc_onb': '1'};
        saved['hsk16_theme'] = '"$theme"';
        await t.runAsync(() => bootApp(saved));
        t.view.physicalSize = Size(412, name == 'soul' || name == 'stats' || name == 'info' ? 2400 : 892);
        t.view.devicePixelRatio = 1;
        go();
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(key: key, child: const XueCiApp()));
        await t.pump(const Duration(milliseconds: 700));
        final c = navKey.currentContext!;
        if (name == 'settings') app.openSettings!(c);
        if (name == 'realm') app.openRealm!(c);
        if (name == 'goal') app.openGoal!(c, false);
        if (name == 'info') app.openInfo!(c, 'realm');
        if (name == 'streak') app.openStreak!(c);
        if (name == 'backup') openBackup(c);
        await t.pump(const Duration(milliseconds: 700));
        final f = await check(t, key, '$theme/$name');
        all.addAll(f);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 8));
        expect(f, isEmpty, reason: f.join('\n'));
      });
    }
  }
}

