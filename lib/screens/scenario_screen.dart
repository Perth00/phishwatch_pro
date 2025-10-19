import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';

class ScenarioScreen extends StatefulWidget {
  final String scenarioId;
  const ScenarioScreen({super.key, required this.scenarioId});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  bool? _answer; // true = phishing, false = safe
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated || !(auth.currentUser?.emailVerified ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scenario')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please sign in and verify your email to try scenarios.',
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/register'),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final scenario = LearningRepository.getScenario(widget.scenarioId)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(scenario.title)),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scenario.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ToggleButtons(
              isSelected: [
                (_answer ?? false) == true,
                (_answer ?? true) == false,
              ],
              onPressed: (i) => setState(() => _answer = i == 0),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Phishing'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Safe'),
                ),
              ],
            ),
            const Spacer(),
            if (_submitted) ...[
              Text(
                _answer == scenario.isPhishing ? 'Correct' : 'Incorrect',
                style: TextStyle(
                  color:
                      _answer == scenario.isPhishing
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Why: ${scenario.rationale}'),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _answer == null
                        ? null
                        : () async {
                          await context
                              .read<ProgressService>()
                              .recordScenarioAttempt(
                                scenarioId: scenario.id,
                                correct: _answer == scenario.isPhishing,
                              );
                          if (mounted) setState(() => _submitted = true);
                        },
                child: Text(_submitted ? 'Submitted' : 'Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
