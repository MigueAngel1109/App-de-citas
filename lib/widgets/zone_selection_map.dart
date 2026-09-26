import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/zone_data.dart';

/// Mapa interactivo de selección de zonas de preferencia.
/// Mismo estilo visual limpio que el mapa de reservas, sin marcadores invasivos
/// y con una hoja modal de filtro desplegable para evitar conflictos de gestos con el mapa.
class ZoneSelectionMap extends StatefulWidget {
  final Set<String> initialSelectedZones;

  const ZoneSelectionMap({super.key, required this.initialSelectedZones});

  @override
  State<ZoneSelectionMap> createState() => _ZoneSelectionMapState();
}

class _ZoneSelectionMapState extends State<ZoneSelectionMap> {
  final Set<String> _selectedZones = {};
  GoogleMapController? _mapController;
  Map<String, LatLng> _centroids = {};

  static const List<Map<String, String>> _zoneInfoList = [
    {'name': 'Chapinero', 'desc': 'Zona Rosa, Zona G, Parque 93, Quinta Camacho'},
    {'name': 'Usaquén', 'desc': 'Santa Bárbara, Cedritos, Usaquén Histórico'},
    {'name': 'Teusaquillo', 'desc': 'Park Way, La Soledad, Galerías, Salitre'},
    {'name': 'Suba', 'desc': 'La Colina, Niza, Suba Centro'},
    {'name': 'Santa Fe', 'desc': 'La Macarena, Torres del Parque, Centro Internacional'},
    {'name': 'La Candelaria', 'desc': 'Centro Histórico, Chorro de Quevedo, Museos'},
    {'name': 'Barrios Unidos', 'desc': 'El Lago, Polo, 7 de Agosto, Alcázares'},
    {'name': 'Fontibón', 'desc': 'Ciudad Salitre Occidental, Modelia, Hayuelos'},
    {'name': 'Engativá', 'desc': 'Normandía, Álamos, Minuto de Dios, Boyacá Real'},
    {'name': 'Kennedy', 'desc': 'Américas, Castilla, Timiza, Plaza de las Américas'},
    {'name': 'Puente Aranda', 'desc': 'Ciudad Montes, Industrial Centenario'},
    {'name': 'Los Mártires', 'desc': 'Eduardo Santos, Santa Isabel, La Pepita'},
    {'name': 'Antonio Nariño', 'desc': 'Restrepo, Santander, Ciudad Berna'},
    {'name': 'San Cristóbal', 'desc': '20 de Julio, Suroriente, San Blas'},
    {'name': 'Usme', 'desc': 'Usme Pueblo, La Flora, Santa Librada'},
    {'name': 'Tunjuelito', 'desc': 'Venecia, San Vicente, Tunal'},
    {'name': 'Bosa', 'desc': 'Bosa Centro, El Recreo, Porvenir'},
    {'name': 'Rafael Uribe Uribe', 'desc': 'Quiroga, Olaya, Gustavo Restrepo'},
    {'name': 'Ciudad Bolívar', 'desc': 'TransMiCable, El Ensueño, Candelaria La Nueva'},
    {'name': 'Sumapaz', 'desc': 'Páramo de Sumapaz, Región rural'},
  ];

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
      "elementType": "geometry",
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
  void initState() {
    super.initState();
    _selectedZones.addAll(widget.initialSelectedZones);
    _calculateCentroids();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _calculateCentroids() {
    _centroids = {};
    for (final entry in ZoneData.polygons.entries) {
      if (entry.value.isEmpty) continue;
      double latSum = 0;
      double lngSum = 0;
      for (final p in entry.value) {
        latSum += p.latitude;
        lngSum += p.longitude;
      }
      _centroids[entry.key] = LatLng(
        latSum / entry.value.length,
        lngSum / entry.value.length,
      );
    }
  }

  void _toggleZone(String zoneName) {
    setState(() {
      if (_selectedZones.contains(zoneName)) {
        _selectedZones.remove(zoneName);
      } else {
        _selectedZones.add(zoneName);
      }
    });
  }

  void _focusOnZone(String zoneName) {
    final centroid = _centroids[zoneName];
    if (centroid != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(centroid, 12.8),
      );
    }
  }

  Set<Polygon> _buildPolygons() {
    final Set<Polygon> polygons = {};

    for (final entry in ZoneData.polygons.entries) {
      final zoneName = entry.key;
      final isSelected = _selectedZones.contains(zoneName);

      polygons.add(
        Polygon(
          polygonId: PolygonId(zoneName),
          points: entry.value,
          fillColor: isSelected
              ? AppColors.primary.withOpacity(0.24)
              : Colors.black.withOpacity(0.04),
          strokeColor: isSelected ? AppColors.primary : Colors.black45,
          strokeWidth: isSelected ? 3 : 1,
          consumeTapEvents: true,
          onTap: () => _toggleZone(zoneName),
        ),
      );
    }

    return polygons;
  }

  /// Despliega la hoja modal con el filtro y listado completo de zonas
  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filterQuery = '';
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final filtered = _zoneInfoList.where((loc) {
              final name = loc['name']!;
              final desc = loc['desc']!;
              final q = filterQuery.toLowerCase().trim();
              if (q.isEmpty) return true;
              return name.toLowerCase().contains(q) || desc.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Tirador superior
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Título y acciones rápidas
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          'Filtrar Zonas de Bogotá',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              setState(() {
                                if (_selectedZones.length == _zoneInfoList.length) {
                                  _selectedZones.clear();
                                } else {
                                  _selectedZones.addAll(_zoneInfoList.map((e) => e['name']!));
                                }
                              });
                            });
                          },
                          child: Text(
                            _selectedZones.length == _zoneInfoList.length ? 'Limpiar todas' : 'Elegir todas',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Barra de búsqueda dentro del filtro
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          filterQuery = val;
                        });
                      },
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar localidad o barrio (ej. Chapinero, 93)...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF3F5F8),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Lista vertical de localidades con checkboxes
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontró "$filterQuery"',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              final zoneName = item['name']!;
                              final zoneDesc = item['desc']!;
                              final isSelected = _selectedZones.contains(zoneName);

                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    _toggleZone(zoneName);
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                        color: isSelected ? AppColors.primary : AppColors.textLight,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              zoneName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              zoneDesc,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botón para volar el mapa a la zona
                                      IconButton(
                                        icon: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.textSecondary),
                                        tooltip: 'Ver en mapa',
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _focusOnZone(zoneName);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Botón Listo / Aplicar en el filtro
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Aplicar (${_selectedZones.length} seleccionadas)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final topOffset = topPadding > 0 ? topPadding : 16.0;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Google Map interactivo idéntico al mapa de reservas (sin puntos rojos invasivos)
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(4.6533, -74.0836),
              zoom: 11.5,
            ),
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
            polygons: _buildPolygons(),
            markers: const {}, // Puntos rojos eliminados
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),

          // 2. Barra Superior Flotante: Volver + Título + Botón de Filtro
          Positioned(
            top: topOffset + 10,
            left: 16,
            right: 16,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
                    onPressed: () => Navigator.pop(context, _selectedZones),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zonas de Preferencia',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Toca en el mapa o abre el filtro',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Botón que saca el filtro de zonas
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openFilterBottomSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Filtrar (${_selectedZones.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // 3. Panel Inferior Flotante de Confirmación
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedZones.length} ${_selectedZones.length == 1 ? "zona seleccionada" : "zonas seleccionadas"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          onTap: _openFilterBottomSheet,
                          child: const Text(
                            'Abrir lista de zonas ↗',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selectedZones),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Guardar Zonas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
