import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config
import 'fcm_service.dart';
import '../admin/services/admin_session_storage.dart';

class AdminNotificationService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Headers with admin auth token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Fallback plain headers (kept for cases where auth is not required)
  // ignore: unused_element
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Try URL with fallback mechanism
  static Future<http.Response> _requestWithFallback(String method, String path, {Map<String, String>? headers, dynamic body}) async {
    // Use auth headers by default if no custom headers provided
    final effectiveHeaders = headers ?? await _authHeaders();
    try {
      final uri = Uri.parse("$baseUrl$path");
      print("Trying primary URL: $uri with method: $method");

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: effectiveHeaders);
          break;
        case 'POST':
          response = await http.post(uri, headers: effectiveHeaders, body: body);
          break;
        case 'PUT':
          response = await http.put(uri, headers: effectiveHeaders, body: body);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: effectiveHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.headers['content-type']?.contains('text/html') ?? false) {
        throw Exception('Server returned HTML instead of JSON');
      }

      return response;
    } catch (e) {
      print("Primary URL failed: $e");
      for (final fallbackUrl in ApiConfig.fallbackBaseUrls) {
        try {
          if (fallbackUrl.isEmpty) continue;
          final uri = Uri.parse("$fallbackUrl$path");
          print("Trying fallback URL: $uri with method: $method");

          late http.Response response;
          switch (method.toUpperCase()) {
            case 'GET':
              response = await http.get(uri, headers: effectiveHeaders);
              break;
            case 'POST':
              response = await http.post(uri, headers: effectiveHeaders, body: body);
              break;
            case 'PUT':
              response = await http.put(uri, headers: effectiveHeaders, body: body);
              break;
            case 'DELETE':
              response = await http.delete(uri, headers: effectiveHeaders);
              break;
            default:
              throw Exception('Unsupported HTTP method: $method');
          }

          if (response.headers['content-type']?.contains('text/html') ?? false) {
            print("Fallback URL returned HTML");
            continue;
          }

          print("Successfully connected to fallback URL: $fallbackUrl");
          return response;
        } catch (fallbackError) {
          print("Fallback URL failed: $fallbackError");
          continue;
        }
      }
      rethrow;
    }
  }

  /// Send a welcome notification to a newly registered patient
  static Future<Map<String, dynamic>> sendWelcomeNotification({
    required String userId,
    required String patientId,
    required String patientName,
    String serviceType = 'immunization',
  }) async {
    try {
      final title = "Welcome to HealthTrack!";
      final message = serviceType == 'maternal' 
        ? "Welcome $patientName! Your maternal care account has been successfully created. You'll receive important health reminders and updates."
        : "Welcome $patientName! Your immunization account has been successfully created. You'll receive vaccination reminders and health updates.";

      final response = await _requestWithFallback(
        'POST',
        "/admin/notifications/send",
        body: json.encode({
          'userId': userId,
          'patientId': patientId,
          'notificationType': 'system',
          'title': title,
          'message': message,
        }),
      );

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
          return {
            'success': true,
            'message': 'Welcome notification sent successfully',
            'data': data['data'] ?? {},
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to send welcome notification',
          };
        }
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send welcome notification',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send welcome notification: $e',
      };
    }
  }

  // Get pending appointments count
  static Future<int> getPendingAppointmentsCount() async {
    try {
      final response = await _requestWithFallback('GET', "/admin/appointments/pending-count");

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
          return data['count'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch pending count');
        }
      } else if (response.statusCode == 404) {
        // Return 0 for 404 - no pending appointments found
        return 0;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch pending count");
      }
    } catch (e) {
      print("Error fetching pending appointments count: $e");
      // Return 0 instead of throwing to prevent UI crashes
      return 0;
    }
  }
  
  // Stream for real-time pending appointments count
  static Stream<int> streamPendingAppointmentsCount({Duration refreshInterval = const Duration(seconds: 30)}) {
    // Create a stream controller
    final controller = StreamController<int>();
    
    // Function to fetch and add count to stream
    Future<void> fetchAndAddToStream() async {
      try {
        final count = await getPendingAppointmentsCount();
        if (!controller.isClosed) {
          controller.add(count);
        }
      } catch (e) {
        print("Error in streamPendingAppointmentsCount: $e");
        if (!controller.isClosed) {
          // Add 0 on error to prevent stream errors
          controller.add(0);
        }
      }
    }
    
    // Fetch immediately
    fetchAndAddToStream();
    
    // Set up periodic fetching with timer reference for cleanup
    final timer = Timer.periodic(refreshInterval, (_) => fetchAndAddToStream());
    
    // Add timer cancellation to the controller's onCancel callback
    controller.onCancel = () {
      timer.cancel();
      controller.close();
    };
    
    // Return the stream as broadcast stream for multiple listeners
    return controller.stream.asBroadcastStream();
  }

  // Send appointment status update notification
  static Future<Map<String, dynamic>> sendAppointmentStatusNotification({
    required String userId,
    required String appointmentId,
    required String status,
    required String message,
    String? userToken, // optional: pass user JWT when called from user context
  }) async {
    try {
      // Get FCM token
      String? fcmToken;
      try {
        fcmToken = await FCMService.getToken();
        print('Retrieved FCM token for status update: ${fcmToken != null ? "${fcmToken.substring(0, 20)}..." : "None"}');
      } catch (tokenError) {
        print('Warning: Could not retrieve FCM token for status update: $tokenError');
        // Continue without FCM token - notification will still be stored in database
      }

      final requestBody = json.encode({
        'userId': userId,
        'appointmentId': appointmentId,
        'notificationType': 'status_update',
        'message': message,
        'title': 'Appointment Status Update',
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      });

      print('Sending appointment status notification with request body: $requestBody');

      // If a user token is provided, use it; otherwise fall back to admin token
      final Map<String, String>? overrideHeaders = userToken != null && userToken.isNotEmpty
          ? {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $userToken',
            }
          : null;

      final response = await _requestWithFallback(
        'POST',
        "/admin/notifications/send-status",
        headers: overrideHeaders,
        body: requestBody,
      );

      print('Received response for status notification: ${response.statusCode} - ${response.body}');

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
          return data['data'] ?? {};
        } else {
          throw Exception(data['message'] ?? 'Failed to send status notification');
        }
      } else if (response.statusCode == 404) {
        // More descriptive error message for 404
        if (response.headers['content-type']?.contains('text/html') ?? false) {
          throw Exception('Status notification endpoint not found. Please check if the server is running and the network configuration is correct.');
        } else {
          // If it's JSON, parse the actual error message
          try {
            final data = json.decode(response.body);
            throw Exception(data['message'] ?? 'Status notification endpoint returned 404 error.');
          } catch (parseError) {
            throw Exception('Status notification endpoint not found. Please check if the server is running and the network configuration is correct.');
          }
        }
      } else if (response.statusCode >= 500) {
        throw Exception('Server error occurred. Please try again later.');
      } else {
        // Try to parse error response as JSON, fallback to status code
        try {
          final data = json.decode(response.body);
          throw Exception(data['message'] ?? 'Failed to send status notification (HTTP ${response.statusCode})');
        } catch (parseError) {
          throw Exception('Failed to send status notification (HTTP ${response.statusCode}): ${response.body}');
        }
      }
    } on FormatException catch (e) {
      throw Exception('Invalid response from server. The server may be returning HTML instead of JSON. Error: $e');
    } catch (e) {
      print('Error in sendAppointmentStatusNotification: $e');
      // Provide more context-specific error messages
      final errorMessage = e.toString();
      if (errorMessage.contains('SocketException') || errorMessage.contains('Failed host lookup')) {
        throw Exception('Cannot connect to the server. Please check your network connection and ensure the server is running.');
      } else if (errorMessage.contains('Connection refused')) {
        throw Exception('Connection to server was refused. Please check if the server is running on the configured IP and port.');
      } else {
        throw Exception("Failed to send status notification: $e");
      }
    }
  }
}