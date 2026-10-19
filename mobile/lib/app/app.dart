/// The app's state and its services, in one place (the WebView app kept these as globals: state.js, core.js,
/// boot.js, language.js, screens.js). Widgets listen to [app] and rebuild when it changes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../data/seal.dart';
import '../data/store.dart';
import '../data/words.dart';
import '../engine/fsrs.dart' as fsrs;
import '../engine/js.dart';
import '../engine/learn.dart';
import '../i18n/l10.dart';
import 'mastery.dart';
import 'native.dart';
import 'runner.dart';

late App app;

/// screens: home, list, card, quiz, session, placement, bt, stats, soul
const focusScreens = ['list', 'card', 'quiz', 'session', 'placement', 'bt'];
const themes = ['auto', 'light', 'dark', 'black'];
const fxModes = ['auto', 'low', 'full'];
const qTypes = ['auto', 'm', 'f', 's', 'l', 'c', 'p', 't', 'exam', 'mock'];

class App extends ChangeNotifier {
  final Store store;
  final Vocab vocab;
  late LM lm;
  final Map<String, L10> texts;
  final AssetBundle bundle;
  String langPref;
  String lang;

  App._(this.store, this.vocab, this.texts, this.bundle, this.langPref, this.lang);

  L10 get t => texts[lang]!;

  // ---------------------------------------------------------------- start
  /// Opens the store (moving v1.x progress over on the first start), loads the words and the text, opens the
  /// sealed part when its time has come, and starts the engine.
  static Future<App> boot({
    KvBackend? backend,
    Map<String, String>? legacy,
    AssetBundle? assets,
    JsRandom? random,
    int Function()? clock,
    int? tzOffset,
    String? sysLang,
  }) async {
    final bundle = assets ?? rootBundle;
    KvBackend be;
    if (backend != null) {
      be = backend;
    } else {
      final dir = await Native.I.filesDir();
      be = dir != null ? FileBackend(Directory('$dir/store')) : MemoryBackend();
    }
    final store = Store(be);
    final saved = be.loadAll();
    var leg = legacy;
    if (leg == null && backend == null && !saved.containsKey('xc_schema')) leg = await Native.I.legacy();
    store.open(legacy: leg);

    final texts = <String, L10>{};
    for (final l in langs) {
      texts[l] = L10.fromJson(l, await bundle.loadString('assets/i18n/$l.json'));
    }
    final pref0 = store.get('mm_lang', 'auto');
    final pref = pref0 is String && (pref0 == 'auto' || langs.contains(pref0)) ? pref0 : 'auto';
    final lang = pref == 'auto' ? (sysLang ?? _sysLang()) : pref;

    final core = json.decode(await bundle.loadString('assets/data/core.json')) as Map;
    final cols = (core['cols'] as List).cast<String>();
    final words = [for (final r in core['rows'] as List) Word.row(cols, r as List)];
    final vocab = Vocab(words, lang: lang);
    await _addLang(bundle, words, lang, '');
    vocab.loaded.add(lang);
    final lv = store.get('xc_lvl', null);
    final gate = lv is Map && jsTruthy(lv['gate']);
    final a = App._(store, vocab, texts, bundle, pref, lang);
    if (gate) await a._openBand();
    store.migrate({...vocab.data.map((d) => d.id), ...a._bandIdsCache});
    a.lm = LM(store, vocab, random: random, clock: clock, tzOffset: tzOffset);
    await a._init();
    return a;
  }

  static String _sysLang([List<String>? list]) {
    for (final n in list ?? Native.I.sysLangs()) {
      final c = n.toLowerCase().length >= 2 ? n.toLowerCase().substring(0, 2) : n.toLowerCase();
      if (c == 'id' || c == 'in' || c == 'ms') return 'id';
      if (c == 'en' || c == 'th' || c == 'vi') return c;
    }
    return 'en';
  }

  String sysLang() => _sysLang();

  static Future<void> _addLang(AssetBundle b, List<Word> words, String l, String part) async {
    Map j;
    if (part.isEmpty) {
      j = json.decode(await b.loadString('assets/data/$l.json')) as Map;
    } else {
      j = unseal((await b.load('assets/data/s-$l.bin')).buffer.asUint8List(), 's-$l.bin', _hsk6) as Map;
    }
    final rows = j['rows'] as List;
    if (rows.length != words.length) throw StateError('$l$part does not match the word list');
    for (var i = 0; i < rows.length; i++) {
      words[i].m[l] = rows[i][0] as String;
      words[i].t[l] = rows[i][1] as String;
    }
  }

