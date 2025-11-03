import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/progress_service.dart';
import '../widgets/quiz_card.dart';
import '../widgets/locked_overlay.dart';
import '../widgets/filter_bar.dart';
import 'learn_screen.dart';
// Video scenario imports removed; All Quizzes shows only quizzes

class AllQuizzesScreen extends StatefulWidget {
  const AllQuizzesScreen({super.key});

  @override
  State<AllQuizzesScreen> createState() => _AllQuizzesScreenState();
}

class _AllQuizzesScreenState extends State<AllQuizzesScreen> {
  Map<String, String> _levels = <String, String>{};
  String _filterCategory = 'All';
  String _filterLevel = 'All';
  // Type filter removed; All Quizzes lists only quizzes

  static const Map<String, int> _totalLessonsByCategory = <String, int>{
    'Basics': 5,
    'Email Security': 4,
    'Web Safety': 3,
    'Advanced': 6,
  };

  static const List<String> _order = <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  int _idx(String level) => _order.indexOf(level).clamp(0, _order.length - 1);

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    final Map<String, String> lvls =
        await context.read<ProgressService>().getCategoryLevels();
    if (!mounted) return;
    setState(() => _levels = lvls);
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = LearningRepository.quizzes;
    // Build from fixed categories to ensure all appear
    const List<String> categories = [
      'Basics',
      'Email Security',
      'Web Safety',
      'Advanced',
    ];
    Quiz _pickBase(String cat) {
      try {
        return quizzes.firstWhere((q) => q.category == cat);
      } catch (_) {
        return quizzes.first; // fallback
      }
    }

    final List<({String category, String level, Quiz quiz})>
    entries = <({String category, String level, Quiz quiz})>[];
    for (final cat in categories) {
      final base = _pickBase(cat);
      for (final level in ['Beginner', 'Intermediate', 'Advanced']) {
        entries.add((category: cat, level: level, quiz: base));
      }
    }
    const List<String> catOrder = [
      'Basics',
      'Email Security',
      'Web Safety',
      'Advanced',
    ];
    const List<String> levelOrder = ['Beginner', 'Intermediate', 'Advanced'];
    entries.sort((a, b) {
      final ai = catOrder.indexOf(a.category);
      final bi = catOrder.indexOf(b.category);
      if (ai != bi) return ai.compareTo(bi);
      final al = levelOrder.indexOf(a.level);
      final bl = levelOrder.indexOf(b.level);
      if (al != bl) return al.compareTo(bl);
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Quizzes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final popped = await Navigator.of(context).maybePop();
            if (!popped && context.mounted) context.go('/learn');
          },
        ),
      ),
      body: Column(
        children: [
          _buildFiltersTop(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              itemCount:
                  entries
                      .where(
                        (e) =>
                            _filterCategory == 'All'
                                ? true
                                : e.category == _filterCategory,
                      )
                      .where(
                        (e) =>
                            _filterLevel == 'All'
                                ? true
                                : e.level == _filterLevel,
                      )
                      .length,
              separatorBuilder:
                  (_, __) => const SizedBox(height: AppConstants.spacingM),
              itemBuilder: (context, i) {
                final filtered =
                    entries
                        .where(
                          (e) =>
                              _filterCategory == 'All'
                                  ? true
                                  : e.category == _filterCategory,
                        )
                        .where(
                          (e) =>
                              _filterLevel == 'All'
                                  ? true
                                  : e.level == _filterLevel,
                        )
                        .toList();
                final e = filtered[i];
                final String category = e.category;
                final String level = e.level;
                final String userLevel = _levels[category] ?? 'Beginner';
                final bool locked = _idx(level) > _idx(userLevel);

                {
                  final q = e.quiz;
                  final String quizId =
                      'quiz_${category.toLowerCase().replaceAll(' ', '_')}_${level.toLowerCase()}';
                  final int totalLessons =
                      _totalLessonsByCategory[category] ?? 5;
                  final card = QuizCard(
                    quiz: QuizData(
                      id: quizId,
                      title: category,
                      description: 'Practice in $category',
                      difficulty: level,
                      questions: q.questions.length,
                      timeMinutes: 5,
                      completedAt: null,
                      score: null,
                    ),
                    category: category,
                    totalLessons: totalLessons,
                    onTap: () {
                      if (locked) {
                        _showLockedHint(context, category, level);
                        return;
                      }
                      () async {
                        final bool? ok = await showDialog<bool>(
                          context: context,
                          barrierDismissible: true,
                          builder:
                              (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('Start quiz?'),
                                content: Text('Start $category • $level now?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Start'),
                                  ),
                                ],
                              ),
                        );
                        if (ok != true) return;
                        if (!context.mounted) return;
                        context.go(
                          '/quiz/$quizId',
                          extra: {
                            'overrideCategory': category,
                            'overrideLevel': level,
                            'overrideTitle': '$category • $level',
                          },
                        );
                      }();
                    },
                  );
                  if (!locked) return card;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius,
                    ),
                    child: Stack(
                      children: [
                        ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.grey,
                            BlendMode.saturation,
                          ),
                          child: card,
                        ),
                        const LockedOverlay(),
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius,
                              ),
                              onTap:
                                  () =>
                                      _showLockedHint(context, category, level),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Video scenarios are not displayed on All Quizzes page
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedHint(BuildContext context, String category, String level) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unlock $level in $category by passing more attempts.'),
      ),
    );
  }

  Widget _buildFiltersTop() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedFilterBar(
          categories: const [
            'All',
            'Basics',
            'Email Security',
            'Web Safety',
            'Advanced',
          ],
          levels: const ['All', 'Beginner', 'Intermediate', 'Advanced'],
          selectedCategory: _filterCategory,
          selectedLevel: _filterLevel,
          onChanged: (cat, lvl) {
            setState(() {
              _filterCategory = cat ?? 'All';
              _filterLevel = lvl ?? 'All';
            });
          },
          gradientStart: AppTheme.primaryColor,
          gradientEnd: AppTheme.accentColor,
        ),
        // Extra row removed; the type chips are now integrated above
      ],
    );
  }
}
