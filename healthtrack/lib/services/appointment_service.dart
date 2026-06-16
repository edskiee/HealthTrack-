import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'error_handler_service.dart';
import 'api_config.dart';
import '../admin/services/admin_session_storage.dart';
import 'user_session_storage.dart';

class AppointmentService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }
  
  // Fallback URLs to try if the primary URL fails
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Headers for admin-protected endpoints (Bearer opaque token)
  static Future<Map<String, String>> _adminHeaders() async {
    final token = await AdminSessionStorage.getToken();
    // DEBUG — remove once 401s are resolved
    print('[AppointmentService] _adminHeaders() token='
        '${token == null ? "NULL" : token.isEmpty ? "EMPTY" : "${token.substring(0, token.length.clamp(0, 10))}..."}');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Headers for user-protected endpoints (Bearer JWT)
  static Future<Map<String, String>> _userHeaders() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all appointments for a user
  static Future<List<Map<String, dynamic>>> getUserAppointments(String userId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/user/$userId"),
          headers: await _userHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch appointments');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch appointments");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch appointments: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch appointments");
  }

  /// Get upcoming approved appointments for a user (for dashboard)
  static Future<List<Map<String, dynamic>>> getUserUpcomingAppointments(String userId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/user/$userId/upcoming"),
          headers: await _userHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch upcoming appointments');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch upcoming appointments");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch upcoming appointments: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch upcoming appointments");
  }

  /// Get all appointments (for admin)
  static Future<List<Map<String, dynamic>>> getAllAppointments() async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments"),
          headers: await _adminHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch appointments');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch appointments");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch appointments: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch appointments");
  }

  /// Add a new appointment with comprehensive validation and duplicate prevention
  static Future<Map<String, dynamic>> addAppointment(Map<String, dynamic> appointmentData) async {
    try {
      // Convert frontend field names to backend field names
      final Map<String, dynamic> backendData = {
        'user_id': appointmentData['userId'],
        'patient_id': appointmentData['patientId'],
        'doctor_name': appointmentData['doctorName'],
        'clinic_hospital': appointmentData['clinicHospital'],
        'appointment_date': appointmentData['appointmentDate'],
        'appointment_time': appointmentData['appointmentTime'],
        'appointment_type': appointmentData['appointmentType'],
        'notes': appointmentData['notes'],
        // Always use 'pending' as the initial status for new appointments
        'status': 'pending',
      };
      
      // Include slotId if provided for auto-approval
      if (appointmentData.containsKey('slotId')) {
        backendData['slot_id'] = appointmentData['slotId'];
      }

      // Validate appointment data
      final validationError = ValidationService.validateAppointmentData(appointmentData);
      if (validationError != null) {
        ErrorHandlerService.handleValidationError('appointment', validationError);
        return {
          'success': false,
          'message': validationError,
          'error': 'Validation failed',
        };
      }

      // Check for duplicate requests
      final requestKey = DuplicatePreventionService().generateRequestKey('add_appointment', appointmentData);
      if (DuplicatePreventionService().isDuplicateRequest(requestKey)) {
        return {
          'success': false,
          'message': 'Duplicate appointment request detected. Please wait a moment before trying again.',
          'error': 'Duplicate request',
        };
      }

      // Try each URL in the fallback list until one works
      Exception? lastException;
      for (final url in fallbackBaseUrls) {
        try {
          final response = await http.post(
            Uri.parse("$url/appointments"),
            headers: await _userHeaders(),
            body: json.encode(backendData),
          ).timeout(const Duration(seconds: 10));

          // Clear duplicate prevention after successful request
          DuplicatePreventionService().clearRequestHistory(requestKey);

          if (response.statusCode == 200 || response.statusCode == 201) {
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
            
            return {
              'success': isSuccess,
              'message': data['message'] ?? 'Appointment added successfully',
              'data': data['data'] ?? {},
            };
          } else {
            final data = json.decode(response.body);
            final errorMessage = data['message'] ?? 'Failed to add appointment';
            final errorType = data['error_type'] ?? 'unknown_error';
            
            // Return specific error information instead of throwing exception
            return {
              'success': false,
              'message': errorMessage,
              'error': errorType,
              'error_code': data['error_code'],
              'code': data['code'], // pass through backend code (e.g. ACTIVE_APPOINTMENT_EXISTS)
              'existingAppointment': data['existingAppointment'], // for active appointment block
            };
          }
        } on SocketException {
          lastException = Exception("No internet connection. Please check your network and try again.");
          // Continue to try the next URL
        } on TimeoutException {
          lastException = Exception("Request timeout. Please try again.");
          // Continue to try the next URL
        } catch (e) {
          lastException = Exception("Failed to add appointment: $e");
          // Continue to try the next URL
        }
      }

      // If we've tried all URLs and none worked, throw the last exception
      ErrorHandlerService.handleError(lastException ?? Exception('Failed to add appointment'), context: 'add_appointment');
      throw lastException ?? Exception('Failed to add appointment');
    } catch (e) {
      ErrorHandlerService.handleError(e, context: 'add_appointment');
      return {
        'success': false,
        'message': 'Failed to add appointment: ${e.toString()}',
        'error': 'unknown_error',
      };
    }
  }

  /// Update appointment status (approve, cancel, reschedule) with validation and error handling
  static Future<Map<String, dynamic>> updateAppointmentStatus(
    String appointmentId,
    String status, {
    String? rescheduleDate,
    String? rescheduleTime,
    String? notes
  }) async {
    // Validate status
    final validStatuses = [
      'approved',
      'cancelled',
      'rescheduled',
      'pending',
      'completed',
      'no_show',
    ];
    if (!validStatuses.contains(status)) {
      ErrorHandlerService.handleValidationError('status', 'Invalid status: $status');
      return {
        'success': false,
        'message': 'Invalid status: $status',
        'error': 'Validation failed',
      };
    }

    // Validate reschedule data if status is rescheduled
    if (status == 'rescheduled') {
      if (rescheduleDate == null || rescheduleTime == null) {
        ErrorHandlerService.handleValidationError('reschedule', 'Reschedule date and time are required for rescheduled status');
        return {
          'success': false,
          'message': 'Reschedule date and time are required for rescheduled status',
          'error': 'Validation failed',
        };
      }
      
      if (!ValidationService.validateDate(rescheduleDate)) {
        ErrorHandlerService.handleValidationError('rescheduleDate', 'Invalid reschedule date format');
        return {
          'success': false,
          'message': 'Invalid reschedule date format',
          'error': 'Validation failed',
        };
      }
      
      if (!ValidationService.validateTime(rescheduleTime)) {
        ErrorHandlerService.handleValidationError('rescheduleTime', 'Invalid reschedule time format');
        return {
          'success': false,
          'message': 'Invalid reschedule time format',
          'error': 'Validation failed',
        };
      }
    }

    // Try each URL in the fallback list until one works
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final apiUrl = Uri.parse('$url/appointments/status/$appointmentId');
        
        final response = await http.put(
          apiUrl,
          headers: await _adminHeaders(),
          body: jsonEncode({
            'status': status,
            'rescheduleDate': rescheduleDate,
            'rescheduleTime': rescheduleTime,
            'notes': notes,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // If the update was successful, send a notification to the user
          if (data['success'] ?? false) {
            try {
              // Get the updated appointment data
              final appointmentData = data['data'] as Map<String, dynamic>?;
              if (appointmentData != null) {
                // Backend handles all notifications automatically when status is updated.
                // No client-side notification call needed here.
              }
            } catch (notificationError) {
              print('Warning: Failed to send notification after appointment status update: $notificationError');
              // Don't fail the entire operation if notification sending fails
            }
          }
          
          return {
            'success': data['success'] ?? false,
            'message': data['message'] ?? 'Status updated successfully',
            'data': data['data'],
          };
        } else {
          final data = jsonDecode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to update status');
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception('Network error: $e');
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return error
    ErrorHandlerService.handleError(lastException ?? Exception('Failed to update status'), context: 'update_appointment_status');
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to update status',
      'error': 'Connection error',
    };
  }

  /// Get appointment notifications for a user
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/notifications/$userId"),
          headers: await _userHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch notifications');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch notifications");
            // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch notifications: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch notifications");
  }

  /// Mark notification as read
  static Future<bool> markNotificationAsRead(String notificationId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.put(
          Uri.parse("$url/appointments/notifications/read/$notificationId"),
          headers: await _userHeaders(),
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
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to mark notification as read');
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to mark notification as read: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to mark notification as read");
  }

  /// Get consultation types
  static Future<List<Map<String, dynamic>>> getConsultationTypes() async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/consultation-types"),
          headers: await _userHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch consultation types');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch consultation types");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch consultation types: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch consultation types");
  }

  /// Get next appointment for a patient
  static Future<Map<String, dynamic>?> getNextAppointment(String patientId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/next/$patientId"),
          headers: await _userHeaders(),
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
            return data['data'] as Map<String, dynamic>?;
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch next appointment');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch next appointment");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch next appointment: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch next appointment");
  }

  /// Get upcoming appointments (for admin dashboard)
  static Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointments/upcoming"),
          headers: await _adminHeaders(),
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
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException = Exception(data['message'] ?? 'Failed to fetch upcoming appointments');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch upcoming appointments");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch upcoming appointments: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch upcoming appointments");
  }

  /// Delete an appointment
  static Future<Map<String, dynamic>> deleteAppointment(String appointmentId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse("$url/appointments/$appointmentId"),
          headers: await _adminHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 204) {
          final data = response.statusCode == 204 ? {} : json.decode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Appointment deleted successfully',
            'data': data['data'] ?? {},
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to delete appointment');
          // Continue to try the next URL
        }
      } on SocketException {
        lastException = Exception("No internet connection. Please check your network and try again.");
        // Continue to try the next URL
      } on TimeoutException {
        lastException = Exception("Request timeout. Please try again.");
        // Continue to try the next URL
      } catch (e) {
        lastException = Exception("Failed to delete appointment: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, log the error and throw the exception
    ErrorHandlerService.handleError(lastException ?? Exception('Failed to delete appointment'), context: 'delete_appointment');
    throw lastException ?? Exception("Failed to delete appointment");
  }
}