  static String _hsk6 = '';

  // ---------------------------------------------------------------- the sealed part (HSK 7–9)
  bool get band => vocab.band;
  List<Word> _bandWords = [];
  Set<String> _bandIdsCache = {};
  Map<String, dynamic> sealedX = {};

  Future<void> _openBand() async {
    if (vocab.band) return;
    _hsk6 = vocab.data.where((d) => d.l == 6).map((d) => d.h).join();
    final pk = unseal((await bundle.load('assets/data/s0.bin')).buffer.asUint8List(), 's0.bin', _hsk6) as Map;
    final c = pk['core'] as Map;
    final cols = (c['cols'] as List).cast<String>();
    _bandWords = [for (final r in c['rows'] as List) Word.row(cols, r as List)];
    for (final l in vocab.loaded) {
      await _addLang(bundle, _bandWords, l, '-b');
    }
    sealedX = (pk['x'] as Map).cast<String, dynamic>();
    final i18n = (sealedX['i18n'] as Map).cast<String, dynamic>();
    for (final l in langs) {
      texts[l]!.addSealed((i18n[l] as Map?)?.cast<String, dynamic>());
    }
    rn.addAll((sealedX['rn'] as List).cast<String>());
    rpy.addAll((sealedX['rpy'] as List).cast<String>());
    rs.addAll((sealedX['rs'] as List).cast<String>());
    vocab.add(_bandWords);
    vocab.band = true;
    _bandIdsCache = _bandWords.map((d) => d.id).toSet();
  }

  /// the gate opened (a breakthrough to 飞升): HSK 7–9 join every index
  Future<void> openBand() async {
    if (vocab.band) return;
    await _openBand();
    lm.bandAdded();
    notifyListeners();
  }

  /// the ids of the sealed words, without adding them (checking a backup code from a learner past the gate)
  Future<Set<String>> bandIds() async {
    if (_bandIdsCache.isNotEmpty) return _bandIdsCache;
    final h6 = vocab.data.where((d) => d.l == 6).map((d) => d.h).join();
    final pk = unseal((await bundle.load('assets/data/s0.bin')).buffer.asUint8List(), 's0.bin', h6) as Map;
    final c = pk['core'] as Map;
    final cols = (c['cols'] as List).cast<String>();
    final li = cols.indexOf('l'), hi = cols.indexOf('h');
    return {for (final r in c['rows'] as List) '${r[li]}:${r[hi]}'};
  }

  // ---------------------------------------------------------------- realms (境界)
  /// 0 凡人 not tested · 1–6 studying HSK 1–6 · 7 飞升. What lies beyond comes from the sealed part.
  final List<String> rn = ['凡人', '炼气', '筑基', '金丹', '元婴', '化神', '渡劫', '飞升'];
  final List<String> rpy = ['fánrén', 'liànqì', 'zhùjī', 'jīndān', 'yuányīng', 'huàshén', 'dùjié', 'fēishēng'];
  final List<String> rs = ['凡', '炼', '筑', '金', '元', '化', '渡', '飞'];
  static const sn = ['初期', '中期', '后期', '圆满'];
  static const spy = ['chūqī', 'zhōngqī', 'hòuqī', 'yuánmǎn'];
  int get topR => band ? 10 : 7;
  int realmLv(int r) => math.max(1, math.min(band ? 9 : 6, r));
  int realmPct(int r) {
    final st = lm.stage(r < 1 ? lm.baseLevel() : r);
    return st != null ? (math.min(1, st.share / 0.8) * 100).round() : 0;
  }

  String realmHSK(int r) => r < 1 ? '' : (lm.isFinal(r) ? 'HSK ${realmLv(r)} ✓' : 'HSK $r');

  /// weekdays Monday first (0 = Sunday, as JS getDay); names in the study language (4 Jan 2026 was a Sunday)
  static const wk = [1, 2, 3, 4, 5, 6, 0];
  String wkName(int w, {bool long = false}) => (long ? DateFormat.EEEE(intlLoc) : DateFormat.E(intlLoc)).format(DateTime(2026, 1, 4 + w));

