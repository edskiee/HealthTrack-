import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'admin_session_storage.dart';

class SystemSettingsService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  static Future<Map<String, String>> _hdr() async {
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

  static List<String> get _bases => [
        ApiConfig.baseUrl,
        ...ApiConfig.fallbackBaseUrls,
      ];

  /// Get all system settings
  static Future<List<Map<String, dynamic>>> getAllSettings() async {
    Exception? lastException;
    final headers = await _hdr();
    for (final url in _bases.where((u) => u.isNotEmpty)) {
      try {
        final response = await http
            .get(
              Uri.parse("$url/system-settings"),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch system settings');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch system settings");
        }
      } catch (e) {
        lastException = Exception("Failed to fetch system settings: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch system settings");
  }

  /// Get a specific setting by key
  static Future<Map<String, dynamic>?> getSettingByKey(String key) async {
    Exception? lastException;
    final headers = await _hdr();
    for (final url in _bases.where((u) => u.isNotEmpty)) {
      try {
        final response = await http
            .get(
              Uri.parse("$url/system-settings/$key"),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return data['data'];
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch system setting');
          }
        } else if (response.statusCode == 404) {
          return null;
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch system setting");
        }
      } catch (e) {
        lastException = Exception("Failed to fetch system setting: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch system setting");
  }

  /// Update a setting
  static Future<bool> updateSetting(
      String key, String value, String type, String? description) async {
    Exception? lastException;
    final headers = await _hdr();
    for (final url in _bases.where((u) => u.isNotEmpty)) {
      try {
        final response = await http
            .put(
              Uri.parse("$url/system-settings/$key"),
              headers: headers,
              body: json.encode({
                "setting_value": value,
                "setting_type": type,
                "description": description,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['success'] == true;
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to update system setting");
        }
      } catch (e) {
        lastException = Exception("Failed to update system setting: $e");
      }
    }
    throw lastException ?? Exception("Failed to update system setting");
  }

  /// Bulk update settings
  static Future<bool> bulkUpdateSettings(
      List<Map<String, dynamic>> settings) async {
    Exception? lastException;
    final headers = await _hdr();
    for (final url in _bases.where((u) => u.isNotEmpty)) {
      try {
        final response = await http
            .post(
              Uri.parse("$url/system-settings/bulk-update"),
              headers: headers,
              body: json.encode({
                "settings": settings,
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['success'] == true;
        } else {
          lastException = Exception(
              "HTTP ${response.statusCode}: Failed to bulk update system settings");
        }
      } catch (e) {
        lastException =
            Exception("Failed to bulk update system settings: $e");
      }
    }
    throw lastException ??
        Exception("Failed to bulk update system settings");
  }
}
