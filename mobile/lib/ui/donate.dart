/// 护法: the donation sheet (the coin next to Settings, and once per realm after a breakthrough). Donations go through
/// Google Play Billing (Native.donProducts / donBuy, Donate.kt), unlock nothing, and are only counted on the phone
/// (App.donAdd, xc_dn). Off Google Play the sheet says so instead of showing prices.
library;

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/native.dart';
import 'glass.dart';
import 'sheet.dart';
import 'theme.dart';
import 'widgets.dart';

void openDonate(BuildContext context) => openSheet(context, name: 'donate', (c) => const _Donate());

class _Donate extends StatefulWidget {
  const _Donate();
  @override
  State<_Donate> createState() => _DonateState();
}

class _DonateState extends State<_Donate> {
  Map<String, String>? prices; // id → price in the phone's currency
  bool loading = true, busy = false;
  String? msg; // ok | pending | error

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Native.I.donProducts(App.donIds);
    if (!mounted) return;
    if (r != null && r.done > 0) app.donAdd(r.done);
    setState(() {
      loading = false;
      prices = r == null ? null : {for (final e in r.items) e.id: e.price};
    });
  }

  Future<void> _buy(String id) async {
    if (busy) return;
    setState(() {
      busy = true;
      msg = null;
    });
    final r = await Native.I.donBuy(id);
    if (!mounted) return;
    if (r == 'ok') app.donAdd(1);
    setState(() {
      busy = false;
      msg = r == 'cancel' ? null : r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final tiers = t.dnTier;
    Widget tier(int i) {
      final id = App.donIds[i];
      final price = prices?[id];
      final row = tiers.length > i ? tiers[i] as List : const ['', ''];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Press(
          onTap: price == null || busy ? null : () => _buy(id),
          scale: .98,
          label: '${row[1]}, ${price ?? ''}',
          child: Tile(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text('${row[0]}', style: F.s(17, w: FontWeight.w900, family: F.hz, c: p.gold)),
                ),
                Expanded(
                  child: Text('${row[1]}', style: F.s(14.5, w: FontWeight.w700, c: p.fg)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: th.acc, borderRadius: BorderRadius.circular(999)),
                  child: Text(price ?? '…', style: F.s(13.5, w: FontWeight.w800, c: p.onAcc, feat: F.tab)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final note = switch (msg) {
      'ok' => t.dnThanks,
      'pending' => t.dnPending,
      'error' => t.dnErr,
      _ => null,
    };
    return SheetBody(
      titleW: Text(t.dnT, style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25)),
      children: [
        Lead(t.dnLead),
        Lead(t.dnUse),
        const SizedBox(height: 4),
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(t.dnLoad, textAlign: TextAlign.center, style: F.s(13.5, c: p.soft)),
          )
        else if (prices == null)
          Tile(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Text(t.dnNone, style: F.s(13.5, c: p.soft, h: 1.45)),
          )
        else
          for (var i = 0; i < App.donIds.length; i++) tier(i),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(note, textAlign: TextAlign.center, style: F.s(14, w: FontWeight.w700, c: msg == 'error' ? p.bad : p.good, h: 1.4)),
          ),
        if (app.patron && msg != 'ok')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(t.dnCount(app.fmt(app.donN)), textAlign: TextAlign.center, style: F.s(13, w: FontWeight.w700, c: p.gold)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(t.dnFree, textAlign: TextAlign.center, style: F.s(12, c: p.mute, h: 1.4)),
        ),
      ],
    );
  }
}

/// the quiet invitation on a passed breakthrough (once per realm, never after the placement test or at the gate)
class DonateAsk extends StatelessWidget {
  final int realm;
  const DonateAsk(this.realm, {super.key});
  @override
  Widget build(BuildContext context) {
    if (!app.donAskOnce(realm)) return const SizedBox.shrink();
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Press(
        onTap: () => app.openDonate?.call(context),
        scale: .98,
        label: '${t.dnAsk} ${t.dnAskBtn}',
        child: Tile(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Text('护', style: F.s(18, w: FontWeight.w900, family: F.hz, c: p.gold)),
              const SizedBox(width: 10),
              Expanded(child: Text(t.dnAsk, style: F.s(13, c: p.soft, h: 1.4))),
              const SizedBox(width: 8),
              Text('${t.dnAskBtn} ›', style: F.s(13, w: FontWeight.w800, c: th.acc)),
            ],
          ),
        ),
      ),
    );
  }
}

/// a small 护法 seal for donors (Soul Sea, under the realm)
class PatronBadge extends StatelessWidget {
  const PatronBadge({super.key});
  @override
  Widget build(BuildContext context) {
    if (!app.patron) return const SizedBox.shrink();
    final p = Th.pal(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        label: app.t.dnT,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: p.gold.withValues(alpha: .7), width: 1.2),
          ),
          child: Text('护法', style: F.s(12.5, w: FontWeight.w900, family: F.hz, c: p.gold, ls: 2)),
        ),
      ),
    );
  }
}
