import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'widgets/splash_star.dart';

/// Onboarding splash matching the reference layout 1:1.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _SplashBackground()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Trusted servers\n',
                            style: GoogleFonts.googleSans(
                              fontSize: 40,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              letterSpacing: -0.8,
                            ),
                          ),
                          TextSpan(
                            text: 'with one tap',
                            style: GoogleFonts.googleSans(
                              fontSize: 40,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Keep your data private and secure\nevery time you connect',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.googleSans(
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                        color: AppColors.ink.withValues(alpha: 0.88),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SplashStar(
                          size: (size.width * 0.58).clamp(180.0, 250.0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: onGetStarted,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          textStyle: GoogleFonts.googleSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Get started'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.splash),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, 0.55),
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentGlow.withValues(alpha: 0.55),
                    const Color(0xFFD6E2FA).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.72),
            child: Opacity(
              opacity: 0.14,
              child: CustomPaint(
                size: const Size(360, 220),
                painter: _GlobeWatermarkPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobeWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.accent;

    final center = Offset(size.width / 2, size.height * 0.15);
    final radius = size.width * 0.42;

    canvas.drawCircle(center, radius, paint);

    for (final t in [0.35, 0.55, 0.75]) {
      final y = center.dy - radius + radius * 2 * t;
      final dy = y - center.dy;
      final halfWidth = math.sqrt(math.max(0, radius * radius - dy * dy));
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx, y),
          width: halfWidth * 2,
          height: radius * 0.22,
        ),
        0,
        math.pi,
        false,
        paint,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 0.7,
        height: radius * 2,
      ),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
