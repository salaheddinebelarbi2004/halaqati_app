import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_badges.dart';
import 'app_card.dart';

/// Compact metric tile: big value, small label, optional accent.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.color,
    this.onTap,
    this.alignment = MainAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      semanticLabel: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.sm, color: accent),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of [StatTile]s that adapts to the window width.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.maxWidth});

  final List<Widget> tiles;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = maxWidth ?? constraints.maxWidth;
        // Comfortable minimum tile width keeps labels readable everywhere.
        final columns = (width / 190).floor().clamp(1, tiles.length);
        final spacing = AppSpacing.md;
        final tileWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// Horizontal progress indicator with a label and a trailing percentage.
///
/// [LinearProgressIndicator] forces `minWidth: double.infinity`, so dropping
/// this straight into a `Row` gives it unbounded width: the row then measures
/// as infinitely wide, every `Expanded` sibling collapses and the card renders
/// as a long empty strip. The guard below keeps the bar usable in that case
/// instead of silently breaking the layout.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.showLabel = true,
    this.label,
    this.unboundedWidth = 120,
  });

  /// 0.0 – 1.0
  final double value;
  final Color? color;
  final double height;
  final bool showLabel;
  final String? label;

  /// Width used when the parent hands us unbounded width (e.g. a `Row`).
  final double unboundedWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final accent = color ?? theme.colorScheme.primary;

    final bar = ClipRRect(
      borderRadius: AppRadius.allPill,
      child: LinearProgressIndicator(
        value: clamped,
        minHeight: height,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );

    if (!showLabel) {
      return LayoutBuilder(
        builder: (context, constraints) => constraints.hasBoundedWidth
            ? bar
            : SizedBox(width: unboundedWidth, child: bar),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  label!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${(clamped * 100).round()}%',
                style: theme.textTheme.labelMedium?.copyWith(color: accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        bar,
      ],
    );
  }
}

/// Progress card used for attendance ratios and memorization goals.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.caption,
    this.icon,
    this.color,
    this.onTap,
  });

  final String title;
  final double value;
  final String? subtitle;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      semanticLabel: '$title ${(value * 100).round()} بالمئة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Icon(icon, size: AppIconSize.sm, color: accent),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${(value.clamp(0.0, 1.0) * 100).round()}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(value: value, color: accent, showLabel: false),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular percentage indicator with a caption, used for rankings.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    this.size = 56,
    this.color,
    this.label,
  });

  /// 0.0 – 1.0
  final double value;
  final double size;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          Text(
            label ?? '${(clamped * 100).round()}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rank pill used in leaderboards: gold / silver / bronze, then neutral.
class RankPill extends StatelessWidget {
  const RankPill({super.key, required this.rank, this.size = 28});

  final int rank;
  final double size;

  static const List<Color> _medals = [
    Color(0xFFC9A227), // gold
    Color(0xFF9AA5AD), // silver
    Color(0xFFB87333), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop = rank >= 1 && rank <= 3;
    final background = isTop
        ? _medals[rank - 1].withValues(alpha: 0.16)
        : theme.colorScheme.surfaceContainer;
    final foreground = isTop
        ? _medals[rank - 1]
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allMd,
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Status summary strip: label + count + colour, used above lists.
class StatusSummaryBar extends StatelessWidget {
  const StatusSummaryBar({super.key, required this.items});

  final List<({String label, int count, Color color})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.allPill,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  item.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  '${item.count}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Quick action tile used on the dashboard.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.caption,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      semanticLabel: label,
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(icon, size: AppIconSize.md, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            size: AppIconSize.md,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// Rounded avatar showing the first letter of a name.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = AppSizes.avatarMd,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final letter = name.trim().isEmpty ? '؟' : name.trim()[0];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Text(
        letter,
        style: theme.textTheme.titleMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Section label + count chip used above lists.
class CountHeader extends StatelessWidget {
  const CountHeader({super.key, required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        AppBadge(
          label: '$count',
          color: theme.colorScheme.onSurfaceVariant,
          dense: true,
        ),
      ],
    );
  }
}
