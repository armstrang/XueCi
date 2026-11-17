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

/// A black hole seen from the front, in a round window of deep space: a black core with a bright, glowing ring, and
/// thick soft clouds (pink, lavender, violet, mint) winding in towards it with thin streaks of light between them,
/// like a storm being pulled into the hole. Everything turns together (once in about 8 seconds) and the clouds drift
/// slowly inwards; the ring glows and breathes. No lightning.
class BlackHolePainter extends CustomPainter {
  final Color c, gold;
  final bool on, still;
  BlackHolePainter(this.c, this.gold, this.on, this.still) : super(repaint: still ? null : qiT);

  static const _pink = Color(0xffff5fa8), _lav = Color(0xffc49bff), _violet = Color(0xff7a46e6), _mint = Color(0xff4fe3b4);
  static const _blue = Color(0xff4f86ff), _amber = Color(0xffff9a3c), _cream = Color(0xffffe9d0);

  @override
  void paint(Canvas canvas, Size s) {
    final R = s.width / 2;
    final o = Offset(R, R);
    final t = still ? .9 : qiT.value;
    final turn = t * 2 * math.pi / 8;
    final core = R * .34;
    final lit = on ? 1.0 : .82;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: o, radius: R)));
    // the window: deep space, the realm's colour faint round the hole
    canvas.drawCircle(
      o,
      R,
      Paint()..shader = const RadialGradient(colors: [Color(0x66351670), Color(0x520c0626)]).createShader(Rect.fromCircle(center: o, radius: R)),
    );
    canvas.drawCircle(
      o,
      R * .75,
      Paint()..shader = RadialGradient(colors: [c.withValues(alpha: on ? .22 : .14), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: R * .75)),
    );
    // stars
    final star = Paint();
    for (var i = 0; i < 14; i++) {
      final f = (i * .618034) % 1;
      final a = i * 2.399963 - turn * .6;
      star.color = Colors.white.withValues(alpha: (.3 + .5 * ((i * 7) % 5) / 4) * (.55 + .45 * math.sin(t * 3.1 + i * 1.7)));
      canvas.drawCircle(o + Offset(math.cos(a), math.sin(a)) * (R * (.5 + .46 * f)), R * (.012 + .014 * ((i * 3) % 4) / 3), star);
    }

    // where a spiral arm is: [k] the arm, [r] the radius; clouds and streaks wind in the same way
    double ang(int k, double r, [double off = 0]) => -turn + k * math.pi / 2 + 2.3 * math.log(R * 1.05 / r) + off;
    Offset at(int k, double r, [double off = 0]) {
      final a = ang(k, r, off);
      return o + Offset(math.cos(a), math.sin(a)) * r;
    }

    // thick clouds: soft round puffs along each arm, big outside and smaller inside, drifting slowly inwards
    const arms = [
      [_pink, _lav],
      [_lav, _violet],
      [_mint, _blue],
      [_violet, _pink],
    ];
    final puff = Paint()..isAntiAlias = true;
    const per = 14;
    for (var k = 0; k < 4; k++) {
      for (var i = 0; i < per; i++) {
        final f0 = (i / per + t * .035 + k * .013) % 1; // 0 rim → 1 core
        final r = R * 1.02 - (R * 1.02 - core * 1.18) * f0;
        final wob = math.sin(i * 2.1 + k * 1.3 + t * .9);
        final at1 = at(k, r, wob * .13);
        final rad = R * (.12 + .34 * (1 - f0)) * (1 + .22 * wob);
        final col = Color.lerp(arms[k][i.isEven ? 0 : 1], _cream, math.pow(f0, 2.2).toDouble() * .55)!;
        final a = (math.sin(math.pi * f0) * .95 + .05) * (.62 + .12 * wob) * lit;
        puff.shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: a * .55), col.withValues(alpha: 0)], stops: const [0, .55, 1])
            .createShader(Rect.fromCircle(center: at1, radius: rad));
        canvas.drawCircle(at1, rad, puff);
      }
    }

    // thin streaks of light winding in between the clouds
    Path streak(int k, double off) {
      final path = Path();
      for (var i = 0; i <= 22; i++) {
        final r = R * 1.02 - (R * 1.02 - core * 1.1) * (i / 22);
        final q = at(k, r, off);
        i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      return path;
    }

    for (var k = 0; k < 4; k++) {
      for (final off in [-.2, .22]) {
        canvas.drawPath(
          streak(k, off),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = R * .016
            ..strokeCap = StrokeCap.round
            ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .85 * lit), Color.lerp(arms[k][0], Colors.white, .5)!.withValues(alpha: .22 * lit), Colors.white.withValues(alpha: 0)], stops: const [.3, .62, 1])
                .createShader(Rect.fromCircle(center: o, radius: R)),
        );
      }
    }

    // the ring of light round the hole: a wide soft glow, a hot band and a thin white edge; brightest on one side,
    // which travels round
    final ringR = core * 1.07;
    final hot = turn * 1.3;
    Shader ringSweep(double a) => SweepGradient(
      transform: GradientRotation(-hot),
      colors: [Colors.white.withValues(alpha: a), _amber.withValues(alpha: a * .95), _pink.withValues(alpha: a * .75), _violet.withValues(alpha: a * .5), _amber.withValues(alpha: a * .85), Colors.white.withValues(alpha: a)],
      stops: const [0, .14, .4, .66, .88, 1],
    ).createShader(Rect.fromCircle(center: o, radius: ringR));
    final pulse = 1 + .14 * math.sin(t * 2.4);
    canvas.drawCircle(
      o,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * .26 * pulse
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, R * .08)
        ..shader = ringSweep(.8 * lit),
    );
    canvas.drawCircle(
      o,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * .1 * pulse
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, R * .025)
        ..shader = ringSweep(1),
    );
    // the core, with a thin white edge
    canvas.drawCircle(o, core, Paint()..color = const Color(0xf2060210));
    canvas.drawCircle(
      o,
      core * 1.01,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = R * .03
        ..shader = ringSweep(1),
    );
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
