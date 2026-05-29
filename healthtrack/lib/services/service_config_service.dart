import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ServiceConfigService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Get all active services
  static Future<List<Map<String, dynamic>>> getAllServices({String? serviceType}) async {
    Exception? lastException;
    
    for (final url in fallbackBaseUrls) {
      try {
        // Build URL with service type filter if provided
        String urlPath = "$url/service-config";
        if (serviceType != null) {
          urlPath += "?service_type=$serviceType";
        }
        
        final response = await http.get(
          Uri.parse(urlPath),
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

  /// Get service by ID
  static Future<Map<String, dynamic>> getServiceById(int id) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/service-config/$id"),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return data['data'];
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch service');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch service");
        }
      } catch (e) {
        lastException = Exception("Failed to fetch service: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch service");
  }
}