import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../admin/services/admin_session_storage.dart';
import 'user_session_storage.dart';

class AppointmentSlotService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Returns headers with Bearer token for admin-protected endpoints.
  static Future<Map<String, String>> _adminHeaders() async {
    return AdminSessionStorage.authHeaders();
  }

  /// Returns headers with Bearer token for user-protected endpoints.
  static Future<Map<String, String>> _userHeaders() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Plain headers for public (unauthenticated) endpoints.
  static Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Get available appointment slots for a service on a specific date
  static Future<List<Map<String, dynamic>>> getAvailableSlots(
      int serviceId, String date) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/appointment-slots/available?serviceId=$serviceId&date=$date"),
          headers: _publicHeaders,
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
        final headers = await _adminHeaders();
        print('[AppointmentSlotService] GET $url$urlPath headers=$headers');

        final response = await http.get(
          Uri.parse('$url$urlPath'),
          headers: headers,
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
  static Future<List<Map<String, dynamic>>> getUserViewableSlots({
    int? serviceId,
    String? date,
  }) async {
    Exception? lastException;
      
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
          headers: _publicHeaders,
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
          headers: _publicHeaders,
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

        final headers = await _adminHeaders();
        print('[AppointmentSlotService] POST $uri headers=$headers');
        print('[AppointmentSlotService] Authorization present: ${headers.containsKey('Authorization')}');

        final response = await http.post(
          uri,
          headers: headers,
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
          headers: await _adminHeaders(),
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
          headers: await _adminHeaders(),
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
          headers: _publicHeaders,
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
          headers: await _userHeaders(),
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

  /// Delete all appointment slots for a specific date + service (bulk admin action).
  ///
  /// Passes [adminId] for server-side audit logging.
  /// The backend will cascade-cancel any active appointments and send
  /// in-app notifications to affected patients.
  static Future<Map<String, dynamic>> deleteAllSlotsForDate({
    required int serviceId,
    required String date,
    String? adminId,
  }) async {
    Exception? lastException;

    final queryParams = <String, String>{
      'serviceId': serviceId.toString(),
      'date': date,
    };
    if (adminId != null && adminId.isNotEmpty) {
      queryParams['adminId'] = adminId;
    }

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final urlPath = '/appointment-slots?$queryString';

    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse('$url$urlPath'),
          headers: await _adminHeaders(),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        } else {
          final data = json.decode(response.body);
          lastException = Exception(
              data['message'] ?? 'HTTP ${response.statusCode}: Failed to delete all slots');
        }
      } on TimeoutException {
        lastException = Exception('Request timed out. Please check your connection and try again.');
      } catch (e) {
        lastException = Exception('Failed to delete all slots: $e');
      }
    }
    throw lastException ?? Exception('Failed to delete all slots');
  }

  /// Delete all appointment slots with optional filtering (generic admin utility).
  static Future<Map<String, dynamic>> deleteAllSlots({
    int? serviceId,
    String? date,
  }) async {
    Exception? lastException;
    
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
          headers: await _adminHeaders(),
        ).timeout(const Duration(seconds: 30));

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

  // ── Pre-delete bookings check ────────────────────────────────────────────────

  /// Returns the list of active appointments linked to [slotId].
  /// Used by the admin UI to show a booking-aware confirmation before deleting.
  static Future<Map<String, dynamic>> getSlotBookings(int slotId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final headers = await _adminHeaders();
        final response = await http.get(
          Uri.parse('$url/appointment-slots/$slotId/bookings'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return Map<String, dynamic>.from(data['data'] ?? {});
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch slot bookings');
        } else if (response.statusCode == 404) {
          return {'slot_id': slotId, 'appointments': [], 'booked_count': 0};
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch slot bookings');
        }
      } on TimeoutException {
        lastException = Exception('Request timed out fetching slot bookings.');
      } catch (e) {
        lastException = Exception('Failed to fetch slot bookings: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch slot bookings');
  }

  // ── Step 2: Per-date detail with linked patient/appointment info ─────────────

  /// Fetch slots for a given date enriched with booked appointment + patient info.  /// Returns { slots: [...], summary: { total, available, booked, fully_booked } }
  static Future<Map<String, dynamic>> getDateDetail({
    required int serviceId,
    required String date,
  }) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final headers = await _adminHeaders();
        final response = await http.get(
          Uri.parse('$url/appointment-slots/date-detail?serviceId=$serviceId&date=$date'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return Map<String, dynamic>.from(data['data'] ?? {});
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch date detail');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch date detail');
        }
      } on TimeoutException {
        lastException = Exception('Request timed out fetching date detail.');
      } catch (e) {
        lastException = Exception('Failed to fetch date detail: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch date detail');
  }

  // ── Step 3: Reschedule entire date ──────────────────────────────────────────

  /// Move all slots (and their linked appointments) from [fromDate] to [toDate].
  static Future<Map<String, dynamic>> rescheduleDate({
    required int serviceId,
    required String fromDate,
    required String toDate,
    int? adminId,
  }) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final headers = await _adminHeaders();
        final response = await http.post(
          Uri.parse('$url/appointment-slots/reschedule-date'),
          headers: headers,
          body: json.encode({
            'service_id': serviceId,
            'from_date':  fromDate,
            'to_date':    toDate,
            if (adminId != null) 'admin_id': adminId,
          }),
        ).timeout(const Duration(seconds: 30));

        final data = json.decode(response.body);
        if (response.statusCode == 200) return Map<String, dynamic>.from(data);
        if (response.statusCode == 409) {
          // Conflict — surface the detailed message from server
          throw Exception(data['message'] ?? 'Conflict: target date already has slots');
        }
        lastException = Exception(data['message'] ?? 'HTTP ${response.statusCode}: Failed to reschedule date');
      } on TimeoutException {
        lastException = Exception('Request timed out. Rescheduling may still be in progress — refresh the calendar.');
      } catch (e) {
        if (e is Exception) { lastException = e; } else {
          lastException = Exception('Failed to reschedule date: $e');
        }
      }
    }
    throw lastException ?? Exception('Failed to reschedule date');
  }

  // ── Step 4: Edit existing slot configuration for a date ─────────────────────

  /// Regenerate the slot grid for [date] with new config.
  /// Displaced bookings are automatically notified (handled server-side).
  static Future<Map<String, dynamic>> editDateSlots({
    required int serviceId,
    required String date,
    required String startTime,
    required String endTime,
    required int slotDurationMinutes,
    int? adminId,
  }) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final headers = await _adminHeaders();
        final response = await http.put(
          Uri.parse('$url/appointment-slots/edit-date'),
          headers: headers,
          body: json.encode({
            'service_id':            serviceId,
            'date':                  date,
            'start_time':            startTime,
            'end_time':              endTime,
            'slot_duration_minutes': slotDurationMinutes,
            if (adminId != null) 'admin_id': adminId,
          }),
        ).timeout(const Duration(seconds: 30));

        final data = json.decode(response.body);
        if (response.statusCode == 200) return Map<String, dynamic>.from(data);
        lastException = Exception(data['message'] ?? 'HTTP ${response.statusCode}: Failed to edit date slots');
      } on TimeoutException {
        lastException = Exception('Request timed out editing slots.');
      } catch (e) {
        if (e is Exception) { lastException = e; } else {
          lastException = Exception('Failed to edit date slots: $e');
        }
      }
    }
    throw lastException ?? Exception('Failed to edit date slots');
  }
}