  // ---------------------------------------------------------------- the screen state (state.js)
  int level = 1;
  Map<int, int> unitBy = {for (var l = 1; l <= 9; l++) l: 1};
  String q = '';
  int shown = 60;
  bool hide = false, weak = false;
  String screen = 'home';
  String prevScreen = 'home';
  String qType = 'auto';
  String theme = 'auto';
  String fxPref = 'auto';
  bool fxDown = false; // the frame watcher stepped down once (xc_fxd)
  Map<String, dynamic> note = {};

  int get unit => unitBy[level] ?? 0;
  void saveUI() => store.set('hsk16_ui', {
    'level': level,
    'unitBy': {for (final e in unitBy.entries) '${e.key}': e.value},
    'qt': qType,
  });
  void saveNote() => store.set('xc_note', note);

  Future<void> _init() async {
    final ui = store.get('hsk16_ui', {});
    if (ui is Map) {
      final l = ui['level'];
      if (l is num && vocab.levels.contains(l.toInt())) level = l.toInt();
      final ub = ui['unitBy'];
      if (ub is Map) {
        ub.forEach((k, v) {
          final kk = int.tryParse('$k');
          if (kk != null && v is num) unitBy[kk] = v.toInt();
        });
      }
      if (qTypes.contains(ui['qt'])) qType = ui['qt'] as String;
    }
    final th = store.get('hsk16_theme', null);
    theme = themes.contains(th) ? th as String : 'auto';
    final fx = store.get('xc_fx', 'auto');
    fxPref = fxModes.contains(fx) ? fx as String : 'auto';
    fxDown = jsTruthy(store.get('xc_fxd', 0));
    final n = store.get('xc_note', {});
    note = n is Map ? Map<String, dynamic>.from(n) : {};
    for (final l in langs) {
      await initializeDateFormatting(_intlLoc(l));
    }
    lm.ttsReady = () => ttsOK;
    loadRem();
    canRemind = Native.I.isAndroid;
    lm.saveStats();
  }

  // ---------------------------------------------------------------- mastery
  int lvl(Word d) {
    final e = lm.stats[d.id];
    return e != null && e[0] + e[1] > 0 ? e[2].toInt() : -1;
  }

  MSum summary(Iterable<Word> a) => summaryOf(a, lvl);
  List<Word> by(int l) => vocab.by[l] ?? const [];
  int masteredAll() => vocab.data.where((d) => lvl(d) >= maxL).length;

  List<Word> pool() => unit != 0 ? by(level).where((d) => d.u == unit).toList() : by(level);
  List<Word> unitItems(int u) => u != 0 ? by(level).where((d) => d.u == u).toList() : by(level);

  // ---------------------------------------------------------------- words in the study language
  String m(Word d) => vocab.mOf(d);
  String m1(Word d) => vocab.m1(d);
  String tr(Word d) => vocab.trOf(d);

  // ---------------------------------------------------------------- formatting (L10.loc)
  static String _intlLoc(String l) => switch (l) {
    'id' => 'id',
    'th' => 'th',
    'vi' => 'vi',
    _ => 'en',
  };
  String get intlLoc => _intlLoc(lang);
  String fmt(num n) => NumberFormat.decimalPattern(intlLoc).format(n);
  String fmt1(double x) {
    final f = NumberFormat.decimalPattern(intlLoc)..maximumFractionDigits = 1;
    return f.format(x);
  }

  String pctTxt(double p) {
    if (p > 0 && p < 10) {
      final f = NumberFormat.decimalPattern(intlLoc)..maximumFractionDigits = 1;
      return '${f.format(p)}%';
    }
    return '${fmt(p.floor())}%';
  }

  /// a date as on the screens: day and short month (with the year when it is not this year)
  String dateS(Object x) {
    DateTime d;
    if (x is String) {
      final p = x.split('-').map(int.parse).toList();
      d = DateTime(p[0], p[1], p[2]);
    } else {
      d = x as DateTime;
    }
    final now = lm.dayDate(lm.today());
    return (d.year == now.year ? DateFormat.MMMd(intlLoc) : DateFormat.yMMMd(intlLoc)).format(d);
  }

  /// minutes since 1 Jan 2026 UTC → the local calendar date
  DateTime tDate(num t) => lm.dayDate(lm.dayOf(t));

  // ---------------------------------------------------------------- level, unit, language, theme
  void setLevel(int l) {
    level = l;
    shown = 60;
    q = '';
    saveUI();
    runner.reset();
    notifyListeners();
  }

