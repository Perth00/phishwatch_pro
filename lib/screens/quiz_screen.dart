import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  const QuizScreen({super.key, required this.quizId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    // If user is not authenticated or not verified, show guard
    final auth = context.watch<AuthService>();
    if (!auth.isAuthenticated || !(auth.currentUser?.emailVerified ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please sign in and verify your email to take quizzes.',
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
    final quiz = LearningRepository.getQuiz(widget.quizId)!;
    final theme = Theme.of(context);
    final q = _index < quiz.questions.length ? quiz.questions[_index] : null;
    return Scaffold(
      appBar: AppBar(title: Text(quiz.title)),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child:
            _finished
                ? _buildResult(theme, quiz)
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${_index + 1}/${quiz.questions.length}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(q!.prompt),
                    const SizedBox(height: 8),
                    ...List.generate(q.options.length, (i) {
                      return RadioListTile<int>(
                        value: i,
                        groupValue: _selected,
                        onChanged: (v) => setState(() => _selected = v),
                        title: Text(q.options[i]),
                      );
                    }),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _selected == null
                                ? null
                                : () {
                                  if (_selected == q.correctIndex) _correct++;
                                  if (_index + 1 == quiz.questions.length) {
                                    setState(() => _finished = true);
                                    context
                                        .read<ProgressService>()
                                        .recordQuizResult(
                                          quizId: quiz.id,
                                          correct: _correct,
                                          total: quiz.questions.length,
                                        );
                                  } else {
                                    setState(() {
                                      _index++;
                                      _selected = null;
                                    });
                                  }
                                },
                        child: Text(
                          _index + 1 == quiz.questions.length
                              ? 'Finish'
                              : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, Quiz quiz) {
    final percent = (100.0 * _correct / (quiz.questions.length))
        .toStringAsFixed(0);
    final passed = 100.0 * _correct / quiz.questions.length >= quiz.passPercent;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Score: $percent%',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: passed ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(passed ? 'Great job! Level progressing.' : 'Keep practicing.'),
        ],
      ),
    );
  }
}
