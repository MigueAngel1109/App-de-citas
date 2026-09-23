import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Selector visual ligero de zonas y localidades de Bogotá.
/// Reemplaza el mapa pesado para evitar instanciar múltiples motores de Google Maps
/// y prevenir cierres abruptos / sobrecostos de memoria.
class ZoneSelectionMap extends StatefulWidget {
  final Set<String> initialSelectedZones;

  const ZoneSelectionMap({super.key, required this.initialSelectedZones});

  @override
  State<ZoneSelectionMap> createState() => _ZoneSelectionMapState();
}

class _ZoneSelectionMapState extends State<ZoneSelectionMap> {
  final Set<String> _selectedZones = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, dynamic>> _bogotaLocalities = [
    {'name': 'Chapinero', 'icon': Icons.nightlife, 'desc': 'Zona Rosa, Zona G, Parque 93, Quinta Camacho'},
    {'name': 'Usaquén', 'icon': Icons.restaurant, 'desc': 'Santa Bárbara, Cedritos, Centro Histórico de Usaquén'},
    {'name': 'Teusaquillo', 'icon': Icons.park, 'desc': 'Park Way, La Soledad, Galerías, Salitre'},
    {'name': 'Suba', 'icon': Icons.nature_people, 'desc': 'La Colina, Niza, Suba Centro'},
    {'name': 'Santa Fe', 'icon': Icons.museum, 'desc': 'La Macarena, Torres del Parque, Centro Internacional'},
    {'name': 'La Candelaria', 'icon': Icons.history_edu, 'desc': 'Centro Histórico, Museos, Chorro de Quevedo'},
    {'name': 'Barrios Unidos', 'icon': Icons.sports_tennis, 'desc': 'El Lago, Polo, 7 de Agosto'},
    {'name': 'Fontibón', 'icon': Icons.flight_takeoff, 'desc': 'Ciudad Salitre Occidental, Modelia'},
    {'name': 'Engativá', 'icon': Icons.apartment, 'desc': 'Normandía, Álamos, Minuto de Dios'},
    {'name': 'Kennedy', 'icon': Icons.storefront, 'desc': 'Américas, Castilla, Timiza'},
    {'name': 'Puente Aranda', 'icon': Icons.precision_manufacturing, 'desc': 'Ciudad Montes, Industrial'},
    {'name': 'Los Mártires', 'icon': Icons.location_city, 'desc': 'Eduardo Santos, Santa Isabel'},
    {'name': 'Antonio Nariño', 'icon': Icons.home_work, 'desc': 'Restrepo, Santander'},
    {'name': 'San Cristóbal', 'icon': Icons.terrain, 'desc': '20 de Julio, Suroriente'},
    {'name': 'Usme', 'icon': Icons.landscape, 'desc': 'Usme Pueblo, La Flora'},
    {'name': 'Tunjuelito', 'icon': Icons.water_drop, 'desc': 'Venecia, San Vicente'},
    {'name': 'Bosa', 'icon': Icons.domain, 'desc': 'Bosa Centro, El Recreo'},
    {'name': 'Rafael Uribe Uribe', 'icon': Icons.signpost, 'desc': 'Quiroga, Olaya'},
    {'name': 'Ciudad Bolívar', 'icon': Icons.tram, 'desc': 'TransMiCable, El Ensueño'},
    {'name': 'Sumapaz', 'icon': Icons.eco, 'desc': 'Páramo de Sumapaz, Región rural'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedZones.addAll(widget.initialSelectedZones);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _selectAll() {
    setState(() {
      for (final loc in _bogotaLocalities) {
        _selectedZones.add(loc['name'] as String);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedZones.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _bogotaLocalities.where((loc) {
      final name = loc['name'] as String;
      final desc = loc['desc'] as String;
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return name.toLowerCase().contains(query) || desc.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context, _selectedZones),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zonas de Interés',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Selecciona dónde quieres ver y recibir citas',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _selectedZones.length == _bogotaLocalities.length ? _clearAll : _selectAll,
            child: Text(
              _selectedZones.length == _bogotaLocalities.length ? 'Deseleccionar' : 'Todas',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Buscar localidad o barrio (ej. Chapinero, 93)...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),

            // Contador de zonas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedZones.length} ${_selectedZones.length == 1 ? "zona seleccionada" : "zonas seleccionadas"}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  if (_selectedZones.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      onPressed: _clearAll,
                      child: const Text('Limpiar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
            ),

            // Listado de localidades tipo tarjeta
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No encontramos zonas para "$_searchQuery"',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final loc = filtered[i];
                        final name = loc['name'] as String;
                        final desc = loc['desc'] as String;
                        final icon = loc['icon'] as IconData;
                        final isSelected = _selectedZones.contains(name);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleZone(name),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.07) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.divider,
                                  width: isSelected ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : const Color(0xFFF1F3F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          desc,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : AppColors.textLight,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 15)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedZones),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _selectedZones.isEmpty
                    ? 'Guardar sin zonas'
                    : 'Aplicar ${_selectedZones.length} ${_selectedZones.length == 1 ? "Zona" : "Zonas"}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
