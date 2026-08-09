import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rounded 8-point asterisk with a dark tech/circuit fill.
class SplashStar extends StatelessWidget {
  const SplashStar({super.key, this.size = 220});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SplashStarPainter()),
    );
  }
}

class _SplashStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.46;
    final path = _roundedAsterisk(center, outer);

    canvas.save();
    canvas.clipPath(path);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A1020),
            Color(0xFF141C34),
            Color(0xFF1C1030),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawCircle(
      center.translate(-outer * 0.18, -outer * 0.12),
      outer * 0.55,
      Paint()
        ..color = const Color(0xFF2F6BFF).withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawCircle(
      center.translate(outer * 0.22, outer * 0.18),
      outer * 0.48,
      Paint()
        ..color = const Color(0xFFC2185B).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
    canvas.drawCircle(
      center,
      outer * 0.32,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7EC8FF).withValues(alpha: 0.55);
    final pink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF4D9A).withValues(alpha: 0.42);
    final cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = const Color(0xFF40E0D0).withValues(alpha: 0.48);

    for (var i = 0; i < 16; i++) {
      final t = i / 16;
      final y = size.height * (0.1 + t * 0.8);
      final wobble = math.sin(t * math.pi * 5) * outer * 0.07;
      canvas.drawLine(
        Offset(center.dx - outer * 0.75, y + wobble),
        Offset(center.dx + outer * 0.75, y - wobble * 0.5),
        i.isEven ? blue : cyan,
      );
    }

    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * outer * 0.12,
        center + Offset(math.cos(angle), math.sin(angle)) * outer * 0.9,
        pink,
      );
    }

    final node = Paint()..color = const Color(0xFF9AD7FF);
    for (var i = 0; i < 22; i++) {
      final a = i * 0.95;
      final r = outer * (0.18 + (i % 5) * 0.12);
      canvas.drawCircle(
        center + Offset(math.cos(a) * r, math.sin(a) * r),
        1.5,
        node,
      );
    }

    canvas.restore();
  }

  /// Thick rounded arms at 45° increments (reference asterisk shape).
  Path _roundedAsterisk(Offset center, double outer) {
    final armLength = outer;
    final armWidth = outer * 0.34;
    final path = Path();

    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: armWidth,
          height: armLength * 2,
        ),
        Radius.circular(armWidth / 2),
      );

      final matrix = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(angle)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

      path.addPath(Path()..addRRect(rect), Offset.zero, matrix4: matrix.storage);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
