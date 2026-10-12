import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/zone_data.dart';

/// Modelo de ítem de zona para el selector jerárquico
class ZoneItem {
  final String id;
  final String title;
  final String subtitle;

  const ZoneItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

/// Selector de Zonas y Preferencias Geográficas
/// Layout de Pantalla Dividida (Split View):
/// - Mitad Superior: Mapa monocromático en escala de grises, sin etiquetas ni POIs, operado con 1 dedo y zoom fijo.
/// - Mitad Inferior: Lista deslizable con checkboxes organizados jerárquicamente:
///     * Bogotá D.C. (con toggle master "Seleccionar toda Bogotá" y expansión/colapso de zonas)
///     * Sabana Norte (Cota, Chía, Cajicá agrupadas)
///     * Sabana Occidente (Mosquera, Madrid agrupadas)
///     * Sur (Soacha)
/// - Pie de Página: Botón persistente 'Guardar' (sticky bottom button).
/// - Estilo visual de polígonos: Borde #4A4A4A y relleno translúcido suave al marcar la zona.
/// - Prevención de propagación de eventos táctiles con hitTestBehavior opaque.
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
  bool _bogotaExpanded = true;

  // Zonas operativas de Bogotá estructuradas y fusionadas (8 macrozonas operativas)
  static const List<ZoneItem> _bogotaZones = [
    ZoneItem(
      id: 'Chapinero Central',
      title: 'Chapinero Central',
      subtitle: 'Zona Rosa, Zona G, Parque 93, Quinta Camacho, Barrios Unidos',
    ),
    ZoneItem(
      id: 'Usaquén',
      title: 'Usaquén',
      subtitle: 'Santa Bárbara, Cedritos, Usaquén Histórico',
    ),
    ZoneItem(
      id: 'Galerías - Teusaquillo',
      title: 'Galerías - Teusaquillo',
      subtitle: 'Park Way, Galerías, Salitre, Puente Aranda, Antonio Nariño',
    ),
    ZoneItem(
      id: 'Centro Histórico',
      title: 'Centro Histórico',
      subtitle: 'La Candelaria, Santa Fe, La Macarena, Los Mártires',
    ),
    ZoneItem(
      id: 'Suba',
      title: 'Suba',
      subtitle: 'La Colina, Niza, Suba Centro',
    ),
    ZoneItem(
      id: 'Occidente (Engativá - Fontibón)',
      title: 'Occidente (Engativá - Fontibón)',
      subtitle: 'Normandía, Modelia, Salitre Occ., Hayuelos, Álamos',
    ),
    ZoneItem(
      id: 'Suroccidente (Kennedy - Bosa)',
      title: 'Suroccidente (Kennedy - Bosa)',
      subtitle: 'Américas, Castilla, Timiza, Bosa Centro, Porvenir',
    ),
    ZoneItem(
      id: 'Suroriente (Tunjuelito - San Cristóbal - Rafael Uribe)',
      title: 'Suroriente (Tunjuelito - San Cristóbal - Rafael Uribe)',
      subtitle: 'Venecia, Tunal, 20 de Julio, Quiroga, Olaya',
    ),
  ];

  // Municipios Aledaños agrupados por subregiones
  static const List<ZoneItem> _surroundingZones = [
    ZoneItem(
      id: 'Sabana Norte',
      title: 'Sabana Norte',
      subtitle: 'Chía • Cota • Cajicá',
    ),
    ZoneItem(
      id: 'Sabana Occidente',
      title: 'Sabana Occidente',
      subtitle: 'Mosquera • Madrid',
    ),
    ZoneItem(
      id: 'Sur (Soacha)',
      title: 'Sur',
      subtitle: 'Soacha',
    ),
  ];

