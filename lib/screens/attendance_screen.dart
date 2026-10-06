import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../core/date_only.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_badges.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_metrics.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/attendance_tile.dart';
import '../widgets/date_navigator.dart';

/// Daily attendance.
///
/// Flow: pick a day → press "بدء التسجيل" → tap a status per student →
/// press "حفظ". The buffer stays local until saved, so a half-finished
/// session is never written by accident, and the whole save is one upsert
/// rather than a query per student.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String?, String?> _pendingChanges = const {};
  bool _readOnly = false;
  bool _editing = false;
  bool _saving = false;

  bool get _isEditable {
    final diff = DateTime.now().difference(_selectedDate).inDays;
    return diff >= 0 && diff <= 2;
  }

  bool get _canGoForward {
    final today = DateTime.now();
    return _selectedDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  Future<void> _changeDate(DateTime value) async {
    if (_editing && !await _confirmDiscard()) return;
    setState(() {
      _selectedDate = value;
      _pendingChanges = const {};
      _editing = false;
      _readOnly = !_isEditable;
    });
  }

  Future<bool> _confirmDiscard() => AppDialog.confirm(
    context,
    title: 'تجاهل التعديلات؟',
    message: 'لديك تغييرات لم تُحفظ في هذه الجلسة. هل تريد المتابعة دون حفظها؟',
    confirmLabel: 'تجاهل',
    cancelLabel: 'العودة',
    destructive: true,
  );

  void _startEditing(Map<String?, String?> saved) {
    setState(() {
      _editing = true;
      _pendingChanges = Map.of(saved);
    });
  }

  void _setStatus(String? studentId, String status) {
    setState(() => _pendingChanges[studentId] = status);
  }

  static int _changedCount(
    Map<String?, String?> pending,
    Map<String?, String?> saved,
  ) {
    var count = 0;
    for (final entry in pending.entries) {
      if (entry.value != saved[entry.key]) count++;
    }
    return count;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final rows = [
      for (final entry in _pendingChanges.entries)
        if (entry.value != null && entry.key != null)
          Attendance(
            studentId: entry.key!,
            date: _selectedDate,
            status: entry.value!,
          ),
    ];

    try {
      await ref.read(dataServiceProvider).saveAttendance(rows);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _pendingChanges = const {};
        _saving = false;
      });
      AppSnack.success(context, 'تم حفظ الحضور');
    } on AppException catch (error) {
      // Not queued, not retried in the background: the buffer is still on
      // screen so the teacher can press save again.
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, error.message);
    }
  }

  static ({int present, int absent, int late, int excused, int unmarked})
  _countsOf(List<Student> students, Map<String?, String?> map) {
    var present = 0, absent = 0, late = 0, excused = 0, unmarked = 0;
    for (final student in students) {
      switch (map[student.id]) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'late':
          late++;
        case 'excused':
          excused++;
        default:
          unmarked++;
      }
    }
    return (
      present: present,
      absent: absent,
      late: late,
      excused: excused,
      unmarked: unmarked,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      locale: const Locale('ar'),
      helpText: 'اختر يوم الحلقة',
    );
    if (picked != null) _changeDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(activeStudentsProvider);
    final day = dateOnly(_selectedDate);
    final async = ref.watch(attendanceProvider(day));

    // The saved statuses arrive over the wire, so derive them rather than
    // keeping a second copy that could drift.
    final savedMap = <String?, String?>{
      for (final a in async.valueOrNull ?? const <Attendance>[])
        a.studentId: a.status,
    };
    final statusMap = _editing ? _pendingChanges : savedMap;
    final counts = _countsOf(students, statusMap);

    if (async.hasError && !async.hasValue) {
      return AppScaffold(
        title: 'الحضور',
        body: ErrorState(
          message: '${async.error}',
          onRetry: () => ref.invalidate(attendanceProvider(day)),
        ),
      );
    }

    return AppScaffold(
      title: 'الحضور',
      body: Column(
        children: [
          DateNavigator(
            date: _selectedDate,
            readOnly: _readOnly,
            canGoForward: _canGoForward,
            onChanged: _changeDate,
            onPickDate: _pickDate,
          ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StatusSummaryBar(
                items: [
                  (
                    label: AttendanceStatus.label('present'),
                    count: counts.present,
                    color: AppColors.statusPresent,
                  ),
                  (
                    label: AttendanceStatus.label('absent'),
                    count: counts.absent,
                    color: AppColors.statusAbsent,
                  ),
                  (
                    label: AttendanceStatus.label('late'),
                    count: counts.late,
                    color: AppColors.statusLate,
                  ),
                  (
                    label: AttendanceStatus.label('excused'),
                    count: counts.excused,
                    color: AppColors.statusExcused,
                  ),
                  if (counts.unmarked > 0)
                    (
                      label: 'لم يُسجَّل',
                      count: counts.unmarked,
                      color: AppColors.statusNone,
                    ),
                ],
              ),
            ),
          ],
          if (_isEditable && !_readOnly) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _editing
                  ? Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'حفظ الحضور',
                            icon: Iconsax.save_2,
                            expand: true,
                            loading: _saving,
                            onPressed:
                                _changedCount(_pendingChanges, savedMap) == 0
                                ? null
                                : _saveAll,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'إلغاء',
                          variant: AppButtonVariant.outline,
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _editing = false;
                                  _pendingChanges = const {};
                                }),
                        ),
                      ],
                    )
                  : AppButton(
                      label: 'بدء تسجيل الحضور',
                      icon: Iconsax.play,
                      expand: true,
                      onPressed: students.isEmpty
                          ? null
                          : () => _startEditing(savedMap),
                    ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: async.isLoading && !async.hasValue
                ? const AppLoadingView(message: 'جارٍ تحميل السجل')
                : students.isEmpty
                ? EmptyState(
                    icon: Iconsax.people,
                    title: 'لا يوجد طلاب نشطون',
                    message:
                        'أضف الطلاب أولاً من شاشة الطلاب، ثم عد لتسجيل الحضور.',
                    actionLabel: 'الذهاب إلى الطلاب',
                    onAction: () =>
                        Navigator.of(context).pushNamed('/students'),
                  )
                : _StudentList(
                    students: students,
                    statusOf: (id) => statusMap[id],
                    editable: _editing,
                    onStatusSelected: _editing ? _setStatus : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  const _StudentList({
    required this.students,
    required this.statusOf,
    required this.editable,
    this.onStatusSelected,
  });

  final List<Student> students;
  final String? Function(String?) statusOf;
  final bool editable;
  final void Function(String? studentId, String status)? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: students.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (context, index) {
        final student = students[index];
        return AttendanceTile(
          student: student,
          status: statusOf(student.id),
          editable: editable,
          onStatusSelected: onStatusSelected == null
              ? null
              : (status) => onStatusSelected!(student.id, status),
        );
      },
    );
  }
}
