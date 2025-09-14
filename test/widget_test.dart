import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:phishwatch_pro/main.dart';
import 'package:phishwatch_pro/services/theme_service.dart';

void main() {
  group('PhishWatch Pro App Tests', () {
    testWidgets('PhishWatchApp builds without crashing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App starts with welcome screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should start on welcome screen
      expect(find.text('Welcome to PhishWatch Pro'), findsOneWidget);
      expect(find.text('Your personal security assistant'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip Tutorial'), findsOneWidget);
    });

    testWidgets('Navigation from welcome to home works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Get Started" button
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Should navigate to home screen
      expect(find.text('Detect Phishing Attempts'), findsOneWidget);
      expect(find.text('PhishWatch Pro'), findsOneWidget);
    });

    testWidgets('Theme toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeService())],
          child: const PhishWatchApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home screen to access theme toggle
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Find and tap the theme toggle button
      final themeToggle = find.byTooltip('Toggle theme');
      expect(themeToggle, findsOneWidget);

      await tester.tap(themeToggle);
      await tester.pumpAndSettle();

      // Button should still be present after toggle
      expect(themeToggle, findsOneWidget);
    });
  });
}
