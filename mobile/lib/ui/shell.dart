/// The frame of the app: theme, background, the screen of the moment, the tab bar, toasts, the back button.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app/app.dart';
import '../app/native.dart';
import 'exam.dart';
import 'fx.dart';
import 'glass.dart';
import 'hskk.dart';
import 'home.dart';
import 'icons.dart';
import 'lens.dart';
import 'qi.dart';
import 'screens.dart';
import 'splash.dart';
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
    app.addListener(app.syncBgm);
    app.syncBgm();
  }

  @override
  void dispose() {
    app.removeListener(app.syncBgm);
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
  String? _shown;
  // the opening plays once, on a start that opens on Home
  late bool _splash = splashOn && app.screen == 'home';

  void _on() => setState(() {});

  @override
  void initState() {
    super.initState();
    app.addListener(_on);
    // before Home is built, so its pieces start hidden
    splashT.value = _splash ? 0 : splashDone;
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
        // the tour, the goal sheet or a welcome wait until the opening is over
        if (!_splash) startTasks(context);
      });
    }
    final s = app.screen;
    if (s != _shown) {
      // ink washes across as the new screen comes in (not on the first one, not between questions)
      if (_shown != null && !_splash) qiSweep(th.p.dark ? Colors.white : const Color(0xff1b1d27));
      _shown = s;
    }
    final kb = MediaQuery.viewInsetsOf(context).bottom > 80;
    // hidden while answering: a session, the quiz, the tests, typing, an open menu, an exam
    final tabs = !const ['session', 'placement', 'bt', 'hkrun'].contains(s) && !kb && !app.menuOpen && !app.inExam;
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
                // qi in the air (storm clouds during a tribulation); not in an HSK simulation
                if (!app.inExam) const Positioned.fill(child: QiField()),
                Positioned.fill(
                  // only the new screen comes in (the old one leaves at once, so no two screens are drawn together):
                  // a short fade and rise, transform and opacity only
                  child: AnimatedSwitcher(
                    duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
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
                if (tabs) const Positioned(left: 0, right: 0, bottom: 0, child: Rise(4, child: RepaintBoundary(child: TabBar2()))),
                const Positioned(left: 0, right: 0, bottom: 0, child: RepaintBoundary(child: ToastHost())),
                const Positioned.fill(child: QiOver()),
                if (_splash)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Splash(
                        onDone: () {
                          if (!mounted) return;
                          setState(() => _splash = false);
                          startTasks(context);
                        },
                      ),
                    ),
                  ),
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
  'hskk' => const HskkScreen(),
  'exam' => const ExamScreen(),
  'hkrun' => const HkRunScreen(),
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

/// the tab bar (v1.4, like Gala's): a frosted capsule with HSK (Home with List, Cards and Quiz), HSKK (speaking) and
/// Tests, each an icon over its name with a glass lens under the open one; beside it, apart, a round orb for the Soul
/// Sea in the realm's colour, breathing slowly
class TabBar2 extends StatelessWidget {
  const TabBar2({super.key});
  static const tabs = ['home', 'hskk', 'exam'];
  static const height = 64.0;

  /// the tab a screen belongs to (List, Cards and Quiz live under HSK)
  static int tabOf(String s) => switch (s) {
    'home' || 'list' || 'card' || 'quiz' => 0,
    'hskk' => 1,
    'exam' => 2,
    _ => -1,
  };

  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final p = th.p;
    final t = app.t;
    final names = [t.tabHsk, t.tabHskk, t.tabExam];
    const icons = [I.cards, I.mic, I.qExam];
    final cur = tabOf(app.screen);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final w = MediaQuery.sizeOf(context).width;
    final barW = (w - 28).clamp(0, 460).toDouble();
    const shadow = [
      BoxShadow(color: Color.fromRGBO(0, 0, 0, .40), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -18),
      BoxShadow(color: Color.fromRGBO(0, 0, 0, .16), offset: Offset(0, 2), blurRadius: 8, spreadRadius: -4),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + 10),
      child: Center(
        child: SizedBox(
          width: barW,
          height: height,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label: t.modesL,
                  child: Glass(
                    radius: 999,
                    frost: true,
                    shadow: shadow,
                    child: Compact(
                      max: 1.1,
                      child: LensRow(
                        count: tabs.length,
                        selected: cur,
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
              const SizedBox(width: 10),
              const SoulOrbButton(size: height),
            ],
          ),
        ),
      ),
    );
  }
}

