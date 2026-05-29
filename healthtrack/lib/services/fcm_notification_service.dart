import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class FCMNotificationService {
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Headers for API requests
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Send appointment reminder notification to a patient
  static Future<Map<String, dynamic>> sendAppointmentReminder({
    required String patientId,
    required String title,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-notifications/appointment-reminder'),
        headers: _headers,
        body: json.encode({
          'patientId': patientId,
          'title': title,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'],
          'data': data['data'] ?? {},
        };
      } else {
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'Failed to send appointment reminder';
        
        // Provide more user-friendly error messages
        if (errorMessage.contains('Patient not found')) {
          errorMessage = 'Patient record not found in the system';
        } else if (errorMessage.contains('FCM token')) {
          errorMessage = 'Patient\'s mobile app is not properly registered for notifications. Please ensure they have installed the app and logged in at least once.';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'error': data['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send appointment reminder. Please check your internet connection and try again.',
        'error': 'network_error',
      };
    }
  }

  /// Send general notification to a patient
  static Future<Map<String, dynamic>> sendPatientNotification({
    required String patientId,
    required String title,
    required String message,
    String notificationType = 'general',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-notifications/patient-notification'),
        headers: _headers,
        body: json.encode({
          'patientId': patientId,
          'title': title,
          'message': message,
          'notificationType': notificationType,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] == true,
          'message': data['message'],
          'data': data['data'] ?? {},
        };
      } else {
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'Failed to send notification';
        
        // Provide more user-friendly error messages
        if (errorMessage.contains('Patient not found')) {
          errorMessage = 'Patient record not found in the system';
        } else if (errorMessage.contains('FCM token')) {
          errorMessage = 'Patient\'s mobile app is not properly registered for notifications. Please ensure they have installed the app and logged in at least once.';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'error': data['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send notification. Please check your internet connection and try again.',
        'error': 'network_error',
      };
    }
  }

  /// Check if a patient has a valid FCM token registered
  static Future<Map<String, dynamic>> checkPatientFCMToken({
    required String patientId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-notifications/check-patient-token'),
        headers: _headers,
        body: json.encode({
          'patientId': patientId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] == true,
          'hasValidToken': data['hasValidToken'] ?? false,
          'message': data['message'],
          'data': data['data'] ?? {},
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'hasValidToken': false,
          'message': data['message'] ?? 'Failed to check patient FCM token status',
          'error': data['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'hasValidToken': false,
        'message': 'Failed to check patient FCM token status. Please check your internet connection.',
        'error': 'network_error',
      };
    }
  }
}