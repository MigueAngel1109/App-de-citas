import 'package:http/http.dart' as http;

void main() async {
  // En Next.js, los datos de la página están disponibles en /_next/data/{buildId}/...
  // O podemos llamar a un endpoint de api
  final buildId = 'CNQJ5P9R8zNW-p7W0MLj1';
  final nextDataUrl = 'https://www.apparta.co/_next/data/$buildId/di-lucca/reservas/branch/payment.json?branch_id=1860&token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh&establishmentSlug=di-lucca';
  print('Trying: $nextDataUrl');
  try {
    final r = await http.get(Uri.parse(nextDataUrl));
    print('status: ${r.statusCode}');
    if (r.statusCode == 200) {
      print('First 300 chars: ${r.body.substring(0, 300)}');
    }
  } catch (e) {
    print('err: $e');
  }
}
