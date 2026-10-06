import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../data/surah_catalog.dart';
import '../models/settings.dart';
import '../models/student.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_badges.dart';
import '../widgets/app_card.dart';
import '../widgets/app_metrics.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';

/// Period selector: weekly / monthly / term / all time.
enum ReportPeriod {
  weekly('أسبوعي'),
  monthly('شهري'),
  term('الفصل'),
  total('الإجمالي');

  const ReportPeriod(this.label);

  final String label;

  DateTime startFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportPeriod.weekly => today.subtract(Duration(days: now.weekday - 1)),
      ReportPeriod.monthly => DateTime(now.year, now.month, 1),
      ReportPeriod.term => DateTime(now.year, now.month - 3, 1),
      ReportPeriod.total => DateTime(2020),
    };
  }

  String get rangeLabel {
    final start = startFrom(DateTime.now());
    final end = DateTime.now();
    return '${DateFormat.yMMMd('ar').format(start)} — ${DateFormat.yMMMd('ar').format(end)}';
  }
}

/// Rankings and exports. Read-only by design — no data is mutated here.
///
/// A period costs three round trips: the roster, the attendance rows and the
/// memorization rows, all paged. The old implementation asked the database
/// once per student per metric.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _pdfService = PdfService();

  ReportPeriod _period = ReportPeriod.weekly;
  bool _exporting = false;

  /// Midnight-normalised on purpose. `reportDataProvider` is keyed on the
  /// period record, so a `DateTime.now()` carrying a time component would mint a
  /// new provider — and a fresh fetch — on every rebuild, pinning the screen on
  /// the loading circle. Day granularity is what the queries and
  /// `dateInRange` already use.
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _startDate => _period.startFrom(_today);
  DateTime get _endDate => _today;

  Future<void> _exportPdf(Map<String, dynamic> rankings) async {
    setState(() => _exporting = true);
    try {
      await _pdfService.generateAndPrintReport(
        'تقرير ${_period.label}',
        rankings['hodor_ranking'] as List<Map<String, dynamic>>,
        rankings['hifd_ranking'] as List<Map<String, dynamic>>,
        rankings['overall_ranking'] as List<Map<String, dynamic>>,
        _startDate,
        _endDate,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static List<Map<String, dynamic>> _list(
    Map<String, dynamic>? rankings,
    String key,
  ) =>
      (rankings?[key] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    final period = (start: _startDate, end: _endDate);
    final async = ref.watch(reportDataProvider(period));
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    // The ranking maths runs over the rows already in memory, so it costs
    // nothing extra to recompute when the settings stream pushes new weights.
    final rankings = async.valueOrNull?.rankings(
      settings,
      _startDate,
      _endDate,
    );

    return AppScaffold(
      title: 'التقارير',
      actions: [
        AppIconButton(
          icon: Iconsax.export,
          tooltip: 'تصدير PDF',
          onPressed: (rankings == null || _exporting)
              ? null
              : () => _exportPdf(rankings),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _PeriodSelector(
              value: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ),
          Expanded(
            child: async.isLoading
                ? const AppLoadingView(message: 'جارٍ حساب التقارير')
                : async.hasError
                ? ErrorState(
                    message: '${async.error}',
                    onRetry: () => ref.invalidate(reportDataProvider(period)),
                  )
                : _list(rankings, 'overall_ranking').isEmpty
                ? const EmptyState(
                    icon: Iconsax.chart,
                    title: 'لا توجد بيانات',
                    message: 'سجّل الحضور والتحفيظ أولاً ليظهر الترتيب هنا.',
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(reportDataProvider(period)),
                    child: ListView(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.huge,
                      ),
                      children: [
                        _OverallCard(
                          entries: _list(rankings, 'overall_ranking'),
                          sessions: rankings!['total_sessions'] as int? ?? 0,
                          rangeLabel: _period.rangeLabel,
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        _RankingSection(
                          title: 'الأفضل في الحضور',
                          icon: Iconsax.calendar_tick,
                          color: AppColors.statusPresent,
                          entries: _list(rankings, 'hodor_ranking'),
                          scoreKey: 'hodor_score',
                          valueOf: (e) => '${e['present']}/${e['total_days']}',
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        _RankingSection(
                          title: 'الأفضل في التحفيظ',
                          icon: Iconsax.book_1,
                          color: AppColors.gold,
                          entries: _list(rankings, 'hifd_ranking'),
                          scoreKey: 'hifd_score',
                          valueOf: (e) =>
                              'متوسط ${(e['avg_grade'] as double).toStringAsFixed(1)} من ٣',
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final ReportPeriod value;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSizes.buttonHeightSm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: ReportPeriod.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final period = ReportPeriod.values[index];
          final selected = period == value;
          return Material(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: AppRadius.allPill,
            child: InkWell(
              onTap: () => onChanged(period),
              borderRadius: AppRadius.allPill,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.allPill,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                child: Text(
                  period.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.entries,
    required this.sessions,
    required this.rangeLabel,
  });

  final List<Map<String, dynamic>> entries;
  final int sessions;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = entries.take(3).toList();

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الترتيب العام',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$sessions حصة',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rangeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const AppCardDivider(),
          if (top.isEmpty)
            Text(
              'لا يوجد طلاب',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final entry in top)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _LeaderRow(
                  rank: top.indexOf(entry) + 1,
                  student: entry['student'] as Student,
                  score: (entry['overall_score'] as double) / 100,
                  caption:
                      'تحفيظ ${(entry['hifd_score'] as double).round()}% • حضور ${(entry['hodor_score'] as double).round()}%',
                ),
              ),
        ],
      ),
    );
  }
}

class _RankingSection extends StatelessWidget {
  const _RankingSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.scoreKey,
    required this.valueOf,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> entries;
  final String scoreKey;
  final String Function(Map<String, dynamic>) valueOf;

  /// How many rows to show per ranking.
  static const int limit = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = entries.take(limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: AppIconSize.sm, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'لا توجد بيانات',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: theme.colorScheme.outline),
                  _RankRow(
                    rank: i + 1,
                    student: visible[i]['student'] as Student,
                    score: (visible[i][scoreKey] as double) / 100,
                    color: color,
                    caption: valueOf(visible[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.student,
    required this.score,
    required this.caption,
  });

  final int rank;
  final Student student;
  final double score;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        RankPill(rank: rank, size: 30),
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
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        ScoreRing(value: score, size: 40, label: '${(score * 100).round()}'),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.student,
    required this.score,
    required this.caption,
    required this.color,
  });

  final int rank;
  final Student student;
  final double score;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          RankPill(rank: rank),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 56,
            child: AppProgressBar(value: score, color: color, showLabel: false),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 42,
            child: Text(
              '${(score * 100).round()}%',
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-student report with the memorization history for the chosen period.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = report['student'] as Student?;
    final ranges = (report['hifd_ranges'] as List?) ?? const [];

    return AppScaffold(
      title: student?.fullName ?? 'تفاصيل الطالب',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'الحضور',
                        value: '${(report['hodor_score'] as double).round()}%',
                        color: AppColors.statusPresent,
                        icon: Iconsax.calendar_tick,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'التحفيظ',
                        value: '${(report['hifd_score'] as double).round()}%',
                        color: AppColors.gold,
                        icon: Iconsax.book_1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'المحصّل',
                        value:
                            '${(report['overall_score'] as double).round()}%',
                        icon: Iconsax.award,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'الأيام',
                        value: '${report['present']}/${report['total_days']}',
                        icon: Iconsax.calendar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text(
            'سجل التحفيظ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (ranges.isEmpty)
            AppCard(
              variant: AppCardVariant.outlined,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Text(
                  'لا توجد إدخالات',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final row in ranges)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: _HifdRangeRow(entry: row),
              ),
        ],
      ),
    );
  }
}

class _HifdRangeRow extends StatelessWidget {
  const _HifdRangeRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = entry['type'] as String;
    final grade = entry['grade'] as int;
    final range = formatSurahRange(
      entry['surah_from'] as int,
      entry['ayah_from'] as int,
      entry['surah_to'] as int,
      entry['ayah_to'] as int,
    );
    final date = entry['date'] as String;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HifdGrade.color(grade).withValues(alpha: 0.12),
              borderRadius: AppRadius.allMd,
            ),
            child: Icon(
              HifdGrade.icon(grade),
              size: AppIconSize.sm,
              color: HifdGrade.color(grade),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.quranSurahName.copyWith(
                    fontSize: 15,
                    fontFamilyFallback: AppTypography.quranFallback,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${HifdType.label(type)} • ${DateFormat.yMMMd('ar').format(DateTime.parse(date))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
