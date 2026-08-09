import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/app_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../scan/scan_result_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  var _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    _handled = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.crimson),
      ),
    );

    try {
      final result = await AppStore.instance.analyzeUrl(value);
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ScanResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _handled = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'QR Scanner',
          style: GoogleFonts.googleSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(AppIcons.flash),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          CustomPaint(painter: _ScanOverlayPainter()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Text(
                'Align the QR code inside the frame',
                textAlign: TextAlign.center,
                style: GoogleFonts.googleSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final hole = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: size.width * 0.68,
      height: size.width * 0.68,
    );

    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final border = Paint()
      ..color = AppColors.crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(18)),
      border,
    );

    final corner = Paint()
      ..color = AppColors.ember
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 22.0;
    void drawCorner(Offset a, Offset b, Offset c) {
      canvas.drawLine(a, b, corner);
      canvas.drawLine(b, c, corner);
    }

    drawCorner(hole.topLeft.translate(0, arm), hole.topLeft, hole.topLeft.translate(arm, 0));
    drawCorner(hole.topRight.translate(-arm, 0), hole.topRight, hole.topRight.translate(0, arm));
    drawCorner(hole.bottomLeft.translate(0, -arm), hole.bottomLeft, hole.bottomLeft.translate(arm, 0));
    drawCorner(hole.bottomRight.translate(-arm, 0), hole.bottomRight, hole.bottomRight.translate(0, -arm));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
