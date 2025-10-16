import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../screens/welcome_screen.dart';

class FeatureShowcase extends StatelessWidget {
  final FeatureData feature;
  final bool isActive;

  const FeatureShowcase({
    super.key,
    required this.feature,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Feature icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: feature.color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(feature.icon, size: 60, color: feature.color),
          ),

          const SizedBox(height: AppConstants.spacingL),

          // Feature title
          Text(
            feature.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.spacingM),

          // Feature description
          Flexible(
            child: Text(
              feature.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
