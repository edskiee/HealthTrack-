import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'admin_session_storage.dart';

class AdminProfileService {
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

  // Get admin profile
  static Future<Map<String, dynamic>> getAdminProfile(int adminId) async {
    try {
      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];

      http.Response? response;
      String successUrl = "";

      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url${ApiConfig.getAdminEndpoint}/$adminId";
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
          var admin = data['admin'];
          return {
            "id": admin["id"] as int,
            "username": admin["username"] as String,
            "email": admin["email"] as String?,
            "full_name": admin["full_name"] as String?,
            "last_login": admin["last_login"] as String?,
            "created_at": admin["created_at"] as String?,
            if (admin["role"] != null) "role": admin["role"],
            if (admin["password_changed_at"] != null)
              "password_changed_at": admin["password_changed_at"],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch admin profile');
        }
      } else if (response.statusCode == 404) {
        throw Exception("Admin profile not found");
      } else if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("Failed to fetch admin profile: $e");
    }
  }

  // Update admin profile
  static Future<Map<String, dynamic>> updateAdminProfile({
    required int adminId,
    String? fullName,
    String? email,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final headers = await _authorizedHeaders();
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];
      http.Response? response;

      for (final url in allUrls) {
        if (url.isEmpty) continue;
        try {
          response = await http
              .put(
                Uri.parse("$url${ApiConfig.updateAdminEndpoint}/$adminId"),
                headers: headers,
                body: json.encode({
                  if (fullName != null) "full_name": fullName,
                  if (email != null) "email": email,
                  if (currentPassword != null)
                    "current_password": currentPassword,
                  if (newPassword != null) "new_password": newPassword,
                }),
              )
              .timeout(const Duration(seconds: 10));
          break;
        } on TimeoutException catch (_) {
          continue;
        } on SocketException catch (_) {
          continue;
        } catch (_) {
          continue;
        }
      }

      if (response == null) {
        throw Exception("Could not reach the server.");
      }

      final data = json.decode(response.body);
      bool isSuccess = false;
      if (data['success'] is bool) {
        isSuccess = data['success'];
      } else if (data['success'] is String) {
        isSuccess = data['success'].toLowerCase() == 'true';
      } else if (data['success'] is int) {
        isSuccess = data['success'] == 1;
      }

      if (response.statusCode == 200 && isSuccess) {
        var admin = data['admin'];
        return {
          "id": admin["id"] as int,
          "username": admin["username"] as String,
          "email": admin["email"] as String?,
          "full_name": admin["full_name"] as String?,
          "last_login": admin["last_login"] as String?,
          "created_at": admin["created_at"] as String?,
          if (admin["role"] != null) "role": admin["role"],
          if (admin["password_changed_at"] != null)
            "password_changed_at": admin["password_changed_at"],
        };
      }
      if (response.statusCode == 400 || !isSuccess) {
        throw Exception(data['message'] ?? 'Bad request');
      }
      if (response.statusCode == 404) {
        throw Exception("Admin profile not found");
      }
      if (response.statusCode == 500) {
        throw Exception("Server error. Please try again later.");
      }
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    } catch (e) {
      throw Exception("Failed to update admin profile: $e");
    }
  }
}