  void setUnit(int u) {
    unitBy[level] = u;
    shown = 60;
    saveUI();
    runner.reset();
    notifyListeners();
  }

  /// the study language: its word meanings load the first time it is chosen
  Future<bool> setLang(String pref, {bool silent = false}) async {
    final l = pref == 'auto' ? sysLang() : pref;
    if (!vocab.loaded.contains(l)) {
      try {
        await _addLang(bundle, vocab.data.where((d) => d.l <= 6).toList(), l, '');
        if (band) await _addLang(bundle, _bandWords, l, '-b');
        vocab.loaded.add(l);
      } catch (_) {
        toast(t.dataFail);
        return false;
      }
    }
    langPref = pref;
    store.set('mm_lang', pref);
    final changed = l != lang;
    lang = l;
    if (changed) {
      vocab.setLang(l);
      langChanged?.call();
    }
    notifyListeners();
    if (!silent) toast(pref == 'auto' ? '${t.auto} · ${t.name}' : t.name);
    return true;
  }

  VoidCallback? langChanged;
  VoidCallback? resetRun;

  void setTheme(String th) {
    if (!themes.contains(th)) th = 'auto';
    theme = th;
    store.set('hsk16_theme', th);
    notifyListeners();
    toast('${t.theme}: ${L10.text(t.th[th])}');
  }

  /// visual effects: low = no blur, no glow; full = the drifting light behind everything
  String get fx => fxPref == 'auto' ? fxDetect() : fxPref;
  int deviceCores = Platform.numberOfProcessors;
  bool lowRam = false;
  String fxDetect() {
    if (fxDown) return 'low';
    if (lowRam || deviceCores <= 4) return 'low';
    return 'full';
  }

