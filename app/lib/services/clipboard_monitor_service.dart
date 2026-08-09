import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/link_extractor.dart';

typedef ClipboardUrlCallback = void Function(String url);

/// Foreground-only clipboard URL prompts (Settings toggle).
class ClipboardMonitorService {
  ClipboardMonitorService._();
  static final ClipboardMonitorService instance = ClipboardMonitorService._();

  static const _prefsKey = 'clipboard_monitor_enabled';
  static const _lastKey = 'clipboard_monitor_last_url';

  Timer? _timer;
  bool _enabled = true;
  String? _lastPrompted;
  ClipboardUrlCallback? onUrlDetected;
  bool _running = false;

  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? true;
    _lastPrompted = prefs.getString(_lastKey);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
    if (value) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (!_enabled || _running) return;
    if (kIsWeb) return;
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    _tick();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (!_enabled || onUrlDetected == null) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final url = LinkExtractor.firstUrl(data?.text);
      if (url == null) return;
      if (url == _lastPrompted) return;
      _lastPrompted = url;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastKey, url);
      onUrlDetected?.call(url);
    } catch (_) {
      // Clipboard may be unavailable on some OS versions.
    }
  }

  Future<void> markHandled(String url) async {
    _lastPrompted = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, url);
  }
}
