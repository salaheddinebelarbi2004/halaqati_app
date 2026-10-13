import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../data/surah_catalog.dart';
import '../models/settings.dart';
import '../models/student.dart';
import '../services/pdf_service.dart';
import '../services/ranking_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_badges.dart';
import '../widgets/app_card.dart';
import '../widgets/app_metrics.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';

/// Grade labels used in the Hifd ranking cards (3 = best).
const _gradeLabels = {3: 'ممتاز', 2: 'جيد', 1: 'يحتاج مراجعة'};

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

  ReportPeriod _period = ReportPeriod.monthly;
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

  /// Opens the per-student report. The ranking entry is merged on top of the
  /// base report so the detail screen shows exactly the same scores and ranks
  /// as the ranking lists.
  void _openStudentReport(
    BuildContext context,
    Student student,
    ReportData data,
    AppSettings settings,
    Map<String, dynamic> rankings,
  ) {
    final base = RankingService.studentReport(
      student: student,
      attendance: data.attendance,
      hifdEntries: data.hifdEntries,
      settings: settings,
      start: _startDate,
      end: _endDate,
    );
    final entry = _list(rankings, 'overall_ranking').firstWhere(
      (e) => (e['student'] as Student).id == student.id,
      orElse: () => <String, dynamic>{},
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudentDetailScreen(report: {...base, ...entry}),
      ),
    );
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
    final data = async.valueOrNull;
    final rankings = data?.rankings(
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
                        message:
                            'تعذّر تحميل التقارير. تحقّق من الاتصال ثم أعد المحاولة.',
                        onRetry: () =>
                            ref.invalidate(reportDataProvider(period)),
                      )
                    : _list(rankings, 'overall_ranking').isEmpty
                        ? const EmptyState(
                            icon: Iconsax.chart,
                            title: 'لا توجد بيانات',
                            message:
                                'سجّل الحضور والتحفيظ أولاً ليظهر الترتيب هنا.',
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
                                  sessions:
                                      rankings!['total_sessions'] as int? ?? 0,
                                  rangeLabel: _period.rangeLabel,
                                  onStudentTap: (student) => _openStudentReport(
                                    context,
                                    student,
                                    data!,
                                    settings,
                                    rankings,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sectionGap),
                                _RankingSection(
                                  title: 'الأفضل في الحضور',
                                  icon: Iconsax.calendar_tick,
                                  color: AppColors.statusPresent,
                                  entries: _list(rankings, 'hodor_ranking'),
                                  scoreKey: 'hodor_score',
                                  valueOf: (e) =>
                                      '${e['attended']}/${e['expected_sessions']} • حاضر ${e['present']}، متأخر ${e['late']}، غائب ${e['absent']}',
                                  onStudentTap: (student) => _openStudentReport(
                                    context,
                                    student,
                                    data!,
                                    settings,
                                    rankings,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sectionGap),
                                _HifdRankingSection(
                                  entries: _list(rankings, 'hifd_ranking'),
                                  onStudentTap: (student) => _openStudentReport(
                                    context,
                                    student,
                                    data!,
                                    settings,
                                    rankings,
                                  ),
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
    required this.onStudentTap,
  });

  final List<Map<String, dynamic>> entries;
  final int sessions;
  final String rangeLabel;
  final ValueChanged<Student> onStudentTap;

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
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _LeaderRow(
                  rank: i + 1,
                  student: top[i]['student'] as Student,
                  score: (top[i]['overall_score'] as double) / 100,
                  caption:
                      'تحفيظ ${(top[i]['hifd_score'] as double).round()}% • حضور ${top[i]['attended']}/${top[i]['expected_sessions']}',
                  onTap: () => onStudentTap(top[i]['student'] as Student),
                ),
              ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'الترتيب حسب النتيجة الموزونة، ثم الحصص المسجّلة وعدد سجلات التحفيظ.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
    required this.onStudentTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> entries;
  final String scoreKey;
  final String Function(Map<String, dynamic>) valueOf;
  final ValueChanged<Student> onStudentTap;

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
                    onTap: () =>
                        onStudentTap(visible[i]['student'] as Student),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Detailed Hifd ranking: one card per student with records, sessions, ayahs,
/// grade distribution and the quality / volume breakdown of the score.
class _HifdRankingSection extends StatelessWidget {
  const _HifdRankingSection({
    required this.entries,
    required this.onStudentTap,
  });

  final List<Map<String, dynamic>> entries;
  final ValueChanged<Student> onStudentTap;

  static const int limit = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = entries
        .where((e) => (e['hifdh_records'] as int) > 0)
        .take(limit)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Iconsax.book_1, size: AppIconSize.sm, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'الأفضل في التحفيظ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            'النتيجة = ٧٠٪ جودة (متوسط التقييم) + ٣٠٪ كمية (عدد السجلات مقارنة بالأكثر حفظاً).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'لا توجد سجلات تحفيظ في هذه الفترة',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final e in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: _HifdRankCard(
                entry: e,
                onTap: () => onStudentTap(e['student'] as Student),
              ),
            ),
      ],
    );
  }
}

