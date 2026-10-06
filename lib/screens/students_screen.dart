import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../core/app_responsive.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../models/student.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_text_field.dart';
import '../widgets/student_card.dart';

/// Roster management: search, filter by active state, add and edit.
///
/// The roster is a realtime subscription, so adding or reactivating a student
/// on another device appears here on its own.
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();

  bool _showInactive = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Student> get _visible {
    final all = ref.read(studentsProvider).valueOrNull ?? const <Student>[];
    final roster = _showInactive ? all : all.where((s) => s.active).toList();
    if (_query.isEmpty) return roster;
    final q = _query.toLowerCase();
    return roster.where((s) => s.fullName.toLowerCase().contains(q)).toList();
  }

  Future<void> _addOrEditStudent({Student? existing}) async {
    final result = await Navigator.of(
      context,
    ).pushNamed('/student-form', arguments: existing);
    // No reload needed: the save lands in the cloud and the subscription
    // pushes it back.
    if (result == true) setState(() {});
  }

  Future<void> _toggleActive(Student student) async {
    final deactivating = student.active;
    final confirmed = deactivating
        ? await AppDialog.confirm(
            context,
            title: 'إيقاف الطالب',
            message:
                'سيتم إيقاف ${student.fullName} مؤقتاً. لن تظهر بياناته في الحضور والتحفيظ، ويمكنك استعادته لاحقاً.',
            confirmLabel: 'إيقاف',
            destructive: true,
            icon: Iconsax.close_circle,
          )
        : true;

    if (!confirmed || !mounted) return;

    try {
      final db = ref.read(dataServiceProvider);
      final updated = student.copyWith(active: !student.active);
      if (updated.active) {
        await db.updateStudent(updated);
      } else {
        await db.deactivateStudent(student.id!);
      }
      if (!mounted) return;
      AppSnack.success(
        context,
        deactivating ? 'تم إيقاف الطالب' : 'تمت استعادة الطالب',
      );
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    }
  }

  String _subtitleFor(Student student) {
    final date = student.enrollmentDate;
    if (date == null) return 'بدون تاريخ التحاق';
    return 'التحاق ${DateFormat.yMMMd('ar').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentsProvider);
    final all = async.valueOrNull ?? const <Student>[];
    final filtered = _visible;

    return AppScaffold(
      title: 'الطلاب',
      actions: [
        AppIconButton(
          icon: _showInactive ? Iconsax.eye_slash : Iconsax.eye,
          tooltip: _showInactive ? 'إظهار النشطين فقط' : 'إظهار غير النشطين',
          onPressed: () => setState(() => _showInactive = !_showInactive),
        ),
      ],
      floatingActionButton: AppButton(
        label: 'طالب جديد',
        icon: Iconsax.add,
        onPressed: () => _addOrEditStudent(),
      ),
      body: async.isLoading && all.isEmpty
          ? const Center(child: AppLoadingView(message: 'جارٍ تحميل الطلاب'))
          : async.hasError && all.isEmpty
          ? ErrorState(
              message: '${async.error}',
              onRetry: () => ref.invalidate(studentsProvider),
            )
          : all.isEmpty
          ? EmptyState(
              icon: Iconsax.people,
              title: _showInactive
                  ? 'لا يوجد طلاب مسجّلون'
                  : 'لا يوجد طلاب نشطون',
              message: _showInactive
                  ? 'أضف أول طالب لتبدأ متابعة الحضور والتحفيظ.'
                  : 'جميع الطلاب غير نشطين. أظهر غير النشطين للعرض.',
              actionLabel: 'إضافة طالب',
              onAction: () => _addOrEditStudent(),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(studentsProvider),
              child: ListView(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 96),
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hint: 'ابحث عن طالب',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'الإجمالي',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      Text(
                        '${filtered.length} من ${_showInactive ? all.length : all.where((s) => s.active).length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.huge),
                      child: EmptyState(
                        compact: true,
                        icon: Iconsax.search_normal,
                        title: 'لا توجد نتائج',
                        message: 'جرّب اسماً آخر.',
                      ),
                    )
                  else
                    for (final student in filtered)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.cardGap,
                        ),
                        child: StudentCard(
                          student: student,
                          subtitle: _subtitleFor(student),
                          onEdit: () => _addOrEditStudent(existing: student),
                          onToggleActive: () => _toggleActive(student),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// Add / edit a single student. Same form for both operations.
class StudentFormScreen extends ConsumerStatefulWidget {
  const StudentFormScreen({super.key});

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  Student? _existing;
  DateTime? _birthDate;
  DateTime? _enrollmentDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Student?;
      if (args == null) return;
      setState(() {
        _existing = args;
        _nameController.text = args.fullName;
        _phoneController.text = args.guardianPhone ?? '';
        _notesController.text = args.notes ?? '';
        _birthDate = args.birthDate;
        _enrollmentDate = args.enrollmentDate;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isEditing => _existing != null;

  Future<void> _pickDate({required bool isBirth}) async {
    final now = DateTime.now();
    final initial = (isBirth ? _birthDate : _enrollmentDate) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1950),
      lastDate: now,
      locale: const Locale('ar'),
      helpText: isBirth ? 'تاريخ الميلاد' : 'تاريخ الالتحاق',
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isBirth) {
        _birthDate = date;
      } else {
        _enrollmentDate = date;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final student = Student(
      id: _existing?.id,
      fullName: _nameController.text.trim(),
      guardianPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      birthDate: _birthDate,
      enrollmentDate: _enrollmentDate ?? DateTime.now(),
      active: _existing?.active ?? true,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      final db = ref.read(dataServiceProvider);
      if (_isEditing) {
        await db.updateStudent(student);
      } else {
        await db.insertStudent(student);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (error) {
      // Cloud-only: nothing was stored, so keep the form exactly as the
      // teacher left it and let them retry.
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnack.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: _isEditing ? 'تعديل طالب' : 'طالب جديد',
      maxWidth: AppLayout.formMaxWidth,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            Text(
              _isEditing ? 'حدّث بيانات الطالب' : 'أدخل بيانات الطالب الأساسية',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              variant: AppCardVariant.outlined,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'مثال: عبد الله محمد',
                    icon: Iconsax.user,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'هذا الحقل مطلوب'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DateField(
                    label: 'تاريخ الميلاد',
                    value: _birthDate,
                    onTap: () => _pickDate(isBirth: true),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _phoneController,
                    label: 'جوال ولي الأمر',
                    hint: '05xxxxxxxx',
                    icon: Iconsax.call,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DateField(
                    label: 'تاريخ الالتحاق',
                    value: _enrollmentDate,
                    onTap: () => _pickDate(isBirth: false),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _notesController,
                    label: 'ملاحظات (اختياري)',
                    hint: 'أي معلومة تودّ تذكّرها',
                    icon: Iconsax.note_text,
                    maxLines: 3,
                    minLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'حفظ التعديلات' : 'إضافة الطالب',
              icon: Iconsax.save_2,
              expand: true,
              size: AppButtonSize.large,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? null
        : DateFormat.yMMMd('ar').format(value!);
    final age = label == 'تاريخ الميلاد' ? _ageOf(value) : null;

    return AppPickerField(
      label: label,
      value: age != null ? '$formatted • $age' : (formatted ?? ''),
      isPlaceholder: formatted == null,
      placeholder: 'اختر التاريخ',
      icon: Iconsax.calendar,
      onTap: onTap,
    );
  }

  static String? _ageOf(DateTime? birth) {
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return (age >= 0 && age < 120) ? '$age سنة' : null;
  }
}
