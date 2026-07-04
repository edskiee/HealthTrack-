import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

/// Mirrors the status values returned by the backend computeStatus() function.
enum VaccineDoseStatus {
  completed,
  dueSoon,
  overdue,
  notYetDue,
  locked; // previous dose not yet given — due date cannot be computed

  static VaccineDoseStatus fromString(String s) {
    switch (s) {
      case 'completed':  return VaccineDoseStatus.completed;
      case 'due_soon':   return VaccineDoseStatus.dueSoon;
      case 'overdue':    return VaccineDoseStatus.overdue;
      case 'locked':     return VaccineDoseStatus.locked;
      default:           return VaccineDoseStatus.notYetDue;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineDashboardSummary
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// VaccineDose  (one row inside a VaccineGroup)
// ─────────────────────────────────────────────────────────────────────────────

class VaccineDose {
  final int scheduleId;
  final int? recordId;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;
  final String scheduleFrom;    // 'dob' or 'previous_dose'
  final int intervalDays;

  /// Record-based computed due date ("YYYY-MM-DD").
  /// NULL when status == locked (previous dose not yet given).
  final String? dueDateEstimate;

  /// DOB-based theoretical date — the date the dose "was supposed to be
  /// given on" per the fixed EPI schedule. Always present when DOB is known.
  final String? theoreticalDueDate;

  /// Actual date this dose was administered. NULL if not yet given.
  final String? givenAt;

  /// Stored theoretical date on the child_vaccine_records row (same as
  /// theoreticalDueDate once backfilled; may be null for old records).
  final String? scheduledDate;

  final String? givenBy;
  final String? notes;
  final String? remarks;
  final VaccineDoseStatus status;

  const VaccineDose({
    required this.scheduleId,
    this.recordId,
    required this.doseNumber,
    required this.doseLabel,
    required this.scheduleLabel,
    required this.scheduleFrom,
    required this.intervalDays,
    this.dueDateEstimate,
    this.theoreticalDueDate,
    this.givenAt,
    this.scheduledDate,
    this.givenBy,
    this.notes,
    this.remarks,
    required this.status,
  });

  factory VaccineDose.fromJson(Map<String, dynamic> json) {
    return VaccineDose(
      scheduleId:          _parseInt(json['schedule_id']),
      recordId:            json['record_id'] != null ? _parseInt(json['record_id']) : null,
      doseNumber:          _parseInt(json['dose_number']),
      doseLabel:           json['dose_label']?.toString() ?? '',
      scheduleLabel:       json['schedule_label']?.toString() ?? '',
      scheduleFrom:        json['schedule_from']?.toString() ?? 'dob',
      intervalDays:        _parseInt(json['interval_days']),
      dueDateEstimate:     json['due_date_estimate']?.toString(),
      theoreticalDueDate:  json['theoretical_due_date']?.toString(),
      givenAt:             json['given_at']?.toString(),
      scheduledDate:       json['scheduled_date']?.toString(),
      givenBy:             json['given_by']?.toString(),
      notes:               json['notes']?.toString(),
      remarks:             json['remarks']?.toString(),
      status:              VaccineDoseStatus.fromString(json['status']?.toString() ?? ''),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineGroup
// ─────────────────────────────────────────────────────────────────────────────

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

  /// Aggregate status label shown on the group header chip.
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

// ─────────────────────────────────────────────────────────────────────────────
// VaccinePendingDose
// ─────────────────────────────────────────────────────────────────────────────

class VaccinePendingDose {
  final String vaccineName;
  final String vaccineKey;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;

  /// Record-based due date. NULL when locked.
  final String? dueDateEstimate;

  /// DOB-based theoretical due date (always present when DOB known).
  final String? theoreticalDueDate;

  final int? daysOverdue;
  final VaccineDoseStatus status;

  /// Name of the blocking prior dose (when status == locked).
  final String? waitingFor;

  const VaccinePendingDose({
    required this.vaccineName,
    required this.vaccineKey,
    required this.doseNumber,
    required this.doseLabel,
    required this.scheduleLabel,
    this.dueDateEstimate,
    this.theoreticalDueDate,
    this.daysOverdue,
    required this.status,
    this.waitingFor,
  });

  factory VaccinePendingDose.fromJson(Map<String, dynamic> json) {
    return VaccinePendingDose(
      vaccineName:         json['vaccine_name']?.toString() ?? '',
      vaccineKey:          json['vaccine_key']?.toString() ?? '',
      doseNumber:          _parseInt(json['dose_number']),
      doseLabel:           json['dose_label']?.toString() ?? '',
      scheduleLabel:       json['schedule_label']?.toString() ?? '',
      dueDateEstimate:     json['due_date_estimate']?.toString(),
      theoreticalDueDate:  json['theoretical_due_date']?.toString(),
      daysOverdue:         json['days_overdue'] != null ? _parseInt(json['days_overdue']) : null,
      status:              VaccineDoseStatus.fromString(json['status']?.toString() ?? ''),
      waitingFor:          json['waiting_for']?.toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineCardData
// ─────────────────────────────────────────────────────────────────────────────

class VaccineCardData {
  final String childName;
  final String? dob;
  final String? sex;
  final int ageInDays;
  final int totalDosesRequired;
  final int totalDosesCompleted;
  final bool fullyUpToDate;
  final String overallStatus; // "up_to_date" | "action_needed" | "overdue"
  final List<VaccineGroup> vaccines;
  final List<VaccinePendingDose> pendingDoses;
  final Map<String, dynamic>? nextDue;
  final Map<String, dynamic>? overdueAlert;

  const VaccineCardData({
    required this.childName,
    this.dob,
    this.sex,
    required this.ageInDays,
    required this.totalDosesRequired,
    required this.totalDosesCompleted,
    required this.fullyUpToDate,
    required this.overallStatus,
    required this.vaccines,
    required this.pendingDoses,
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

    final rawPending = json['pending_doses'];
    final pendingDoses = rawPending is List
        ? rawPending
            .whereType<Map<String, dynamic>>()
            .map(VaccinePendingDose.fromJson)
            .toList()
        : <VaccinePendingDose>[];

    return VaccineCardData(
      childName:           json['child_name']?.toString() ?? '',
      dob:                 json['dob']?.toString(),
      sex:                 json['sex']?.toString(),
      ageInDays:           _parseInt(json['age_in_days']),
      totalDosesRequired:  _parseInt(json['total_doses_required']),
      totalDosesCompleted: _parseInt(json['total_doses_completed']),
      fullyUpToDate:       json['fully_up_to_date'] == true,
      overallStatus:       json['overall_status']?.toString() ?? 'up_to_date',
      vaccines:            vaccines,
      pendingDoses:        pendingDoses,
      nextDue:             json['next_due'] as Map<String, dynamic>?,
      overdueAlert:        json['overdue_alert'] as Map<String, dynamic>?,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// All completed doses across all vaccine groups, flattened.
  List<VaccineCompletedEntry> get completedDoses => vaccines
      .expand((g) => g.doses
          .where((d) => d.status == VaccineDoseStatus.completed)
          .map((d) => VaccineCompletedEntry(vaccineName: g.vaccineName, dose: d)))
      .toList();
}

/// Pairs a completed VaccineDose with its parent vaccine name.
class VaccineCompletedEntry {
  final String vaccineName;
  final VaccineDose dose;
  const VaccineCompletedEntry({required this.vaccineName, required this.dose});
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineService
// ─────────────────────────────────────────────────────────────────────────────

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

  // ── GET /vaccines/dashboard/:patientId ──────────────────────────────────

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
            return VaccineDashboardSummary.fromJson(body['data'] as Map<String, dynamic>);
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

  // ── GET /vaccines/card/:patientId ────────────────────────────────────────

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
            return VaccineCardData.fromJson(body['data'] as Map<String, dynamic>);
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

  // ── POST /vaccines/record ────────────────────────────────────────────────

  /// Admin marks [scheduleId] as given for [patientId].
  /// [givenAtOverride] — optional ISO date "YYYY-MM-DD" if the actual
  /// administration date is not today (retroactive entry).
  static Future<Map<String, dynamic>> markDoseGiven({
    required int patientId,
    required int scheduleId,
    String? givenBy,
    String? notes,
    String? remarks,
    int? completedByUserId,
    String? givenAtOverride,
  }) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.post(
          Uri.parse('$base/vaccines/record'),
          headers: await _headers(),
          body: json.encode({
            'patient_id':           patientId,
            'vaccine_schedule_id':  scheduleId,
            if (givenBy != null)            'given_by':             givenBy,
            if (notes  != null)             'notes':                notes,
            if (remarks != null)            'remarks':              remarks,
            if (completedByUserId != null)  'completed_by_user_id': completedByUserId,
            if (givenAtOverride != null)    'given_at_override':    givenAtOverride,
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

  // ── DELETE /vaccines/record/:recordId ────────────────────────────────────

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