  void setFx(String m) {
    fxPref = m;
    store.set('xc_fx', m);
    if (m == 'full') {
      store.remove('xc_fxd');
      fxDown = false;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- speech
  bool get ttsOK => Native.I.ttsState == 'ready';
  bool canSpeak() => Native.I.isAndroid || Native.off && _ttsTest;
  bool _ttsTest = false;
  set ttsTest(bool v) => _ttsTest = v;

  // ---------------------------------------------------------------- navigation
  final List<VoidCallback> beforeShow = [];
  late final Runner runner = Runner(this);
  void go(String s) {
    if (s == 'stats' && screen != 'stats') prevScreen = screen;
    for (final f in beforeShow) {
      f();
    }
    runner.reset();
    menuOpen = false;
    screen = s;
    scrollTop++;
    notifyListeners();
  }

  /// tapping the open tab again: back to the top
  int scrollTop = 0;

  // ---------------------------------------------------------------- toast
  final ValueNotifier<({String msg, int id, int ms})?> toastV = ValueNotifier(null);
  int _toastN = 0;
  Timer? _toastT;
  void toast(String msg, [int ms = 2000]) {
    _toastT?.cancel();
    toastV.value = (msg: msg, id: ++_toastN, ms: ms);
    _toastT = Timer(Duration(milliseconds: ms), () => toastV.value = null);
  }

  /// the engine fits its model to this learner now and then (in the background)
  void maybeOptimize() => lm.maybeOptimize(runner: (job) => Isolate.run(job));

  // ---------------------------------------------------------------- what the screens register (sheets live in the UI)
  void Function(BuildContext)? openStreak, openSettings, openRealm;
  void Function(BuildContext, String?)? openInfo;
  void Function(BuildContext, bool, [String?])? openGoal;
  void Function(BuildContext)? openShare;
  VoidCallback? onWordmark;

  /// the back button asks this first (a run or a test may want to warn); true = handled
  bool Function()? backHook;
  final List<void Function(BuildContext)> startHooks = [];
  bool menuOpen = false; // the quiz type menu is open: the tab bar steps aside
  bool inExam = false; // an HSK simulation is running: the tab bar steps aside
  bool sessionExtra = false;

  /// a brand-new learner: no test, no practice yet (Home shows two ways in instead of numbers)
  bool isNewbie() {
    final pt = lm.lvInfo?['pt'];
    return lm.realm() == 0 && lm.stats.isEmpty && !(pt is List && pt.isNotEmpty);
  }

  /// the goal in a few words (plan card chip, Settings)
  String goalChip() {
    final g = lm.goal;
    if (g == null) return t.planSet;
    if (g['t'] == 'none') return t.gNone;
    return g['t'] == 'exam' ? t.gExamChip(g['lv'], dateS(g['date'] as String)) : t.gLvChip(g['lv'], dateS(g['date'] as String));
  }

  String skName(String k) => switch (k) {
    'm' => t.skM,
    'f' => t.skF,
    _ => t.skS,
  };

  void startSession(bool extra) {
    sessionExtra = extra;
    go('session');
  }

  // ---------------------------------------------------------------- backup timing (xc_bk = ms since 1970, as v1.x)
  int nowMs() => lm.now() * 60000 + fsrs.epochMs;
  int practisedN([Map<String, List<num>>? st]) => (st ?? lm.stats).values.where((e) => e.length > 1 && e[0] + e[1] > 0).length;
  int bkLastAt() {
    final t = store.get('xc_bk', 0);
    return t is num && t.isFinite && t > 0 ? t.toInt() : 0;
  }

  int? bkAge() {
    final t = bkLastAt();
    return t > 0 ? ((nowMs() - t) / 864e5).floor() : null;
  }

  /// worth a reminder: some real progress, and no backup yet or the last one is over a month old (a quiet dot)
  bool bkDue() {
    final a = bkAge();
    return practisedN() >= 30 && (a == null || a > 30);
  }

  void bkNoted() {
    store.set('xc_bk', nowMs());
    notifyListeners();
  }

  // ---------------------------------------------------------------- daily reminder (Android)
  bool canRemind = false;
  Map<String, dynamic> rem = {'on': false, 'h': 19, 'm': 0};
  void loadRem() {
    final r = store.get('xc_rem', {});
    if (r is Map) {
      rem = {'on': r['on'] == true, 'h': r['h'] is num ? (r['h'] as num).toInt() : 19, 'm': r['m'] is num ? (r['m'] as num).toInt() : 0};
    }
  }

  String _remKey = '';
  String remBody() {
    final p = lm.plan(), g = lm.goal;
    final min = math.max(5, p.minutes);
    return g != null && g['t'] != 'none'
        ? t.remGoal(min, g['t'] == 'exam' ? t.gExamChip(g['lv'], dateS(g['date'] as String)) : 'HSK ${g['lv']}')
        : t.remFree(min);
  }

  void syncReminder() {
    if (!canRemind) return;
    final o = {'on': rem['on'] == true, 'h': rem['h'], 'm': rem['m'], 'title': t.remTitle, 'body': remBody(), 'channel': t.remChannel};
    final k = json.encode(o);
    if (k == _remKey) return;
    _remKey = k;
    Native.I.setReminder(o);
  }

  void syncRest() {
    if (Native.I.isAndroid) Native.I.setRestDays(lm.rest);
  }

  // ---------------------------------------------------------------- the home-screen widget (Android)
  String _widgetLast = '';
  static const cardC = ['#a3a9b3', '#6fd08f', '#5cc8cf', '#6dbbea', '#94a3f5', '#bf9af0', '#ec8dbd', '#e8bd57', '#ff8f78', '#a7b4dc'];
  String cardColour(int r) => r < 1 ? cardC[0] : (r > 9 || (r > 6 && !band) ? '#e6c36a' : cardC[r]);

  /// ready-made text for the widget (it cannot run the app's code): sent only when something changed
  void syncWidget(String today) {
    if (!Native.I.isAndroid) return;
    final r = lm.realm();
    final p = realmPct(r);
    final st = lm.stage(r < 1 ? lm.baseLevel() : r);
    final k = lm.streak();
    final o = {
      'r': rn[r],
      'py': rpy[r],
      'm': L10.text(t.realmM[r]) + (r > 0 ? ' · ${realmHSK(r)}' : ''),
      'p': r > 0 ? p.clamp(0, 100) : 0,
      's': r > 0 && st != null ? '${sn[st.i]} ${L10.text(t.stageM[st.i])} · $p%' : t.rLine0,
      'tl': t.planT,
      't': plainText(today).trim(),
      'd': t.strDays(fmt(k.days)),
      'lit': k.today,
      'c': cardColour(r),
    };
    final j = json.encode(o);
    if (j == _widgetLast) return;
    _widgetLast = j;
    Native.I.setWidget(o);
  }

  void changed() => notifyListeners();
}
