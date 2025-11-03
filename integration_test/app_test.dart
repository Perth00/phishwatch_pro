import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:phishwatch_pro/main.dart';
import 'package:phishwatch_pro/services/theme_service.dart';
import 'package:phishwatch_pro/services/onboarding_service.dart';
import 'package:phishwatch_pro/services/history_service.dart';
import 'package:phishwatch_pro/services/auth_service.dart';
import 'package:phishwatch_pro/services/settings_service.dart';
import 'package:phishwatch_pro/services/progress_service.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  bool onboardingCompleted = true,
  bool withFakeHistory = false,
}) async {
  // Mock SharedPreferences for VM tests and pre-seed state
  final Map<String, Object> prefs = <String, Object>{
    'onboarding_completed': onboardingCompleted,
  };
  if (withFakeHistory) {
    // Pre-populate history so Home shows a Recent Result with "View Details"
    prefs['scan_history_v1'] =
        '[\n'
        '{"id":"test-1","timestamp":"2024-01-01T00:00:00.000Z","classification":"Phishing","confidence":0.92,"riskLevel":"High","source":"User input","preview":"Suspicious message preview...","isPhishing":true,"message":"This is a suspicious message containing a malicious link asking for your password."}'
        '\n]';
  }
  SharedPreferences.setMockInitialValues(prefs);

  await tester.pumpWidget(
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
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PhishWatch Pro Integration Tests', () {
    testWidgets('Complete user flow: Home -> Result -> History', (
      WidgetTester tester,
    ) async {
      // Start directly on Home (onboarding completed) with a fake recent result
      await _pumpApp(tester, onboardingCompleted: true, withFakeHistory: true);

      // Home Screen
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      expect(find.text('Scan Message'), findsAtLeastNWidgets(1));

      // Open recent result
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Scan Result Screen
      expect(find.text('Scan Result'), findsOneWidget);

      // Navigate to History
      await tester.tap(find.text('View History'));
      await tester.pumpAndSettle();

      // History Screen
      expect(find.text('Scan History'), findsOneWidget);

      // Back to home
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('Theme switching works throughout the app', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester);

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
      await _pumpApp(tester);

      // Test scan button in bottom nav
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      // Should show scan bottom sheet (do not trigger real scans)
      expect(find.text('Choose Scan Type'), findsOneWidget);
    });

    testWidgets('Scan URL dialog opens', (WidgetTester tester) async {
      await _pumpApp(tester);

      // Tap Scan URL – verify dialog appears; avoid network calls
      await tester.tap(find.text('Scan URL').first);
      await tester.pumpAndSettle();

      expect(find.text('Enter URL to scan'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
    });

    testWidgets('History filter functionality works', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, withFakeHistory: true);

      // Navigate to history
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
      await _pumpApp(tester, withFakeHistory: true);

      // Tap on recent result card
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      expect(find.text('Scan Result'), findsOneWidget);
    });

    testWidgets('History item tap navigation works', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, withFakeHistory: true);

      // Navigate to history
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
      await _pumpApp(tester, withFakeHistory: true);

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
      await _pumpApp(tester, onboardingCompleted: false);

      // Skip tutorial instead of getting started
      await tester.tap(find.text('Skip Tutorial'));
      await tester.pumpAndSettle();

      // Per current flow, skipping leads to login
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('App maintains state during navigation', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, withFakeHistory: true);

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
