import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../core/date_only.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../data/surah_catalog.dart';
import '../models/hifd_entry.dart';
import '../models/student.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_badges.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_text_field.dart';
import '../widgets/date_navigator.dart';
import '../widgets/hifd_widgets.dart';
import '../widgets/app_metrics.dart';

/// Memorization (hifdh) register for a given day.
///
/// Surah names are always shown — never numbers — and ayah ranges are
/// bounded by the real ayah count of the selected surah.
class HifdScreen extends ConsumerStatefulWidget {
  const HifdScreen({super.key});

  @override
  ConsumerState<HifdScreen> createState() => _HifdScreenState();
}

class _HifdScreenState extends ConsumerState<HifdScreen> {
  final _searchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _readOnly = false;
  bool _locking = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isEditable {
    final diff = DateTime.now().difference(_selectedDate).inDays;
    return diff >= 0 && diff <= 2;
  }

  bool get _canGoForward {
    final today = DateTime.now();
    return _selectedDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  void _changeDate(DateTime value) {
    setState(() {
      _selectedDate = value;
      _readOnly = !_isEditable;
    });
  }

  List<Student> get _filtered {
    final students = ref.read(activeStudentsProvider);
    if (_query.isEmpty) return students;
    final q = _query.toLowerCase();
    return students.where((s) => s.fullName.toLowerCase().contains(q)).toList();
  }

  Future<void> _openEntryForm(Student student) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => HifdEntrySheet(
        student: student,
        date: _selectedDate,
        existingEntries: _grouped[student.id] ?? const <HifdEntry>[],
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(dataServiceProvider)
          .saveHifdEntry(
            HifdEntry(
              studentId: student.id!,
              date: _selectedDate,
              type: result['type'] as String,
              surahFrom: result['surah_from'] as int,
              ayahFrom: result['ayah_from'] as int,
              surahTo: result['surah_to'] as int,
              ayahTo: result['ayah_to'] as int,
              grade: result['grade'] as int,
            ),
          );
      ref.invalidate(reportDataProvider);
      if (!mounted) return;
      AppSnack.success(context, 'تم حفظ التحفيظ');
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    }
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

  /// Whether the app-bar lock/unlock button accepts a tap.
  ///
  /// A locked day can always be reopened; an unlocked day can only be
  /// confirmed while it is still inside the editable window.
  bool get _canToggleLock {
    if (_locking) return false;
    return _locked || _isEditable;
  }

  Future<void> _toggleLock() => _locked ? _unlockDay() : _confirmDay();

  Future<void> _confirmDay() async {
    final missing = _missingStudents;
    final ok = await AppDialog.confirm(
      context,
      title: 'اعتماد تحفيظ هذا اليوم',
      message: missing.isEmpty
          ? 'بعد الاعتماد لن تستطيع تعديل تحفيظ هذا اليوم، وستُغلق كل مقاديره نهائياً لمنع أي تغيير بعد التأكيد.'
          : 'لم يُسجَّل تحفيظ لـ ${missing.length} طالب:\n${missing.take(4).map((s) => '• ${s.fullName}').join('\n')}${missing.length > 4 ? '\n• وآخرون' : ''}\n\nبعد الاعتماد لن تستطيع تعديل هذا اليوم، وستُغلق كل مقاديره نهائياً لمنع أي تغيير بعد التأكيد.',
      confirmLabel: 'اعتماد نهائي',
      cancelLabel: 'رجوع',
      icon: Iconsax.shield_tick,
    );
    if (!ok || !mounted) return;

    setState(() => _locking = true);
    try {
      await ref.read(dataServiceProvider).lockHifdDay(_selectedDate);
      if (!mounted) return;
      AppSnack.success(context, 'تم اعتماد تحفيظ اليوم وإغلاقه');
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    } finally {
      if (mounted) setState(() => _locking = false);
    }
  }

  Future<void> _unlockDay() async {
    final ok = await AppDialog.confirm(
      context,
      title: 'إعادة فتح التعديل؟',
      message:
          'سيصبح من الممكن تعديل تحفيظ هذا اليوم مرة أخرى، وستتغير الأرقام في التقارير. '
          'استخدم هذا فقط عند وجود خطأ موثّق في التسجيل.',
      confirmLabel: 'إعادة الفتح',
      cancelLabel: 'إلغاء',
      destructive: true,
      icon: Iconsax.warning_2,
    );
    if (!ok || !mounted) return;

    setState(() => _locking = true);
    try {
      await ref.read(dataServiceProvider).unlockHifdDay(_selectedDate);
      if (!mounted) return;
      AppSnack.success(context, 'تم إعادة فتح تعديل هذا اليوم');
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    } finally {
      if (mounted) setState(() => _locking = false);
    }
  }

  /// Entries for the selected day, keyed by student.
  Map<String?, List<HifdEntry>> get _grouped {
    final grouped = <String?, List<HifdEntry>>{};
    final entries =
        ref.read(hifdEntriesProvider(dateOnly(_selectedDate))).valueOrNull ??
        const <HifdEntry>[];
    for (final entry in entries) {
      grouped.putIfAbsent(entry.studentId, () => <HifdEntry>[]).add(entry);
    }
    return grouped;
  }

  /// A confirmed day is frozen: the teacher can no longer add, change or
  /// delete anything that feeds the reports, so numbers cannot be quietly
  /// improved after the fact.
  bool get _locked =>
      ref
          .read(lockedHifdDaysProvider)
          .valueOrNull
          ?.contains(dateOnly(_selectedDate)) ??
      false;

  bool get _isFrozen => _locked || !_isEditable;

  /// Students with nothing recorded for the selected day.
  List<Student> get _missingStudents => ref
      .read(activeStudentsProvider)
      .where((s) => (_grouped[s.id] ?? const <HifdEntry>[]).isEmpty)
      .toList();

  int get _recordedCount => _grouped.values.fold(0, (a, b) => a + b.length);

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(activeStudentsProvider);
    final grouped = _grouped;
    final locked = _locked;
    final filtered = _filtered;

    return AppScaffold(
      title: 'التحفيظ',
      actions: [
        if (students.isNotEmpty)
          AppIconButton(
            icon: locked ? Iconsax.lock_1 : Iconsax.shield_tick,
            tooltip: locked ? 'إعادة فتح التعديل' : 'اعتماد وتثبيت اليوم',
            variant: locked
                ? AppButtonVariant.outline
                : AppButtonVariant.secondary,
            onPressed: _canToggleLock ? _toggleLock : null,
          ),
      ],
      body: Column(
        children: [
          DateNavigator(
            date: _selectedDate,
            readOnly: _readOnly || locked,
            canGoForward: _canGoForward,
            onChanged: _changeDate,
            onPickDate: _pickDate,
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: _LockedBanner(onUnlock: _locking ? null : _unlockDay),
            ),
          if (students.isEmpty)
            Expanded(
              child: EmptyState(
                icon: Iconsax.book_1,
                title: 'لا يوجد طلاب نشطون',
                message: 'أضف الطلاب أولاً لتتمكن من تسجيل التحفيظ.',
                actionLabel: 'الذهاب إلى الطلاب',
                onAction: () => Navigator.of(context).pushNamed('/students'),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(
                  hifdEntriesProvider(dateOnly(_selectedDate)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  children: [
                    AppSearchField(
                      controller: _searchController,
                      hint: 'ابحث عن طالب',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DayOverviewCard(
                      recorded: _recordedCount,
                      totalStudents: students.length,
                      locked: locked,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (filtered.isEmpty)
                      const EmptyState(
                        compact: true,
                        icon: Iconsax.search_normal,
                        title: 'لا توجد نتائج',
                        message: 'جرّب اسماً آخر.',
                      )
                    else
                      for (final student in filtered)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.cardGap,
                          ),
                          child: HifdProgressCard(
                            studentName: student.fullName,
                            entries: grouped[student.id] ?? const <HifdEntry>[],
                            emptyHint: _isFrozen
                                ? 'لا يوجد تحفيظ'
                                : 'اضغط لتسجيل التحفيظ',
                            onTap: _isFrozen
                                ? null
                                : () => _openEntryForm(student),
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

/// Shown above the register when the day has been confirmed: the numbers are
/// frozen and only a deliberate, logged unlock can change them again.
class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.onUnlock});

  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      variant: AppCardVariant.filled,
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      backgroundColor: AppColors.gold.withValues(alpha: 0.10),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Iconsax.lock_1,
            size: AppIconSize.md,
            color: AppColors.gold,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم اعتماد هذا اليوم وإغلاقه',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'لا يمكن تعديل التحفيظ أو إضافته بعد الاعتماد.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'فتح',
            size: AppButtonSize.small,
            variant: AppButtonVariant.outline,
            onPressed: onUnlock,
          ),
        ],
      ),
    );
  }
}

class _DayOverviewCard extends StatelessWidget {
  const _DayOverviewCard({
    required this.recorded,
    required this.totalStudents,
    this.locked = false,
  });

  final int recorded;
  final int totalStudents;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = totalStudents == 0 ? 0.0 : recorded / totalStudents;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppRadius.allMd,
            ),
            child: const Icon(
              Iconsax.book_1,
              size: AppIconSize.md,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مقدار محفوظ في هذه الجلسة',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recorded == 0
                      ? 'لم يُسجَّل تحفيظ بعد'
                      : '$recorded مقدار لـ $totalStudents طالب',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  const AppDotBadge(
                    label: 'معتمد ومقفل',
                    color: AppColors.gold,
                  ),
                ],
              ],
            ),
          ),
          if (recorded > 0)
            SizedBox(
              width: 88,
              child: AppProgressBar(
                value: ratio.clamp(0.0, 1.0),
                color: AppColors.gold,
                showLabel: false,
              ),
            ),
        ],
      ),
    );
  }
}

