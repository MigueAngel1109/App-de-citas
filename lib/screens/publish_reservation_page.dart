import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../utils/secrets.dart';
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

  final List<String> _planTypes = ['Comida/Cena', 'Tragos', 'Café/Brunch'];
  final List<String> _paymentTypes = ['Yo invito', 'Cuentas separadas', 'Abierto a discutir'];

  @override
  void dispose() {
    _linkController.dispose();
    _detailsController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<List<PlaceAutocomplete>> _searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    // 1. En plataformas móviles nativas (Android/iOS) con Google Places
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

    // 2. En Web o fallback multiplataforma libre de CORS (Photon - OpenStreetMap)
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
            if (name.isEmpty) continue;

            final street = props['street'] as String? ?? '';
            final city = props['city'] as String? ?? props['locality'] as String? ?? 'Bogotá';
            final country = props['country'] as String? ?? 'Colombia';

            final descParts = [name, if (street.isNotEmpty) street, city, country];
            final description = descParts.join(', ');

            GeoPoint? point;
            if (geom != null && geom['coordinates'] is List) {
              final coords = geom['coordinates'] as List;
              if (coords.length >= 2) {
                final lng = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();
                point = GeoPoint(lat, lng);
              }
            }

            results.add(PlaceAutocomplete(
              description: description,
              placeId: props['osm_id']?.toString() ?? '',
              location: point,
            ));
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('Photon search error: $e');
    }

    // 3. Fallback con Nominatim OpenStreetMap
    try {
      final nominatimUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&countrycodes=co&limit=5',
      );
      final response = await http.get(nominatimUrl, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List data = json.decode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          return data.map((p) {
            final lat = double.tryParse(p['lat'].toString()) ?? 4.6097;
            final lon = double.tryParse(p['lon'].toString()) ?? -74.0817;
            return PlaceAutocomplete(
              description: p['display_name'] as String,
              placeId: p['place_id'].toString(),
              location: GeoPoint(lat, lon),
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    }

    return [];
  }

  Future<void> _getPlaceDetails(String placeId) async {
    if (googleMapsApiKey == 'TU_API_KEY_AQUI' || placeId.isEmpty) return;
    setState(() => _isFetchingPlace = true);
    final url = Uri.parse('https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$googleMapsApiKey');
    try {
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
      Position position = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 5));
      setState(() {
        _selectedLocation = GeoPoint(position.latitude, position.longitude);
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = 'Mi ubicación actual (Bogotá)';
        }
        _isFetchingPlace = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Ubicación actual fijada correctamente'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        // Fallback a coordenadas de Bogotá centro
        _selectedLocation = const GeoPoint(4.6097, -74.0817);
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = 'Bogotá Centro';
        }
        _isFetchingPlace = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Se fijó la ubicación central de Bogotá'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indica el nombre del restaurante o lugar')));
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona la fecha y la hora')));
      return;
    }
    
    // Si aún no se fijaron coordenadas, intentar resolverlas automáticamente
    if (_selectedLocation == null) {
      setState(() => _isPublishing = true);
      try {
        final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 3));
        _selectedLocation = GeoPoint(pos.latitude, pos.longitude);
      } catch (_) {
        _selectedLocation = const GeoPoint(4.6097, -74.0817);
      }
    }

    final dateTime = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    setState(() => _isPublishing = true);

    try {
      // Obtener datos del perfil del usuario para persistirlos en la reserva
      String hostName = user.displayName ?? '';
      String hostPhoto = user.photoURL ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final uData = userDoc.data();
          if (uData != null) {
            if (uData['name'] != null && (uData['name'] as String).isNotEmpty) {
              hostName = uData['name'];
            }
            final pList = (uData['photoUrls'] as List?) ?? (uData['photos'] as List?);
            if (pList != null && pList.isNotEmpty) {
              final first = pList[0]?.toString() ?? '';
              if (first.isNotEmpty) hostPhoto = first;
            }
          }
        }
      } catch (_) {}

      final savedLocation = _selectedLocation;

      await FirebaseFirestore.instance.collection('reservations').add({
        'userId': user.uid,
        'userName': hostName.isNotEmpty ? hostName : 'Alguien',
        'userPhoto': hostPhoto,
        'link': _linkController.text.trim(),
        'placeName': _placeController.text.trim(),
        'location': savedLocation,
        'dateTime': Timestamp.fromDate(dateTime),
        'planType': _selectedPlan,
        'paymentType': _selectedPayment,
        'details': _detailsController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isPublishing = false);
      if (widget.onPublished != null) {
        // Limpiar el formulario si se publicó con éxito
        _linkController.clear();
        _detailsController.clear();
        _placeController.clear();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Publicar Reserva', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Enlace de confirmación
                _buildSectionTitle('1. Enlace de confirmación', 'Valida tu mesa pegando el enlace de Resy u OpenTable.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _linkController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration(hint: 'https://', icon: Icons.link),
                ),
                
                const SizedBox(height: 32),

                // 2. Lugar de la cita
                _buildSectionTitle('2. Lugar de la cita', 'Busca el restaurante o bar en Google Maps.'),
                const SizedBox(height: 12),
                Autocomplete<PlaceAutocomplete>(
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.length < 2) return const Iterable<PlaceAutocomplete>.empty();
                    return await _searchPlaces(textEditingValue.text);
                  },
                  displayStringForOption: (PlaceAutocomplete option) => option.description,
                  onSelected: (PlaceAutocomplete selection) {
                    _placeController.text = selection.description;
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
                      decoration: _inputDecoration(hint: 'Ej: Andrés D.C. Bogotá', icon: Icons.place),
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
                      color: Colors.green.withOpacity(0.1),
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
                    label: const Text('Fijar con mi ubicación actual', style: TextStyle(fontSize: 13, color: AppColors.primary)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // 3. Fecha y Hora
                _buildSectionTitle('3. Fecha y Hora', '¿Cuándo es la cita?'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate == null ? 'Fecha' : DateFormat('dd MMM yyyy').format(_selectedDate!),
                                style: TextStyle(color: _selectedDate == null ? AppColors.textLight : AppColors.textPrimary, fontSize: 16),
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
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime == null ? 'Hora' : _selectedTime!.format(context),
                                style: TextStyle(color: _selectedTime == null ? AppColors.textLight : AppColors.textPrimary, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 4. Tipo de plan
                _buildSectionTitle('4. Tipo de plan', '¿Cuál es la vibra de la cita?'),
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

                const SizedBox(height: 32),

                // 5. Modalidad de pago
                _buildSectionTitle('5. Modalidad de pago', 'Establece las expectativas desde el principio.'),
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

                const SizedBox(height: 32),

                // 6. Detalles adicionales
                _buildSectionTitle('6. Detalles adicionales', 'Añade contexto sobre lo que buscas o el lugar.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _detailsController,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration(hint: 'Detalle sobre la cita...'),
                ),
              ],
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.95),
                border: const Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isPublishing ? null : _publishReservation,
                  icon: _isPublishing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    _isPublishing ? 'Publicando...' : 'Publicar Cita en el Mapa de Bogotá',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textLight) : null,
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14),
        ),
      ),
    );
  }
}
