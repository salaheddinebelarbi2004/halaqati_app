import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized typography.
///
/// * Cairo — UI text (Arabic-first, clean geometric humanist).
/// * Amiri Quran — Qur'anic content only, kept visually distinct from UI text.
class AppTypography {
  const AppTypography._();

  static const String uiFont = 'Cairo';
  static const String quranFont = 'Amiri Quran';

  /// Fallbacks guarantee readable Arabic even if web fonts are unavailable.
  static const List<String> uiFallback = <String>[
    'Cairo',
    'Noto Sans Arabic',
    'Tahoma',
    'Arial',
  ];

  static const List<String> quranFallback = <String>[
    'Amiri Quran',
    'Amiri',
    'Scheherazade New',
    'Traditional Arabic',
    'Noto Naskh Arabic',
    'Times New Roman',
  ];

  static TextStyle _ui({
    double? size,
    FontWeight? weight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => GoogleFonts.cairo(
    textStyle: TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    ),
  );

  // ------------------------------------------------------------ UI styles
  static TextStyle get displayLarge =>
      _ui(size: 34, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.4);

  static TextStyle get displayMedium =>
      _ui(size: 28, weight: FontWeight.w700, height: 1.25, letterSpacing: -0.3);

  static TextStyle get headlineLarge =>
      _ui(size: 24, weight: FontWeight.w700, height: 1.3, letterSpacing: -0.2);

  static TextStyle get headlineMedium =>
      _ui(size: 20, weight: FontWeight.w700, height: 1.35);

  static TextStyle get headlineSmall =>
      _ui(size: 18, weight: FontWeight.w700, height: 1.4);

  static TextStyle get titleLarge =>
      _ui(size: 17, weight: FontWeight.w600, height: 1.45);

  static TextStyle get titleMedium =>
      _ui(size: 15, weight: FontWeight.w600, height: 1.45);

  static TextStyle get titleSmall =>
      _ui(size: 14, weight: FontWeight.w600, height: 1.45);

  static TextStyle get bodyLarge =>
      _ui(size: 15, weight: FontWeight.w400, height: 1.6);

  static TextStyle get bodyMedium =>
      _ui(size: 13.5, weight: FontWeight.w400, height: 1.6);

  static TextStyle get bodySmall =>
      _ui(size: 12, weight: FontWeight.w400, height: 1.5);

  static TextStyle get labelLarge =>
      _ui(size: 14, weight: FontWeight.w600, height: 1.2);

  static TextStyle get labelMedium =>
      _ui(size: 12.5, weight: FontWeight.w600, height: 1.2);

  static TextStyle get labelSmall =>
      _ui(size: 11, weight: FontWeight.w600, height: 1.2);

  // ------------------------------------------------------ semantic styles
  /// Big page / screen title.
  static TextStyle pageTitle(BuildContext context) =>
      headlineLarge.copyWith(color: context.textPrimary);

  /// Section header inside a page.
  static TextStyle sectionTitle(BuildContext context) =>
      titleMedium.copyWith(color: context.textPrimary);

  /// Primary readable body copy.
  static TextStyle textPrimary(BuildContext context) =>
      bodyLarge.copyWith(color: context.textPrimary);

  /// Supporting / secondary copy.
  static TextStyle textSecondary(BuildContext context) =>
      bodyMedium.copyWith(color: context.textSecondary);

  /// Compact metadata (dates, counts, hints).
  static TextStyle textTertiary(BuildContext context) =>
      bodySmall.copyWith(color: context.textTertiary);

  static TextStyle get labelEmphasized =>
      labelLarge.copyWith(letterSpacing: 0.2);

  // ------------------------------------------------------- Quranic styles
  /// Distinct typography reserved for Qur'anic text.
  static TextStyle get quranAyah => GoogleFonts.amiriQuran(
    fontSize: 26,
    fontWeight: FontWeight.w400,
    height: 2.0,
    letterSpacing: 0,
  );

  static TextStyle get quranSurahName => GoogleFonts.amiriQuran(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.6,
  );

  static TextStyle get quranCaption =>
      _ui(size: 12, weight: FontWeight.w600, height: 1.4, letterSpacing: 0.3);

  // -------------------------------------------------------- theme builders
  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    TextStyle t(TextStyle style) =>
        style.copyWith(color: primaryText, fontFamilyFallback: uiFallback);
    TextStyle s(TextStyle style) =>
        style.copyWith(color: secondaryText, fontFamilyFallback: uiFallback);

    return TextTheme(
      displayLarge: t(displayLarge),
      displayMedium: t(displayMedium),
      displaySmall: t(headlineLarge),
      headlineLarge: t(headlineLarge),
      headlineMedium: t(headlineMedium),
      headlineSmall: t(headlineSmall),
      titleLarge: t(titleLarge),
      titleMedium: t(titleMedium),
      titleSmall: t(titleSmall),
      bodyLarge: t(bodyLarge),
      bodyMedium: s(bodyMedium),
      bodySmall: s(bodySmall),
      labelLarge: t(labelLarge),
      labelMedium: s(labelMedium),
      labelSmall: s(labelSmall),
    );
  }
}

/// Ergonomic reading sizes for the Qur'an screen.
enum QuranTextScale {
  small(0.85, 22),
  medium(1.0, 26),
  large(1.18, 31);

  const QuranTextScale(this.factor, this.baseSize);

  final double factor;
  final double baseSize;

  TextStyle get style => AppTypography.quranAyah.copyWith(fontSize: baseSize);

  String get labelAr => switch (this) {
    QuranTextScale.small => 'صغير',
    QuranTextScale.medium => 'متوسط',
    QuranTextScale.large => 'كبير',
  };
}

/// Color helpers bound to the active theme brightness.
extension ThemeTextColors on BuildContext {
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary =>
      Theme.of(this).textTheme.bodyMedium?.color ??
      AppColors.lightTextSecondary;
  Color get textTertiary =>
      Theme.of(this).textTheme.bodySmall?.color ?? AppColors.lightTextTertiary;
}
