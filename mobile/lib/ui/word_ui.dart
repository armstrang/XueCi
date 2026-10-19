/// How a word is shown (list, card back, quiz feedback): hanzi in tone colours, pinyin, meaning, the example
/// sentence with the word marked, its pinyin, its translation; speaker buttons.
library;


import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/mastery.dart';
import '../app/native.dart';
import '../data/words.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// speak a word or sentence (Android TextToSpeech, zh-CN); a missing voice opens the phone's speech settings
Future<void> speak(String text) async {
  final st = await Native.I.ttsStatus();
  if (st == 'missing' || st == 'unsupported') {
    app.toast(app.t.ttsMissing);
    Future.delayed(const Duration(milliseconds: 1200), Native.I.openTtsSettings);
    return;
  }
  if (st == 'none') {
    app.toast(app.t.ttsNone);
    return;
  }
  await Native.I.speak(text);
}

/// a round speaker button (sm 26, normal 32, lg 46, xl 76)
class Spk extends StatelessWidget {
  final String text;
  final double size;
  final VoidCallback? onSpoken;
  const Spk(this.text, {super.key, this.size = 32, this.onSpoken});
  @override
  Widget build(BuildContext context) {
    if (!app.canSpeak()) return const SizedBox.shrink();
    final th = Th.of(context);
    return Press(
      onTap: () {
        onSpoken?.call();
        speak(text);
      },
      scale: .9,
      label: app.t.listen,
      child: SizedBox(
        width: size < 32 ? 34 : size,
        height: size < 32 ? 34 : size,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .13)),
            child: Center(child: Icon2(I.speaker, size: size * .48, color: th.acc)),
          ),
        ),
      ),
    );
  }
}

/// the meaning: the first sense bold, the others after a dot
class MeanText extends StatelessWidget {
  final String m;
  final double size;
  const MeanText(this.m, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final parts = m.split(';').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: parts[0], style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final x in parts.skip(1)) TextSpan(text: ' · $x', style: TextStyle(color: p.soft)),
        ],
      ),
      style: F.s(size, c: p.fg, h: 1.4),
    );
  }
}

/// the example sentence with the learned word marked (or as a gap, or with other text in its place: [fill])
class ExampleText extends StatelessWidget {
  final Word d;
  final double size;
  final bool gap;
  final String? fill;
  final bool plainFill;
  const ExampleText(this.d, {super.key, this.size = 15, this.gap = false, this.fill, this.plainFill = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final z = d.z, w = d.h;
    final i = z.indexOf(w);
    final st = F.s(size, c: p.fg, h: 1.6, family: F.zh);
    if (i < 0) return Text(z, style: st, locale: const Locale('zh', 'CN'));
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: z.substring(0, i)),
          fill != null
              ? TextSpan(text: fill, style: plainFill ? null : TextStyle(color: th.acc, fontWeight: FontWeight.w700))
              : gap
              ? TextSpan(text: '＿＿', style: TextStyle(color: th.acc, fontWeight: FontWeight.w700))
              : TextSpan(text: w, style: TextStyle(fontWeight: FontWeight.w700, backgroundColor: p.mark)),
          TextSpan(text: z.substring(i + w.length)),
        ],
      ),
      style: st,
      locale: const Locale('zh', 'CN'),
    );
  }
}

/// the sentence's pinyin (zp), the learned word {in braces} in the level's colour (or as a gap, or [fill] instead)
class ZpText extends StatelessWidget {
  final Word d;
  final bool gap;
  final bool plainWord;
  final String? fill;
  const ZpText(this.d, {super.key, this.gap = false, this.plainWord = false, this.fill});
  @override
  Widget build(BuildContext context) {
    final zp = d.zp;
    if (zp == null || zp.isEmpty) return const SizedBox.shrink();
    final th = Th.of(context);
    final p = th.p;
    final m = RegExp(r'\{([^}]*)\}').firstMatch(zp);
    final st = F.s(12.5, c: p.soft, h: 1.45);
    if (m != null && fill != null) return Text(zp.substring(0, m.start) + fill! + zp.substring(m.end), style: st);
    if (m == null || plainWord) return Text(zp.replaceAll(RegExp('[{}]'), ''), style: st);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: zp.substring(0, m.start)),
          TextSpan(
            text: gap ? '＿＿' : m.group(1),
            style: TextStyle(color: Pal.mix(th.acc, .82, p.fg), fontWeight: FontWeight.w700),
          ),
          TextSpan(text: zp.substring(m.end)),
        ],
      ),
      style: st,
    );
  }
}

