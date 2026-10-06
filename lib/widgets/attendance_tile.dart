import 'package:flutter/material.dart';
import '../models/student.dart';
import '../theme/app_spacing.dart';
import 'app_badges.dart';
import 'app_card.dart';
import 'app_metrics.dart';

/// Attendance row.
///
/// Read mode shows the recorded status. Edit mode turns the same row into a
/// compact set of one-tap options so registering a session takes minimal taps
/// and never requires a heavy table.
class AttendanceTile extends StatelessWidget {
  const AttendanceTile({
    super.key,
    required this.student,
    required this.status,
    this.editable = false,
    this.onStatusSelected,
    this.onTap,
  });

  final Student student;
  final String? status;
  final bool editable;
  final ValueChanged<String>? onStatusSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStatus = status != null;
    final color = AttendanceStatus.color(status ?? '');

    return AppCard(
      onTap: editable ? null : onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: hasStatus ? color.withValues(alpha: 0.45) : null,
      semanticLabel:
          '${student.fullName}، ${AttendanceStatus.label(status ?? '')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(
                name: student.fullName,
                color: hasStatus ? color : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (!editable) ...[
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: AttendanceStatus.label(status ?? ''),
                  color: color,
                  icon: AttendanceStatus.icon(status ?? ''),
                  dense: true,
                ),
              ],
            ],
          ),
          if (editable) ...[
            const SizedBox(height: AppSpacing.md),
            _StatusSelector(selected: status, onSelected: onStatusSelected),
          ],
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.xs + 2;
        final total = constraints.maxWidth;
        final itemWidth = (total - gap * 3) / 4;

        return Row(
          children: [
            for (var i = 0; i < AttendanceStatus.all.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                child: _StatusOption(
                  status: AttendanceStatus.all[i],
                  selected: selected == AttendanceStatus.all[i],
                  onTap: onSelected == null
                      ? null
                      : () => onSelected!(AttendanceStatus.all[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AttendanceStatus.color(status);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      selected: selected,
      button: true,
      label: AttendanceStatus.label(status),
      child: Material(
        color: selected
            ? color.withValues(alpha: isDark ? 0.24 : 0.12)
            : theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allMd,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: Curves.easeOut,
            height: AppSizes.buttonHeightSm,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: selected ? color : theme.colorScheme.outline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AttendanceStatus.icon(status),
                  size: AppIconSize.xs + 1,
                  color: selected ? color : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs + 1),
                Flexible(
                  child: Text(
                    AttendanceStatus.label(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
