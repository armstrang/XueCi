/// The backup sheet (backup.js): back up (a code to copy or share) or restore (paste a code, check it, apply it).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app.dart';
import '../app/backup.dart';
import '../app/native.dart';
import 'glass.dart';
import 'icons.dart';
import 'settings.dart' show bkDate, bkLastLine;
import 'sheet.dart';
import 'theme.dart';
import 'widgets.dart';

void openBackup(BuildContext context) {
  openSheet(context, name: 'backup', (c) => const _Backup());
}

class _Backup extends StatefulWidget {
  const _Backup();
  @override
  State<_Backup> createState() => _BackupState();
}

class _BackupState extends State<_Backup> {
  String mode = 'menu'; // menu make restore
  final code = TextEditingController();
  Restore? pending;
  String msg = '';
  bool bad = false;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  void show(String m) {
    mode = m;
    pending = null;
    msg = '';
    bad = false;
    code.text = m == 'make' ? makeCode(app) : '';
  }

  void say(String m, [bool b = false]) => setState(() {
    msg = m;
    bad = b;
  });

  Future<void> copy() async {
    if (code.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code.text));
    app.bkNoted();
    app.toast(app.t.bkCopied);
  }

  Future<void> share() async {
    if (code.text.isEmpty) return;
    final title = app.t.bkShareText(bkDate(app.nowMs()));
    if (await Native.I.shareText('$title:\n${code.text}')) app.bkNoted();
  }

  Future<void> paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = d?.text ?? '';
    if (txt.isNotEmpty) {
      setState(() {
        code.text = txt;
        pending = null;
        msg = '';
      });
    }
  }

  Future<void> check() async {
    final t = app.t;
    final b = await readCode(app, code.text);
    if (!mounted) return;
    if (b == null) {
      say(t.bkBad, true);
      return;
    }
    setState(() {
      pending = b;
      msg = t.bkConfirm(app.fmt(app.practisedN(b.stats)), bkDate(b.at), app.fmt(app.practisedN()));
      bad = false;
    });
  }

  Future<void> apply() async {
    final b = pending;
    if (b == null) return;
    final nav = Navigator.of(context);
    if (await applyCode(app, b)) {
      nav.pop();
      app.toast(app.t.bkDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final menu = mode == 'menu', make = mode == 'make';
    final title = menu ? t.bkT : (make ? t.bkTitleMake : t.bkTitleRestore);
    final lead = menu ? t.bkNote : (make ? t.bkLeadMake(app.fmt(app.practisedN())) : t.bkLeadRestore);
    Widget opt(Ic ic, String b, String sub, String to) => Press(
      onTap: () => setState(() => show(to)),
      scale: .98,
      label: '$b, $sub',
      child: Glass(
        solid: true,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: th.acc.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
              child: Icon2(ic, size: 20, color: th.acc),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b, style: F.s(15, w: FontWeight.w800, c: p.fg)),
                  Text(sub, style: F.s(12.5, c: p.soft, h: 1.35)),
                ],
              ),
            ),
            Text('›', style: F.s(18, c: p.mute)),
          ],
        ),
      ),
    );
    final due = app.bkDue();
    // back: from a code view to the two choices, then close
    return PopScope(
      canPop: menu,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => show('menu'));
      },
      child: SheetBody(
      titleW: Text(title, style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25)),
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(lead, style: F.s(13.5, c: p.soft, h: 1.45))),
        if (menu) ...[
          opt(I.upload, t.bkMake, t.bkMakeSub, 'make'),
          const SizedBox(height: 8),
          opt(I.download, t.bkRestore, t.bkRestoreSub, 'restore'),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
            child: Row(
              children: [
                if (due) ...[Dot(p.sYellow, size: 7), const SizedBox(width: 7)],
                Expanded(
                  child: Text(
                    bkLastLine(),
                    style: F.s(12.5, w: due ? FontWeight.w700 : FontWeight.w400, c: due ? p.soft : p.mute, h: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            decoration: BoxDecoration(
              color: p.sunk,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.gEdge),
            ),
            child: TextField(
              controller: code,
              readOnly: make,
              minLines: 4,
              maxLines: 7,
              autocorrect: false,
              enableSuggestions: false,
              style: F.s(12, c: p.fg, h: 1.45, family: 'monospace'),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: make ? null : 'XUECI1:…',
                hintStyle: F.s(12, c: p.mute),
              ),
              onChanged: (_) {
                if (pending != null || msg.isNotEmpty) {
                  setState(() {
                    pending = null;
                    msg = '';
                  });
                }
              },
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(msg, style: F.s(13, c: bad ? p.bad : p.soft, h: 1.45)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: make
                ? [
                    GhostBtn(t.bkCopy, onTap: copy),
                    if (Native.I.isAndroid) GhostBtn(t.bkShare, pri: true, onTap: share),
                  ]
                : pending != null
                ? [
                    GhostBtn(t.cancel, onTap: () => setState(() {
                      pending = null;
                      msg = '';
                    })),
                    _Danger(t.bkApply, onTap: apply),
                  ]
                : [GhostBtn(t.bkPaste, onTap: paste), GhostBtn(t.bkCheck, pri: true, onTap: check)],
          ),
        ],
      ],
    ),
    );
  }
}

class _Danger extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Danger(this.label, {required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Press(
      onTap: onTap,
      scale: 1.04,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: p.bad, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: F.s(14, w: FontWeight.w800, c: p.onAcc)),
      ),
    );
  }
}
