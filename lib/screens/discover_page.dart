import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../utils/marker_generator.dart';
import '../widgets/user_profile_modal.dart';
import '../widgets/tinder_swipe_view.dart';
import 'my_profile_page.dart';
import '../utils/zone_data.dart';
import '../widgets/map_tutorial_overlay.dart';
import 'publish_reservation_page.dart';
import '../utils/place_photo_service.dart';

class ReservationMapItem {
  final String id;
  final Map<String, dynamic> data;
  final LatLng latLng;
  final String placeName;
  final String planType;
  final String paymentType;
  final String details;
  final String link;
  final String formattedDate;
  final String locationText;
  final String hostUserId;
  final String hostName;
  final int? hostAge;
  final String hostBio;
  final String hostPhoto;
  final String hostInstagram;
  final String restaurantPhoto;

  ReservationMapItem({
    required this.id,
    required this.data,
    required this.latLng,
    required this.placeName,
    required this.planType,
    required this.paymentType,
    required this.details,
    required this.link,
    required this.formattedDate,
    required this.locationText,
    required this.hostUserId,
    required this.hostName,
    this.hostAge,
    required this.hostBio,
    required this.hostPhoto,
    required this.hostInstagram,
    required this.restaurantPhoto,
  });
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => DiscoverPageState();
}

class DiscoverPageState extends State<DiscoverPage> {
  GoogleMapController? _mapController;
  
  // Bogotá por defecto
  static const LatLng _bogotaCenter = LatLng(4.6097, -74.0817);
  LatLng _currentPosition = _bogotaCenter;
  
  Set<Marker> _markers = {};
  List<ReservationMapItem> _reservationsList = [];
  ReservationMapItem? _selectedReservation;
  int _selectedReservationIndex = 0;
  int _panAnimationId = 0;
  LatLng _lastCameraPosition = _bogotaCenter;
  bool _showPeopleDiscovery = false;
  final Set<String> _preferredZones = {};
  bool _showMapTutorial = false;
  bool _hasDismissedTutorialLocally = false;

  // Cache para no descargar la foto cada vez que se mueve el mapa
  final Map<String, BitmapDescriptor> _markerCache = {};

