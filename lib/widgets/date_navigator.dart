import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Day navigation shared by the attendance and hifdh screens.
///
/// Includes a relative day label ("اليوم", "أمس", weekday) so the teacher
/// always knows which session is on screen.
class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.onChanged,
    this.canGoForward = true,
    this.readOnly = false,
    this.onPickDate,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final bool canGoForward;
  final bool readOnly;
  final Future<void> Function()? onPickDate;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String relativeLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff == 2) return 'قبل يومين';
    if (diff == -1) return 'غداً';
    return DateFormat('EEEE', 'ar').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = relativeLabel(date);
    final hijriish = DateFormat('d MMMM yyyy', 'ar').format(date);

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'اليوم التالي',
            onPressed: canGoForward
                ? () => onChanged(date.add(const Duration(days: 1)))
                : null,
          ),
          Expanded(
            child: InkWell(
              onTap: onPickDate,
              borderRadius: AppRadius.allMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: [
                    Text(
                      relative,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      hijriish,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (readOnly) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const _ReadOnlyChip(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'اليوم السابق',
            onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyChip extends StatelessWidget {
  const _ReadOnlyChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.info_circle,
            size: AppIconSize.xs,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'للقراءة فقط',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
