import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseurl = "https://aetheris-backend-a56i.onrender.com";
  // Android Emulator → 10.0.2.2
  // iOS Simulator → localhost
  // Real Device → PC IP

  static Future<String> sendSpeed(double speed) async {
    try {
      final response = await http.post(
        Uri.parse("$baseurl/speed"),
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
