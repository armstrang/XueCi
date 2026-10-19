/// The goal sheet (goal.js, reminder.js): the target (an HSK level by a date, the HSK exam, or none), the daily
/// amount (minutes, new words or automatic), the daily reminder (Android) and the meditation days.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/native.dart';
import '../engine/learn.dart';
import 'glass.dart';
import 'sheet.dart';
import 'theme.dart';
import 'widgets.dart';

const minChips = [5, 10, 15, 20, 30, 45, 60];
const newChips = [3, 5, 10, 15, 20, 30];

void openGoal(BuildContext context, bool first, [String? focus, int? minLv]) {
  openSheet(context, name: 'goal', (c) => _Goal(first: first, focus: focus, minLv: minLv)).then((_) {
    app.store.set('xc_onb', 1);
  });
}

class _Goal extends StatefulWidget {
  final bool first;
  final String? focus;
  final int? minLv;
  const _Goal({required this.first, this.focus, this.minLv});
  @override
  State<_Goal> createState() => _GoalState();
}

class _GoalState extends State<_Goal> {
  late Json g;
  late List<int> rest;
  late Map<String, dynamic> rem;
  final medKey = GlobalKey();
  bool notifOK = true;

  @override
  void initState() {
    super.initState();
    final lm = app.lm;
    final g0 = lm.goal;
    rest = [...lm.rest];
    g = g0 != null
        ? (json.decode(json.encode(g0)) as Map).cast<String, dynamic>()
        : {'t': 'level', 'lv': lm.curLevel(), 'date': LM.isoDay(lm.dayAfter(90)), 'pace': 'auto', 'n': 15};
    g['lv'] ??= lm.curLevel();
    if (widget.minLv != null && g['t'] != 'none' && (g['lv'] as num) < widget.minLv!) g['lv'] = widget.minLv;
    rem = {...app.rem};
    if (widget.first && app.canRemind && app.store.get('xc_rem', null) == null) rem['on'] = true;
    g['date'] ??= LM.isoDay(lm.dayAfter(90));
    g['n'] ??= g['pace'] == 'new' ? 10 : 15;
    if (app.canRemind) {
      Native.I.notifStatus().then((s) {
        if (mounted) setState(() => notifOK = s == 'granted' || s == 'unsupported');
      });
    }
    if (widget.focus == 'rest') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = medKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: .5);
      });
    }
  }

  Future<void> save() async {
    final t = app.t;
    final nav = Navigator.of(context);
    var msg = t.gSaved;
    if (rem['on'] == true && app.canRemind && !notifOK) {
      final ok = await Native.I.requestNotifications();
      if (!ok) {
        rem['on'] = false;
        msg = t.remDenied;
      }
    }
    app.rem = rem;
    app.store.set('xc_rem', rem);
    app.lm.setGoal(g);
    app.lm.setRest(rest);
    app.syncRest();
    app.runner.reset();
    app.changed();
    app.syncReminder();
    nav.pop();
    app.toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final lm = app.lm;
    final pl = lm.plan(g);
    final tgt = g['t'] != 'none';
    final bad = tgt && lm.daysTo(g['date'] as String) < 1;
    Widget seg(String k, Object v, String label, {Color? lc}) {
      final on = '${g[k]}' == '$v';
      return Expanded(
        child: _GSeg(
          label: label,
          on: on,
          color: lc,
          onTap: () => setState(() {
            g[k] = v;
            if (k == 't' && g['t'] == 'none' && g['pace'] == 'auto') {
              g['pace'] = 'new';
              g['n'] = 10;
            }
            if (k == 'pace' && g['pace'] != 'auto') {
              final n = g['n'];
              g['n'] = g['pace'] == 'min' ? (minChips.contains(n) ? n : 15) : (newChips.contains(n) ? n : 10);
            }
          }),
        ),
      );
    }

    Widget row(List<Widget> c) => Row(children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 6), c[i]]]);
    Widget sec(String label, List<Widget> c, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label.toUpperCase(), style: F.s(11.5, w: FontWeight.w800, c: p.soft, ls: .6)),
          ),
          ...c,
        ],
      ),
    );

    // the forecast line
    String fc;
    var cls = '';
    final fixes = <Widget>[];
    if (bad) {
      fc = t.gDateBad;
      cls = 'bad';
    } else if (pl.status == 'free') {
      fc = t.fcFree(pl.newPerDay, pl.minutes);
    } else if (pl.status == 'review') {
      fc = t.fcAllDone;
    } else if (pl.status == 'examweek') {
      fc = t.stExamWeek;
    } else if (pl.status == 'ok') {
      fc = t.fcOk(pl.newPerDay, pl.revPerDay, pl.minutes, pl.finish != null ? app.dateS(pl.finish!) : '–');
      cls = 'good';
    } else {
      fc = t.fcBehind(pl.finish != null ? app.dateS(pl.finish!) : null);
      cls = 'bad';
      if (g['pace'] != 'new' && pl.needMin != null) {
        fixes.add(GhostBtn(t.fcFixMin(pl.needMin), fontSize: 13, onTap: () => setState(() {
          g['pace'] = 'min';
          g['n'] = pl.needMin;
        })));
      }
      if (g['pace'] != 'min' && pl.need <= 60) {
        fixes.add(GhostBtn(t.fcFixNew(pl.need), fontSize: 13, onTap: () => setState(() {
          g['pace'] = 'new';
          g['n'] = pl.need;
        })));
      }
      if (pl.fixDate != null) {
        fixes.add(GhostBtn(t.fcFixDate(app.dateS(pl.fixDate!)), fontSize: 13, onTap: () => setState(() => g['date'] = LM.isoDay(pl.fixDate!))));
      }
    }
    final chips = g['pace'] == 'min' ? minChips : newChips;
    final list = chips.contains(g['n']) ? chips : ([...chips, (g['n'] as num).toInt()]..sort());
    final fcBg = cls == 'good'
        ? Color.alphaBlend(p.good.withValues(alpha: .13), p.surface)
        : cls == 'bad'
        ? Color.alphaBlend(p.bad.withValues(alpha: .12), p.surface)
        : p.fgA(.06);
    final dt = DateTime.parse(g['date'] as String);
    return SheetBody(
      title: t.gT,
      children: [
        Text(t.gLead, style: F.s(13.5, c: p.soft, h: 1.45)),
        if (widget.first && lm.lvInfo == null && lm.canTest())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Press(
              onTap: () {
                Navigator.of(context).pop();
                app.go('placement');
              },
              scale: .98,
              label: t.ptSuggest,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(color: th.acc.withValues(alpha: .09), borderRadius: BorderRadius.circular(14), border: Border.all(color: th.acc.withValues(alpha: .55))),
                child: Rich(t.ptSuggest, style: F.s(13.5, w: FontWeight.w600, c: p.fg, h: 1.4)),
              ),
            ),
          ),
        sec(t.gWhat, [row([seg('t', 'level', t.gLevel), seg('t', 'exam', t.gExam), seg('t', 'none', t.gNone)])]),
        if (tgt) ...[
          sec(t.gLv, [
            for (var r0 = 0; r0 < app.vocab.levels.length; r0 += 6)
              Padding(
                padding: EdgeInsets.only(top: r0 > 0 ? 6 : 0),
                child: row([
                  for (var i = r0; i < r0 + 6; i++)
                    if (i < app.vocab.levels.length)
                      seg('lv', app.vocab.levels[i], 'HSK ${app.vocab.levels[i]}', lc: p.l(app.vocab.levels[i]))
                    else
                      const Expanded(child: SizedBox()),
                ]),
              ),
          ]),
          sec(g['t'] == 'exam' ? t.gDateExam : t.gDate, [
            Press(
              onTap: () async {
                final first = lm.dayAfter(1);
                final d = await showDatePicker(
                  context: context,
                  firstDate: first,
                  lastDate: DateTime(first.year + 6),
                  initialDate: dt.isBefore(first) ? first : dt,
                );
                if (d != null) setState(() => g['date'] = LM.isoDay(d));
              },
              scale: .99,
              label: '${g['t'] == 'exam' ? t.gDateExam : t.gDate}: ${app.dateS(dt)}',
              child: Glass(
                solid: true,
                radius: 13,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(alignment: Alignment.centerLeft, child: Text(app.dateS(dt), style: F.s(15, c: p.fg))),
              ),
            ),
          ]),
        ],
        sec(t.gPace, [
          row([seg('pace', 'min', t.gMin), seg('pace', 'new', t.gNew), if (tgt) seg('pace', 'auto', t.gAuto)]),
          if (g['pace'] != 'auto')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final n in list)
                    _GSeg(
                      label: g['pace'] == 'min' ? t.gMinN(n) : t.gNewN(n),
                      on: g['n'] == n,
                      pill: true,
                      onTap: () => setState(() => g['n'] = n),
                    ),
                ],
              ),
            ),
        ]),
        Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: fcBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Rich(fc, style: F.s(13.5, c: p.fg, h: 1.45)),
                if (fixes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: Wrap(spacing: 6, runSpacing: 6, children: fixes)),
              ],
            ),
          ),
        ),
        if (app.canRemind)
          sec(t.remT, [
            Row(
              children: [
                Expanded(flex: 4, child: _GSeg(label: t.remOn, on: rem['on'] == true, onTap: () => setState(() => rem['on'] = true))),
                const SizedBox(width: 6),
                Expanded(flex: 4, child: _GSeg(label: t.remOff, on: rem['on'] != true, onTap: () => setState(() => rem['on'] = false))),
                const SizedBox(width: 6),
                Expanded(
                  flex: 5,
                  child: Opacity(
                    opacity: rem['on'] == true ? 1 : .45,
                    child: _GSeg(
                      label: '${'${rem['h']}'.padLeft(2, '0')}:${'${rem['m']}'.padLeft(2, '0')}',
                      on: false,
                      onTap: rem['on'] != true
                          ? null
                          : () async {
                              final tm = await showTimePicker(context: context, initialTime: TimeOfDay(hour: rem['h'] as int, minute: rem['m'] as int));
                              if (tm != null) {
                                setState(() {
                                  rem['h'] = tm.hour;
                                  rem['m'] = tm.minute;
                                });
                              }
                            },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Rich(t.remNote, style: F.s(12, c: p.soft, h: 1.45)),
                  if (app.rem['on'] == true && rem['on'] == true && !notifOK)
                    GestureDetector(
                      onTap: Native.I.openNotifSettings,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
                        child: Text(t.remOpen, style: F.s(12, w: FontWeight.w800, c: th.acc).copyWith(decoration: TextDecoration.underline, decorationColor: th.acc)),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        sec(t.medT, key: medKey, [
          row([
            for (final w in App.wk)
              Expanded(
                child: Semantics(
                  label: app.wkName(w, long: true),
                  child: ExcludeSemantics(
                    child: _GSeg(
                      label: app.wkName(w),
                      on: rest.contains(w),
                      onTap: () => setState(() {
                        if (rest.contains(w)) {
                          rest.remove(w);
                        } else {
                          rest.add(w);
                          if (rest.length > 2) rest.removeAt(0);
                        }
                      }),
                    ),
                  ),
                ),
              ),
          ]),
          Padding(padding: const EdgeInsets.only(top: 8), child: Rich(t.medNote, style: F.s(12, c: p.soft, h: 1.45))),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GhostBtn(widget.first ? t.gSkip : t.cancel, onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 8),
            GhostBtn(t.gSave, pri: true, onTap: bad ? null : save),
          ],
        ),
      ],
    );
  }
}

class _GSeg extends StatelessWidget {
  final String label;
  final bool on;
  final Color? color;
  final bool pill;
  final VoidCallback? onTap;
  const _GSeg({required this.label, required this.on, this.color, this.pill = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final c = color ?? th.acc;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: Press(
        onTap: onTap,
        scale: .96,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 40),
          padding: pill ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7) : const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          alignment: pill ? null : Alignment.center,
          decoration: BoxDecoration(
            color: on ? c : p.surface.withValues(alpha: p.dark ? .5 : .75),
            borderRadius: BorderRadius.circular(pill ? 999 : 13),
            border: Border.all(color: on ? Colors.transparent : p.gEdge),
          ),
          child: ExcludeSemantics(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: F.s(13, w: FontWeight.w700, c: on ? p.onAcc : p.fg, h: 1.25),
            ),
          ),
        ),
      ),
    );
  }
}
