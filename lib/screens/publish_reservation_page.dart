import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/secrets.dart';
import '../utils/place_photo_service.dart';
import '../utils/place_photo_stub.dart' if (dart.library.js) '../utils/place_photo_web.dart' as js_bridge;
import 'discover_page.dart';
import 'subscription_plans_page.dart';

class PlaceAutocomplete {
  final String description;
  final String placeId;
  final GeoPoint? location;

  PlaceAutocomplete({
    required this.description,
    required this.placeId,
    this.location,
  });
}

class PublishReservationPage extends StatefulWidget {
  final void Function(GeoPoint? location)? onPublished;
  const PublishReservationPage({super.key, this.onPublished});

  @override
  State<PublishReservationPage> createState() => _PublishReservationPageState();
}

class _PublishReservationPageState extends State<PublishReservationPage> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  TextEditingController? _autoCompleteTextController;
  
  String _selectedPlan = 'Comida/Cena';
  String _selectedPayment = 'Cuentas separadas';
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  GeoPoint? _selectedLocation;

  bool _isPublishing = false;
  bool _isFetchingPlace = false;
  bool _isParsingLink = false;
  String? _linkParseMessage;
  String? _linkError;
  bool _lockDateTime = false;
  String? _realPlacePhoto;
  bool _hasDetectedData = false;
  bool _showManualEntry = false;

  bool get _showDetails => _hasDetectedData || _showManualEntry || _placeController.text.trim().isNotEmpty;

  // Categorías con Café y Brunch separados
  final List<String> _planTypes = ['Comida/Cena', 'Tragos', 'Café', 'Brunch'];
  final List<String> _paymentTypes = ['Yo invito', 'Cuentas separadas', 'Abierto a discutir'];

  @override
  void initState() {
    super.initState();
    _initDefaultDateTime();
  }

  void _initDefaultDateTime() {
    final now = DateTime.now();
    if (now.hour >= 21) {
      _selectedDate = DateTime(now.year, now.month, now.day + 1);
      _selectedTime = const TimeOfDay(hour: 20, minute: 0);
    } else {
      _selectedDate = DateTime(now.year, now.month, now.day);
      final nextHour = (now.hour + 2).clamp(12, 21);
      _selectedTime = TimeOfDay(hour: nextHour, minute: 0);
    }
  }

  DateTime _getNextWeekday(int weekday) {
    DateTime d = DateTime.now();
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  void dispose() {
    _linkController.dispose();
    _detailsController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _lookupPlacePhoto(String placeName) {
    if (placeName.trim().isEmpty) return;
    final clean = placeName.split(',')[0].trim();
    PlacePhotoService.fetchPhotoForPlace(clean).then((photo) {
      if (photo != null && mounted) {
        setState(() {
          _realPlacePhoto = photo;
        });
      }
    });
  }

  Future<void> _openExternalPlatform(String url) async {
    // Si es OpenTable, intentar abrir directamente la app instalada en el celular
    if (url.contains('opentable')) {
      final appUri = Uri.parse('opentable://');
      try {
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El portapapeles está vacío. Copia primero la reserva.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Si el portapapeles tiene una URL embebida (ej: mensaje compartido por WhatsApp)
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
      String? cleanUrl;
      if (urlMatch != null) {
        cleanUrl = urlMatch.group(0);
      } else if (_isValidUrl(text)) {
        cleanUrl = text.startsWith('http://') || text.startsWith('https://') ? text : 'https://$text';
      }

      if (cleanUrl != null) {
        setState(() {
          _linkController.text = cleanUrl!;
          _linkError = null;
        });
        _parseReservationLink(cleanUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Enlace pegado correctamente'),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _linkError = 'Solo se permiten enlaces web (ej: https://...)';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('El texto copiado no es un link. Solo se permiten enlaces web (ej: https://...).'),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error pasting from clipboard: $e');
    }
  }

  DateTime? _parseSpanishDate(String text) {
    final clean = text.toLowerCase().replaceAll('.', '').replaceAll(',', ' ').trim();

    // 1. ISO YYYY-MM-DD
    final isoMatch = RegExp(r'\b(202[4-9])-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])\b').firstMatch(clean);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // 2. DD/MM/YYYY or DD-MM-YYYY
    final dmyMatch = RegExp(r'\b([0-2]?[0-9]|3[01])[/\-](0?[1-9]|1[0-2])[/\-](202[4-9])\b').firstMatch(clean);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      return DateTime(y, m, d);
    }

    // 3. DD [de] mes [de] [YYYY] ej: "02 oct", "2 de octubre", "vie, 02 oct."
    const monthMap = {
      'ene': 1, 'enero': 1, 'jan': 1, 'january': 1,
      'feb': 2, 'febrero': 2, 'february': 2,
      'mar': 3, 'marzo': 3, 'march': 3,
      'abr': 4, 'abril': 4, 'apr': 4, 'april': 4,
      'may': 5, 'mayo': 5,
      'jun': 6, 'junio': 6, 'june': 6,
      'jul': 7, 'julio': 7, 'july': 7,
      'ago': 8, 'agosto': 8, 'aug': 8, 'august': 8,
      'sep': 9, 'sept': 9, 'septiembre': 9, 'september': 9,
      'oct': 10, 'octubre': 10, 'october': 10,
      'nov': 11, 'noviembre': 11, 'november': 11,
      'dic': 12, 'diciembre': 12, 'dec': 12, 'december': 12,
    };

    final monthNames = monthMap.keys.join('|');
    final textDateMatch = RegExp(
      '(\\b[0-2]?[0-9]|3[01])\\s*(?:de)?\\s*($monthNames)(?:\\s*(?:de)?\\s*(202[4-9]))?',
      caseSensitive: false,
    ).firstMatch(clean);

    if (textDateMatch != null) {
      final d = int.parse(textDateMatch.group(1)!);
      final mName = textDateMatch.group(2)!.toLowerCase();
      final m = monthMap[mName]!;
      final yStr = textDateMatch.group(3);
      final currentYear = DateTime.now().year;
      final y = yStr != null ? int.parse(yStr) : (m < DateTime.now().month ? currentYear + 1 : currentYear);
      return DateTime(y, m, d);
    }

    // 4. English month day: ej. "Oct 2", "October 2nd", "Fri, Oct 2 at 7:30 PM"
    final engDateMatch = RegExp(
      '\\b($monthNames)\\s+([0-2]?[0-9]|3[01])(?:st|nd|rd|th)?(?:\\s*,?\\s*(202[4-9]))?',
      caseSensitive: false,
    ).firstMatch(clean);

    if (engDateMatch != null) {
      final mName = engDateMatch.group(1)!.toLowerCase();
      final m = monthMap[mName]!;
      final d = int.parse(engDateMatch.group(2)!);
      final yStr = engDateMatch.group(3);
      final currentYear = DateTime.now().year;
      final y = yStr != null ? int.parse(yStr) : (m < DateTime.now().month ? currentYear + 1 : currentYear);
      return DateTime(y, m, d);
    }

    return null;
  }

  TimeOfDay? _parseTimeString(String timeStr) {
    try {
      final clean = timeStr.trim().toLowerCase();
      final match = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?\s*(am|pm)?').firstMatch(clean);
      if (match != null) {
        int h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final ampm = match.group(3);
        if (ampm == 'pm' && h < 12) h += 12;
        if (ampm == 'am' && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return null;
  }

  String _cleanSlug(String raw) {
    var s = Uri.decodeComponent(raw).trim();
    // Reemplazar guiones y guiones bajos por espacios
    s = s.replaceAll(RegExp(r'[-_+]+'), ' ');
    // Quitar extensiones comunes
    s = s.replaceAll(RegExp(r'\.(html|php|aspx|json)$', caseSensitive: false), '');
    // Capitalizar palabras
    return s.split(' ').where((w) => w.isNotEmpty).map((w) {
      if (w.length <= 2 && (w.toLowerCase() == 'de' || w.toLowerCase() == 'la' || w.toLowerCase() == 'el' || w.toLowerCase() == 'y')) {
        return w.toLowerCase();
      }
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  String _cleanOpenTableSlug(String raw) {
    var s = Uri.decodeComponent(raw).toLowerCase().trim();
    // Quitar sufijos comunes de ubicación de OpenTable
    s = s.replaceAll(RegExp(r'-(bogota|colombia|medellin|cali|cartagena|co|restaurante|restaurant)$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'-(bogota|colombia|medellin|cali|cartagena)$', caseSensitive: false), '');
    return _cleanSlug(s);
  }

  bool _isValidUrl(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    if (t.contains(' ')) return false;
    final urlPattern = RegExp(
      r'^(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,8}\b(?:[-a-zA-Z0-9@:%_\+.~#?&//=]*)$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(t);
  }

  Future<void> _parseReservationLink(String rawUrl) async {
    final trimmedInput = rawUrl.trim();
    if (trimmedInput.isEmpty) {
      if (mounted) {
        setState(() {
          _linkError = null;
          _linkParseMessage = null;
          _isParsingLink = false;
          _hasDetectedData = false;
        });
      }
      return;
    }

    // Extraer link si viene dentro de un texto
    final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(trimmedInput);
    String cleanUrl = trimmedInput;
    if (urlMatch != null) {
      cleanUrl = urlMatch.group(0)!;
    } else if (_isValidUrl(trimmedInput)) {
      cleanUrl = trimmedInput.startsWith('http://') || trimmedInput.startsWith('https://') ? trimmedInput : 'https://$trimmedInput';
    } else {
      if (mounted) {
        setState(() {
          _linkError = 'Solo se permiten enlaces web (ej: https://...)';
          _isParsingLink = false;
          _linkParseMessage = null;
        });
      }
      return;
    }

    if (cleanUrl != _linkController.text) {
      _linkController.value = TextEditingValue(
        text: cleanUrl,
        selection: TextSelection.collapsed(offset: cleanUrl.length),
      );
    }

    var trimmed = cleanUrl;

    setState(() {
      _linkError = null;
      _isParsingLink = true;
      _linkParseMessage = 'Analizando reserva de OpenTable / externa...';
    });

    try {
      var parsedUri = Uri.tryParse(trimmed);
      if (parsedUri == null) {
        setState(() => _isParsingLink = false);
        return;
      }

      // Desempaquetar Firebase Dynamic Links de OpenTable si traen parámetro ?link=...
      if (parsedUri.queryParameters.containsKey('link')) {
        final innerLink = parsedUri.queryParameters['link'];
        if (innerLink != null && innerLink.isNotEmpty) {
          final parsedInner = Uri.tryParse(innerLink);
          if (parsedInner != null) {
            parsedUri = parsedInner;
            trimmed = innerLink;
          }
        }
      }

      // Resolver redirecciones si es un enlace corto de la app móvil (opentable.page.link, ot.app.link, s.opentable.com)
      if (parsedUri.host.contains('page.link') || parsedUri.host.contains('app.link') || parsedUri.host == 's.opentable.com') {
        if (!kIsWeb) {
          try {
            final client = http.Client();
            final req = http.Request('GET', parsedUri)..followRedirects = true;
            final streamed = await client.send(req).timeout(const Duration(seconds: 4));
            final redirected = streamed.request?.url;
            client.close();
            if (redirected != null) {
              parsedUri = redirected;
              trimmed = redirected.toString();
            }
          } catch (_) {}
        }
      }

      if (parsedUri == null) {
        setState(() => _isParsingLink = false);
        return;
      }
      final Uri uri = parsedUri;

      String? detectedPlace;
      DateTime? detectedDate;
      TimeOfDay? detectedTime;
      String? platformDetected;

      final host = uri.host.toLowerCase();
      final segments = uri.pathSegments;

      const stopWords = {
        'restaurante', 'restaurantes', 'reserva', 'reservas', 'branch', 'payment', 
        'bogota', 'colombia', 'm', 'menu', 'r'
      };

      // ==========================================
      // 1. APPARTA (apparta.com / apparta.co)
      // ==========================================
      if (host.contains('apparta')) {
        platformDetected = 'Apparta';
        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i].toLowerCase();
          if (!stopWords.contains(seg) && seg.isNotEmpty) {
            detectedPlace = _cleanSlug(segments[i]);
            break;
          }
        }
      }
      // ==========================================
      // 2. MESA 24/7 (mesa247.co / mesa247.pe / mesa247.com / mesa247.cloud)
      // ==========================================
      else if (host.contains('mesa247') || host.contains('mesa 24/7')) {
        platformDetected = 'Mesa 24/7';
        for (var i = segments.length - 1; i >= 0; i--) {
          final seg = segments[i].toLowerCase();
          // Ignorar IDs/hashes hexadecimales (ej: 300322ccf2d2c767785aaf14f3f6ad08) y slugs genéricos
          final isHash = RegExp(r'^[0-9a-fA-F]{16,}$').hasMatch(seg);
          final isGeneric = seg.contains('comparte') || seg.contains('reserva');
          if (!stopWords.contains(seg) && seg.isNotEmpty && !isHash && !isGeneric) {
            detectedPlace = _cleanSlug(segments[i]);
            break;
          }
        }
      }
      // ==========================================
      // 3. CLUVI (menu.cluvi.co / cluvi.com)
      // ==========================================
      else if (host.contains('cluvi')) {
        platformDetected = 'Cluvi';
        for (var i = segments.length - 1; i >= 0; i--) {
          final seg = segments[i].toLowerCase();
          if (!stopWords.contains(seg) && seg.isNotEmpty) {
            detectedPlace = _cleanSlug(segments[i]);
            break;
          }
        }
      }
      // ==========================================
      // 4. JUSTO (getjusto.com / justo.com)
      // ==========================================
      else if (host.contains('justo') || host.contains('getjusto')) {
        platformDetected = 'Justo';
        final subparts = host.split('.');
        if (subparts.length > 2 && subparts[0] != 'www' && subparts[0] != 'app') {
          detectedPlace = _cleanSlug(subparts[0]);
        }
        if (detectedPlace == null) {
          for (var i = 0; i < segments.length; i++) {
            final seg = segments[i].toLowerCase();
            if (!stopWords.contains(seg) && seg.isNotEmpty) {
              detectedPlace = _cleanSlug(segments[i]);
              break;
            }
          }
        }
      }
      // ==========================================
      // 5. DEGUSTA (degustaco.com / degusta.com.co / degusta.com)
      // ==========================================
      else if (host.contains('degusta')) {
        platformDetected = 'Degusta';
        for (var i = segments.length - 1; i >= 0; i--) {
          final seg = segments[i].toLowerCase();
          if (!stopWords.contains(seg) && seg.isNotEmpty) {
            detectedPlace = _cleanSlug(segments[i]);
            break;
          }
        }
      }
      // ==========================================
      // 6. OPENTABLE (web y app móvil)
      // ==========================================
      else if (host.contains('opentable') || host.contains('ot.app.link')) {
        platformDetected = 'OpenTable';
        for (var i = segments.length - 1; i >= 0; i--) {
          final seg = segments[i].toLowerCase();
          final isGeneric = seg == 'book' ||
              seg == 'booking' ||
              seg == 'confirmation' ||
              seg == 'confirm' ||
              seg == 'r' ||
              seg == 'view' ||
              seg == 'restref' ||
              seg == 'restaurant' ||
              seg == 'profile' ||
              seg == 'experiences-view' ||
              seg == 'experiences' ||
              seg == 'invite' ||
              seg == 'invitation' ||
              seg == 'share' ||
              seg == 'd' ||
              seg == 'reservations' ||
              seg == 'reservation';
          if (!stopWords.contains(seg) && seg.isNotEmpty && !isGeneric) {
            // Evitar IDs numéricos de restaurante (ej: /restaurant/profile/12345)
            if (!RegExp(r'^\d+$').hasMatch(seg)) {
              detectedPlace = _cleanOpenTableSlug(segments[i]);
              break;
            }
          }
        }

        // Parámetros de URL comunes en enlaces compartidos de la app de OpenTable
        final qp = uri.queryParameters;
        if (detectedPlace == null) {
          for (final key in ['restaurantname', 'restaurant_name', 'name', 'place', 'rname']) {
            if (qp.containsKey(key) && qp[key]!.trim().isNotEmpty) {
              detectedPlace = _cleanOpenTableSlug(qp[key]!);
              break;
            }
          }
        }
      }

      final opentableRid = uri.queryParameters['rid'] ?? uri.queryParameters['restaurantid'] ?? uri.queryParameters['restaurantId'];

      // Extraer parámetros query estándar (date, time, datetime, hour, etc.)
      final queryParams = uri.queryParameters;
      for (final entry in queryParams.entries) {
        final k = entry.key.toLowerCase();
        final v = entry.value;

        // Fecha / Hora combinada (ej: OpenTable dateTime=2026-10-02T19:30:00 o dateTime=2026-10-02T19%3A30%3A00)
        if ((k == 'datetime' || k == 'dt' || k == 'reservationdatetime') && (detectedDate == null || detectedTime == null)) {
          final cleanVal = Uri.decodeComponent(v);
          final parsed = DateTime.tryParse(cleanVal) ?? DateTime.tryParse(v);
          if (parsed != null) {
            detectedDate ??= DateTime(parsed.year, parsed.month, parsed.day);
            detectedTime ??= TimeOfDay(hour: parsed.hour, minute: parsed.minute);
          }
        }

        // Fecha individual
        if ((k == 'date' || k == 'd' || k == 'fecha' || k == 'dia') && detectedDate == null) {
          final cleanVal = Uri.decodeComponent(v);
          final parsed = _parseSpanishDate(cleanVal) ?? DateTime.tryParse(cleanVal) ?? _parseSpanishDate(v) ?? DateTime.tryParse(v);
          if (parsed != null) {
            detectedDate = DateTime(parsed.year, parsed.month, parsed.day);
          }
        }

        // Hora individual
        if ((k == 'time' || k == 't' || k == 'hora') && detectedTime == null) {
          final cleanVal = Uri.decodeComponent(v);
          detectedTime = _parseTimeString(cleanVal) ?? _parseTimeString(v);
        }

        // Lugar en query si no se detectó antes
        if ((k == 'place' || k == 'restaurant' || k == 'restaurante' || k == 'name' || k == 'restaurantname') && detectedPlace == null) {
          detectedPlace = _cleanSlug(v);
        }
      }

      // Regex directo en el texto de la URL (por si queryParameters no lo decodificó o venía codificado)
      if (detectedDate == null || detectedTime == null) {
        final dtRegex = RegExp(r'[?&](?:datetime|dateTime|dt|reservationdatetime)=([^&]+)', caseSensitive: false);
        final dtMatch = dtRegex.firstMatch(trimmed);
        if (dtMatch != null) {
          final rawVal = Uri.decodeComponent(dtMatch.group(1)!);
          final parsed = DateTime.tryParse(rawVal);
          if (parsed != null) {
            detectedDate ??= DateTime(parsed.year, parsed.month, parsed.day);
            detectedTime ??= TimeOfDay(hour: parsed.hour, minute: parsed.minute);
          }
        }
      }

      // Inspección de contenido web
      if (detectedDate == null || detectedTime == null || detectedPlace == null) {
        // A. Intento directo nativo (no Web o endpoints sin bloqueo)
        if (!kIsWeb) {
          try {
            final res = await http.get(uri).timeout(const Duration(seconds: 4));
            if (res.statusCode == 200) {
              final htmlBody = utf8.decode(res.bodyBytes, allowMalformed: true);

              // Extraer Next.js __NEXT_DATA__
              final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', dotAll: true).firstMatch(htmlBody);
              if (nextDataMatch != null) {
                try {
                  final jsonStr = nextDataMatch.group(1);
                  if (jsonStr != null) {
                    final data = json.decode(jsonStr);
                    final pageProps = data['props']?['pageProps'];
                    final prePurchase = pageProps?['initialPrePurchaseData'];
                    if (prePurchase != null) {
                      final resDateStr = prePurchase['meta_reservation_date'] as String?;
                      if (resDateStr != null && detectedDate == null) {
                        detectedDate = DateTime.tryParse(resDateStr);
                      }
                      final resTimeStr = prePurchase['meta_reservation_start_time'] as String?;
                      if (resTimeStr != null && detectedTime == null) {
                        detectedTime = _parseTimeString(resTimeStr);
                      }
                      final estData = pageProps?['establishmentData'] ?? pageProps?['establishment'];
                      if (estData != null && estData['name'] != null && (detectedPlace == null || detectedPlace.isEmpty)) {
                        detectedPlace = estData['name'].toString().trim();
                      }
                    }
                  }
                } catch (_) {}
              }

              // Extraer de OpenGraph og:title, JSON-LD, HTML title y meta description
              if (detectedPlace == null || detectedDate == null || detectedTime == null) {
                // OpenGraph og:title (muy común en OpenTable web y móvil)
                final ogTitleMatch = RegExp(r'<meta[^>]+property=["\x27]og:title["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(htmlBody)
                    ?? RegExp(r'<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]+property=["\x27]og:title["\x27]', caseSensitive: false).firstMatch(htmlBody);
                if (ogTitleMatch != null && detectedPlace == null) {
                  var cand = ogTitleMatch.group(1)!.trim();
                  cand = cand.replaceAll(RegExp(r'\s*\|\s*OpenTable.*$', caseSensitive: false), '');
                  cand = cand.replaceAll(RegExp(r'\s*-\s*Bogot[aá].*$', caseSensitive: false), '');
                  cand = cand.replaceAll(RegExp(r'^(?:Reserva en|Reserva confirmada en|Your reservation at|Reservation at)\s+', caseSensitive: false), '');
                  if (cand.isNotEmpty && cand.length < 60 && !cand.toLowerCase().contains('opentable')) {
                    detectedPlace = cand;
                  }
                }

                // JSON-LD Schema.org (Restaurant)
                if (detectedPlace == null) {
                  final jsonLdMatch = RegExp(r'<script[^>]+type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>', dotAll: true).firstMatch(htmlBody);
                  if (jsonLdMatch != null) {
                    try {
                      final data = json.decode(jsonLdMatch.group(1)!);
                      if (data is Map && data['name'] != null) {
                        detectedPlace = data['name'].toString().trim();
                      }
                    } catch (_) {}
                  }
                }

                // HTML <title>
                if (detectedPlace == null) {
                  final titleTagMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(htmlBody);
                  if (titleTagMatch != null) {
                    var cand = titleTagMatch.group(1)!.trim();
                    cand = cand.replaceAll(RegExp(r'\s*\|\s*OpenTable.*$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'\s*-\s*Bogot[aá].*$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'^(?:Reserva en|Reserva confirmada en|Your reservation at|Reservation at)\s+', caseSensitive: false), '');
                    if (cand.isNotEmpty && cand.length < 50 && !cand.toLowerCase().contains('opentable')) {
                      detectedPlace = cand;
                    }
                  }
                }

                final metaDescMatch = RegExp(
                  r'<meta[^>]+(?:name|itemprop)=["\x27]description["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]',
                  caseSensitive: false,
                ).firstMatch(htmlBody);
                if (metaDescMatch != null) {
                  final content = metaDescMatch.group(1)!;
                  final parts = content.split('|');
                  if (detectedPlace == null && parts.isNotEmpty) {
                    var candidate = parts[0].replaceAll(RegExp(r'\([^)]*\)'), '').trim();
                    if (candidate.isNotEmpty && candidate.length < 50 && !candidate.toLowerCase().contains('comparte tu reserva')) {
                      detectedPlace = candidate;
                    }
                  }
                  if (parts.length > 1) {
                    detectedDate ??= _parseSpanishDate(parts[1]);
                    detectedTime ??= _parseTimeString(parts[1]);
                  }
                }
              }

              // Extraer dateTime de JSON (ej: OpenTable primary-window-vars)
              final dtMatch = RegExp(r'"reservation"\s*:\s*\{[^}]*"dateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(htmlBody) ??
                  RegExp(r'"dateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(htmlBody) ??
                  RegExp(r'"reservationDateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(htmlBody) ??
                  RegExp(r'"meta_reservation_datetime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(htmlBody);
              if (dtMatch != null && (detectedDate == null || detectedTime == null)) {
                final rawDt = dtMatch.group(1)!;
                final parsed = DateTime.tryParse(rawDt);
                if (parsed != null) {
                  final dt = (rawDt.endsWith('Z') || parsed.isUtc)
                      ? parsed.toUtc().subtract(const Duration(hours: 5))
                      : parsed;
                  detectedDate = DateTime(dt.year, dt.month, dt.day);
                  detectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
                }
              }

              if (detectedDate == null) {
                final dMatch = RegExp(r'"(?:reservationDate|bookingDate)"\s*:\s*"(\d{4}-\d{2}-\d{2})"', caseSensitive: false).firstMatch(htmlBody);
                if (dMatch != null) {
                  final parsed = DateTime.tryParse(dMatch.group(1)!);
                  if (parsed != null) {
                    detectedDate = DateTime(parsed.year, parsed.month, parsed.day);
                  }
                }
              }

              if (detectedTime == null) {
                final tMatch = RegExp(r'"(?:reservationTime|bookingTime)"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(htmlBody);
                if (tMatch != null) {
                  detectedTime = _parseTimeString(tMatch.group(1)!);
                }
              }
            }
          } catch (_) {}
        }

        // B. Fallback universal con proxy CORS (para Web y scraping asistido)
        if (detectedDate == null || detectedTime == null || detectedPlace == null) {
          try {
            final jinaUri = Uri.parse('https://r.jina.ai/$trimmed');
            http.Response jinaRes;
            try {
              jinaRes = await http.get(
                jinaUri,
                headers: {'x-return-format': 'html'},
              ).timeout(const Duration(seconds: 8));
            } catch (_) {
              jinaRes = await http.get(jinaUri).timeout(const Duration(seconds: 8));
            }
            if (jinaRes.statusCode != 200) {
              jinaRes = await http.get(jinaUri).timeout(const Duration(seconds: 8));
            }

            if (jinaRes.statusCode == 200) {
              final bodyContent = jinaRes.body;

              // 1. Extraer dateTime de JSON y scripts (OpenTable primary-window-vars, etc.)
              final dtMatch = RegExp(r'"reservation"\s*:\s*\{[^}]*"dateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(bodyContent) ??
                  RegExp(r'"dateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(bodyContent) ??
                  RegExp(r'"reservationDateTime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(bodyContent) ??
                  RegExp(r'"meta_reservation_datetime"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(bodyContent);
              if (dtMatch != null && (detectedDate == null || detectedTime == null)) {
                final rawDt = dtMatch.group(1)!;
                final parsed = DateTime.tryParse(rawDt);
                if (parsed != null) {
                  // Ajustar a hora Bogotá (UTC-5) si viene en UTC con sufijo Z
                  final dt = (rawDt.endsWith('Z') || parsed.isUtc)
                      ? parsed.toUtc().subtract(const Duration(hours: 5))
                      : parsed;
                  detectedDate = DateTime(dt.year, dt.month, dt.day);
                  detectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
                }
              }

              // 2. Extraer fecha / hora individuales de JSON (excluyendo fechas de catálogo/menú como startDate)
              if (detectedDate == null) {
                final dMatch = RegExp(r'"(?:reservationDate|bookingDate|resDate)"\s*:\s*"(\d{4}-\d{2}-\d{2})"', caseSensitive: false).firstMatch(bodyContent);
                if (dMatch != null) {
                  final parsed = DateTime.tryParse(dMatch.group(1)!);
                  if (parsed != null) {
                    detectedDate = DateTime(parsed.year, parsed.month, parsed.day);
                  }
                }
              }

              if (detectedTime == null) {
                final tMatch = RegExp(r'"(?:reservationTime|bookingTime|resTime)"\s*:\s*"([^"]+)"', caseSensitive: false).firstMatch(bodyContent);
                if (tMatch != null) {
                  detectedTime = _parseTimeString(tMatch.group(1)!);
                }
              }

              // 3. Punch line: no autocompletar nada; la persona escoge si ingresa algo o no.

              // 4. Texto plano de la página / markdown para fechas y horas en lenguaje natural (si no se obtuvieron por JSON)
              if (detectedDate == null || detectedTime == null) {
                final plainText = bodyContent.replaceAll(RegExp(r'<[^>]*>'), '\n');
                final lines = plainText.split('\n');
                for (final line in lines) {
                  final trimmedLine = line.trim();
                  if (trimmedLine.isEmpty) continue;
                  // Ignorar líneas con llaves JSON o catálogos
                  if (trimmedLine.contains('{') || trimmedLine.contains('}') || trimmedLine.contains('"schedule"')) continue;
                  detectedDate ??= _parseSpanishDate(trimmedLine);
                  detectedTime ??= _parseTimeString(trimmedLine);
                  if (detectedDate != null && detectedTime != null) break;
                }
              }

              if (detectedPlace == null) {
                // Caso OpenTable en markdown o HTML: "Your Reservation at Selvátiko by Petronio" o "Reserva en..."
                final otResMatch = RegExp(r'(?:Your Reservation at|Reservation at|Reserva en)\s+([^|\n\r#<]+)', caseSensitive: false).firstMatch(bodyContent);
                if (otResMatch != null) {
                  var cand = otResMatch.group(1)?.trim();
                  if (cand != null) {
                    cand = cand.replaceAll(RegExp(r'\s*\|\s*OpenTable.*$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'\s*-\s*OpenTable.*$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'\s*-\s*Bogot[aá].*$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'\s+Restaurant$', caseSensitive: false), '');
                    cand = cand.replaceAll(RegExp(r'\s+Restaurante$', caseSensitive: false), '');
                    cand = cand.trim();
                    if (cand.isNotEmpty && cand.length < 60) {
                      detectedPlace = cand;
                    }
                  }
                }

                if (detectedPlace == null) {
                  final otLinkMatch = RegExp(r'opentable\.com/r/([a-zA-Z0-9_\-]+)', caseSensitive: false).firstMatch(bodyContent);
                  if (otLinkMatch != null) {
                    final slug = otLinkMatch.group(1);
                    if (slug != null && slug.isNotEmpty) {
                      detectedPlace = _cleanOpenTableSlug(slug);
                    }
                  }
                }

                // Caso Mesa 24/7 en markdown: suele venir en un heading: #### Afluente Restaurante
                if (detectedPlace == null) {
                  final headingMatches = RegExp(r'#{1,4}\s+([^\n\r#]+)').allMatches(bodyContent);
                  for (final hm in headingMatches) {
                    final cand = hm.group(1)?.trim();
                    if (cand != null &&
                        cand.isNotEmpty &&
                        cand.length < 50 &&
                        !cand.toLowerCase().contains('comparte') &&
                        !cand.toLowerCase().contains('reserva') &&
                        !cand.toLowerCase().contains('reservation') &&
                        !cand.toLowerCase().contains('opentable') &&
                        !cand.toLowerCase().contains('mesa 24/7') &&
                        !cand.toLowerCase().contains('image')) {
                      detectedPlace = cand;
                      break;
                    }
                  }
                }

                if (detectedPlace == null) {
                  final titleMatch = RegExp(r'Title:\s*(.+?)(?:\s+reservas|\s+menu|\s*\||\n|$)', caseSensitive: false).firstMatch(bodyContent);
                  if (titleMatch != null) {
                    var candidate = titleMatch.group(1)?.trim();
                    if (candidate != null) {
                      candidate = candidate.replaceAll(RegExp(r'^OpenTable\s*[-|:]\s*', caseSensitive: false), '');
                      candidate = candidate.replaceAll(RegExp(r'^(?:Your Reservation at|Reservation at|Reserva en)\s+', caseSensitive: false), '');
                      candidate = candidate.replaceAll(RegExp(r'\s*\|\s*OpenTable.*$', caseSensitive: false), '');
                      candidate = candidate.replaceAll(RegExp(r'\s*-\s*OpenTable.*$', caseSensitive: false), '');
                      candidate = candidate.replaceAll(RegExp(r'\s*-\s*Bogot[aá].*$', caseSensitive: false), '');
                      candidate = candidate.replaceAll(RegExp(r'\s+Restaurant$', caseSensitive: false), '');
                      candidate = candidate.trim();
                      if (candidate.isNotEmpty &&
                          candidate.length < 60 &&
                          !candidate.toLowerCase().contains('comparte tu reserva') &&
                          !candidate.toLowerCase().contains('opentable')) {
                        detectedPlace = candidate;
                      }
                    }
                  }
                }
              }
            }
          } catch (_) {}

          // Fallback adicional si es OpenTable con restaurant ID (rid)
          if (detectedPlace == null && opentableRid != null && opentableRid.isNotEmpty) {
            try {
              final otProfileUri = Uri.parse('https://r.jina.ai/https://www.opentable.com/restaurant/profile/$opentableRid');
              final otProfileRes = await http.get(otProfileUri).timeout(const Duration(seconds: 6));
              if (otProfileRes.statusCode == 200) {
                final pText = otProfileRes.body;
                final tMatch = RegExp(r'Title:\s*(.+?)(?:\s*-\s*Bogot|\s*\||\n|$)', caseSensitive: false).firstMatch(pText);
                if (tMatch != null) {
                  var pName = tMatch.group(1)?.trim();
                  if (pName != null && pName.isNotEmpty && !pName.toLowerCase().contains('opentable')) {
                    detectedPlace = pName;
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      if (platformDetected == null && (rawUrl.toLowerCase().contains('opentable') || trimmed.toLowerCase().contains('opentable'))) {
        platformDetected = 'OpenTable';
      }

      // Aplicar información detectada a la interfaz
      bool updatedAny = false;

      if (detectedPlace != null && detectedPlace.trim().isNotEmpty) {
        final cleanPlace = detectedPlace.trim();
        _placeController.text = cleanPlace;
        if (_autoCompleteTextController != null) {
          _autoCompleteTextController!.text = cleanPlace;
        }
        _lookupPlacePhoto(cleanPlace);
        _searchPlaces('$cleanPlace Bogotá').then((places) {
          if (places.isNotEmpty && mounted) {
            if (places.first.location != null) {
              setState(() {
                _selectedLocation = places.first.location;
                _isFetchingPlace = false;
              });
            } else {
              _getPlaceDetails(places.first.placeId);
            }
          } else if (mounted) {
            setState(() {
              _selectedLocation ??= const GeoPoint(4.6698, -74.0573);
              _isFetchingPlace = false;
            });
          }
        });
        updatedAny = true;
      }

      if (!_lockDateTime) {
        if (detectedDate != null) {
          _selectedDate = detectedDate;
          updatedAny = true;
        }
        if (detectedTime != null) {
          _selectedTime = detectedTime;
          updatedAny = true;
        }
      }

      if (mounted) {
        setState(() {
          _isParsingLink = false;
          if (updatedAny) {
            _hasDetectedData = true;
            final pName = platformDetected ?? 'el enlace';
            final parts = <String>[];
            if (detectedPlace != null) parts.add('Lugar');
            if (detectedDate != null) parts.add('Fecha');
            if (detectedTime != null) parts.add('Hora');
            _linkParseMessage = '✨ Detectado desde $pName: ${parts.join(', ')}';
          } else {
            _linkParseMessage = platformDetected != null 
                ? 'Plataforma $platformDetected identificada. Puedes ajustar los datos.' 
                : null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error parsing link: $e');
      if (mounted) {
        setState(() {
          _isParsingLink = false;
          _linkParseMessage = null;
        });
      }
    }
  }

  Future<List<PlaceAutocomplete>> _searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // 0. En Web, consultar directamente el servicio oficial de Google Maps Places vía JS (sin bloqueo CORS)
    if (kIsWeb) {
      try {
        final details = await js_bridge.fetchPlaceDetailsFromJs(cleanQuery);
        if (details != null) {
          final name = (details['name'] as String? ?? '').isNotEmpty
              ? details['name'] as String
              : cleanQuery;
          final address = details['address'] as String? ?? '';
          final label = address.isNotEmpty ? '$name, $address' : name;
          final lat = (details['lat'] as num?)?.toDouble();
          final lng = (details['lng'] as num?)?.toDouble();
          final photo = details['photo'] as String?;
          if (photo != null && photo.isNotEmpty && mounted) {
            setState(() => _realPlacePhoto = photo);
          }
          GeoPoint? loc;
          if (lat != null && lng != null) {
            loc = GeoPoint(lat, lng);
          }
          return [
            PlaceAutocomplete(
              description: label,
              placeId: 'google_web_${DateTime.now().millisecondsSinceEpoch}',
              location: loc,
            ),
          ];
        }
      } catch (e) {
        debugPrint('Web JS place search error: $e');
      }
    }

    // 1. Con Google Places
    if (!kIsWeb && googleMapsApiKey != 'TU_API_KEY_AQUI') {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(cleanQuery)}&key=$googleMapsApiKey&components=country:co',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 'OK') {
            return (data['predictions'] as List).map((p) => PlaceAutocomplete(
              description: p['description'] as String,
              placeId: p['place_id'] as String,
            )).toList();
          }
        }
      } catch (e) {
        debugPrint('Google Places not available: $e');
      }
    }

    // 2. Fallback multiplataforma (Photon - OpenStreetMap)
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&lat=4.6097&lon=-74.0817&limit=6',
      );
      final response = await http.get(photonUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final List<PlaceAutocomplete> results = [];
          for (var item in features) {
            final props = item['properties'] as Map<String, dynamic>?;
            final geom = item['geometry'] as Map<String, dynamic>?;
            if (props == null) continue;

            final name = props['name'] as String? ?? '';
            final street = props['street'] as String? ?? '';
            final city = props['city'] as String? ?? props['state'] as String? ?? 'Bogotá';
            
            String label = name;
            if (street.isNotEmpty && street != name) label += ', $street';
            if (city.isNotEmpty) label += ', $city';

            GeoPoint? point;
            if (geom != null && geom['coordinates'] != null) {
              final coords = geom['coordinates'] as List;
              if (coords.length >= 2) {
                point = GeoPoint((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
              }
            }

            results.add(PlaceAutocomplete(
              description: label,
              placeId: props['osm_id']?.toString() ?? '',
              location: point,
            ));
          }
          return results;
        }
      }
    } catch (e) {
      debugPrint('Photon search error: $e');
    }

    return [];
  }

  Future<void> _getPlaceDetails(String placeId) async {
    setState(() => _isFetchingPlace = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,name,formatted_address&key=$googleMapsApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          setState(() {
            _selectedLocation = GeoPoint(loc['lat'], loc['lng']);
            _isFetchingPlace = false;
          });
          return;
        }
      }
    } catch(e) {
      debugPrint('Error getting place details: $e');
    }
    setState(() => _isFetchingPlace = false);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingPlace = true);
    try {
      setState(() {
        _selectedLocation = const GeoPoint(4.6097, -74.0817);
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = 'Mi ubicación actual (Bogotá)';
        }
        _isFetchingPlace = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Ubicación fijada correctamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _selectedLocation = const GeoPoint(4.6097, -74.0817);
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = 'Bogotá Centro';
        }
        _isFetchingPlace = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final baseDate = _selectedDate ?? now;
    final initial = baseDate.isBefore(now) ? now : baseDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _publishReservation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión')));
      return;
    }

    final rawLink = _linkController.text.trim();
    if (rawLink.isNotEmpty && !_isValidUrl(rawLink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un enlace web válido o bórralo para continuar.')),
      );
      return;
    }

    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa el nombre del lugar')));
      return;
    }

    if (_selectedLocation == null) {
      if (_placeController.text.trim().isNotEmpty) {
        _selectedLocation = const GeoPoint(4.6698, -74.0573);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar un lugar de la lista o fijar tu ubicación')));
        return;
      }
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la fecha y la hora')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Verificar límite de reservas simultáneas según el plan de suscripción
      final plan = userData['plan']?.toString() ?? 'free';
      if (plan != 'pro_plus') {
        final existingQuery = await FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get();
        final currentCount = existingQuery.docs.length;
        final maxAllowed = plan == 'pro' ? 3 : 1;
        if (currentCount >= maxAllowed) {
          setState(() => _isPublishing = false);
          if (mounted) {
            _showPlanUpgradeDialog(plan, currentCount);
          }
          return;
        }
      }

      final userName = userData['name'] ?? 'Usuario';
      final pList = (userData['photoUrls'] as List?) ?? (userData['photos'] as List?);
      final userPhoto = (pList != null && pList.isNotEmpty) ? pList[0] : '';
      final birthDate = userData['birthDate'] != null ? (userData['birthDate'] as Timestamp).toDate() : null;
      int? userAge;
      if (birthDate != null) {
        final today = DateTime.now();
        userAge = today.year - birthDate.year;
        if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
          userAge--;
        }
      }

      final resDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final newDocRef = FirebaseFirestore.instance.collection('reservations').doc();
      final savedLocation = _selectedLocation;
      await newDocRef.set({
        'id': newDocRef.id,
        'userId': user.uid,
        'userName': userName,
        'userAge': userAge,
        'userPhoto': userPhoto,
        'userBio': userData['bio'] ?? '',
        'userInstagram': userData['instagramHandle'] ?? '',
        'placeName': _placeController.text.trim(),
        'location': savedLocation,
        'planType': _selectedPlan,
        'paymentType': _selectedPayment,
        'details': _detailsController.text.trim(),
        'link': _linkController.text.trim(),
        'dateTime': Timestamp.fromDate(resDateTime),
        'placePhoto': _realPlacePhoto ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (!mounted) return;
      setState(() => _isPublishing = false);
      if (widget.onPublished != null) {
        _linkController.clear();
        _detailsController.clear();
        _placeController.clear();
        _realPlacePhoto = null;
        _initDefaultDateTime();
        _selectedLocation = null;
        _hasDetectedData = false;
        _showManualEntry = false;
        widget.onPublished!(savedLocation);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DiscoverPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showPlanUpgradeDialog(String currentPlan, int count) {
    final isPro = currentPlan == 'pro';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFF007A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Límite de Reservas',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          isPro
              ? 'Ya tienes $count reservas activas (máximo permitido en tu plan Pro). Pásate a Almona Pro+ para publicar reservas simultáneas ILIMITADAS.'
              : 'Ya tienes $count reserva activa (máximo permitido en la cuenta Gratuita). Pásate a Almona Pro para tener hasta 3 simultáneas o Pro+ para reservas ILIMITADAS.',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SubscriptionPlansPage.show(context, initialTier: isPro ? SubscriptionTier.proPlus : SubscriptionTier.pro);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Ver Planes Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Publicar Reserva', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Enlace de confirmación con redirección asistida
            _buildSectionTitle(
              '1. Enlace de confirmación',
              'Pega tu enlace',
              trailing: TextButton.icon(
                onPressed: _showHowToPutReservationModal,
                icon: const Icon(Icons.help_outline_rounded, size: 16, color: AppColors.primary),
                label: const Text(
                  '¿Cómo colocar tu reserva?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              onChanged: (val) {
                final trimmed = val.trim();
                if (trimmed.isEmpty) {
                  setState(() {
                    _linkError = null;
                    _linkParseMessage = null;
                    _isParsingLink = false;
                  });
                  return;
                }

                // Si pegaron texto con URL adentro (ej: mensaje de WhatsApp)
                final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(trimmed);
                if (urlMatch != null && urlMatch.group(0) != trimmed) {
                  final extracted = urlMatch.group(0)!;
                  _linkController.value = TextEditingValue(
                    text: extracted,
                    selection: TextSelection.collapsed(offset: extracted.length),
                  );
                  setState(() => _linkError = null);
                  _parseReservationLink(extracted);
                  return;
                }

                if (!_isValidUrl(trimmed)) {
                  setState(() {
                    _linkError = 'Solo se permiten enlaces web (ej: https://...)';
                    _linkParseMessage = null;
                  });
                } else {
                  setState(() => _linkError = null);
                  _parseReservationLink(trimmed);
                }
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                hint: 'https://www.opentable.com/book/...',
                icon: Icons.link,
                errorText: _linkError,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_linkController.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpiar enlace',
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _linkController.clear();
                            setState(() {
                              _linkError = null;
                              _linkParseMessage = null;
                              _isParsingLink = false;
                            });
                            _parseReservationLink('');
                          },
                        ),
                      TextButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_rounded, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Pegar',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isParsingLink) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 8),
                  Text('Detectando automáticamente lugar, fecha y hora...', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ] else if (_linkParseMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _linkParseMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Accesos directos a plataformas de reserva
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildExternalChip('⚡ Apparta', 'https://www.apparta.co/'),
                _buildExternalChip('📅 Mesa 24/7', 'https://www.mesa247.co/'),
                _buildExternalChip('🍽️ OpenTable', 'https://www.opentable.com/'),
              ],
            ),
            


            if (_showDetails) ...[
              const SizedBox(height: 28),

              // 2. Lugar de la reserva
              _buildSectionTitle('2. Lugar de la reserva', 'Busca el restaurante o bar en Bogotá.'),
              const SizedBox(height: 12),
              Autocomplete<PlaceAutocomplete>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.length < 2) return const Iterable<PlaceAutocomplete>.empty();
                  return await _searchPlaces(textEditingValue.text);
                },
                displayStringForOption: (PlaceAutocomplete option) => option.description,
                onSelected: (PlaceAutocomplete selection) {
                  _placeController.text = selection.description;
                  if (_autoCompleteTextController != null) {
                    _autoCompleteTextController!.text = selection.description;
                  }
                  _lookupPlacePhoto(selection.description);
                  if (selection.location != null) {
                    setState(() {
                      _selectedLocation = selection.location;
                      _isFetchingPlace = false;
                    });
                  } else if (selection.placeId.isNotEmpty) {
                    _getPlaceDetails(selection.placeId);
                  }
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _autoCompleteTextController = controller;
                  if (_placeController.text.isNotEmpty && controller.text.isEmpty) {
                    controller.text = _placeController.text;
                  }
                  controller.addListener(() {
                    if (_placeController.text != controller.text) {
                      setState(() {
                        _placeController.text = controller.text;
                      });
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: _inputDecoration(hint: 'Ej: Andrés D.C., Criterión, Cantina...', icon: Icons.place),
                    onSubmitted: (val) {
                      _lookupPlacePhoto(val);
                      onFieldSubmitted();
                    },
                  );
                },
              ),

              if (_isFetchingPlace) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 8),
                    Text('Obteniendo coordenadas del lugar...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ] else if (_selectedLocation != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ubicación fijada (${_selectedLocation!.latitude.toStringAsFixed(3)}, ${_selectedLocation!.longitude.toStringAsFixed(3)})',
                          style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16, color: AppColors.primary),
                  label: const Text('Fijar con mi ubicación actual en Bogotá', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],

              // Vista previa de la foto real del restaurante obtenida de Google Places
              if (_realPlacePhoto != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Image.network(
                        _realPlacePhoto!,
                        height: 125,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                              SizedBox(width: 5),
                              Text(
                                'Foto oficial de Google Places',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Fecha y Hora (Visible una vez detectados o solicitados)
              const SizedBox(height: 28),
              _buildSectionTitle(
                '3. Fecha y Hora',
                '¿Cuándo es tu reserva?',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Conservar fecha', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _lockDateTime,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _lockDateTime = val),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.inputBorder),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDisplayDate(_selectedDate),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.inputBorder),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedTime == null ? 'Seleccionar Hora' : _selectedTime!.format(context),
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Atajos rápidos para fecha y hora
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildQuickDateChip('Hoy', DateTime.now()),
                  _buildQuickDateChip('Mañana', DateTime.now().add(const Duration(days: 1))),
                  _buildQuickDateChip('Viernes', _getNextWeekday(DateTime.friday)),
                  _buildQuickDateChip('Sábado', _getNextWeekday(DateTime.saturday)),
                  _buildQuickTimeChip('7:00 PM', const TimeOfDay(hour: 19, minute: 0)),
                  _buildQuickTimeChip('8:00 PM', const TimeOfDay(hour: 20, minute: 0)),
                  _buildQuickTimeChip('9:00 PM', const TimeOfDay(hour: 21, minute: 0)),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // 4. Tipo de plan (Café y Brunch separados)
            _buildSectionTitle('4. Tipo de plan', '¿Cuál es la vibra del encuentro?'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: _planTypes.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildChip(
                      label: type,
                      isSelected: _selectedPlan == type,
                      onTap: () => setState(() => _selectedPlan = type),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 28),

            // 5. Modalidad de pago
            _buildSectionTitle('5. Modalidad de pago', 'Establece las expectativas con claridad.'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: _paymentTypes.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildChip(
                      label: type,
                      isSelected: _selectedPayment == type,
                      onTap: () => setState(() => _selectedPayment = type),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 6. Punch Line / Detalles adicionales
            _buildSectionTitle('6. Punch Line & Detalles', 'Ambientación para motivar a acompañarte.'),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              minLines: 2,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
              decoration: _inputDecoration(
                hint: 'Ej: "Mesa en la terraza para probar cócteles de autor. ¿Quién se anima?"',
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPublishing ? null : _publishReservation,
              icon: _isPublishing 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _isPublishing ? 'Publicando...' : 'Publicar Reserva en el Mapa',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExternalChip(String label, String url) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
      backgroundColor: AppColors.primary.withOpacity(0.08),
      side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      onPressed: () => _openExternalPlatform(url),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textLight, size: 20) : null,
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorStyle: const TextStyle(fontSize: 12, color: Colors.redAccent),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.inputBorder)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  String _formatDisplayDate(DateTime? dt) {
    if (dt == null) return 'Seleccionar Fecha';
    try {
      return DateFormat('EEE dd MMM yyyy', 'es').format(dt);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
  }

  Widget _buildQuickDateChip(String label, DateTime targetDate) {
    final isSelected = _selectedDate != null &&
        _selectedDate!.year == targetDate.year &&
        _selectedDate!.month == targetDate.month &&
        _selectedDate!.day == targetDate.day;
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = targetDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTimeChip(String label, TimeOfDay targetTime) {
    final isSelected = _selectedTime != null &&
        _selectedTime!.hour == targetTime.hour &&
        _selectedTime!.minute == targetTime.minute;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = targetTime),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showHowToPutReservationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Indicador de arrastre
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Cómo colocar tu reserva?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Guía rápida para copiar el link en cada app',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _buildGuideItem(
                      iconEmoji: '⚡',
                      appName: 'Apparta',
                      color: const Color(0xFF6C5CE7),
                      steps: [
                        'Haz tu reserva normalmente en la app de Apparta o en su web.',
                        'Ve a tu reserva confirmada y toca el botón "Compartir reserva" o copia el enlace que te envían por WhatsApp/correo.',
                        'Pega el enlace en la casilla de esta pantalla y detectaremos el restaurante, fecha y hora en segundos.',
                      ],
                      exampleUrl: 'https://apparta.co/reserva/andres-dc?...',
                    ),
                    const SizedBox(height: 16),
                    _buildGuideItem(
                      iconEmoji: '📅',
                      appName: 'Mesa 24/7',
                      color: const Color(0xFFE17055),
                      steps: [
                        'Al reservar en Mesa 24/7, recibirás un correo o pantalla de confirmación.',
                        'Toca la opción "Compartir reserva" o copia la URL de confirmación que aparece en tu navegador.',
                        'Pégala aquí. El sistema leerá automáticamente el nombre del restaurante y horario.',
                      ],
                      exampleUrl: 'https://www.mesa247.co/reserva/share?id=...',
                    ),
                    const SizedBox(height: 16),
                    _buildGuideItem(
                      iconEmoji: '🍽️',
                      appName: 'OpenTable (App o Web)',
                      color: const Color(0xFFD63031),
                      steps: [
                        'En la app de OpenTable o en su web, entra a tu reserva y toca "Compartir", "Invitar amigos" o copia el enlace.',
                        'Si compartes por WhatsApp o copias al portapapeles, pega el texto o el link directamente aquí.',
                        '¡Listo! Detectamos el restaurante, fecha y hora tanto si viene de la app como si viene de la web.',
                      ],
                      exampleUrl: 'https://opentable.page.link/... o www.opentable.com/r/...',
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '💡 También puedes pegar mensajes de WhatsApp o confirmaciones completas por texto; detectamos fechas y horas automáticamente.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF0984E3), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideItem({
    required String iconEmoji,
    required String appName,
    required Color color,
    required List<String> steps,
    required String exampleUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(iconEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                appName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ej: $exampleUrl',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
