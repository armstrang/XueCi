/// The Android side (MainActivity.kt):
/// speech, the daily reminder, sharing, the home-screen widget — plus the move of v1.x progress. Every call is
/// safe without Android (tests, other platforms): it then does nothing and returns a neutral answer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Native {
  static const _ch = MethodChannel('xueci/native');
  static final Native I = Native._();
  Native._() {
    _ch.setMethodCallHandler((c) async {
      if (c.method == 'notifResult') _notif?.complete(c.arguments == true);
      if (c.method == 'ttsReady') {
        if (c.arguments is String) _tts = c.arguments as String;
        ttsChanged?.call();
      }
      return null;
    });
  }

  /// in tests: replaces the platform
  static bool off = false;
  VoidCallback? ttsChanged;
  Completer<bool>? _notif;

  Future<T?> _call<T>(String m, [Object? a]) async {
    if (off || kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _ch.invokeMethod<T>(m, a);
    } catch (_) {
      return null;
    }
  }

  /// the app's own files folder (the store lives in `files/store`)
  Future<String?> filesDir() => _call<String>('filesDir');

  /// the progress the earlier version (up to 1.17) kept: its localStorage and IndexedDB, read once by a hidden WebView on the
  /// old origin. null when there is none (or no Android); {'!': '1'} when reading it failed (try again later).
  Future<Map<String, String>?> legacy() async {
    final s = await _call<String>('legacy');
    if (s == null || s.isEmpty) return null;
    if (s == '!') return const {'!': '1'};
    try {
      final m = json.decode(s) as Map;
      return m.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return null;
    }
  }

  Future<void> ready() => _call('ready');

  // ---- speech (Android TextToSpeech, zh-CN) ----
  String _tts = 'missing';
  String get ttsState => _tts;
  set ttsTest(String v) => _tts = v; // tests and store pictures: pretend a voice is installed
  Future<String> ttsStatus() async => _tts = await _call<String>('ttsStatus') ?? (off ? _tts : 'unsupported');
  Future<void> speak(String text, {double rate = 0.9}) => _call('speak', {'text': text, 'rate': rate});
  Future<void> stopSpeaking() => _call('stopSpeaking');
  Future<void> openTtsSettings() => _call('openTtsSettings');

  // ---- speaking practice (the phone's recognizer, in its own window: no microphone permission) ----
  Future<bool> canListen() async => (await _call<bool>('canListen')) ?? false;

  /// what the phone heard (its guesses, best first); [] when nothing was heard, null when closed or not possible,
  /// ['!'] when the phone has no recognizer
  Future<List<String>?> listen(String prompt) async {
    final s = await _call<String>('listen', prompt);
    if (s == null) return null;
    if (s == '!') return const ['!'];
    try {
      return [for (final x in json.decode(s) as List) '$x'];
    } catch (_) {
      return null;
    }
  }

  // ---- daily reminder ----
  Future<void> setReminder(Map<String, Object?> r) => _call('setReminder', json.encode(r));
  Future<void> markStudied() => _call('markStudied');
  Future<void> setRestDays(List<int> d) => _call('setRestDays', json.encode(d));
  Future<String> notifStatus() async => await _call<String>('notifStatus') ?? 'unsupported';
  Future<bool> requestNotifications() async {
    if (off || !Platform.isAndroid) return false;
    _notif = Completer();
    await _call('requestNotifications');
    return _notif!.future.timeout(const Duration(seconds: 60), onTimeout: () => false);
  }

  Future<void> openNotifSettings() => _call('openNotifSettings');
  Future<bool> canRemind() async => (await _call<bool>('canRemind')) ?? false;

  // ---- sharing, links, widget ----
  Future<bool> shareText(String text) async => (await _call<bool>('shareText', text)) ?? false;
  Future<bool> shareImage(Uint8List png, String text) async =>
      (await _call<bool>('shareImage', {'png': png, 'text': text})) ?? false;
  Future<void> openUrl(String url) => _call('openUrl', url);
  Future<void> setWidget(Map<String, Object?> data) => _call('setWidget', json.encode(data));

  // ---- 护法: donations through Google Play Billing (Donate.kt) ----
  /// the products with their prices in the phone's currency, plus donations finished earlier but not counted yet;
  /// null when Google Play can't sell here (no Play, the APK from GitHub, no products yet)
  Future<({List<({String id, String price})> items, int done})?> donProducts(List<String> ids) async {
    final s = await _call<String>('donProducts', json.encode(ids));
    if (s == null) return null;
    try {
      final m = json.decode(s) as Map;
      if (m['ok'] != true) return null;
      return (
        items: [for (final e in m['items'] as List) (id: '${(e as Map)['id']}', price: '${e['price']}')],
        done: (m['done'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// ok | pending | cancel | error
  Future<String> donBuy(String id) async => await _call<String>('donBuy', id) ?? 'error';

  /// the device's languages (first = preferred), e.g. ['in-ID', 'en-US']
  List<String> sysLangs() => PlatformDispatcher.instance.locales.map((l) => l.toLanguageTag()).toList();

  bool get isAndroid => !off && !kIsWeb && Platform.isAndroid;
}
