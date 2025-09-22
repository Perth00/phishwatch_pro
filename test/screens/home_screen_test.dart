import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:phishwatch_pro/screens/home_screen.dart';
import 'package:phishwatch_pro/services/theme_service.dart';
import 'package:phishwatch_pro/widgets/scan_button.dart';
import 'package:phishwatch_pro/widgets/bottom_nav_bar.dart';

void main() {
  group('HomeScreen Tests', () {
    testWidgets('HomeScreen displays all required elements', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Check header elements
      expect(find.text('PhishWatch Pro'), findsOneWidget);
      expect(find.byTooltip('Toggle theme'), findsOneWidget);

      // Check main content
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      expect(
        find.text(
          'Scan messages or URLs to check if they\'re legitimate or potentially harmful.',
        ),
        findsOneWidget,
      );

      // Check scan buttons
      expect(find.text('Scan Message'), findsAtLeastNWidgets(1));
      expect(find.text('Scan URL'), findsAtLeastNWidgets(1));

      // Check recent result section
      expect(find.text('Recent Result'), findsOneWidget);

      // Check quick actions
      expect(find.text('View History'), findsOneWidget);
      expect(find.text('Security Tips'), findsOneWidget);

      // Check bottom navigation
      expect(find.byType(BottomNavBar), findsOneWidget);
    });

    testWidgets('Scan buttons are functional', (WidgetTester tester) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/scan-result',
            builder:
                (context, state) =>
                    const Scaffold(body: Text('Scan Result Screen')),
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

      // Test scan message button
      final scanMessageButton = find.text('Scan Message').first;
      await tester.tap(scanMessageButton);
      await tester.pumpAndSettle();

      // Should navigate to scan result
      expect(find.text('Scan Result Screen'), findsOneWidget);
    });

    testWidgets('Theme toggle works correctly', (WidgetTester tester) async {
      final themeService = ThemeService();
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider.value(value: themeService)],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap theme toggle
      final themeToggle = find.byTooltip('Toggle theme');
      expect(themeToggle, findsOneWidget);

      await tester.tap(themeToggle);
      await tester.pumpAndSettle();

      // Button should still be present
      expect(themeToggle, findsOneWidget);
    });

    testWidgets('Bottom navigation responds to taps', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Test bottom navigation tap
      final scanNavItem = find.text('Scan');
      await tester.tap(scanNavItem);
      await tester.pumpAndSettle();

      // Should show scan bottom sheet
      expect(find.text('Choose Scan Type'), findsOneWidget);
    });

    testWidgets('Quick actions work correctly', (WidgetTester tester) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/scan-history',
            builder:
                (context, state) =>
                    const Scaffold(body: Text('Scan History Screen')),
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

      // Test view history button
      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      // Should navigate to history screen
      expect(find.text('Scan History Screen'), findsOneWidget);
    });

    testWidgets('Animations complete without errors', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
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
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Scan bottom sheet displays correctly', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: MaterialApp.router(routerConfig: mockGoRouter),
        ),
      );

      await tester.pumpAndSettle();

      // Tap scan in bottom nav to show bottom sheet
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Check bottom sheet content
      expect(find.text('Choose Scan Type'), findsOneWidget);
      expect(find.text('Scan Message'), findsAtLeastNWidgets(1));
      expect(find.text('Scan URL'), findsAtLeastNWidgets(1));

      // Test bottom sheet scan buttons
      final bottomSheetScanMessage = find.text('Scan Message').last;
      expect(bottomSheetScanMessage, findsOneWidget);
    });
  });
}

