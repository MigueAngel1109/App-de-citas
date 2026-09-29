import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String cleanSlug(String raw) {
  var s = Uri.decodeComponent(raw).trim();
  s = s.replaceAll(RegExp(r'[-_+]+'), ' ');
  s = s.replaceAll(RegExp(r'\.(html|php|aspx|json)$', caseSensitive: false), '');
  return s.split(' ').where((w) => w.isNotEmpty).map((w) {
    if (w.length <= 2 && (w.toLowerCase() == 'de' || w.toLowerCase() == 'la' || w.toLowerCase() == 'el' || w.toLowerCase() == 'y')) {
      return w.toLowerCase();
    }
    return '${w[0].toUpperCase()}${w.substring(1)}';
  }).join(' ');
}

TimeOfDay? parseTimeString(String timeStr) {
  try {
    final clean = timeStr.trim().toLowerCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clean);
    if (match != null) {
      int h = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      if (clean.contains('pm') && h < 12) h += 12;
      if (clean.contains('am') && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    }
  } catch (_) {}
  return null;
}

Map<String, dynamic> parseTestUrl(String rawUrl) {
  final uri = Uri.parse(rawUrl);
  String? detectedPlace;
  DateTime? detectedDate;
  TimeOfDay? detectedTime;
  String? platformDetected;

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments;

  const stopWords = {'restaurante', 'restaurantes', 'reserva', 'reservas', 'bogota', 'colombia', 'm', 'menu', 'r'};

  if (host.contains('apparta')) {
    platformDetected = 'Apparta';
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i].toLowerCase();
      if (!stopWords.contains(seg) && seg.isNotEmpty) {
        detectedPlace = cleanSlug(segments[i]);
        break;
      }
    }
  } else if (host.contains('mesa247') || host.contains('mesa 24/7')) {
    platformDetected = 'Mesa 24/7';
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i].toLowerCase();
      if (!stopWords.contains(seg) && seg.isNotEmpty) {
        detectedPlace = cleanSlug(segments[i]);
        break;
      }
    }
  } else if (host.contains('cluvi')) {
    platformDetected = 'Cluvi';
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i].toLowerCase();
      if (!stopWords.contains(seg) && seg.isNotEmpty) {
        detectedPlace = cleanSlug(segments[i]);
        break;
      }
    }
  } else if (host.contains('justo') || host.contains('getjusto')) {
    platformDetected = 'Justo';
    final subparts = host.split('.');
    if (subparts.length > 2 && subparts[0] != 'www' && subparts[0] != 'app') {
      detectedPlace = cleanSlug(subparts[0]);
    }
    if (detectedPlace == null) {
      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i].toLowerCase();
        if (!stopWords.contains(seg) && seg.isNotEmpty) {
          detectedPlace = cleanSlug(segments[i]);
          break;
        }
      }
    }
  } else if (host.contains('degusta')) {
    platformDetected = 'Degusta';
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i].toLowerCase();
      if (!stopWords.contains(seg) && seg.isNotEmpty) {
        detectedPlace = cleanSlug(segments[i]);
        break;
      }
    }
  }

  final queryParams = uri.queryParameters;
  for (final entry in queryParams.entries) {
    final k = entry.key.toLowerCase();
    final v = entry.value;
    if ((k == 'datetime' || k == 'dt' || k == 'reservationdatetime') && detectedDate == null) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) {
        detectedDate = parsed;
        detectedTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }
    if ((k == 'date' || k == 'd' || k == 'fecha' || k == 'dia') && detectedDate == null) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) detectedDate = parsed;
    }
    if ((k == 'time' || k == 't' || k == 'hora') && detectedTime == null) {
      detectedTime = parseTimeString(v);
    }
  }

  return {
    'platform': platformDetected,
    'place': detectedPlace,
    'date': detectedDate,
    'time': detectedTime,
  };
}

void main() {
  test('Prueba de extracción para Apparta con fecha y hora en URL', () {
    final res = parseTestUrl('https://apparta.com/restaurante/cantina-la-15?date=2026-10-15&time=20:30');
    expect(res['platform'], 'Apparta');
    expect(res['place'], 'Cantina la 15');
    expect(res['date'], DateTime(2026, 10, 15));
    expect(res['time'], const TimeOfDay(hour: 20, minute: 30));
  });

  test('Prueba de extracción para Mesa 24/7 con fecha ISO combinada', () {
    final res = parseTestUrl('https://www.mesa247.co/restaurantes/bogota/criterio-by-rausch?datetime=2026-11-20T19:00:00');
    expect(res['platform'], 'Mesa 24/7');
    expect(res['place'], 'Criterio By Rausch');
    expect(res['date'], DateTime(2026, 11, 20, 19, 0));
    expect(res['time'], const TimeOfDay(hour: 19, minute: 0));
  });

  test('Prueba de extracción para Cluvi', () {
    final res = parseTestUrl('https://menu.cluvi.co/m/la-brasserie?date=2026-12-01&time=08:00pm');
    expect(res['platform'], 'Cluvi');
    expect(res['place'], 'la Brasserie');
    expect(res['time'], const TimeOfDay(hour: 20, minute: 0));
  });

  test('Prueba de extracción para Justo (subdominio)', () {
    final res = parseTestUrl('https://tacos-el-pastor.getjusto.com/?fecha=2026-05-10&hora=14:15');
    expect(res['platform'], 'Justo');
    expect(res['place'], 'Tacos el Pastor');
    expect(res['date'], DateTime(2026, 5, 10));
    expect(res['time'], const TimeOfDay(hour: 14, minute: 15));
  });

  test('Prueba de extracción para Degusta', () {
    final res = parseTestUrl('https://www.degustaco.com/bogota/restaurante/harry-sasson_10293.html');
    expect(res['platform'], 'Degusta');
    expect(res['place'], 'Harry Sasson 10293');
  });
}
