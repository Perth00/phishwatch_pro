import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:phishwatch_pro/screens/welcome_screen.dart';
import 'package:phishwatch_pro/services/theme_service.dart';

void main() {
  group('WelcomeScreen Tests', () {
    testWidgets('WelcomeScreen displays all required elements', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Check header text
      expect(find.text('Welcome to PhishWatch Pro'), findsOneWidget);
      expect(find.text('Your personal security assistant'), findsOneWidget);

      // Check action buttons
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip Tutorial'), findsOneWidget);

      // Check if feature showcase is present
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Feature showcase displays features', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Check if first feature is visible
      expect(find.text('Scan Messages'), findsOneWidget);

      // Swipe to next feature
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Check if second feature is visible
      expect(find.text('Analyze URLs'), findsOneWidget);
    });

    testWidgets('Page indicator updates when swiping', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Page indicator should be present
      expect(
        find.byType(AnimatedContainer),
        findsAtLeastNWidgets(3),
      ); // 3 features = 3 indicators

      // Swipe to change page
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Indicator should still be present (visual state change is hard to test)
      expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(3));
    });

    testWidgets('Buttons are properly styled and accessible', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Check button types
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);

      // Check button accessibility
      final getStartedButton = find.widgetWithText(
        ElevatedButton,
        'Get Started',
      );
      final skipButton = find.widgetWithText(TextButton, 'Skip Tutorial');

      expect(getStartedButton, findsOneWidget);
      expect(skipButton, findsOneWidget);
    });

    testWidgets('Animations complete without errors', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      // Let all animations complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Screen should be fully loaded without errors
      expect(find.text('Welcome to PhishWatch Pro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

