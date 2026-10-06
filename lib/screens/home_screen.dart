import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../core/app_responsive.dart';
import '../core/providers.dart';
import '../models/hifd_entry.dart';
import '../models/student.dart';
import '../models/teacher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_metrics.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/hifd_widgets.dart';
import '../widgets/theme_toggle.dart';

/// Teacher dashboard.
///
/// Answers one question first — "what should I do right now?" — then shows
/// today's numbers, today's memorization, and quick access to the rest.
/// Nothing here is decorative for its own sake.
///
/// Every figure comes from a realtime subscription, so a session marked on
/// another device shows up here without a pull-to-refresh.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(teacherProvider).valueOrNull;
    final students = ref.watch(activeStudentsProvider);
    final today = todayKey();

    final attendance = ref.watch(attendanceProvider(today));
    final hifd = ref.watch(hifdEntriesProvider(today));

    final todayAttendance = {
      for (final a in attendance.valueOrNull ?? const []) a.studentId: a.status,
    };
    final todayHifd = hifd.valueOrNull ?? const <HifdEntry>[];

    final presentCount = todayAttendance.values
        .where((s) => s == 'present')
        .length;
    final unmarkedCount = students
        .where((s) => todayAttendance[s.id] == null)
        .length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // Nothing is cached locally, so pulling just re-reads from the cloud.
          onRefresh: () async {
            ref.invalidate(attendanceProvider(today));
            ref.invalidate(hifdEntriesProvider(today));
          },
          child: ContentShell(
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.huge,
              ),
              children: [
                _TopBar(teacher: teacher, greeting: _greeting),
                const SizedBox(height: AppSpacing.xl),
                _TodaySummaryCard(
                  present: presentCount,
                  unmarked: unmarkedCount,
                  total: students.length,
                  hifdCount: todayHifd.length,
                  onAttendanceTap: () => _open(context, '/attendance'),
                  onHifdTap: () => _open(context, '/hifd'),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                const SectionHeader(
                  title: 'الإجراءات السريعة',
                  subtitle: 'أكثر ما تستخدمه يومياً',
                ),
                _QuickActions(
                  onAttendance: () => _open(context, '/attendance'),
                  onHifd: () => _open(context, '/hifd'),
                  onStudents: () => _open(context, '/students'),
                  onReports: () => _open(context, '/reports'),
                ),
                if (students.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sectionGap),
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: EmptyState(
                      compact: true,
                      icon: Iconsax.people,
                      title: 'لا يوجد طلاب بعد',
                      message: 'ابدأ بإضافة أول طالب إلى حلقتك.',
                      actionLabel: 'إضافة طالب',
                      onAction: () => _open(context, '/students'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.sectionGap),
                  SectionHeader(
                    title: 'متابعة الطلاب',
                    subtitle: 'نظرة سريعة على تحفيظ اليوم',
                    action: TextButton(
                      onPressed: () => _open(context, '/students'),
                      child: const Text('عرض الكل'),
                    ),
                  ),
                  _StudentProgressList(
                    students: students,
                    entriesByStudent: _groupHifdByStudent(todayHifd),
                    onTap: () => _open(context, '/students'),
                    limit: students.length > 3 ? 3 : students.length,
                  ),
                ],
                if (todayHifd.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sectionGap),
                  const SectionHeader(
                    title: 'محفوظ اليوم',
                    subtitle: 'ما تم تسجيله في هذه الحلقة',
                  ),
                  for (final entry in todayHifd.take(4))
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.cardGap,
                      ),
                      child: HifdEntryCard(entry: entry, showDate: false),
                    ),
                ],
                const SizedBox(height: AppSpacing.sectionGap),
                _HalaqaInfoCard(teacher: teacher),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Map<String?, List<HifdEntry>> _groupHifdByStudent(
    List<HifdEntry> entries,
  ) {
    final map = <String?, List<HifdEntry>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.studentId, () => <HifdEntry>[]).add(entry);
    }
    return map;
  }

  static String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'طاب يومك';
    return 'مساء الخير';
  }

  static void _open(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.teacher, required this.greeting});

  final Teacher? teacher;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const AppLogo(size: 34, alignment: Alignment.centerRight),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                teacher?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const ThemeToggleButton(),
        const SizedBox(width: AppSpacing.sm),
        AppIconButton(
          icon: Iconsax.setting_2,
          tooltip: 'الإعدادات',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.present,
    required this.unmarked,
    required this.total,
    required this.hifdCount,
    required this.onAttendanceTap,
    required this.onHifdTap,
  });

  final int present;
  final int unmarked;
  final int total;
  final int hifdCount;
  final VoidCallback onAttendanceTap;
  final VoidCallback onHifdTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : present / total;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حضور اليوم',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$present',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unmarked > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$unmarked لم يُسجَّل بعد',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ScoreRing(
                value: ratio,
                size: 62,
                color: ratio >= 0.8
                    ? AppColors.success
                    : theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppProgressBar(
            value: ratio,
            showLabel: false,
            color: ratio >= 0.8 ? AppColors.success : null,
          ),
          const AppCardDivider(),
          InkWell(
            onTap: onHifdTap,
            borderRadius: AppRadius.allMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: AppRadius.allMd,
                    ),
                    child: const Icon(
                      Iconsax.book_1,
                      size: AppIconSize.sm,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'تحفيظ اليوم',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    hifdCount == 0 ? 'لا يوجد' : '$hifdCount مقدار',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: AppIconSize.md,
                    color: theme.colorScheme.onSurfaceVariant,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAttendance,
    required this.onHifd,
    required this.onStudents,
    required this.onReports,
  });

  final VoidCallback onAttendance;
  final VoidCallback onHifd;
  final VoidCallback onStudents;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      QuickActionTile(
        label: 'تسجيل الحضور',
        caption: 'بدء أو تعديل حضور اليوم',
        icon: Iconsax.calendar_tick,
        onTap: onAttendance,
      ),
      QuickActionTile(
        label: 'التحفيظ',
        caption: 'تسجيل جديد ومراجعة',
        icon: Iconsax.book_1,
        color: AppColors.gold,
        onTap: onHifd,
      ),
      QuickActionTile(
        label: 'الطلاب',
        caption: 'الإضافة والتعديل والمتابعة',
        icon: Iconsax.people,
        onTap: onStudents,
      ),
      QuickActionTile(
        label: 'التقارير والترتيب',
        caption: 'مقارنة أداء الطلاب',
        icon: Iconsax.ranking,
        onTap: onReports,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, more on wider windows.
        final columns = constraints.maxWidth >= 720 ? 2 : 1;
        if (columns == 1) {
          return Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.cardGap),
                actions[i],
              ],
            ],
          );
        }
        final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final a in actions) SizedBox(width: tileWidth, child: a),
          ],
        );
      },
    );
  }
}

