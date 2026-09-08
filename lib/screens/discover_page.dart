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
  bool _isLoadingLocation = true;
  bool _showPeopleDiscovery = false;

  // Icono del punto azul para la ubicación actual
  BitmapDescriptor? _blueDotIcon;

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
    super.dispose();
  }

  Future<void> _initBlueDot() async {
    try {
      final icon = await createCurrentLocationMarkerBitmap();
      if (mounted) {
        setState(() {
          _blueDotIcon = icon;
        });
      }
    } catch (e) {
      debugPrint('Error init blue dot: $e');
    }
  }

  void _listenToCurrentUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _markerCache.clear(); // Limpiar caché para re-dibujar marcadores con fotos frescas
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

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoadingLocation = false);
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14.0));
      }

      // Escuchar actualizaciones de posición en vivo para mantener el punto azul siempre al día
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    } catch(e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _listenToReservations() {
    _reservationsSub?.cancel();
    _reservationsSub = FirebaseFirestore.instance.collection('reservations').snapshots().listen((snapshot) async {
      final Set<Marker> newMarkers = {};
      final Map<String, Map<String, dynamic>?> userDocsCache = {};
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final latLng = _parseLocation(data['location'], data['latitude'], data['longitude']);
          if (latLng == null) continue;

          final userId = data['userId'] as String?;
          String userName = (data['userName'] != null && (data['userName'] as String).isNotEmpty)
              ? data['userName']
              : 'Alguien';
          String photoUrl = data['userPhoto'] ?? '';
          
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
          final dateStr = _formatReservationDate(data['dateTime']);

          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: latLng,
              icon: icon,
              infoWindow: InfoWindow(
                title: '$userName • $placeName',
                snippet: '$planType • $dateStr',
                onTap: () {
                  _showReservationDetails(doc.id, data, userName, photoUrl);
                },
              ),
              onTap: () {
                _showReservationDetails(doc.id, data, userName, photoUrl);
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
        });
      }
    }, onError: (e) {
      debugPrint('Error listening to reservations: $e');
    });
  }

  void _showReservationDetails(String reservationId, Map<String, dynamic> data, String userName, String photoUrl) {
    final placeName = data['placeName'] ?? 'Restaurante';
    final planType = data['planType'] ?? 'Comida';
    final paymentType = data['paymentType'] ?? '';
    final details = data['details'] ?? '';
    final link = data['link'] ?? '';
    final dateStr = _formatReservationDate(data['dateTime']);

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final hostUserId = data['userId'] as String? ?? '';
    final bool isMyReservation = (currentUserId.isNotEmpty && currentUserId == hostUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Foto y Nombre con acción interactiva para ver perfil
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.pop(context); // Cierra bottom sheet
                  if (isMyReservation) {
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
                    if (hostUserId.isNotEmpty) {
                      UserProfileModal.show(context, userId: hostUserId, name: userName, photo: photoUrl);
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.surface,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        onBackgroundImageError: photoUrl.isNotEmpty ? (_, __) {} : null,
                        child: photoUrl.isEmpty ? const Icon(Icons.person, size: 40, color: AppColors.textLight) : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isMyReservation ? 'Toca para ver o editar tu perfil' : 'Toca para ver el perfil de $userName',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isMyReservation) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_pin, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Esta es tu cita publicada 📌',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Info de la cita
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.place, placeName),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.calendar_month, dateStr),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.celebration, paymentType.isNotEmpty ? '$planType • $paymentType' : planType),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.info_outline, details),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),

              // Botón de Enlace (Resy/OpenTable)
              if (link.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final uri = Uri.parse(link.startsWith('http') ? link : 'https://$link');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Error launching URL: $e');
                    }
                  },
                  icon: const Icon(Icons.link, color: AppColors.primary),
                  label: const Text('Ver reserva original', style: TextStyle(color: AppColors.primary, fontSize: 16)),
                ),

              const SizedBox(height: 16),

              // Botón Primario: Unirme (o Aviso si es cita propia)
              if (isMyReservation)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Center(
                    child: Text(
                      'No puedes solicitar unirte a tu propia cita',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: currentUserId.isNotEmpty
                      ? FirebaseFirestore.instance
                          .collection('reservation_requests')
                          .where('reservationId', isEqualTo: reservationId)
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isAccepted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isAccepted ? const Color(0xFF2E7D32).withOpacity(0.3) : const Color(0xFFE65100).withOpacity(0.3),
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
                              isAccepted ? '¡Solicitud Aceptada! (Hay Match 🎉)' : 'Solicitud ya enviada (Pendiente ⏳)',
                              style: TextStyle(
                                color: isAccepted ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openRequestJoinDialog(reservationId, data, hostUserId, userName, placeName);
                        },
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: const Text('Solicitar unirme', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 12),

              // Botón Secundario: Ver Perfil del creador (o Cerrar si es propia)
              if (!isMyReservation)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (hostUserId.isNotEmpty) {
                        UserProfileModal.show(context, userId: hostUserId, name: userName, photo: photoUrl);
                      }
                    },
                    icon: const Icon(Icons.account_circle_outlined, color: AppColors.primary, size: 20),
                    label: Text('Ver Perfil de $userName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: const Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
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
                        'Solicitar unirte a la cita',
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
                                      'title': 'Cita publicada',
                                      'description': '$hostUserName publicó esta cita en el mapa.',
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16))),
      ],
    );
  }

  Set<Marker> get _combinedMarkers {
    final markers = Set<Marker>.from(_markers);
    if (_blueDotIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_current_location_dot'),
          position: _currentPosition,
          icon: _blueDotIcon!,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 999.0,
          infoWindow: const InfoWindow(
            title: 'Tu ubicación actual',
            snippet: 'Aquí te encuentras ahora mismo',
          ),
        ),
      );
    }
    return markers;
  }

  Set<Circle> get _mapCircles {
    return {
      Circle(
        circleId: const CircleId('current_location_accuracy_halo'),
        center: _currentPosition,
        radius: 35,
        fillColor: const Color(0x181A73E8),
        strokeColor: const Color(0x441A73E8),
        strokeWidth: 1,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Vista 1: Mapa de Google con Citas
          if (!_showPeopleDiscovery) ...[
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14.0),
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _combinedMarkers,
              circles: _mapCircles,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
            
            // Badge indicador de citas activas
            Positioned(
              top: 106,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.celebration, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_markers.length} ${_markers.length == 1 ? "cita activa" : "citas activas"}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón personalizado de ubicación superior derecho
            Positioned(
              top: 106,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'btnLocation',
                mini: true,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: AppColors.primary),
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14.0));
                },
              ),
            ),

            if (_isLoadingLocation)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Buscando tu ubicación...'),
                      ],
                    ),
                  ),
                ),
              ),
          ] else ...[
            // Vista 2: Descubrir Personas Estilo Tinder
            Positioned.fill(
              top: 102,
              child: TinderSwipeView(
                onSwitchToMap: () => setState(() => _showPeopleDiscovery = false),
              ),
            ),
          ],

          // Selector superior flotante ("Citas en Mapa" / "Descubrir Personas")
          Positioned(
            top: 48,
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
                              'Citas en Mapa',
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
        ],
      ),
    );
  }
}
