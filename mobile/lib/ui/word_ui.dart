/// How a word is shown (list, card back, quiz feedback): hanzi in tone colours, pinyin, meaning, the example
/// sentence with the word marked, its pinyin, its translation; speaker buttons.
library;

import 'dart:math' as math;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/mastery.dart';
import '../app/native.dart';
import '../app/speech.dart';
import '../data/words.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'sheet.dart';
import 'shell.dart' show navKey;
import 'theme.dart';
import 'widgets.dart';

/// speak a word or sentence (Android TextToSpeech, zh-CN); a missing voice opens the phone's speech settings
Future<void> speak(String text) async {
  final st = await Native.I.ttsStatus();
  if (st == 'missing' || st == 'unsupported') {
    final c = navKey.currentContext;
    if (c != null && c.mounted && st == 'missing') {
      openTtsGuide(c);
    } else {
      app.toast(app.t.ttsMissing);
      Future.delayed(const Duration(milliseconds: 1200), Native.I.openTtsSettings);
    }
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
              Mic(d, size: 26),
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

/// a round microphone button: opens the speaking sheet for the word's sentence (or the word)
class Mic extends StatelessWidget {
  final Word d;
  final double size;
  final bool sentence;
  const Mic(this.d, {super.key, this.size = 32, this.sentence = true});
  @override
  Widget build(BuildContext context) {
    if (!app.canListen) return const SizedBox.shrink();
    final th = Th.of(context);
    return Press(
      onTap: () => openSpeak(context, d, sentence: sentence),
      scale: .9,
      label: app.t.spkMic,
      child: SizedBox(
        width: size < 32 ? 34 : size,
        height: size < 32 ? 34 : size,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .13)),
            child: Center(child: Icon2(I.mic, size: size * .5, color: th.acc)),
          ),
        ),
      ),
    );
  }
}

/// hanzi coloured by what was said: green right, red (underlined) wrong; plain before any try. A tap on a hanzi
/// says it (the assist: hear the one you missed).
class SpokenText extends StatelessWidget {
  final String text;
  final List<bool>? ok;
  final double size;
  const SpokenText(this.text, this.ok, {super.key, this.size = 26});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final ch = text.runes.map(String.fromCharCode).toList();
    final base = F.s(size, w: FontWeight.w800, family: F.hz, c: p.fg, h: 1.3);
    final tap = app.canSpeak();
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < ch.length; i++)
              () {
                final mark = ok != null && isHan(ch[i]) && i < ok!.length;
                final t = Text(
                  ch[i],
                  locale: const Locale('zh', 'CN'),
                  style: !mark
                      ? base
                      : base.copyWith(
                          color: ok![i] ? p.good : p.bad,
                          decoration: ok![i] ? null : TextDecoration.underline,
                          decorationColor: p.bad,
                          decorationThickness: 2.4,
                        ),
                );
                return tap && isHan(ch[i]) ? GestureDetector(onTap: () => speak(ch[i]), child: t) : t;
              }(),
          ],
        ),
      ),
    );
  }
}

/// the big round microphone: tinted liquid glass. While the app listens it breathes with your voice ([level] 0–1),
/// rings of light go out from it and a thin arc counts down the 15 seconds; tapping it again stops. Only this
/// button redraws.
class BigMic extends StatefulWidget {
  final VoidCallback? onTap;
  final bool busy;
  final double level;
  const BigMic({super.key, this.onTap, this.busy = false, this.level = 0});
  @override
  State<BigMic> createState() => _BigMicState();
}