/// Entry form presented as a bottom sheet.
///
/// Surah selection shows Arabic names with ayah counts; ayah pickers are
/// constrained to the selected surah's real length.
class HifdEntrySheet extends StatefulWidget {
  const HifdEntrySheet({
    super.key,
    required this.student,
    required this.date,
    this.existingEntries = const <HifdEntry>[],
  });

  final Student student;
  final DateTime date;
  final List<HifdEntry> existingEntries;

  @override
  State<HifdEntrySheet> createState() => _HifdEntrySheetState();
}

class _HifdEntrySheetState extends State<HifdEntrySheet> {
  static const int _defaultSurah = 1;

  String _type = HifdType.jadid;
  int _surahFrom = _defaultSurah;
  int _ayahFrom = 1;
  int _surahTo = _defaultSurah;
  int _ayahTo = 1;
  bool _fullSurah = false;
  int _grade = 3;
  bool _ready = false;

  SurahCatalog get _catalog => SurahCatalog.instance;

  @override
  void initState() {
    super.initState();
    _syncFromExisting();
    _catalog.ensureLoaded().then((_) {
      if (!mounted) return;
      setState(() {
        _fullSurah = widget.existingEntries.isNotEmpty &&
            widget.existingEntries.first.isFullSurah(
              _catalog.ayahCountOf(widget.existingEntries.first.surahFrom),
            );
        _ready = _catalog.error == null;
      });
    });
  }

