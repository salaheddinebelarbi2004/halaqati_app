import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The application design system.
///
/// Screens and widgets read from [ThemeData] only — no hardcoded colors,
/// font sizes, paddings or radii in feature code.
class AppTheme {
  const AppTheme._();

  // Legacy aliases kept so older call-sites keep compiling.
  static const Color primary = AppColors.brand;
  static const Color secondary = AppColors.gold;
  static const Color accent = AppColors.brandLight;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger = AppColors.danger;
  static const Color info = AppColors.info;

  static LinearGradient get primaryGradient =>
      const LinearGradient(colors: [AppColors.brand, AppColors.brandLight]);

  // ------------------------------------------------------------------ light
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brand,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCEFE9),
    onPrimaryContainer: Color(0xFF05372D),
    secondary: Color(0xFF3E635A),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFDCEFE9),
    onSecondaryContainer: Color(0xFF0C2B24),
    tertiary: AppColors.gold,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF6E9D6),
    onTertiaryContainer: Color(0xFF3A2A10),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: Color(0xFF5A1A12),
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightTextPrimary,
    onSurfaceVariant: AppColors.lightTextSecondary,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFBFCFB),
    surfaceContainer: AppColors.lightSurfaceMuted,
    surfaceContainerHigh: Color(0xFFE9EEEC),
    surfaceContainerHighest: Color(0xFFE2E8E5),
    outline: AppColors.lightBorder,
    outlineVariant: Color(0xFFEDF1EF),
    shadow: Color(0x14112F28),
    scrim: Color(0x66101816),
    inverseSurface: Color(0xFF1B2624),
    onInverseSurface: Color(0xFFEFF4F2),
    inversePrimary: Color(0xFF6FCFB4),
  );

  // ------------------------------------------------------------------- dark
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6FCFB4),
    onPrimary: Color(0xFF00382D),
    primaryContainer: Color(0xFF0A5445),
    onPrimaryContainer: Color(0xFFA9EBD8),
    secondary: Color(0xFFA8C9BF),
    onSecondary: Color(0xFF12352D),
    secondaryContainer: Color(0xFF2A4A43),
    onSecondaryContainer: Color(0xFFD4EDE5),
    tertiary: AppColors.goldLight,
    onTertiary: Color(0xFF3A2A10),
    tertiaryContainer: Color(0xFF4A3A1C),
    onTertiaryContainer: Color(0xFFF6E9D6),
    error: Color(0xFFE38A7C),
    onError: Color(0xFF4A120B),
    errorContainer: Color(0xFF6B241A),
    onErrorContainer: Color(0xFFFBDAD4),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    surfaceContainerLowest: Color(0xFF0A100F),
    surfaceContainerLow: Color(0xFF131B1A),
    surfaceContainer: AppColors.darkSurfaceMuted,
    surfaceContainerHigh: Color(0xFF222D2B),
    surfaceContainerHighest: Color(0xFF2B3734),
    outline: AppColors.darkBorder,
    outlineVariant: Color(0xFF1E2826),
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    inverseSurface: AppColors.darkTextPrimary,
    onInverseSurface: Color(0xFF101A18),
    inversePrimary: AppColors.brand,
  );

  static ThemeData get light => _build(_lightScheme, Brightness.light);
  static ThemeData get dark => _build(_darkScheme, Brightness.dark);

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textTheme = AppTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      canvasColor: isLight
          ? AppColors.lightBackground
          : AppColors.darkBackground,
      fontFamily: AppTypography.uiFont,
      textTheme: textTheme,
      // ------------------------------------------------------------ buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: AppTypography.labelLarge,
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: AppTypography.labelLarge,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTypography.labelLarge,
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
        ),
      ),
      // ------------------------------------------------------------- inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? AppColors.lightSurface
            : AppColors.darkSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: scheme.primary,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        errorStyle: AppTypography.bodySmall.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w500,
        ),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outline),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
        disabledBorder: _inputBorder(scheme.outlineVariant),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(),
      // -------------------------------------------------------------- cards
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      // -------------------------------------------------------------- chips
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: AppTypography.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        showCheckmark: false,
      ),
      // ------------------------------------------------------------- others
      appBarTheme: AppBarTheme(
        backgroundColor: isLight
            ? AppColors.lightBackground
            : AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: AppSizes.appBarHeight,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: AppIconSize.md),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(AppTypography.labelSmall),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allLg,
          side: BorderSide(color: scheme.outline),
        ),
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.1),
        trackHeight: 4,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(AppTypography.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: WidgetStatePropertyAll(
            const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.allSm,
        ),
        textStyle: AppTypography.bodySmall.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: scheme.onSurface,
        ),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
      ),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.allMd,
        borderSide: BorderSide(color: color, width: width),
      );
}
