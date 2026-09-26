import 'package:flutter/material.dart';

/// Icono vectorial del logotipo de Instagram
class InstagramIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Gradient? gradient;

  const InstagramIcon({
    super.key,
    this.size = 16,
    this.color,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _InstagramPainter(
          color: color ?? const Color(0xFFE1306C),
          gradient: gradient,
        ),
      ),
    );
  }
}

class _InstagramPainter extends CustomPainter {
  final Color color;
  final Gradient? gradient;

  _InstagramPainter({required this.color, this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.11;

    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, w - strokeWidth, h - strokeWidth);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()..style = PaintingStyle.fill;

    if (gradient != null) {
      final shader = gradient!.createShader(Rect.fromLTWH(0, 0, w, h));
      strokePaint.shader = shader;
      dotPaint.shader = shader;
    } else {
      strokePaint.color = color;
      dotPaint.color = color;
    }

    // 1. Marco exterior redondeado (squircle)
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.28));
    canvas.drawRRect(rrect, strokePaint);

    // 2. Lente circular central
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.22, strokePaint);

    // 3. Punto flash superior derecho
    canvas.drawCircle(Offset(w * 0.73, h * 0.27), w * 0.065, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _InstagramPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.gradient != gradient;
}
