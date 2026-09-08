import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

// ============================================================
// ICONO PERSONALIZADO COPA DE MARTINI
// ============================================================

class MartiniGlassIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MartiniGlassIcon({
    super.key,
    this.size = 40,
    this.color = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MartiniGlassPainter(color: color),
      ),
    );
  }
}

class _MartiniGlassPainter extends CustomPainter {
  final Color color;

  _MartiniGlassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.065;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // 1. Palillo (diagonal desde el interior del vaso hacia la esquina superior derecha)
    canvas.drawLine(
      Offset(w * 0.55, h * 0.44),
      Offset(w * 0.92, h * 0.08),
      strokePaint,
    );

    // 2. Aceituna en el palillo
    canvas.save();
    canvas.translate(w * 0.77, h * 0.22);
    canvas.rotate(-0.785); // -45 grados
    final oliveRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.20,
      height: w * 0.12,
    );
    canvas.drawOval(oliveRect, fillPaint);
    canvas.restore();

    // 3. Contorno del Vaso estilo Martini
    final bowlPath = Path()
      ..moveTo(w * 0.16, h * 0.28)
      ..lineTo(w * 0.84, h * 0.28)
      ..lineTo(w * 0.50, h * 0.60)
      ..close();
    canvas.drawPath(bowlPath, strokePaint);

    // 4. Relleno del líquido dentro de la copa
    final liquidPath = Path()
      ..moveTo(w * 0.23, h * 0.35)
      ..lineTo(w * 0.77, h * 0.35)
      ..lineTo(w * 0.50, h * 0.58)
      ..close();
    canvas.drawPath(liquidPath, fillPaint);

    // 5. Tallo vertical
    canvas.drawLine(
      Offset(w * 0.50, h * 0.60),
      Offset(w * 0.50, h * 0.88),
      strokePaint,
    );

    // 6. Base de la copa
    final basePath = Path()
      ..moveTo(w * 0.32, h * 0.94)
      ..lineTo(w * 0.68, h * 0.94)
      ..lineTo(w * 0.50, h * 0.86)
      ..close();
    canvas.drawPath(basePath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MartiniGlassPainter oldDelegate) =>
      oldDelegate.color != color;
}

