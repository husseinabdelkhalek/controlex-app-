import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryViolet.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const double step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final neonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryCyan.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.5;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height * 0.7), neonPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height * 0.7), neonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
