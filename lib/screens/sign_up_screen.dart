import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _madrassaController = TextEditingController();
  final _halaqaController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _madrassaController.dispose();
    _halaqaController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'هذا الحقل مطلوب';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : 'البريد الإلكتروني غير صحيح';
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
    return value.length < 6 ? 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل' : null;
  }

  String _messageFor(Object error) {
    if (error is AppException) return error.message;
    if (error is AuthApiException) return describeAuthError(error);
    return 'حدث خطأ غير متوقع';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final auth = ref.read(authServiceProvider);
      final response = await auth.signUpResponse(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      if (response.session == null) {
        AppSnack.success(
          context,
          'تم إنشاء الحساب. أكمل تأكيد البريد الإلكتروني ثم سجّل الدخول لإتمام حفظ البيانات.',
        );
        return;
      }

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
      ref.invalidate(teacherProvider);
      AppSnack.success(context, 'تم إنشاء الحساب وحفظ بيانات الحلقة');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                      const AppLogo(size: 96),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'إنشاء حساب جديد',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'املأ بيانات الحساب وبيانات الحلقة في صفحة واحدة',
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
                            Text(
                              'بيانات الحساب',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hint: 'name@example.com',
                              icon: Iconsax.sms,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _passwordController,
                              label: 'كلمة المرور',
                              icon: Iconsax.lock_1,
                              obscureText: _obscure,
                              textCapitalization: TextCapitalization.none,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              validator: _validatePassword,
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'إظهار' : 'إخفاء',
                                icon: Icon(
                                  _obscure ? Iconsax.eye : Iconsax.eye_slash,
                                  size: AppIconSize.sm,
                                ),
                                onPressed: () {
                                  setState(() => _obscure = !_obscure);
                                },
                              ),
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            Text(
                              'بيانات الحلقة',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
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
                              controller: _phoneController,
                              label: 'رقم الجوال (اختياري)',
                              hint: '05xxxxxxxx',
                              icon: Iconsax.call,
                              keyboardType: TextInputType.phone,
                              textCapitalization: TextCapitalization.none,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            AppTextField(
                              controller: _madrassaController,
                              label: 'اسم المدرسة',
                              hint: 'مثال: مدرسة النور',
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
                            const SizedBox(height: AppSpacing.xxl),
                            AppButton(
                              label: 'إنشاء الحساب',
                              icon: Iconsax.user_add,
                              expand: true,
                              size: AppButtonSize.large,
                              loading: _loading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('العودة إلى تسجيل الدخول'),
                            ),
                          ],
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
