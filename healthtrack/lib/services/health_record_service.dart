import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config

class HealthRecordService {
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

  /// Get all health records for a patient
  static Future<List<Map<String, dynamic>>> getUserHealthRecords(int patientId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/health-records/patient/$patientId"),
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
            lastException = Exception(data['message'] ?? 'Failed to fetch health records');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch health records");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch health records: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch health records");
  }

  /// Get health records by type
  static Future<List<Map<String, dynamic>>> getHealthRecordsByType(
    int patientId, String recordType) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/health-records/patient/$patientId?type=${Uri.encodeComponent(recordType)}"),
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
            lastException = Exception(data['message'] ?? 'Failed to fetch health records by type');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch health records by type");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch health records by type: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch health records by type");
  }

  /// Add a new health record
  static Future<Map<String, dynamic>> addHealthRecord(Map<String, dynamic> recordData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.post(
          Uri.parse("$url/health-records"),
          headers: _headers,
          body: json.encode(recordData),
        ).timeout(const Duration(seconds: 10));

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
            'message': data['message'] ?? 'Health record added successfully',
            'data': data['data'] ?? {},
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to add health record');
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to add health record: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to add health record',
      'data': {},
    };
  }

  /// Update health record
  static Future<Map<String, dynamic>> updateHealthRecord(int id, Map<String, dynamic> recordData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.put(
          Uri.parse("$url/health-records/$id"),
          headers: _headers,
          body: json.encode(recordData),
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
          
          return {
            'success': isSuccess,
            'message': data['message'] ?? 'Health record updated successfully',
            'data': data['data'] ?? {},
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to update health record');
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to update health record: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to update health record',
      'data': {},
    };
  }

  /// Delete health record
  static Future<Map<String, dynamic>> deleteHealthRecord(int id) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.delete(
          Uri.parse("$url/health-records/$id"),
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
          
          return {
            'success': isSuccess,
            'message': data['message'] ?? 'Health record deleted successfully',
            'data': data['data'] ?? {},
          };
        } else {
          final data = json.decode(response.body);
          lastException = Exception(data['message'] ?? 'Failed to delete health record');
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to delete health record: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, return the last exception
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to delete health record',
      'data': {},
    };
  }

  /// Get health records by date range
  static Future<List<Map<String, dynamic>>> getHealthRecordsByDateRange(
    int patientId, String startDate, String endDate) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/health-records/patient/$patientId?start_date=$startDate&end_date=$endDate"),
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
            lastException = Exception(data['message'] ?? 'Failed to fetch health records by date range');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch health records by date range");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch health records by date range: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch health records by date range");
  }

  /// Search health records
  static Future<List<Map<String, dynamic>>> searchHealthRecords(
    int patientId, String query) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/health-records/patient/$patientId?q=${Uri.encodeComponent(query)}"),
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
            lastException = Exception(data['message'] ?? 'Failed to search health records');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to search health records");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to search health records: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to search health records");
  }

  /// Get recent health records (last 30 days)
  static Future<List<Map<String, dynamic>>> getRecentHealthRecords(int patientId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse("$url/health-records/patient/$patientId?recent=true"),
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
            lastException = Exception(data['message'] ?? 'Failed to fetch recent health records');
            // Continue to try the next URL
          }
        } else {
          lastException = Exception("HTTP ${response.statusCode}: Failed to fetch recent health records");
          // Continue to try the next URL
        }
      } catch (e) {
        lastException = Exception("Failed to fetch recent health records: $e");
        // Continue to try the next URL
      }
    }
    
    // If all URLs failed, throw the last exception
    throw lastException ?? Exception("Failed to fetch recent health records");
  }
}