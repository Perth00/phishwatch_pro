import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class AnimatedPageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const AnimatedPageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: AppAnimations.normalAnimation,
          curve: AppAnimations.defaultCurve,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                index == currentPage
                    ? AppTheme.primaryColor
                    : theme.colorScheme.outline.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
