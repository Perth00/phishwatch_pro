import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/sound_service.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';

class RecentResultCard extends StatefulWidget {
  const RecentResultCard({super.key});

  @override
  State<RecentResultCard> createState() => _RecentResultCardState();
}

class _RecentResultCardState extends State<RecentResultCard> {
  bool _isContentVisible = false;

  void _toggleContentVisibility() {
    setState(() {
      _isContentVisible = !_isContentVisible;
    });
    SoundService.playButtonSound();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final history = context.watch<HistoryService>();
    final item = history.latest;

    if (item == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Row(
            children: [
              const Icon(Icons.history, color: AppTheme.primaryColor),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Text(
                  'No scans yet. Your latest scan will appear here.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                    color: (item.isPhishing
                            ? AppTheme.errorColor
                            : AppTheme.successColor)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isPhishing
                            ? Icons.dangerous_outlined
                            : Icons.verified_outlined,
                        size: 16,
                        color:
                            item.isPhishing
                                ? AppTheme.errorColor
                                : AppTheme.successColor,
                      ),
                      const SizedBox(width: AppConstants.spacingXS),
                      Text(
                        item.classification,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              item.isPhishing
                                  ? AppTheme.errorColor
                                  : AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  ((item.confidence * 100).toStringAsFixed(1)) + '% Confidence',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        item.isPhishing
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Message source
            Text(
              'Source: ' + item.source,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Message preview (with toggle visibility)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.spacingS),
              ),
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: _isContentVisible ? 1.0 : 0.3,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isContentVisible ? item.message : item.preview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  // Interactive overlay
                  if (!_isContentVisible)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(
                            AppConstants.spacingS,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleContentVisibility,
                            borderRadius: BorderRadius.circular(
                              AppConstants.spacingS,
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      color: colorScheme.onSurface.withOpacity(
                                        0.7,
                                      ),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tap to reveal',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Hide button when content is visible
                  if (_isContentVisible)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleContentVisibility,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.visibility_off_outlined,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingM),

            // Suspicious elements (show/hide based on content visibility)
            AnimatedOpacity(
              opacity: _isContentVisible ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    children:
                        _isContentVisible
                            ? [
                              _buildSuspiciousTag(context, 'Urgency tactics'),
                              _buildSuspiciousTag(context, 'Suspicious domain'),
                              _buildSuspiciousTag(
                                context,
                                'Request for credentials',
                              ),
                              _buildSuspiciousTag(
                                context,
                                'Fake security warning',
                              ),
                              _buildSuspiciousTag(
                                context,
                                'Credential harvesting',
                              ),
                            ]
                            : [
                              _buildSuspiciousTag(context, 'Urgency tactics'),
                              _buildSuspiciousTag(context, 'Suspicious domain'),
                              _buildSuspiciousTag(
                                context,
                                'Request for credentials',
                              ),
                            ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.spacingL),

            // View details button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    () => context.go(
                      '/scan-result',
                      extra: item.toScanResultData(),
                    ),
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