/// the round Soul Sea button beside the tab bar: a small black hole whose disk runs through the realm's colour, gold,
/// violet and blue, turning slowly on the shared clock (qi.dart); brighter and ringed when the Soul Sea is open
class SoulOrbButton extends StatelessWidget {
  final double size;
  const SoulOrbButton({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) {
    final th = Th.of(context);
    final on = app.screen == 'soul';
    // light effects, "remove animations" or no clock: the same picture, standing still
    final still = th.low || !qiOn || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Press(
      onTap: () {
        if (on) {
          app.scrollTop++;
          app.changed();
        } else {
          app.go('soul');
        }
      },
      scale: .92,
      label: app.t.tabSoul,
      selected: on,
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: Glass(
            radius: 999,
            frost: true,
            shadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .38), offset: Offset(0, 16), blurRadius: 34, spreadRadius: -16)],
            child: Center(
              child: CustomPaint(
                size: Size.square(size * .84),
                painter: BlackHolePainter(th.rc, th.p.gold, on, still),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A black hole in a dark round window: a black core with a thin bright rim, a tilted disk of light around it (the far
/// half behind the core, the near half in front), and the light bent over the top and under the bottom of the core.
/// The colours of the disk run round it and turn once in about 14 seconds; nothing else moves.
class BlackHolePainter extends CustomPainter {
  final Color c, gold;
  final bool on, still;
  BlackHolePainter(this.c, this.gold, this.on, this.still) : super(repaint: still ? null : qiT);

  static const _violet = Color(0xffa070ff), _blue = Color(0xff4cc9f0), _pink = Color(0xffff6fb0);

  @override
  void paint(Canvas canvas, Size s) {
    final R = s.width / 2;
    final o = Offset(R, R);
    final t = still ? .9 : qiT.value;
    final turn = t * 2 * math.pi / 14;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: R)));
    // the window: deep space
    canvas.drawCircle(
      o,
      R,
      Paint()..shader = const RadialGradient(colors: [Color(0xff1a0f33), Color(0xff08050f)]).createShader(Rect.fromCircle(center: o, radius: R)),
    );
    // a faint glow of the realm's colour around the hole
    canvas.drawCircle(
      o,
      R * .95,
      Paint()..shader = RadialGradient(colors: [c.withValues(alpha: on ? .42 : .3), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: R * .95)),
    );

    canvas.translate(o.dx, o.dy);
    canvas.rotate(-.42); // the disk is tilted
    final rx = R * .84, ry = R * .2, core = R * .4;
    final ring = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    // a paint's colour alpha does not touch its shader, so the dimmer layer gets a shader of its own
    Shader sweepOf(double a) => SweepGradient(
      transform: GradientRotation(turn),
      colors: [for (final k in [Colors.white, gold, c, _violet, _blue, _pink, gold, Colors.white]) k.withValues(alpha: a)],
      stops: const [0, .12, .3, .5, .66, .8, .93, 1],
    ).createShader(ring);
    final bright = sweepOf(1), soft = sweepOf(on ? .42 : .3);
    Paint disk(double w, Shader sh) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..shader = sh
      ..isAntiAlias = true;
    final path = Path()..addOval(ring);
    void drawDisk() {
      canvas.drawPath(path, disk(R * .3, soft)); // soft body: the glow of the gas
      canvas.drawPath(path, disk(R * .13, bright)); // the hot band
    }

    // the far half of the disk, behind the core
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-R, -R, R, 0));
    drawDisk();
    canvas.restore();

    // the core, with a thin warm rim (the photon ring)
    canvas.drawCircle(Offset.zero, core, Paint()..color = const Color(0xff020104));
    canvas.drawCircle(
      Offset.zero,
      core,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * .03
        ..color = Color.lerp(gold, Colors.white, .55)!.withValues(alpha: .8),
    );

    // light bent over the top and under the bottom of the core: arcs that fade out towards both ends
    final lens = Rect.fromCircle(center: Offset.zero, radius: core * 1.13);
    final warm = Color.lerp(gold, Colors.white, .5)!;
    void arc(double from, double alpha, double width) {
      canvas.drawArc(
        lens,
        from,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [warm.withValues(alpha: 0), warm.withValues(alpha: alpha), warm.withValues(alpha: 0)]).createShader(lens),
      );
    }

    arc(-math.pi, .95, R * .08);
    arc(0, .45, R * .06);

    // the near half of the disk, in front of the core
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-R, 0, R, R));
    drawDisk();
    canvas.restore();
    canvas.restore();

    // the Soul Sea is open: a ring in the realm's colour
    if (on) {
      canvas.drawCircle(
        o,
        R - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = c,
      );
    } else {
      canvas.drawCircle(
        o,
        R - .5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: .2),
      );
    }
  }

  @override
  bool shouldRepaint(BlackHolePainter o) => o.c != c || o.gold != gold || o.on != on || o.still != still;
}

/// toasts: a frosted capsule above the tab bar
class ToastHost extends StatelessWidget {
  const ToastHost({super.key});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tabs = !const ['session', 'placement', 'bt', 'hkrun'].contains(app.screen);
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
