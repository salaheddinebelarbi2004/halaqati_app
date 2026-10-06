import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../models/student.dart';
import '../theme/app_spacing.dart';
import 'app_badges.dart';
import 'app_card.dart';
import 'app_metrics.dart';

/// Student list row: identity on the right, metadata on the left.
///
/// Matches the RTL reading order used throughout the app.
class StudentCard extends StatelessWidget {
  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.onEdit,
    this.onToggleActive,
    this.trailing,
    this.subtitle,
    this.leadingBadges = const <Widget>[],
  });

  final Student student;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;
  final Widget? trailing;
  final String? subtitle;
  final List<Widget> leadingBadges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = <Widget>[
      if (!student.active)
        const AppBadge(
          label: 'غير نشط',
          color: Color(0xFF7A8783),
          icon: Iconsax.close_circle,
          dense: true,
        ),
      ...leadingBadges,
    ];

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      semanticLabel: student.fullName,
      child: Row(
        children: [
          AppAvatar(
            name: student.fullName,
            color: student.active ? null : const Color(0xFF9AA5A1),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: student.active
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: badges,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ] else if (onEdit != null || onToggleActive != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _StudentActions(
              onEdit: onEdit,
              onToggleActive: onToggleActive,
              active: student.active,
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentActions extends StatelessWidget {
  const _StudentActions({
    required this.onEdit,
    required this.onToggleActive,
    required this.active,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          _RoundAction(
            icon: Iconsax.edit_2,
            tooltip: 'تعديل',
            onPressed: onEdit,
          ),
        if (onToggleActive != null) ...[
          const SizedBox(width: AppSpacing.xs),
          _RoundAction(
            icon: active ? Iconsax.close_circle : Iconsax.refresh,
            tooltip: active ? 'إيقاف' : 'استعادة',
            color: active
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            onPressed: onToggleActive,
          ),
        ],
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = color ?? scheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.allMd,
          child: Container(
            width: AppSizes.minTapTarget,
            height: AppSizes.minTapTarget,
            alignment: Alignment.center,
            child: Icon(icon, size: AppIconSize.sm, color: foreground),
          ),
        ),
      ),
    );
  }
}
