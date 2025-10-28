import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';

class ScenarioScreen extends StatefulWidget {
  final String scenarioId;
  final String? overrideCategory;
  final String? overrideLevel;
  final String? overrideTitle;
  const ScenarioScreen({
    super.key,
    required this.scenarioId,
    this.overrideCategory,
    this.overrideLevel,
    this.overrideTitle,
  });

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  bool _loading = true;
  late String _category;
  late String _level;
  List<Scenario> _scenarios = <Scenario>[];
  int _index = 0;
  bool? _selected; // true = phishing, false = safe
  // Single-attempt mode; lock after first choice
  bool _locked = false;
  final List<bool?> _userAnswers = <bool?>[];
  final List<bool> _isCorrect = <bool>[];
  int _resetsUsed = 0;
  DateTime? _questionStart;

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
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scenario Practice'),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_index >= _scenarios.length) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scenario Results'),
          leading: BackButton(
            onPressed: () {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary (${_scenarios.length} questions)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _scenarios.length,
                  itemBuilder: (context, i) {
                    final sc = _scenarios[i];
                    final ok = _isCorrect[i];
                    return ListTile(
                      leading: Icon(
                        ok ? Icons.check_circle : Icons.cancel,
                        color: ok ? AppTheme.successColor : AppTheme.errorColor,
                      ),
                      title: Text(sc.title),
                      subtitle: Text(
                        'Your answer: ' +
                            (_userAnswers[i] == true
                                ? 'Phishing'
                                : _userAnswers[i] == false
                                ? 'Safe'
                                : 'No answer') +
                            ' • Correct: ' +
                            (sc.isPhishing ? 'Phishing' : 'Safe'),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      SoundService.playButtonSound();
                      _confirmAndResetScenario();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
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
        ),
      );
    }

    final scenario = _scenarios[_index];
    final bool showFeedback = _locked || _selected != null;
    final bool isCorrectNow =
        _selected != null && _selected == scenario.isPhishing;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_category} • $_level'),
        leading: BackButton(
          onPressed: () {
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Column(
            key: ValueKey<int>(_index),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${_index + 1}/${_scenarios.length}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(scenario.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(scenario.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _locked ? null : () => _onSelect(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            showFeedback && _selected == true
                                ? (isCorrectNow
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor)
                                : null,
                        foregroundColor:
                            showFeedback && _selected == true
                                ? Colors.white
                                : null,
                      ),
                      child: const Text('Phishing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _locked ? null : () => _onSelect(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            showFeedback && _selected == false
                                ? ((!isCorrectNow && _selected == false)
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor)
                                : null,
                        foregroundColor:
                            showFeedback && _selected == false
                                ? Colors.white
                                : null,
                      ),
                      child: const Text('Safe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Single-attempt flow: no attempts counter
              const Spacer(),
              if (_locked) ...[
                Text(
                  _selected == scenario.isPhishing ? 'Correct' : 'Incorrect',
                  style: TextStyle(
                    color:
                        _selected == scenario.isPhishing
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Why: ${scenario.rationale}'),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SoundService.playButtonSound();
                        _resetScenario();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _locked
                              ? () {
                                SoundService.playButtonSound();
                                _next();
                              }
                              : null,
                      child: Text(
                        _index + 1 == _scenarios.length ? 'Finish' : 'Next',
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final meta = LearningRepository.getScenario(widget.scenarioId)!;
    _category = widget.overrideCategory ?? meta.category;
    _level = widget.overrideLevel ?? meta.difficulty;
    final loaded = await context.read<ProgressService>().loadScenarioCsv(
      category: _category,
      level: _level,
    );
    final pick =
        loaded.isEmpty ? [meta] : loaded
          ..shuffle();
    setState(() {
      _scenarios = pick.length > 10 ? pick.take(10).toList() : pick;
      _userAnswers.addAll(List<bool?>.filled(_scenarios.length, null));
      _isCorrect.addAll(List<bool>.filled(_scenarios.length, false));
      _loading = false;
    });
    _questionStart = DateTime.now();
  }

  Future<void> _onSelect(bool value) async {
    if (_locked) return;
    setState(() {
      _selected = value;
    });
    final current = _scenarios[_index];
    final correctNow = value == current.isPhishing;
    final int durationSec =
        DateTime.now().difference(_questionStart ?? DateTime.now()).inSeconds;
    if (correctNow) {
      SoundService.playSuccessSound();
      _userAnswers[_index] = value;
      _isCorrect[_index] = true;
      _locked = true;
      await context.read<ProgressService>().recordScenarioAttempt(
        scenarioId: current.id,
        correct: true,
        durationSec: durationSec,
      );
      setState(() {});
      return;
    }
    // Single attempt: lock immediately on wrong answer
    SoundService.playErrorSound();
    _userAnswers[_index] = value;
    _isCorrect[_index] = false;
    _locked = true;
    await context.read<ProgressService>().recordScenarioAttempt(
      scenarioId: current.id,
      correct: false,
      durationSec: durationSec,
    );
    setState(() {});
  }

  void _resetScenario() {
    setState(() {
      _index = 0;
      _selected = null;
      _locked = false;
      // Randomize order on reset
      _scenarios.shuffle();
      for (int i = 0; i < _userAnswers.length; i++) {
        _userAnswers[i] = null;
        _isCorrect[i] = false;
      }
      _questionStart = DateTime.now();
    });
  }

  Future<void> _confirmAndResetScenario() async {
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
                      Text('Reset practice?'),
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
      _resetScenario();
    }
  }

  void _next() {
    if (_index + 1 >= _scenarios.length) {
      setState(() {
        _index = _scenarios.length;
      });
      return;
    }
    setState(() {
      _index += 1;
      _selected = null;
      _locked = false;
      _questionStart = DateTime.now();
    });
  }
}
