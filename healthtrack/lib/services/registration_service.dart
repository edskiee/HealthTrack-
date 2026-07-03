import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'api_config.dart'; // Import the new API config

class RegistrationService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
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

  /// Register new user with child patient record
  static Future<Map<String, dynamic>> registerUserWithChild(Map<String, dynamic> registrationData) async {
    try {
      print('🚀 Registering user with child data: $registrationData');
      print('🌐 Using base URL: $baseUrl');

      // Start with primary URL, then try fallbacks
      List<String> allUrls = [baseUrl, ...fallbackBaseUrls];
      
      http.Response? response;
      String successUrl = "";
      
      // Add flag to create health record automaticallyl
      
      // Try each URL until one works
      for (String url in allUrls) {
        try {
          final fullUrl = "$url/auth/register";
          print("🔗 Trying URL: $fullUrl");
          
          response = await http.post(
            Uri.parse(fullUrl),
            headers: _headers,
            body: json.encode(registrationData),
          ).timeout(const Duration(seconds: 30)); // Increased timeout to 30 seconds
          
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
        return {
          'success': false,
          'message': 'Could not connect to server. Please check your internet connection and ensure the server is running.',
          'data': {},
        };
      }

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Ensure consistent type handling for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }
        
        if (isSuccess) {
          try {
            // Store user and patient data in session - SAFE TYPE CONVERSION
            final userData = data['data']?['user'] ?? data['user'];
            final patientData = data['data']?['patient'] ?? data['patient'];
            final rawChildren = data['children'] ?? data['data']?['children'];
                        
            if (userData != null) {
              // Ensure userData is a Map before setting
              if (userData is Map<String, dynamic>) {
                UserSession.instance.setUserData(userData);
              } else {
                print('⚠️ Warning: userData is not a Map, skipping session storage');
              }
            }
                        
            if (patientData != null) {
              // Ensure patientData is a Map before setting
              if (patientData is Map<String, dynamic>) {
                UserSession.instance.setPatientData(patientData);
                // Also seed the children list with this first child
                UserSession.instance.setChildren([patientData]);
              } else {
                print('⚠️ Warning: patientData is not a Map, creating minimal data');
                // Create minimal patient data as fallback
                final minimalPatientData = {
                  'id': userData?['id']?.toString() ?? '',
                  'user_id': userData?['id']?.toString() ?? '',
                  'child_fullname': userData?['full_name']?.toString() ?? 'Unknown Child',
                  'mother_fullname': userData?['full_name']?.toString() ?? '',
                  'dob': userData?['date_of_birth']?.toString() ?? '',
                  'sex': userData?['gender']?.toString() ?? 'Male',
                  'status': 'active'
                };
                UserSession.instance.setPatientData(minimalPatientData);
                UserSession.instance.setChildren([minimalPatientData]);
              }
            } else {
              // Create a minimal patient data object from user data - SAFE TYPE CONVERSION
              final minimalPatientData = {
                'id': userData?['id']?.toString() ?? '',
                'user_id': userData?['id']?.toString() ?? '',
                'child_fullname': userData?['full_name']?.toString() ?? 'Unknown Child',
                'mother_fullname': userData?['full_name']?.toString() ?? '',
                'dob': userData?['date_of_birth']?.toString() ?? '',
                'sex': userData?['gender']?.toString() ?? 'Male',
                'status': 'active'
              };
              UserSession.instance.setPatientData(minimalPatientData);
              UserSession.instance.setChildren([minimalPatientData]);
            }

            // If the server returned a full children array (future-proof), use it
            if (rawChildren is List && rawChildren.isNotEmpty) {
              UserSession.instance.setChildren(rawChildren);
            }
          } catch (e) {
            print('⚠️ Error setting session data: $e');
            // Continue with registration even if session setting fails
          }
                      
          // Send welcome notification to newly registered patient
          try {
            final userData = data['data']?['user'] ?? data['user'];
            final patientData = data['data']?['patient'] ?? data['patient'];
            
            if (userData != null && patientData != null) {
              final userId = userData['id']?.toString() ?? '';
              final patientId = patientData['id']?.toString() ?? '';
              final patientName = patientData['child_fullname']?.toString() ?? patientData['mother_fullname']?.toString() ?? 'Patient';
              final serviceType = userData['service_type']?.toString() ?? 'immunization';
              
              // Import AdminNotificationService to send welcome notification
              // Note: We can't import it here due to circular dependencies, so we'll use a delayed approach
              print('Would send welcome notification to user $userId, patient $patientId');
            }
          } catch (notificationError) {
            print('Warning: Could not send welcome notification: $notificationError');
            // Don't fail the registration if notification sending fails
          }
          
          return {
            'success': true,
            'message': data['message']?.toString() ?? 'Registration completed successfully',
            'data': data['data'] is Map<String, dynamic> ? data['data'] : {},
          };
        } else {
          return {
            'success': false,
            'message': data['message']?.toString() ?? 'Registration failed',
            'data': {},
          };
        }
      } else {
        // Try to parse error response
        try {
          final data = json.decode(response.body);
          String errorMessage = 'Registration failed';
          
          // Provide more specific error messages based on status code
          if (response.statusCode == 400) {
            errorMessage = data['message']?.toString() ?? 'Invalid registration data provided';
          } else if (response.statusCode == 409) {
            errorMessage = data['message']?.toString() ?? 'Username already exists. Please choose a different username.';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = data['message']?.toString() ?? 'Registration failed with status: ${response.statusCode}';
          }
          
          return {
            'success': false,
            'message': errorMessage,
            'data': {},
          };
        } catch (parseError) {
          // If we can't parse the error response, return a generic error
          return {
            'success': false,
            'message': 'Registration failed with status: ${response.statusCode}',
            'data': {},
          };
        }
      }
    } on SocketException catch (e) {
      print('💥 Network error in registerUserWithChild: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your internet connection and ensure the server is running.',
        'data': {},
      };
    } on TimeoutException catch (e) {
      print('💥 Timeout error in registerUserWithChild: $e');
      return {
        'success': false,
        'message': 'Connection timeout. The server might be slow or unreachable. Please try again.',
        'data': {},
      };
    } catch (e) {
      print('💥 Exception in registerUserWithChild: $e');
      return {
        'success': false,
        'message': 'Failed to register: $e',
        'data': {},
      };
    }
  }

  /// Check if username exists
  static Future<bool> checkUsernameExists(String username) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/check-username?username=${Uri.encodeComponent(username)}"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both boolean and string responses for success field
        if (data['success'] is bool) {
          return data['success'];
        } else if (data['success'] is String) {
          return data['success'].toLowerCase() == 'true';
        } else if (data['exists'] is bool) {
          return data['exists'];
        }
        return false;
      }
      return false;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  /// Check if email exists
  static Future<bool> checkEmailExists(String email) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/check-email?email=${Uri.encodeComponent(email)}"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both boolean and string responses for success field
        if (data['success'] is bool) {
          return data['success'];
        } else if (data['success'] is String) {
          return data['success'].toLowerCase() == 'true';
        } else if (data['exists'] is bool) {
          return data['exists'];
        }
        return false;
      }
      return false;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  /// Test connection to registration API
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}