  void _syncFromExisting() {
    if (widget.existingEntries.isEmpty) return;
    final entry = widget.existingEntries.first;
    _type = entry.type;
    _surahFrom = entry.surahFrom;
    _ayahFrom = entry.ayahFrom;
    _surahTo = entry.surahTo;
    _ayahTo = entry.ayahTo;
    _grade = entry.grade;
  }

  void _setFromSurah(int surah) {
    setState(() {
      _surahFrom = surah;
      _surahTo = surah;
      _ayahFrom = 1;
      _ayahTo = _fullSurah ? _catalog.ayahCountOf(surah) : 1;
    });
  }

  void _setToSurah(int surah) {
    setState(() {
      _surahTo = surah < _surahFrom ? _surahFrom : surah;
      _fullSurah = false;
      _ayahTo = 1;
      if (_surahTo == _surahFrom && _ayahTo < _ayahFrom) {
        _ayahTo = _ayahFrom;
      }
    });
  }

  void _setFromAyah(int ayah) {
    setState(() {
      _ayahFrom = ayah;
      if (_surahFrom == _surahTo && _ayahTo < ayah) _ayahTo = ayah;
    });
  }

  void _setToAyah(int ayah) {
    setState(
      () => _ayahTo = _surahFrom == _surahTo && ayah < _ayahFrom
          ? _ayahFrom
          : ayah,
    );
  }

  void _setFullSurah(bool value) {
    setState(() {
      _fullSurah = value;
      if (value) {
        _surahTo = _surahFrom;
        _ayahFrom = 1;
        _ayahTo = _catalog.ayahCountOf(_surahFrom);
      }
    });
  }

