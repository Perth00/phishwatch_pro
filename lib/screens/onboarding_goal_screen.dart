import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/progress_service.dart';
import 'package:go_router/go_router.dart';

class OnboardingGoalScreen extends StatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  State<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends State<OnboardingGoalScreen> {
  String _selected = 'casual';

  Future<void> _continue() async {
    final progress = context.read<ProgressService>();
    await progress.ensureUserProfile(goal: _selected);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Goal')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you like to learn?',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _GoalTile(
              value: 'casual',
              group: _selected,
              title: 'Casual learner',
              subtitle: 'Short lessons for daily learning',
              onChanged: (v) => setState(() => _selected = v!),
            ),
            _GoalTile(
              value: 'employee',
              group: _selected,
              title: 'Employee training',
              subtitle: 'Practice on real-world corporate scenarios',
              onChanged: (v) => setState(() => _selected = v!),
            ),
            _GoalTile(
              value: 'exam',
              group: _selected,
              title: 'Exam prep',
              subtitle: 'Prepare for security awareness assessments',
              onChanged: (v) => setState(() => _selected = v!),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continue,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final String value;
  final String group;
  final String title;
  final String subtitle;
  final ValueChanged<String?> onChanged;

  const _GoalTile({
    required this.value,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Card(
      child: RadioListTile<String>(
        value: value,
        groupValue: group,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
        selected: selected,
      ),
    );
  }
}


