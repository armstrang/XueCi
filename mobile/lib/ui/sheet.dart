/// Sheets: frosted glass from the bottom (a centred card on wide screens), a title row
/// with a close button, the back button closes them.
library;


import 'package:flutter/material.dart';

import '../app/app.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';

Future<T?> openSheet<T>(BuildContext context, Widget Function(BuildContext) body, {bool dismissible = true, String? name}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: app.t.close,
    barrierColor: const Color.fromRGBO(8, 10, 16, .34),
    transitionDuration: const Duration(milliseconds: 280),
    routeSettings: RouteSettings(name: name),
    // the route sits under the app's Th (MaterialApp.builder), so a theme change mid-sheet shows at once
    pageBuilder: (c, a1, a2) => _SheetFrame(
      child: ListenableBuilder(listenable: app, builder: (c, _) => Builder(builder: body)),
    ),
    transitionBuilder: (c, a, _, child) {
      final wide = MediaQuery.sizeOf(c).width >= 600;
      final e = const Cubic(.2, .9, .25, 1).transform(a.value);
      if (wide) {
        return Opacity(opacity: a.value, child: Transform.scale(scale: .92 + .08 * e, child: child));
      }
      return FractionalTranslation(translation: Offset(0, 1 - e), child: child);
    },
  );
}

class _SheetFrame extends StatelessWidget {
  final Widget child;
  const _SheetFrame({required this.child});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 600;
    final r = wide ? BorderRadius.circular(32) : const BorderRadius.vertical(top: Radius.circular(32));
    Widget box = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: mq.size.height * (wide ? .9 : .92)),
      child: Glass(
        frost: true,
        borderRadius: r,
        radius: 32,
        shadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .35), offset: Offset(0, -20), blurRadius: 60, spreadRadius: -24)],
        child: ClipRRect(borderRadius: r, child: child),
      ),
    );
    return Align(
      alignment: wide ? Alignment.center : Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: wide ? 0 : mq.viewInsets.bottom),
        child: Material(type: MaterialType.transparency, child: box),
      ),
    );
  }
}

/// the usual sheet body: title row, scrolling content
class SheetBody extends StatelessWidget {
  final String? title;
  final Widget? titleW;
  final List<Widget> children;
  final Widget? lead;
  final EdgeInsets padding;
  final bool close;
  final ScrollController? controller;
  const SheetBody({
    super.key,
    this.title,
    this.titleW,
    required this.children,
    this.lead,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.close = true,
    this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || titleW != null || close)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
            child: Row(
              children: [
                if (lead != null) ...[lead!, const SizedBox(width: 10)],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: titleW ?? Text(title ?? '', style: F.s(19, w: FontWeight.w800, c: p.fg, h: 1.25)),
                  ),
                ),
                if (close) CloseBtn(onTap: () => Navigator.of(context).maybePop()),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            controller: controller,
            padding: padding + EdgeInsets.only(bottom: bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ],
    );
  }
}

class CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const CloseBtn({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Th.pal(context);
    return Press(
      onTap: onTap,
      scale: 1.06,
      label: app.t.close,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Glass(
            radius: 999,
            width: 36,
            height: 36,
            child: Center(child: Icon2(I.close, size: 16, color: p.fg)),
          ),
        ),
      ),
    );
  }
}

/// a lead paragraph in a sheet
class Lead extends StatelessWidget {
  final String text;
  const Lead(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: F.s(14, c: Th.pal(context).soft, h: 1.45)),
  );
}
