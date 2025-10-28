import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;
  final String? overrideCategory;
  final String? overrideLevel;
  final String? overrideTitle;
  const QuizScreen({
    super.key,
    required this.quizId,
    this.overrideCategory,
    this.overrideLevel,
    this.overrideTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _finished = false;
  bool _loading = true;
  List<MultipleChoiceQuestion> _questions = <MultipleChoiceQuestion>[];
  bool _locked = false;
  final List<int?> _userAnswers = <int?>[];
  final List<bool> _isCorrect = <bool>[];
  int _resetsUsed = 0;
  DateTime? _startTime;

  Future<void> _confirmAndResetQuiz() async {
    if (_resetsUsed >= 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reset limit reached (2)')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          builder:
              (context, scale, child) => Transform.scale(
                scale: scale,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: const [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Reset quiz?'),
                    ],
                  ),
                  content: const Text(
                    'You can reset up to 2 times. This will start from question 1.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
        );
      },
    );
    if (ok == true) {
      setState(() {
        _resetsUsed += 1;
      });
      // Reload a fresh randomized set from CSV for this quiz's category/level
      await _loadQuestions();
      setState(() {
        _index = 0;
        _correct = 0;
        _selected = null;
        _finished = false;
        _locked = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final quizMeta = LearningRepository.getQuiz(widget.quizId)!;
    final String effectiveCategory =
        widget.overrideCategory ?? quizMeta.category;
    final String effectiveLevel = widget.overrideLevel ?? quizMeta.difficulty;
    try {
      final loaded = await context.read<ProgressService>().loadCsvQuestions(
        category: effectiveCategory,
        level: effectiveLevel,
      );
      final chosen = (loaded.isEmpty ? quizMeta.questions : loaded).toList();
      chosen.shuffle();
      // Limit to 10 questions per quiz
      setState(() {
        _questions = chosen.length > 10 ? chosen.take(10).toList() : chosen;
        _loading = false;
        _userAnswers.addAll(List<int?>.filled(_questions.length, null));
        _isCorrect.addAll(List<bool>.filled(_questions.length, false));
      });
      _startTime = DateTime.now();
    } catch (_) {
      setState(() {
        _questions = quizMeta.questions;
        _loading = false;
        _userAnswers.addAll(List<int?>.filled(_questions.length, null));
        _isCorrect.addAll(List<bool>.filled(_questions.length, false));
      });
      _startTime = DateTime.now();
    }
  }

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
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final q = _index < _questions.length ? _questions[_index] : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.overrideTitle ?? quiz.title),
        leading: BackButton(
          onPressed: () {
            SoundService.playButtonSound();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/learn');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child:
            _finished
                ? _buildResult(theme, quiz)
                : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Column(
                    key: ValueKey<int>(_index),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${_index + 1}/${_questions.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(q!.prompt),
                      const SizedBox(height: 8),
                      ...List.generate(q.options.length, (i) {
                        final bool highlight =
                            (_locked || _selected != null) && _selected == i;
                        final bool isRight = i == q.correctIndex;
                        final Color? tileColor =
                            highlight
                                ? (isRight
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor)
                                    .withOpacity(0.15)
                                : null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  highlight
                                      ? (isRight
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor)
                                      : theme.colorScheme.outline.withOpacity(
                                        0.2,
                                      ),
                            ),
                          ),
                          child: RadioListTile<int>(
                            value: i,
                            groupValue: _selected,
                            onChanged: (_) => _onSelectOption(i),
                            title: Text(q.options[i]),
                          ),
                        );
                      }),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                SoundService.playButtonSound();
                                _confirmAndResetQuiz();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  !_locked
                                      ? null
                                      : () {
                                        // Click sound only on navigation
                                        SoundService.playButtonSound();
                                        if (_index + 1 == _questions.length) {
                                          setState(() => _finished = true);
                                          context
                                              .read<ProgressService>()
                                              .recordQuizResult(
                                                quizId: quiz.id,
                                                correct: _correct,
                                                total: _questions.length,
                                                category: quiz.category,
                                                difficulty: quiz.difficulty,
                                                durationSec:
                                                    DateTime.now()
                                                        .difference(
                                                          _startTime ??
                                                              DateTime.now(),
                                                        )
                                                        .inSeconds,
                                              );
                                        } else {
                                          setState(() {
                                            _index++;
                                            _selected = null;
                                            _locked = false;
                                          });
                                        }
                                      },
                              child: Text(
                                _index + 1 == _questions.length
                                    ? 'Finish'
                                    : 'Next',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, Quiz quiz) {
    final percent = (100.0 * _correct / (_questions.length)).toStringAsFixed(0);
    final passed = 100.0 * _correct / _questions.length >= quiz.passPercent;
    // Persist detailed attempt for history and progress
    final answers = <Map<String, dynamic>>[];
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      answers.add({
        'id': q.id,
        'prompt': q.prompt,
        'options': q.options,
        'userIndex': _userAnswers[i],
        'correctIndex': q.correctIndex,
        'userCorrect': _isCorrect[i],
      });
    }
    final int durationSec =
        DateTime.now().difference(_startTime ?? DateTime.now()).inSeconds;
    context.read<ProgressService>().recordQuizAttemptDetailed(
      quizId: quiz.id,
      category: widget.overrideCategory ?? quiz.category,
      difficulty: widget.overrideLevel ?? quiz.difficulty,
      correct: _correct,
      total: _questions.length,
      answers: answers,
      durationSec: durationSec,
    );
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.1),
                  AppTheme.successColor.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.emoji_events : Icons.trending_down,
                  color: passed ? AppTheme.successColor : AppTheme.errorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: $percent%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color:
                              passed
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passed
                            ? 'Great job! Level progressing.'
                            : 'Keep practicing.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Results breakdown', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, i) {
                final q = _questions[i];
                final ua = _userAnswers[i];
                final ok = _isCorrect[i];
                final String userAns =
                    ua == null
                        ? 'No answer'
                        : (ua >= 0 && ua < q.options.length
                            ? q.options[ua]
                            : 'No answer');
                final String rightAns = q.options[q.correctIndex];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color:
                          ok
                              ? AppTheme.successColor.withOpacity(0.4)
                              : AppTheme.errorColor.withOpacity(0.4),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      ok ? Icons.check_circle : Icons.cancel,
                      color: ok ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                    title: Text(q.prompt),
                    subtitle: Text(
                      'Your answer: ' + userAns + ' • Correct: ' + rightAns,
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  context.go('/learn');
                },
                child: const Text('Back to Learn'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  SoundService.playButtonSound();
                  context.push('/progress');
                },
                child: const Text('View Progress'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSelectOption(int i) {
    if (_loading || _finished) return;
    if (_locked) return;
    setState(() {
      _selected = i;
    });
    final q = _questions[_index];
    final bool correctNow = i == q.correctIndex;
    if (correctNow) {
      // Only success sound (no click)
      SoundService.playSuccessSound();
      _locked = true;
      _userAnswers[_index] = i;
      _isCorrect[_index] = true;
      _correct += 1;
      setState(() {});
      return;
    }
    // Single attempt mode: lock on wrong immediately; only error sound
    SoundService.playErrorSound();
    _locked = true;
    _userAnswers[_index] = i;
    _isCorrect[_index] = false;
    setState(() {});
  }
}
