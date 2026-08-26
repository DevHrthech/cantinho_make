import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fundo escuro com grade sutil (referência ao mockup).
class AppShellBackground extends StatelessWidget {
  const AppShellBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.darkBg,
                Color(0xFF1A0508),
                AppColors.darkBg,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        CustomPaint(
          painter: _GridPainter(),
          child: const SizedBox.expand(),
        ),
        ?child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.wine.withValues(alpha: 0.14)
      ..strokeWidth = 0.7;
    const step = 32.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
