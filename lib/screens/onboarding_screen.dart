import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../core/app_responsive.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../models/teacher.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text_field.dart';

/// First-run screen: capture the teacher's identity before anything else.
/// Deliberately a single focused card — no feature list, no carousel.
///
/// The teacher row's id is the auth user id, supplied by the database default.
/// The client never picks it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _madrassaController = TextEditingController();
  final _halaqaController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _madrassaController.dispose();
    _halaqaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
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
      if (!mounted) return;
      // `teacherProvider` now has a row, so the root routes to home on its
      // own — no imperative navigation needed.
      ref.invalidate(teacherProvider);
      AppSnack.success(context, 'تم حفظ بياناتك، أهلاً بك');
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnack.error(context, error.message);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xxl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppLogo(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'أهلاً بك في حلقاتي',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'أدخل بياناتك لتتمكن من متابعة طلابك وتحفيظهم',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: 'اسم الشيخ',
                              hint: 'مثال: الشيخ عبد الله',
                              icon: Iconsax.teacher,
                              textCapitalization: TextCapitalization.words,
                              validator: _required,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _madrassaController,
                              label: 'اسم Madrassa',
                              hint: 'مثال: Madrassa النور',
                              icon: Iconsax.home,
                              textCapitalization: TextCapitalization.words,
                              validator: _required,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _halaqaController,
                              label: 'اسم الحلقة',
                              hint: 'مثال: حلقة الفاتحة',
                              icon: Iconsax.group,
                              textCapitalization: TextCapitalization.words,
                              validator: _required,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _phoneController,
                              label: 'رقم الجوال (اختياري)',
                              hint: '05xxxxxxxx',
                              icon: Iconsax.call,
                              keyboardType: TextInputType.phone,
                              textCapitalization: TextCapitalization.none,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            AppButton(
                              label: 'ابدأ',
                              icon: Iconsax.arrow_left,
                              expand: true,
                              size: AppButtonSize.large,
                              loading: _loading,
                              onPressed: _save,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'يمكنك تعديل هذه البيانات لاحقاً من الإعدادات',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
