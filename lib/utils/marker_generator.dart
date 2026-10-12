import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

Future<BitmapDescriptor> createCustomMarkerBitmap(String imageUrl) async {
  // Tamaño fijo solicitado: width: 48.0, height: 48.0, imagePixelRatio: 3.5
  const double logicalSize = 48.0;
  const double devicePixelRatio = 3.5;
  final int pixelSize = (logicalSize * devicePixelRatio).round(); // 168px

  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  
  // Escalamos el canvas para que todo el dibujo se haga en coordenadas lógicas (48x48)
  canvas.scale(devicePixelRatio);
  const double radius = logicalSize / 2.0;

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
          ..color = Colors.black.withOpacity(0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
        canvas.drawCircle(const Offset(radius, radius), radius - 1.2, shadowPaint);

        // 2. Recortar en círculo para que SOLO se vea la foto
        canvas.save();
        const double innerMargin = 1.6;
        const double innerSize = logicalSize - (innerMargin * 2);
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
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();

        // 4. Borde blanco delgado y nítido para contraste con el mapa
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
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    canvas.drawCircle(const Offset(radius, radius), radius - 1.2, shadowPaint);

    final Paint bgPaint = Paint()..color = const Color(0xFFFF5252);
    canvas.drawCircle(const Offset(radius, radius), radius - 1.5, bgPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(const Offset(radius, radius), radius - 1.5, borderPaint);

    // Silueta de avatar estilizada proporcional
    final Paint avatarPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius - 5.5), 6.5, avatarPaint);
    final Path bodyPath = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(radius, radius + 10.5), radius: 11.0),
        3.14159,
        3.14159,
      );
    canvas.drawPath(bodyPath, avatarPaint);
  }

  try {
    final img = await pictureRecorder.endRecording().toImage(pixelSize, pixelSize);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) {
      // Especificar ancho y alto fijos lógicos (width: 48.0, height: 48.0)
      // para que en Google Maps el icono conserve SIEMPRE su tamaño fijo de 48x48
      // sin importar cuánto se acerque o aleje el zoom del mapa
      return BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        width: logicalSize,
        height: logicalSize,
        imagePixelRatio: devicePixelRatio,
      );
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
