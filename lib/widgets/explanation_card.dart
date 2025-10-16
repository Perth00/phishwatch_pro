import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class ExplanationCard extends StatelessWidget {
  final bool isPhishing;
  final double confidence;
  final List<String> suspiciousElements;
  final String? title;
  final String? description;
  final List<String>? explanations;

  const ExplanationCard({
    super.key,
    required this.isPhishing,
    required this.confidence,
    required this.suspiciousElements,
    this.title,
    this.description,
    this.explanations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTitle =
        title ?? (isPhishing ? 'Why This is Phishing' : 'Why This is Safe');
    final effectiveDescription = description ?? _getDefaultDescription();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isPhishing ? Icons.warning_amber : Icons.info_outline,
                  color:
                      isPhishing
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    effectiveTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          isPhishing
                              ? AppTheme.warningColor
                              : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Description
            Text(
              effectiveDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            ),

            if (suspiciousElements.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingL),

              // Suspicious elements
              Text(
                isPhishing
                    ? 'Suspicious Elements Found:'
                    : 'Safety Indicators:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppConstants.spacingM),

              ...suspiciousElements.map(
                (element) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isPhishing
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color:
                            isPhishing
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Expanded(
                        child: Text(
                          element,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (explanations != null && explanations!.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingL),

              Text(
                'Detailed Analysis:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppConstants.spacingM),

              ...explanations!.map(
                (explanation) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(
                        AppConstants.spacingS,
                      ),
                    ),
                    child: Text(
                      explanation,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppConstants.spacingL),

            // Action recommendation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: (isPhishing
                        ? AppTheme.errorColor
                        : AppTheme.successColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.spacingS),
                border: Border.all(
                  color: (isPhishing
                          ? AppTheme.errorColor
                          : AppTheme.successColor)
                      .withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isPhishing ? Icons.block : Icons.thumb_up,
                        color:
                            isPhishing
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(
                        'Recommendation',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              isPhishing
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    _getRecommendation(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDefaultDescription() {
    if (isPhishing) {
      return 'Our analysis has identified several indicators that suggest this message is likely a phishing attempt designed to steal your personal information or credentials.';
    } else {
      return 'Our analysis indicates this message appears to be legitimate and safe, though you should always exercise caution with any unsolicited communications.';
    }
  }

  String _getRecommendation() {
    if (isPhishing) {
      if (confidence > 0.8) {
        return 'DO NOT click any links, download attachments, or provide personal information. Delete this message immediately.';
      } else if (confidence > 0.6) {
        return 'Exercise extreme caution. Verify the sender through official channels before taking any action.';
      } else {
        return 'Be cautious and verify the legitimacy of this message before proceeding.';
      }
    } else {
      return 'While this message appears safe, always verify important requests through official channels and never provide sensitive information via email.';
    }
  }
}