/// a word's mastery: dot + "Level 7/20 · 10 right, 2 wrong"
class LevelLine extends StatelessWidget {
  final Word d;
  const LevelLine(this.d, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final s = app.lvl(d);
    final e = app.lm.stats[d.id];
    final txt = s < 0 ? L10.text(app.t.band['none']) : app.t.stTxt(s, e![0], e[1]);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Dot(levelColor(p, s)),
        const SizedBox(width: 6),
        Flexible(child: Text(txt, style: F.s(12.5, c: p.soft))),
      ],
    );
  }
}

/// the head of a word: hanzi, pinyin, speaker
class WordHead extends StatelessWidget {
  final Word d;
  final double hz;
  const WordHead(this.d, {super.key, this.hz = 26});
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 10,
    runSpacing: 2,
    children: [
      Hz(d, size: hz, weight: FontWeight.w900, family: F.hz),
      Py(d, size: 14, weight: FontWeight.w700),
      Spk(d.h),
    ],
  );
}

/// everything about a word below its head: meaning, the sentence, its pinyin and translation
class WordBody extends StatelessWidget {
  final Word d;
  final double mean;
  final bool hide;
  const WordBody(this.d, {super.key, this.mean = 14, this.hide = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final blur = hide;
    Widget veil(Widget w) => blur ? _Veil(child: w) : w;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        veil(MeanText(app.m(d), size: mean)),
        if (d.z.isNotEmpty) ...[
          const SizedBox(height: 7),
          Container(height: 1, color: p.line),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: ExampleText(d)),
              Spk(d.z, size: 26),
            ],
          ),
          ZpText(d),
          veil(
            Text(
              app.tr(d),
              style: F.s(12.5, c: p.soft, style: app.lang == 'th' ? FontStyle.normal : FontStyle.italic, h: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}

/// hidden meanings (List › hide): blurred until tapped
class _Veil extends StatefulWidget {
  final Widget child;
  const _Veil({required this.child});
  @override
  State<_Veil> createState() => _VeilState();
}

class _VeilState extends State<_Veil> {
  bool open = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => open = !open),
    // a hidden meaning is a soft bar of its own size (no blur: a list of blurred rows would cost every frame)
    child: open
        ? widget.child
        : Semantics(
            hidden: true,
            child: Stack(
              children: [
                Opacity(opacity: 0, child: widget.child),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Th.pal(context).fgA(.10), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

/// a word as a card in the list
class WordCard extends StatelessWidget {
  final Word d;
  final bool showLevel;
  final bool hide;
  const WordCard(this.d, {super.key, this.showLevel = false, this.hide = false});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final s = app.lvl(d);
    return Glass(
      solid: true,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: WordHead(d)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showLevel) ...[LvChip(d.l), const SizedBox(width: 6)],
                    Semantics(label: s < 0 ? L10.text(app.t.band['none']) : app.t.stTxt(s, app.lm.stats[d.id]![0], app.lm.stats[d.id]![1]), child: Dot(levelColor(p, s))),
                    const SizedBox(width: 6),
                    Text(d.n.toString().padLeft(4, '0'), style: F.s(11.5, c: p.mute, feat: F.tab)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          WordBody(d, hide: hide),
        ],
      ),
    );
  }
}

/// "HSK 3" in the level's colour
class LvChip extends StatelessWidget {
  final int l;
  const LvChip(this.l, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: p.l(l), borderRadius: BorderRadius.circular(999)),
      child: Text('HSK $l', style: F.s(10.5, w: FontWeight.w800, c: p.onAcc)),
    );
  }
}
