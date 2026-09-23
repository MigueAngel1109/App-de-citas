import 'dart:async';
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
          setState(() {
            _markerCache.clear(); // Limpiar caché para re-dibujar marcadores con fotos frescas
            if (snap.exists && snap.data() != null) {
              final data = snap.data()!;
              if (data['preferredZones'] != null && data['preferredZones'] is List) {
                _preferredZones.clear();
                _preferredZones.addAll((data['preferredZones'] as List).map((e) => e.toString()));
              }
              if (data['hasSeenMapTutorial'] != true && !_hasDismissedTutorialLocally) {
                _showMapTutorial = true;
              }
            }
          });
        _listenToReservations(); // Refrescar marcadores en el mapa con las fotos actualizadas
      }
    });
  }

  void moveToLocation(LatLng position) {
    _currentPosition = position;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15.0),
    );
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
      return DateFormat('EEEE dd MMM • HH:mm', 'es').format(dateTime);
    } catch (_) {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$day/$month/${dateTime.year} • $hour:$minute';
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

  String _resolveRestaurantPhoto(Map<String, dynamic> data, String planType, String seed) {
    if (data['placePhoto'] != null && (data['placePhoto'] as String).isNotEmpty) {
      return data['placePhoto'];
    }
    if (data['restaurantPhoto'] != null && (data['restaurantPhoto'] as String).isNotEmpty) {
      return data['restaurantPhoto'];
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

          final restaurantPhoto = _resolveRestaurantPhoto(data, planType, doc.id);

          newReservationsList.add(
            ReservationMapItem(
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
            ),
          );

          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: latLng,
              icon: icon,
              infoWindow: InfoWindow(
                title: '$userName • $placeName',
                snippet: '$planType • $dateStr',
                onTap: () {
                  _openReservationCarousel(initialDocId: doc.id);
                },
              ),
              onTap: () {
                _openReservationCarousel(initialDocId: doc.id);
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
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to reservations: $e');
    });
  }

  void _openReservationCarousel({String? initialDocId}) {
    if (_reservationsList.isEmpty) return;

    int initialIndex = 0;
    if (initialDocId != null) {
      final idx = _reservationsList.indexWhere((r) => r.id == initialDocId);
      if (idx != -1) initialIndex = idx;
    }

    // Centrar suavemente el mapa en la reserva inicial
    final initialItem = _reservationsList[initialIndex];
    _mapController?.animateCamera(CameraUpdate.newLatLng(initialItem.latLng));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final PageController pageController = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final total = _reservationsList.length;
            final current = _reservationsList[currentIndex];

            return Container(
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tirador superior de arrastre
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cabecera: Badge "RESERVA X DE N" a la izquierda y paginación a la derecha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge: [ 🍸 RESERVA 1 DE 8 ]
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF2F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getPlanIcon(current.planType), style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              'RESERVA ${currentIndex + 1} DE $total',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2C3437),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Paginación: < [— · ·] >
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Flecha izquierda
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            splashRadius: 16,
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              size: 24,
                              color: currentIndex > 0 ? const Color(0xFF1E242B) : Colors.grey.shade300,
                            ),
                            onPressed: currentIndex > 0
                                ? () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(width: 4),

                          // Puntos animados
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              total > 7 ? 7 : total,
                              (dotIdx) {
                                final bool isActive = (dotIdx == currentIndex) || (dotIdx == 6 && currentIndex >= 6);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  width: isActive ? 16 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFF1A1F24) : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Flecha derecha
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            splashRadius: 16,
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              size: 24,
                              color: currentIndex < total - 1 ? const Color(0xFF1E242B) : Colors.grey.shade300,
                            ),
                            onPressed: currentIndex < total - 1
                                ? () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Carrusel deslizable PageView
                  SizedBox(
                    height: 385,
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: total,
                      onPageChanged: (newIdx) {
                        setModalState(() {
                          currentIndex = newIdx;
                        });
                        final item = _reservationsList[newIdx];
                        // Sincronizar el mapa en vivo hacia la reserva deslizada
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(item.latLng),
                        );
                      },
                      itemBuilder: (context, idx) {
                        final res = _reservationsList[idx];
                        return _buildReservationCardContent(context, res);
                      },
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
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 175,
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
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF262C36),
                      child: const Center(
                        child: Icon(Icons.restaurant, color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
                ),

                // Degradado inferior
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
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
                          Icon(Icons.search, size: 13, color: Colors.white),
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

                // Pill Superior Derecha: Tipo de Plan (Ej: "Cena & Tragos 🍸")
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      '${res.planType} ${_getPlanIcon(res.planType)}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Pill Inferior Izquierda: Instagram tag o enlace
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              color: Color(0xFF161A1D),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // 3. Ubicación y Fecha / Hora
          Row(
            children: [
              const Icon(Icons.place, size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                res.locationText,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.access_time_filled, size: 15, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                res.formattedDate,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. Tarjeta del Anfitrión (Estilo Mateo, 28)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pop(context);
              if (isMine) {
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
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                        RichText(
                          text: TextSpan(
                            children: [
                              const TextSpan(
                                text: 'ANFITRIÓN: ',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              TextSpan(
                                text: res.hostAge != null ? '${res.hostName}, ${res.hostAge}' : res.hostName,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          res.hostBio.isNotEmpty
                              ? res.hostBio
                              : (res.details.isNotEmpty ? res.details : 'Toca para ver el perfil completo.'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 5. Botón Principal: "Solicitar unirme a [Nombre]"
          if (isMine)
            SizedBox(
              width: double.infinity,
              height: 50,
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
                final reqStatus = hasRequested
                    ? (reqSnap.data!.docs.first.data() as Map<String, dynamic>)['status'] ?? 'pending'
                    : null;

                if (hasRequested) {
                  final isAccepted = reqStatus == 'accepted';
                  return Container(
                    width: double.infinity,
                    height: 50,
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
                          isAccepted ? Icons.check_circle : Icons.hourglass_top,
                          color: isAccepted ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAccepted ? '¡Solicitud Aceptada! (Hay Match 🎉)' : 'Solicitud enviada (Pendiente ⏳)',
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

                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _openRequestJoinDialog(res.id, res.data, res.hostUserId, res.hostName, res.placeName);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16181F),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Solicitar unirme a ${res.hostName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
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


  Set<Marker> get _combinedMarkers {
    return Set<Marker>.from(_markers);
  }

  Set<Circle> get _mapCircles {
    final Set<Circle> circles = {};
    for (String zone in _preferredZones) {
      if (ZoneData.zoneCircles.containsKey(zone)) {
        final data = ZoneData.zoneCircles[zone]!;
        circles.add(
          Circle(
            circleId: CircleId(zone),
            center: data['center'],
            radius: data['radius'],
            fillColor: AppColors.primary.withOpacity(0.15),
            strokeColor: AppColors.primary,
            strokeWidth: 2,
          ),
        );
      }
    }
    return circles;
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
      "stylers": [{ "color": "#7a7f87" }]
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
      "featureType": "poi.business",
      "stylers": [{ "visibility": "off" }]
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
      "stylers": [
        { "saturation": -100 },
        { "lightness": 12 }
      ]
    },
    {
      "featureType": "landscape.man_made",
      "stylers": [{ "visibility": "off" }]
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
            fillColor: AppColors.primary.withOpacity(0.15),
            strokeColor: AppColors.primary.withOpacity(0.5),
            strokeWidth: 2,
            consumeTapEvents: false, // Make sure they don't block marker taps
          ),
        );
      }
    }
    return polygons;
  }

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
          if (!_showPeopleDiscovery) ...[
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14.0),
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
                circles: _mapCircles,
                polygons: _buildPolygons(),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
            ),
          ] else ...[
            // Vista 2: Descubrir Personas Estilo Tinder
            Positioned.fill(
              top: topOffset + 66,
              bottom: 95,
              child: TinderSwipeView(
                onSwitchToMap: () => setState(() => _showPeopleDiscovery = false),
              ),
            ),
          ],

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