class _BigMicState extends State<BigMic> with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(seconds: 15));
  late final Listenable _both = Listenable.merge([_ring, _count]);
  bool _was = false;

  @override
  void didUpdateWidget(BigMic o) {
    super.didUpdateWidget(o);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.busy == _was) return;
    _was = widget.busy;
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.busy) {
      if (!reduce) _ring.repeat();
      _count.forward(from: 0);
    } else {
      _ring.stop();
      _ring.value = 0;
      _count.stop();
      _count.value = 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final c = th.acc;
    final busy = widget.busy;
    final btn = CustomPaint(
      painter: OuterShadow(
        th.low ? const [] : [BoxShadow(color: c.withValues(alpha: busy ? .6 : .45), offset: const Offset(0, 12), blurRadius: busy ? 34 : 28, spreadRadius: -10)],
        44,
      ),
      child: Glass(
        inner: true,
        radius: 44,
        width: 88,
        height: 88,
        shadow: const [],
        color: tintFill(th, busy ? Color.lerp(c, th.p.bad, .55)! : c),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
            child: busy
                // listening: a rounded square = stop
                ? Container(
                    key: const ValueKey('stop'),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: th.p.dark ? th.p.fg : th.p.onAcc, borderRadius: BorderRadius.circular(7)),
                  )
                : Icon2(I.mic, key: const ValueKey('mic'), size: 40, color: th.p.dark ? th.p.fg : th.p.onAcc, width: 2.2),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: busy ? app.t.spkStop : app.t.spkMic,
      child: Press(
        onTap: widget.onTap,
        scale: .92,
        child: SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (busy)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _both,
                      builder: (ctx, _) => CustomPaint(painter: _Rings(_ring.value, _count.value, c, th.p.fgA(.12))),
                    ),
                  ),
                ),
              // the button breathes with the voice: a quick ease towards the loudness
              TweenAnimationBuilder<double>(
                tween: Tween(end: busy ? 1.03 + .1 * widget.level.clamp(0, 1) : 1),
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
                child: btn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// rings of light going out from the microphone, and the arc of the 15 seconds
class _Rings extends CustomPainter {
  final double t, count;
  final Color c, track;
  _Rings(this.t, this.count, this.c, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final ctr = s.center(Offset.zero);
    for (final k in [t, (t + .5) % 1]) {
      final r = 44 + 20 * Curves.easeOut.transform(k);
      canvas.drawCircle(
        ctr,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - k) + .4
          ..color = c.withValues(alpha: .5 * (1 - k)),
      );
    }
    final rect = Rect.fromCircle(center: ctr, radius: 66);
    canvas.drawCircle(ctr, 66, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (1 - count),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = c,
    );
  }

  @override
  bool shouldRepaint(_Rings o) => o.t != t || o.count != count || o.c != c;
}

/// the score: a ring that fills to 0–100 with the number counting up; the colour and the word say the band
class ScoreRing extends StatelessWidget {
  final int score;
  const ScoreRing(this.score, {super.key});
  static int band(int s) => s <= 50 ? 0 : (s <= 75 ? 1 : (s < 100 ? 2 : 3));
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final b = band(score);
    final col = [p.bad, p.sYellow, p.good, p.gold][b];
    final words = app.t.spkBand;
    final word = words.length > b ? L10.text(words[b]) : '';
    return Semantics(
      label: '$score. $word',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              builder: (c, v, _) => SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: _ScorePainter(v, col, p.fgA(.12)),
                  child: Center(
                    child: Text('${(v * 100).round()}', style: F.s(30, w: FontWeight.w800, c: p.fg, feat: F.tab, h: 1)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(word, style: F.s(16, w: FontWeight.w800, c: b == 3 ? p.gold : p.fg)),
          ],
        ),
      ),
    );
  }
}

class _ScorePainter extends CustomPainter {
  final double v;
  final Color c, track;
  _ScorePainter(this.v, this.c, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2 - 4;
    final ctr = s.center(Offset.zero);
    canvas.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = track);
    if (v <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: ctr, radius: r),
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = c,
    );
  }

  @override
  bool shouldRepaint(_ScorePainter o) => o.v != v || o.c != c;
}

/// the score of a try: the share of the target's hanzi said right, 0–100
int speakScore(SpeakResult r, String target) => (r.share(target) * 100).round();

/// Speaking, shared by the quiz and the List's sheet: [top] shows the target (coloured once tried), then the
/// result (score, what you said, hear the right one), then the microphone: one tap starts, a second tap stops
/// (15 s at most). [onResult] gets every try with words in it.
class SpeakArea extends StatefulWidget {
  final String target;
  final Widget Function(BuildContext c, SpeakResult? res, bool busy, String heard) top;
  final void Function(SpeakResult r)? onResult;
  final Widget? after;
  const SpeakArea({super.key, required this.target, required this.top, this.onResult, this.after});
  @override
  State<SpeakArea> createState() => _SpeakAreaState();
}

class _SpeakAreaState extends State<SpeakArea> {
  SpeakResult? res;
  bool busy = false, nothing = false;
  final level = ValueNotifier<double>(0);
  String partial = '', err = '';

  @override
  void dispose() {
    level.dispose();
    if (busy) Native.I.listenStop();
    Native.I.listenEv = null;
    super.dispose();
  }

