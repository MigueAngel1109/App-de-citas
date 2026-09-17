import json

with open('bogota_polygons_raw.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

def extract_coords(geojson):
    t = geojson['type']
    coords = geojson['coordinates']
    points = []
    if t == 'Polygon':
        ring = coords[0]
        for pt in ring:
            points.append((pt[1], pt[0]))
    elif t == 'MultiPolygon':
        largest = max(coords, key=lambda poly: len(poly[0]))
        ring = largest[0]
        for pt in ring:
            points.append((pt[1], pt[0]))
    
    if len(points) > 120:
        step = max(1, len(points) // 80)
        points = points[::step]
    return points

lines = []
lines.append("import 'package:google_maps_flutter/google_maps_flutter.dart';")
lines.append("")
lines.append("class ZoneData {")
lines.append("  static const Map<String, List<LatLng>> polygons = {")

for zone_name, geojson in data.items():
    pts = extract_coords(geojson)
    lines.append(f"    '{zone_name}': [")
    for lat, lng in pts:
        lines.append(f"      LatLng({lat:.5f}, {lng:.5f}),")
    lines.append("    ],")

lines.append("  };")
lines.append("")
lines.append("  static const Map<String, Map<String, dynamic>> zoneCircles = {};")
lines.append("}")

with open('lib/utils/zone_data.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('Successfully generated lib/utils/zone_data.dart!')
