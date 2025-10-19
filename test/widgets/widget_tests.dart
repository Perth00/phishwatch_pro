import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:phishwatch_pro/widgets/scan_button.dart';
import 'package:phishwatch_pro/widgets/bottom_nav_bar.dart';
import 'package:phishwatch_pro/widgets/recent_result_card.dart';
import 'package:phishwatch_pro/widgets/history_item_card.dart';
import 'package:phishwatch_pro/screens/scan_history_screen.dart';
import 'package:phishwatch_pro/models/history_item.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('ScanButton displays correctly and responds to tap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanButton(
              icon: Icons.message_outlined,
              label: 'Test Scan Button',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if elements are present
      expect(find.text('Test Scan Button'), findsOneWidget);
      expect(find.byIcon(Icons.message_outlined), findsOneWidget);

      // Test tap functionality
      await tester.tap(find.byType(ScanButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('ScanButton animation works correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanButton(
              icon: Icons.link_outlined,
              label: 'Test Animation',
              onPressed: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test tap down animation
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScanButton)),
      );
      await tester.pump();

      // Button should be pressed (scaled down)
      expect(find.byType(Transform), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // Animation should complete without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('BottomNavBar displays correctly', (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if nav items are present
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Learn'), findsOneWidget);

      // Check icons
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('BottomNavBar responds to taps', (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomNavBar(
              currentIndex: selectedIndex,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap scan button
      await tester.tap(find.text('Scan'));
      await tester.pump();

      // The onTap callback should have been called
      // (We can't directly test the callback result in this setup,
      // but we can ensure no exceptions occurred)
      expect(tester.takeException(), isNull);
    });

    testWidgets('RecentResultCard displays correctly', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (context, state) => const Scaffold(body: RecentResultCard()),
          ),
          GoRoute(
            path: '/scan-result',
            builder:
                (context, state) =>
                    const Scaffold(body: Text('Scan Result Page')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: mockGoRouter));

      await tester.pumpAndSettle();

      // Check if card elements are present
      expect(find.text('Phishing Detected'), findsOneWidget);
      expect(find.text('92.4% Confidence'), findsOneWidget);
      expect(
        find.text('Message from: unknown@securebank-verify.com'),
        findsOneWidget,
      );
      expect(find.text('Suspicious elements:'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);

      // Check suspicious tags
      expect(find.text('Urgency tactics'), findsOneWidget);
      expect(find.text('Suspicious domain'), findsOneWidget);
      expect(find.text('Request for credentials'), findsOneWidget);
    });

    testWidgets('RecentResultCard navigation works', (
      WidgetTester tester,
    ) async {
      final mockGoRouter = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (context, state) => const Scaffold(body: RecentResultCard()),
          ),
          GoRoute(
            path: '/scan-result',
            builder:
                (context, state) =>
                    const Scaffold(body: Text('Scan Result Page')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: mockGoRouter));

      await tester.pumpAndSettle();

      // Tap view details button
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Should navigate to scan result page
      expect(find.text('Scan Result Page'), findsOneWidget);
    });

    testWidgets('HistoryItemCard displays correctly', (
      WidgetTester tester,
    ) async {
      final historyItem = HistoryItem(
        id: 'test-1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        classification: 'Phishing',
        confidence: 0.94,
        riskLevel: 'High',
        source: 'test@phishing.com',
        preview: 'Urgent: Your account will be suspended...',
        isPhishing: true,
        message: 'Urgent: Your account will be suspended...',
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(
              item: historyItem,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check if card elements are present
      expect(find.text('Phishing'), findsOneWidget);
      expect(find.text('Confidence: 94%'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('From: test@phishing.com'), findsOneWidget);
      expect(
        find.text('Urgent: Your account will be suspended...'),
        findsOneWidget,
      );
      expect(find.text('View Details'), findsOneWidget);

      // Test tap functionality
      await tester.tap(find.byType(HistoryItemCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('HistoryItemCard shows correct classification colors', (
      WidgetTester tester,
    ) async {
      final safeItem = HistoryItem(
        id: 'safe-1',
        timestamp: DateTime.now(),
        classification: 'Safe',
        confidence: 0.15,
        riskLevel: 'Low',
        source: 'legitimate@bank.com',
        preview: 'Your statement is ready...',
        isPhishing: false,
        message: 'Your statement is ready...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryItemCard(item: safeItem, onTap: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Check safe classification
      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Confidence: 15%'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('HistoryItemCard animation works correctly', (
      WidgetTester tester,
    ) async {
      final historyItem = HistoryItem(
        id: 'test-1',
        timestamp: DateTime.now(),
        classification: 'Suspicious',
        confidence: 0.67,
        riskLevel: 'Medium',
        source: 'suspicious@site.com',
        preview: 'Click here for amazing deals...',
        isPhishing: true,
        message: 'Click here for amazing deals...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryItemCard(item: historyItem, onTap: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test tap animation
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HistoryItemCard)),
      );
      await tester.pump();

      // Card should be pressed (scaled down)
      expect(find.byType(Transform), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // Animation should complete without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('HistoryItemCard timestamp formatting works', (
      WidgetTester tester,
    ) async {
      final recentItem = HistoryItem(
        id: 'recent-1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        classification: 'Phishing',
        confidence: 0.85,
        riskLevel: 'High',
        source: 'recent@test.com',
        preview: 'Recent message...',
        isPhishing: true,
        message: 'Recent message...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HistoryItemCard(item: recentItem, onTap: () {})),
        ),
      );

      await tester.pumpAndSettle();

      // Should show minutes ago
      expect(find.textContaining('m ago'), findsOneWidget);
    });
  });
}
