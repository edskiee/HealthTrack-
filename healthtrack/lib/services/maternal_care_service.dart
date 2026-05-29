import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'api_config.dart'; // Import the new API config

class MaternalCareService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Get maternal care data for the logged-in user
  static Future<Map<String, dynamic>> getMaternalCareData(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients/user/$userId"),
        headers: _headers,
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
        
        if (isSuccess && data['data'] != null) {
          return {
            'success': true,
            'message': data['message'] ?? 'Maternal care data fetched successfully',
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'No maternal care data found for this user');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch maternal care data");
      }
    } catch (e) {
      throw Exception("Failed to fetch maternal care data: $e");
    }
  }

  // Get health records for maternal care patient
  static Future<List<Map<String, dynamic>>> getMaternalHealthRecords(String patientId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/health-records/patient/$patientId"),
        headers: _headers,
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
          throw Exception(data['message'] ?? 'Failed to fetch health records');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch health records");
      }
    } catch (e) {
      throw Exception("Failed to fetch maternal health records: $e");
    }
  }

  // Get upcoming appointments for maternal care
  static Future<List<Map<String, dynamic>>> getUpcomingAppointments(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/appointments/user/$userId"),
        headers: _headers,
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
          // Filter for upcoming appointments (status = pending, scheduled, or approved)
          List<dynamic> allAppointments = data['data'] ?? [];
          List<Map<String, dynamic>> upcomingAppointments = [];
          
          for (var appointment in allAppointments) {
            if (appointment is Map<String, dynamic>) {
              String status = appointment['status']?.toString().toLowerCase() ?? '';
              if (status == 'pending' || status == 'scheduled' || status == 'approved') {
                upcomingAppointments.add(appointment);
              }
            }
          }
          
          return upcomingAppointments;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch appointments');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch appointments");
      }
    } catch (e) {
      throw Exception("Failed to fetch upcoming appointments: $e");
    }
  }

  // Get dynamic health tips for maternal care
  static Future<List<String>> getHealthTips() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/health-tips/maternal"),
        headers: _headers,
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
          return List<String>.from(data['data'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch health tips');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch health tips");
      }
    } catch (e) {
      // Return default tips if there's an error
      return [
        "Drink plenty of water to stay hydrated during pregnancy",
        "Take prenatal vitamins as prescribed by your doctor",
        "Get regular exercise like walking or prenatal yoga"
      ];
    }
  }

  // Stream maternal care data for real-time updates
  static Stream<Map<String, dynamic>> streamMaternalCareData(String userId) async* {
    while (true) {
      try {
        final data = await getMaternalCareData(userId);
        yield data;
      } catch (e) {
        print('Error streaming maternal care data: $e');
        yield {'success': false, 'message': 'Error fetching data', 'data': {}};
      }
      await Future.delayed(const Duration(seconds: 30)); // Update every 30 seconds
    }
  }

  // Stream health tips for real-time updates
  static Stream<List<String>> streamHealthTips() async* {
    while (true) {
      try {
        final tips = await getHealthTips();
        yield tips;
      } catch (e) {
        print('Error streaming health tips: $e');
        yield [
          "Drink plenty of water to stay hydrated during pregnancy",
          "Take prenatal vitamins as prescribed by your doctor",
          "Get regular exercise like walking or prenatal yoga"
        ];
      }
      await Future.delayed(const Duration(minutes: 5)); // Update every 5 minutes
    }
  }
}