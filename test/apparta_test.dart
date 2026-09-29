import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Analizar link de Apparta Di Lucca', () {
    final uri = Uri.parse('https://www.apparta.co/di-lucca/reservas/branch/payment?branch_id=1860&token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh');
    final segments = uri.pathSegments;
    print('Segments: $segments');
    const stopWords = {'restaurante', 'restaurantes', 'reserva', 'reservas', 'branch', 'payment', 'bogota', 'colombia', 'm', 'menu', 'r'};
    String? detectedPlace;
    for (var i = segments.length - 1; i >= 0; i--) {
      final seg = segments[i].toLowerCase();
      if (!stopWords.contains(seg) && seg.isNotEmpty) {
        detectedPlace = segments[i];
        break;
      }
    }
    print('Detected place: $detectedPlace');
    expect(detectedPlace, 'di-lucca');
  });
}
