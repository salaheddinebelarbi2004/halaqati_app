import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Consistent confirmation / information dialogs.
class AppDialog {
  const AppDialog._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool destructive = false,
    IconData? icon,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon == null
            ? null
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: destructive
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: destructive
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                  size: AppIconSize.md,
                ),
              ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  variant: AppButtonVariant.outline,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  variant: destructive
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'حسناً',
    IconData? icon,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: Theme.of(ctx).colorScheme.primary,
                size: AppIconSize.xl,
              ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          AppButton(
            label: confirmLabel,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

/// Consistent bottom sheets with a title row and safe-area aware body.
class AppBottomSheet {
  const AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    double? maxHeightFactor = 0.85,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * (maxHeightFactor ?? 0.85),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              color: Theme.of(ctx).colorScheme.onSurface,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(child: builder(ctx)),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

/// Consistent, unobtrusive feedback messages.
class AppSnack {
  const AppSnack._();

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_outline_rounded,
    bool isError = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(
                icon,
                size: AppIconSize.sm,
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onInverseSurface,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, icon: Icons.check_circle_outline_rounded);

  static void error(BuildContext context, String message) =>
      show(context, message, icon: Icons.error_outline_rounded, isError: true);
}

/// Centered, width-constrained dialog body for forms that are too tall for a
/// plain [AlertDialog] on small windows.
class DialogBodyShell extends StatelessWidget {
  const DialogBodyShell({super.key, required this.child, this.maxWidth = 520});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
