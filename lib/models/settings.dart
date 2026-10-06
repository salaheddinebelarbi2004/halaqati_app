/// Persisted user preferences, one row per teacher.
///
/// The app is Arabic-only, so there is deliberately no language field: every
/// string in the interface is written in Arabic and the whole tree is forced
/// to RTL. [themeMode] is the only appearance preference; the two weights
/// drive the overall ranking score.
class AppSettings {
  const AppSettings({
    this.teacherId,
    this.hodorWeight = 0.4,
    this.hifdWeight = 0.6,
    this.themeMode = themeSystem,
  });

  /// Values accepted by the `theme_mode` column.
  static const String themeSystem = 'system';
  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  static const List<String> themeValues = [themeSystem, themeLight, themeDark];

  final String? teacherId;
  final double hodorWeight;
  final double hifdWeight;
  final String themeMode;

  Map<String, dynamic> toJson() => {
    'hodor_weight': hodorWeight,
    'hifd_weight': hifdWeight,
    'theme_mode': themeMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final stored = json['theme_mode'] as String?;
    return AppSettings(
      teacherId: json['teacher_id'] as String?,
      hodorWeight: (json['hodor_weight'] as num?)?.toDouble() ?? 0.4,
      hifdWeight: (json['hifd_weight'] as num?)?.toDouble() ?? 0.6,
      // Guard against a value written by an older/newer build.
      themeMode: themeValues.contains(stored) ? stored! : themeSystem,
    );
  }

  AppSettings copyWith({
    String? teacherId,
    double? hodorWeight,
    double? hifdWeight,
    String? themeMode,
  }) => AppSettings(
    teacherId: teacherId ?? this.teacherId,
    hodorWeight: hodorWeight ?? this.hodorWeight,
    hifdWeight: hifdWeight ?? this.hifdWeight,
    themeMode: themeMode ?? this.themeMode,
  );
}
