import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/video_scenario.dart';

class VideoScenarioCard extends StatelessWidget {
  final VideoScenario scenario;
  final VoidCallback onTap;

  const VideoScenarioCard({
    super.key,
    required this.scenario,
    required this.onTap,
  });

  // Category color kept previously; no longer needed since we vary by level and random accent.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keep cat available for future use (e.g., subtitles), currently accents use lvl/randomBorder
    Color _levelColor(String level) {
      switch (level.toLowerCase()) {
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

    // Keep mapping in case we need level color elsewhere
    final Color _ = _levelColor(scenario.difficulty);
    // Use a deterministic accent for both border and icons so they match visually
    final int hash = scenario.id.codeUnits.fold(
      0,
      (p, c) => (p * 31 + c) & 0x7fffffff,
    );
    final List<Color> palette = <Color>[
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.infoColor,
    ];
    final Color accent = palette[hash % palette.length];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: BorderSide(color: accent.withOpacity(0.65), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingS),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.play_circle_outline, color: accent),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Text(
                      scenario.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: Text(
                      scenario.difficulty,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
              Row(
                children: [
                  Icon(Icons.ondemand_video, color: accent),
                  const SizedBox(width: 6),
                  Text('Watch and answer', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
