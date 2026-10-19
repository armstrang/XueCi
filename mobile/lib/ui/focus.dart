/// The focused screens (List, Cards, Quiz, today's session, the placement test, the tribulation): one floating
/// glass capsule at the top (back · title · HSK · unit), then the task. The level and unit pickers open as glass
/// menus under the capsule.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/mastery.dart';
import '../data/pinyin.dart';
import '../data/words.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';
import 'word_ui.dart';

/// the capsule header shared by the focused screens, Stats and the Soul Sea
class Capsule extends StatelessWidget {
  final String title;
  final bool pickers;
  final List<Widget> trailing;
  final VoidCallback? onBack;
  const Capsule({super.key, required this.title, this.pickers = false, this.trailing = const [], this.onBack});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final u = app.unit;
    return Compact(
      child: Glass(
        radius: 999,
        frost: true,
        padding: const EdgeInsets.all(4),
        shadow: const [BoxShadow(color: Color.fromRGBO(20, 25, 40, .45), offset: Offset(0, 10), blurRadius: 26, spreadRadius: -16)],
        child: Row(
          children: [
            _CapBtn(
              label: t.back,
              onTap: onBack ?? () => backFrom(context),
              child: Icon2(I.back, size: 22, color: p.fg),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: F.s(18, w: FontWeight.w800, c: p.fg, ls: -.3),
                ),
              ),
            ),
            if (pickers) ...[
              _CapBtn(
                label: '${t.pickLv}: HSK ${app.level}',
                onTap: () => openLevelMenu(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('HSK ${app.level}', style: F.s(15, w: FontWeight.w800, c: th.acc)),
                    const SizedBox(width: 4),
                    Icon2(I.chev, size: 14, color: p.mute),
                  ],
                ),
              ),
              Container(width: 1, height: 18, color: p.fgA(.14)),
              _CapBtn(
                label: '${t.pickU}: ${u != 0 ? '${t.unit} $u' : t.allU}',
                onTap: () => openUnitMenu(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      u != 0 ? '${t.unit} ${u.toString().padLeft(2, '0')}' : t.allShort,
                      style: F.s(15, w: FontWeight.w700, c: p.fg),
                    ),
                    const SizedBox(width: 4),
                    Icon2(I.chev, size: 14, color: p.mute),
                  ],
                ),
              ),
            ],
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// the back arrow of a focused screen (a running HSK simulation warns first)
void backFrom(BuildContext context) {
  if (app.backHook != null && app.backHook!()) return;
  app.go(app.screen == 'stats' ? app.prevScreen : 'home');
}

class _CapBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String label;
  const _CapBtn({required this.child, required this.onTap, required this.label});
  @override
  Widget build(BuildContext context) => Press(
    onTap: onTap,
    scale: .95,
    label: label,
    child: Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      child: child,
    ),
  );
}

/// a glass menu that drops from the top right, under the capsule
Future<T?> openMenu<T>(BuildContext context, Widget Function(BuildContext) body, {double width = 440}) {
  final th = Th.of(context);
  final top = MediaQuery.paddingOf(context).top + 64;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: app.t.close,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (c, a1, a2) => Th(
      p: th.p,
      acc: th.acc,
      rc: th.rc,
      low: th.low,
      full: th.full,
      fs: th.fs,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(c).height - top - 24),
            child: Material(type: MaterialType.transparency, child: _MenuBox(child: Builder(builder: body))),
          ),
        ),
      ),
    ),
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        alignment: Alignment.topRight,
        scale: Tween(begin: .88, end: 1.0).animate(CurvedAnimation(parent: a, curve: const Cubic(.2, .9, .3, 1.15))),
        child: child,
      ),
    ),
  );
}

class _MenuBox extends StatelessWidget {
  final Widget child;
  const _MenuBox({required this.child});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final r = BorderRadius.circular(22);
    Widget box = Container(
      decoration: BoxDecoration(
        color: th.low ? th.p.surface : th.p.gHead,
        borderRadius: r,
        border: Border.all(color: th.p.gEdge),
      ),
      padding: const EdgeInsets.all(6),
      child: child,
    );
    if (!th.low) {
      box = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: box),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: sh(const [BoxShadow(color: Color.fromRGBO(22, 26, 34, .3), offset: Offset(0, 18), blurRadius: 50)]),
      ),
      child: box,
    );
  }
}

