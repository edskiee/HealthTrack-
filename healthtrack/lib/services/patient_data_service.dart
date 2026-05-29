import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'api_config.dart'; // Import the new API config

class PatientDataService {
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

  /// Fetch patient data for logged-in user
  static Future<Map<String, dynamic>> fetchUserPatientData(String userId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        print('🔍 Fetching patient data for user ID: $userId');
        print('🌐 Using base URL: $url');

        final response = await http.get(
          Uri.parse("$url/patients/user/$userId"),
          headers: _headers,
        ).timeout(const Duration(seconds: 10));

        print('📡 Response status: ${response.statusCode}');
        print('📄 Response body: ${response.body}');

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
          
          // Check if the response has success=true
          if (isSuccess && data['data'] != null) {
            return {
              'success': true,
              'message': data['message'] ?? 'Patient data fetched successfully',
              'data': data['data'],
            };
          } else if (data['data'] != null) {
            // Some responses might not have success field but still have data
            return {
              'success': true,
              'message': 'Patient data fetched successfully',
              'data': data['data'],
            };
          } else {
            lastException = Exception(data['message'] ?? 'No patient data found for this user');
            // Continue to try the next URL
          }
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to fetch patient data');
          // Continue to try the next URL
        }
      } catch (e) {
        print('💥 Exception in fetchUserPatientData: $e');
        lastException = Exception('Failed to fetch patient data: $e');
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to fetch patient data',
      'data': {},
    };
  }

  /// Create new patient record
  static Future<Map<String, dynamic>> createPatientRecord(Map<String, dynamic> patientData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        print('📝 Creating new patient record: $patientData');
        print('🌐 Using base URL: $url');

        final response = await http.post(
          Uri.parse("$url/patients"),
          headers: _headers,
          body: json.encode(patientData),
        ).timeout(const Duration(seconds: 10));

        print('📡 Response status: ${response.statusCode}');
        print('📄 Response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          
          return {
            'success': true,
            'message': data['message'] ?? 'Patient record created successfully',
            'data': data['data'] ?? data['patient'] ?? data,
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to create patient record');
          // Continue to try the next URL
        }
      } catch (e) {
        print('💥 Exception in createPatientRecord: $e');
        lastException = Exception('Failed to create patient record: $e');
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to create patient record',
      'data': {},
    };
  }

  /// Update existing patient record
  static Future<Map<String, dynamic>> updatePatientRecord(String patientId, Map<String, dynamic> patientData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        print('📝 Updating patient record $patientId: $patientData');
        print('🌐 Using base URL: $url');

        final response = await http.put(
          Uri.parse("$url/patients/$patientId"),
          headers: _headers,
          body: json.encode(patientData),
        ).timeout(const Duration(seconds: 10));

        print('📡 Response status: ${response.statusCode}');
        print('📄 Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          return {
            'success': true,
            'message': data['message'] ?? 'Patient record updated successfully',
            'data': data['data'] ?? data['patient'] ?? data,
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to update patient record');
          // Continue to try the next URL
        }
      } catch (e) {
        print('💥 Exception in updatePatientRecord: $e');
        lastException = Exception('Failed to update patient record: $e');
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to update patient record',
      'data': {},
    };
  }

  /// Load user session data (call after login)
  static Future<bool> loadUserSessionData() async {
    final userSession = UserSession.instance;
    
    if (!userSession.isLoggedIn) {
      print('❌ No user logged in');
      return false;
    }

    try {
      // Fetch patient data for the logged-in user
      final result = await fetchUserPatientData(userSession.userId);
      
      // Robust type checking for success field
      bool isSuccess = false;
      if (result['success'] is bool) {
        isSuccess = result['success'];
      } else if (result['success'] is String) {
        isSuccess = result['success'].toLowerCase() == 'true';
      } else if (result['success'] is int) {
        isSuccess = result['success'] == 1;
      }
      
      if (isSuccess && result['data'] != null) {
        // Store patient data in session
        userSession.setPatientData(result['data']);
        userSession.printSessionInfo();
        return true;
      } else {
        print('❌ Failed to load patient data: ${result['message']}');
        // Try to create a new patient record if none exists
        final createResult = await createPatientRecord({
          'user_id': userSession.userId,
          'child_fullname': userSession.userData?['username'] ?? 'Patient',
          'mother_fullname': userSession.userData?['full_name'] ?? 'Parent',
          'dob': '2020-01-01', // Default date of birth
          'sex': userSession.userData?['gender'] ?? 'Male',
          'address': userSession.userData?['address'] ?? '',
          'status': 'active',
        });
        
        // Robust type checking for success field
        bool isCreateSuccess = false;
        if (createResult['success'] is bool) {
          isCreateSuccess = createResult['success'];
        } else if (createResult['success'] is String) {
          isCreateSuccess = createResult['success'].toLowerCase() == 'true';
        } else if (createResult['success'] is int) {
          isCreateSuccess = createResult['success'] == 1;
        }
        
        if (isCreateSuccess && createResult['data'] != null) {
          // Store new patient data in session
          userSession.setPatientData(createResult['data']);
          userSession.printSessionInfo();
          return true;
        }
        
        return false;
      }
    } catch (e) {
      print('❌ Error loading session data: $e');
      return false;
    }
  }
}