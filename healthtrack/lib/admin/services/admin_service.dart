import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'admin_session_storage.dart';

class AdminService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    // DEBUG — remove once 401s are resolved
    print('[AdminService] _authHeaders() token='
        '${token == null ? "NULL" : token.isEmpty ? "EMPTY" : "${token.substring(0, token.length.clamp(0, 10))}..."}');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all services
  static Future<List<Map<String, dynamic>>> getAllServices() async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/service-config"),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch services');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch services");
        }
      } catch (e) {
        lastException = Exception("Failed to fetch services: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch services");
  }

  /// Create a new service
  static Future<Map<String, dynamic>> createService(Map<String, dynamic> serviceData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.post(
          Uri.parse("$url/service-config"),
          headers: await _authHeaders(),
          body: json.encode(serviceData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          return data;
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to create service");
        }
      } catch (e) {
        lastException = Exception("Failed to create service: $e");
      }
    }
    throw lastException ?? Exception("Failed to create service");
  }

  /// Update an existing service
  static Future<Map<String, dynamic>> updateService(int serviceId, Map<String, dynamic> serviceData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.put(
          Uri.parse("$url/service-config/$serviceId"),
          headers: await _authHeaders(),
          body: json.encode(serviceData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to update service");
        }
      } catch (e) {
        lastException = Exception("Failed to update service: $e");
      }
    }
    throw lastException ?? Exception("Failed to update service");
  }

  /// Delete a service
  static Future<Map<String, dynamic>> deleteService(int serviceId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse("$url/service-config/$serviceId"),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to delete service");
        }
      } catch (e) {
        lastException = Exception("Failed to delete service: $e");
      }
    }
    throw lastException ?? Exception("Failed to delete service");
  }
}