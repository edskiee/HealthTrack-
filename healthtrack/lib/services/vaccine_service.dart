import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session_storage.dart';

/// Data class for the dashboard summary response.
class VaccineDashboardSummary {
  final String childName;
  final int todayCompleted;
  final int todayInProgress;
  final int todayMissed;
  final Map<String, dynamic>? lastCompleted;
  final Map<String, dynamic>? nextDue;
  final bool fullyUpToDate;

  const VaccineDashboardSummary({
    required this.childName,
    required this.todayCompleted,
    required this.todayInProgress,
    required this.todayMissed,
    this.lastCompleted,
    this.nextDue,
    required this.fullyUpToDate,
  });

  factory VaccineDashboardSummary.fromJson(Map<String, dynamic> json) {
    return VaccineDashboardSummary(
      childName:       json['child_name']?.toString() ?? '',
      todayCompleted:  _parseInt(json['today_completed']),
      todayInProgress: _parseInt(json['today_in_progress']),
      todayMissed:     _parseInt(json['today_missed']),
      lastCompleted:   json['last_completed'] as Map<String, dynamic>?,
      nextDue:         json['next_due'] as Map<String, dynamic>?,
      fullyUpToDate:   json['fully_up_to_date'] == true,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Data class for a single vaccine dose entry on the card.
class VaccineDose {
  final int scheduleId;
  final int? recordId;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;
  final String? dueDateEstimate; // ISO date string e.g. "2026-01-01"
  final String? givenAt;         // ISO datetime string
  final String? givenBy;
  final String? notes;
  final VaccineDoseStatus status;

  const VaccineDose({
    required this.scheduleId,
    this.recordId,
    required this.doseNumber,
    required this.doseLabel,
    required this.scheduleLabel,
    this.dueDateEstimate,
    this.givenAt,
    this.givenBy,
    this.notes,
    required this.status,
  });

  factory VaccineDose.fromJson(Map<String, dynamic> json) {
    return VaccineDose(
      scheduleId:       _parseInt(json['schedule_id']),
      recordId:         json['record_id'] != null ? _parseInt(json['record_id']) : null,
      doseNumber:       _parseInt(json['dose_number']),
      doseLabel:        json['dose_label']?.toString() ?? '',
      scheduleLabel:    json['schedule_label']?.toString() ?? '',
      dueDateEstimate:  json['due_date_estimate']?.toString(),
      givenAt:          json['given_at']?.toString(),
      givenBy:          json['given_by']?.toString(),
      notes:            json['notes']?.toString(),
      status:           VaccineDoseStatus.fromString(json['status']?.toString() ?? ''),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Mirrors the status values computed by the backend.
enum VaccineDoseStatus {
  completed,
  dueSoon,
  overdue,
  notYetDue,
  locked;

  static VaccineDoseStatus fromString(String s) {
    switch (s) {
      case 'completed':   return VaccineDoseStatus.completed;
      case 'due_soon':    return VaccineDoseStatus.dueSoon;
      case 'overdue':     return VaccineDoseStatus.overdue;
      case 'locked':      return VaccineDoseStatus.locked;
      default:            return VaccineDoseStatus.notYetDue;
    }
  }
}

/// Data class for a vaccine group (name + all doses) on the card.
class VaccineGroup {
  final String vaccineName;
  final String vaccineKey;
  final List<VaccineDose> doses;

  const VaccineGroup({
    required this.vaccineName,
    required this.vaccineKey,
    required this.doses,
  });

  factory VaccineGroup.fromJson(Map<String, dynamic> json) {
    final rawDoses = json['doses'];
    final doses = rawDoses is List
        ? rawDoses
            .whereType<Map<String, dynamic>>()
            .map(VaccineDose.fromJson)
            .toList()
        : <VaccineDose>[];
    return VaccineGroup(
      vaccineName: json['vaccine_name']?.toString() ?? '',
      vaccineKey:  json['vaccine_key']?.toString() ?? '',
      doses:       doses,
    );
  }

  /// Aggregate status shown on the group header chip.
  String get groupStatusLabel {
    final total     = doses.length;
    final completed = doses.where((d) => d.status == VaccineDoseStatus.completed).length;
    if (completed == total) return 'Completed';
    if (completed == 0) {
      if (doses.any((d) => d.status == VaccineDoseStatus.overdue)) return 'Overdue';
      if (doses.any((d) => d.status == VaccineDoseStatus.dueSoon)) return 'Due soon';
      return 'Not yet due';
    }
    return '$completed of $total done';
  }
}

/// Full vaccine card data.
class VaccineCardData {
  final String childName;
  final String? dob;
  final int ageInDays;
  final List<VaccineGroup> vaccines;
  final Map<String, dynamic>? nextDue;
  final Map<String, dynamic>? overdueAlert;

  const VaccineCardData({
    required this.childName,
    this.dob,
    required this.ageInDays,
    required this.vaccines,
    this.nextDue,
    this.overdueAlert,
  });

  factory VaccineCardData.fromJson(Map<String, dynamic> json) {
    final rawVaccines = json['vaccines'];
    final vaccines = rawVaccines is List
        ? rawVaccines
            .whereType<Map<String, dynamic>>()
            .map(VaccineGroup.fromJson)
            .toList()
        : <VaccineGroup>[];
    return VaccineCardData(
      childName:    json['child_name']?.toString() ?? '',
      dob:          json['dob']?.toString(),
      ageInDays:    json['age_in_days'] is int
                      ? json['age_in_days'] as int
                      : int.tryParse(json['age_in_days']?.toString() ?? '') ?? 0,
      vaccines:     vaccines,
      nextDue:      json['next_due'] as Map<String, dynamic>?,
      overdueAlert: json['overdue_alert'] as Map<String, dynamic>?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Service class for all vaccine tracking API calls.
/// Mirrors AppointmentService: fallbackBaseUrls loop, Bearer JWT, 10s timeout.
class VaccineService {
  static List<String> get _urls => ApiConfig.fallbackBaseUrls;

  static Future<Map<String, String>> _headers() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static bool _isOk(Map<String, dynamic> data) {
    final s = data['success'];
    if (s is bool)   return s;
    if (s is int)    return s == 1;
    if (s is String) return s.toLowerCase() == 'true';
    return false;
  }

  // ── GET /vaccines/dashboard/:patientId ─────────────────────────────────────

  /// Fetches the live dashboard summary for [patientId].
  /// Returns null only if there is genuinely no data (e.g. patient not found).
  /// Throws on network/server error so the caller can surface it.
  static Future<VaccineDashboardSummary> getDashboardSummary(int patientId) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.get(
          Uri.parse('$base/vaccines/dashboard/$patientId'),
          headers: await _headers(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (_isOk(body)) {
            return VaccineDashboardSummary.fromJson(
              body['data'] as Map<String, dynamic>,
            );
          }
          last = Exception(body['message'] ?? 'Failed to load vaccine dashboard');
        } else {
          last = Exception('HTTP ${response.statusCode}: vaccine dashboard');
        }
      } catch (e) {
        last = Exception('Vaccine dashboard request failed: $e');
      }
    }
    throw last ?? Exception('Failed to load vaccine dashboard');
  }

  // ── GET /vaccines/card/:patientId ──────────────────────────────────────────

  /// Fetches the full dose-by-dose vaccine card for [patientId].
  static Future<VaccineCardData> getVaccineCard(int patientId) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.get(
          Uri.parse('$base/vaccines/card/$patientId'),
          headers: await _headers(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (_isOk(body)) {
            return VaccineCardData.fromJson(
              body['data'] as Map<String, dynamic>,
            );
          }
          last = Exception(body['message'] ?? 'Failed to load vaccine card');
        } else {
          last = Exception('HTTP ${response.statusCode}: vaccine card');
        }
      } catch (e) {
        last = Exception('Vaccine card request failed: $e');
      }
    }
    throw last ?? Exception('Failed to load vaccine card');
  }

  // ── POST /vaccines/record ──────────────────────────────────────────────────

  /// Admin marks [scheduleId] as given for [patientId].
  static Future<Map<String, dynamic>> markDoseGiven({
    required int patientId,
    required int scheduleId,
    String? givenBy,
    String? notes,
  }) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.post(
          Uri.parse('$base/vaccines/record'),
          headers: await _headers(),
          body: json.encode({
            'patient_id':          patientId,
            'vaccine_schedule_id': scheduleId,
            if (givenBy != null) 'given_by': givenBy,
            if (notes   != null) 'notes':    notes,
          }),
        ).timeout(const Duration(seconds: 10));

        final body = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': _isOk(body),
          'message': body['message'] ?? '',
          'data':    body['data'] ?? {},
        };
      } catch (e) {
        last = Exception('Mark dose given failed: $e');
      }
    }
    return {
      'success': false,
      'message': last?.toString() ?? 'Failed to mark dose as given',
    };
  }

  // ── DELETE /vaccines/record/:recordId ─────────────────────────────────────

  /// Admin removes a completion record (data correction).
  static Future<Map<String, dynamic>> removeDoseRecord(int recordId) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.delete(
          Uri.parse('$base/vaccines/record/$recordId'),
          headers: await _headers(),
        ).timeout(const Duration(seconds: 10));

        final body = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': _isOk(body),
          'message': body['message'] ?? '',
        };
      } catch (e) {
        last = Exception('Remove dose record failed: $e');
      }
    }
    return {
      'success': false,
      'message': last?.toString() ?? 'Failed to remove dose record',
    };
  }
}
