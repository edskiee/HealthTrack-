import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // Get all services
  static Future<List<Map<String, dynamic>>> getAllServices() async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;
      String successUrl = "";

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/service-config";
          print("🔗 Trying URL: $fullUrl");

          response = await http
              .get(
                Uri.parse(fullUrl),
                headers: _headers,
              )
              .timeout(const Duration(seconds: 10));

          successUrl = url;
          print("✅ Successfully connected to: $successUrl");
          break; // Exit loop on successful connection
        } on TimeoutException catch (e) {
          print("⏰ Timeout connecting to $url: $e");
          continue; // Try next URL
        } on SocketException catch (e) {
          print("🔌 Socket error connecting to $url: $e");
          continue; // Try next URL
        } catch (e) {
          print("❌ Failed to connect to $url: $e");
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure the server is running.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        if (isSuccess) {
          List services = data['data'] ?? [];
          return services.map((service) {
            return {
              "id": service["id"] as int,
              "service_name": service["service_name"] as String,
              "service_description": service["service_description"] as String?,
              "service_type": service["service_type"] as String,
              "is_enabled": service["is_enabled"] as int,
              "required_fields": service["required_fields"] is List
                  ? List<String>.from(service["required_fields"])
                  : service["required_fields"] is String
                      ? List<String>.from(json.decode(service["required_fields"]))
                      : [],
              "available_days": service["available_days"] is List
                  ? List<String>.from(service["available_days"])
                  : service["available_days"] is String
                      ? List<String>.from(json.decode(service["available_days"]))
                      : [],
              "max_appointments_per_day":
                  service["max_appointments_per_day"] as int,
              "created_at": service["created_at"] as String,
              "updated_at": service["updated_at"] as String,
            };
          }).toList();
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
      final response = await http.get(
        Uri.parse("$baseUrl/service-config/$id"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        if (isSuccess) {
          var service = data['data'];
          return {
            "id": service["id"] as int,
            "service_name": service["service_name"] as String,
            "service_description": service["service_description"] as String?,
            "service_type": service["service_type"] as String,
            "is_enabled": service["is_enabled"] as int,
            "required_fields": service["required_fields"] is List
                ? List<String>.from(service["required_fields"])
                : service["required_fields"] is String
                    ? List<String>.from(json.decode(service["required_fields"]))
                    : [],
            "available_days": service["available_days"] is List
                ? List<String>.from(service["available_days"])
                : service["available_days"] is String
                    ? List<String>.from(json.decode(service["available_days"]))
                    : [],
            "max_appointments_per_day": service["max_appointments_per_day"] as int,
            "created_at": service["created_at"] as String,
            "updated_at": service["updated_at"] as String,
          };
        } else {
          // Return null if service not found
          return null;
        }
      } else if (response.statusCode == 404) {
        // Service not found
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
      final response = await http.post(
        Uri.parse("$baseUrl/service-config"),
        headers: _headers,
        body: json.encode({
          "service_name": serviceName,
          "service_description": serviceDescription,
          "service_type": serviceType,
          "is_enabled": isEnabled,
          "required_fields": requiredFields,
          "available_days": availableDays,
          "max_appointments_per_day": maxAppointmentsPerDay,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        if (isSuccess) {
          var service = data['data'];
          return {
            "id": service["id"] as int,
            "service_name": service["service_name"] as String,
            "service_description": service["service_description"] as String?,
            "service_type": service["service_type"] as String,
            "is_enabled": service["is_enabled"] as bool,
            "required_fields": service["required_fields"] is List
                ? List<String>.from(service["required_fields"])
                : [],
            "available_days": service["available_days"] is List
                ? List<String>.from(service["available_days"])
                : [],
            "max_appointments_per_day": service["max_appointments_per_day"] as int,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to create service');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to create service");
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
      final response = await http.put(
        Uri.parse("$baseUrl/service-config/$id"),
        headers: _headers,
        body: json.encode({
          if (serviceName != null) "service_name": serviceName,
          if (serviceDescription != null)
            "service_description": serviceDescription,
          if (serviceType != null) "service_type": serviceType,
          if (isEnabled != null) "is_enabled": isEnabled,
          if (requiredFields != null) "required_fields": requiredFields,
          if (availableDays != null) "available_days": availableDays,
          if (maxAppointmentsPerDay != null)
            "max_appointments_per_day": maxAppointmentsPerDay,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        if (isSuccess) {
          var service = data['data'];
          return {
            "id": service["id"] as int,
            "service_name": service["service_name"] as String,
            "service_description": service["service_description"] as String?,
            "service_type": service["service_type"] as String,
            "is_enabled": service["is_enabled"] as int,
            "required_fields": service["required_fields"] is List
                ? List<String>.from(service["required_fields"])
                : service["required_fields"] is String
                    ? List<String>.from(json.decode(service["required_fields"]))
                    : [],
            "available_days": service["available_days"] is List
                ? List<String>.from(service["available_days"])
                : service["available_days"] is String
                    ? List<String>.from(json.decode(service["available_days"]))
                    : [],
            "max_appointments_per_day": service["max_appointments_per_day"] as int,
            "created_at": service["created_at"] as String,
            "updated_at": service["updated_at"] as String,
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to update service');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to update service");
      }
    } catch (e) {
      throw Exception("Failed to update service: $e");
    }
  }

  // Delete a service (soft delete)
  static Future<bool> deleteService(int id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/service-config/$id"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to delete service");
      }
    } catch (e) {
      throw Exception("Failed to delete service: $e");
    }
  }

  // Get service form structure
  static Future<Map<String, dynamic>?> getServiceFormStructure(int id) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/service-config/$id/form-structure"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        if (isSuccess) {
          var service = data['data'];
          return {
            "id": service["id"] as int,
            "service_name": service["service_name"] as String,
            "required_fields": service["required_fields"] is List
                ? List<String>.from(service["required_fields"])
                : service["required_fields"] is String
                    ? List<String>.from(json.decode(service["required_fields"]))
                    : [],
          };
        } else {
          // Return null if service not found
          return null;
        }
      } else if (response.statusCode == 404) {
        // Service not found
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
      final response = await http.put(
        Uri.parse("$baseUrl/service-config/$id/form-structure"),
        headers: _headers,
        body: json.encode({
          "required_fields": requiredFields,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }

        return isSuccess;
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: Failed to update service form structure");
      }
    } catch (e) {
      throw Exception("Failed to update service form structure: $e");
    }
  }
}