import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_responsive.dart';
import '../core/errors/app_exception.dart';
import '../core/providers.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text_field.dart';

/// Email + password entry point. One teacher account is one halaqa, and every
/// row that account can see is decided by Row Level Security on the server.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  /// Runs an auth call, turning any failure into one Arabic sentence.
  ///
  /// `guard` has already reduced transport failures to
  /// [AppException.offline]; what is left is a server answer we must phrase.
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppSnack.success(context, success);
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object error) {
    if (error is AppException) return error.message;

    if (error is AuthApiException) {
      final status = error.statusCode;
      if (status == 'email_not_confirmed') {
        return 'يرجى تأكيد بريدك الإلكتروني أولا';
      }
      // Gotrue answers 400 for bad credentials and for a duplicate sign-up;
      // only the former is worth naming here.
      if (status == 'invalid_credentials') {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      }
      return error.message.isEmpty ? 'حدث خطأ غير متوقع' : error.message;
    }
    return 'حدث خطأ غير متوقع';
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _run(
      () => ref
          .read(authServiceProvider)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          ),
      'تم تسجيل الدخول',
    );
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(authServiceProvider)
          .signUp(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      AppSnack.success(
        context,
        created
            ? 'تم إنشاء الحساب. إذا طُلب تأكيد البريد الإلكتروني فافتح الرسالة أولاً.'
            : 'هذا البريد مسجّل بالفعل. سجّل الدخول بدلاً من ذلك.',
      );
    } catch (error) {
      if (!mounted) return;
      AppSnack.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      AppSnack.error(context, 'أدخل بريدك الإلكتروني أولاً');
      return;
    }
    await _run(
      () => ref.read(authServiceProvider).resetPassword(email),
      'تم إرسال رابط إعادة التعيين إلى بريدك',
    );
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
                      const _BrandHeader(),
                      const SizedBox(height: AppSpacing.xxl),
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              hint: 'name@example.com',
                              icon: Iconsax.sms,
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              enabled: !_busy,
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
                              enabled: !_busy,
                              validator: _validatePassword,
                              onSubmitted: (_) => _signIn(),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'إظهار' : 'إخفاء',
                                icon: Icon(
                                  _obscure ? Iconsax.eye : Iconsax.eye_slash,
                                  size: AppIconSize.sm,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: _busy ? null : _forgotPassword,
                                child: const Text('نسيت كلمة المرور؟'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'تسجيل الدخول',
                              icon: Iconsax.login,
                              expand: true,
                              size: AppButtonSize.large,
                              loading: _busy,
                              onPressed: _signIn,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'إنشاء حساب',
                              icon: Iconsax.user_add,
                              variant: AppButtonVariant.outline,
                              expand: true,
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pushNamed('/signup'),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 28, end: 0),
      builder: (context, offset, child) {
        return Opacity(
          opacity: 1 - (offset / 28),
          child: Transform.translate(offset: Offset(0, offset), child: child),
        );
      },
      child: Column(
        children: [
          const AppLogo(size: 104),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'حلقتي',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'إدارة الحلقة بسهولة ووضوح',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
