import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final target = 'https://www.apparta.co/di-lucca/reservas/branch/payment?branch_id=1860&token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh';
  
  // 1. codetabs
  try {
    final u = Uri.parse('https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(target)}');
    final r = await http.get(u).timeout(const Duration(seconds: 8));
    print('codetabs status: ${r.statusCode}, length: ${r.body.length}');
  } catch (e) {
    print('codetabs error: $e');
  }

  // 2. thingproxy
  try {
    final u = Uri.parse('https://thingproxy.freeboard.io/fetch/$target');
    final r = await http.get(u).timeout(const Duration(seconds: 8));
    print('thingproxy status: ${r.statusCode}, length: ${r.body.length}');
  } catch (e) {
    print('thingproxy error: $e');
  }

  // 3. direct Apparta API if there is one
  try {
    final u = Uri.parse('https://www.apparta.co/api/reservation?token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh');
    final r = await http.get(u).timeout(const Duration(seconds: 5));
    print('direct api status: ${r.statusCode}');
  } catch (e) {
    print('direct api error: $e');
  }
}
