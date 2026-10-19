/// Small shared pieces: buttons, chips, hanzi in tone colours, text with <b>, the grade badge.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../data/pinyin.dart';
import '../data/words.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';

/// text with `<b>` from the interface texts
class Rich extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign align;
  final int? maxLines;
  final Color? boldColor;
  const Rich(this.text, {super.key, required this.style, this.align = TextAlign.start, this.maxLines, this.boldColor});
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: style,
      children: richSpans(text, bold: TextStyle(fontWeight: FontWeight.w800, color: boldColor)),
    ),
    textAlign: align,
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : null,
    semanticsLabel: plainText(text),
  );
}

/// the hanzi of a word, each character in its tone's colour (when the pinyin has one syllable per character)
class Hz extends StatelessWidget {
  final Word d;
  final double size;
  final FontWeight weight;
  final String family;
  final bool tones;
  const Hz(this.d, {super.key, this.size = 28, this.weight = FontWeight.w700, this.family = F.zh, this.tones = true});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final ch = d.h.runes.map(String.fromCharCode).toList();
    final style = F.s(size, w: weight, family: family, h: 1.15, c: p.fg);
    if (!tones || ch.length != d.s.length) return Text(d.h, style: style, locale: const Locale('zh', 'CN'));
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < ch.length; i++)
            TextSpan(text: ch[i], style: style.copyWith(color: p.t(tone(d.s[i])))),
        ],
      ),
      locale: const Locale('zh', 'CN'),
      semanticsLabel: d.h,
    );
  }
}

/// pinyin of a word, syllables in tone colours
class Py extends StatelessWidget {
  final Word d;
  final double size;
  final FontWeight weight;
  const Py(this.d, {super.key, this.size = 15, this.weight = FontWeight.w600});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final st = F.s(size, w: weight, c: p.fg);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < d.s.length; i++) ...[
            if (i > 0 && RegExp(r'^[aeoāáǎàēéěèōóǒò]').hasMatch(d.s[i])) TextSpan(text: "'", style: st),
            TextSpan(text: d.s[i], style: st.copyWith(color: p.t(tone(d.s[i])))),
          ],
        ],
      ),
      semanticsLabel: d.p,
    );
  }
}

/// the main button (planbtn / next): solid in the level's colour
class MainBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Ic? icon;
  final Widget? lead;
  final bool wide;
  final Color? color;
  final double radius;
  final EdgeInsets padding;
  final double fontSize;
  final String? semantics;
  const MainBtn(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.lead,
    this.wide = false,
    this.color,
    this.radius = 20,
    this.padding = const EdgeInsets.fromLTRB(15, 12, 18, 12),
    this.fontSize = 15,
    this.semantics,
  });
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final c = color ?? th.acc;
    final on = onTap != null;
    final fg = th.p.onAcc;
    return Opacity(
      opacity: on ? 1 : .45,
      child: Press(
        onTap: onTap,
        scale: .97,
        label: semantics ?? label,
        child: Container(
          width: wide ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, .22)!, c, Color.lerp(c, Colors.black, .06)!],
              stops: const [0, .55, 1],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: th.p.dark ? .28 : .45), width: 1),
            boxShadow: sh(th.low ? null : [BoxShadow(color: c.withValues(alpha: .5), offset: const Offset(0, 10), blurRadius: 24, spreadRadius: -8)]),
          ),
          child: Row(
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon2(icon!, size: 15, color: fg), const SizedBox(width: 7)],
              ?lead,
              Flexible(
                child: Text(
                  label,
                  style: F.s(fontSize, w: FontWeight.w800, c: fg),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// the quiet button (ghost): glass with a label
class GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool wide;
  final bool pri;
  final Widget? lead;
  final double fontSize;
  final EdgeInsets padding;
  const GhostBtn(
    this.label, {
    super.key,
    this.onTap,
    this.wide = false,
    this.pri = false,
    this.lead,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final on = onTap != null;
    final child = Row(
      mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (lead != null) ...[lead!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: F.s(fontSize, w: FontWeight.w800, c: pri ? th.p.onAcc : th.p.fg),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: on ? 1 : .45,
      child: Press(
        onTap: onTap,
        scale: wide ? .98 : 1.04,
        label: label,
        child: pri
            ? Container(
                width: wide ? double.infinity : null,
                padding: padding,
                decoration: BoxDecoration(color: th.acc, borderRadius: BorderRadius.circular(16)),
                child: child,
              )
            : Glass(radius: wide ? 16 : 999, padding: padding, width: wide ? double.infinity : null, child: child),
      ),
    );
  }
}

/// a small glass chip (goal chip, trial chip)
class GChip extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final double height;
  const GChip({super.key, required this.child, this.onTap, this.label, this.height = 32});
  @override
  Widget build(BuildContext context) => Press(
    onTap: onTap,
    scale: 1.05,
    label: label,
        child: Builder(
      builder: (c) {
        final th = Th.of(c);
        return Glass(
          inner: true,
          radius: 999,
          height: height,
          color: th.acc.withValues(alpha: th.p.dark ? .07 : .06),
          shadow: const [],
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(widthFactor: 1, child: child),
        );
      },
    ),
  );
}

/// foundation quality badge (道基): 下品 中品 上品 完美
class GradeBadge extends StatelessWidget {
  final int g;
  final bool small;
  const GradeBadge(this.g, {super.key, this.small = true});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final gc = switch (g) {
      2 => p.l(3),
      3 => p.l(5),
      4 => p.gold,
      _ => p.mute,
    };
    final name = LMNames.grades[g];
    return Container(
      padding: small ? const EdgeInsets.symmetric(horizontal: 8, vertical: 1) : const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: gc.withValues(alpha: .10),
        border: Border.all(color: gc, width: small ? 1 : 1.5),
        borderRadius: BorderRadius.circular(small ? 999 : 16),
        boxShadow: sh(g == 4 ? [BoxShadow(color: p.gold.withValues(alpha: .18), spreadRadius: 3)] : null),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: F.s(small ? 13 : 24, w: FontWeight.w900, family: F.hz, c: gc, ls: small ? 0 : 1)),
          if (!small) Text(L10.text(app.t.gradeM[g]), style: F.s(11.5, c: p.soft)),
        ],
      ),
    );
  }
}