  void _submit() {
    final fromMax = _catalog.ayahCountOf(_surahFrom);
    final toMax = _catalog.ayahCountOf(_surahTo);
    if (_surahFrom > _surahTo ||
        _ayahFrom < 1 ||
        _ayahFrom > fromMax ||
        _ayahTo < 1 ||
        _ayahTo > toMax ||
        (_surahFrom == _surahTo && _ayahFrom > _ayahTo) ||
        (_fullSurah &&
            (_surahFrom != _surahTo ||
                _ayahFrom != 1 ||
                _ayahTo != fromMax))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نطاق آيات صحيح')),
      );
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'type': _type,
      'surah_from': _surahFrom,
      'ayah_from': _ayahFrom,
      'surah_to': _surahTo,
      'ayah_to': _ayahTo,
      'grade': _grade,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.student.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'نوع التحفيظ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            HifdTypeSelector(
              value: _type,
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'المقدار المحفوظ',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_catalog.error != null)
              ErrorState(
                message: 'تعذّر تحميل أسماء السور. أعد فتح هذه الشاشة.',
                onRetry: () => _catalog.ensureLoaded().then((_) {
                  if (mounted) setState(() {});
                }),
              )
            else if (!_ready)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: AppLoadingView(),
              )
            else ...[
              _RangeRow(
                fromLabel: 'من سورة',
                toLabel: 'إلى سورة',
                surahFrom: _surahFrom,
                surahTo: _surahTo,
                onFromSurah: _setFromSurah,
                onToSurah: _setToSurah,
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                value: _fullSurah,
                onChanged: (value) => _setFullSurah(value ?? false),
                title: const Text('سورة كاملة'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              _RangeRow(
                fromLabel: 'من آية',
                toLabel: 'إلى آية',
                surahFrom: _surahFrom,
                surahTo: _surahTo,
                ayahFrom: _ayahFrom,
                ayahTo: _ayahTo,
                onFromAyah: _setFromAyah,
                onToAyah: _setToAyah,
                pickSurahs: false,
                ayahControlsEnabled: !_fullSurah,
              ),
              const SizedBox(height: AppSpacing.md),
              _RangePreview(
                surahFrom: _surahFrom,
                ayahFrom: _ayahFrom,
                surahTo: _surahTo,
                ayahTo: _ayahTo,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              'التقييم',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            HifdGradeSelector(
              value: _grade,
              onChanged: (v) => setState(() => _grade = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'حفظ',
              icon: Iconsax.save_2,
              expand: true,
              size: AppButtonSize.large,
              onPressed: _ready ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A from/to pair of pickers sharing one row on wide windows, stacked on
/// narrow ones.
class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.fromLabel,
    required this.toLabel,
    required this.surahFrom,
    required this.surahTo,
    this.ayahFrom,
    this.ayahTo,
    this.onFromAyah,
    this.onToAyah,
    this.onFromSurah,
    this.onToSurah,
    this.pickSurahs = true,
    this.ayahControlsEnabled = true,
  });

  final String fromLabel;
  final String toLabel;
  final int surahFrom;
  final int surahTo;
  final ValueChanged<int>? onFromSurah;
  final ValueChanged<int>? onToSurah;
  final int? ayahFrom;
  final int? ayahTo;
  final ValueChanged<int>? onFromAyah;
  final ValueChanged<int>? onToAyah;
  final bool pickSurahs;
  final bool ayahControlsEnabled;

  @override
  Widget build(BuildContext context) {
    final fromField = pickSurahs
        ? _SurahField(
            label: fromLabel,
            surah: surahFrom,
            onChanged: onFromSurah!,
          )
        : _AyahField(
            label: fromLabel,
            surah: surahFrom,
            ayah: ayahFrom ?? 1,
            onChanged: onFromAyah!,
            enabled: ayahControlsEnabled,
          );

    final toField = pickSurahs
        ? _SurahField(label: toLabel, surah: surahTo, onChanged: onToSurah!)
        : _AyahField(
            label: toLabel,
            surah: surahTo,
            ayah: ayahTo ?? 1,
            onChanged: onToAyah!,
            enabled: ayahControlsEnabled,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              fromField,
              const SizedBox(height: AppSpacing.md),
              toField,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fromField),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: toField),
          ],
        );
      },
    );
  }
}

