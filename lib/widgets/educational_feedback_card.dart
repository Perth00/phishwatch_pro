import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../services/gemini_service.dart';

/// Widget that displays educational feedback from Gemini analysis
class EducationalFeedbackCard extends StatelessWidget {
  const EducationalFeedbackCard({
    super.key,
    required this.analysis,
    required this.isPhishing,
  });

  final GeminiAnalysis analysis;
  final bool isPhishing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accentColor =
        isPhishing ? AppTheme.errorColor : AppTheme.successColor;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isPhishing ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: accentColor,
                  size: 24,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    isPhishing
                        ? 'Why This is Phishing'
                        : 'Why This is Legitimate',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Explanation
            Text(
              analysis.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            ),

            const SizedBox(height: AppConstants.spacingL),

            // Suspicious/Positive Elements
            _buildSection(
              theme: theme,
              title:
                  isPhishing
                      ? 'Suspicious Elements Found:'
                      : 'Positive Indicators:',
              items: analysis.suspiciousElements,
              accentColor: accentColor,
              icon:
                  isPhishing ? Icons.error_outline : Icons.check_circle_outline,
            ),

            const SizedBox(height: AppConstants.spacingL),

            // Recommendations / Safety Tips
            _buildRecommendationSection(
              theme: theme,
              tips: analysis.safetyTips,
              isPhishing: isPhishing,
            ),

            if (analysis.reasoning.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingL),

              // Educational Reasoning (Expandable)
              _buildReasoningSection(
                theme: theme,
                reasoning: analysis.reasoning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required List<String> items,
    required Color accentColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationSection({
    required ThemeData theme,
    required List<String> tips,
    required bool isPhishing,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color:
            isPhishing
                ? AppTheme.errorColor.withOpacity(0.08)
                : AppTheme.successColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.spacingS),
        border: Border.all(
          color:
              isPhishing
                  ? AppTheme.errorColor.withOpacity(0.2)
                  : AppTheme.successColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: isPhishing ? AppTheme.errorColor : AppTheme.successColor,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'Recommendation',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isPhishing ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          if (isPhishing)
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppConstants.spacingS),
              ),
              child: Text(
                'DO NOT click any links, download attachments, or provide personal information. Delete this message immediately.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Safety Tips:',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningSection({
    required ThemeData theme,
    required String reasoning,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(
        left: AppConstants.spacingM,
        right: AppConstants.spacingM,
        bottom: AppConstants.spacingM,
      ),
      title: Row(
        children: [
          Icon(Icons.school_outlined, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            'Learn More',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      children: [
        Text(
          reasoning,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Loading widget shown while Gemini analysis is in progress
class EducationalFeedbackLoading extends StatelessWidget {
  const EducationalFeedbackLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Text(
                    'Generating educational insights...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            LinearProgressIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error widget shown when Gemini analysis fails
class EducationalFeedbackError extends StatelessWidget {
  const EducationalFeedbackError({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Could not generate educational insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Educational feedback requires an API key configuration.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppConstants.spacingM),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
