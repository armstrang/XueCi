/// The frame of the app: theme, background, the screen of the moment, the tab bar, toasts, the back button.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/app.dart';
import '../app/native.dart';
import 'fx.dart';
import 'glass.dart';
import 'home.dart';
import 'icons.dart';
import 'lens.dart';
import 'screens.dart';
import 'theme.dart';

final navKey = GlobalKey<NavigatorState>();

class XueCiApp extends StatefulWidget {
  const XueCiApp({super.key});
  @override
  State<XueCiApp> createState() => _XueCiAppState();
}

class _XueCiAppState extends State<XueCiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    wireSheets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (app.langPref == 'auto' && app.sysLang() != app.lang) app.setLang('auto', silent: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive || s == AppLifecycleState.hidden) {
      app.lm.pause();
      app.store.flush();
    }
    if (s == AppLifecycleState.resumed) {
      Native.I.ttsStatus().then((_) => app.changed());
      app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final p = palFor(app.theme, platform);
        final acc = p.l(app.level);
        final r = app.lm.realm();
        return MaterialApp(
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          title: 'XueCi Mandarin',
          locale: Locale(app.lang),
          supportedLocales: const [Locale('id'), Locale('en'), Locale('th'), Locale('vi')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: p.brightness,
            fontFamily: F.ui,
            fontFamilyFallback: F.fallback,
            colorScheme: ColorScheme.fromSeed(seedColor: acc, brightness: p.brightness, primary: acc),
            scaffoldBackgroundColor: p.bg,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            textSelectionTheme: TextSelectionThemeData(cursorColor: acc, selectionHandleColor: acc),
          ),
          builder: (c, child) {
            final mq = MediaQuery.of(c);
            final fs = mq.textScaler.scale(1).clamp(.85, 1.6);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(fs)),
              child: Th(
                p: p,
                acc: acc,
                rc: p.realm(r, band: app.band),
                low: app.fx == 'low',
                full: app.fx == 'full',
                fs: fs,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: (p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarDividerColor: Colors.transparent,
                    systemNavigationBarContrastEnforced: false,
                  ),
                  child: child!,
                ),
              ),
            );
          },
          home: const Shell(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _readySent = false;

  void _on() => setState(() {});

  @override
  void initState() {
    super.initState();
    app.addListener(_on);
  }

  @override
  void dispose() {
    app.removeListener(_on);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    if (!_readySent) {
      _readySent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Native.I.ready();
        startTasks(context);
      });
    }
    final s = app.screen;
    final kb = MediaQuery.viewInsetsOf(context).bottom > 80;
    final tabs = !const ['session', 'placement', 'bt'].contains(s) && !kb && !app.menuOpen && !app.inExam;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) {
        if (!did) back(context);
      },
      child: Listener(
        onPointerDown: (_) => fxWake.value++,
        child: Scaffold(
        backgroundColor: th.p.bg,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: GlowBackground(tone: th.acc)),
            if (th.full && !const ['session', 'placement', 'bt'].contains(s)) const Positioned.fill(child: DriftGlow()),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, ?cur]),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: .985, end: 1.0).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(s == 'list' || focusScreens.contains(s) ? 'f:$s' : s), child: screenFor(s)),
              ),
            ),
            if (tabs) const Positioned(left: 0, right: 0, bottom: 0, child: TabBar2()),
            const Positioned(left: 0, right: 0, bottom: 0, child: ToastHost()),
          ],
        ),
      ),
      ),
    );
  }
}

Widget screenFor(String s) => switch (s) {
  'home' => const HomeScreen(),
  'stats' => const StatsScreenHost(),
  'soul' => const SoulScreenHost(),
  _ => FocusScreenHost(mode: s),
};

/// Android's back button: an open sheet closes first (the navigator), then the screen goes back; on Home the app
/// leaves.
void back(BuildContext context) {
  if (app.backHook != null && app.backHook!()) return;
  if (app.screen == 'home') {
    SystemNavigator.pop();
    return;
  }
  app.go(app.screen == 'stats' ? app.prevScreen : 'home');
}

/// the tab bar (v1.16): five tabs, icons only except the open one, a glass lens under it that can be dragged
class TabBar2 extends StatelessWidget {
  const TabBar2({super.key});
  static const tabs = ['home', 'list', 'card', 'quiz', 'soul'];
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final names = [t.tabHome, t.list, t.card, t.quiz, t.tabStats];
    final icons = [I.home, I.list, I.cards, I.star, I.flame];
    final cur = tabs.indexOf(app.screen);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final w = MediaQuery.sizeOf(context).width;
    final barW = (w - 40).clamp(0, 430).toDouble();
    final h = 54.0;
    Color colOf(int i) => i == 4 ? p.elFire : th.acc;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + 10),
      child: Center(
        child: Semantics(
          container: true,
          label: t.modesL,
          child: SizedBox(
            width: barW,
            height: h,
            child: Glass(
              radius: 999,
              frost: true,
              shadow: const [
                BoxShadow(color: Color.fromRGBO(0, 0, 0, .45), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -18),
                BoxShadow(color: Color.fromRGBO(0, 0, 0, .2), offset: Offset(0, 2), blurRadius: 8, spreadRadius: -4),
              ],
              child: Compact(
                max: 1.12,
                child: LensRow(
                  count: 5,
                  selected: cur < 0 ? -1 : cur,
                  height: h,
                  onSelect: (i) => app.go(tabs[i]),
                  widths: (total, sel) {
                    if (sel < 0) return List.filled(5, total / 5);
                    final big = (total * .34).clamp(0, 140).toDouble().clamp(total / 5, total);
                    final rest = (total - big) / 4;
                    return [for (var k = 0; k < 5; k++) k == sel ? big : rest];
                  },
                  lens: (c, sel, drag) => sel < 0 ? const SizedBox() : TabLens(lc: colOf(sel)),
                  item: (c, i, on) {
                    final col = on ? colOf(i) : p.fg.withValues(alpha: .88);
                    return Press(
                      onTap: () {
                        if (app.screen == tabs[i]) {
                          app.scrollTop++;
                          app.changed();
                        } else {
                          app.go(tabs[i]);
                        }
                      },
                      scale: .9,
                      label: names[i],
                      selected: on,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon2(icons[i], size: 22, color: col),
                          if (on) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                names[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: F.s(13, w: FontWeight.w800, c: col),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// toasts: a frosted capsule above the tab bar
class ToastHost extends StatelessWidget {
  const ToastHost({super.key});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tabs = !const ['session', 'placement', 'bt'].contains(app.screen);
    return ValueListenableBuilder(
      valueListenable: app.toastV,
      builder: (c, v, _) => IgnorePointer(
        ignoring: v == null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (w, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: w),
          ),
          child: v == null
              ? const SizedBox(key: ValueKey(0))
              : Padding(
                  key: ValueKey(v.id),
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + (tabs ? 76 : 20)),
                  child: GestureDetector(
                    onTap: () => app.toastV.value = null,
                    child: Semantics(
                      liveRegion: true,
                      child: Glass(
                        radius: v.ms > 2000 ? 22 : 999,
                        frost: true,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text(
                          v.msg,
                          textAlign: TextAlign.center,
                          style: F.s(14, w: FontWeight.w600, c: Th.pal(c).fg, h: 1.35),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// work after the first frame: the tour or the goal sheet on a first start, a welcome back, the model fit
void startTasks(BuildContext context) {
  Timer(const Duration(seconds: 6), app.maybeOptimize);
  for (final f in app.startHooks) {
    f(context);
  }
}