class _SurahField extends StatelessWidget {
  const _SurahField({
    required this.label,
    required this.surah,
    required this.onChanged,
  });

  final String label;
  final int surah;
  final ValueChanged<int> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await AppBottomSheet.show<int>(
      context: context,
      title: 'اختر السورة',
      subtitle: 'اختر من ١١٤ سورة',
      maxHeightFactor: 0.8,
      builder: (ctx) => _SurahPickerSheet(
        selected: surah,
        onSelect: (value) => Navigator.of(ctx).pop(value),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = SurahCatalog.instance;
    return AppPickerField(
      label: label,
      value: catalog.nameOf(surah),
      isPlaceholder: false,
      icon: Iconsax.book_1,
      onTap: () => _open(context),
    );
  }
}

class _AyahField extends StatelessWidget {
  const _AyahField({
    required this.label,
    required this.surah,
    required this.ayah,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final int surah;
  final int ayah;
  final ValueChanged<int> onChanged;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final max = SurahCatalog.instance.ayahCountOf(surah);
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (ctx) => _AyahPickerSheet(
        surah: surah,
        selected: ayah.clamp(1, max),
        onSelect: (value) => Navigator.of(ctx).pop(value),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AppPickerField(
          label: label,
          value: '$ayah',
          isPlaceholder: false,
          icon: Iconsax.document,
          onTap: enabled ? () => _open(context) : () {},
        ),
      ),
    );
  }
}

/// Live preview of the selected range, rendered in the Qur'anic typeface.
class _RangePreview extends StatelessWidget {
  const _RangePreview({
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
  });

  final int surahFrom;
  final int ayahFrom;
  final int surahTo;
  final int ayahTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = SurahCatalog.instance;

    return AppCard(
      variant: AppCardVariant.filled,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المقدار المختار',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatSurahRange(surahFrom, ayahFrom, surahTo, ayahTo),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: AppTypography.quranSurahName.copyWith(
              fontSize: 18,
              color: theme.colorScheme.onSurface,
              fontFamilyFallback: AppTypography.quranFallback,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            surahFrom == surahTo
                ? 'سورة ${catalog.nameOf(surahFrom)} — ${catalog.ayahCountOf(surahFrom)} آية'
                : 'من سورة ${catalog.nameOf(surahFrom)} إلى سورة ${catalog.nameOf(surahTo)}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahPickerSheet extends StatefulWidget {
  const _SurahPickerSheet({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = SurahCatalog.instance;
    final query = _query.trim();
    final surahs = catalog.surahs
        .where((surah) => surah.name.contains(query))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TextField(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم السورة',
              prefixIcon: Icon(Iconsax.search_normal),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: surahs.isEmpty
              ? const Center(child: Text('لا توجد سورة بهذا الاسم'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  itemCount: surahs.length,
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    final isSelected = surah.number == widget.selected;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Material(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: AppRadius.allMd,
                        child: InkWell(
                          onTap: () => widget.onSelect(surah.number),
                          borderRadius: AppRadius.allMd,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '${surah.number}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    surah.name,
                                    textDirection: TextDirection.rtl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.quranSurahName
                                        .copyWith(
                                          fontSize: 17,
                                          fontFamilyFallback:
                                              AppTypography.quranFallback,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${surah.numberOfAyahs} آية',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AyahPickerSheet extends StatelessWidget {
  const _AyahPickerSheet({
    required this.surah,
    required this.selected,
    required this.onSelect,
  });

  final int surah;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = SurahCatalog.instance.ayahCountOf(surah);
    // ~4 readable rows of ayah numbers on any window.
    final rowHeight = 48.0;
    final height = ((max / 4).ceil() * rowHeight).clamp(200.0, 380.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                'سورة ${SurahCatalog.instance.nameOf(surah)}',
                textDirection: TextDirection.rtl,
                style: AppTypography.quranSurahName.copyWith(
                  fontSize: 19,
                  fontFamilyFallback: AppTypography.quranFallback,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'اختر رقم الآية من 1 إلى $max',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.6,
            ),
            itemCount: max,
            itemBuilder: (context, index) {
              final number = index + 1;
              final isSelected = number == selected;
              return Material(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: AppRadius.allMd,
                child: InkWell(
                  onTap: () => onSelect(number),
                  borderRadius: AppRadius.allMd,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.allMd,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      '$number',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
