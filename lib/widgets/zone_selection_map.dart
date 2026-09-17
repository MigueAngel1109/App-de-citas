import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/zone_data.dart';

class ZoneSelectionMap extends StatefulWidget {
  final Set<String> initialSelectedZones;

  const ZoneSelectionMap({super.key, required this.initialSelectedZones});

  @override
  State<ZoneSelectionMap> createState() => _ZoneSelectionMapState();
}

class _ZoneSelectionMapState extends State<ZoneSelectionMap> {
  late GoogleMapController _mapController;
  final Set<String> _selectedZones = {};

  @override
  void initState() {
    super.initState();
    _selectedZones.addAll(widget.initialSelectedZones);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle('''
      [
        {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
        {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
        {"elementType": "labels.text.fill", "stylers": [{"color": "#555555"}]},
        {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
        {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#c9c9c9"}]},
        {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#333333"}]},
        {"featureType": "poi", "stylers": [{"visibility": "off"}]},
        {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
        {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#e0e0e0"}]},
        {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#e8e8e8"}]},
        {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#666666"}]},
        {"featureType": "transit", "stylers": [{"visibility": "off"}]},
        {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c8dff0"}]},
        {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#8ab4cc"}]}
      ]
    ''');
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

  Set<Polygon> _buildPolygons() {
    final Set<Polygon> polygons = {};
    for (var entry in ZoneData.polygons.entries) {
      final zoneName = entry.key;
      final isSelected = _selectedZones.contains(zoneName);

      final Color activeColor = const Color(0xFFE53935);
      final Color inactiveColor = const Color(0xFF424242);

      polygons.add(
        Polygon(
          polygonId: PolygonId(zoneName),
          points: entry.value,
          fillColor: isSelected
              ? activeColor.withOpacity(0.30)
              : inactiveColor.withOpacity(0.06),
          strokeColor: isSelected
              ? activeColor
              : inactiveColor.withOpacity(0.35),
          strokeWidth: isSelected ? 3 : 1,
          consumeTapEvents: true,
          onTap: () => _toggleZone(zoneName),
        ),
      );
    }
    return polygons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context, widget.initialSelectedZones),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(4.65, -74.09),
              zoom: 11.2,
            ),
            onMapCreated: _onMapCreated,
            polygons: _buildPolygons(),
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Panel inferior con zonas seleccionadas y botón guardar
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _selectedZones.isEmpty
                            ? 'Toca un pin para seleccionar una zona'
                            : '${_selectedZones.length} ${_selectedZones.length == 1 ? 'zona seleccionada' : 'zonas seleccionadas'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedZones.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedZones.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: _selectedZones.map((z) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                        ),
                        child: Text(z, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedZones),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

