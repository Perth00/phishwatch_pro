import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class ProgressIndicatorWidget extends StatefulWidget {
  final double progress;
  final Color color;
  final double height;
  final Duration animationDuration;

  const ProgressIndicatorWidget({
    super.key,
    required this.progress,
    required this.color,
    this.height = 6.0,
    this.animationDuration = AppAnimations.normalAnimation,
  });

  @override
  State<ProgressIndicatorWidget> createState() =>
      _ProgressIndicatorWidgetState();
}

class _ProgressIndicatorWidgetState extends State<ProgressIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(ProgressIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress.clamp(0.0, 1.0),
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
      );

      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.height / 2),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return FractionallySizedBox(
            widthFactor: _progressAnimation.value,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.height / 2),
                gradient: LinearGradient(
                  colors: [widget.color, widget.color.withOpacity(0.8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CircularProgressWidget extends StatefulWidget {
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Duration animationDuration;

  const CircularProgressWidget({
    super.key,
    required this.progress,
    required this.color,
    this.size = 60.0,
    this.strokeWidth = 6.0,
    this.child,
    this.animationDuration = AppAnimations.slowAnimation,
  });

  @override
  State<CircularProgressWidget> createState() => _CircularProgressWidgetState();
}

class _CircularProgressWidgetState extends State<CircularProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: widget.strokeWidth,
                backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(
                  0.3,
                ),
                valueColor: AlwaysStoppedAnimation(widget.color),
              ),
              if (widget.child != null) Center(child: widget.child!),
            ],
          );
        },
      ),
    );
  }
}

class AnimatedCounterWidget extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? textStyle;

  const AnimatedCounterWidget({
    super.key,
    required this.value,
    this.duration = AppAnimations.normalAnimation,
    this.textStyle,
  });

  @override
  State<AnimatedCounterWidget> createState() => _AnimatedCounterWidgetState();
}

class _AnimatedCounterWidgetState extends State<AnimatedCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _counterAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    _counterAnimation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _counterAnimation,
      builder: (context, child) {
        return Text('${_counterAnimation.value}', style: widget.textStyle);
      },
    );
  }
}

