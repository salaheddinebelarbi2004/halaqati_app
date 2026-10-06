import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_controller.dart';
import 'app_button.dart';

/// Compact app-bar button that cycles فاتح -> داكن -> تلقائي.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    // Show the mode currently in effect; for "system" that is whatever the
    // platform reports right now.
    final Brightness effective = switch (mode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
    };
    final icon = effective == Brightness.dark
        ? Icons.dark_mode_rounded
        : Icons.light_mode_rounded;
    final next = switch (mode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };

    return AppIconButton(
      icon: icon,
      tooltip:
          'المظهر: ${themeModeLabel(mode)} — اضغط للتبديل إلى ${themeModeLabel(next)}',
      onPressed: () => controller.cycle(),
    );
  }
}

/// Three-way appearance selector used on the settings screen.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              themeModeIcon(mode),
              size: AppIconSize.md,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'المظهر',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              themeModeLabel(mode),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (final option in const [
              ThemeMode.light,
              ThemeMode.dark,
              ThemeMode.system,
            ]) ...[
              if (option != ThemeMode.light)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ThemeOption(
                  mode: option,
                  selected: option == mode,
                  onTap: () => controller.set(option),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Semantics(
      selected: selected,
      button: true,
      label: themeModeLabel(mode),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surface,
        borderRadius: AppRadius.allMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allMd,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: selected ? accent : theme.colorScheme.outline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  themeModeIcon(mode),
                  size: AppIconSize.md,
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  themeModeLabel(mode),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? accent
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
