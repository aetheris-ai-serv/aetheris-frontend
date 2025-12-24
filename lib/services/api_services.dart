import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.104.15.233:8000";
  // Android Emulator → 10.0.2.2
  // iOS Simulator → localhost
  // Real Device → PC IP

  static Future<String> sendSpeed(double speed) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/speed"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"speed": speed}),
      );

      print("STATUS: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["message"];
      } else {
        return "Server error";
      }
    } catch (e) {
      print("ERROR: $e");
      return "Connection error";
    }
  }
}
