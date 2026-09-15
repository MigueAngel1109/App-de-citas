import 'package:google_maps_flutter/google_maps_flutter.dart';

class ZoneData {
  static const Map<String, List<LatLng>> polygons = {};

  static const Map<String, Map<String, dynamic>> zoneCircles = {
    'Usaquén': {'center': LatLng(4.7303, -74.0305), 'radius': 3000.0},
    'Chapinero': {'center': LatLng(4.6438, -74.0583), 'radius': 2500.0},
    'Santa Fe': {'center': LatLng(4.5959, -74.0620), 'radius': 2000.0},
    'San Cristóbal': {'center': LatLng(4.5510, -74.0833), 'radius': 3000.0},
    'Usme': {'center': LatLng(4.4533, -74.1221), 'radius': 4000.0},
    'Tunjuelito': {'center': LatLng(4.5760, -74.1378), 'radius': 2500.0},
    'Bosa': {'center': LatLng(4.6196, -74.1950), 'radius': 3000.0},
    'Kennedy': {'center': LatLng(4.6291, -74.1537), 'radius': 3500.0},
    'Fontibón': {'center': LatLng(4.6738, -74.1437), 'radius': 3000.0},
    'Engativá': {'center': LatLng(4.7042, -74.1165), 'radius': 3000.0},
    'Suba': {'center': LatLng(4.7414, -74.0840), 'radius': 4000.0},
    'Barrios Unidos': {'center': LatLng(4.6687, -74.0786), 'radius': 2500.0},
    'Teusaquillo': {'center': LatLng(4.6416, -74.0847), 'radius': 2000.0},
    'Los Mártires': {'center': LatLng(4.6074, -74.0863), 'radius': 1500.0},
    'Antonio Nariño': {'center': LatLng(4.5878, -74.1026), 'radius': 1500.0},
    'Puente Aranda': {'center': LatLng(4.6178, -74.1158), 'radius': 2500.0},
    'La Candelaria': {'center': LatLng(4.5966, -74.0734), 'radius': 1000.0},
    'Rafael Uribe Uribe': {'center': LatLng(4.5683, -74.1143), 'radius': 2500.0},
    'Ciudad Bolívar': {'center': LatLng(4.5218, -74.1610), 'radius': 4000.0},
    'Sumapaz': {'center': LatLng(4.0818, -74.2831), 'radius': 5000.0},
  };
}
