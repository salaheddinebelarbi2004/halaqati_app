import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

/// The single button primitive.
///
/// Every action in the app is expressed through this widget so sizing,
/// radius, typography and states stay identical everywhere.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.expand = false,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;
  final bool loading;
  final Color? color;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = switch (size) {
      AppButtonSize.small => AppSizes.buttonHeightSm,
      AppButtonSize.medium => AppSizes.buttonHeight,
      AppButtonSize.large => 54.0,
    };
    final iconSize = switch (size) {
      AppButtonSize.small => AppIconSize.sm,
      _ => AppIconSize.md,
    };
    final horizontalPadding = switch (size) {
      AppButtonSize.small => AppSpacing.md,
      _ => AppSpacing.xl,
    };

    final accent = color ?? scheme.primary;

    final (background, foreground, border) = switch (variant) {
      AppButtonVariant.primary => (accent, scheme.onPrimary, null),
      AppButtonVariant.secondary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        null,
      ),
      AppButtonVariant.outline => (Colors.transparent, accent, accent),
      AppButtonVariant.ghost => (
        Colors.transparent,
        scheme.onSurfaceVariant,
        null,
      ),
      AppButtonVariant.danger => (scheme.error, scheme.onError, null),
    };

    final content = _enabled
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: iconSize, color: foreground),
              ],
            ],
          )
        : _BusyLabel(label: label, color: foreground);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: _enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.7,
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          elevation: 0,
        ),
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: _enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: scheme.surfaceContainer,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.6,
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          elevation: 0,
        ),
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: _enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(
            color: _enabled
                ? (border ?? scheme.outline)
                : scheme.outlineVariant,
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: _enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.5,
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          minimumSize: Size(0, height - AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
        ),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: _enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          elevation: 0,
        ),
        child: content,
      ),
    };

    final sized = SizedBox(height: height, child: button);
    return expand ? SizedBox(width: double.infinity, child: sized) : sized;
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: AppIconSize.sm,
          height: AppIconSize.sm,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Square icon-only action with a consistent hit area.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppButtonVariant.ghost,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (variant) {
      AppButtonVariant.primary => color ?? scheme.primary,
      AppButtonVariant.secondary => scheme.surfaceContainer,
      AppButtonVariant.outline => Colors.transparent,
      _ => Colors.transparent,
    };
    final foreground = switch (variant) {
      AppButtonVariant.primary =>
        color != null ? scheme.onError : scheme.onPrimary,
      AppButtonVariant.secondary => scheme.onSurface,
      _ => color ?? scheme.onSurfaceVariant,
    };

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.allMd,
          child: Container(
            width: AppSizes.minTapTarget,
            height: AppSizes.minTapTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allMd,
              border: variant == AppButtonVariant.outline
                  ? Border.all(color: scheme.outline)
                  : null,
            ),
            child: Icon(
              icon,
              size: AppIconSize.md,
              color: onPressed == null
                  ? foreground.withValues(alpha: 0.45)
                  : foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable row of quick shortcuts (iconsax based).
class AppIconStrip extends StatelessWidget {
  const AppIconStrip({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: AppIconSize.xs,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
