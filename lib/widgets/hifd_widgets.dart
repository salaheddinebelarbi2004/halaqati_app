import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../data/surah_catalog.dart';
import '../models/hifd_entry.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_badges.dart';
import 'app_card.dart';
import 'app_metrics.dart';

/// Qur'anic text rendered with a dedicated font so it is always visually
/// distinct from application UI text.
class QuranText extends StatelessWidget {
  const QuranText(
    this.text, {
    super.key,
    this.scale = QuranTextScale.medium,
    this.color,
    this.textAlign = TextAlign.center,
    this.maxLines,
  });

  final String text;
  final QuranTextScale scale;
  final Color? color;
  final TextAlign textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: scale.style.copyWith(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontFamilyFallback: AppTypography.quranFallback,
      ),
    );
  }
}

/// Surah name rendered in the Qur'anic typeface.
class SurahNameText extends StatelessWidget {
  const SurahNameText(this.surahNumber, {super.key, this.fontSize = 18});

  final int surahNumber;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      SurahCatalog.instance.nameOf(surahNumber),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.quranSurahName.copyWith(
        fontSize: fontSize,
        color: Theme.of(context).colorScheme.onSurface,
        fontFamilyFallback: AppTypography.quranFallback,
      ),
    );
  }
}

/// Reference chip: surah name + ayah number.
class SurahRefChip extends StatelessWidget {
  const SurahRefChip({
    super.key,
    required this.surah,
    required this.ayah,
    this.color,
  });

  final int surah;
  final int ayah;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.book_1, size: AppIconSize.xs, color: accent),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(
            '${SurahCatalog.instance.nameOf(surah)} $surah:$ayah',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One memorization record: what was memorized, its type and its grade.
class HifdEntryCard extends StatelessWidget {
  const HifdEntryCard({
    super.key,
    required this.entry,
    this.studentName,
    this.onTap,
    this.showDate = false,
    this.dateLabel,
  });

  final HifdEntry entry;
  final String? studentName;
  final VoidCallback? onTap;
  final bool showDate;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = HifdType.color(entry.type);
    final gradeColor = HifdGrade.color(entry.grade);
    final range = formatSurahRange(
      entry.surahFrom,
      entry.ayahFrom,
      entry.surahTo,
      entry.ayahTo,
    );

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel:
          '${HifdType.label(entry.type)}، $range، ${HifdGrade.label(entry.grade)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.allMd,
                ),
                child: Icon(
                  entry.type == HifdType.jadid
                      ? Iconsax.document
                      : Iconsax.refresh,
                  size: AppIconSize.sm,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (studentName != null)
                      Text(
                        studentName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    Text(
                      range,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.quranSurahName.copyWith(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                        fontFamilyFallback: AppTypography.quranFallback,
                      ),
                    ),
                    if (showDate && dateLabel != null)
                      Text(
                        dateLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge(
                label: HifdGrade.label(entry.grade),
                color: gradeColor,
                icon: HifdGrade.icon(entry.grade),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppDotBadge(label: HifdType.label(entry.type), color: typeColor),
              AppDotBadge(
                label:
                    '${SurahCatalog.instance.ayahCountOf(entry.surahFrom)} آية في ${SurahCatalog.instance.shortNameOf(entry.surahFrom)}',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact summary of what a student memorized today (or on a given date).
class HifdProgressCard extends StatelessWidget {
  const HifdProgressCard({
    super.key,
    required this.studentName,
    required this.entries,
    this.onTap,
    this.attendanceStatus,
    this.emptyHint = 'لم يُسجَّل تحفيظ بعد',
  });

  final String studentName;
  final List<HifdEntry> entries;
  final VoidCallback? onTap;
  final String? attendanceStatus;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = attendanceStatus == null
        ? 'لم يُسجّل'
        : AttendanceStatus.label(attendanceStatus!);
    final statusColor = attendanceStatus == null
        ? Theme.of(context).colorScheme.outline
        : AttendanceStatus.color(attendanceStatus!);

    if (entries.isEmpty) {
      return AppCard(
        onTap: onTap,
        variant: AppCardVariant.outlined,
        padding: const EdgeInsets.all(AppSpacing.md),
        semanticLabel: '$studentName، $emptyHint',
        child: Row(
          children: [
            AppAvatar(
              name: studentName,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          emptyHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AppBadge(
                        label: statusLabel,
                        color: statusColor,
                        dense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              size: AppIconSize.md,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      );
    }

    final jadid = entries.where((e) => e.type == HifdType.jadid).toList();
    final muraja3a = entries.where((e) => e.type == HifdType.muraja3a).toList();
    final bestGrade = entries
        .map((e) => e.grade)
        .reduce((a, b) => a > b ? a : b);

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: '$studentName، تم تسجيل ${entries.length} مقدار',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: studentName, color: HifdGrade.color(bestGrade)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  AppBadge(
                    label: statusLabel,
                    color: statusColor,
                    dense: true,
                  ),
                  AppBadge(
                    label: HifdGrade.label(bestGrade),
                    color: HifdGrade.color(bestGrade),
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in entries.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  AppDotBadge(
                    label: HifdType.label(entry.type),
                    color: HifdType.color(entry.type),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      formatSurahRange(
                        entry.surahFrom,
                        entry.ayahFrom,
                        entry.surahTo,
                        entry.ayahTo,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (entries.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '+ ${entries.length - 2} مقدار آخر',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (jadid.isNotEmpty || muraja3a.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                if (jadid.isNotEmpty) 'جديد ${jadid.length}',
                if (muraja3a.isNotEmpty) 'مراجعة ${muraja3a.length}',
              ].join(' • '),
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

/// Grade picker rendered as three large, unmistakable options.
class HifdGradeSelector extends StatelessWidget {
  const HifdGradeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final itemWidth = (constraints.maxWidth - gap * 2) / 3;
        return Row(
          children: [
            for (var i = 0; i < HifdGrade.all.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                child: _GradeOption(
                  grade: HifdGrade.all[i],
                  selected: value == HifdGrade.all[i],
                  onTap: () => onChanged(HifdGrade.all[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GradeOption extends StatelessWidget {
  const _GradeOption({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final int grade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = HifdGrade.color(grade);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      selected: selected,
      button: true,
      label: HifdGrade.label(grade),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: selected ? color : theme.colorScheme.outline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  HifdGrade.icon(grade),
                  size: AppIconSize.md,
                  color: selected ? color : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  HifdGrade.label(grade),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? color
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

/// Memorization type selector: جديد / مراجعة.
class HifdTypeSelector extends StatelessWidget {
  const HifdTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Row(
          children: [
            for (final type in const [HifdType.jadid, HifdType.muraja3a]) ...[
              if (type != HifdType.jadid) const SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                child: _TypeOption(
                  type: type,
                  selected: value == type,
                  onTap: () => onChanged(type),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = HifdType.color(type);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      selected: selected,
      button: true,
      label: HifdType.label(type),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: selected ? color : theme.colorScheme.outline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HifdType.label(type),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? color : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  HifdType.description(type),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
