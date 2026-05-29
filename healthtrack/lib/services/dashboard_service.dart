import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config

class DashboardService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Test connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/stats"),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print("Connection test failed: $e");
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
      final response = await http.get(
        Uri.parse("${baseUrl}/dashboard/stats"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return data or empty map if data is null
        return data['data'] as Map<String, dynamic>? ?? {};
      } else {
        print("Failed to fetch dashboard stats. Status: ${response.statusCode}");
        throw Exception("Failed to fetch dashboard stats. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching dashboard stats: $e");
      // Return default values to prevent app crash
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
      final response = await http.get(
        Uri.parse("${baseUrl}/dashboard/activities"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return data or empty list if data is null
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        print("Failed to fetch recent activities. Status: ${response.statusCode}");
        throw Exception("Failed to fetch recent activities. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching recent activities: $e");
      // Return empty list to prevent app crash
      return [];
    }
  }

  // Get today's appointments
  static Future<List<Map<String, dynamic>>> getTodayAppointments() async {
    try {
      final response = await http.get(
        Uri.parse("${baseUrl}/dashboard/appointments"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return data or empty list if data is null
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        print("Failed to fetch today's appointments. Status: ${response.statusCode}");
        throw Exception("Failed to fetch today's appointments. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching today's appointments: $e");
      // Return empty list to prevent app crash
      return [];
    }
  }
  
  // Get weekly appointments data
  static Future<Map<String, dynamic>> getWeeklyAppointments() async {
    try {
      final response = await http.get(
        Uri.parse("${baseUrl}/dashboard/weekly-appointments"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return data or empty map if data is null
        return data['data'] as Map<String, dynamic>? ?? {};
      } else {
        print("Failed to fetch weekly appointments. Status: ${response.statusCode}");
        throw Exception("Failed to fetch weekly appointments. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching weekly appointments: $e");
      // Return default values to prevent app crash
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
      final response = await http.get(
        Uri.parse("${baseUrl}/dashboard/service-type-distribution"),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Return data or empty list if data is null
        if (data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        print("Failed to fetch service type distribution. Status: ${response.statusCode}");
        throw Exception("Failed to fetch service type distribution. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching service type distribution: $e");
      // Return empty list to prevent app crash
      return [];
    }
  }
}