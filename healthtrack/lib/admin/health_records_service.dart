import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart'; // Import the new API config
import '../services/dashboard_service.dart';
import 'services/admin_session_storage.dart';

class HealthRecordsService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Async headers that include the admin Bearer token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get a paginated page of health records with optional server-side filters.
  ///
  /// Returns a map: { data: List<Map>, total: int, page: int, totalPages: int }
  static Future<Map<String, dynamic>> getHealthRecordsPage({
    int page = 1,
    int limit = 20,
    String? search,
    String? serviceType,
    String? recordType,
    String? gender,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'page':  page.toString(),
        'limit': limit.toString(),
      };
      if (search != null && search.isNotEmpty) queryParams['q'] = search;
      if (serviceType != null && serviceType != 'All') queryParams['serviceType'] = serviceType;
      if (recordType != null && recordType != 'All') queryParams['recordType'] = recordType;
      if (gender != null && gender != 'All') queryParams['gender'] = gender;
      if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;

      final uri = Uri.parse("$baseUrl/health-records")
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _authHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool isSuccess;
        if (data['success'] is bool) isSuccess = data['success'];
        else if (data['success'] is String) isSuccess = data['success'].toLowerCase() == 'true';
        else if (data['success'] is int) isSuccess = data['success'] == 1;
        else isSuccess = false;

        if (!isSuccess) throw Exception(data['message'] ?? 'Failed to fetch health records');

        final List records = data['data'] ?? [];
        return {
          'data':       records.map(_mapRecord).toList().cast<Map<String, dynamic>>(),
          'total':      (data['total'] as num?)?.toInt() ?? 0,
          'page':       (data['page']  as num?)?.toInt() ?? page,
          'totalPages': (data['totalPages'] as num?)?.toInt() ?? 1,
        };
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch health records");
      }
    } catch (e) {
      throw Exception("Failed to fetch health records: $e");
    }
  }

  static Map<String, dynamic> _mapRecord(dynamic record) {
    return {
      "id":            record['id']?.toString() ?? '',
      "recordId":      record['record_id']?.toString() ?? '',
      "patientId":     record['patient_id']?.toString() ?? '',
      "name":          record['name']?.toString() ?? '',
      "age":           record['age']?.toString() ?? '',
      "gender":        record['gender']?.toString() ?? '',
      "status":        record['status']?.toString() ?? '',
      "diagnosis":     record['diagnosis']?.toString() ?? '',
      "dateOfVisit":   record['date_of_visit']?.toString() ?? '',
      "recordType":    record['record_type']?.toString() ?? '',
      "title":         record['title']?.toString() ?? '',
      "description":   record['description']?.toString() ?? '',
      "patientName":   record['patient_name']?.toString() ?? '',
      "motherName":    record['mother_name']?.toString() ?? '',
      "dateOfBirth":   record['date_of_birth']?.toString() ?? '',
      "placeOfBirth":  record['place_of_birth']?.toString() ?? '',
      "birthWeight":   record['birth_weight']?.toString() ?? '',
      "birthHeight":   record['birth_height']?.toString() ?? '',
      "sex":           record['sex']?.toString() ?? '',
      "address":       record['address']?.toString() ?? '',
      "createdAt":     record['created_at']?.toString() ?? '',
    };
  }

  /// Get all health records (legacy — uses pagination internally).
  static Future<List<Map<String, dynamic>>> getHealthRecords() async {
    try {
      final result = await getHealthRecordsPage(page: 1, limit: 20);
      return (result['data'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception("Failed to fetch health records: $e");
    }
  }

  /// Get health records by patient ID
  static Future<List<Map<String, dynamic>>> getHealthRecordsByPatient(int patientId) async {
    try {
      // Add timestamp to prevent caching and ensure fresh data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse("$baseUrl/health-records/patient/$patientId?_t=$timestamp"),
        headers: await _authHeaders(),
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
          // Handle empty data case properly
          List records = data['data'] ?? [];
          if (records.isEmpty) {
            return []; // Return empty list instead of throwing an error
          }
          return records.map((record) => {
            "id": record['id']?.toString() ?? '',
            "recordId": record['record_id']?.toString() ?? '',
            "patientId": record['patient_id']?.toString() ?? '',
            "name": record['name']?.toString() ?? '',
            "age": record['age']?.toString() ?? '',
            "gender": record['gender']?.toString() ?? '',
            "status": record['status']?.toString() ?? '',
            "diagnosis": record['diagnosis']?.toString() ?? '',
            "dateOfVisit": record['date_of_visit']?.toString() ?? '',
            "recordType": record['record_type']?.toString() ?? '',
            "title": record['title']?.toString() ?? '',
            "description": record['description']?.toString() ?? '',
            "patientName": record['patient_name']?.toString() ?? '',
            "motherName": record['mother_name']?.toString() ?? '',
            "dateOfBirth": record['date_of_birth']?.toString() ?? '',
            "placeOfBirth": record['place_of_birth']?.toString() ?? '',
            "birthWeight": record['birth_weight']?.toString() ?? '',
            "birthHeight": record['birth_height']?.toString() ?? '',
            "sex": record['sex']?.toString() ?? '',
            "address": record['address']?.toString() ?? '',
            "createdAt": record['created_at']?.toString() ?? '',
          }).toList().cast<Map<String, dynamic>>();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch health records');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch health records");
      }
    } catch (e) {
      throw Exception("Failed to fetch health records: $e");
    }
  }

  /// Add a health record
  static Future<bool> addHealthRecord(Map<String, dynamic> recordData) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/health-records"),
        headers: await _authHeaders(),
        body: json.encode(recordData),
      );

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
        
        if (isSuccess) {
          // Trigger dashboard refresh to update all modules
          DashboardService.triggerDashboardRefresh();
          return true;
        }
        return false;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to add health record');
      }
    } catch (e) {
      throw Exception("Failed to add health record: $e");
    }
  }

  /// Update an existing health record
  static Future<bool> updateHealthRecord(int id, Map<String, dynamic> recordData) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/health-records/$id"),
        headers: await _authHeaders(),
        body: json.encode(recordData),
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
          // Trigger dashboard refresh to update all modules
          DashboardService.triggerDashboardRefresh();
          return true;
        }
        return false;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to update health record');
      }
    } catch (e) {
      throw Exception("Failed to update health record: $e");
    }
  }

  /// Delete health record
  static Future<bool> deleteHealthRecord(int id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/health-records/$id"),
        headers: await _authHeaders(),
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
          // Trigger dashboard refresh to update all modules
          DashboardService.triggerDashboardRefresh();
          return true;
        }
        return false;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to delete health record');
      }
    } catch (e) {
      throw Exception("Failed to delete health record: $e");
    }
  }
}
