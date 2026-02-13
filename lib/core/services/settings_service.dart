import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // --- Keys ---
  static const String _kKey = 'chaos_key';
  static const String _kThreads = 'chaos_threads';

  // --- Getters ---
  String get encryptionKey => _prefs.getString(_kKey) ?? '1234567890123456';

  int get threadCount {
    int? val = _prefs.getInt(_kThreads);
    if (val != null) return val;
    // Default to device cores or 4
    if (!kIsWeb &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS)) {
      return Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 4;
    }
    return 4;
  }

  // --- Setters ---
  Future<void> setEncryptionKey(String value) async {
    await _prefs.setString(_kKey, value);
  }

  Future<void> setThreadCount(int value) async {
    await _prefs.setInt(_kThreads, value);
  }

  Future<void> resetDefaults() async {
    await _prefs.remove(_kKey);
    await _prefs.remove(_kThreads);
  }
}
