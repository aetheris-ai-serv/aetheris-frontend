import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendSpeed(double speed) async {
  final url = Uri.parse(
    'http://192.168.1.5:8000/api/speed/',
  ); // Replace with your IP

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'speed': speed}),
  );

  if (response.statusCode == 200) {
    print('✅ Speed sent: ${response.body}');
  } else {
    print('❌ Failed: ${response.statusCode}');
  }
}