  Future<void> _tap() async {
    if (busy) {
      HapticFeedback.selectionClick();
      Native.I.listenStop();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      busy = true;
      nothing = false;
      partial = '';
      err = '';
    });
    level.value = 0;
    final r = await app.hear(widget.target, onEvent: (ev) {
      if (!mounted) return;
      switch (ev['t']) {
        case 'rms':
          level.value = (((ev['v'] as num).toDouble() + 2) / 12).clamp(0.0, 1.0); // only the button redraws
        case 'partial':
          setState(() => partial = '${ev['v']}');
        case 'err':
          err = '${ev['v']}';
      }
    });
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r == null) return;
      if (r.heard.isEmpty) {
        nothing = true;
        return;
      }
      res = r;
    });
    if (r != null && r.heard.isNotEmpty) {
      final sc = speakScore(r, widget.target);
      sc >= 76 ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
      widget.onResult?.call(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final r = res;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.top(context, busy ? null : r, busy, partial),
        // the result: score, what you said, the assist
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: busy || (r == null && !nothing)
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: nothing
                      ? Text('${t.spkNothing}${err.isEmpty ? '' : ' ($err)'}', textAlign: TextAlign.center, style: F.s(15, w: FontWeight.w700, c: p.soft))
                      : Column(
                          children: [
                            ScoreRing(speakScore(r!, widget.target)),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(text: '${t.spkYou} '),
                                TextSpan(text: r.heard, style: F.s(17, w: FontWeight.w700, family: F.zh, c: p.fg)),
                              ]),
                              textAlign: TextAlign.center,
                              style: F.s(14, c: p.soft),
                            ),
                          ],
                        ),
                ),
        ),
        const SizedBox(height: 4),
        if (app.canSpeak())
          Center(
            child: TextButton.icon(
              onPressed: () => speak(widget.target),
              icon: Icon2(I.speaker, size: 18, color: th.acc),
              label: Text(r != null ? t.spkRight : t.spkHear, style: F.s(15, w: FontWeight.w700, c: th.acc)),
            ),
          ),
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: level,
            builder: (c, v, _) => BigMic(onTap: _tap, busy: busy, level: v),
          ),
        ),
        Text(
          busy
              ? t.spkStop
              : (app.micOK ? '${t.spkTap} · ${L10.text(t.spkLv[spkLevels.indexOf(app.spk)])}' : t.spkAsk),
          textAlign: TextAlign.center,
          style: F.s(13.5, c: p.soft),
        ),
        if (widget.after != null) ...[const SizedBox(height: 14), widget.after!],
      ],
    );
  }
}

/// the speaking sheet (List): say the sentence (or the word), see each hanzi marked, try again as often as you like
void openSpeak(BuildContext context, Word d, {bool sentence = true}) {
  final sent = sentence && d.z.isNotEmpty;
  final target = sent ? d.z : d.h;
  openSheet(context, name: 'speak', (c) {
    final p = Th.pal(c);
    final t = app.t;
    return SheetBody(
      title: sent ? t.spkSay : t.qSpeak,
      children: [
        SpeakArea(
          target: target,
          top: (c, res, busy, heard) => Column(
            children: [
              const SizedBox(height: 6),
              SpokenText(target, res?.ok, size: sent ? 26 : 56),
              const SizedBox(height: 6),
              if (sent) ZpText(d, plainWord: true) else Py(d, size: 17),
              const SizedBox(height: 4),
              Text(sent ? app.tr(d) : app.m1(d), textAlign: TextAlign.center, style: F.s(14, c: p.soft, h: 1.4)),
              if (busy) ...[
                const SizedBox(height: 12),
                Text(
                  heard.isEmpty ? t.spkListening : heard,
                  textAlign: TextAlign.center,
                  style: F.s(heard.isEmpty ? 15 : 20, w: FontWeight.w700, c: p.soft, family: heard.isEmpty ? F.ui : F.zh),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  });
}

/// how to install a Mandarin voice (the speaker needs one): steps and a button to the TTS settings
void openTtsGuide(BuildContext context) {
  openSheet(context, name: 'ttsguide', (c) {
    final th = Th.of(c);
    final p = th.p;
    final t = app.t;
    final steps = t.ttsGuide;
    return SheetBody(
      title: t.ttsGuideT,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .15)),
                  child: Text('${i + 1}', style: F.s(13, w: FontWeight.w800, c: p.fg)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(L10.text(steps[i]), style: F.s(15, c: p.fg, h: 1.4))),
              ],
            ),
          ),
        const SizedBox(height: 14),
        MainBtn(t.ttsGuideBtn, wide: true, big: true, radius: 28, onTap: () {
          Navigator.pop(c);
          Native.I.openTtsSettings();
        }),
      ],
    );
  });
}