  StreamSubscription? _userSub;
  StreamSubscription? _reservationsSub;
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    _initBlueDot();
    _determinePosition();
    _listenToReservations();
    _listenToCurrentUserProfile();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _userSub?.cancel();
    _reservationsSub?.cancel();
    _mapController = null;
    super.dispose();
  }

  Future<void> _initBlueDot() async {
    // No-op ya que no usamos ubicación
  }

  void _listenToCurrentUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
        if (mounted) {
          bool zonesChanged = false;
          if (snap.exists && snap.data() != null) {
            final data = snap.data()!;
            if (data['preferredZones'] != null && data['preferredZones'] is List) {
              final newZones = (data['preferredZones'] as List).map((e) => e.toString()).toSet();
              if (newZones.length != _preferredZones.length || !_preferredZones.containsAll(newZones)) {
                _preferredZones.clear();
                _preferredZones.addAll(newZones);
                zonesChanged = true;
              }
            }
            if (data['hasSeenMapTutorial'] != true && !_hasDismissedTutorialLocally) {
              _showMapTutorial = true;
            }
          }
          setState(() {});
          if (zonesChanged) {
            _listenToReservations();
          }
        }
    });
  }

  void moveToLocation(LatLng position) {
    _currentPosition = position;
    _lastCameraPosition = position;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15.0),
    );
  }

  Future<void> _smoothPanTo(LatLng target) async {
    if (_mapController == null) return;
    final animId = ++_panAnimationId;
    
    final start = _lastCameraPosition;
    final dLat = target.latitude - start.latitude;
    final dLng = target.longitude - start.longitude;
    final dist = math.sqrt(dLat * dLat + dLng * dLng);

    // Si la distancia es insignificante, simplemente centrar directamente
    if (dist < 0.0002) {
      _lastCameraPosition = target;
      await _mapController?.animateCamera(CameraUpdate.newLatLng(target));
      return;
    }

    // Pasos adaptativos según la distancia para un desplazamiento continuo fluido
    final int steps = (dist / 0.0035).round().clamp(6, 18);
    const stepDelay = Duration(milliseconds: 28);

    for (int i = 1; i <= steps; i++) {
      if (_panAnimationId != animId || !mounted) return;
      final t = i / steps;
      // Curva easeInOut cuadrática para suavizar arranque y frenado
      final curvedT = t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
      final curLat = start.latitude + dLat * curvedT;
      final curLng = start.longitude + dLng * curvedT;
      
      await _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(curLat, curLng)),
      );
      await Future.delayed(stepDelay);
    }

    if (_panAnimationId == animId && mounted) {
      _lastCameraPosition = target;
      await _mapController?.animateCamera(CameraUpdate.newLatLng(target));
    }
  }

  void _goToReservation(int newIndex) {
    if (_reservationsList.isEmpty) return;

    int idx = newIndex;
    if (idx < 0) {
      idx = _reservationsList.length - 1;
    } else if (idx >= _reservationsList.length) {
      idx = 0;
    }

    setState(() {
      _selectedReservationIndex = idx;
      _selectedReservation = _reservationsList[idx];
    });

    _smoothPanTo(_reservationsList[idx].latLng);
  }

  void _goToNextReservation() {
    _goToReservation(_selectedReservationIndex + 1);
  }

  void _goToPrevReservation() {
    _goToReservation(_selectedReservationIndex - 1);
  }

  LatLng? _parseLocation(dynamic loc, dynamic lat, dynamic lng) {
    if (loc is GeoPoint) {
      return LatLng(loc.latitude, loc.longitude);
    }
    if (loc is Map) {
      final num? la = loc['latitude'] ?? loc['lat'];
      final num? lo = loc['longitude'] ?? loc['lng'];
      if (la != null && lo != null) {
        return LatLng(la.toDouble(), lo.toDouble());
      }
    }
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    return null;
  }

  String _formatReservationDate(dynamic rawDateTime) {
    DateTime? dateTime;
    if (rawDateTime is Timestamp) {
      dateTime = rawDateTime.toDate();
    } else if (rawDateTime is DateTime) {
      dateTime = rawDateTime;
    } else if (rawDateTime is String) {
      dateTime = DateTime.tryParse(rawDateTime);
    }

    if (dateTime == null) return '';

    try {
      return DateFormat('EEE dd MMM • HH:mm', 'es').format(dateTime);
    } catch (_) {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day/$month • $hour:$minute';
    }
  }

  Future<void> _determinePosition() async {}

  int? _calculateAge(dynamic birthDate) {
    if (birthDate == null) return null;
    DateTime? date;
    if (birthDate is Timestamp) {
      date = birthDate.toDate();
    } else if (birthDate is DateTime) {
      date = birthDate;
    } else if (birthDate is String) {
      date = DateTime.tryParse(birthDate);
    }
    if (date == null) return null;
    final today = DateTime.now();
    int age = today.year - date.year;
    if (today.month < date.month || (today.month == date.month && today.day < date.day)) {
      age--;
    }
    return age;
  }

  String _getPlanIcon(String planType) {
    final p = planType.toLowerCase();
    if (p.contains('trago') || p.contains('copa') || p.contains('bar')) return '🍸';
    if (p.contains('caf') || p.contains('brunch')) return '☕';
    return '🍽️';
  }

  String _resolveRestaurantPhoto(Map<String, dynamic> data, String planType, String seed, {String placeName = '', String docId = ''}) {
    // 1. Prioridad: Foto oficial verificada o en caché para el lugar (con CORS habilitado)
    if (placeName.isNotEmpty) {
      final realPhoto = PlacePhotoService.getVerifiedOrCachedPhoto(placeName);
      if (realPhoto != null && realPhoto.isNotEmpty) {
        return realPhoto;
      }
      if (docId.isNotEmpty) {
        PlacePhotoService.resolveAndPersistPlacePhoto(docId, placeName);
      }
    }

    // 2. Foto guardada previamente en Firestore (solo si no es una URL con problema CORS de maps.googleapis.com)
    final savedPhoto = (data['placePhoto'] as String?) ?? (data['restaurantPhoto'] as String?);
    if (savedPhoto != null && savedPhoto.isNotEmpty) {
      if (!savedPhoto.contains('maps.googleapis.com')) {
        return savedPhoto;
      }
    }
    
    final plan = planType.toLowerCase();
    if (plan.contains('trago') || plan.contains('bar') || plan.contains('copa')) {
      final list = [
        'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=800&q=80',
        'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800&q=80',
        'https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=800&q=80',
      ];
      return list[seed.hashCode.abs() % list.length];
    } else if (plan.contains('caf') || plan.contains('brunch')) {
      final list = [
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
        'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&q=80',
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&q=80',
      ];
      return list[seed.hashCode.abs() % list.length];
    } else {
      // Comida / Cena / Restaurante elegante
      final list = [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80',
        'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800&q=80',
        'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800&q=80',
        'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&q=80',
      ];
      return list[seed.hashCode.abs() % list.length];
    }
  }

  void _showFullImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.65),
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isReservationInPreferredZones(LatLng latLng, Map<String, dynamic> data) {
    // Si el usuario no ha seleccionado ninguna zona, no mostrar citas fuera de zona
    if (_preferredZones.isEmpty) return false;

    // 1. Verificación geométrica exacta por polígono (Ray Casting)
    if (ZoneData.isPointInAnyZone(latLng, _preferredZones)) {
      return true;
    }

    // 2. Verificación secundaria por metadato 'zone' o 'zoneName' guardado en el documento
    final docZone = (data['zone'] ?? data['zoneName'])?.toString().trim();
    if (docZone != null && docZone.isNotEmpty) {
      final normDocZone = ZoneData.normalizeZoneName(docZone);
      for (final pz in _preferredZones) {
        if (ZoneData.normalizeZoneName(pz) == normDocZone) {
          return true;
        }
      }
    }

    // 3. Verificación por coincidencia con el nombre de la localidad en dirección o nombre
    final placeName = data['placeName']?.toString() ?? '';
    final address = data['address']?.toString() ?? '';
    for (final pz in _preferredZones) {
      final normPz = ZoneData.normalizeZoneName(pz);
      if (normPz.length >= 4) {
        if (ZoneData.normalizeZoneName(placeName).contains(normPz) ||
            ZoneData.normalizeZoneName(address).contains(normPz)) {
          return true;
        }
      }
    }

    return false;
  }


  void _listenToReservations() {
    _reservationsSub?.cancel();
    _reservationsSub = FirebaseFirestore.instance.collection('reservations').snapshots().listen((snapshot) async {
      final Set<Marker> newMarkers = {};
      final List<ReservationMapItem> newReservationsList = [];
      final Map<String, Map<String, dynamic>?> userDocsCache = {};
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final latLng = _parseLocation(data['location'], data['latitude'], data['longitude']);
          if (latLng == null) continue;

          // FILTRO DE ZONAS ELEGIDAS POR EL USUARIO:
          // Solo mostrar citas que estén dentro de las zonas que el usuario haya seleccionado.
          // Si la cita está fuera de esa zona, NO debe aparecer.
          if (!_isReservationInPreferredZones(latLng, data)) {
            continue;
          }

          final userId = data['userId'] as String?;
          String userName = (data['userName'] != null && (data['userName'] as String).isNotEmpty)
              ? data['userName']
              : 'Alguien';
          String photoUrl = data['userPhoto'] ?? '';
          String hostBio = '';
          int? hostAge;
          String hostInstagram = '';
          
          // Consultar los datos frescos del usuario en 'users' para garantizar que la foto y nombre
          // reflejen cualquier cambio de perfil reciente.
          if (userId != null && userId.isNotEmpty) {
            Map<String, dynamic>? userData;
            if (userDocsCache.containsKey(userId)) {
              userData = userDocsCache[userId];
            } else {
              try {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                userData = userDoc.data();
                userDocsCache[userId] = userData;
              } catch (_) {
                userDocsCache[userId] = null;
              }
            }
            if (userData != null) {
              if (userData['name'] != null && (userData['name'] as String).isNotEmpty) {
                userName = userData['name'];
              }
              final pList = (userData['photoUrls'] as List?) ?? (userData['photos'] as List?);
              if (pList != null && pList.isNotEmpty) {
                final first = pList[0]?.toString() ?? '';
                if (first.isNotEmpty) photoUrl = first;
              }
              hostBio = userData['bio']?.toString() ?? '';
              hostAge = _calculateAge(userData['birthDate']);
              hostInstagram = userData['instagramHandle']?.toString() ?? '';
            }
          }

          // Generar el marcador (burbuja circular) usando caché
          BitmapDescriptor icon;
          if (_markerCache.containsKey(photoUrl)) {
            icon = _markerCache[photoUrl]!;
          } else {
            try {
              icon = await createCustomMarkerBitmap(photoUrl);
              _markerCache[photoUrl] = icon;
            } catch (e) {
              icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
            }
          }

          final placeName = data['placeName'] ?? 'Restaurante';
          final planType = data['planType'] ?? 'Comida';
          final paymentType = data['paymentType'] ?? '';
          final details = data['details'] ?? '';
          final link = data['link'] ?? '';
          final dateStr = _formatReservationDate(data['dateTime']);

          String locationArea = 'Zona Bogotá';
          if (data['address'] != null && (data['address'] as String).isNotEmpty) {
            locationArea = data['address'];
          } else if (placeName.contains(',')) {
            final parts = placeName.split(',');
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              locationArea = parts[1].trim();
            }
          }

          final restaurantPhoto = _resolveRestaurantPhoto(data, planType, doc.id, placeName: placeName, docId: doc.id);

          final resItem = ReservationMapItem(
            id: doc.id,
            data: data,
            latLng: latLng,
            placeName: placeName.contains(',') ? placeName.split(',')[0].trim() : placeName,
            planType: planType,
            paymentType: paymentType,
            details: details,
            link: link,
            formattedDate: dateStr,
            locationText: locationArea,
            hostUserId: userId ?? '',
            hostName: userName,
            hostAge: hostAge,
            hostBio: hostBio,
            hostPhoto: photoUrl,
            hostInstagram: hostInstagram,
            restaurantPhoto: restaurantPhoto,
          );
          newReservationsList.add(resItem);

          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: latLng,
              icon: icon,
              infoWindow: InfoWindow.noText,
              onTap: () {
                final idx = _reservationsList.indexWhere((r) => r.id == doc.id);
                if (idx != -1) {
                  _goToReservation(idx);
                } else {
                  setState(() {
                    _selectedReservation = resItem;
                  });
                  _smoothPanTo(latLng);
                }
              },
            ),
          );
        } catch (e) {
          debugPrint('Error processing doc ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          _reservationsList = newReservationsList;
          if (_selectedReservation != null) {
            final foundIdx = newReservationsList.indexWhere((r) => r.id == _selectedReservation!.id);
            if (foundIdx != -1) {
              _selectedReservationIndex = foundIdx;
              _selectedReservation = newReservationsList[foundIdx];
            } else if (newReservationsList.isNotEmpty) {
              _selectedReservationIndex = 0;
              _selectedReservation = newReservationsList.first;
            }
          } else if (newReservationsList.isNotEmpty) {
            // Fija y visible siempre en el mapa desde el inicio para pasar entre citas directamente
            _selectedReservationIndex = 0;
            _selectedReservation = newReservationsList.first;
          }
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to reservations: $e');
    });
  }

  void _openReservationDetails(ReservationMapItem res) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SafeArea(
          bottom: true,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tirador superior de arrastre
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cabecera: Badges de categoría y pago a la izquierda y botón cerrar (X) a la derecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_getPlanIcon(res.planType), style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 5),
                              Text(
                                res.planType.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (res.paymentType.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  res.paymentType.toLowerCase().contains('invito')
                                      ? Icons.card_giftcard_rounded
                                      : Icons.payments_outlined,
                                  size: 13,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  res.paymentType,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 17, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Contenido completo de la cita (scrollable si es necesario)
                Flexible(
                  child: _buildReservationCardContent(context, res),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReservationCardContent(BuildContext context, ReservationMapItem res) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isMine = (currentUserId.isNotEmpty && currentUserId == res.hostUserId);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Imagen Banner del Restaurante / Lugar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: Image.network(
                    res.restaurantPhoto,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFEEF1F6),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Image.network(
                      _resolveRestaurantPhoto({}, res.planType, res.id),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF262C36),
                        child: const Center(
                          child: Icon(Icons.restaurant, color: Colors.white70, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),

                // Degradado inferior sutil
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pill Superior Izquierda: "🔍 Toca para ampliar"
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () => _showFullImageDialog(context, res.restaurantPhoto, res.placeName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Toca para ampliar',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pill Inferior Izquierda: Instagram tag o enlace de reserva
                if (res.hostInstagram.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://instagram.com/${res.hostInstagram}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '@${res.hostInstagram}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (res.link.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(res.link.startsWith('http') ? res.link : 'https://${res.link}');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Ver Reserva',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Nombre del Restaurante / Lugar
          Text(
            res.placeName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          // 3. Ubicación y Fecha / Hora en Chips elegantes
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      res.locationText,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      res.formattedDate,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. Tarjeta del Anfitrión (Estilo Mateo, 28)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isMine) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: AppColors.background,
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: const Text('Mi Perfil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      ),
                      body: const MyProfilePage(),
                    ),
                  ),
                );
              } else {
                UserProfileModal.show(context, userId: res.hostUserId, name: res.hostName, photo: res.hostPhoto);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: res.hostPhoto.isNotEmpty ? NetworkImage(res.hostPhoto) : null,
                    child: res.hostPhoto.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 22) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ANFITRIÓN',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                res.hostAge != null ? '${res.hostName}, ${res.hostAge}' : res.hostName,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          res.hostBio.isNotEmpty
                              ? res.hostBio
                              : (res.details.isNotEmpty ? res.details : 'Toca para ver el perfil completo.'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 5. Botón Principal: "Solicitar unirme a la cita"
          if (isMine)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esta es tu reserva publicada. Puedes gestionarla en la pestaña Reservas 📌'),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                label: const Text(
                  'Tu Reserva Publicada 📌',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E242B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: currentUserId.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('reservation_requests')
                      .where('reservationId', isEqualTo: res.id)
                      .where('requesterUserId', isEqualTo: currentUserId)
                      .snapshots()
                  : null,
              builder: (context, reqSnap) {
                final hasRequested = reqSnap.hasData && reqSnap.data!.docs.isNotEmpty;
                final reqDocData = hasRequested ? (reqSnap.data!.docs.first.data() as Map<String, dynamic>) : null;
                final reqStatus = reqDocData?['status'] ?? 'pending';
                final isReschedule = reqDocData?['requestType'] == 'reschedule';

                if (hasRequested) {
                  final isAccepted = reqStatus == 'accepted';
                  return Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isAccepted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isAccepted
                            ? const Color(0xFF2E7D32).withOpacity(0.3)
                            : const Color(0xFFE65100).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAccepted
                              ? Icons.check_circle
                              : (isReschedule ? Icons.event_repeat_rounded : Icons.hourglass_top),
                          color: isAccepted ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAccepted
                              ? '¡Solicitud Aceptada! (Hay Match 🎉)'
                              : (isReschedule
                                  ? 'Propuesta enviada (Pendiente 🗓️)'
                                  : 'Solicitud enviada (Pendiente ⏳)'),
                          style: TextStyle(
                            color: isAccepted ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openRequestJoinDialog(res.id, res.data, res.hostUserId, res.hostName, res.placeName);
                        },
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Solicitar unirme a la cita',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16181F),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openRescheduleDialog(res.id, res.data, res.hostUserId, res.hostName, res.placeName);
                        },
                        icon: const Icon(Icons.edit_calendar_rounded, size: 17, color: Color(0xFF334155)),
                        label: const Text(
                          'Proponer reprogramar cita',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _openRequestJoinDialog(
    String reservationId,
    Map<String, dynamic> reservationData,
    String hostUserId,
    String hostUserName,
    String placeName,
  ) {
    final messageController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Solicitar unirte a la reserva',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 8),
                  Text(
                    'Vas a solicitar unirte al plan en $placeName con $hostUserName.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mensaje para romper el hielo (opcional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: messageController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej. ¡Me encantaría ir! Conozco ese sitio y es genial...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isSending
                          ? null
                          : () async {
                              setModalState(() => isSending = true);
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) throw Exception('Debes iniciar sesión');

                                String requesterName = user.displayName ?? 'Usuario';
                                String requesterPhoto = user.photoURL ?? '';

                                try {
                                  final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                  if (uDoc.exists) {
                                    final uData = uDoc.data();
                                    if (uData != null) {
                                      if (uData['name'] != null && (uData['name'] as String).isNotEmpty) {
                                        requesterName = uData['name'];
                                      }
                                      final pList = (uData['photoUrls'] as List?) ?? (uData['photos'] as List?);
                                      if (pList != null && pList.isNotEmpty) {
                                        final first = pList[0]?.toString() ?? '';
                                        if (first.isNotEmpty) requesterPhoto = first;
                                      }
                                    }
                                  }
                                } catch (_) {}

                                final msg = messageController.text.trim();
                                final now = Timestamp.now();

                                await FirebaseFirestore.instance.collection('reservation_requests').add({
                                  'reservationId': reservationId,
                                  'hostUserId': hostUserId,
                                  'requesterUserId': user.uid,
                                  'requesterName': requesterName,
                                  'requesterPhoto': requesterPhoto,
                                  'placeName': placeName,
                                  'dateTime': reservationData['dateTime'],
                                  'planType': reservationData['planType'] ?? 'Comida',
                                  'paymentType': reservationData['paymentType'] ?? '',
                                  'status': 'pending',
                                  'message': msg,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'interactionHistory': [
                                    {
                                      'type': 'created',
                                      'title': 'Reserva publicada',
                                      'description': '$hostUserName publicó esta reserva en el mapa.',
                                      'timestamp': reservationData['createdAt'] ?? now,
                                    },
                                    {
                                      'type': 'request_sent',
                                      'title': 'Solicitud enviada',
                                      'description': msg.isNotEmpty
                                          ? '$requesterName envió una solicitud para unirse: "$msg"'
                                          : '$requesterName envió una solicitud para unirse.',
                                      'timestamp': now,
                                    },
                                  ],
                                });

                                if (context.mounted) {
                                  Navigator.pop(context); // Cierra modal de solicitud
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('¡Solicitud enviada a $hostUserName! Te avisaremos cuando responda 🤞'),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isSending = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                      icon: isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: const Text('Enviar Solicitud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openRescheduleDialog(
    String reservationId,
    Map<String, dynamic> reservationData,
    String hostUserId,
    String hostUserName,
    String placeName,
  ) {
    // Tomar fecha actual de la reserva como referencia inicial
    DateTime initialDateTime = DateTime.now().add(const Duration(days: 1));
    final rawDate = reservationData['dateTime'];
    if (rawDate is Timestamp) {
      initialDateTime = rawDate.toDate();
    } else if (rawDate is DateTime) {
      initialDateTime = rawDate;
    } else if (rawDate is String) {
      initialDateTime = DateTime.tryParse(rawDate) ?? initialDateTime;
    }

    DateTime selectedDate = initialDateTime;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialDateTime);
    final messageController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateFormatted = DateFormat('EEEE dd MMMM', 'es').format(selectedDate);
            final timeFormatted = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 22, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text(
                              'Proponer Reprogramar',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 6),
                    Text(
                      'Sugiere una nueva fecha u hora para la cita en $placeName con $hostUserName.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Selector de Nueva Fecha y Hora
                    const Text(
                      'Nueva fecha y hora propuesta',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Selector de Fecha
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate.isBefore(DateTime.now()) ? DateTime.now() : selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (ctx, child) {
                                  return Theme(
                                    data: Theme.of(ctx).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.inputBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dateFormatted,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Selector de Hora
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                                builder: (ctx, child) {
                                  return Theme(
                                    data: Theme.of(ctx).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() => selectedTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.inputBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      timeFormatted,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Mensaje o motivo (opcional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Ej. Me encantaría ir, ¿te quedaría bien este nuevo horario?',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSending
                            ? null
                            : () async {
                                setModalState(() => isSending = true);
                                try {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) throw Exception('Debes iniciar sesión');

                                  String requesterName = user.displayName ?? 'Usuario';
                                  String requesterPhoto = user.photoURL ?? '';

                                  try {
                                    final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                    if (uDoc.exists) {
                                      final uData = uDoc.data();
                                      if (uData != null) {
                                        if (uData['name'] != null && (uData['name'] as String).isNotEmpty) {
                                          requesterName = uData['name'];
                                        }
                                        final pList = (uData['photoUrls'] as List?) ?? (uData['photos'] as List?);
                                        if (pList != null && pList.isNotEmpty) {
                                          final first = pList[0]?.toString() ?? '';
                                          if (first.isNotEmpty) requesterPhoto = first;
                                        }
                                      }
                                    }
                                  } catch (_) {}

                                  final proposedDt = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  );

                                  final msg = messageController.text.trim();
                                  final now = Timestamp.now();
                                  final proposedStr = '${DateFormat('EEE dd MMM', 'es').format(proposedDt)} a las $timeFormatted';

                                  await FirebaseFirestore.instance.collection('reservation_requests').add({
                                    'reservationId': reservationId,
                                    'hostUserId': hostUserId,
                                    'requesterUserId': user.uid,
                                    'requesterName': requesterName,
                                    'requesterPhoto': requesterPhoto,
                                    'placeName': placeName,
                                    'dateTime': reservationData['dateTime'],
                                    'proposedDateTime': Timestamp.fromDate(proposedDt),
                                    'planType': reservationData['planType'] ?? 'Comida',
                                    'paymentType': reservationData['paymentType'] ?? '',
                                    'status': 'pending',
                                    'requestType': 'reschedule',
                                    'message': msg.isNotEmpty ? msg : 'Propuesta de reprogramación para $proposedStr',
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'interactionHistory': [
                                      {
                                        'type': 'created',
                                        'title': 'Reserva publicada',
                                        'description': '$hostUserName publicó esta reserva en el mapa.',
                                        'timestamp': reservationData['createdAt'] ?? now,
                                      },
                                      {
                                        'type': 'reschedule_proposed',
                                        'title': 'Propuesta de reprogramación',
                                        'description': msg.isNotEmpty
                                            ? '$requesterName propuso reprogramar para $proposedStr: "$msg"'
                                            : '$requesterName propuso reprogramar la cita para $proposedStr.',
                                        'timestamp': now,
                                      },
                                    ],
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('¡Propuesta enviada a $hostUserName para el $proposedStr! 🗓️✨'),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSending = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              },
                        icon: isSending
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Enviar Propuesta',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16181F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Set<Marker> get _combinedMarkers {
    return Set<Marker>.from(_markers);
  }

  Set<Polygon> _buildPolygons() {
    final Set<Polygon> polygons = {};
    final normPreferred = _preferredZones.map(ZoneData.normalizeZoneName).toSet();

    for (var entry in ZoneData.polygons.entries) {
      final zoneName = entry.key;
      if (normPreferred.contains(ZoneData.normalizeZoneName(zoneName))) {
        polygons.add(
          Polygon(
            polygonId: PolygonId(zoneName),
            points: entry.value,
            fillColor: Colors.transparent,
            strokeColor: Colors.black,
            strokeWidth: 2,
            consumeTapEvents: false,
          ),
        );
      }
    }
    return polygons;
  }

  static const String _cleanMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{ "color": "#f5f6f8" }]
    },
    {
      "elementType": "labels.icon",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [{ "color": "#5b616c" }]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [{ "color": "#ffffff" }, { "weight": 2 }]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "administrative.neighborhood",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "administrative.land_parcel",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "poi",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{ "color": "#f5f6f8" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{ "color": "#ffffff" }]
    },
    {
      "featureType": "road",
      "elementType": "labels.icon",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "road.arterial",
      "elementType": "labels",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "road.local",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "transit",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [{ "color": "#cdd1d8" }]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry",
      "stylers": [
        { "color": "#cdd1d8" },
        { "visibility": "on" }
      ]
    },
    {
      "featureType": "landscape.natural",
      "elementType": "geometry",
      "stylers": [
        { "color": "#f5f6f8" },
        { "visibility": "on" }
      ]
    },
    {
      "featureType": "landscape.natural.terrain",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{ "color": "#e2e6ea" }]
    }
  ]
  ''';


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topOffset = topPadding > 0 ? topPadding : 16.0;

    return Scaffold(
      primary: false,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vista 1: Mapa (mantenido con Offstage para no destruir el iframe de Google Maps ni reiniciar texturas)
          Positioned.fill(
            child: Offstage(
              offstage: _showPeopleDiscovery,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 11.8),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                indoorViewEnabled: false,
                trafficEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                style: _cleanMapStyle,
                markers: _combinedMarkers,
                circles: const {},
                polygons: _buildPolygons(),
                onCameraMove: (CameraPosition pos) {
                  _lastCameraPosition = pos.target;
                },
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
            ),
          ),
          // Vista 2: Descubrir Personas Estilo Tinder
          if (_showPeopleDiscovery)
            Positioned.fill(
              top: topOffset + 66,
              bottom: 95,
              child: TinderSwipeView(
                onSwitchToMap: () => setState(() => _showPeopleDiscovery = false),
              ),
            ),

          // Selector superior flotante ("Reservas en Mapa" / "Descubrir Personas")
          Positioned(
            top: topOffset + 8,
            left: 20,
            right: 20,
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => _showPeopleDiscovery = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: !_showPeopleDiscovery ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 16, color: !_showPeopleDiscovery ? Colors.white : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Reservas en Mapa',
                              style: TextStyle(
                                color: !_showPeopleDiscovery ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => _showPeopleDiscovery = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _showPeopleDiscovery ? Colors.pinkAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_fire_department, size: 16, color: _showPeopleDiscovery ? Colors.white : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Descubrir Personas',
                              style: TextStyle(
                                color: _showPeopleDiscovery ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controles flotantes en la vista de Mapa
          if (!_showPeopleDiscovery) ...[
            // Botón flotante "Hacer reserva" ubicado al lado derecho encima del carrusel de citas
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              bottom: _selectedReservation != null ? 236 : 102,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublishReservationPage(
                          onPublished: (loc) {
                            if (loc != null) {
                              moveToLocation(LatLng(loc.latitude, loc.longitude));
                            }
                            _listenToReservations();
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Hacer reserva',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Ventana flotante de la reserva seleccionada (arriba de la barra del menú central)
            if (_selectedReservation != null)
              Positioned(
                bottom: 102,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -100) {
                        _goToNextReservation();
                      } else if (details.primaryVelocity! > 100) {
                        _goToPrevReservation();
                      }
                    }
                  },
                  onTap: () {
                    _openReservationDetails(_selectedReservation!);
                  },
                  child: Container(
                    height: 122,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          // Foto del restaurante/lugar
                          SizedBox(
                            width: 105,
                            height: 122,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  _selectedReservation!.restaurantPhoto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.network(
                                    _resolveRestaurantPhoto({}, _selectedReservation!.planType, _selectedReservation!.id),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF2C3437),
                                      child: const Icon(Icons.restaurant, color: Colors.white70, size: 30),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _getPlanIcon(_selectedReservation!.planType),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Contenido info reserva
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Fila 1: Nombre del lugar + Flechas entre citas + Botón cerrar (X)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedReservation!.placeName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Flechas para desplazarse entre citas
                                      if (_reservationsList.length > 1) ...[
                                        Container(
                                          height: 27,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F3F5),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: _goToPrevReservation,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                  child: Icon(Icons.chevron_left_rounded, size: 19, color: Color(0xFF1E242B)),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                                child: Text(
                                                  '${_selectedReservationIndex + 1}/${_reservationsList.length}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF2C3437),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _goToNextReservation,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                                  child: Icon(Icons.chevron_right_rounded, size: 19, color: Color(0xFF1E242B)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      // Botón cerrar (X)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedReservation = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 15, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Fila 2: Plan + Fecha y Hora completa (ocupa todo el ancho, nunca se corta con ...)
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 13, color: AppColors.primary.withOpacity(0.9)),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: RichText(
                                          maxLines: 1,
                                          overflow: TextOverflow.visible,
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _selectedReservation!.planType,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E242B),
                                                ),
                                              ),
                                              const TextSpan(
                                                text: ' • ',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              TextSpan(
                                                text: _selectedReservation!.formattedDate,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4B5563),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Fila inferior: Host avatar, nombre y botón "Ver cita"
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundImage: _selectedReservation!.hostPhoto.isNotEmpty
                                            ? NetworkImage(_selectedReservation!.hostPhoto)
                                            : null,
                                        backgroundColor: Colors.grey[300],
                                        child: _selectedReservation!.hostPhoto.isEmpty
                                            ? const Icon(Icons.person, size: 14, color: Colors.white)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedReservation!.hostName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          _openReservationDetails(_selectedReservation!);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Text(
                                            'Ver cita',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // Onboarding / Tutorial estático del mapa
          if (_showMapTutorial)
            MapTutorialOverlay(
              onDismiss: () {
                setState(() {
                  _showMapTutorial = false;
                  _hasDismissedTutorialLocally = true;
                });
                MapTutorialOverlay.markAsSeen();
              },
            ),
        ],
      ),
    );
  }
}
