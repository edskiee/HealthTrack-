import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'admin_session_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum VaccineDoseStatus {
  completed,
  overdue,
  dueSoon,
  notYetDue,
  locked;

  static VaccineDoseStatus fromString(String s) {
    switch (s) {
      case 'completed':  return VaccineDoseStatus.completed;
      case 'overdue':    return VaccineDoseStatus.overdue;
      case 'due_soon':   return VaccineDoseStatus.dueSoon;
      case 'locked':     return VaccineDoseStatus.locked;
      default:           return VaccineDoseStatus.notYetDue;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineDose
// ─────────────────────────────────────────────────────────────────────────────

class VaccineDose {
  final int scheduleId;
  final int? recordId;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;
  final String scheduleFrom;   // 'dob' | 'previous_dose'
  final int intervalDays;

  /// Record-based computed due date. NULL when locked.
  final String? dueDateEstimate;

  /// DOB-based theoretical date — "was supposed to be given on".
  final String? theoreticalDueDate;

  /// Actual date administered (null if not yet given).
  final String? givenAt;

  /// Stored theoretical date on the record row (same as theoreticalDueDate
  /// once backfilled; may be null for legacy rows).
  final String? scheduledDate;

  final String? givenBy;
  final String? notes;
  final String? remarks;
  final VaccineDoseStatus status;

  const VaccineDose({
    required this.scheduleId,
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
    this.recordId,
    required this.status,
  });

  factory VaccineDose.fromJson(Map<String, dynamic> j) {
    return VaccineDose(
      scheduleId:         _i(j['schedule_id']),
      recordId:           j['record_id'] != null ? _i(j['record_id']) : null,
      doseNumber:         _i(j['dose_number']),
      doseLabel:          j['dose_label']?.toString() ?? '',
      scheduleLabel:      j['schedule_label']?.toString() ?? '',
      scheduleFrom:       j['schedule_from']?.toString() ?? 'dob',
      intervalDays:       _i(j['interval_days']),
      dueDateEstimate:    j['due_date_estimate']?.toString(),
      theoreticalDueDate: j['theoretical_due_date']?.toString(),
      givenAt:            j['given_at']?.toString(),
      scheduledDate:      j['scheduled_date']?.toString(),
      givenBy:            j['given_by']?.toString(),
      notes:              j['notes']?.toString(),
      remarks:            j['remarks']?.toString(),
      status:             VaccineDoseStatus.fromString(j['status']?.toString() ?? ''),
    );
  }

  static int _i(dynamic v) {
    if (v is int)    return v;
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

  factory VaccineGroup.fromJson(Map<String, dynamic> j) {
    final rawDoses = (j['doses'] as List?) ?? [];
    return VaccineGroup(
      vaccineName: j['vaccine_name']?.toString() ?? '',
      vaccineKey:  j['vaccine_key']?.toString() ?? '',
      doses: rawDoses
          .map((d) => VaccineDose.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PendingDose
// ─────────────────────────────────────────────────────────────────────────────

class PendingDose {
  final String vaccineName;
  final String vaccineKey;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;

  /// Record-based due date. NULL when locked.
  final String? dueDateEstimate;

  /// DOB-based theoretical due date.
  final String? theoreticalDueDate;

  final int? daysOverdue;
  final VaccineDoseStatus status;
  final String? waitingFor;

  const PendingDose({
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

  factory PendingDose.fromJson(Map<String, dynamic> j) {
    return PendingDose(
      vaccineName:        j['vaccine_name']?.toString() ?? '',
      vaccineKey:         j['vaccine_key']?.toString() ?? '',
      doseNumber:         _i(j['dose_number']),
      doseLabel:          j['dose_label']?.toString() ?? '',
      scheduleLabel:      j['schedule_label']?.toString() ?? '',
      dueDateEstimate:    j['due_date_estimate']?.toString(),
      theoreticalDueDate: j['theoretical_due_date']?.toString(),
      daysOverdue:        j['days_overdue'] != null ? _i(j['days_overdue']) : null,
      status:             VaccineDoseStatus.fromString(j['status']?.toString() ?? ''),
      waitingFor:         j['waiting_for']?.toString(),
    );
  }

  static int _i(dynamic v) {
    if (v is int)    return v;
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
  final String? serviceType;
  final bool dobNeedsVerification;
  final bool notImmunization;
  final int ageInDays;
  final int totalDosesRequired;
  final int totalDosesCompleted;
  final bool fullyUpToDate;
  final String overallStatus;
  final List<VaccineGroup> vaccines;
  final List<PendingDose> pendingDoses;

  const VaccineCardData({
    required this.childName,
    this.dob,
    this.sex,
    this.serviceType,
    required this.dobNeedsVerification,
    required this.notImmunization,
    required this.ageInDays,
    required this.totalDosesRequired,
    required this.totalDosesCompleted,
    required this.fullyUpToDate,
    required this.overallStatus,
    required this.vaccines,
    required this.pendingDoses,
  });

  factory VaccineCardData.fromJson(Map<String, dynamic> j) {
    final rawVaccines = (j['vaccines']      as List?) ?? [];
    final rawPending  = (j['pending_doses'] as List?) ?? [];
    return VaccineCardData(
      childName:           j['child_name']?.toString() ?? 'Unknown',
      dob:                 j['dob']?.toString(),
      sex:                 j['sex']?.toString(),
      serviceType:         j['service_type']?.toString(),
      dobNeedsVerification: j['dob_needs_verification'] == true || j['dob_needs_verification'] == 1,
      notImmunization:     j['not_immunization'] == true,
      ageInDays:           (j['age_in_days'] as num?)?.toInt() ?? 0,
      totalDosesRequired:  (j['total_doses_required'] as num?)?.toInt() ?? 0,
      totalDosesCompleted: (j['total_doses_completed'] as num?)?.toInt() ?? 0,
      fullyUpToDate:       j['fully_up_to_date'] == true,
      overallStatus:       j['overall_status']?.toString() ?? 'up_to_date',
      vaccines: rawVaccines
          .map((v) => VaccineGroup.fromJson(v as Map<String, dynamic>))
          .toList(),
      pendingDoses: rawPending
          .map((p) => PendingDose.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  List<VaccineDose> get completedDoses => vaccines
      .expand((g) => g.doses)
      .where((d) => d.status == VaccineDoseStatus.completed)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineBadgeSummary
// ─────────────────────────────────────────────────────────────────────────────

class VaccineBadgeSummary {
  final String overallStatus;
  final int totalDosesRequired;
  final int totalDosesCompleted;
  final String? nextDueDate;
  final bool dobNeedsVerification;
  final bool notImmunization;

  const VaccineBadgeSummary({
    required this.overallStatus,
    required this.totalDosesRequired,
    required this.totalDosesCompleted,
    this.nextDueDate,
    required this.dobNeedsVerification,
    required this.notImmunization,
  });

  factory VaccineBadgeSummary.fromJson(Map<String, dynamic> j) {
    return VaccineBadgeSummary(
      overallStatus:        j['overall_status']?.toString() ?? 'up_to_date',
      totalDosesRequired:   (j['total_doses_required'] as num?)?.toInt() ?? 0,
      totalDosesCompleted:  (j['total_doses_completed'] as num?)?.toInt() ?? 0,
      nextDueDate:          j['next_due_date']?.toString(),
      dobNeedsVerification: j['dob_needs_verification'] == true || j['dob_needs_verification'] == 1,
      notImmunization:      j['not_immunization'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VaccineTrackingService
// ─────────────────────────────────────────────────────────────────────────────

class VaccineTrackingService {
  static String get _base => ApiConfig.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<VaccineCardData> getAdminVaccineCard(int patientId) async {
    final uri = Uri.parse('$_base/vaccines/admin/card/$patientId');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message']?.toString() ?? 'HTTP ${response.statusCode}');
    }
    if (body['success'] != true && body['success'] != 1) {
      throw Exception(body['message']?.toString() ?? 'Failed to load vaccine card');
    }
    return VaccineCardData.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<VaccineBadgeSummary> getAdminBadge(int patientId) async {
    final uri = Uri.parse('$_base/vaccines/admin/badge/$patientId');
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));

    final body = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message']?.toString() ?? 'HTTP ${response.statusCode}');
    }
    if (body['success'] != true && body['success'] != 1) {
      throw Exception(body['message']?.toString() ?? 'Failed to load badge');
    }
    return VaccineBadgeSummary.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Mark a dose as given.
  /// [givenAtOverride] — optional ISO date if admin is entering retroactively.
  static Future<Map<String, dynamic>> markDoseGiven({
    required int patientId,
    required int scheduleId,
    String? givenBy,
    String? notes,
    String? remarks,
    int? completedByUserId,
    String? givenAtOverride,
  }) async {
    final uri = Uri.parse('$_base/vaccines/record');
    final response = await http
        .post(
          uri,
          headers: await _headers(),
          body: json.encode({
            'patient_id':           patientId,
            'vaccine_schedule_id':  scheduleId,
            if (givenBy != null)            'given_by':             givenBy,
            if (notes   != null)            'notes':                notes,
            if (remarks != null)            'remarks':              remarks,
            if (completedByUserId != null)  'completed_by_user_id': completedByUserId,
            if (givenAtOverride != null)    'given_at_override':    givenAtOverride,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = json.decode(response.body) as Map<String, dynamic>;
    return {
      'success': body['success'] == true || body['success'] == 1,
      'message': body['message']?.toString() ?? '',
      'data':    body['data'] ?? {},
    };
  }

  /// Remove a completion record (data correction).
  static Future<Map<String, dynamic>> removeDoseRecord(int recordId) async {
    final uri = Uri.parse('$_base/vaccines/record/$recordId');
    final response = await http
        .delete(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    final body = json.decode(response.body) as Map<String, dynamic>;
    return {
      'success': body['success'] == true || body['success'] == 1,
      'message': body['message']?.toString() ?? '',
    };
  }
}
