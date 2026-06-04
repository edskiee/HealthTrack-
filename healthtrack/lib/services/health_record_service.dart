import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../admin/services/admin_session_storage.dart';

class HealthRecordService {
  static String get baseUrl => ApiConfig.baseUrl;
  static List<String> get fallbackBaseUrls => ApiConfig.fallbackBaseUrls;

  /// Async headers that include the admin Bearer token.
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    // DEBUG — remove once 401s are resolved
    print('[HealthRecordService] _authHeaders() token='
        '${token == null ? "NULL" : token.isEmpty ? "EMPTY" : "${token.substring(0, token.length.clamp(0, 10))}..."}');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all health records for a patient
  static Future<List<Map<String, dynamic>>> getUserHealthRecords(int patientId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/health-records/patient/$patientId'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch health records');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch health records');
        }
      } catch (e) {
        lastException = Exception('Failed to fetch health records: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch health records');
  }

  /// Get health records by type
  static Future<List<Map<String, dynamic>>> getHealthRecordsByType(
      int patientId, String recordType) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/health-records/patient/$patientId?type=${Uri.encodeComponent(recordType)}'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch health records by type');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch health records by type');
        }
      } catch (e) {
        lastException = Exception('Failed to fetch health records by type: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch health records by type');
  }

  /// Add a new health record
  static Future<Map<String, dynamic>> addHealthRecord(Map<String, dynamic> recordData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.post(
          Uri.parse('$url/health-records'),
          headers: await _authHeaders(),
          body: json.encode(recordData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          return {
            'success': _isSuccess(data),
            'message': data['message'] ?? 'Health record added successfully',
            'data': data['data'] ?? {},
          };
        }
        final data = json.decode(response.body);
        lastException = Exception(data['message'] ?? 'Failed to add health record');
      } catch (e) {
        lastException = Exception('Failed to add health record: $e');
      }
    }
    return {
      'success': false,
      'message': lastException?.toString() ?? 'Failed to add health record',
      'data': {},
    };
  }

  /// Update health record
  static Future<Map<String, dynamic>> updateHealthRecord(
      int id, Map<String, dynamic> recordData) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.put(
          Uri.parse('$url/health-records/$id'),
          headers: await _authHeaders(),
          body: json.encode(recordData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return {
            'success': _isSuccess(data),
            'message': data['message'] ?? 'Health record updated successfully',
            'data': data['data'] ?? {},
          };
        }
        final data = json.decode(response.body);
        lastException = Exception(data['message'] ?? 'Failed to update health record');
      } catch (e) {
        lastException = Exception('Failed to update health record: $e');
      }
    }
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
          Uri.parse('$url/health-records/$id'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return {
            'success': _isSuccess(data),
            'message': data['message'] ?? 'Health record deleted successfully',
            'data': data['data'] ?? {},
          };
        }
        final data = json.decode(response.body);
        lastException = Exception(data['message'] ?? 'Failed to delete health record');
      } catch (e) {
        lastException = Exception('Failed to delete health record: $e');
      }
    }
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
          Uri.parse('$url/health-records/patient/$patientId?start_date=$startDate&end_date=$endDate'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch health records by date range');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch health records by date range');
        }
      } catch (e) {
        lastException = Exception('Failed to fetch health records by date range: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch health records by date range');
  }

  /// Search health records
  static Future<List<Map<String, dynamic>>> searchHealthRecords(
      int patientId, String query) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/health-records/patient/$patientId?q=${Uri.encodeComponent(query)}'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          lastException = Exception(data['message'] ?? 'Failed to search health records');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to search health records');
        }
      } catch (e) {
        lastException = Exception('Failed to search health records: $e');
      }
    }
    throw lastException ?? Exception('Failed to search health records');
  }

  /// Get recent health records (last 30 days)
  static Future<List<Map<String, dynamic>>> getRecentHealthRecords(int patientId) async {
    Exception? lastException;
    for (final url in fallbackBaseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/health-records/patient/$patientId?recent=true'),
          headers: await _authHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          lastException = Exception(data['message'] ?? 'Failed to fetch recent health records');
        } else {
          lastException = Exception('HTTP ${response.statusCode}: Failed to fetch recent health records');
        }
      } catch (e) {
        lastException = Exception('Failed to fetch recent health records: $e');
      }
    }
    throw lastException ?? Exception('Failed to fetch recent health records');
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static bool _isSuccess(Map<String, dynamic> data) {
    final s = data['success'];
    if (s is bool) return s;
    if (s is String) return s.toLowerCase() == 'true';
    if (s is int) return s == 1;
    return false;
  }
}
