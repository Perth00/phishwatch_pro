import 'package:flutter/material.dart';
import '../services/sound_service.dart';

class BouncyButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? background;
  final Color? foreground;
  final EdgeInsetsGeometry padding;
  final double bounceScale;
  final double hoverLift;

  const BouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.background,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.bounceScale = 0.96,
    this.hoverLift = 4,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 140),
      value: 1,
      upperBound: 1,
      lowerBound: widget.bounceScale,
    );
    _scale = _controller.drive(
      Tween<double>(begin: 1, end: widget.bounceScale),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(_) => _controller.reverse();
  void _up(_) => _controller.forward();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.background ?? colorScheme.primary;
    final foreground = widget.foreground ?? colorScheme.onPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: () => _controller.forward(),
        onTap: () {
          // Play lightweight click sound for generic button taps
          SoundService.playButtonSound();
          widget.onPressed?.call();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _hovered ? -widget.hoverLift : 0),
              child: Transform.scale(
                scale: _scale.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: background.withOpacity(_hovered ? 0.36 : 0.18),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: widget.padding,
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: foreground),
                        child: Center(child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
