import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_responsive.dart';
import 'core/config/env.dart';
import 'core/providers.dart';
import 'data/surah_catalog.dart';
import 'screens/attendance_screen.dart';
import 'screens/hifd_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/students_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_states.dart';
import 'widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  await SurahCatalog.instance.ensureLoaded();

  runApp(const ProviderScope(child: HalaqatiApp()));
}

/// Shown when the app was started without `--dart-define` values. Failing here
/// beats a stack trace from deep inside the Supabase client.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'إعدادات التطبيق غير مكتملة.\n'
            'شغّل التطبيق مع معاملات SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class HalaqatiApp extends ConsumerWidget {
  const HalaqatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'حلقاتي',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The app is Arabic only.
      supportedLocales: const [Locale('ar')],
      locale: const Locale('ar'),
      // Arabic is the primary language: force RTL for every platform.
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: ScreenUtilBootstrap(
          // Cloud-only: no local cache, so a lost connection has to be said
          // out loud rather than silently swallowed.
          child: OfflineBanner(
            isOnline: ref.watch(onlineProvider).valueOrNull ?? true,
            onRetry: () => ref.invalidate(onlineProvider),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

class AppRoutes {
  const AppRoutes._();

  static const String root = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String students = '/students';
  static const String studentForm = '/student-form';
  static const String attendance = '/attendance';
  static const String hifd = '/hifd';
  static const String reports = '/reports';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = switch (settings.name) {
      home => (BuildContext _) => const HomeScreen(),
      onboarding => (BuildContext _) => const OnboardingScreen(),
      students => (BuildContext _) => const StudentsScreen(),
      studentForm => (BuildContext _) => const StudentFormScreen(),
      attendance => (BuildContext _) => const AttendanceScreen(),
      hifd => (BuildContext _) => const HifdScreen(),
      reports => (BuildContext _) => const ReportsScreen(),
      login => (BuildContext _) => const LoginScreen(),
      signup => (BuildContext _) => const SignUpScreen(),
      AppRoutes.settings => (BuildContext _) => const SettingsScreen(),
      splash => (BuildContext _) => const SplashScreen(),
      _ => (BuildContext _) => const RootScreen(),
    };
    return MaterialPageRoute<dynamic>(builder: builder, settings: settings);
  }
}

/// Routes on the signed-in state, and reacts to it.
///
/// No session -> login. Session but no teacher row -> onboarding. Session and
/// teacher row -> home. Listening to `onAuthStateChange` means login and logout
/// navigate on their own, with no imperative push or pop.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => ErrorState(message: '$error'),
      data: (state) {
        if (state.session == null) return const LoginScreen();
        return ref
            .watch(teacherProvider)
            .when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(teacherProvider),
              ),
              data: (teacher) => teacher == null
                  ? const OnboardingScreen()
                  : const HomeScreen(),
            );
      },
    );
  }
}
