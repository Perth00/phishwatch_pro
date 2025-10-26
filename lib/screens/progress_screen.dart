import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_theme.dart';
import '../models/learning_content.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import '../widgets/animated_card.dart';
import '../widgets/progress_indicator_widget.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        leading: BackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Fallback to learn screen to avoid dead-ends/black screens
              context.go('/learn');
            }
          },
        ),
      ),
      body:
          auth.isAuthenticated
              ? _buildAuthenticated(theme)
              : _buildGuest(theme, context),
    );
  }

  Widget _buildGuest(ThemeData theme, BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Sign in to track your progress'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticated(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      children: [
        AnimatedCard(
          delay: const Duration(milliseconds: 100),
          child: _OverallHeaderCard(theme: theme),
        ),
        const SizedBox(height: AppConstants.spacingL),
        AnimatedCard(
          delay: const Duration(milliseconds: 200),
          child: _AccuracyChart(theme: theme),
        ),
        const SizedBox(height: AppConstants.spacingL),
        AnimatedCard(
          delay: const Duration(milliseconds: 300),
          child: _CategoryProgressGrid(theme: theme),
        ),
      ],
    );
  }
}

class _OverallHeaderCard extends StatelessWidget {
  final ThemeData theme;
  const _OverallHeaderCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Overall badge
          StreamBuilder<String>(
            stream: context.read<ProgressService>().watchOverallLevel(),
            builder: (context, snap) {
              final level = snap.data ?? 'Beginner';
              return _pill('Level: $level', AppTheme.primaryColor);
            },
          ),
          const Spacer(),
          _UserStats(theme: theme),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserStats extends StatelessWidget {
  final ThemeData theme;
  const _UserStats({required this.theme});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    // Use user doc for basic counters; chart computes accuracy separately
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = (snap.data?.data() ?? <String, dynamic>{});
        final stats = Map<String, dynamic>.from(data['stats'] ?? {});
        final quizzes = (stats['quizzesCompleted'] ?? 0) as int;
        final scenarios = (stats['scenariosCompleted'] ?? 0) as int;
        final lessons = (stats['lessonsCompleted'] ?? 0) as int;
        return Row(
          children: [
            _stat('Quizzes', quizzes, AppTheme.primaryColor),
            const SizedBox(width: 12),
            _stat('Scenarios', scenarios, AppTheme.warningColor),
            const SizedBox(width: 12),
            _stat('Lessons', lessons, AppTheme.successColor),
          ],
        );
      },
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _AccuracyChart extends StatelessWidget {
  final ThemeData theme;
  const _AccuracyChart({required this.theme});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Quiz Accuracy', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('quizzes')
                    .orderBy('completedAt', descending: true)
                    .limit(7)
                    .snapshots(),
            builder: (context, snap) {
              final docs =
                  snap.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final accuracies =
                  docs
                      .map((d) => (d.data()['accuracy'] ?? 0.0) as num)
                      .toList()
                      .reversed
                      .toList();
              if (accuracies.isEmpty) {
                return Text(
                  'No quiz attempts yet. Take a quiz to see your progress!',
                  style: theme.textTheme.bodySmall,
                );
              }
              final sections =
                  accuracies.asMap().entries.map((e) {
                    final value = e.value.toDouble().clamp(0, 100);
                    final color = AppTheme.primaryColor.withOpacity(
                      0.4 + 0.5 * (value / 100),
                    );
                    return PieChartSectionData(
                      value: value <= 0 ? 1.0 : value.toDouble(),
                      color: color,
                      title: '${value.toStringAsFixed(0)}%',
                      radius: 50 + (value / 100) * 20,
                      titleStyle: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    );
                  }).toList();

              return SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (evt, resp) {
                        // Tooltip via SnackBar on touch
                        if (resp?.touchedSection != null &&
                            evt is FlTapUpEvent) {
                          final v = resp!.touchedSection!.touchedSection!.value;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Accuracy: ${v.toStringAsFixed(0)}%',
                              ),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  swapAnimationDuration: AppAnimations.normalAnimation,
                  swapAnimationCurve: AppAnimations.defaultCurve,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryProgressGrid extends StatelessWidget {
  final ThemeData theme;
  const _CategoryProgressGrid({required this.theme});

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesFromRepository();
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Per-Category Progress', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...categories.map((c) => _categoryRow(context, c)).toList(),
        ],
      ),
    );
  }

  List<_CategoryInfo> _categoriesFromRepository() {
    final Map<String, int> totals = {};
    for (final q in LearningRepository.quizzes) {
      totals.update(q.category, (v) => v + 1, ifAbsent: () => 1);
    }
    return totals.entries
        .map((e) => _CategoryInfo(name: e.key, total: e.value))
        .toList();
  }

  Widget _categoryRow(BuildContext context, _CategoryInfo info) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(info.name)),
          SizedBox(
            width: 180,
            child: StreamBuilder<int>(
              stream: context
                  .read<ProgressService>()
                  .watchCompletedQuizzesCount(category: info.name),
              builder: (context, snap) {
                final completed = (snap.data ?? 0).clamp(0, info.total);
                final progress =
                    info.total == 0
                        ? 0.0
                        : completed.toDouble() / info.total.toDouble();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ProgressIndicatorWidget(
                      progress: progress,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed/${info.total}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryInfo {
  final String name;
  final int total;
  _CategoryInfo({required this.name, required this.total});
}
