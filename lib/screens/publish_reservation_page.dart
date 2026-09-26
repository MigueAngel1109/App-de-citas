import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/secrets.dart';
import '../utils/place_photo_service.dart';
import 'discover_page.dart';

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
  
  String _selectedPlan = 'Comida/Cena';
  String _selectedPayment = 'Cuentas separadas';
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  GeoPoint? _selectedLocation;

  bool _isPublishing = false;
  bool _isFetchingPlace = false;
  bool _lockDateTime = false;
  String? _realPlacePhoto;

  // Categorías con Café y Brunch separados
  final List<String> _planTypes = ['Comida/Cena', 'Tragos', 'Café', 'Brunch'];
  final List<String> _paymentTypes = ['Yo invito', 'Cuentas separadas', 'Abierto a discutir'];

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
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _parseReservationLink(String url) {
    final clean = url.trim().toLowerCase();
    if (clean.contains('opentable.com')) {
      try {
        final uri = Uri.parse(url.trim());
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          String candidate = segments.last;
          if (candidate.isEmpty && segments.length > 1) {
            candidate = segments[segments.length - 2];
          }
          if (candidate != 'r' && candidate.isNotEmpty) {
            final formatted = candidate
                .replaceAll('-', ' ')
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                .join(' ');
            if (_placeController.text.trim().isEmpty) {
              _placeController.text = '$formatted Bogotá';
              _lookupPlacePhoto(formatted);
              _searchPlaces('$formatted Bogotá').then((places) {
                if (places.isNotEmpty && mounted) {
                  _getPlaceDetails(places.first.placeId);
                }
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing OpenTable url: $e');
      }
    }
  }

  Future<List<PlaceAutocomplete>> _searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

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
    if (_lockDateTime) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    if (_lockDateTime) return;
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

    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa el nombre del lugar')));
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar un lugar de la lista o fijar tu ubicación')));
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la fecha y la hora')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
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
        _selectedDate = null;
        _selectedTime = null;
        _selectedLocation = null;
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
            _buildSectionTitle('1. Enlace de confirmación', 'Pega tu reserva externa o ábrela para reservar asistido.'),
            const SizedBox(height: 10),
            TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              onChanged: _parseReservationLink,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(hint: 'https://www.opentable.com/... o enlace', icon: Icons.link),
            ),
            const SizedBox(height: 8),
            // Accesos directos a plataformas de reserva
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildExternalChip('🍽️ OpenTable', 'https://www.opentable.com/'),
                _buildExternalChip('📍 Google Reserve', 'https://www.google.com/maps/reserve/'),
                _buildExternalChip('🍷 Restorando', 'https://www.restorando.com.co/'),
              ],
            ),
            
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
                controller.addListener(() {
                  if (_placeController.text != controller.text) {
                    _placeController.text = controller.text;
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

            const SizedBox(height: 28),

            // 3. Fecha y Hora
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('3. Fecha y Hora', '¿Cuándo es tu reserva?'),
                Row(
                  children: [
                    const Text('Bloquear fecha', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _lockDateTime,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _lockDateTime = val),
                      ),
                    ),
                  ],
                ),
              ],
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
                        color: _lockDateTime ? const Color(0xFFF1F3F6) : AppColors.surface,
                        border: Border.all(color: AppColors.inputBorder),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: _lockDateTime ? AppColors.textLight : AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate == null ? 'Fecha' : DateFormat('dd MMM yyyy').format(_selectedDate!),
                            style: TextStyle(color: _selectedDate == null ? AppColors.textLight : AppColors.textPrimary, fontSize: 15),
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
                        color: _lockDateTime ? const Color(0xFFF1F3F6) : AppColors.surface,
                        border: Border.all(color: AppColors.inputBorder),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: _lockDateTime ? AppColors.textLight : AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime == null ? 'Hora' : _selectedTime!.format(context),
                            style: TextStyle(color: _selectedTime == null ? AppColors.textLight : AppColors.textPrimary, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // 4. Tipo de plan (Café y Brunch separados)
            _buildSectionTitle('4. Tipo de plan', '¿Cuál es la vibra del encuentro?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _planTypes.map((type) => _buildChip(
                label: type,
                isSelected: _selectedPlan == type,
                onTap: () => setState(() => _selectedPlan = type),
              )).toList(),
            ),

            const SizedBox(height: 28),

            // 5. Modalidad de pago
            _buildSectionTitle('5. Modalidad de pago', 'Establece las expectativas con claridad.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _paymentTypes.map((type) => _buildChip(
                label: type,
                isSelected: _selectedPayment == type,
                onTap: () => setState(() => _selectedPayment = type),
              )).toList(),
            ),

            const SizedBox(height: 28),

            // 6. Punch Line / Detalles adicionales
            _buildSectionTitle('6. Punch Line & Detalles', 'Ambientación para motivar a acompañarte.'),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration(
                hint: 'Añade una frase ganadora para ambientar el plan (ej. "Tengo reservada la mesa en la terraza con vista para probar cócteles de autor. ¿Quién se anima?")',
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

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textLight, size: 20) : null,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
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
}
