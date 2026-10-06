import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

enum AppCardVariant {
  /// Surface with a hairline border — the default, calmest option.
  outlined,

  /// Surface with a hairline border plus a very light shadow.
  elevated,

  /// Tinted container, used for grouped/secondary information.
  filled,
}

/// The single card primitive used across the application.
///
/// Screens configure it; they never hand-roll containers, borders or shadows.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.variant = AppCardVariant.outlined,
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
    this.semanticLabel,
    this.clipContent = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final AppCardVariant variant;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final String? semanticLabel;
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? AppRadius.allLg;
    final isFilled = variant == AppCardVariant.filled;

    final shadows = switch (variant) {
      AppCardVariant.elevated => AppShadows.subtle,
      _ => AppShadows.none,
    };

    final background =
        backgroundColor ??
        (isFilled ? scheme.surfaceContainer : scheme.surface);

    final content = Padding(padding: padding, child: child);

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          boxShadow: shadows,
          border: Border.all(
            color:
                borderColor ?? (isFilled ? Colors.transparent : scheme.outline),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: radius,
            focusColor: scheme.primary.withValues(alpha: 0.06),
            splashColor: scheme.primary.withValues(alpha: 0.05),
            highlightColor: scheme.primary.withValues(alpha: 0.03),
            child: clipContent
                ? ClipRRect(borderRadius: radius, child: content)
                : content,
          ),
        ),
      ),
    );
  }
}

/// Compact key/value row used inside cards.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppIconSize.sm,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin separator used inside cards instead of heavy dividers.
class AppCardDivider extends StatelessWidget {
  const AppCardDivider({super.key, this.vertical = AppSpacing.md});

  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outline),
    );
  }
}
