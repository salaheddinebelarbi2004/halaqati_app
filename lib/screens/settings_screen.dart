import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../models/settings.dart';
import '../models/teacher.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_text_field.dart';
import '../widgets/theme_toggle.dart';

/// Settings: teacher profile, ranking weights, appearance, account.
///
/// Weights are kept in local state while a slider is being dragged and
/// written on release, so the cloud sees one update per gesture rather than
/// one per pixel.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _madrassaController = TextEditingController();
  final _halaqaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AppSettings? _draftWeights;
  bool _profileFilled = false;
  bool _savingProfile = false;
  bool _signingOut = false;

  @override
  void dispose() {
    _nameController.dispose();
    _madrassaController.dispose();
    _halaqaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Fill the profile form once the teacher row arrives. Doing it from a
  /// listener rather than `initState` means a slow network does not leave the
  /// fields permanently blank. Runs at most once, so a later weight change
  /// never overwrites text the teacher is typing.
  void _fillProfile(Teacher teacher) {
    if (_profileFilled) return;
    _profileFilled = true;
    _nameController.text = teacher.name;
    _madrassaController.text = teacher.madrassaName;
    _halaqaController.text = teacher.halaqaName;
    _phoneController.text = teacher.phone ?? '';
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingProfile = true);

    try {
      // No id is sent: the row is keyed by the auth user id.
      await ref
          .read(dataServiceProvider)
          .saveTeacher(
            Teacher(
              name: _nameController.text.trim(),
              madrassaName: _madrassaController.text.trim(),
              halaqaName: _halaqaController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
            ),
          );
      ref.invalidate(teacherProvider);
      if (!mounted) return;
      setState(() => _savingProfile = false);
      AppSnack.success(context, 'تم حفظ البيانات');
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _savingProfile = false);
      AppSnack.error(context, error.message);
    }
  }

  Future<void> _saveWeights(AppSettings draft) async {
    try {
      await ref
          .read(dataServiceProvider)
          .saveWeights(hodor: draft.hodorWeight, hifd: draft.hifdWeight);
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'تسجيل الخروج',
      message:
          'ستحتاج إلى إدخال بريدك وكلمة المرور للدخول مرة أخرى. '
          'بياناتك محفوظة في حسابك ولن تُحذف.',
      confirmLabel: 'خروج',
      cancelLabel: 'إلغاء',
      destructive: true,
      icon: Iconsax.logout,
    );
    if (!confirmed || !mounted) return;

    setState(() => _signingOut = true);
    try {
      // Clear cached rows first: a signed-out account must not be able to see
      // the previous teacher's data flash on the login screen.
      invalidateAccountData(ref);
      await ref.read(authServiceProvider).signOut();
      // The root widget reacts to the session change on its own, but any
      // screen pushed on top of it (this one, usually) has to be dropped.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AppException catch (error) {
      if (!mounted) return;
      AppSnack.error(context, error.message);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fill the profile form once the teacher row arrives, so a slow network
    // does not leave the fields permanently blank.
    ref.listen(teacherProvider, (_, next) {
      final teacher = next.valueOrNull;
      if (teacher != null) _fillProfile(teacher);
    });
    final teacher = ref.watch(teacherProvider).valueOrNull;
    if (teacher != null) _fillProfile(teacher);

    final remote =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    // The slider owns the value while it is being dragged.
    final settings = _draftWeights ?? remote;
    final email = ref.watch(currentUserProvider)?.email;

    return AppScaffold(
      title: 'الإعدادات',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: [
          const SectionHeader(
            title: 'بيانات الحلقة',
            subtitle: 'تظهر في أعلى الشاشة الرئيسية والتقارير',
          ),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _nameController,
                    label: 'اسم الشيخ',
                    icon: Iconsax.teacher,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _madrassaController,
                    label: 'اسم المدرسة',
                    icon: Iconsax.home,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _halaqaController,
                    label: 'اسم الحلقة',
                    icon: Iconsax.group,
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _phoneController,
                    label: 'رقم الجوال (اختياري)',
                    icon: Iconsax.call,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'حفظ البيانات',
                    icon: Iconsax.save_2,
                    expand: true,
                    loading: _savingProfile,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(
            title: 'أوزان الترتيب',
            subtitle: 'كيف يُحتسب الترتيب العام في التقارير',
          ),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _WeightSlider(
                  label: 'وزن الحضور',
                  value: settings.hodorWeight,
                  onChanged: (v) => setState(
                    () => _draftWeights = settings.copyWith(hodorWeight: v),
                  ),
                  onChangeEnd: (v) async {
                    await _saveWeights(settings.copyWith(hodorWeight: v));
                    if (mounted) setState(() => _draftWeights = null);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _WeightSlider(
                  label: 'وزن التحفيظ',
                  value: settings.hifdWeight,
                  onChanged: (v) => setState(
                    () => _draftWeights = settings.copyWith(hifdWeight: v),
                  ),
                  onChangeEnd: (v) async {
                    await _saveWeights(settings.copyWith(hifdWeight: v));
                    if (mounted) setState(() => _draftWeights = null);
                  },
                ),
                const AppCardDivider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المحصّل = حضور × ${settings.hodorWeight.toStringAsFixed(2)} + تحفيظ × ${settings.hifdWeight.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(title: 'مظهر التطبيق'),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: const ThemeModeSelector(),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const SectionHeader(
            title: 'الحساب',
            subtitle: 'البيانات محفوظة في حسابك وتظهر على كل أجهزتك',
          ),
          _SignOutCard(
            signingOut: _signingOut,
            email: email,
            onSignOut: _signOut,
          ),
          const SizedBox(height: AppSpacing.md),
          _CloudNoticeCard(),
        ],
      ),
    );
  }
}

/// Shown when the teacher row has not loaded yet, so the profile form is not
/// silently blank.
class ProfileMissingNotice extends StatelessWidget {
  const ProfileMissingNotice({super.key});

  @override
  Widget build(BuildContext context) => AppCard(
    variant: AppCardVariant.outlined,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      children: [
        Icon(
          Iconsax.refresh,
          size: AppIconSize.sm,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'جارٍ تحميل بيانات الحلقة…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The reverse of the old "your data never leaves this phone" notice.
class _CloudNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AppCard(
    variant: AppCardVariant.outlined,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      children: [
        Icon(
          Iconsax.shield,
          size: AppIconSize.sm,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'تُحفظ بياناتك في حسابك على السحابة، ولا يراها إلا أنت.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SignOutCard extends StatelessWidget {
  const _SignOutCard({
    required this.signingOut,
    required this.onSignOut,
    this.email,
  });

  final bool signingOut;
  final VoidCallback onSignOut;
  final String? email;

  @override
  Widget build(BuildContext context) => AppCard(
    variant: AppCardVariant.outlined,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (email != null) ...[
          Row(
            children: [
              Icon(
                Iconsax.user,
                size: AppIconSize.sm,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  email!,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppButton(
          label: 'تسجيل الخروج',
          icon: Iconsax.logout,
          variant: AppButtonVariant.outline,
          expand: true,
          loading: signingOut,
          onPressed: signingOut ? null : onSignOut,
        ),
      ],
    ),
  );
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 20,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}