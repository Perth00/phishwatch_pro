import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../screens/learn_screen.dart';
import 'animated_card.dart';

class QuizCard extends StatelessWidget {
  final QuizData quiz;
  final VoidCallback onTap;

  const QuizCard({super.key, required this.quiz, required this.onTap});

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
    final isCompleted = quiz.completedAt != null;

    return PopOutCard(
      onTap: onTap,
      child: Card(
        elevation: 2,
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
                      color: _difficultyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _difficultyIcon,
                      color: _difficultyColor,
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
                        Text(
                          quiz.difficulty,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _difficultyColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: AppConstants.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.successColor,
                            size: 16,
                          ),
                          const SizedBox(width: AppConstants.spacingXS),
                          Text(
                            '${quiz.score}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                  _buildDetailChip(
                    icon: Icons.timer_outlined,
                    label: '${quiz.timeMinutes} min',
                    theme: theme,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),

              if (isCompleted) ...[
                const SizedBox(height: AppConstants.spacingM),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Completed on ${_formatDate(quiz.completedAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.successColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
