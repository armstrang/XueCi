/// The tones & help sheet (info.js): the five tones, the help topics (realms, stages, elements and the glossary as
/// tables), about, the privacy policy.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../app/app.dart';
import '../app/native.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'realm.dart' show rcol;
import 'settings.dart' show privacyUrl;
import 'sheet.dart';
import 'soul.dart' show el5, atz, elp, elColor;
import 'theme.dart';
import 'widgets.dart';

/// the glossary's public terms (the sealed part adds its own when the gate is open)
const gl = [
  ('境界', 'jìngjiè', 'jj'),
  ('突破', 'tūpò', 'tp'),
  ('识海', 'shíhǎi', 'sh'),
  ('五行', 'wǔxíng', 'wx'),
  ('指点', 'zhǐdiǎn', 'zd'),
  ('今日试炼', 'jīnrì shìliàn', 'sl'),
  ('修炼天数', 'xiūliàn tiānshù', 'xl'),
  ('闭关', 'bìguān', 'bg'),
  ('调息', 'tiáoxī', 'tx'),
  ('休息之道', 'xiūxi zhī dào', 'xd'),
  ('境界历程', 'jìngjiè lìchéng', 'lc'),
  ('雷劫', 'léijié', 'lj'),
  ('道基', 'dàojī', 'dj'),
  ('认定', 'rèndìng', 'rd'),
  ('境界不稳', 'jìngjiè bù wěn', 'bw'),
  ('试炼稳固', 'shìliàn wěngù', 'wg'),
  ('补劫', 'bǔjié', 'bj'),
];

void openInfo(BuildContext context, [String? topic]) {
  openSheet(context, name: 'info', (c) => _Info(topic: topic));
}

class _Info extends StatefulWidget {
  final String? topic;
  const _Info({this.topic});
  @override
  State<_Info> createState() => _InfoState();
}

