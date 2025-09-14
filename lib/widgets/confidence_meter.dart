import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class ConfidenceMeter extends StatefulWidget {
  final double confidence;
  final bool isPhishing;

  const ConfidenceMeter({
    super.key,
    required this.confidence,
    required this.isPhishing,
  });

  @override
  State<ConfidenceMeter> createState() => _ConfidenceMeterState();
}

class _ConfidenceMeterState extends State<ConfidenceMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.slowAnimation,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: widget.confidence).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    // Start animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _confidenceColor {
    if (widget.isPhishing) {
      return widget.confidence > 0.7
          ? AppTheme.errorColor
          : AppTheme.warningColor;
    } else {
      return widget.confidence < 0.3
          ? AppTheme.successColor
          : AppTheme.warningColor;
    }
  }

  String get _confidenceText {
    final percentage = (widget.confidence * 100).round();
    return '$percentage%';
  }

  String get _confidenceLabel {
    if (widget.isPhishing) {
      return 'Phishing Confidence';
    } else {
      return 'Safe Confidence';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          children: [
            Text(
              _confidenceLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),

            // Circular progress indicator
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _animation.value,
                        strokeWidth: 8,
                        backgroundColor: theme.colorScheme.outline.withOpacity(
                          0.2,
                        ),
                        valueColor: AlwaysStoppedAnimation(_confidenceColor),
                      ),
                      Center(
                        child: Text(
                          _confidenceText,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _confidenceColor,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: AppConstants.spacingL),

            // Confidence description
            Text(
              _getConfidenceDescription(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getConfidenceDescription() {
    if (widget.isPhishing) {
      if (widget.confidence > 0.8) {
        return 'High confidence this is a phishing attempt. Exercise extreme caution.';
      } else if (widget.confidence > 0.6) {
        return 'Moderate confidence this is phishing. Be very careful.';
      } else {
        return 'Low confidence, but still suspicious. Verify before proceeding.';
      }
    } else {
      if (widget.confidence < 0.2) {
        return 'High confidence this message is safe.';
      } else if (widget.confidence < 0.4) {
        return 'Appears to be safe, but always stay vigilant.';
      } else {
        return 'Uncertain classification. Review carefully.';
      }
    }
  }
}
