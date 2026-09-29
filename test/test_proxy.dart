import 'package:http/http.dart' as http;

void main() async {
  final target = 'https://www.apparta.co/di-lucca/reservas/branch/payment?branch_id=1860&token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh';

  final proxies = [
    'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(target)}',
    'https://thingproxy.freeboard.io/fetch/$target',
    'https://api.allorigins.win/raw?url=${Uri.encodeComponent(target)}',
  ];

  for (final p in proxies) {
    print('Testing proxy: $p');
    try {
      final res = await http.get(Uri.parse(p), headers: {
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 6));
      print('Status: ${res.statusCode}, len: ${res.body.length}');
      if (res.statusCode == 200 && res.body.contains('__NEXT_DATA__')) {
        print('SUCCESS! Found __NEXT_DATA__ via $p');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
