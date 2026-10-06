import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../models/settings.dart';

/// Owns the light / dark / follow-system preference.
///
/// The value lives in the cloud `settings` row and is watched as a realtime
/// subscription, so the choice follows the teacher to every signed-in device
/// and survives a restart without storing anything locally.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._ref) : super(ThemeMode.system) {
    _ref.listen<AsyncValue<AppSettings>>(settingsProvider, (_, next) {
      final restored = modeFromStorage(
        next.valueOrNull?.themeMode ?? AppSettings.themeSystem,
      );
      if (restored != state && mounted) state = restored;
    }, fireImmediately: true);
  }

  final Ref _ref;

  /// Cycles light -> dark -> system. Used by the compact app-bar button.
  Future<void> cycle() async {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await set(next);
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      await _ref.read(dataServiceProvider).saveThemeMode(toStorage(mode));
    } catch (_) {
      // Keep the in-memory choice even if it could not be persisted.
    }
  }

  static String toStorage(ThemeMode mode) => switch (mode) {
    ThemeMode.light => AppSettings.themeLight,
    ThemeMode.dark => AppSettings.themeDark,
    ThemeMode.system => AppSettings.themeSystem,
  };

  static ThemeMode modeFromStorage(String value) => switch (value) {
    AppSettings.themeLight => ThemeMode.light,
    AppSettings.themeDark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref),
);

/// Arabic label for a mode, used by the settings screen and tooltips.
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'فاتح',
  ThemeMode.dark => 'داكن',
  ThemeMode.system => 'تلقائي',
};

/// Icon describing the mode a button would switch *to*.
IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Icons.light_mode_rounded,
  ThemeMode.dark => Icons.dark_mode_rounded,
  ThemeMode.system => Icons.brightness_auto_rounded,
};
