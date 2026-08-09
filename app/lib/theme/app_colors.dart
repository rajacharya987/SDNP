import 'package:flutter/material.dart';

/// Brand palette matched to the splash screen.
abstract final class AppColors {
  /// Splash accent blue ("with one tap").
  static const Color accent = Color(0xFF5B8DEF);
  static const Color accentDeep = Color(0xFF3D6FD8);
  static const Color accentSoft = Color(0xFFE8F0FE);
  static const Color accentGlow = Color(0xFFB8C9F5);
  static const Color sky = Color(0xFFDDE8FC);

  // Legacy aliases used across screens → splash blue.
  static const Color crimson = accent;
  static const Color flame = Color(0xFF7BA4F3);
  static const Color ember = Color(0xFF9BB8F5);
  static const Color deepRed = accentDeep;
  static const Color blush = accentSoft;

  static const Color ink = Color(0xFF111111);
  static const Color slate = Color(0xFF6B6B6B);
  static const Color mist = Color(0xFFF7F9FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  static const Color safe = Color(0xFF2E7D32);
  static const Color safeSoft = Color(0xFFE8F5E9);
  static const Color caution = Color(0xFFF9A825);
  static const Color cautionSoft = Color(0xFFFFF8E1);
  static const Color danger = Color(0xFFE53935);
  static const Color dangerSoft = Color(0xFFFFEBEE);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D6FD8), accent, Color(0xFF7BA4F3)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Soft blue page background (same family as splash).
  static const LinearGradient page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF7F9FF),
      Color(0xFFE8F0FE),
      sky,
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  static const LinearGradient brandSoft = page;
  static const LinearGradient hero = page;
  static const LinearGradient splash = page;
}
