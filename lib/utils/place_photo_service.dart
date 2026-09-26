import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secrets.dart';
import 'place_photo_stub.dart' if (dart.library.js) 'place_photo_web.dart' as js_bridge;

class PlacePhotoService {
  static final Map<String, String> _cache = {};

  // Fotos oficiales verificadas y con CORS habilitado en Google CDN (lh3.googleusercontent.com)
  static final Map<String, String> _verifiedPlaces = {
    'osaka': 'https://lh3.googleusercontent.com/place-photos/AG9NLjCCizhn0GAmqGNO-SMECXnDwnIaMnRMxopae4FG9CFN11h6s2a91uWjvbWEhcj8jkRB2t-RCVOCoinOHTGyWMMi4Kj0Jl8sUD_9GSxd2qq7-F9a1IMPDLjM64XynoSXzvxiD0F3Tdvn1O8zvXKerrPIvQ=s1600-w800',
    'oda': 'https://lh3.googleusercontent.com/place-photos/AG9NLjBqaXRv13oxj799H3ro3_Vo_1sGlbIKKDOZXZLahLSrzx0i2GzhCWNfee-_UioVuBHs57TbpjZYZmsKt8a6YgnLqIG8zhpzC_sDbZGOdkq6y68Pz47LuNX3cfx60tSz8ESBOHp7Hey45m06tbuoqykbDA=s1600-w800',
    'oda restaurante': 'https://lh3.googleusercontent.com/place-photos/AG9NLjBqaXRv13oxj799H3ro3_Vo_1sGlbIKKDOZXZLahLSrzx0i2GzhCWNfee-_UioVuBHs57TbpjZYZmsKt8a6YgnLqIG8zhpzC_sDbZGOdkq6y68Pz47LuNX3cfx60tSz8ESBOHp7Hey45m06tbuoqykbDA=s1600-w800',
    'andres': 'https://lh3.googleusercontent.com/grass-cs/ACvplmNmhADqc8YsAg8r4_2sYb3r8IzEXU-SxfRYr6JzOKUP2QrJJ-pClkjCdAM7xxCAwiYsjZVWVVQZEI3tOSUYvO5bbweSlbzl2TlMIC_K9mKWMe_dKZS4jII_9WbnxroxgcbAhLLC_8mZf6vX=s1600-w800',
    'andres dc': 'https://lh3.googleusercontent.com/grass-cs/ACvplmNmhADqc8YsAg8r4_2sYb3r8IzEXU-SxfRYr6JzOKUP2QrJJ-pClkjCdAM7xxCAwiYsjZVWVVQZEI3tOSUYvO5bbweSlbzl2TlMIC_K9mKWMe_dKZS4jII_9WbnxroxgcbAhLLC_8mZf6vX=s1600-w800',
    'andres d.c.': 'https://lh3.googleusercontent.com/grass-cs/ACvplmNmhADqc8YsAg8r4_2sYb3r8IzEXU-SxfRYr6JzOKUP2QrJJ-pClkjCdAM7xxCAwiYsjZVWVVQZEI3tOSUYvO5bbweSlbzl2TlMIC_K9mKWMe_dKZS4jII_9WbnxroxgcbAhLLC_8mZf6vX=s1600-w800',
    'andres carne de res': 'https://lh3.googleusercontent.com/grass-cs/ACvplmNmhADqc8YsAg8r4_2sYb3r8IzEXU-SxfRYr6JzOKUP2QrJJ-pClkjCdAM7xxCAwiYsjZVWVVQZEI3tOSUYvO5bbweSlbzl2TlMIC_K9mKWMe_dKZS4jII_9WbnxroxgcbAhLLC_8mZf6vX=s1600-w800',
    'harry sasson': 'https://lh3.googleusercontent.com/grass-cs/ACvplmN55lR8YAmsPoaRfYODwLuj3yUY1fCmWSM9JVa3LRVNOg5tpzAFf3rRd5p1RANgE7aq83k4IkMp_4Avflz_xwz2T4-iRn0-RO7j62JtBBaFyxQ_Lg-UjVD91WQmoen4hHV0nali=s1600-w800',
    'el chato': 'https://lh3.googleusercontent.com/grass-cs/ACvplmP8wnQjPyLvtdfRVtVjjHkQCZbp2q7bsFo0InN4sL80-spHrwMo2BqGhtUJMVzp3c-khAz1ERysRStFrHzwnqYEdt4VkxGxCege3Up_d0Zs9ViRwlDYp2n1L7iPw8YZQxEW0g0R=s1600-w800',
    'cantina la 15': 'https://lh3.googleusercontent.com/place-photos/AG9NLjDQZhmq0zzIqlyMxDl93ZMiqreok6bmJetffPQKmbHbzVsuu1pSGKcYGAXOg0tH9V_Khsxp2dkC071pyEzqYwtZzpYWLzQGpfNlMJP72exq16oO3VK4VHcD_xxKygEiXODkXyA8748nCaytOA=s1600-w800',
    'criterion': 'https://lh3.googleusercontent.com/grass-cs/ACvplmN9JfG9daDXJO_J8aOcVtPU40duijxJ8o9Iij7vhIT9h1aeA_z4EFoSZYbsJ8bHAnHaBp-RlDPke6buFvWWYBrgT4ri9IAVwOUBS5cUbE3wrDcovMEXxvkrrxv8pV6a-fl6SJuS2g=s1600-w800',
    'crepes': 'https://lh3.googleusercontent.com/place-photos/AG9NLjBgjeXFppzfQw0gVLWO3gaMo2U6wnFP5oe101GcjhDZgYPJeSmcHXkb5lA5Cen04CeCqvvRptPo2icNKyqGXGsTkz6bBRKPM4gE3LHbrCEXf5gUTyaKLkO2S1uv7wXLI-vmFg5iuR5pGzei43M=s1600-w800',
    'crepes & waffles': 'https://lh3.googleusercontent.com/place-photos/AG9NLjBgjeXFppzfQw0gVLWO3gaMo2U6wnFP5oe101GcjhDZgYPJeSmcHXkb5lA5Cen04CeCqvvRptPo2icNKyqGXGsTkz6bBRKPM4gE3LHbrCEXf5gUTyaKLkO2S1uv7wXLI-vmFg5iuR5pGzei43M=s1600-w800',
    'wok': 'https://lh3.googleusercontent.com/grass-cs/ACvplmOEFv4WfjaDdr5KXEEq5c7X47H2ZNRdfFF1B11Jg2ypS5Y9sRx8H-O-FfFBOX3qdmwgni5jzcnZi2xqmFRhBcA7IBvY6g5uePazqn3BIJD4tjP2BDSwazUJ8QBUneIlFPltVoFqaw=s1600-w800',
    'masa': 'https://lh3.googleusercontent.com/grass-cs/ACvplmPSAcQjeF0yx5HdeR8GbcMvkAMqGMAKw7nRlLVVThS8CTBGzc2Llf1SHA9uCxJf5-uBURljYX0Hb1Qlbw5hsTNfKkNbAKA78q_LignnwQulp2aMNQMCve1nJmypgWWZPiFMgWv_qi97jZIq=s1600-w800',
    'masa 70': 'https://lh3.googleusercontent.com/grass-cs/ACvplmPSAcQjeF0yx5HdeR8GbcMvkAMqGMAKw7nRlLVVThS8CTBGzc2Llf1SHA9uCxJf5-uBURljYX0Hb1Qlbw5hsTNfKkNbAKA78q_LignnwQulp2aMNQMCve1nJmypgWWZPiFMgWv_qi97jZIq=s1600-w800',
  };

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('.', '')
        .replaceAll('-', ' ');
  }

  static String? getVerifiedOrCachedPhoto(String placeName) {
    if (placeName.isEmpty) return null;
    final norm = _normalize(placeName);
    for (final entry in _verifiedPlaces.entries) {
      if (norm.contains(entry.key) || entry.key.contains(norm)) {
        return entry.value;
      }
    }
    return _cache[norm];
  }

  static Future<String?> fetchPhotoForPlace(String placeName) async {
    if (placeName.trim().isEmpty) return null;
    final cached = getVerifiedOrCachedPhoto(placeName);
    if (cached != null) return cached;

    final norm = _normalize(placeName);
    final query = '$placeName Bogotá';

    // 1. En Web, consultar directamente el servicio oficial de Google Maps Places vía JS (retorna CDN con CORS)
    if (kIsWeb) {
      try {
        final photoUrl = await js_bridge.fetchPlacePhotoFromJs(query);
        if (photoUrl != null && photoUrl.isNotEmpty) {
          _cache[norm] = photoUrl;
          return photoUrl;
        }
      } catch (e) {
        debugPrint('Web JS Places error: $e');
      }
    }

    // 2. En Móvil (o fallback), consultar Google Places REST API
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent(query)}&inputtype=textquery&fields=photos,name&key=$googleMapsApiKey',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['candidates'] != null && (data['candidates'] as List).isNotEmpty) {
          final candidate = data['candidates'][0];
          final photos = candidate['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            final photoRef = photos[0]['photo_reference'] as String?;
            if (photoRef != null && photoRef.isNotEmpty) {
              final rawUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=$photoRef&key=$googleMapsApiKey';
              String finalPhotoUrl = rawUrl;
              if (!kIsWeb) {
                try {
                  final client = http.Client();
                  final req = http.Request('HEAD', Uri.parse(rawUrl))..followRedirects = false;
                  final streamed = await client.send(req).timeout(const Duration(seconds: 2));
                  final location = streamed.headers['location'];
                  if (location != null && location.isNotEmpty) {
                    finalPhotoUrl = location;
                  }
                  client.close();
                } catch (_) {}
              }
              _cache[norm] = finalPhotoUrl;
              return finalPhotoUrl;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Places REST photo fetch error: $e');
    }

    return null;
  }

  // Persistir la foto real encontrada en el documento de Firestore para que quede guardada
  static void resolveAndPersistPlacePhoto(String docId, String placeName) {
    if (docId.isEmpty || placeName.isEmpty) return;
    fetchPhotoForPlace(placeName).then((photoUrl) {
      if (photoUrl != null && photoUrl.isNotEmpty && !photoUrl.contains('maps.googleapis.com')) {
        FirebaseFirestore.instance.collection('reservations').doc(docId).update({
          'placePhoto': photoUrl,
        }).catchError((e) {
          debugPrint('Error updating reservation with real place photo: $e');
        });
      }
    });
  }
}
