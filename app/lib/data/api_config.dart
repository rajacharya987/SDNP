import 'package:flutter/foundation.dart';

/// Backend API base URL for SafeLink / SentinelX.
abstract final class ApiConfig {
  /// Laravel API root (includes `/api/v1`).
  ///
  /// Override at run time:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1`
  ///
  /// Physical Android over USB: use 127.0.0.1 and run
  /// `adb reverse tcp:8000 tcp:8000` (emulator can use the same).
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Works for emulator + physical device when `adb reverse tcp:8000 tcp:8000` is set.
      // Do NOT use 10.0.2.2 on a real phone — that address only exists in the emulator.
      return 'http://127.0.0.1:8000/api/v1';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://127.0.0.1:8000/api/v1';
    }

    return 'http://localhost:8000/api/v1';
  }
}
