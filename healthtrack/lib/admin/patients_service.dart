import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart'; // Import the new API config
import '../services/dashboard_service.dart';
import 'services/admin_session_storage.dart';

class PatientsService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Async headers that include the admin Bearer token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    // DEBUG — remove once 401s are resolved
    print('[PatientsService] _authHeaders() token='
        '${token == null ? "NULL" : token.isEmpty ? "EMPTY" : "${token.substring(0, token.length.clamp(0, 10))}..."}');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all patients (returns data in Flutter format)
  static Future<List<Map<String, String>>> getPatients() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients"),
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
          List patients = data['data'] ?? [];
          // Convert to the format expected by your Flutter UI
          return patients.map((patient) {
            return {
              "id": patient['id']?.toString() ?? '',
              "childName": patient['childName']?.toString() ?? '',
              "motherName": patient['motherName']?.toString() ?? '',
              "fatherName": patient['fatherName']?.toString() ?? '',
              "dob": patient['dob']?.toString() ?? '',
              "placeOfBirth": patient['placeOfBirth']?.toString() ?? '',
              "birthWeight": patient['birthWeight']?.toString() ?? '',
              "birthHeight": patient['birthHeight']?.toString() ?? '',
              "sex": patient['sex']?.toString() ?? '',
              "address": patient['address']?.toString() ?? '',
              "recordType": patient['recordType']?.toString() ?? 'Diagnosis',
              "serviceType": patient['serviceType']?.toString() ?? 'immunization',
              "recordDescription": patient['recordDescription']?.toString() ?? '',
              // Maternal care fields
              "familySerialNumber": patient['family_serial_number']?.toString() ?? '',
              "contactNumber": patient['contact_number']?.toString() ?? '',
              "spouseName": patient['spouse_name']?.toString() ?? '',
              "livingChildrenCount": patient['living_children_count']?.toString() ?? '0',
              "monthlyIncome": patient['monthly_income']?.toString() ?? '0',
              "religion": patient['religion']?.toString() ?? '',
              "city": patient['city']?.toString() ?? '',
              "province": patient['province']?.toString() ?? '',
              "age": patient['age']?.toString() ?? '0',
              "education": patient['education']?.toString() ?? '',
              "occupation": patient['occupation']?.toString() ?? '',
              "birthAttendant": patient['birth_attendant']?.toString() ?? '',
              "facilityType": patient['facility_type']?.toString() ?? '',
              // Immunization fields
              "healthCenter": patient['health_center']?.toString() ?? '',
              "barangay": patient['barangay']?.toString() ?? '',
              "familyNumber": patient['family_number']?.toString() ?? '',
              // Date fields
              "createdAt": patient['created_at']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch patients');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch patients");
      }
    } catch (e) {
      throw Exception("Failed to fetch patients: $e");
    }
  }

  /// Add a patient (sends data in Flutter format to API)
  static Future<Map<String, dynamic>> addPatient(Map<String, String> patientData) async {
    try {
      // Enhanced debugging
      print('🚀 Adding patient with data: $patientData');
      print('🌐 Using base URL: $baseUrl');
      
      // Convert Flutter format to API format
      final apiData = {
        'userId': patientData['userId'] ?? '1', // Add userId from patientData
        'childName': patientData['childName'],
        'motherName': patientData['motherName'],
        'fatherName': patientData['fatherName'],
        'dob': patientData['dob'],
        'placeOfBirth': patientData['placeOfBirth'],
        'birthWeight': patientData['birthWeight'],
        'birthHeight': patientData['birthHeight'],
        'sex': patientData['sex'],
        'address': patientData['address'],
        'recordType': patientData['recordType'],
        'serviceType': patientData['serviceType'],
        'recordDescription': patientData['recordDescription'],
        // Maternal care fields
        'familySerialNumber': patientData['familySerialNumber'],
        'contactNumber': patientData['contactNumber'],
        'spouseName': patientData['spouseName'],
        'livingChildrenCount': int.tryParse(patientData['livingChildrenCount'] ?? '0'),
        'monthlyIncome': double.tryParse(patientData['monthlyIncome'] ?? '0'),
        'religion': patientData['religion'],
        'city': patientData['city'],
        'province': patientData['province'],
        'age': int.tryParse(patientData['age'] ?? '0'),
        'education': patientData['education'],
        'occupation': patientData['occupation'],
        'birthAttendant': patientData['birthAttendant'],
        'facilityType': patientData['facilityType'],
        // Immunization fields
        'healthCenter': patientData['healthCenter'],
        'barangay': patientData['barangay'],
        'familyNumber': patientData['familyNumber'],
        'createHealthRecord': true, // Flag to create health record automatically
      };

      print('📦 Sending API data: $apiData');
      
      final response = await http.post(
        Uri.parse("$baseUrl/patients"),
        headers: await _authHeaders(),
        body: json.encode(apiData),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool success = false;
        if (data['success'] is bool) {
          success = data['success'];
        } else if (data['success'] is String) {
          success = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          success = data['success'] == 1;
        }
        
        // Trigger dashboard refresh to update all modules
        if (success) {
          DashboardService.triggerRefresh();
        }
        
        print('✅ API response success: $success');
        
        // Trigger dashboard refresh when patient is added successfully
        if (success) {
          DashboardService.triggerDashboardRefresh();
          return {
            'success': true,
            'message': 'Patient added successfully',
            'data': data['data']
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to add patient'
          };
        }
      } else {
        final data = json.decode(response.body);
        final errorMsg = data['message'] ?? 'HTTP ${response.statusCode}: Failed to add patient';
        print('❌ API Error: $errorMsg');
        return {
          'success': false,
          'message': errorMsg
        };
      }
    } catch (e) {
      print('💥 Exception in addPatient: $e');
      return {
        'success': false,
        'message': 'Error adding patient: $e'
      };
    }
  }

  /// Update an existing patient (sends data in Flutter format to API)
  static Future<Map<String, dynamic>> updatePatient(String id, Map<String, String> patientData) async {
    try {
      // Convert Flutter format to API format
      final apiData = {
        'childName': patientData['childName'],
        'motherName': patientData['motherName'],
        'fatherName': patientData['fatherName'],
        'dob': patientData['dob'],
        'placeOfBirth': patientData['placeOfBirth'],
        'birthWeight': patientData['birthWeight'],
        'birthHeight': patientData['birthHeight'],
        'sex': patientData['sex'],
        'address': patientData['address'],
        'recordType': patientData['recordType'],
        'serviceType': patientData['serviceType'],
        'recordDescription': patientData['recordDescription'],
        // Maternal care fields
        'familySerialNumber': patientData['familySerialNumber'],
        'contactNumber': patientData['contactNumber'],
        'spouseName': patientData['spouseName'],
        'livingChildrenCount': int.tryParse(patientData['livingChildrenCount'] ?? '0'),
        'monthlyIncome': double.tryParse(patientData['monthlyIncome'] ?? '0'),
        'religion': patientData['religion'],
        'city': patientData['city'],
        'province': patientData['province'],
        'age': int.tryParse(patientData['age'] ?? '0'),
        'education': patientData['education'],
        'occupation': patientData['occupation'],
        'birthAttendant': patientData['birthAttendant'],
        'facilityType': patientData['facilityType'],
        // Immunization fields
        'healthCenter': patientData['healthCenter'],
        'barangay': patientData['barangay'],
        'familyNumber': patientData['familyNumber'],
      };

      final response = await http.put(
        Uri.parse("$baseUrl/patients/$id"),
        headers: await _authHeaders(),
        body: json.encode(apiData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool success = false;
        if (data['success'] is bool) {
          success = data['success'];
        } else if (data['success'] is String) {
          success = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          success = data['success'] == 1;
        }
        
        // Trigger dashboard refresh when patient is updated successfully
        if (success) {
          DashboardService.triggerDashboardRefresh();
          return {
            'success': true,
            'message': 'Patient updated successfully',
            'data': data['data']
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to update patient'
          };
        }
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'HTTP ${response.statusCode}: Failed to update patient'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating patient: $e'
      };
    }
  }

  /// Delete a patient
  static Future<Map<String, dynamic>> deletePatient(String id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/patients/$id"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool success = false;
        if (data['success'] is bool) {
          success = data['success'];
        } else if (data['success'] is String) {
          success = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          success = data['success'] == 1;
        }
        
        // Trigger dashboard refresh when patient is deleted successfully
        if (success) {
          DashboardService.triggerDashboardRefresh();
          return {
            'success': true,
            'message': 'Patient deleted successfully'
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to delete patient'
          };
        }
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'HTTP ${response.statusCode}: Failed to delete patient'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting patient: $e'
      };
    }
  }

  /// Get patient by ID
  static Future<Map<String, dynamic>> getPatientById(String id) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients/$id"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool success = false;
        if (data['success'] is bool) {
          success = data['success'];
        } else if (data['success'] is String) {
          success = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          success = data['success'] == 1;
        }
        
        if (success) {
          return {
            'success': true,
            'data': data['data']
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch patient'
          };
        }
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'HTTP ${response.statusCode}: Failed to fetch patient'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching patient: $e'
      };
    }
  }

  /// Search patients by name
  static Future<List<Map<String, String>>> searchPatients(String query) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients/search?q=$query"),
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
          List patients = data['data'] ?? [];
          // Convert to the format expected by your Flutter UI
          return patients.map((patient) {
            return {
              "id": patient['id']?.toString() ?? '',
              "childName": patient['childName']?.toString() ?? '',
              "motherName": patient['motherName']?.toString() ?? '',
              "fatherName": patient['fatherName']?.toString() ?? '',
              "dob": patient['dob']?.toString() ?? '',
              "placeOfBirth": patient['placeOfBirth']?.toString() ?? '',
              "birthWeight": patient['birthWeight']?.toString() ?? '',
              "birthHeight": patient['birthHeight']?.toString() ?? '',
              "sex": patient['sex']?.toString() ?? '',
              "address": patient['address']?.toString() ?? '',
              "recordType": patient['recordType']?.toString() ?? 'Diagnosis',
              "serviceType": patient['serviceType']?.toString() ?? 'immunization',
              "recordDescription": patient['recordDescription']?.toString() ?? '',
              // Maternal care fields
              "familySerialNumber": patient['family_serial_number']?.toString() ?? '',
              "contactNumber": patient['contact_number']?.toString() ?? '',
              "spouseName": patient['spouse_name']?.toString() ?? '',
              "livingChildrenCount": patient['living_children_count']?.toString() ?? '0',
              "monthlyIncome": patient['monthly_income']?.toString() ?? '0',
              "religion": patient['religion']?.toString() ?? '',
              "city": patient['city']?.toString() ?? '',
              "province": patient['province']?.toString() ?? '',
              "age": patient['age']?.toString() ?? '0',
              "education": patient['education']?.toString() ?? '',
              "occupation": patient['occupation']?.toString() ?? '',
              "birthAttendant": patient['birth_attendant']?.toString() ?? '',
              "facilityType": patient['facility_type']?.toString() ?? '',
              // Immunization fields
              "healthCenter": patient['health_center']?.toString() ?? '',
              "barangay": patient['barangay']?.toString() ?? '',
              "familyNumber": patient['family_number']?.toString() ?? '',
              // Date fields
              "createdAt": patient['created_at']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
          throw Exception(data['message'] ?? 'Failed to search patients');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to search patients");
      }
    } catch (e) {
      throw Exception("Failed to search patients: $e");
    }
  }

  /// Export patients to CSV
  static Future<bool> exportPatientsToCSV() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients/export/csv"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        // In a real implementation, you would save the CSV data to a file
        // For now, we'll just return true to indicate success
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Export patients to Excel
  static Future<bool> exportPatientsToExcel() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients/export/excel"),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        // In a real implementation, you would save the Excel data to a file
        // For now, we'll just return true to indicate success
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
