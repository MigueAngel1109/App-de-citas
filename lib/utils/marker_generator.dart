import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

Future<BitmapDescriptor> createCustomMarkerBitmap(String imageUrl) async {
  // Tamaño compacto y proporcionado para mapa (76x76 píxeles)
  const int size = 76;
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  const double radius = size / 2.0;

  bool imageLoaded = false;
  if (imageUrl.isNotEmpty && (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'))) {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        // 1. Sombra suave exterior para dar relieve sobre el mapa
        final Paint shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(const Offset(radius, radius), radius - 1.5, shadowPaint);

        // 2. Recortar en círculo para que SOLO se vea la foto
        canvas.save();
        const double innerMargin = 1.5;
        const double innerSize = size - (innerMargin * 2);
        final Path clipPath = Path()
          ..addOval(const Rect.fromLTWH(innerMargin, innerMargin, innerSize, innerSize));
        canvas.clipPath(clipPath);

        // 3. Escalar y centrar la foto recortándola en cuadrado perfecto
        final double srcW = image.width.toDouble();
        final double srcH = image.height.toDouble();
        final double minDim = srcW < srcH ? srcW : srcH;
        final Rect srcRect = Rect.fromLTWH(
          (srcW - minDim) / 2,
          (srcH - minDim) / 2,
          minDim,
          minDim,
        );
        const Rect dstRect = Rect.fromLTWH(innerMargin, innerMargin, innerSize, innerSize);
        canvas.drawImageRect(
          image,
          srcRect,
          dstRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();

        // 4. Borde blanco delgado y limpio para contraste con el mapa
        final Paint borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(const Offset(radius, radius), radius - innerMargin, borderPaint);

        imageLoaded = true;
      }
    } catch (e) {
      debugPrint('Warning: Could not load marker image ($imageUrl): $e');
    }
  }

  if (!imageLoaded) {
    // Si no hay foto o falla la descarga, avatar compacto y limpio
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(const Offset(radius, radius), radius - 1.5, shadowPaint);

    final Paint bgPaint = Paint()..color = const Color(0xFFFF5252);
    canvas.drawCircle(const Offset(radius, radius), radius - 2, bgPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(radius, radius), radius - 2, borderPaint);

    // Silueta de avatar estilizada proporcional
    final Paint avatarPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius - 7), 9, avatarPaint);
    final Path bodyPath = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(radius, radius + 13), radius: 14),
        3.14159,
        3.14159,
      );
    canvas.drawPath(bodyPath, avatarPaint);
  }

  try {
    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      return BitmapDescriptor.bytes(data.buffer.asUint8List());
    }
  } catch (e) {
    debugPrint('Error converting marker image to bytes: $e');
  }

  return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
}

/// Genera el clásico punto azul pequeño con halo translúcido de Google Maps para la ubicación actual
Future<BitmapDescriptor> createCurrentLocationMarkerBitmap() async {
  const int size = 44;
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  const double center = size / 2.0;

  // 1. Halo azul suave translúcido
  final Paint haloPaint = Paint()
    ..color = const Color(0x401A73E8)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(center, center), 20, haloPaint);

  // 2. Borde blanco
  final Paint whiteBorderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(center, center), 9, whiteBorderPaint);

  // 3. Punto azul Google Maps
  final Paint blueDotPaint = Paint()
    ..color = const Color(0xFF1A73E8)
    ..style = PaintingStyle.fill;
  canvas.drawCircle(const Offset(center, center), 6.5, blueDotPaint);

  try {
    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      return BitmapDescriptor.bytes(data.buffer.asUint8List());
    }
  } catch (e) {
    debugPrint('Error creating location dot marker: $e');
  }

  return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
}
