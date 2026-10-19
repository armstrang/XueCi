/// Stats (stats.js, research.js): learning insights from the answer log, the memory model's accuracy, the research
/// code, word mastery per HSK level with a dot per word, a word's detail, reset and history deletion.
library;

import 'dart:convert';
import 'dart:io' show ZLibEncoder;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/mastery.dart';
import '../app/native.dart';
import '../data/words.dart';
import '../i18n/l10.dart';
import 'focus.dart';
import 'glass.dart';
import 'home.dart' show LevelLens;
import 'run_view.dart' show tName;
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  int lv = app.level;
  String? sel;
  bool confirm = false, hist = false;
  bool mcOpen = false;
  static bool rsOpen = false;
  final _scroll = ScrollController();
  static final researchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (rsOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = researchKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350));
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final arr = app.by(lv);
    final s = app.summary(arr);
    final d = sel == null ? null : app.vocab.idx[sel];
    final pad = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, pad.bottom + (d != null ? 190 : 96)),
          children: [
            Capsule(title: t.stTitle),
            const SizedBox(height: 12),
            const _Insights(),
            const SizedBox(height: 12),
            Glass(
              radius: 22,
              padding: const EdgeInsets.all(2),
              child: LevelLens(
                level: lv,
                onPick: (l) => setState(() {
                  lv = l;
                  sel = null;
                  confirm = false;
                }),
              ),
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: app.pctTxt(s.p), style: F.s(28, w: FontWeight.w800, c: p.fg, ls: -.5, feat: F.tab)),
                  TextSpan(text: ' ${t.memoWord}', style: F.s(13, c: p.soft)),
                ],
              ),
            ),
            Text(
              'HSK $lv · ${t.words(app.fmt(s.n))} · ${t.practiced(app.fmt(s.n - s.none))} · ${t.matureN(app.fmt(s.mature))}',
              style: F.s(12.5, c: p.soft),
            ),
            const SizedBox(height: 10),
            SizedBox(height: 12, child: MiniBar(s, width: double.infinity)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (b, r) in const [('red', '0–6'), ('yellow', '7–13'), ('green', '14–20'), ('none', '')])
                  Glass(
                    solid: true,
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Dot(p.band(b)),
                            const SizedBox(width: 6),
                            Text(app.fmt(s.band(b)), style: F.s(15, w: FontWeight.w800, c: p.fg, feat: F.tab)),
                          ],
                        ),
                        Text(
                          '${L10.text(t.band[b])}${r.isNotEmpty ? ' · ${t.lvlWord} $r' : ''}',
                          style: F.s(11.5, c: p.soft),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Scale(big: th.fs >= 1.15),
            const SizedBox(height: 14),
            for (var u = 1; u <= (app.vocab.units[lv] ?? 1); u++) _unit(context, arr.where((x) => x.u == u).toList(), u),
            const SizedBox(height: 10),
            _foot(context),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + 78,
          child: d == null || d.l != lv ? _Hint(t.dotHint) : _Detail(d),
        ),
      ],
    );
  }

  Widget _unit(BuildContext context, List<Word> it, int u) {
    final p = Th.pal(context);
    final t = app.t;
    final su = app.summary(it);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${t.unit.toUpperCase()} ${u.toString().padLeft(2, '0')}', style: F.s(11.5, w: FontWeight.w800, c: p.fg, ls: .5)),
                TextSpan(text: ' · ${app.pctTxt(su.p)} · ${plainText(t.matureOf(su.mature, su.n))}', style: F.s(11.5, c: p.soft)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final d in it)
                Semantics(
                  button: true,
                  selected: d.id == sel,
                  label: d.h,
                  child: GestureDetector(
                    onTap: () => setState(() => sel = d.id),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: levelColor(p, app.lvl(d)),
                        borderRadius: BorderRadius.circular(6),
                        border: d.id == sel ? Border.all(color: p.fg, width: 2) : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _foot(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    if (confirm || hist) {
      return Glass(
        solid: true,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(confirm ? t.rsQ(lv) : t.histQ, style: F.s(14, c: p.fg, h: 1.4)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: GhostBtn(t.cancel, wide: true, onTap: () => setState(() => confirm = hist = false))),
                const SizedBox(width: 8),
                Expanded(
                  child: MainBtn(
                    confirm ? t.rsYes : t.histYes,
                    wide: true,
                    radius: 16,
                    color: p.bad,
                    onTap: () {
                      if (confirm) {
                        for (final d in app.by(lv)) {
                          app.lm.stats.remove(d.id);
                          app.lm.forget(d.id);
                        }
                        app.lm.saveStats();
                        app.runner.reset();
                        app.toast(t.rsDone(lv));
                      } else {
                        app.lm.clearLog();
                        app.toast(t.histDone);
                      }
                      setState(() {
                        confirm = hist = false;
                        sel = null;
                      });
                      app.changed();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.rsNote, style: F.s(12.5, c: p.soft, h: 1.45)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Press(
              onTap: () => setState(() => confirm = true),
              scale: 1.04,
              label: t.rsAsk(lv),
              child: Glass(
                radius: 999,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(t.rsAsk(lv), style: F.s(13, w: FontWeight.w700, c: p.bad)),
              ),
            ),
            GhostBtn(t.histDel, fontSize: 13, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), onTap: () => setState(() => hist = true)),
          ],
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Glass(
    frost: true,
    radius: 18,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Text(text, style: F.s(13, c: Th.pal(context).mute)),
  );
}

class _Detail extends StatelessWidget {
  final Word d;
  const _Detail(this.d);
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    final e = app.lm.memOf(d.id);
    final names = [t.skM, t.skF, t.skS];
    return Glass(
      frost: true,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(d.n.toString().padLeft(4, '0'), style: F.s(11.5, c: p.mute, feat: F.tab)),
              Hz(d, size: 24, weight: FontWeight.w900, family: F.hz),
              Py(d, size: 14, weight: FontWeight.w700),
              Text(app.m1(d), style: F.s(13, c: p.fg)),
              Spk(d.h, size: 26),
            ],
          ),
          LevelLine(d),
          if (e != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Builder(
                    builder: (c) {
                      final l = app.lm.skLevel(e.sk(['m', 'f', 's'][i]));
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${names[i]} ', style: F.s(12, c: p.soft)),
                          Dot(levelColor(p, l), size: 8),
                          Text(' ${l < 0 ? '–' : l}', style: F.s(12, w: FontWeight.w800, c: p.fg)),
                        ],
                      );
                    },
                  ),
                Text(t.detNext(t.rel((app.lm.nextDue(d.id) ?? 0).ceil())), style: F.s(12, c: p.soft)),
                if (e.L == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: p.sYellow.withValues(alpha: .2), borderRadius: BorderRadius.circular(999)),
                    child: Text(t.detLegacy, style: F.s(11, w: FontWeight.w700, c: p.fg)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// the 1–20 colour scale under the counts
class _Scale extends StatelessWidget {
  final bool big;
  const _Scale({required this.big});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    return LayoutBuilder(
      builder: (c, bc) {
        final w = bc.maxWidth / 20;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(children: [for (var i = 1; i <= 20; i++) Container(width: w, height: 10, color: levelColor(p, i))]),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (final (i, s) in [(1, '1'), (7, '7'), if (!big) (14, '14')])
                    Positioned(left: (i - 1) * w, child: Text(s, style: F.s(11, c: p.soft))),
                  Positioned(right: 0, child: Text('20 · ${t.matureWord}', style: F.s(11, c: p.soft))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Insights extends StatefulWidget {
  const _Insights();
  @override
  State<_Insights> createState() => _InsightsState();
}

class _InsightsState extends State<_Insights> {
  bool mc = false;
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final i = app.lm.insights();
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(t.insT, style: F.s(17, w: FontWeight.w800, c: p.fg)),
        const SizedBox(width: 8),
        Expanded(child: Text(t.insPriv, textAlign: TextAlign.right, style: F.s(12, c: p.soft))),
      ],
    );
    if (i['total'] == 0) {
      return Glass(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const SizedBox(height: 8), Text(t.insEmpty, style: F.s(13, c: p.soft, h: 1.45))]),
      );
    }
    final skills = i['skills'] as Map<String, Map<String, int>>;
    final cal = i['cal'] as Map;
    Color col(int x) => x >= 85 ? p.sGreen : (x >= 65 ? p.sYellow : p.sRed);
    Widget kpi(String a, String b) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: p.fgA(.06), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a, style: F.s(20, w: FontWeight.w800, c: p.fg, feat: F.tab)),
            Text(b, style: F.s(11.5, c: p.soft, h: 1.3)),
          ],
        ),
      ),
    );
    final pairs = i['pairs'] as List;
    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          const SizedBox(height: 10),
          Row(
            children: [
              kpi(i['recall'] == null ? '–' : '${i['recall']}%', t.insRecall),
              const SizedBox(width: 8),
              kpi(app.fmt(i['n7'] as int), t.insAns7),
              const SizedBox(width: 8),
              kpi((cal['n'] as int) >= 5 ? '${((cal['acc'] as double) * 100).round()}%' : '–', t.insCal),
            ],
          ),
          const SizedBox(height: 8),
          for (final k in const ['m', 'f', 's', 'l', 'c', 'p', 't'])
            if (skills[k] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        tName(k),
                        style: F.s(13.5, w: i['weak'] == k ? FontWeight.w800 : FontWeight.w400, c: i['weak'] == k ? p.bad : p.fg),
                      ),
                    ),
                    Expanded(child: StackBar([(skills[k]!['p']! / 100, col(skills[k]!['p']!))], height: 6)),
                    SizedBox(
                      width: 48,
                      child: Text('${skills[k]!['p']}%', textAlign: TextAlign.right, style: F.s(13.5, w: FontWeight.w800, c: p.fg, feat: F.tab)),
                    ),
                  ],
                ),
              ),
          if (i['weak'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t.insWeak(tName(i['weak'] as String)), style: F.s(13, c: p.soft, h: 1.45))),
          if (pairs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(t.insConf, style: F.s(12.5, c: p.soft)),
                for (final pr in pairs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(color: p.fgA(.06), borderRadius: BorderRadius.circular(999)),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: (pr[0] as Word).h, style: F.s(16, w: FontWeight.w900, family: F.hz)),
                          const TextSpan(text: ' ↔ '),
                          TextSpan(text: (pr[1] as Word).h, style: F.s(16, w: FontWeight.w900, family: F.hz)),
                          TextSpan(text: ' ×${pr[2]}', style: F.s(11, c: p.soft)),
                        ],
                      ),
                      style: F.s(13, c: p.fg),
                    ),
                  ),
              ],
            ),
          ],
          const _Divider(),
          _model(context, i),
          const _Divider(),
          _Research(key: StatsScreenState.researchKey),
        ],
      ),
    );
  }

  Widget _model(BuildContext context, Map i) {
    final p = Th.pal(context);
    final t = app.t;
    final c = app.lm.modelCheck();
    String pc(num x) => '${(x * 100).round()}%';
    final model = i['model'] as Map?;
    final state = model != null
        ? t.insModelOwn(app.fmt(model['n'] as num))
        : ((i['spaced'] as int) >= (i['need'] as int) ? t.insModelSoon : t.insModelBase(app.fmt(i['spaced'] as int), app.fmt(i['need'] as int)));
    final n = (c['n'] as int?) ?? 0;
    if (n < 30) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.mcT, style: F.s(14.5, w: FontWeight.w800, c: p.fg)),
          const SizedBox(height: 4),
          Text('${t.mcWait(app.fmt(n))} $state', style: F.s(12.5, c: p.soft, h: 1.45)),
        ],
      );
    }
    final ece = ((c['ece'] as double) * 100).round();
    return _Fold(
      title: t.mcT,
      sub: '±$ece · ${t.mcN(app.fmt(n))}',
      open: mc,
      onToggle: (v) => setState(() => mc = v),
      children: [
        Row(
          children: [
            for (final (a, b) in [(pc(c['pred'] as double), t.mcPred), (pc(c['real'] as double), t.mcReal), ('±$ece', t.mcGap)])
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: p.fgA(.06), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(a, style: F.s(18, w: FontWeight.w800, c: p.fg)), Text(b, style: F.s(11.5, c: p.soft))],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final b in c['bins'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 74, child: Text('${((b['a'] as num) * 100).round()}–${((b['b'] as num) * 100).round()}%', style: F.s(12.5, c: p.fg))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (cx, bc) {
                      final y = (b['y'] as num).toDouble(), pr = (b['p'] as num).toDouble();
                      final g = (y - pr).abs();
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          StackBar([(y, g <= .05 ? p.sGreen : (g <= .1 ? p.sYellow : p.sRed))], height: 6),
                          Positioned(left: bc.maxWidth * pr - 1, top: -3, child: Container(width: 2, height: 12, color: p.fg)),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: 48, child: Text(pc(b['y'] as num), textAlign: TextAlign.right, style: F.s(12.5, w: FontWeight.w800, c: p.fg))),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('${t.mcHow} $state', style: F.s(12.5, c: p.soft, h: 1.45)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Container(height: 1, color: Th.pal(context).line),
  );
}

/// a folding section (the web app's details element)
class _Fold extends StatelessWidget {
  final String title;
  final String? sub;
  final bool open;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;
  const _Fold({required this.title, this.sub, required this.open, required this.onToggle, required this.children});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onToggle(!open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedRotation(
                    turns: open ? .25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Text('▶', style: F.s(12, c: p.fg)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: F.s(14.5, w: FontWeight.w800, c: p.fg)),
                        if (sub != null) Text(sub!, style: F.s(12, c: p.soft, feat: F.tab)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: open
              ? Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// data for research (voluntary): a code the learner copies or shares themselves
class _Research extends StatefulWidget {
  const _Research({super.key});
  @override
  State<_Research> createState() => _ResearchState();
}

class _ResearchState extends State<_Research> {
  late Map<String, dynamic> prof = () {
    final x = app.store.get('xc_res', {});
    return x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
  }();
  late final _score = TextEditingController(text: prof['score'] is num ? '${prof['score']}' : '');

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  void _save() {
    final p = <String, dynamic>{};
    if (prof['lv'] is int) p['lv'] = prof['lv'];
    final sc = int.tryParse(_score.text.trim());
    if (sc != null && sc >= 0 && sc <= 300) p['score'] = sc;
    if (prof['date'] is String && RegExp(r'^\d{4}-\d\d$').hasMatch(prof['date'])) p['date'] = prof['date'];
    app.store.set('xc_res', p);
  }

  String code() {
    _save();
    final lv = app.lm.lvInfo ?? {};
    final log = app.lm.allLog();
    final o = {
      'app': 'xueci',
      'kind': 'research',
      'v': 1,
      'at': DateTime.now().millisecondsSinceEpoch,
      'hsk': app.store.get('xc_res', {}),
      'realm': app.lm.realm(),
      'lvl': {'hist': lv['hist'] ?? [], 'th': lv['th'], 'per': lv['per'], 'pt': lv['pt']},
      'langs': app.lang,
      'log': [for (final e in log.length > 12000 ? log.sublist(log.length - 12000) : log) e.toJson()],
    };
    final raw = utf8.encode(json.encode(o));
    final z = ZLibEncoder(raw: true, level: 9).convert(raw);
    return 'XUECIR1:${base64Url.encode(z).replaceAll('=', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final levels = app.band ? [1, 2, 3, 4, 5, 6, 7, 8, 9] : [1, 2, 3, 4, 5, 6, 7];
    return _Fold(
      title: t.rsT,
      open: StatsScreenState.rsOpen,
      onToggle: (v) => setState(() => StatsScreenState.rsOpen = v),
      children: [
        Text(t.rsWhat, style: F.s(12.5, c: p.soft, h: 1.45)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _field(
              t.rsHsk,
              DropdownButton<int?>(
                value: prof['lv'] as int?,
                underline: const SizedBox(),
                isDense: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('–')),
                  for (final l in levels) DropdownMenuItem(value: l, child: Text('HSK ${l == 7 && !app.band ? '6+' : l}')),
                ],
                onChanged: (v) => setState(() {
                  prof['lv'] = v;
                  _save();
                }),
              ),
            ),
            _field(
              t.rsScore,
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _score,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  onChanged: (_) => _save(),
                ),
              ),
            ),
            _field(
              t.rsDate,
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: context, firstDate: DateTime(2010), lastDate: now, initialDate: now);
                  if (d != null) {
                    setState(() {
                      prof['date'] = '${d.year}-${d.month.toString().padLeft(2, '0')}';
                      _save();
                    });
                  }
                },
                child: Text(prof['date'] as String? ?? '–', style: F.s(14, w: FontWeight.w700, c: th.acc)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            GhostBtn(
              t.rsCopy,
              fontSize: 13,
              onTap: () {
                Clipboard.setData(ClipboardData(text: code()));
                app.toast(t.rsCopied);
              },
            ),
            const SizedBox(width: 8),
            if (Native.I.isAndroid) GhostBtn(t.bkShare, pri: true, fontSize: 13, onTap: () => Native.I.shareText(code())),
          ],
        ),
        const SizedBox(height: 8),
        Text(t.rsPriv, style: F.s(12, c: p.soft, h: 1.45)),
      ],
    );
  }

  Widget _field(String label, Widget w) {
    final p = Th.pal(context);
    return Glass(
      solid: true,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [Text(label, style: F.s(11.5, c: p.soft)), w],
      ),
    );
  }
}

/// for the screens that open Stats at the research form (Settings › Research)
void openResearch() {
  StatsScreenState.rsOpen = true;
  app.go('stats');
}

