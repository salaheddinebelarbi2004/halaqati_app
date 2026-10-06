import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Small, tinted label used for statuses, counts and metadata.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = true,
    this.dense = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = color ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final background = filled
        ? (isDark ? base.withValues(alpha: 0.18) : base.withValues(alpha: 0.10))
        : Colors.transparent;
    final foreground = filled
        ? (isDark ? _lighten(base) : _darken(base))
        : base;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allPill,
        border: filled ? null : Border.all(color: base.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: foreground),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();
  }
}

/// Neutral badge with a leading dot, used for inactive/secondary states.
class AppDotBadge extends StatelessWidget {
  const AppDotBadge({
    super.key,
    required this.label,
    required this.color,
    this.dense = true,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? 3 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attendance status presentation, defined once for the whole app.
class AttendanceStatus {
  const AttendanceStatus._();

  static const List<String> all = ['present', 'absent', 'late', 'excused'];

  static String label(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'excused':
        return 'بعذر';
      default:
        return 'غير مسجّل';
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'present':
        return AppColors.statusPresent;
      case 'absent':
        return AppColors.statusAbsent;
      case 'late':
        return AppColors.statusLate;
      case 'excused':
        return AppColors.statusExcused;
      default:
        return AppColors.statusNone;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.schedule_rounded;
      case 'excused':
        return Icons.event_busy_rounded;
      default:
        return Icons.remove_circle_outline_rounded;
    }
  }

  static String shortLabel(String status) => switch (status) {
    'present' => 'ح',
    'absent' => 'غ',
    'late' => 'ت',
    'excused' => 'ع',
    _ => '–',
  };
}

/// Hifdh (memorization) type presentation.
class HifdType {
  const HifdType._();

  static const String jadid = 'jadid';
  static const String muraja3a = 'muraja3a';

  static String label(String type) => type == jadid ? 'جديد' : 'مراجعة';

  static Color color(String type) =>
      type == jadid ? AppColors.brand : AppColors.gold;

  /// Longer description used in the entry form.
  static String description(String type) =>
      type == jadid ? 'مقدار جديد محفوظ' : 'مراجعة لمقدار محفوظ سابقاً';
}

/// Memorization grade presentation.
class HifdGrade {
  const HifdGrade._();

  static const List<int> all = [3, 2, 1];

  static String label(int grade) {
    switch (grade) {
      case 3:
        return 'ممتاز';
      case 2:
        return 'جيد';
      case 1:
        return 'ضعيف';
      default:
        return 'غير محدد';
    }
  }

  static Color color(int grade) => AppColors.grade(grade);

  static IconData icon(int grade) {
    switch (grade) {
      case 3:
        return Icons.star_rounded;
      case 2:
        return Icons.star_half_rounded;
      default:
        return Icons.star_outline_rounded;
    }
  }
}
