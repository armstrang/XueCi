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
  // ColorScheme.fromSeed works out whole tonal palettes: made once per theme and level colour, not on every change
  ThemeData? _th;
  (Pal, Color)? _thKey;
  ThemeData _theme(Pal p, Color acc) {
    if (_th != null && _thKey == (p, acc)) return _th!;
    _thKey = (p, acc);
    return _th = ThemeData(
      brightness: p.brightness,
      fontFamily: F.ui,
      fontFamilyFallback: F.fallback,
      colorScheme: ColorScheme.fromSeed(seedColor: acc, brightness: p.brightness, primary: acc),
      scaffoldBackgroundColor: p.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(cursorColor: acc, selectionHandleColor: acc),
    );
  }

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
          theme: _theme(p, acc),
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
                tick: app.tick,
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
    // hidden while answering: a session, the quiz, the tests, typing, an open menu, an exam
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
          body: BackdropGroup(
            child: Stack(
              children: [
                Positioned.fill(child: GlowBackground(tone: th.acc)),
                // the drifting glow only on the light theme: dark and true black keep the mockup's still, deep background
                if (th.full && !th.p.dark && !const ['session', 'placement', 'bt'].contains(s))
                  const Positioned.fill(child: DriftGlow()),
                Positioned.fill(
                  // only the new screen comes in (the old one leaves at once, so no two screens are drawn together):
                  // a short fade and rise, transform and opacity only
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    reverseDuration: Duration.zero,
                    layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, .012), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: RepaintBoundary(
                      key: ValueKey(s == 'list' || focusScreens.contains(s) ? 'f:$s' : s),
                      child: screenFor(s),
                    ),
                  ),
                ),
                if (tabs) const Positioned(left: 0, right: 0, bottom: 0, child: RepaintBoundary(child: TabBar2())),
                const Positioned(left: 0, right: 0, bottom: 0, child: RepaintBoundary(child: ToastHost())),
              ],
            ),
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

/// the tab bar: five tabs, each an icon over its name (iOS), a glass lens under the open one that springs to a new tab
/// and can be dragged
class TabBar2 extends StatelessWidget {
  const TabBar2({super.key});
  static const tabs = ['home', 'list', 'card', 'quiz', 'soul'];
  static const height = 64.0;
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final names = [t.tabHome, t.list, t.card, t.quiz, t.tabSoul];
    const icons = [I.home, I.list, I.cards, I.quiz, I.orb];
    final cur = tabs.indexOf(app.screen);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final w = MediaQuery.sizeOf(context).width;
    final barW = (w - 28).clamp(0, 440).toDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + 10),
      child: Center(
        child: Semantics(
          container: true,
          label: t.modesL,
          child: SizedBox(
            width: barW,
            height: height,
            child: Glass(
              radius: 999,
              frost: true,
              shadow: const [
                BoxShadow(color: Color.fromRGBO(0, 0, 0, .40), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -18),
                BoxShadow(color: Color.fromRGBO(0, 0, 0, .16), offset: Offset(0, 2), blurRadius: 8, spreadRadius: -4),
              ],
              child: Compact(
                max: 1.1,
                child: LensRow(
                  count: 5,
                  selected: cur < 0 ? -1 : cur,
                  height: height,
                  padding: const EdgeInsets.all(5),
                  onSelect: (i) => app.go(tabs[i]),
                  lens: (c, sel, drag) => sel < 0 ? const SizedBox() : TabLens(lc: th.acc),
                  item: (c, i, on) {
                    final col = on ? th.acc : p.soft;
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon2(icons[i], size: 23, color: col, width: on ? 2.1 : 1.9),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                names[i],
                                maxLines: 1,
                                style: F.s(10.5, w: on ? FontWeight.w800 : FontWeight.w600, c: col, ls: -.1),
                              ),
                            ),
                          ],
                        ),
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
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a),
              child: w,
            ),
          ),
          child: v == null
              ? const SizedBox(key: ValueKey(0))
              : Padding(
                  key: ValueKey(v.id),
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + (tabs ? 86 : 20)),
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
