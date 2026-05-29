import 'dart:convert';
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for SocketException
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AppointmentSlotService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Get available appointment slots for a service on a specific date
  static Future<List<Map<String, dynamic>>> getAvailableSlots(
      int serviceId, String date) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointment-slots/available?serviceId=$serviceId&date=$date"),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch available slots');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch available slots");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        print('Network error: $e');
        lastException = Exception("Failed to fetch available slots: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch available slots");
  }

  /// Get all appointment slots for admin view
  static Future<List<Map<String, dynamic>>> getAllSlots({
    int? serviceId,
    String? date,
  }) async {
    Exception? lastException;
      
    // Build query parameters
    final queryParams = <String, String>{};
    if (serviceId != null) queryParams['serviceId'] = serviceId.toString();
    if (date != null) queryParams['date'] = date;
      
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
      
    final urlPath = queryString.isEmpty 
        ? '/appointment-slots' 
        : '/appointment-slots?$queryString';
      
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url$urlPath'),
        ).timeout(const Duration(seconds: 10));
  
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch appointment slots');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch appointment slots");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to fetch appointment slots: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch appointment slots");
  }
  
  /// Get user-viewable slots (shows all slots including booked ones for display)
  /// This endpoint returns all slots but filters based on actual availability
  static Future<List<Map<String, dynamic>>> getUserViewableSlots({
    int? serviceId,
    String? date,
  }) async {
    Exception? lastException;
      
    // Build query parameters
    final queryParams = <String, String>{};
    if (serviceId != null) queryParams['serviceId'] = serviceId.toString();
    if (date != null) queryParams['date'] = date;
      
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
      
    final urlPath= queryString.isEmpty 
        ? '/appointment-slots/user-view' 
        : '/appointment-slots/user-view?$queryString';
      
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url$urlPath'),
        ).timeout(const Duration(seconds: 10));
  
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch user-viewable slots');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch user-viewable slots");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to fetch user-viewable slots: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch user-viewable slots");
  }

  /// Get slots by specific date (for real-time updates)
  static Future<List<Map<String, dynamic>>> getSlotsByDate({
    required int serviceId,
    required String date,
  }) async {
    Exception? lastException;
    
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointment-slots/available?serviceId=$serviceId&date=$date"),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch slots for date');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch slots for date");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to fetch slots for date: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch slots for date");
  }

  /// Create a new appointment slot
  static Future<Map<String, dynamic>> createSlot({
    required int serviceId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
    int maxPatients = 10,
    bool generateSlots = false, // Add this new parameter
  }) async {
    Exception? lastException;
    
    // Log the attempt to create a slot
    print('🔵 Attempting to create appointment slot');
    print('   Service ID: $serviceId');
    print('   Date: $appointmentDate');
    print('   Start time: $startTime');
    print('   End time: $endTime');
    print('   Generate slots: $generateSlots');
    print('   Fallback URLs: ${fallbackBaseUrls.join(", ")}');
    
    for (final url in fallbackBaseUrls) {
      try {
        print('🌐 Trying URL: $url');
        final uri = Uri.parse('$url/appointment-slots');
        print('   Full URI: $uri');
        
        final requestBody = {
          'service_id': serviceId,
          'appointment_date': appointmentDate,
          'start_time': startTime,
          'end_time': endTime,
          'slot_duration_minutes': slotDurationMinutes,
          'max_patients': maxPatients,
          'generate_slots': generateSlots,
        };
        
        print('📦 Request body: ${json.encode(requestBody)}');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw http.ClientException(
              'Request timed out after 30 seconds. The server took too long to respond. ' +
              'Try generating fewer slots or check server performance.',
              uri,
            );
          },
        );

        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body}');
        
        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          print('✅ Slot created successfully: ${data['message']}');
          return data;
        } else {
          final data = json.decode(response.body);
          final errorMessage = data['message'] ?? "HTTP ${response.statusCode}: Failed to create appointment slot";
          print('❌ Server error: $errorMessage');
          lastException = Exception(errorMessage);
        }
      } on http.ClientException catch (e) {
        // Network-level errors
        final errorMessage = _formatNetworkError(e, url);
        print('❌ Network error: $errorMessage');
        lastException = Exception(errorMessage);
      } on TimeoutException catch (e) {
        final errorMessage = "⏱️ Request timed out. Please try again with a smaller time range or fewer slots.";
        print('❌ Timeout error: $errorMessage');
        lastException = Exception(errorMessage);
      } catch (e) {
        final errorMessage = "❌ Failed to create appointment slot: ${e.toString()}. URL tried: $url";
        print('❌ General error: $errorMessage');
        lastException = Exception(errorMessage);
      }
    }
    
    final finalError = lastException ?? Exception("Failed to create appointment slot after trying all endpoints: ${fallbackBaseUrls.join(', ')}");
    print('💥 All attempts failed. Final error: $finalError');
    throw finalError;
  }
  
  /// Helper method to format network errors in a user-friendly way
  static String _formatNetworkError(http.ClientException e, String attemptedUrl) {
    final message = e.message.toLowerCase();
    
    if (message.contains('socketexception') || message.contains('failed host')) {
      return "🔌 Cannot connect to server at $attemptedUrl. " +
             "Please ensure:\n" +
             "• The backend server is running (run: cd backend_nodejs && node src/server.js)\n" +
             "• Your network connection is active\n" +
             "• Firewall is not blocking port 3000";
    } else if (message.contains('timed out')) {
      return "⏱️ Connection timed out to $attemptedUrl. " +
             "The server may be busy or unreachable.";
    } else if (message.contains('permission denied')) {
      return "🚫 Permission denied connecting to $attemptedUrl. " +
             "Check firewall settings.";
    } else {
      return "🌐 Network error connecting to $attemptedUrl: ${e.message}. " +
             "Please check your network connection and server status.";
    }
  }

  /// Update an appointment slot
  static Future<Map<String, dynamic>> updateSlot({
    required int slotId,
    int? serviceId,
    String? appointmentDate,
    String? startTime,
    String? endTime,
    int? slotDurationMinutes,
    int? maxPatients,
    bool? isAvailable,
  }) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final updateData = <String, dynamic>{};
        
        if (serviceId != null) updateData['service_id'] = serviceId;
        if (appointmentDate != null) updateData['appointment_date'] = appointmentDate;
        if (startTime != null) updateData['start_time'] = startTime;
        if (endTime != null) updateData['end_time'] = endTime;
        if (slotDurationMinutes != null) updateData['slot_duration_minutes'] = slotDurationMinutes;
        if (maxPatients != null) updateData['max_patients'] = maxPatients;
        if (isAvailable != null) updateData['is_available'] = isAvailable;
        
        final response = await http.put(
          Uri.parse('$url/appointment-slots/$slotId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updateData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          final data = json.decode(response.body);
          lastException =
              Exception(data['message'] ?? "HTTP ${response.statusCode}: Failed to update appointment slot");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to update appointment slot: $e");
      }
    }
    throw lastException ?? Exception("Failed to update appointment slot");
  }

  /// Delete an appointment slot
  static Future<Map<String, dynamic>> deleteSlot(int slotId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse('$url/appointment-slots/$slotId'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          final data = json.decode(response.body);
          lastException =
              Exception(data['message'] ?? "HTTP ${response.statusCode}: Failed to delete appointment slot");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to delete appointment slot: $e");
      }
    }
    throw lastException ?? Exception("Failed to delete appointment slot");
  }

  /// Get slots availability for a month (for user calendar)
  static Future<Map<String, dynamic>> getSlotsAvailabilityForMonth({
    required int serviceId,
    required int year,
    required int month,
  }) async {
    Exception? lastException;
    
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointment-slots/availability?serviceId=$serviceId&year=$year&month=$month"),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return data;
          } else {
            lastException =
                Exception(data['message'] ?? 'Failed to fetch slots availability for month');
          }
        } else {
          lastException =
              Exception("HTTP ${response.statusCode}: Failed to fetch slots availability for month");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to fetch slots availability for month: $e");
      }
    }
    throw lastException ?? Exception("Failed to fetch slots availability for month");
  }

  /// Book an appointment slot
  static Future<Map<String, dynamic>> bookSlot(int slotId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.post(
          Uri.parse("$url/appointment-slots/book"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'slotId': slotId}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          final data = json.decode(response.body);
          lastException =
              Exception(data['message'] ?? "HTTP ${response.statusCode}: Failed to book slot");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to book slot: $e");
      }
    }
    throw lastException ?? Exception("Failed to book slot");
  }

  /// Delete all appointment slots with optional filtering
  static Future<Map<String, dynamic>> deleteAllSlots({
    int? serviceId,
    String? date,
  }) async {
    Exception? lastException;
    
    // Build query parameters
    final queryParams = <String, String>{};
    if (serviceId != null) queryParams['serviceId'] = serviceId.toString();
    if (date != null) queryParams['date'] = date;
      
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
      
    final urlPath = queryString.isEmpty 
        ? '/appointment-slots' 
        : '/appointment-slots?$queryString';
    
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse('$url$urlPath'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 30)); // Increased timeout for bulk operations

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          final data = json.decode(response.body);
          lastException =
              Exception(data['message'] ?? "HTTP ${response.statusCode}: Failed to delete appointment slots");
        }
      } on TimeoutException {
        lastException = Exception("Request timed out. Please check your connection and try again.");
      } catch (e) {
        lastException = Exception("Failed to delete appointment slots: $e");
      }
    }
    throw lastException ?? Exception("Failed to delete appointment slots");
  }
}