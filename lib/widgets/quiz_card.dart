import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/progress_service.dart';
import '../screens/learn_screen.dart';
import 'animated_card.dart';

class QuizCard extends StatelessWidget {
  final QuizData quiz;
  final VoidCallback onTap;
  final int totalLessons;
  final String category;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.onTap,
    required this.totalLessons,
    required this.category,
  });

  Color get _categoryColor {
    switch (category) {
      case 'Basics':
        return AppTheme.primaryColor; // purple/indigo
      case 'Email Security':
        return AppTheme.warningColor; // yellow/amber
      case 'Web Safety':
        return AppTheme.successColor; // green
      case 'Advanced':
        return AppTheme.errorColor; // red
      default:
        return AppTheme.primaryColor;
    }
  }

  Color get _difficultyColor {
    switch (quiz.difficulty.toLowerCase()) {
      case 'beginner':
        return AppTheme.successColor;
      case 'intermediate':
        return AppTheme.warningColor;
      case 'advanced':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _difficultyIcon {
    switch (quiz.difficulty.toLowerCase()) {
      case 'beginner':
        return Icons.school_outlined;
      case 'intermediate':
        return Icons.trending_up_outlined;
      case 'advanced':
        return Icons.psychology_outlined;
      default:
        return Icons.quiz_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopOutCard(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: _categoryColor.withOpacity(0.45), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: _categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _difficultyIcon,
                      color: _categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _difficultyColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _difficultyColor.withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            quiz.difficulty,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _difficultyColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category progress percent for this quiz's category+level
                  StreamBuilder<int>(
                    stream: context
                        .read<ProgressService>()
                        .watchCompletedQuizzesCount(
                          category: category,
                          difficulty: quiz.difficulty,
                        ),
                    builder: (context, snap) {
                      final int completed = (snap.data ?? 0).clamp(
                        0,
                        totalLessons,
                      );
                      final int percent =
                          totalLessons == 0
                              ? 0
                              : ((completed / totalLessons) * 100).round();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingS,
                          vertical: AppConstants.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: _categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.percent,
                              color: _categoryColor,
                              size: 16,
                            ),
                            const SizedBox(width: AppConstants.spacingXS),
                            Text(
                              '$percent%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.spacingM),

              // Description
              Text(
                quiz.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: AppConstants.spacingM),

              // Quiz details
              Row(
                children: [
                  _buildDetailChip(
                    icon: Icons.quiz_outlined,
                    label: '${quiz.questions} questions',
                    theme: theme,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  // Duration chip from Firestore if available
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: context.read<ProgressService>().watchQuizResult(
                      quizId: quiz.id,
                    ),
                    builder: (context, snap) {
                      final int? dur = (snap.data?['durationSec'] as int?);
                      final String label =
                          dur != null
                              ? '${(dur / 60).ceil()} min'
                              : '${quiz.timeMinutes} min';
                      return _buildDetailChip(
                        icon: Icons.timer_outlined,
                        label: label,
                        theme: theme,
                      );
                    },
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: _categoryColor.withOpacity(0.9),
                  ),
                ],
              ),

              // Completed time from Firestore
              StreamBuilder<Map<String, dynamic>?>(
                stream: context.read<ProgressService>().watchQuizResult(
                  quizId: quiz.id,
                ),
                builder: (context, snap) {
                  final dynamic ts = snap.data?['completedAt'];
                  DateTime? dt;
                  if (ts is DateTime) dt = ts;
                  if (ts is Timestamp) dt = ts.toDate();
                  if (dt == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      const SizedBox(height: AppConstants.spacingM),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.spacingS),
                        decoration: BoxDecoration(
                          color: _categoryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _categoryColor.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          'Completed on ${_formatDate(dt)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _categoryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Today';
    }
  }
}
