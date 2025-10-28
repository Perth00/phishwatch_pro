import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class LockedOverlay extends StatelessWidget {
  final BorderRadius borderRadius;
  const LockedOverlay({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: CustomPaint(
          painter: _CrossPainter(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: borderRadius,
            ),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                color: AppTheme.errorColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..color = AppTheme.errorColor.withOpacity(0.65)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
    // Big X
    canvas.drawLine(
      Offset(12, 12),
      Offset(size.width - 12, size.height - 12),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 12, 12),
      Offset(12, size.height - 12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
