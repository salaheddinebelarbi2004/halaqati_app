import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../core/errors/app_exception.dart';
import '../theme/app_spacing.dart';

/// Persistent strip shown above every screen while the app is offline.
///
/// The app is cloud-only, so there is no local cache to fall back on. Saying
/// so once, plainly, beats letting the teacher tap a button that silently
/// does nothing.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOnline,
    required this.child,
    this.onRetry,
  });

  final bool isOnline;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isOnline) return child;

    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.warning_2,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      AppException.offlineMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: Text(
                        'إعادة المحاولة',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
