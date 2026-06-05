import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';

class ServiceConfigService {
  // Get base URL based on platform
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Fallback URLs to try if the primary URL fails
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  // Headers for API requests
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Safely converts a DB boolean-like value (int 0/1, bool, null) to int (1 or 0).
  /// Falls back to checking is_active when is_enabled is absent.
  static int _resolveEnabledFlag(Map<String, dynamic> service) {
    final raw = service['is_enabled'] ?? service['is_active'];
    if (raw == null) return 1; // default to enabled if field is missing
    if (raw is bool) return raw ? 1 : 0;
    if (raw is int) return raw == 1 ? 1 : 0;
    return 1;
  }

  /// Parses a JSON field that may arrive as a List, a JSON string, or null.
  static List<String> _parseJsonList(dynamic value) {
    if (value is List) return List<String>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        return List<String>.from(json.decode(value));
      } catch (_) {}
    }
    return [];
  }

  static Map<String, dynamic> _mapService(Map<String, dynamic> service) {
    return {
      "id": service["id"] as int,
      "service_name": service["service_name"] as String,
      "service_description": service["service_description"] as String?,
      "service_type": service["service_type"] as String,
      // Expose as int (1 = enabled, 0 = disabled) for backwards compat with callers
      "is_enabled": _resolveEnabledFlag(service),
      "is_active": _resolveEnabledFlag(service),
      "required_fields": _parseJsonList(service["required_fields"]),
      "available_days": _parseJsonList(service["available_days"]),
      "max_appointments_per_day":
          (service["max_appointments_per_day"] as num?)?.toInt() ?? 50,
      "created_at": service["created_at"]?.toString() ?? '',
      "updated_at": service["updated_at"]?.toString() ?? '',
    };
  }

  // Get all services
  static Future<List<Map<String, dynamic>>> getAllServices() async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          response = await http
              .get(Uri.parse("$url/service-config"), headers: _headers)
              .timeout(const Duration(seconds: 10));
          break; // Exit loop on successful connection
        } on TimeoutException {
          continue;
        } on SocketException {
          continue;
        } catch (_) {
          continue;
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure the server is running.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isSuccess(data)) {
          final List services = data['data'] ?? [];
          return services
              .map((s) => _mapService(s as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch services');
        }
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to fetch services");
      }
    } catch (e) {
      throw Exception("Failed to fetch services: $e");
    }
  }

  // Get a specific service by ID
  static Future<Map<String, dynamic>?> getServiceById(int id) async {
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/service-config/$id"), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isSuccess(data)) {
          return _mapService(data['data'] as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch service");
      }
    } catch (e) {
      throw Exception("Failed to fetch service: $e");
    }
  }

  // Create a new service
  static Future<Map<String, dynamic>> createService({
    required String serviceName,
    String? serviceDescription,
    required String serviceType,
    bool isEnabled = true,
    List<String> requiredFields = const [],
    List<String> availableDays = const [],
    int maxAppointmentsPerDay = 50,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/service-config"),
            headers: _headers,
            body: json.encode({
              "service_name": serviceName,
              "service_description": serviceDescription,
              "service_type": serviceType,
              "is_enabled": isEnabled ? 1 : 0,
              "is_active": isEnabled ? 1 : 0,
              "required_fields": requiredFields,
              "available_days": availableDays,
              "max_appointments_per_day": maxAppointmentsPerDay,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (_isSuccess(data)) {
          return _mapService(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to create service');
        }
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to create service");
      }
    } catch (e) {
      throw Exception("Failed to create service: $e");
    }
  }

  // Update a service
  static Future<Map<String, dynamic>> updateService({
    required int id,
    String? serviceName,
    String? serviceDescription,
    String? serviceType,
    bool? isEnabled,
    List<String>? requiredFields,
    List<String>? availableDays,
    int? maxAppointmentsPerDay,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (serviceName != null) body["service_name"] = serviceName;
      if (serviceDescription != null)
        body["service_description"] = serviceDescription;
      if (serviceType != null) body["service_type"] = serviceType;
      if (isEnabled != null) {
        body["is_enabled"] = isEnabled ? 1 : 0;
        body["is_active"] = isEnabled ? 1 : 0;
      }
      if (requiredFields != null) body["required_fields"] = requiredFields;
      if (availableDays != null) body["available_days"] = availableDays;
      if (maxAppointmentsPerDay != null)
        body["max_appointments_per_day"] = maxAppointmentsPerDay;

      final response = await http
          .put(
            Uri.parse("$baseUrl/service-config/$id"),
            headers: _headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isSuccess(data)) {
          return _mapService(data['data'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Failed to update service');
        }
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to update service");
      }
    } catch (e) {
      throw Exception("Failed to update service: $e");
    }
  }

  // Delete a service (soft delete)
  static Future<bool> deleteService(int id) async {
    try {
      final response = await http
          .delete(Uri.parse("$baseUrl/service-config/$id"), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _isSuccess(data);
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to delete service");
      }
    } catch (e) {
      throw Exception("Failed to delete service: $e");
    }
  }

  // Get service form structure
  static Future<Map<String, dynamic>?> getServiceFormStructure(int id) async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/service-config/$id/form-structure"),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isSuccess(data)) {
          final service = data['data'] as Map<String, dynamic>;
          return {
            "id": service["id"] as int,
            "service_name": service["service_name"] as String,
            "required_fields": _parseJsonList(service["required_fields"]),
          };
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to fetch service form structure");
      }
    } catch (e) {
      throw Exception("Failed to fetch service form structure: $e");
    }
  }

  // Update service form structure
  static Future<bool> updateServiceFormStructure(
      int id, List<String> requiredFields) async {
    try {
      final response = await http
          .put(
            Uri.parse("$baseUrl/service-config/$id/form-structure"),
            headers: _headers,
            body: json.encode({"required_fields": requiredFields}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _isSuccess(data);
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to update service form structure");
      }
    } catch (e) {
      throw Exception("Failed to update service form structure: $e");
    }
  }

  /// Robustly determines if an API response indicates success.
  static bool _isSuccess(Map<String, dynamic> data) {
    final s = data['success'];
    if (s is bool) return s;
    if (s is String) return s.toLowerCase() == 'true';
    if (s is int) return s == 1;
    return false;
  }
}
