import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:phishwatch_pro/main.dart';
import 'package:phishwatch_pro/services/theme_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PhishWatch Pro Integration Tests', () {
    testWidgets(
      'Complete user flow: Welcome -> Home -> Scan -> Result -> History',
      (WidgetTester tester) async {
        // Start the app
        await tester.pumpWidget(
          MultiProvider(
            providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
            child: const PhishWatchApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Welcome Screen
        expect(find.text('Welcome to PhishWatch Pro'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);

        // Tap Get Started
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();

        // Step 2: Home Screen
        expect(find.text('Detect Phishing Attempts'), findsOneWidget);
        expect(find.text('Scan Message'), findsAtLeastNWidgets(1));

        // Tap Scan Message
        await tester.tap(find.text('Scan Message').first);
        await tester.pumpAndSettle();

        // Step 3: Scan Result Screen
        expect(find.text('Scan Result'), findsOneWidget);
        expect(find.text('Phishing'), findsOneWidget);

        // Navigate to History
        await tester.tap(find.text('View History'));
        await tester.pumpAndSettle();

        // Step 4: History Screen
        expect(find.text('Scan History'), findsOneWidget);

        // Go back to home
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      },
    );

    testWidgets('Theme switching works throughout the app', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home screen
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Find theme toggle
      final themeToggle = find.byTooltip('Toggle theme');
      expect(themeToggle, findsOneWidget);

      // Toggle theme
      await tester.tap(themeToggle);
      await tester.pumpAndSettle();

      // App should still function normally
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);

      // Navigate to another screen to test theme persistence
      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      expect(find.text('Scan History'), findsOneWidget);

      // Toggle theme again
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(themeToggle);
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('Bottom navigation works correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Test scan button in bottom nav
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Should show scan bottom sheet
      expect(find.text('Choose Scan Type'), findsOneWidget);

      // Test scan from bottom sheet
      await tester.tap(find.text('Scan Message').last);
      await tester.pumpAndSettle();

      expect(find.text('Scan Result'), findsOneWidget);
    });

    testWidgets('Scan URL flow works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Tap Scan URL
      await tester.tap(find.text('Scan URL').first);
      await tester.pumpAndSettle();

      // Should navigate to scan result
      expect(find.text('Scan Result'), findsOneWidget);

      // Test navigation from result screen
      await tester.tap(find.text('Scan Another'));
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('History filter functionality works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home then history
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      // Open filter dialog
      await tester.tap(find.byTooltip('Filter results'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Results'), findsOneWidget);
      expect(find.text('Phishing'), findsOneWidget);
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Suspicious'), findsOneWidget);

      // Close filter dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Scan History'), findsOneWidget);
    });

    testWidgets('Recent result card navigation works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Tap on recent result card
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Result'), findsOneWidget);
    });

    testWidgets('History item tap navigation works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home then history
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      // Tap on a history item
      await tester.tap(find.text('View Details').first);
      await tester.pumpAndSettle();

      expect(find.text('Scan Result'), findsOneWidget);
    });

    testWidgets('App handles back navigation correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate through multiple screens
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Message').first);
      await tester.pumpAndSettle();

      // Use back navigation
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);

      // Navigate to history and back
      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('Welcome screen tutorial can be skipped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Skip tutorial instead of getting started
      await tester.tap(find.text('Skip Tutorial'));
      await tester.pumpAndSettle();

      // Should still navigate to home screen
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('App maintains state during navigation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Navigate to different screens and back
      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Home screen should still be intact
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      expect(find.text('Recent Result'), findsOneWidget);
      expect(find.text('Scan Message'), findsAtLeastNWidgets(1));
    });
  });
}
