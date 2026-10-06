import 'package:flutter/material.dart';

/// Centralized color system for the application.
///
/// A calm, trustworthy palette built around a deep emerald/teal primary
/// (evokes traditional Islamic manuscript illumination) with a restrained
/// gold accent used sparingly for highlights only.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- brand
  static const Color brand = Color(0xFF0E6B58);
  static const Color brandDark = Color(0xFF0A5445);
  static const Color brandLight = Color(0xFF14836C);

  static const Color gold = Color(0xFFB4894A);
  static const Color goldLight = Color(0xFFD8B276);

  // ------------------------------------------------------------- light UI
  static const Color lightBackground = Color(0xFFF6F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFEFF2F1);
  static const Color lightBorder = Color(0xFFE3E8E6);
  static const Color lightTextPrimary = Color(0xFF111B18);
  static const Color lightTextSecondary = Color(0xFF5C6B67);
  static const Color lightTextTertiary = Color(0xFF8B9894);

  // -------------------------------------------------------------- dark UI
  static const Color darkBackground = Color(0xFF0D1413);
  static const Color darkSurface = Color(0xFF151E1C);
  static const Color darkSurfaceMuted = Color(0xFF1C2725);
  static const Color darkBorder = Color(0xFF26322F);
  static const Color darkTextPrimary = Color(0xFFE7EDEA);
  static const Color darkTextSecondary = Color(0xFFA3B1AD);
  static const Color darkTextTertiary = Color(0xFF76857F);

  // ------------------------------------------------------------- status
  static const Color success = Color(0xFF2E9E6B);
  static const Color successSoft = Color(0xFFE6F4ED);
  static const Color warning = Color(0xFFC98A2E);
  static const Color warningSoft = Color(0xFFFBF1E1);
  static const Color danger = Color(0xFFC0503F);
  static const Color dangerSoft = Color(0xFFFAEAE7);
  static const Color info = Color(0xFF3B7EC0);
  static const Color infoSoft = Color(0xFFE8F0F9);
  static const Color neutral = Color(0xFF7A8783);
  static const Color neutralSoft = Color(0xFFEDEFF0);

  /// Attendance status palette (shared across light & dark themes).
  static const Color statusPresent = success;
  static const Color statusAbsent = danger;
  static const Color statusLate = warning;
  static const Color statusExcused = neutral;
  static const Color statusNone = Color(0xFF9AA5A1);

  /// Hifdh grade palette: 3 = ممتاز, 2 = جيد, 1 = ضعيف.
  static Color grade(int grade) {
    switch (grade) {
      case 3:
        return success;
      case 2:
        return info;
      default:
        return danger;
    }
  }
}