  /// Estilo de mapa monocromático/escala de grises sin etiquetas de texto ni POIs
  static const String _monochromeMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [{ "color": "#f0f1f3" }]
    },
    {
      "elementType": "labels",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "elementType": "labels.icon",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "elementType": "labels.text",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "administrative",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "poi",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{ "color": "#ffffff" }]
    },
    {
      "featureType": "road",
      "elementType": "labels",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "transit",
      "stylers": [{ "visibility": "off" }]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [{ "color": "#e5e7eb" }]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{ "color": "#d5dbe1" }]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _migrateAndInitSelectedZones();
    _calculateCentroids();
  }

  /// Migra selecciones antiguas a las nuevas macrozonas y zonas operativas
  void _migrateAndInitSelectedZones() {
    for (final rawZone in widget.initialSelectedZones) {
      if (rawZone == 'Ciudad Bolívar' || rawZone == 'Usme' || rawZone == 'Sumapaz') {
        // Descartadas por la poda geográfica
        continue;
      }
      if (rawZone == 'Chapinero' || rawZone == 'Barrios Unidos') {
        _selectedZones.add('Chapinero Central');
      } else if (rawZone == 'Teusaquillo' || rawZone == 'Puente Aranda' || rawZone == 'Antonio Nariño') {
        _selectedZones.add('Galerías - Teusaquillo');
      } else if (rawZone == 'La Candelaria' || rawZone == 'Santa Fe' || rawZone == 'Los Mártires') {
        _selectedZones.add('Centro Histórico');
      } else if (rawZone == 'Fontibón' || rawZone == 'Engativá' || rawZone == 'Occidente (Engativá - Fontibón)') {
        _selectedZones.add('Occidente (Engativá - Fontibón)');
      } else if (rawZone == 'Kennedy' || rawZone == 'Bosa' || rawZone == 'Suroccidente (Kennedy - Bosa)') {
        _selectedZones.add('Suroccidente (Kennedy - Bosa)');
      } else if (rawZone == 'Tunjuelito' || rawZone == 'San Cristóbal' || rawZone == 'Rafael Uribe Uribe' || rawZone == 'Suroriente (Tunjuelito - San Cristóbal - Rafael Uribe)') {
        _selectedZones.add('Suroriente (Tunjuelito - San Cristóbal - Rafael Uribe)');
      } else if (rawZone == 'Chía' || rawZone == 'Cota' || rawZone == 'Cajicá') {
        _selectedZones.add('Sabana Norte');
      } else if (rawZone == 'Mosquera' || rawZone == 'Madrid') {
        _selectedZones.add('Sabana Occidente');
      } else if (rawZone == 'Soacha') {
        _selectedZones.add('Sur (Soacha)');
      } else {
        _selectedZones.add(rawZone);
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _calculateCentroids() {
    _centroids = {};
    for (final zoneItem in [..._bogotaZones, ..._surroundingZones]) {
      final polyLists = ZoneData.getPolygonsForZone(zoneItem.id);
      if (polyLists.isEmpty) continue;
      double latSum = 0;
      double lngSum = 0;
      int totalPoints = 0;
      for (final poly in polyLists) {
        for (final p in poly) {
          latSum += p.latitude;
          lngSum += p.longitude;
          totalPoints++;
        }
      }
      if (totalPoints > 0) {
        _centroids[zoneItem.id] = LatLng(latSum / totalPoints, lngSum / totalPoints);
      }
    }
  }

  bool get _isAllBogotaSelected {
    return _bogotaZones.every((z) => _selectedZones.contains(z.id));
  }

  void _toggleAllBogota() {
    setState(() {
      if (_isAllBogotaSelected) {
        for (final z in _bogotaZones) {
          _selectedZones.remove(z.id);
        }
      } else {
        for (final z in _bogotaZones) {
          _selectedZones.add(z.id);
        }
      }
    });
  }

  void _toggleZone(String zoneId) {
    setState(() {
      if (_selectedZones.contains(zoneId)) {
        _selectedZones.remove(zoneId);
      } else {
        _selectedZones.add(zoneId);
      }
    });
  }

  void _focusOnZone(String zoneId) {
    final centroid = _centroids[zoneId];
    if (centroid != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(centroid),
      );
    }
  }

  Set<Polygon> _buildPolygons() {
    final Set<Polygon> polygons = {};

    // Líneas de trazo en gris para definir claramente las divisiones de las zonas
    const activeBorder = Color(0xFF4B5563);   // Gris medio oscuro para zona seleccionada
    const inactiveBorder = Color(0xFF9CA3AF); // Gris medio neutro para ver la división

    for (final zoneItem in [..._bogotaZones, ..._surroundingZones]) {
      final isSelected = _selectedZones.contains(zoneItem.id);
      final polyLists = ZoneData.getPolygonsForZone(zoneItem.id);

      for (int i = 0; i < polyLists.length; i++) {
        final pts = polyLists[i];
        polygons.add(
          Polygon(
            polygonId: PolygonId('${zoneItem.id}_$i'),
            points: pts,
            fillColor: isSelected
                ? const Color(0xFF4B5563).withOpacity(0.22)
                : const Color(0xFF4B5563).withOpacity(0.03),
            strokeColor: isSelected ? activeBorder : inactiveBorder,
            strokeWidth: isSelected ? 2 : 1,
            consumeTapEvents: true,
            onTap: () => _toggleZone(zoneItem.id),
          ),
        );
      }
    }

    return polygons;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Ampliado un 25% (de 0.40 a 0.50 de la pantalla), dando más protagonismo al mapa y reduciendo la lista de zonas
    final mapHeight = (screenHeight * 0.50).clamp(300.0, 480.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, _selectedZones),
        ),
        title: const Text(
          'Zonas de Preferencia',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedZones.isNotEmpty) {
                  _selectedZones.clear();
                } else {
                  for (final z in _bogotaZones) {
                    _selectedZones.add(z.id);
                  }
                  for (final z in _surroundingZones) {
                    _selectedZones.add(z.id);
                  }
                }
              });
            },
            child: Text(
              _selectedZones.isNotEmpty ? 'Limpiar' : 'Todas',
              style: const TextStyle(
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ==========================================
          // MITAD SUPERIOR: MAPA ESTILIZADO MONOCROMÁTICO
          // Zoom bloqueado/estático, operado con 1 dedo
          // ==========================================
          SizedBox(
            height: mapHeight,
            width: double.infinity,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(4.6850, -74.0750),
                        zoom: 10.6,
                      ),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false, // Sin botones invasivos de Google
                      zoomGesturesEnabled: true,  // Aumentar o disminuir libremente con dos dedos (pinch-to-zoom)
                      scrollGesturesEnabled: true, // Moverse con un dedo
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      indoorViewEnabled: false,
                      trafficEnabled: false,
                      style: _monochromeMapStyle,
                      polygons: _buildPolygons(),
                      markers: const {},
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                // Indicador visual flotante discreto sobre el mapa
                Positioned(
                  top: 10,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4A4A4A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedZones.length} ${_selectedZones.length == 1 ? "zona activa" : "zonas activas"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3437),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),

          // ==========================================
          // MITAD INFERIOR: LISTA DESLIZABLE CON CHECKBOXES
          // ==========================================
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                // ------------------------------------
                // SECCIÓN: BOGOTÁ D.C. (MASTER CHECKBOX + EXPANDIBLE)
                // ------------------------------------
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isAllBogotaSelected ? const Color(0xFF4A4A4A) : const Color(0xFFE5E7EB),
                      width: _isAllBogotaSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Encabezado maestro de Bogotá D.C.
                      InkWell(
                        onTap: _toggleAllBogota,
                        borderRadius: BorderRadius.vertical(
                          top: const Radius.circular(18),
                          bottom: _bogotaExpanded ? Radius.zero : const Radius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              _buildCheckbox(
                                isChecked: _isAllBogotaSelected,
                                onTap: _toggleAllBogota,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text(
                                          'Bogotá D.C.',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Toda la ciudad',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_bogotaZones.where((z) => _selectedZones.contains(z.id)).length} de ${_bogotaZones.length} zonas seleccionadas',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón colapsar / desplegar zonas individuales
                              IconButton(
                                icon: Icon(
                                  _bogotaExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF4A4A4A),
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _bogotaExpanded = !_bogotaExpanded;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Lista desplegada de zonas de Bogotá
                      if (_bogotaExpanded) ...[
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          itemCount: _bogotaZones.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F2F5)),
                          itemBuilder: (context, index) {
                            final zone = _bogotaZones[index];
                            final isChecked = _selectedZones.contains(zone.id);
                            return _buildZoneTile(
                              zone: zone,
                              isChecked: isChecked,
                              onToggle: () => _toggleZone(zone.id),
                              onFocus: () => _focusOnZone(zone.id),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ------------------------------------
                // SECCIÓN: MUNICIPIOS ALEDAÑOS
                // ------------------------------------
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Municipios Aledaños',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Lista de municipios aledaños
                ..._surroundingZones.map((zone) {
                  final isChecked = _selectedZones.contains(zone.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isChecked ? const Color(0xFF4A4A4A) : const Color(0xFFE5E7EB),
                        width: isChecked ? 1.4 : 1,
                      ),
                    ),
                    child: _buildZoneTile(
                      zone: zone,
                      isChecked: isChecked,
                      onToggle: () => _toggleZone(zone.id),
                      onFocus: () => _focusOnZone(zone.id),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ==========================================
          // PIE DE PÁGINA: BOTÓN PERSISTENTE 'GUARDAR'
          // Sticky Bottom Button idéntico a la referencia
          // ==========================================
          _buildStickyBottomButton(context),
        ],
      ),
    );
  }

  /// Checkbox con estilo limpio y elegante en gris oscuro suave
  Widget _buildCheckbox({required bool isChecked, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isChecked ? const Color(0xFF4B5563) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isChecked ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
            width: 1.8,
          ),
        ),
        child: isChecked
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  /// Tile individual de zona con checkbox, título, descripción y botón centrar
  Widget _buildZoneTile({
    required ZoneItem zone,
    required bool isChecked,
    required VoidCallback onToggle,
    required VoidCallback onFocus,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildCheckbox(isChecked: isChecked, onTap: onToggle),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                      color: isChecked ? const Color(0xFF111111) : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    zone.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.my_location_rounded, size: 18, color: Color(0xFF9CA3AF)),
              tooltip: 'Ubicar en mapa',
              onPressed: onFocus,
            ),
          ],
        ),
      ),
    );
  }

  /// Pie de página persistente con hitTestBehavior opaque para prevenir traspaso de toques al mapa
  Widget _buildStickyBottomButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 4 : 16),
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
        height: 54,
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _selectedZones);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Guardar (${_selectedZones.length} ${_selectedZones.length == 1 ? "zona" : "zonas"})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
