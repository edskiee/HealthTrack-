import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config
import '../admin/services/admin_session_storage.dart'; // Admin token storage

class DashboardService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  // Async headers that include the admin Bearer token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    debugPrint('[DashboardService] token=${token == null ? "NULL" : token.isEmpty ? "EMPTY" : "${token.substring(0, token.length.clamp(0, 10))}..."}');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Try a GET across all fallback URLs, return the first successful response.
  static Future<http.Response> _getWithFallback(String path) async {
    Object? lastError;
    for (final url in fallbackBaseUrls) {
      try {
        return await http
            .get(Uri.parse('$url$path'), headers: await _authHeaders())
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('All URLs failed for $path');
  }

  // Test connection
  static Future<bool> testConnection() async {
    try {
      final response = await _getWithFallback('/dashboard/stats');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Connection test failed: $e");
      return false;
    }
  }
  // Singleton instance for global access
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  // Stream controller for real-time updates
  static final List<Map<String, dynamic>> _refreshCallbacks = [];

  // Add refresh callback for dashboard updates
  static void addRefreshCallback(Function() callback, {bool priority = false}) {
    _refreshCallbacks.add({
      'callback': callback,
      'priority': priority,
    });
  }
  
  // Trigger refresh for all registered callbacks
  static void triggerRefresh() {
    // Execute priority callbacks first
    for (var callbackData in _refreshCallbacks.where((c) => c['priority'] == true)) {
      callbackData['callback']();
    }
    
    // Then execute non-priority callbacks
    for (var callbackData in _refreshCallbacks.where((c) => c['priority'] != true)) {
      callbackData['callback']();
    }
  }

  // Remove refresh callback
  static void removeRefreshCallback(Function() callback) {
    _refreshCallbacks.removeWhere((callbackData) => callbackData['callback'] == callback);
  }

  // Trigger refresh for all listening dashboards
  static void triggerDashboardRefresh() {
    for (var callback in _refreshCallbacks) {
      callback['callback']();
    }
  }
  
  // Get dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _getWithFallback('/dashboard/stats');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>? ?? {};
      } else {
        throw Exception("Failed to fetch dashboard stats. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
      return {
        'totalPatients': 0,
        'appointmentsToday': 0,
        'pendingApprovals': 0,
        'todayRecords': 0,
        'maternalPatients': 0,
        'immunizationPatients': 0,
        'totalPatientsChange': 0.0,
        'maternalPatientsChange': 0.0,
        'immunizationPatientsChange': 0.0,
        'appointmentsTodayChange': 0.0,
        'todayRecordsChange': 0.0,
        'pendingApprovalsChange': 0.0,
      };
    }
  }

  // Get recent activities
  static Future<List<Map<String, dynamic>>> getRecentActivities() async {
    try {
      final response = await _getWithFallback('/dashboard/activities');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        throw Exception("Failed to fetch recent activities. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching recent activities: $e");
      return [];
    }
  }

  // Get today's appointments
  static Future<List<Map<String, dynamic>>> getTodayAppointments() async {
    try {
      final response = await _getWithFallback('/dashboard/appointments');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        throw Exception("Failed to fetch today's appointments. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching today's appointments: $e");
      return [];
    }
  }

  // Get weekly appointments data
  static Future<Map<String, dynamic>> getWeeklyAppointments() async {
    try {
      final response = await _getWithFallback('/dashboard/weekly-appointments');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>? ?? {};
      } else {
        throw Exception("Failed to fetch weekly appointments. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching weekly appointments: $e");
      return {
        'Mon': 0,
        'Tue': 0,
        'Wed': 0,
        'Thu': 0,
        'Fri': 0,
        'Sat': 0,
        'Sun': 0
      };
    }
  }
  
  // Get service type distribution data
  static Future<List<Map<String, dynamic>>> getServiceTypeDistribution() async {
    try {
      final response = await _getWithFallback('/dashboard/service-type-distribution');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        throw Exception("Failed to fetch service type distribution. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching service type distribution: $e");
      return [];
    }
  }
}