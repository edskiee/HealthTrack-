import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config
import 'ip_detection_service.dart'; // Import IP detection service
import 'fcm_service.dart'; // Import FCM service for token management
import 'user_session.dart'; // Import user session for token storage

class AuthService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return "${ApiConfig.baseUrl}/auth";
  }
  
  // List of fallback URLs to try if the primary URL fails
  static List<String> get fallbackBaseUrls => 
    ApiConfig.fallbackBaseUrls.map((url) => "$url/auth").toList();
  
  static String? _authToken;
  
  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  /// User login with enhanced FCM token handling
  static Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      // Try primary URL first
      String currentUrl = baseUrl;
      http.Response? response;
      
      try {
        response = await http.post(
          Uri.parse("$currentUrl/login"),
          headers: _headers,
          body: json.encode({
            'username': email,  // Node.js backend expects 'username' field
            'password': password,
          }),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        print("Failed with primary URL: $e");
        // If primary URL fails, try fallback URLs
        for (String fallbackUrl in fallbackBaseUrls) {
          try {
            print("Trying fallback URL: $fallbackUrl/login");
            response = await http.post(
              Uri.parse("$fallbackUrl/login"),
              headers: _headers,
              body: json.encode({
                'username': email,
                'password': password,
              }),
            ).timeout(const Duration(seconds: 10));
            
            // If we get here, the request succeeded
            currentUrl = fallbackUrl;
            print("Successfully connected to: $currentUrl");
            break;
          } catch (fallbackError) {
            print("Failed with fallback URL $fallbackUrl: $fallbackError");
            // Continue to next URL
          }
        }
      }
      
      // If all URLs failed, try IP detection
      if (response == null) {
        print("Trying IP detection...");
        final detectedUrl = await IpDetectionService.detectServerUrl();
        if (detectedUrl != null) {
          try {
            print("Trying detected URL: $detectedUrl/auth/login");
            response = await http.post(
              Uri.parse("$detectedUrl/auth/login"),
              headers: _headers,
              body: json.encode({
                'username': email,
                'password': password,
              }),
            ).timeout(const Duration(seconds: 10));
            
            if (response != null && response.statusCode == 200) {
              currentUrl = detectedUrl;
              print("Successfully connected to detected URL: $currentUrl");
            }
          } catch (detectionError) {
            print("Failed with detected URL $detectedUrl: $detectionError");
          }
        }
      }
      
      // If all URLs failed
      if (response == null) {
        throw Exception("Could not connect to server. Please ensure the server is running and you have an internet connection.");
      }

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
        // Get the user data from the response
        // FIX: The server returns user data in data['user'], not data['data']
        final userData = data['user'];
        
        // Save FCM token to server after successful login
        _saveFcmTokenAfterLogin(data);
        
        // Return the complete response data so the login screen can access both user and patient info
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception("Failed to login: $e");
    }
  }
  
  /// Sync server-side push preference (Settings toggle). Requires DB column `push_notifications_enabled`.
  static Future<bool> updatePushNotificationPreference({
    required int userId,
    required bool enabled,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pushNotificationPreferenceEndpoint}',
      );
      final response = await http
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'userId': userId,
              'pushNotificationsEnabled': enabled,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final data = json.decode(response.body);
      return data is Map && data['success'] == true;
    } catch (e) {
      print('❌ updatePushNotificationPreference: $e');
      return false;
    }
  }

  /// Fetch server-side push preference for the user.
  static Future<bool?> fetchPushNotificationPreference(int userId) async {
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pushNotificationPreferenceEndpoint}/$userId',
      );
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      if (data is! Map || data['success'] != true) return null;
      return data['pushNotificationsEnabled'] == true;
    } catch (e) {
      print('❌ fetchPushNotificationPreference: $e');
      return null;
    }
  }

  /// Save FCM token to server after successful login
  static Future<void> _saveFcmTokenAfterLogin(Map<String, dynamic>? loginResponse) async {
    try {
      if (loginResponse == null) return;
      
      // Get user ID from login response (correct path)
      // The response structure is: {success: true, message: "...", data: {user: {...}, patient: {...}}}
      final userId = loginResponse['user']?['id'];
      if (userId == null) {
        print('⚠️ User ID not found in login response');
        print('   Response data: $loginResponse');
        return;
      }
      
      // Get current FCM token
      final fcmToken = await FCMService.getToken();
      if (fcmToken == null) {
        print('⚠️ No FCM token available to save');
        return;
      }
      
      // Save token to server
      await _saveFcmTokenToServer(userId, fcmToken);
    } catch (e) {
      print('❌ Error saving FCM token after login: $e');
    }
  }
  
  /// Save FCM token to server
  static Future<void> _saveFcmTokenToServer(int userId, String fcmToken) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/save-fcm-token");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'fcmToken': fcmToken,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ FCM token saved to server successfully after login');
      } else {
        print('❌ Failed to save FCM token to server: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error saving FCM token to server: $e');
    }
  }

  /// Admin login
  static Future<Map<String, dynamic>?> loginAdmin(String username, String password) async {
    try {
      // Use the centralized API configuration
      String adminLoginUrl = "${ApiConfig.baseUrl}/admin/login";
      
      http.Response? response;
      
      try {
        final url = Uri.parse(adminLoginUrl);
        debugPrint("🔗 Trying URL: $url");
        
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': username,
            'password': password,
          }),
        ).timeout(Duration(seconds: 10)); // 10 second timeout
        
        debugPrint("✅ Successfully connected to: $adminLoginUrl");
      } catch (e) {
        debugPrint("❌ Failed to connect to $adminLoginUrl: $e");
        
        // If primary URL fails, try fallback URLs
        for (String fallbackUrl in ApiConfig.fallbackBaseUrls) {
          try {
            String fallbackAdminLoginUrl = "$fallbackUrl/admin/login";
            debugPrint("🔗 Trying fallback URL: $fallbackAdminLoginUrl");
            
            response = await http.post(
              Uri.parse(fallbackAdminLoginUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'username': username,
                'password': password,
              }),
            ).timeout(Duration(seconds: 10));
            
            debugPrint("✅ Successfully connected to fallback URL: $fallbackAdminLoginUrl");
            break; // Exit loop on successful connection
          } catch (fallbackError) {
            debugPrint("❌ Failed to connect to fallback URL $fallbackUrl: $fallbackError");
            continue; // Try next URL
          }
        }
      }
      
      // If all URLs failed, try IP detection
      if (response == null) {
        print("Trying IP detection for admin login...");
        final detectedUrl = await IpDetectionService.detectServerUrl();
        if (detectedUrl != null) {
          try {
            final adminUrl = "$detectedUrl/admin/login";
            print("Trying detected URL: $adminUrl");
            response = await http.post(
              Uri.parse(adminUrl),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'username': username,
                'password': password,
              }),
            ).timeout(const Duration(seconds: 10));
            
            if (response != null && response.statusCode == 200) {
              debugPrint("✅ Successfully connected to detected admin URL: $adminUrl");
            }
          } catch (detectionError) {
            print("Failed with detected admin URL $detectedUrl: $detectionError");
          }
        }
      }
      
      if (response == null) {
        throw Exception("Could not connect to server. Please ensure the server is running and you have an internet connection.");
      }

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }
      
      // Robust type checking for success field
      bool isSuccess = false;
      if (data['success'] is bool) {
        isSuccess = data['success'];
      } else if (data['success'] is String) {
        isSuccess = data['success'].toLowerCase() == 'true';
      } else if (data['success'] is int) {
        isSuccess = data['success'] == 1;
      }
      
      if (response.statusCode == 200 && isSuccess) {
        return data['admin'];
      } else {
        throw Exception(data['message'] ?? 'Admin login failed');
      }
    } catch (e) {
      throw Exception("Failed to admin login: $e");
    }
  }

  /// Register new user
  static Future<bool> registerUser(Map<String, dynamic> userData) async {
    try {
      // Try primary URL first
      String currentUrl = baseUrl;
      http.Response? response;
      
      try {
        response = await http.post(
          Uri.parse("$currentUrl/register"),
          headers: _headers,
          body: json.encode(userData),
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        print("Failed with primary URL: $e");
        // If primary URL fails, try fallback URLs
        for (String fallbackUrl in fallbackBaseUrls) {
          try {
            print("Trying fallback URL: $fallbackUrl/register");
            response = await http.post(
              Uri.parse("$fallbackUrl/register"),
              headers: _headers,
              body: json.encode(userData),
            ).timeout(const Duration(seconds: 10));
            
            // If we get here, the request succeeded
            currentUrl = fallbackUrl;
            print("Successfully connected to: $currentUrl");
            break;
          } catch (fallbackError) {
            print("Failed with fallback URL $fallbackUrl: $fallbackError");
            // Continue to next URL
          }
        }
      }
      
      // If all URLs failed, try IP detection
      if (response == null) {
        print("Trying IP detection for registration...");
        final detectedUrl = await IpDetectionService.detectServerUrl();
        if (detectedUrl != null) {
          try {
            print("Trying detected URL: $detectedUrl/auth/register");
            response = await http.post(
              Uri.parse("$detectedUrl/auth/register"),
              headers: _headers,
              body: json.encode(userData),
            ).timeout(const Duration(seconds: 10));
            
            if (response != null) {
              currentUrl = detectedUrl;
              print("Successfully connected to detected URL: $currentUrl");
            }
          } catch (detectionError) {
            print("Failed with detected URL $detectedUrl: $detectionError");
          }
        }
      }
      
      // If all URLs failed
      if (response == null) {
        throw Exception("Could not connect to server. Please ensure the server is running and you have an internet connection.");
      }

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
        _authToken = data['token'];
        return true;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception("Failed to register user: $e");
    }
  }

  /// Update user profile
  static Future<bool> updateUserProfile(int userId, Map<String, dynamic> userData) async {
    try {
      if (_authToken == null) {
        throw Exception('Not authenticated');
      }

      // Note: This would need a separate API endpoint for profile updates
      // For now, returning true as placeholder
      return true;
    } catch (e) {
      throw Exception("Failed to update user profile: $e");
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      if (_authToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse("$baseUrl?action=profile"),
        headers: _headers,
      );

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
        return data['data'];
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Failed to get user profile: $e");
    }
  }

  /// Change password
  static Future<bool> changePassword(int userId, String oldPassword, String newPassword) async {
    try {
      if (_authToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse("$baseUrl?action=change-password"),
        headers: _headers,
        body: json.encode({
          'current_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
    } catch (e) {
      throw Exception("Failed to change password: $e");
    }
  }

  /// Reset password (admin function)
  static Future<bool> resetUserPassword(int userId, String newPassword) async {
    try {
      if (_authToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse("$baseUrl?action=reset-password"),
        headers: _headers,
        body: json.encode({
          'user_id': userId,
          'new_password': newPassword,
        }),
      );

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
    } catch (e) {
      throw Exception("Failed to reset password: $e");
    }
  }

  /// Check if email exists
  static Future<bool> emailExists(String email) async {
    try {
      // This would need a separate API endpoint
      // For now, returning false as placeholder
      return false;
    } catch (e) {
      throw Exception("Failed to check email: $e");
    }
  }

  /// Check if username exists
  static Future<bool> usernameExists(String username) async {
    try {
      // This would need a separate API endpoint
      // For now, returning false as placeholder
      return false;
    } catch (e) {
      throw Exception("Failed to check username: $e");
    }
  }

  /// Verify token
  static Future<bool> verifyToken() async {
    try {
      if (_authToken == null) {
        return false;
      }

      final response = await http.get(
        Uri.parse("$baseUrl?action=verify"),
        headers: _headers,
      );

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

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
    } catch (e) {
      _authToken = null;
      return false;
    }
  }

  /// Logout
  static void logout() {
    _authToken = null;
  }

  /// Get current auth token
  static String? get authToken => _authToken;

  /// Check if user is authenticated
  static bool get isAuthenticated => _authToken != null;

  /// Check API connection
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse("${baseUrl.replaceAll('/auth', '')}/"),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}