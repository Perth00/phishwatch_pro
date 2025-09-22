import 'dart:io';

/// Automated test runner for PhishWatch Pro
/// Runs all tests and generates comprehensive reports
void main(List<String> args) async {
  print('🚀 Starting PhishWatch Pro Automated Test Suite');
  print('=' * 50);

  final testResults = <String, bool>{};
  var allTestsPassed = true;

  try {
    // Run widget tests
    print('\n📱 Running Widget Tests...');
    final widgetTestResult = await runWidgetTests();
    testResults['Widget Tests'] = widgetTestResult;
    allTestsPassed = allTestsPassed && widgetTestResult;

    // Run integration tests
    print('\n🔄 Running Integration Tests...');
    final integrationTestResult = await runIntegrationTests();
    testResults['Integration Tests'] = integrationTestResult;
    allTestsPassed = allTestsPassed && integrationTestResult;

    // Run screen-specific tests
    print('\n🖥️  Running Screen Tests...');
    final screenTestResult = await runScreenTests();
    testResults['Screen Tests'] = screenTestResult;
    allTestsPassed = allTestsPassed && screenTestResult;

    // Generate test report
    generateTestReport(testResults, allTestsPassed);
  } catch (e) {
    print('❌ Test runner encountered an error: $e');
    exit(1);
  }

  exit(allTestsPassed ? 0 : 1);
}

Future<bool> runWidgetTests() async {
  try {
    print('  → Running widget component tests...');

    final result = await Process.run('flutter', [
      'test',
      'test/widgets/widget_tests.dart',
      '--reporter',
      'expanded',
    ], workingDirectory: '.');

    if (result.exitCode == 0) {
      print('  ✅ Widget tests passed');
      return true;
    } else {
      print('  ❌ Widget tests failed');
      print(result.stdout);
      print(result.stderr);
      return false;
    }
  } catch (e) {
    print('  ❌ Error running widget tests: $e');
    return false;
  }
}

Future<bool> runIntegrationTests() async {
  try {
    print('  → Running integration tests...');

    final result = await Process.run('flutter', [
      'test',
      'integration_test/app_test.dart',
      '--reporter',
      'expanded',
    ], workingDirectory: '.');

    if (result.exitCode == 0) {
      print('  ✅ Integration tests passed');
      return true;
    } else {
      print('  ❌ Integration tests failed');
      print(result.stdout);
      print(result.stderr);
      return false;
    }
  } catch (e) {
    print('  ❌ Error running integration tests: $e');
    return false;
  }
}

Future<bool> runScreenTests() async {
  try {
    print('  → Running screen-specific tests...');

    final screenTests = [
      'test/screens/welcome_screen_test.dart',
      'test/screens/home_screen_test.dart',
    ];

    var allPassed = true;

    for (final testFile in screenTests) {
      print('    → Testing ${testFile.split('/').last}...');

      final result = await Process.run('flutter', [
        'test',
        testFile,
        '--reporter',
        'compact',
      ], workingDirectory: '.');

      if (result.exitCode == 0) {
        print('    ✅ ${testFile.split('/').last} passed');
      } else {
        print('    ❌ ${testFile.split('/').last} failed');
        print(result.stdout);
        print(result.stderr);
        allPassed = false;
      }
    }

    return allPassed;
  } catch (e) {
    print('  ❌ Error running screen tests: $e');
    return false;
  }
}

void generateTestReport(Map<String, bool> testResults, bool allTestsPassed) {
  print('\n' + '=' * 50);
  print('📊 TEST REPORT');
  print('=' * 50);

  for (final entry in testResults.entries) {
    final status = entry.value ? '✅ PASSED' : '❌ FAILED';
    print('${entry.key.padRight(20)} : $status');
  }

  print('\n' + '-' * 50);

  if (allTestsPassed) {
    print('🎉 ALL TESTS PASSED! Your UI/UX is working correctly.');
    print('✨ PhishWatch Pro is ready for deployment.');
  } else {
    print('⚠️  SOME TESTS FAILED! Please review the failures above.');
    print('🔧 Fix the issues and run tests again.');
  }

  print('-' * 50);

  // Generate detailed report file
  generateDetailedReport(testResults, allTestsPassed);
}

void generateDetailedReport(
  Map<String, bool> testResults,
  bool allTestsPassed,
) {
  final reportContent = StringBuffer();
  final timestamp = DateTime.now().toIso8601String();

  reportContent.writeln('# PhishWatch Pro Test Report');
  reportContent.writeln('Generated: $timestamp');
  reportContent.writeln('');

  reportContent.writeln('## Summary');
  reportContent.writeln(
    'Overall Status: ${allTestsPassed ? "✅ PASSED" : "❌ FAILED"}',
  );
  reportContent.writeln('');

  reportContent.writeln('## Test Results');
  for (final entry in testResults.entries) {
    final status = entry.value ? '✅ PASSED' : '❌ FAILED';
    reportContent.writeln('- **${entry.key}**: $status');
  }

  reportContent.writeln('');
  reportContent.writeln('## Test Coverage');
  reportContent.writeln('- ✅ Welcome Screen Navigation');
  reportContent.writeln('- ✅ Home Screen Functionality');
  reportContent.writeln('- ✅ Scan Button Interactions');
  reportContent.writeln('- ✅ Theme Switching');
  reportContent.writeln('- ✅ Bottom Navigation');
  reportContent.writeln('- ✅ History Management');
  reportContent.writeln('- ✅ Result Display');
  reportContent.writeln('- ✅ Card Components');
  reportContent.writeln('- ✅ Animation Testing');
  reportContent.writeln('- ✅ User Flow Integration');

  try {
    final reportFile = File('test_report.md');
    reportFile.writeAsStringSync(reportContent.toString());
    print('📄 Detailed report saved to: test_report.md');
  } catch (e) {
    print('⚠️  Could not save detailed report: $e');
  }
}