class _InfoState extends State<_Info> {
  late final Set<String> open = {?widget.topic};
  String? licText; // assets/legal/licenses.txt, loaded when first opened
  final keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    if (widget.topic != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = keys[widget.topic]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    const tz = [('妈', 'mā'), ('麻', 'má'), ('马', 'mǎ'), ('骂', 'mà'), ('吗', 'ma')];
    final cred = t.credit.split('{src}');
    Widget h3(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(header: true, child: Text(s, style: F.s(14, w: FontWeight.w800, c: p.fg))),
    );
    Widget isec(List<Widget> c) => Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c),
    );
    return SheetBody(
      titleW: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: th.acc, width: 1.8),
              boxShadow: sh([BoxShadow(color: th.acc.withValues(alpha: .6), blurRadius: 16, spreadRadius: -2)]),
            ),
            child: Text('!', style: F.s(13, w: FontWeight.w900, c: th.acc, h: 1)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(t.infoTitle, style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25))),
        ],
      ),
      children: [
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 2), child: h3(t.toneT)),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t.infoLead, style: F.s(13.5, c: p.soft, h: 1.45))),
        for (var i = 0; i < 5; i++)
          Builder(
            builder: (c) {
              final row = t.tones[i] as List;
              final col = p.t(i + 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Glass(
                  solid: true,
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 34, child: Text(tz[i].$1, textAlign: TextAlign.center, style: F.s(24, w: FontWeight.w900, family: F.hz, c: col, h: 1))),
                      const SizedBox(width: 10),
                      SizedBox(width: 38, child: Text(tz[i].$2, style: F.s(14, w: FontWeight.w800, c: col))),
                      const SizedBox(width: 10),
                      SizedBox(width: 40, height: 24, child: CustomPaint(painter: _ToneCurve(i, col))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(L10.text(row[0]), style: F.s(13.5, w: FontWeight.w700, c: p.fg, h: 1.25)),
                            Rich(L10.text(row[1]), style: F.s(11.5, c: p.soft, h: 1.25)),
                          ],
                        ),
                      ),
                      Text(L10.text(row[2]), style: F.s(12, c: p.soft, style: FontStyle.italic)),
                    ],
                  ),
                ),
              );
            },
          ),
        isec([
          h3(t.helpT),
          for (final x in t.help)
            Builder(
              builder: (c) {
                final e = x as List;
                final k = '${e[0]}';
                final on = open.contains(k);
                return Padding(
                  key: keys.putIfAbsent(k, GlobalKey.new),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Glass(
                    solid: true,
                    radius: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          button: true,
                          expanded: on,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => on ? open.remove(k) : open.add(k)),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                              child: Row(
                                children: [
                                  Expanded(child: Text(L10.text(e[1]), style: F.s(14, w: FontWeight.w800, c: p.fg, h: 1.35))),
                                  AnimatedRotation(
                                    turns: on ? .5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon2(I.chev, size: 14, color: p.mute),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (on)
                          for (final b in e[2] as List) _block(context, L10.text(b)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ]),
        isec([
          h3(t.aboutT),
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Rich(t.about, style: F.s(13, c: p.soft, h: 1.45))),
          Press(
            onTap: () => Native.I.openUrl('https://github.com/armstrang'),
            scale: .98,
            label: 'github.com/armstrang',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon2(I.github, size: 20, color: p.bg),
                  const SizedBox(width: 10),
                  Expanded(child: Text('github.com/armstrang', style: F.s(14, w: FontWeight.w800, c: p.bg))),
                  Text('↗', style: F.s(14, c: p.bg.withValues(alpha: .7))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Press(
            onTap: () => Native.I.openUrl(privacyUrl),
            scale: .98,
            label: t.privacy,
            child: Glass(
              solid: true,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(t.privacy, style: F.s(14, w: FontWeight.w700, c: p.fg))),
                  Text('↗', style: F.s(14, c: p.soft)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Press(
            onTap: () async {
              if (licText != null) return setState(() => licText = null);
              final x = await rootBundle.loadString('assets/legal/licenses.txt');
              if (mounted) setState(() => licText = x);
            },
            scale: .98,
            label: t.licT,
            child: Glass(
              solid: true,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(t.licT, style: F.s(14, w: FontWeight.w700, c: p.fg))),
                  AnimatedRotation(
                    turns: licText != null ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon2(I.chev, size: 14, color: p.mute),
                  ),
                ],
              ),
            ),
          ),
          if (licText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(licText!, style: F.s(10.5, c: p.soft, h: 1.4)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                style: F.s(11.5, c: p.mute, h: 1.45),
                children: [
                  TextSpan(text: cred[0]),
                  if (cred.length > 1) ...[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => Native.I.openUrl('https://github.com/harukicoder/hsk30'),
                        child: Text('hsk30', style: F.s(11.5, c: p.soft).copyWith(decoration: TextDecoration.underline, decorationColor: p.soft)),
                      ),
                    ),
                    TextSpan(text: cred[1]),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  /// '@realms', '@stages', '@elements' and '@gloss' become tables: hanzi, pinyin, meaning, explanation
  Widget _block(BuildContext context, String x) {
    final p = Th.pal(context);
    final th = Th.of(context);
    final t = app.t;
    Widget tab(List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(13, 2, 13, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 6), child: r)]),
    );
    switch (x) {
      case '@realms':
        return tab([
          for (var i = 0; i <= app.topR; i++)
            _HRow(
              app.rn[i],
              app.rpy[i],
              '${L10.text(t.realmM[i])} · ${i > 0 ? app.realmHSK(i) : t.notTested}',
              L10.text(t.realmD[i]),
              rcol(context, i),
            ),
        ]);
      case '@stages':
        return tab([for (var i = 0; i < 4; i++) _HRow(App.sn[i], App.spy[i], L10.text(t.stageM[i]), L10.text(t.stageD[i]), th.acc)]);
      case '@elements':
        return tab([
          for (final (k, g, a) in el5)
            _HRow(
              '$g ${atz[a]!.$1}',
              '${elp[k]} · ${atz[a]!.$2}',
              '${L10.text(t.elName[k])} · ${L10.text(t.attrN[a])}',
              L10.text(t.attrD[a]),
              elColor(p, k),
            ),
        ]);
      case '@gloss':
        final sealed = app.band ? (app.sealedX['gl'] as List? ?? const []) : const [];
        final all = [...gl, for (final e in sealed) (e[0] as String, e[1] as String, e[2] as String)];
        return tab([
          for (final (h, py, k) in all)
            Builder(
              builder: (c) {
                final parts = L10.text(t.gloss[k]).split(': ');
                return _HRow(h, py, parts[0], parts.skip(1).join(': '), th.acc);
              },
            ),
        ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
      child: Rich(x, style: F.s(13, c: p.soft, h: 1.5), boldColor: p.fg),
    );
  }
}

class _HRow extends StatelessWidget {
  final String hz, py, main, sub;
  final Color lc;
  const _HRow(this.hz, this.py, this.main, this.sub, this.lc);
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: lc.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: p.dark ? .08 : .4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hz, style: F.s(17, w: FontWeight.w900, family: F.hz, c: lc, h: 1.25)),
                Text(py, style: F.s(11.5, c: p.soft, h: 1.25)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(main, style: F.s(13, w: FontWeight.w800, c: p.fg, h: 1.4)),
                if (sub.isNotEmpty) Text(sub, style: F.s(12, c: p.soft, h: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneCurve extends CustomPainter {
  final int i;
  final Color c;
  _ToneCurve(this.i, this.c);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.scale(s.width / 40, s.height / 24);
    if (i == 4) {
      canvas.drawCircle(const Offset(20, 14), 3.2, Paint()..color = c);
      return;
    }
    const d = ['M4 6H36', 'M4 17L36 5', 'M4 9Q16 24 23 18T36 5', 'M4 4L36 20'];
    canvas.drawPath(
      svgPath(d[i]),
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ToneCurve o) => o.c != c || o.i != i;
}
