import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../screens/scan_history_screen.dart';
import '../models/history_item.dart';

class HistoryItemCard extends StatefulWidget {
  final HistoryItem item;
  final VoidCallback onTap;

  const HistoryItemCard({super.key, required this.item, required this.onTap});

  @override
  State<HistoryItemCard> createState() => _HistoryItemCardState();
}

class _HistoryItemCardState extends State<HistoryItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.fastAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _classificationColor {
    switch (widget.item.classification.toLowerCase()) {
      case 'phishing':
        return AppTheme.errorColor;
      case 'suspicious':
        return AppTheme.warningColor;
      case 'safe':
        return AppTheme.successColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData get _classificationIcon {
    switch (widget.item.classification.toLowerCase()) {
      case 'phishing':
        return Icons.dangerous_outlined;
      case 'suspicious':
        return Icons.warning_outlined;
      case 'safe':
        return Icons.verified_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _formatConfidence(double confidence) {
    final double pct = confidence * 100;
    if (pct >= 100.0) return '100%';
    if (pct <= 0.0) return '0%';
    return '${pct.toStringAsFixed(1)}%';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: widget.onTap,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        // Classification badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingS,
                            vertical: AppConstants.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: _classificationColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _classificationIcon,
                                size: 16,
                                color: _classificationColor,
                              ),
                              const SizedBox(width: AppConstants.spacingXS),
                              Text(
                                widget.item.classification,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: _classificationColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Timestamp
                        Text(
                          _formatTimestamp(widget.item.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spacingS),

                    // Confidence and risk level
                    Row(
                      children: [
                        Text(
                          'Confidence: ${_formatConfidence(widget.item.confidence)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _classificationColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingM),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingXS,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.outline.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            widget.item.riskLevel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.spacingS),

                    // Source
                    Text(
                      'From: ${widget.item.source}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: AppConstants.spacingS),

                    // Preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppConstants.spacingS),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppConstants.spacingXS,
                        ),
                      ),
                      child: Text(
                        widget.item.preview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: AppConstants.spacingS),

                    // Action indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'View Details',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXS),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