class _StudentProgressList extends StatelessWidget {
  const _StudentProgressList({
    required this.students,
    required this.entriesByStudent,
    required this.onTap,
    this.limit = 4,
  });
  final List<Student> students;
  final Map<String?, List<HifdEntry>> entriesByStudent;
  final VoidCallback onTap;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final preview = students.take(limit).toList();
    return Column(
      children: [
        for (var i = 0; i < preview.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.cardGap),
          HifdProgressCard(
            studentName: preview[i].fullName,
            entries: entriesByStudent[preview[i].id] ?? const <HifdEntry>[],
            onTap: onTap,
          ),
        ],
        if (students.length > limit) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'عرض كل الطلاب (${students.length})',
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
            onPressed: onTap,
          ),
        ],
      ],
    );
  }
}

class _HalaqaInfoCard extends StatelessWidget {
  const _HalaqaInfoCard({required this.teacher});

  final Teacher? teacher;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.home,
                size: AppIconSize.sm,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'معلومات الحلقة',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const AppCardDivider(vertical: AppSpacing.md),
          AppInfoRow(
            label: 'المدرسة',
            value: teacher?.madrassaName ?? '—',
            icon: Iconsax.building,
          ),
          AppInfoRow(
            label: 'الحلقة',
            value: teacher?.halaqaName ?? '—',
            icon: Iconsax.group,
          ),
          if (teacher?.phone != null && teacher!.phone!.isNotEmpty)
            AppInfoRow(
              label: 'الجوال',
              value: teacher!.phone!,
              icon: Iconsax.call,
            ),
        ],
      ),
    );
  }
}
