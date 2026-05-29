import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'services/admin_session_storage.dart';

class SystemSettingsService {
  // Get base URL based on platform
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Fallback URLs to try if the primary URL fails
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  static Future<Map<String, String>> _authorizedHeaders() async {
    final token = await AdminSessionStorage.getToken();
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // Get all system settings
  static Future<List<Map<String, dynamic>>> getAllSettings() async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;
      String successUrl = "";

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/system-settings";
          print("🔗 Trying URL: $fullUrl");

          response = await http
              .get(
                Uri.parse(fullUrl),
                headers: await _authorizedHeaders(),
              )
              .timeout(const Duration(seconds: 10));

          successUrl = url;
          print("✅ Successfully connected to: $successUrl");
          break; // Exit loop on successful connection
        } catch (e) {
          print("❌ Failed to connect to $url: $e");
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure server is running.');
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
          List settings = data['data'] ?? [];
          return settings.map((setting) {
            return {
              "id": setting["id"] as int,
              "setting_key": setting["setting_key"] as String,
              "setting_value": setting["setting_value"] as String,
              "setting_type": setting["setting_type"] as String,
              "description": setting["description"] as String?,
              "is_active": setting["is_active"] as int,
              "created_at": setting["created_at"] as String,
              "updated_at": setting["updated_at"] as String,
            };
          }).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch system settings');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch system settings");
      }
    } catch (e) {
      throw Exception("Failed to fetch system settings: $e");
    }
  }

  // Get a specific setting by key
  static Future<Map<String, dynamic>?> getSettingByKey(String key) async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/system-settings/$key";
          response = await http
              .get(
                Uri.parse(fullUrl),
                headers: await _authorizedHeaders(),
              )
              .timeout(const Duration(seconds: 10));
          break; // Exit loop on successful connection
        } catch (e) {
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure server is running.');
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
          var setting = data['data'];
          return {
            "id": setting["id"] as int,
            "setting_key": setting["setting_key"] as String,
            "setting_value": setting["setting_value"] as String,
            "setting_type": setting["setting_type"] as String,
            "description": setting["description"] as String?,
            "is_active": setting["is_active"] as int,
            "created_at": setting["created_at"] as String,
            "updated_at": setting["updated_at"] as String,
          };
        } else {
          // Return null if setting not found
          return null;
        }
      } else if (response.statusCode == 404) {
        // Setting not found
        return null;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch system setting");
      }
    } catch (e) {
      throw Exception("Failed to fetch system setting: $e");
    }
  }

  // Update a setting
  static Future<bool> updateSetting(String key, String value, String type, String? description) async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/system-settings/$key";
          response = await http
              .put(
                Uri.parse(fullUrl),
                headers: await _authorizedHeaders(),
                body: json.encode({
                  "setting_value": value,
                  "setting_type": type,
                  "description": description,
                }),
              )
              .timeout(const Duration(seconds: 10));
          break; // Exit loop on successful connection
        } catch (e) {
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure server is running.');
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
        
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to update system setting");
      }
    } catch (e) {
      throw Exception("Failed to update system setting: $e");
    }
  }

  // Bulk update settings
  static Future<bool> bulkUpdateSettings(List<Map<String, dynamic>> settings) async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/system-settings/bulk-update";
          response = await http
              .post(
                Uri.parse(fullUrl),
                headers: await _authorizedHeaders(),
                body: json.encode({
                  "settings": settings,
                }),
              )
              .timeout(const Duration(seconds: 10));
          break; // Exit loop on successful connection
        } catch (e) {
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure server is running.');
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
        
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to bulk update system settings");
      }
    } catch (e) {
      throw Exception("Failed to bulk update system settings: $e");
    }
  }

  // Reset a setting to default value
  static Future<bool> resetSetting(String key) async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/system-settings/$key/reset";
          response = await http
              .post(
                Uri.parse(fullUrl),
                headers: await _authorizedHeaders(),
              )
              .timeout(const Duration(seconds: 10));
          break; // Exit loop on successful connection
        } catch (e) {
          continue; // Try next URL
        }
      }

      if (response == null) {
        throw Exception(
            'Could not connect to server. Please check your internet connection and ensure server is running.');
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
        
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to reset system setting");
      }
    } catch (e) {
      throw Exception("Failed to reset system setting: $e");
    }
  }
}