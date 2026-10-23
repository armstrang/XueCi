/// How a word is shown (list, card back, quiz feedback): hanzi in tone colours, pinyin, meaning, the example
/// sentence with the word marked, its pinyin, its translation; speaker buttons.
library;


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

/// hanzi coloured by what was said: green right, red (underlined) wrong; plain before any try
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
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < ch.length; i++)
            TextSpan(
              text: ch[i],
              style: ok == null || !isHan(ch[i])
                  ? null
                  : TextStyle(
                      color: ok![i] ? p.good : p.bad,
                      decoration: ok![i] ? null : TextDecoration.underline,
                      decorationColor: p.bad,
                      decorationThickness: 2.4,
                    ),
            ),
        ],
      ),
      style: base,
      textAlign: TextAlign.center,
      locale: const Locale('zh', 'CN'),
      semanticsLabel: text,
    );
  }
}

/// the big round microphone: tinted liquid glass, pulses while the phone listens
class BigMic extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;
  const BigMic({super.key, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final c = th.acc;
    return Press(
      onTap: onTap,
      scale: .92,
      label: app.t.spkMic,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: busy ? 1 : 0),
        duration: const Duration(milliseconds: 240),
        builder: (ctx, v, child) => Transform.scale(scale: 1 + .06 * v, child: child),
        child: CustomPaint(
          painter: OuterShadow(
            th.low ? const [] : [BoxShadow(color: c.withValues(alpha: .45), offset: const Offset(0, 12), blurRadius: 28, spreadRadius: -10)],
            48,
          ),
          child: Glass(
            inner: true,
            radius: 48,
            width: 96,
            height: 96,
            shadow: const [],
            color: Color.lerp(c, Colors.black, th.p.dark ? .35 : .2)!.withValues(alpha: th.p.dark ? .55 : .8),
            child: Center(child: Icon2(I.mic, size: 42, color: th.p.dark ? th.p.fg : th.p.onAcc, width: 2.2)),
          ),
        ),
      ),
    );
  }
}

/// the speaking sheet (List): say the sentence (or the word), see each hanzi marked, try again as often as you like
void openSpeak(BuildContext context, Word d, {bool sentence = true}) {
  openSheet(context, name: 'speak', (c) => _Speak(d: d, sentence: sentence && d.z.isNotEmpty));
}

class _Speak extends StatefulWidget {
  final Word d;
  final bool sentence;
  const _Speak({required this.d, required this.sentence});
  @override
  State<_Speak> createState() => _SpeakState();
}

class _SpeakState extends State<_Speak> {
  SpeakResult? res;
  bool busy = false, nothing = false;

  String get target => widget.sentence ? widget.d.z : widget.d.h;

  Future<void> _go() async {
    if (busy) return;
    setState(() {
      busy = true;
      nothing = false;
    });
    final r = await app.hear(target);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (r != null && r.heard.isEmpty) {
        nothing = true;
      } else if (r != null) {
        res = r;
        HapticFeedback.lightImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final d = widget.d;
    final r = res;
    final n = target.runes.map(String.fromCharCode).where(isHan).length;
    return SheetBody(
      title: widget.sentence ? t.spkSay : t.qSpeak,
      children: [
        const SizedBox(height: 6),
        Center(child: SpokenText(target, r?.ok, size: widget.sentence ? 26 : 56)),
        const SizedBox(height: 6),
        if (widget.sentence) Center(child: ZpText(d, plainWord: true)) else Center(child: Py(d, size: 17)),
        const SizedBox(height: 4),
        Text(widget.sentence ? app.tr(d) : app.m1(d), textAlign: TextAlign.center, style: F.s(14, c: p.soft, h: 1.4)),
        const SizedBox(height: 18),
        if (r != null || nothing)
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  nothing ? t.spkNothing : (r!.all ? t.spkAll : t.spkSome(r.share(target) * n ~/ 1, n)),
                  textAlign: TextAlign.center,
                  style: F.s(16, w: FontWeight.w800, c: nothing ? p.soft : (r!.all ? p.good : p.bad)),
                ),
                if (!nothing && r!.heard.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(t.spkHeard(r.heard), textAlign: TextAlign.center, style: F.s(14, c: p.soft)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Center(child: BigMic(onTap: busy ? null : _go, busy: busy)),
        const SizedBox(height: 10),
        Text('${t.spkTap} · ${L10.text(t.spkLv[spkLevels.indexOf(app.spk)])}', textAlign: TextAlign.center, style: F.s(13, c: p.soft)),
        if (app.canSpeak())
          Center(
            child: TextButton.icon(
              onPressed: () => speak(target),
              icon: Icon2(I.speaker, size: 18, color: Th.of(context).acc),
              label: Text(t.spkHear, style: F.s(14, w: FontWeight.w700, c: Th.of(context).acc)),
            ),
          ),
      ],
    );
  }
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
