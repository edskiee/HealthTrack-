import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import 'services/admin_session_storage.dart';

class ReportsService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Helper: parse success field robustly ──────────────────────────────────
  static bool _isSuccess(dynamic data) {
    if (data is! Map<String, dynamic>) return false;
    final s = data['success'];
    if (s is bool) return s;
    if (s is int) return s == 1;
    if (s is String) return s.toLowerCase() == 'true';
    return false;
  }

  // ─── Total patients (real API) ─────────────────────────────────────────────
  static Future<int> getTotalPatients() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/patients'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map<String, dynamic>) {
          if (data['data'] is List) return (data['data'] as List).length;
          if (data['count'] is int)  return data['count'] as int;
          if (data['total'] is int)  return data['total'] as int;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('getTotalPatients error: $e');
      return 0;
    }
  }

  // ─── Immunization monthly counts (real API) ────────────────────────────────
  static Future<Map<String, int>> getImmunizationMonthlyCounts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final year = endDate.year;
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/immunization-monthly?year=$year'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is Map) {
          return _toStringIntMap(data['data'] as Map);
        }
      }
      debugPrint('getImmunizationMonthlyCounts HTTP ${resp.statusCode}');
      return _emptyMonthMap();
    } catch (e) {
      debugPrint('getImmunizationMonthlyCounts error: $e');
      return _emptyMonthMap();
    }
  }

  // ─── Prenatal monthly counts (real API) ───────────────────────────────────
  static Future<Map<String, int>> getPrenatalMonthlyCounts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final year = endDate.year;
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/prenatal-monthly?year=$year'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is Map) {
          return _toStringIntMap(data['data'] as Map);
        }
      }
      debugPrint('getPrenatalMonthlyCounts HTTP ${resp.statusCode}');
      return _emptyMonthMap();
    } catch (e) {
      debugPrint('getPrenatalMonthlyCounts error: $e');
      return _emptyMonthMap();
    }
  }

  // ─── Vaccine category distribution (real API) ─────────────────────────────
  static Future<Map<String, int>> getImmunizationVaccineDistribution(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/vaccine-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is Map) {
          return _toStringIntMap(data['data'] as Map);
        }
      }
      debugPrint('getImmunizationVaccineDistribution HTTP ${resp.statusCode}');
      return {};
    } catch (e) {
      debugPrint('getImmunizationVaccineDistribution error: $e');
      return {};
    }
  }

  // ─── Prenatal trimester distribution (real API) ───────────────────────────
  static Future<Map<String, int>> getPrenatalTrimesterDistribution(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/trimester-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is Map) {
          return _toStringIntMap(data['data'] as Map);
        }
      }
      debugPrint('getPrenatalTrimesterDistribution HTTP ${resp.statusCode}');
      return {};
    } catch (e) {
      debugPrint('getPrenatalTrimesterDistribution error: $e');
      return {};
    }
  }

  // ─── Immunization detailed patient list (real API) ────────────────────────
  static Future<List<Map<String, dynamic>>> getImmunizationDetailedData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/immunization-patients?limit=100'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      debugPrint('getImmunizationDetailedData HTTP ${resp.statusCode}');
      return [];
    } catch (e) {
      debugPrint('getImmunizationDetailedData error: $e');
      return [];
    }
  }

  // ─── Prenatal detailed patient list (real API) ────────────────────────────
  static Future<List<Map<String, dynamic>>> getPrenatalDetailedData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/prenatal-patients?limit=100'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      debugPrint('getPrenatalDetailedData HTTP ${resp.statusCode}');
      return [];
    } catch (e) {
      debugPrint('getPrenatalDetailedData error: $e');
      return [];
    }
  }

  // ─── Immunization total count (real API — used for stat card) ─────────────
  static Future<int> getImmunizationCount() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/immunization-patients?limit=1'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data)) {
          final t = data['total'];
          if (t is int) return t;
          if (t is String) return int.tryParse(t) ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('getImmunizationCount error: $e');
      return 0;
    }
  }

  // ─── Prenatal total count (real API — used for stat card) ─────────────────
  static Future<int> getPrenatalCount() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/reports/prenatal-patients?limit=1'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data)) {
          final t = data['total'];
          if (t is int) return t;
          if (t is String) return int.tryParse(t) ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('getPrenatalCount error: $e');
      return 0;
    }
  }

  // ─── Kept for backward compat (dashboard_view.dart uses these) ────────────
  static Future<Map<String, int>> getWeeklyAppointments() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/weekly-appointments'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map<String, dynamic> && data['data'] != null) {
          final dv = data['data'];
          if (dv is Map<String, dynamic>) return _toStringIntMap(dv);
          if (dv is List) {
            final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
            final result = <String, int>{};
            for (int i = 0; i < dv.length && i < 7; i++) {
              final item = dv[i];
              result[days[i]] = item is Map ? (item['count'] as int? ?? 0) : (item is int ? item : 0);
            }
            return result;
          }
        }
      }
      return _emptyWeekMap();
    } catch (e) {
      return _emptyWeekMap();
    }
  }

  static Future<Map<String, int>> getServiceTypeDistribution() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/service-type-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          final result = <String, int>{};
          for (final item in (data['data'] as List)) {
            if (item is Map<String, dynamic>) {
              final key = item['service_type']?.toString() ?? 'unknown';
              final val = item['count'];
              result[key] = val is int ? val : (int.tryParse(val?.toString() ?? '') ?? 0);
            }
          }
          return result;
        }
      }
      return {'immunization': 0, 'maternal': 0};
    } catch (e) {
      return {'immunization': 0, 'maternal': 0};
    }
  }

  static Future<List<Map<String, dynamic>>> getBabyConditions() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/baby-conditions'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getAgeDistribution() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/age-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List).whereType<Map<String, dynamic>>().map((d) => {
            'range':      d['range']      ?? d['age_range'] ?? 'Unknown',
            'babies':     d['babies']     ?? d['count']     ?? 0,
            'percentage': d['percentage'] ?? 0,
          }).toList();
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getGenderDistribution() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/gender-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List).whereType<Map<String, dynamic>>().map((d) => {
            'gender':     d['gender']     ?? d['name']  ?? 'Unknown',
            'babies':     d['babies']     ?? d['count'] ?? 0,
            'percentage': d['percentage'] ?? 0,
          }).toList();
        }
      }
      return [];
    } catch (e) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getLocationDistribution() async {
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl/dashboard/location-distribution'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (_isSuccess(data) && data['data'] is List) {
          return (data['data'] as List).whereType<Map<String, dynamic>>().map((d) => {
            'location':   d['location']   ?? d['name']  ?? 'Unknown',
            'babies':     d['babies']     ?? d['count'] ?? 0,
            'percentage': d['percentage'] ?? 0,
          }).toList();
        }
      }
      return [];
    } catch (e) { return []; }
  }

  // ─── Private helpers ───────────────────────────────────────────────────────
  static Map<String, int> _toStringIntMap(Map raw) {
    final result = <String, int>{};
    raw.forEach((k, v) {
      result[k.toString()] = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
    });
    return result;
  }

  static Map<String, int> _emptyMonthMap() => {
    'Jan': 0, 'Feb': 0, 'Mar': 0, 'Apr': 0, 'May': 0, 'Jun': 0,
    'Jul': 0, 'Aug': 0, 'Sep': 0, 'Oct': 0, 'Nov': 0, 'Dec': 0,
  };

  static Map<String, int> _emptyWeekMap() =>
    {'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
}