class LMNames {
  static const grades = ['', '下品', '中品', '上品', '完美'];
}

/// a section title in the sheets: 指点 zhǐdiǎn · Guidance
class Shd extends StatelessWidget {
  final String hz, py, t;
  final double top;
  const Shd(this.hz, this.py, this.t, {super.key, this.top = 14});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: hz, style: F.s(16, w: FontWeight.w900, family: F.hz, c: p.fg)),
            TextSpan(text: '  $py', style: F.s(12, c: p.soft)),
            TextSpan(text: '  ·  ', style: F.s(13, c: p.mute)),
            TextSpan(text: t, style: F.s(15, w: FontWeight.w800, c: p.fg)),
          ],
        ),
      ),
    );
  }
}

/// a progress bar of segments (mastery bands)
class StackBar extends StatelessWidget {
  final List<(double, Color)> parts; // share 0–1, colour
  final double height;
  final double gap;
  final Color? track;
  const StackBar(this.parts, {super.key, this.height = 8, this.gap = 2, this.track});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track ?? p.fgA(.09),
        // the bar grows in when it first appears
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (c, k, _) => LayoutBuilder(
            builder: (c, bc) => Row(
              children: [
                for (final (s, col) in parts)
                  if (s > 0)
                    Container(
                      width: (bc.maxWidth * s * k - gap).clamp(0, bc.maxWidth),
                      margin: EdgeInsets.only(right: gap),
                      color: col,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// a labelled bar: label · bar · value
class SkRow extends StatelessWidget {
  final Widget label;
  final double frac;
  final Color color;
  final String value;
  final double valueW;
  final Color? valueColor;
  const SkRow({super.key, required this.label, required this.frac, required this.color, required this.value, this.valueW = 44, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Row(
      children: [
        label,
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 7,
              color: p.sunk,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(widthFactor: frac.clamp(0, 1).toDouble(), heightFactor: 1, child: ColoredBox(color: color)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: valueW,
          child: Text(value, textAlign: TextAlign.right, maxLines: 1, style: F.s(12.5, w: FontWeight.w700, c: valueColor ?? p.fg, feat: F.tab)),
        ),
      ],
    );
  }
}

/// a small tile of inner glass (numbers, notes), with a margin like a Container
class Tile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin, padding;
  final double radius;
  const Tile({super.key, required this.child, this.margin, this.padding, this.radius = 14});
  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.zero,
    child: Glass(inner: true, solid: true, radius: radius, padding: padding, shadow: const [], child: child),
  );
}
