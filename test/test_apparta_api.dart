import 'package:http/http.dart' as http;

void main() async {
  final u = Uri.parse('https://www.apparta.co/api/reservation?token=nwarrnu6k72bm09mbi6o3wrmw703z1ggw3gxca7tgjgaoeomn912w6xn59mh');
  final r = await http.get(u);
  print('Body: ${r.body}');
}