class _HifdRankCard extends StatelessWidget {
  const _HifdRankCard({required this.entry, required this.onTap});

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final student = entry['student'] as Student;
    final grades = (entry['grade_counts'] as Map).cast<int, int>();
    final records = entry['hifdh_records'] as int;
    final ayahs = entry['hifdh_ayahs'] as int;
    final avg = entry['avg_grade'] as double;
    final last = entry['last_hifdh_date'] as String?;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RankPill(rank: entry['hifd_rank'] as int),
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
                      if (last != null)
                        Text(
                          'آخر تسميع: ${DateFormat.yMMMd('ar').format(DateTime.parse(last))}',
                          style: muted,
                        ),
                    ],
                  ),
                ),
                ScoreRing(
                  value: (entry['hifd_score'] as double) / 100,
                  size: 44,
                  label: '${(entry['hifd_score'] as double).round()}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                AppBadge(
                  label: '$records سجل',
                  color: AppColors.gold,
                  dense: true,
                ),
                AppBadge(
                  label: '${entry['hifdh_sessions']} حصة',
                  color: AppColors.gold,
                  dense: true,
                ),
                if (ayahs > 0)
                  AppBadge(
                    label: '$ayahs آية',
                    color: AppColors.gold,
                    dense: true,
                  ),
                AppBadge(
                  label: 'متوسط ${avg.toStringAsFixed(1)} / ٣',
                  color: HifdGrade.color(avg.round().clamp(1, 3).toInt()),
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Grade distribution bar.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    for (final g in [3, 2, 1])
                      if ((grades[g] ?? 0) > 0)
                        Expanded(
                          flex: grades[g]!,
                          child: Container(color: HifdGrade.color(g)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                for (final g in [3, 2, 1])
                  if ((grades[g] ?? 0) > 0) '${_gradeLabels[g]} ${grades[g]}',
              ].join(' • '),
              style: muted,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'الجودة ${(entry['hifd_quality'] as double).round()}% • الكمية ${(entry['hifd_volume'] as double).round()}%',
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.student,
    required this.score,
    required this.caption,
    this.onTap,
  });

  final int rank;
  final Student student;
  final double score;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
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
              ScoreRing(
                value: score,
                size: 40,
                label: '${(score * 100).round()}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.student,
    required this.score,
    required this.caption,
    this.onTap,
    required this.color,
  });

  final int rank;
  final Student student;
  final double score;
  final String caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Padding(
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
                child: AppProgressBar(
                  value: score,
                  color: color,
                  showLabel: false,
                ),
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
        ),
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final student = report['student'] as Student?;
    final ranges = (report['hifd_ranges'] as List?) ?? const [];
    final statusCounts =
        (report['status_counts'] as Map?)?.cast<String, int>() ??
            const <String, int>{};
    final surahs = (report['surahs'] as List?)?.cast<int>() ?? const <int>[];
    final gradeCounts =
        (report['grade_counts'] as Map?)?.cast<int, int>() ??
            const <int, int>{};
    final ayahs = report['hifdh_ayahs'] as int? ?? 0;
    final quality = report['hifd_quality'] as double?;
    final volume = report['hifd_volume'] as double?;

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
                        label: 'نسبة الحضور',
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
                        label: 'الحاضرون / الحصص المسجّلة',
                        value:
                            '${report['attended']}/${report['expected_sessions']}',
                        icon: Iconsax.calendar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تفاصيل الحضور',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final status in statusCounts.entries)
                      AppBadge(
                        label:
                            '${status.key == 'present' ? 'حاضر' : status.key == 'late' ? 'متأخر' : status.key == 'absent' ? 'غائب' : status.key == 'excused' ? 'بعذر' : status.key}: ${status.value}',
                        color: AttendanceStatus.color(status.key),
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'الحصص المسجّلة غير المعذورة: ${report['expected_sessions']}. لا تُحتسب الأيام غير المسجّلة غياباً.',
                  style: muted,
                ),
                if (report['hodor_rank'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'الترتيب في الحضور: ${report['hodor_rank']}',
                    style: muted,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ملخص التحفيظ',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${report['hifdh_records']} سجل في ${report['hifdh_sessions']} حصص • متوسط التقييم ${(report['avg_grade'] as double).toStringAsFixed(1)} من ٣',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (ayahs > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('عدد الآيات: $ayahs', style: muted),
                ],
                if (gradeCounts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      for (final g in [3, 2, 1])
                        if ((gradeCounts[g] ?? 0) > 0)
                          '${_gradeLabels[g]} ${gradeCounts[g]}',
                    ].join(' • '),
                    style: muted,
                  ),
                ],
                if (quality != null && volume != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'الجودة ${quality.round()}% • الكمية ${volume.round()}%',
                    style: muted,
                  ),
                ],
                if (report['hifd_rank'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'الترتيب في التحفيظ: ${report['hifd_rank']} • الترتيب العام: ${report['overall_rank']}',
                      style: muted,
                    ),
                  ),
                if (surahs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'السور: ${surahs.map(SurahCatalog.instance.nameOf).join('، ')}',
                    textDirection: ui.TextDirection.rtl,
                    style: AppTypography.quranSurahName.copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text(
            'سجل التحفيظ حسب التاريخ',
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
                  'لا توجد إدخالات تحفيظ خلال هذه الفترة',
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