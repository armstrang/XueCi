/// Settings (settings.js, language.js), the cultivation-days sheet, the short tour and the easter egg.
/// Everything that left the header and Home lives in Settings: theme, visual effects, study language, goal, backup,
/// research code, help and privacy.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app/app.dart';
import '../app/native.dart';
import '../i18n/l10.dart';
import 'glass.dart';
import 'home.dart' show Incense;
import 'icons.dart';
import 'lens.dart' show LensPill;
import 'backup_sheet.dart';
import 'sheet.dart';
import 'stats.dart' show openResearch;
import 'theme.dart';
import 'widgets.dart';

const privacyUrl = 'https://armstrang.github.io/XueCi/privacy/';

// ---------------------------------------------------------------- shared pieces
/// a group of rows with a small caps heading
class SGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SGroup(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: F.s(12, w: FontWeight.w800, c: p.soft, ls: .7),
              ),
            ),
          ),
          // one glass for the group, hairlines between the rows
          Glass(
            radius: 22,
            solid: true,
            child: GlassFlat(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        child: Container(height: 1, color: p.fgA(p.dark ? .08 : .07)),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// a settings row: icon, title (and a line under it), a chevron
class SRow extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String? sub;
  final Widget? subW;
  final String chev;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SRow({
    super.key,
    this.icon,
    required this.title,
    this.sub,
    this.subW,
    this.chev = '›',
    this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Press(
      onTap: onTap,
      scale: .985,
      label: sub != null ? '$title, $sub' : title,
      child: Glass(
        solid: true,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: F.s(15, w: FontWeight.w700, c: p.fg, h: 1.3),
                    ),
                    if (subW != null) subW! else if (sub != null) Text(sub!, style: F.s(12.5, c: p.soft, h: 1.35)),
                  ],
                ),
              ),
              ?trailing,
              const SizedBox(width: 8),
              Text(chev, style: F.s(18, c: p.mute, h: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// a segmented choice (theme, effects)
class Seg extends StatelessWidget {
  final List<(String, String, Widget?)> options; // value, label, icon
  final String value;
  final void Function(String) onPick;
  final String? label;
  const Seg({super.key, required this.options, required this.value, required this.onPick, this.label});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: p.fgA(.06), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            for (final (v, l, ic) in options)
              Expanded(
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: v == value,
                  button: true,
                  label: l,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPick(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedOpacity(
                              opacity: v == value ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const LensPill(),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minHeight: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            alignment: Alignment.center,
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (ic != null) ...[ic, const SizedBox(width: 5)],
                                  Flexible(
                                    child: Text(
                                      l,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: F.s(13, w: FontWeight.w700, c: v == value ? p.fg : p.soft, h: 1.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String bkDate(int ms) => DateFormat.yMMMMd(app.intlLoc).format(DateTime.fromMillisecondsSinceEpoch(ms));
String bkLastLine() {
  final a = app.bkAge();
  return a == null ? app.t.bkNever : app.t.bkLast(bkDate(app.bkLastAt()), a);
}

// ---------------------------------------------------------------- Settings
void openSettings(BuildContext context) {
  openSheet(context, name: 'settings', (c) => const _Settings());
}

class _Settings extends StatefulWidget {
  const _Settings();
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool langOpen = false;

  /// rows that open another sheet or screen close Settings first, so sheets never stack
  void from(VoidCallback f) {
    final nav = Navigator.of(context);
    final ctx = nav.context;
    nav.pop();
    Future.microtask(() {
      if (ctx.mounted) f();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final ctx = Navigator.of(context).context;
    final themeIc = {'auto': I.themeAuto, 'light': I.themeLight, 'dark': I.themeDark, 'black': I.themeBlack};
    final due = app.bkDue();
    return SheetBody(
      title: t.setT,
      children: [
        SGroup(t.setLook, [
          Glass(
            solid: true,
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.theme,
                  style: F.s(15, w: FontWeight.w700, c: p.fg),
                ),
                const SizedBox(height: 8),
                Seg(
                  label: t.theme,
                  value: app.theme,
                  options: [
                    for (final k in themes)
                      (k, L10.text(t.th[k]), Icon2(themeIc[k]!, size: 15, color: k == app.theme ? p.fg : p.soft)),
                  ],
                  onPick: (v) {
                    if (v != app.theme) app.setTheme(v);
                  },
                ),
              ],
            ),
          ),
          Glass(
            solid: true,
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.fxT,
                  style: F.s(15, w: FontWeight.w700, c: p.fg),
                ),
                const SizedBox(height: 8),
                Seg(
                  label: t.fxT,
                  value: app.fxPref,
                  options: [for (final k in fxModes) (k, L10.text(t.fxM[k]), null)],
                  onPick: (v) {
                    if (v != app.fxPref) app.setFx(v);
                  },
                ),
                const SizedBox(height: 8),
                Text(t.fxNote(app.fxPref, app.fxDetect()), style: F.s(12.5, c: p.soft, h: 1.4)),
              ],
            ),
          ),
        ]),
        SGroup(t.langHead, [
          SRow(
            icon: Icon2(I.globe, size: 22, color: th.acc),
            title: t.name,
            sub: app.langPref == 'auto' ? t.auto : null,
            trailing: Text(app.lang.toUpperCase(), style: F.s(13, c: p.soft)),
            chev: langOpen ? '⌄' : '›',
            onTap: () => setState(() => langOpen = !langOpen),
          ),
          if (langOpen)
            Glass(
              solid: true,
              radius: 18,
              padding: const EdgeInsets.all(4),
              child: _LangList(onPick: () => setState(() => langOpen = false)),
            ),
        ]),
        SGroup(t.setStudy, [
          SRow(
            icon: Icon2(I.target, size: 22, color: th.acc),
            title: t.setGoalT,
            sub: app.goalChip(),
            onTap: () => from(() => app.openGoal?.call(ctx, false)),
          ),
        ]),
        SGroup(t.setData, [
          SRow(
            icon: Icon2(I.sync, size: 22, color: due ? p.sYellow : th.acc),
            title: t.bkBtn,
            sub: bkLastLine(),
            onTap: () => from(() => openBackup(ctx)),
          ),
          SRow(
            icon: Icon2(I.flask, size: 22, color: th.acc),
            title: t.rsT,
            onTap: () => from(openResearch),
          ),
        ]),
        SGroup(t.setHelp, [
          SRow(
            icon: Icon2(I.tour, size: 22, color: th.acc),
            title: t.tourRow,
            onTap: () => from(() => openTour(ctx, false)),
          ),
          SRow(
            icon: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '妈',
                    style: TextStyle(color: p.t(1)),
                  ),
                  TextSpan(
                    text: '骂',
                    style: TextStyle(color: p.t(4)),
                  ),
                ],
              ),
              style: F.s(15, w: FontWeight.w900, family: F.hz, h: 1.4),
            ),
            title: t.infoBtn,
            onTap: () => from(() => app.openInfo?.call(ctx, null)),
          ),
          SRow(
            icon: Icon2(I.shield, size: 22, color: th.acc),
            title: t.privacy,
            chev: '↗',
            onTap: () => Native.I.openUrl(privacyUrl),
          ),
        ]),
      ],
    );
  }
}

class _LangList extends StatelessWidget {
  final VoidCallback onPick;
  const _LangList({required this.onPick});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final sl = app.sysLang();
    Widget row(String code, Widget lead, String name, String? sub) {
      final on = app.langPref == code;
      return Semantics(
        selected: on,
        button: true,
        label: sub != null ? '$name, $sub' : name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            onPick();
            if (!on) app.setLang(code);
          },
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: on ? th.acc.withValues(alpha: .12) : null,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: on ? th.acc : p.sunk, borderRadius: BorderRadius.circular(8)),
                    child: DefaultTextStyle(
                      style: F.s(11.5, w: FontWeight.w800, c: on ? p.onAcc : p.soft, ls: .5),
                      child: lead,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: F.s(14.5, w: FontWeight.w700, c: p.fg, h: 1.25),
                        ),
                        if (sub != null) Text(sub, style: F.s(11.5, c: p.soft, h: 1.25)),
                      ],
                    ),
                  ),
                  if (on) Icon2(I.check, size: 16, color: th.acc),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        row(
          'auto',
          Icon2(I.device, size: 15, color: app.langPref == 'auto' ? p.onAcc : p.soft),
          t.auto,
          app.texts[sl]!.name,
        ),
        Container(height: 1, color: p.line, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8)),
        for (final l in const ['id', 'en', 'th', 'vi'])
          Builder(
            builder: (c) {
              final own = app.texts[l]!.name;
              final loc = L10.text(t.names[l]);
              return row(l, Text(l.toUpperCase()), own, loc != own ? loc : null);
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- cultivation days
/// the longest run: the same rules as LM.streak (practice counts, a meditation weekday and one free day a week keep it)
int bestRun(Set<int> s) {
  final all = s.toList()..sort();
  if (all.isEmpty) return 0;
  final lm = app.lm;
  var best = 0;
  for (var i = 0; i < all.length; i++) {
    if (i > 0 && s.contains(all[i] - 1)) continue;
    var d = all[i], n = 0, grace = -99;
    final end = lm.today();
    for (; d <= end; d++) {
      if (s.contains(d) || lm.isRest(d)) {
        n++;
      } else if (grace == -99 || d - grace >= 7) {
        grace = d;
        n++;
      } else {
        break;
      }
    }
    while (n > 0 && !s.contains(d - 1) && d - 1 >= all[i]) {
      d--;
      n--;
    }
    if (n > best) best = n;
  }
  return best;
}

void openStreak(BuildContext context) {
  openSheet(context, name: 'streak', (c) {
    final p = Th.pal(c);
    final t = app.t;
    final lm = app.lm;
    final s = lm.streak();
    final days = lm.studyDays();
    final today = lm.today();
    final wd = lm.weekday(today);
    final start = today - wd - 28;
    final best = bestRun(days);
    Widget cell(String cls, {bool now = false, String text = '', double size = 0}) {
      final done = cls == 'done', rest = cls == 'rest', fut = cls == 'fut';
      return Opacity(
        opacity: fut ? .35 : 1,
        child: Container(
          width: size > 0 ? size : null,
          height: size > 0 ? size : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || fut ? null : (rest ? p.l(2).withValues(alpha: .22) : p.fgA(.05)),
            gradient: done
                ? const LinearGradient(
                    begin: Alignment(-.3, -1),
                    end: Alignment(.3, 1),
                    colors: [Color(0xfff2a15c), Color(0xffd9573a)],
                  )
                : null,
            border: now ? Border.all(color: p.fg, width: 2) : null,
          ),
          child: text.isEmpty
              ? null
              : Text(
                  text,
                  style: F.s(12.5, w: FontWeight.w700, c: done ? Colors.white : (rest ? p.fg : p.soft)),
                ),
        ),
      );
    }

    return SheetBody(
      title: t.strkT,
      children: [
        Row(
          children: [
            Incense(lit: s.today, size: 52),
            const SizedBox(width: 12),
            Text(
              app.fmt(s.days),
              style: F.s(40, w: FontWeight.w800, c: p.fg, h: 1, feat: F.tab),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                t.streakU(s.days),
                style: F.s(15, w: FontWeight.w700, c: p.soft),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            s.today ? t.strkToday : t.strkNot,
            style: F.s(14, w: s.today ? FontWeight.w700 : FontWeight.w400, c: s.today ? p.good : p.soft),
          ),
        ),
        Semantics(
          image: true,
          label: t.strkT,
          child: ExcludeSemantics(
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final w in t.strkWd)
                  Center(
                    child: Text(
                      L10.text(w),
                      style: F.s(11, w: FontWeight.w800, c: p.mute),
                    ),
                  ),
                for (var d = start; d <= today - wd + 6; d++)
                  cell(
                    d > today ? 'fut' : (days.contains(d) ? 'done' : (lm.isRest(d) ? 'rest' : '')),
                    now: d == today,
                    text: '${lm.dayDate(d).day}',
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final (cls, i) in const [('done', 0), ('rest', 1), ('now', 3)])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cell(cls == 'now' ? '' : cls, now: cls == 'now', size: 14),
                    const SizedBox(width: 6),
                    Text(L10.text(t.strkKey[i]), style: F.s(12, c: p.soft)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(t.strkLead, style: F.s(13.5, c: p.soft, h: 1.45)),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            t.strkBest(app.fmt(best > s.days ? best : s.days)),
            style: F.s(13, w: FontWeight.w700, c: p.fg),
          ),
        ),
      ],
    );
  });
}

// ---------------------------------------------------------------- the short tour
void openTour(BuildContext context, bool first) {
  var toGoal = false;
  openSheet(
    context,
    name: 'tour',
    dismissible: false,
    (c) => _Tour(first: first, onGoal: () => toGoal = true),
  ).then((_) {
    if (first) {
      app.store.set('xc_onb', 1);
      if (toGoal && context.mounted) app.openGoal?.call(context, true);
    }
  });
}

class _Tour extends StatefulWidget {
  final bool first;
  final VoidCallback onGoal;
  const _Tour({required this.first, required this.onGoal});
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final steps = t.tour;
    final step = steps[i] as List;
    final last = i == steps.length - 1;
    final art = switch (i) {
      0 => Text(
        '金丹',
        style: F.s(28, w: FontWeight.w900, family: F.hz, c: p.gold),
      ),
      1 => Icon2(I.play, size: 34, color: th.acc),
      _ => Text(
        'HSK',
        style: F.s(26, w: FontWeight.w800, c: th.acc),
      ),
    };
    return SheetBody(
      close: false,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < steps.length; k++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: k == i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(color: k == i ? th.acc : p.fgA(.18), borderRadius: BorderRadius.circular(4)),
              ),
          ],
        ),
        Center(
          child: Container(
            width: 96,
            height: 96,
            margin: const EdgeInsets.only(top: 18, bottom: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: th.acc.withValues(alpha: .14)),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-.32, -.68),
                  radius: 1.1,
                  colors: [Color.fromRGBO(255, 255, 255, .6), Color.fromRGBO(255, 255, 255, 0)],
                  stops: [0, .52],
                ),
              ),
              child: ExcludeSemantics(child: art),
            ),
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            L10.text(step[0]),
            textAlign: TextAlign.center,
            style: F.s(20, w: FontWeight.w800, c: p.fg, h: 1.3),
          ),
        ),
        const SizedBox(height: 8),
        Rich(
          L10.text(step[1]),
          align: TextAlign.center,
          style: F.s(14, c: p.soft, h: 1.5),
          boldColor: p.fg,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GhostBtn(
                last && widget.first ? t.tourLater : t.tourSkip,
                wide: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MainBtn(
                last ? (widget.first ? t.tourGoal : t.tourDone) : t.tourNext,
                wide: true,
                onTap: () {
                  if (!last) {
                    setState(() => i++);
                  } else {
                    widget.onGoal();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- the easter egg
/// seven taps on the wordmark within 2.5 s: a vermilion seal stamps 天外有天 (封 before the seal opens, 开 after)
final List<int> _eggTaps = [];
void eggTap(BuildContext context) {
  final now = DateTime.now().millisecondsSinceEpoch;
  _eggTaps.removeWhere((x) => now - x >= 2500);
  _eggTaps.add(now);
  if (_eggTaps.length < 7) return;
  _eggTaps.clear();
  HapticFeedback.mediumImpact();
  app.note['egg'] = ((app.note['egg'] as num?) ?? 0) + 1;
  app.saveNote();
  final open = app.band;
  final t = app.t;
  Timer? tm;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: t.close,
    barrierColor: const Color.fromRGBO(14, 10, 8, .9),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (c, a, _) {
      tm ??= Timer(const Duration(milliseconds: 5200), () {
        if (c.mounted) Navigator.of(c).maybePop();
      });
      return GestureDetector(
        onTap: () => Navigator.of(c).maybePop(),
        child: Semantics(
          label: '天外有天 · ${t.eggM}',
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.16),
                radius: .75,
                colors: [Color.fromRGBO(120, 24, 18, .55), Color.fromRGBO(120, 24, 18, 0)],
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      margin: const EdgeInsets.only(bottom: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3261E),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: sh(const [BoxShadow(color: Color.fromRGBO(179, 38, 30, .5), blurRadius: 40)]),
                      ),
                      child: Text(
                        open ? '开' : '封',
                        style: F.s(64, w: FontWeight.w900, family: F.hz, c: const Color(0xFFFFF4EA), h: 1),
                      ),
                    ),
                    Text(
                      '天外有天',
                      style: F.s(40, w: FontWeight.w900, family: F.hz, c: const Color(0xFFF3D9A0), ls: 4.8),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text('tiān wài yǒu tiān', style: F.s(14, c: const Color(0xFFE8DCCB), ls: .6)),
                    ),
                    Text(
                      t.eggM,
                      textAlign: TextAlign.center,
                      style: F.s(16, w: FontWeight.w700, c: const Color(0xFFF6EFE4)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      open ? t.eggOpen : t.eggSealed,
                      textAlign: TextAlign.center,
                      style: F.s(13.5, c: const Color(0xFFD9CFC0)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (c, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 1.15, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  ).then((_) => tm?.cancel());
}
