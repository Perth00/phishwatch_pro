import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';

class RecentResultCard extends StatelessWidget {
  const RecentResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: AppConstants.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        size: 16,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(width: AppConstants.spacingXS),
                      Text(
                        'Phishing Detected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '92.4% Confidence',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Message source
            Text(
              'Message from: unknown@securebank-verify.com',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Message preview (blurred)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.spacingS),
              ),
              child: Stack(
                children: [
                  Text(
                    '...clicking this link to verify...within 24 hours.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  // Blur overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(
                          AppConstants.spacingS,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.visibility_off_outlined,
                          color: colorScheme.onSurface.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Suspicious elements
            Text(
              'Suspicious elements:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppConstants.spacingS),

            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingXS,
              children: [
                _buildSuspiciousTag(context, 'Urgency tactics'),
                _buildSuspiciousTag(context, 'Suspicious domain'),
                _buildSuspiciousTag(context, 'Request for credentials'),
              ],
            ),

            const SizedBox(height: AppConstants.spacingL),

            // View details button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/scan-result'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspiciousTag(BuildContext context, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingXS,
      ),
      decoration: BoxDecoration(
        color: colorScheme.outline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }
}
