import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import 'services/admin_session_storage.dart';

class ReportsService {
  // Use the same centralized URL config as other admin services
  static String get baseUrl => ApiConfig.baseUrl;

  // Async headers that include the admin Bearer token
  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Get total patients count with robust error handling
  static Future<int> getTotalPatients() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/patients"),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is List) {
            return (data['data'] as List).length;
          } else if (data.containsKey('count') && data['count'] is int) {
            return data['count'] as int;
          } else if (data.containsKey('total') && data['total'] is int) {
            return data['total'] as int;
          }
        }
        // Fallback: return 0 for any unrecognized format
        return 0;
      } else {
        print("Failed to fetch patients data: HTTP ${response.statusCode}");
        return 0;
      }
    } catch (e) {
      print("Error fetching total patients: $e");
      return 0; // Return 0 instead of throwing to prevent app crash
    }
  }

  // Get weekly appointments data with validation
  static Future<Map<String, int>> getWeeklyAppointments() async {
    try {
      // Get appointments for the current week
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/weekly-appointments"),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            final dataValue = data['data'];
            if (dataValue is Map<String, dynamic>) {
              // Convert dynamic map to Map<String, int>
              final result = <String, int>{};
              dataValue.forEach((key, value) {
                result[key.toString()] = value is int ? value : (value is String ? int.tryParse(value) ?? 0 : 0);
              });
              return result;
            } else if (dataValue is List) {
              // Handle list format by converting to map
              final result = <String, int>{};
              for (int i = 0; i < dataValue.length && i < 7; i++) {
                final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (i < days.length) {
                  final item = dataValue[i];
                  if (item is Map<String, dynamic> && item.containsKey('count')) {
                    result[days[i]] = item['count'] is int ? item['count'] : 0;
                  } else if (item is int) {
                    result[days[i]] = item;
                  } else {
                    result[days[i]] = 0;
                  }
                }
              }
              return result;
            }
          }
        }
        return {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
      } else {
        print("Failed to fetch weekly appointments: HTTP ${response.statusCode}");
        return {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
      }
    } catch (e) {
      print("Error fetching weekly appointments: $e");
      return {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
    }
  }

  // Get service type distribution data with robust validation
  static Future<Map<String, int>> getServiceTypeDistribution() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/service-type-distribution"),
        headers: await _authHeaders(),
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
          final dataValue = data['data'];
          if (dataValue is List) {
            final result = <String, int>{};
            for (final item in dataValue) {
              if (item is Map<String, dynamic>) {
                final serviceType = item['service_type'] as String? ?? item['serviceType'] as String? ?? 'unknown';
                final count = item['count'] as int? ?? (item['count'] is String ? int.tryParse(item['count']) ?? 0 : 0);
                result[serviceType] = count;
              }
            }
            return result;
          } else if (dataValue is Map<String, dynamic>) {
            // Handle direct map format
            final result = <String, int>{};
            dataValue.forEach((key, value) {
              result[key.toString()] = value is int ? value : (value is String ? int.tryParse(value) ?? 0 : 0);
            });
            return result;
          }
        }
        return {'immunization': 0, 'maternal': 0, 'unknown': 0};
      } else {
        print("Failed to fetch service type distribution: HTTP ${response.statusCode}");
        return {'immunization': 0, 'maternal': 0, 'unknown': 0};
      }
    } catch (e) {
      print("Error fetching service type distribution: $e");
      return {'immunization': 0, 'maternal': 0, 'unknown': 0};
    }
  }

  // Get baby conditions data with validation
  static Future<List<Map<String, dynamic>>> getBabyConditions() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/baby-conditions"),
        headers: await _authHeaders(),
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
          final dataValue = data['data'];
          if (dataValue is List) {
            return dataValue.map((condition) {
              if (condition is Map<String, dynamic>) {
                return {
                  "name": condition["name"] as String? ?? condition["condition"] as String? ?? "Unknown",
                  "patients": condition["patients"] as int? ?? (condition["count"] as int? ?? 0),
                  "percentage": condition["percentage"] as int? ?? 0,
                };
              }
              return {"name": "Unknown", "patients": 0, "percentage": 0};
            }).toList();
          }
        }
        return [];
      } else {
        print("Failed to fetch baby conditions: HTTP ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching baby conditions: $e");
      return [];
    }
  }

  // Get age distribution data with validation
  static Future<List<Map<String, dynamic>>> getAgeDistribution() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/age-distribution"),
        headers: await _authHeaders(),
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
          final dataValue = data['data'];
          if (dataValue is List) {
            return dataValue.map((dist) {
              if (dist is Map<String, dynamic>) {
                return {
                  "range": dist["range"] as String? ?? dist["age_range"] as String? ?? "Unknown",
                  "babies": dist["babies"] as int? ?? (dist["count"] as int? ?? 0),
                  "percentage": dist["percentage"] as int? ?? 0,
                };
              }
              return {"range": "Unknown", "babies": 0, "percentage": 0};
            }).toList();
          }
        }
        return [];
      } else {
        print("Failed to fetch age distribution: HTTP ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching age distribution: $e");
      return [];
    }
  }

  // Get gender distribution data with validation
  static Future<List<Map<String, dynamic>>> getGenderDistribution() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/gender-distribution"),
        headers: await _authHeaders(),
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
          final dataValue = data['data'];
          if (dataValue is List) {
            return dataValue.map((dist) {
              if (dist is Map<String, dynamic>) {
                return {
                  "gender": dist["gender"] as String? ?? dist["name"] as String? ?? "Unknown",
                  "babies": dist["babies"] as int? ?? (dist["count"] as int? ?? 0),
                  "percentage": dist["percentage"] as int? ?? 0,
                };
              }
              return {"gender": "Unknown", "babies": 0, "percentage": 0};
            }).toList();
          }
        }
        return [];
      } else {
        print("Failed to fetch gender distribution: HTTP ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching gender distribution: $e");
      return [];
    }
  }

  // Get location distribution data with validation
  static Future<List<Map<String, dynamic>>> getLocationDistribution() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/dashboard/location-distribution"),
        headers: await _authHeaders(),
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
          final dataValue = data['data'];
          if (dataValue is List) {
            return dataValue.map((dist) {
              if (dist is Map<String, dynamic>) {
                return {
                  "location": dist["location"] as String? ?? dist["name"] as String? ?? "Unknown",
                  "babies": dist["babies"] as int? ?? (dist["count"] as int? ?? 0),
                  "percentage": dist["percentage"] as int? ?? 0,
                };
              }
              return {"location": "Unknown", "babies": 0, "percentage": 0};
            }).toList();
          }
        }
        return [];
      } else {
        print("Failed to fetch location distribution: HTTP ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching location distribution: $e");
      return [];
    }
  }

  // Get immunization monthly counts
  static Future<Map<String, int>> getImmunizationMonthlyCounts(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return {
        'Jan': 15,
        'Feb': 12,
        'Mar': 18,
        'Apr': 10,
        'May': 14,
        'Jun': 16,
      };
    } catch (e) {
      throw Exception("Failed to fetch immunization monthly counts: $e");
    }
  }

  // Get prenatal monthly counts
  static Future<Map<String, int>> getPrenatalMonthlyCounts(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return {
        'Jan': 8,
        'Feb': 10,
        'Mar': 12,
        'Apr': 9,
        'May': 11,
        'Jun': 7,
      };
    } catch (e) {
      throw Exception("Failed to fetch prenatal monthly counts: $e");
    }
  }

  // Get immunization vaccine distribution
  static Future<Map<String, int>> getImmunizationVaccineDistribution(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return {
        'BCG': 25,
        'Hepatitis B': 30,
        'Polio': 20,
        'MMR': 15,
        'DPT': 18,
        'Hib': 22,
      };
    } catch (e) {
      throw Exception("Failed to fetch immunization vaccine distribution: $e");
    }
  }

  // Get prenatal trimester distribution
  static Future<Map<String, int>> getPrenatalTrimesterDistribution(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return {
        '1st': 5,
        '2nd': 8,
        '3rd': 12,
      };
    } catch (e) {
      throw Exception("Failed to fetch prenatal trimester distribution: $e");
    }
  }

  // Get immunization detailed data
  static Future<List<Map<String, dynamic>>> getImmunizationDetailedData(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return [
        {
          'childName': 'John Smith',
          'motherName': 'Sarah Smith',
          'dob': '2023-01-15',
          'vaccinesGiven': 'BCG, Hepatitis B',
          'nextDue': '2023-02-15',
          'recordType': 'Immunization',
        },
        {
          'childName': 'Emma Johnson',
          'motherName': 'Lisa Johnson',
          'dob': '2023-02-20',
          'vaccinesGiven': 'Polio, DPT',
          'nextDue': '2023-03-20',
          'recordType': 'Immunization',
        },
      ];
    } catch (e) {
      throw Exception("Failed to fetch immunization detailed data: $e");
    }
  }

  // Get prenatal detailed data
  static Future<List<Map<String, dynamic>>> getPrenatalDetailedData(DateTime startDate, DateTime endDate) async {
    try {
      // This is a placeholder implementation
      // In a real scenario, this would call an API endpoint
      return [
        {
          'patientName': 'Maria Rodriguez',
          'dob': '1990-05-10',
          'trimester': '2nd',
          'lastVisit': '2023-06-01',
          'nextAppointment': '2023-06-15',
          'riskLevel': 'Low',
        },
        {
          'patientName': 'Ana Thompson',
          'dob': '1988-12-03',
          'trimester': '3rd',
          'lastVisit': '2023-06-05',
          'nextAppointment': '2023-06-12',
          'riskLevel': 'Medium',
        },
      ];
    } catch (e) {
      throw Exception("Failed to fetch prenatal detailed data: $e");
    }
  }
}