/// a small bar of a level's or unit's mastery (bands from deep green to red)
class MiniBar extends StatelessWidget {
  final MSum s;
  final double width;
  const MiniBar(this.s, {super.key, this.width = 76});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return SizedBox(
      width: width,
      height: 6,
      child: StackBar([
        for (var k = maxL; k >= 0; k--)
          if (s.lv[k] > 0) (s.lv[k] / s.n, levelColor(p, k)),
      ], height: 6, gap: 0, track: p.sNone),
    );
  }
}

void openLevelMenu(BuildContext context) {
  openMenu(context, (c) {
    final p = Th.pal(c);
    final t = app.t;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Rich(t.allLv(app.fmt(app.masteredAll()), app.fmt(app.vocab.data.length)), style: F.s(12, c: p.soft)),
          ),
          for (final l in app.vocab.levels)
            Builder(
              builder: (c) {
                final s = app.summary(app.by(l));
                final on = app.level == l;
                return Press(
                  onTap: () {
                    Navigator.pop(c);
                    if (!on) app.setLevel(l);
                  },
                  scale: .97,
                  selected: on,
                  label: 'HSK $l, ${t.words(app.fmt(s.n))}, ${app.pctTxt(s.p)}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: on ? p.l(l).withValues(alpha: .12) : null,
                    ),
                    child: Row(
                      children: [
                        Dot(p.l(l), size: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('HSK $l', style: F.s(14.5, w: FontWeight.w700, c: p.fg)),
                              Text(t.words(app.fmt(s.n)), style: F.s(11.5, c: p.soft)),
                            ],
                          ),
                        ),
                        MiniBar(s),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 44,
                          child: Text(app.pctTxt(s.p), textAlign: TextAlign.right, style: F.s(12.5, w: FontWeight.w700, c: p.fg, feat: F.tab)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          Container(height: 1, color: p.line, margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
          Press(
            onTap: () {
              Navigator.pop(c);
              app.go('stats');
            },
            scale: .97,
            label: t.fullStats,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(t.fullStats, style: F.s(14, w: FontWeight.w700, c: Th.of(c).acc))),
                  Text('›', style: F.s(16, c: Th.of(c).acc)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  });
}

void openUnitMenu(BuildContext context) {
  openMenu(context, (c) {
    final p = Th.pal(c);
    final t = app.t;
    final L = app.level;
    final sa = app.summary(app.by(L));
    final units = app.vocab.units[L] ?? 1;
    Widget cell(int u, {bool all = false}) {
      final s = all ? sa : app.summary(app.unitItems(u));
      final on = app.unit == u;
      return Press(
        onTap: () {
          Navigator.pop(c);
          app.setUnit(u);
        },
        scale: .95,
        selected: on,
        label: all ? t.allU : '${t.unit} $u, ${app.pctTxt(s.p)}',
        child: Glass(
          solid: true,
          radius: 15,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
          color: on ? Th.of(c).acc.withValues(alpha: .16) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(all ? t.allU : '${t.uS}${u.toString().padLeft(2, '0')}', style: F.s(14, w: FontWeight.w800, c: p.fg)),
              Text(
                all ? '${t.words(app.fmt(s.n))} · ${app.pctTxt(s.p)} · ${plainText(t.matureOf(app.fmt(s.mature), app.fmt(s.n)))}' : app.pctTxt(s.p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.s(11, c: p.soft),
              ),
              const SizedBox(height: 5),
              MiniBar(s, width: double.infinity),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(0, all: true),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.25,
            children: [for (var u = 1; u <= units; u++) cell(u)],
          ),
        ],
      ),
    );
  });
}

// ---------------------------------------------------------------- the word list
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _q = TextEditingController(text: app.q);
  final _scroll = ScrollController();
  int _top = app.scrollTop;

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static final _latinOnly = RegExp(r'^[\u0000-ɏḀ-ỿ\s]*$');

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    if (_top != app.scrollTop) {
      _top = app.scrollTop;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
    final q = app.q.trim().toLowerCase();
    final qp = _latinOnly.hasMatch(app.q) ? plain(app.q) : '';
    var list = q.isNotEmpty
        ? app.vocab.data.where((d) => d.key.contains(q) || (qp.isNotEmpty && d.key.contains(qp))).toList()
        : app.pool();
    if (app.weak) list = list.where((d) => app.lvl(d) < maxL).toList();
    final total = list.length;
    final shown = list.take(app.shown).toList();
    final L = app.level, u = app.unit;
    final label = q.isNotEmpty
        ? t.results(app.fmt(total), app.q)
        : '${u != 0 ? 'No. ${(u - 1) * 50 + 1}–${(u * 50).clamp(0, app.by(L).length)} · ' : ''}${t.words(app.fmt(total))}';
    final bottom = MediaQuery.paddingOf(context).bottom + 84;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top + 10)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Capsule(title: t.list, pickers: true),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      height: 42,
                      width: MediaQuery.sizeOf(context).width > 520 ? 320 : double.infinity,
                      child: Glass(
                        radius: 999,
                        child: TextField(
                          controller: _q,
                          onChanged: (v) {
                            app.q = v;
                            app.shown = 60;
                            app.changed();
                          },
                          style: F.s(14, c: p.fg),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: t.search,
                            hintStyle: F.s(14, c: p.mute),
                            prefixIcon: Padding(padding: const EdgeInsets.all(13), child: Icon2(I.search, size: 15, color: p.mute)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 40),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    _ToggleChip(
                      on: app.hide,
                      label: t.hide_,
                      icon: Icon2(I.eyeOff, size: 14, color: app.hide ? th.acc : p.soft),
                      onTap: () {
                        app.hide = !app.hide;
                        app.changed();
                      },
                    ),
                    _ToggleChip(
                      on: app.weak,
                      label: t.weak,
                      icon: Dot(p.sYellow),
                      onTap: () {
                        app.weak = !app.weak;
                        app.shown = 60;
                        app.changed();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text(label, style: F.s(12.5, c: p.soft)),
                ),
              ],
            ),
          ),
        ),
        if (total == 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(t.empty, textAlign: TextAlign.center, style: F.s(14, c: p.soft)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverLayoutBuilder(
              builder: (c, sc) {
                final cols = sc.crossAxisExtent >= 1100 ? 3 : (sc.crossAxisExtent >= 700 ? 2 : 1);
                if (cols == 1) {
                  return SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (c, i) => WordCard(shown[i], showLevel: q.isNotEmpty, hide: app.hide),
                  );
                }
                final rows = (shown.length / cols).ceil();
                return SliverList.builder(
                  itemCount: rows,
                  itemBuilder: (c, r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var k = 0; k < cols; k++) ...[
                            if (k > 0) const SizedBox(width: 10),
                            Expanded(
                              child: r * cols + k < shown.length
                                  ? WordCard(shown[r * cols + k], showLevel: q.isNotEmpty, hide: app.hide)
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (total > app.shown)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: GhostBtn(
                  t.more((total - app.shown).clamp(0, 60)),
                  onTap: () {
                    app.shown += 60;
                    app.changed();
                  },
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(child: _Foot(bottom: bottom)),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool on;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  const _ToggleChip({required this.on, required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    return Press(
      onTap: onTap,
      scale: 1.06,
      selected: on,
      label: label,
      child: Glass(
        radius: 999,
        height: 38,
        color: on ? th.acc.withValues(alpha: .12) : null,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(label, style: F.s(12.5, w: FontWeight.w700, c: on ? th.acc : th.p.soft)),
          ],
        ),
      ),
    );
  }
}

/// the tone legend and the data note under the list
class _Foot extends StatelessWidget {
  final double bottom;
  const _Foot({required this.bottom});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final t = app.t;
    const tones = [('妈', 'mā'), ('麻', 'má'), ('马', 'mǎ'), ('骂', 'mà'), ('吗', 'ma')];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 26, 16, bottom),
      child: Column(
        children: [
          Semantics(
            label: t.toneL,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 5; i++)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: tones[i].$1, style: F.s(14, w: FontWeight.w900, family: F.hz, c: p.t(i + 1))),
                        TextSpan(text: ' ${tones[i].$2} ${i < 4 ? t.tone(i + 1) : t.neutral}'),
                      ],
                    ),
                    style: F.s(12, c: p.soft),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(t.foot.replaceAll('{src}', 'hsk30'), textAlign: TextAlign.center, style: F.s(12, c: p.mute, h: 1.45)),
        ],
      ),
    );
  }
}

/// a run of word chips (summary, test results)
class WordChips extends StatelessWidget {
  final List<Word> words;
  const WordChips(this.words, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: p.fgA(.06), borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Hz(d, size: 16, weight: FontWeight.w900, family: F.hz),
                const SizedBox(width: 6),
                Flexible(child: Text(app.m1(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: F.s(12.5, c: p.fg))),
              ],
            ),
          ),
      ],
    );
  }
}

String langLabel(String l) => L10.text(app.texts[l]!.name);
