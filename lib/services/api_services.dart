import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_info.dart';
import '../models/user_data.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.0.7:8000/api';

  final Duration timeoutDuration = Duration(seconds: 10);

  // Add this connection test method
  static Future<bool> testConnection() async {
    try {
      print('🔍 Testing connection to: $baseUrl');
      final response = await http
          .get(Uri.parse('$baseUrl/userinfo/'))
          .timeout(Duration(seconds: 5));

      print('✅ Connection successful! Status: ${response.statusCode}');
      return true;
    } catch (e) {
      print('❌ Connection failed: $e');
      return false;
    }
  }

  // Register User
  Future<Map<String, dynamic>> registerUser(UserInfo userInfo) async {
    try {
      print('Sending request to: $baseUrl/userinfo/');
      print('Request data: ${userInfo.toJson()}');

      final response = await http.post(
        Uri.parse('$baseUrl/userinfo/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userInfo.toJson()),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': UserInfo.fromJson(jsonDecode(response.body)),
        };
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get All Users
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/userinfo/'));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<UserInfo> users = jsonList
            .map((json) => UserInfo.fromJson(json))
            .toList();
        return {'success': true, 'data': users};
      } else {
        return {'success': false, 'error': 'Failed to load users'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get User by ID
  Future<Map<String, dynamic>> getUser(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/userinfo/$userId/'));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': UserInfo.fromJson(jsonDecode(response.body)),
        };
      } else {
        return {'success': false, 'error': 'User not found'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Submit User Data
  Future<Map<String, dynamic>> submitUserData(UserData userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/userdata/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData.toJson()),
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': UserData.fromJson(jsonDecode(response.body)),
        };
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get User Data
  Future<Map<String, dynamic>> getUserData(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/userdata/?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<UserData> dataList = jsonList
            .map((json) => UserData.fromJson(json))
            .toList();
        return {'success': true, 'data': dataList};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
