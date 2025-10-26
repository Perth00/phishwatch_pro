import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'constants/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scan_result_screen.dart';
import 'models/scan_result_data.dart';
import 'screens/scan_history_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/onboarding_goal_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/scenario_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_edit_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/reset_password_sent_screen.dart';
import 'screens/progress_screen.dart';
import 'services/theme_service.dart';
import 'services/onboarding_service.dart';
import 'services/history_service.dart';
import 'services/auth_service.dart';
import 'services/progress_service.dart';
import 'services/settings_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase BEFORE building the widget tree to avoid any
  // race conditions where services access Firebase too early.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize audio session and preload sounds for instant playback
  await SoundService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => OnboardingService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProxyProvider<AuthService, ProgressService>(
          create: (_) => ProgressService(null),
          update: (_, auth, previous) {
            final service = previous ?? ProgressService(auth);
            service.attachAuth(auth);
            return service;
          },
        ),
      ],
      child: const PhishWatchApp(),
    ),
  );
}

class PhishWatchApp extends StatelessWidget {
  const PhishWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp.router(
          title: 'PhishWatch Pro',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        return Consumer<OnboardingService>(
          builder: (context, onboardingService, child) {
            if (!onboardingService.isOnboardingCompleted) {
              return const WelcomeScreen();
            }
            // Land on Home even if not logged in; auth is optional until starting learning/quiz
            return const HomeScreen();
          },
        );
      },
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-sent',
      builder: (context, state) {
        final String email =
            (state.extra is String) ? state.extra as String : '';
        return ResetPasswordSentScreen(email: email);
      },
    ),
    GoRoute(
      path: '/goals',
      builder: (context, state) => const OnboardingGoalScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const ProfileEditScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (context, state) {
        final bool startCooldown =
            (state.extra is bool) ? state.extra as bool : false;
        return VerifyEmailScreen(startWithCooldown: startCooldown);
      },
    ),
    GoRoute(
      path: '/scan-result',
      builder: (context, state) {
        final ScanResultData? data =
            state.extra is ScanResultData
                ? state.extra as ScanResultData
                : null;
        return ScanResultScreen(data: data);
      },
    ),
    GoRoute(
      path: '/lesson/:id',
      builder:
          (context, state) =>
              LessonScreen(lessonId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/quiz/:id',
      builder:
          (context, state) =>
              QuizScreen(quizId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/scenario/:id',
      builder:
          (context, state) =>
              ScenarioScreen(scenarioId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/scan-history',
      builder: (context, state) => const ScanHistoryScreen(),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const ProgressScreen(),
    ),
  ],
);
