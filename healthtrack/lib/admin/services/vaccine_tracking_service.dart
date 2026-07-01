import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import 'admin_session_storage.dart';

/// Dart model representing a single vaccine dose row.
class VaccineDose {
  final int scheduleId;
  final int? recordId;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;
  final String? dueDateEstimate;
  final String? givenAt;
  final String? givenBy;
  final String? notes;
  final VaccineDoseStatus status;

  const VaccineDose({
    required this.scheduleId,
    required this.doseNumber,
    required this.doseLabel,
    required this.scheduleLabel,
    this.dueDateEstimate,
    this.givenAt,
    this.givenBy,
    this.notes,
    this.recordId,
    required this.status,
  });

  factory VaccineDose.fromJson(Map<String, dynamic> j) {
    return VaccineDose(
      scheduleId:       (j['schedule_id'] as num).toInt(),
      recordId:         j['record_id'] != null ? (j['record_id'] as num).toInt() : null,
      doseNumber:       (j['dose_number'] as num).toInt(),
      doseLabel:        j['dose_label']?.toString() ?? '',
      scheduleLabel:    j['schedule_label']?.toString() ?? '',
      dueDateEstimate:  j['due_date_estimate']?.toString(),
      givenAt:          j['given_at']?.toString(),
      givenBy:          j['given_by']?.toString(),
      notes:            j['notes']?.toString(),
      status:           VaccineDoseStatus.fromString(j['status']?.toString() ?? ''),
    );
  }
}

/// Status of a single vaccine dose.
enum VaccineDoseStatus {
  completed,
  overdue,
  dueSoon,
  notYetDue,
  locked;

  static VaccineDoseStatus fromString(String s) {
    switch (s) {
      case 'completed':   return VaccineDoseStatus.completed;
      case 'overdue':     return VaccineDoseStatus.overdue;
      case 'due_soon':    return VaccineDoseStatus.dueSoon;
      case 'locked':      return VaccineDoseStatus.locked;
      default:            return VaccineDoseStatus.notYetDue;
    }
  }
}

/// A named vaccine group (e.g. "Pentavalent") with its doses.
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

/// A pending dose entry for the urgency-sorted pending section.
class PendingDose {
  final String vaccineName;
  final String vaccineKey;
  final int doseNumber;
  final String doseLabel;
  final String scheduleLabel;
  final String? dueDateEstimate;
  final String? maxDateEstimate;
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
    this.maxDateEstimate,
    this.daysOverdue,
    required this.status,
    this.waitingFor,
  });

  factory PendingDose.fromJson(Map<String, dynamic> j) {
    return PendingDose(
      vaccineName:      j['vaccine_name']?.toString() ?? '',
      vaccineKey:       j['vaccine_key']?.toString() ?? '',
      doseNumber:       (j['dose_number'] as num).toInt(),
      doseLabel:        j['dose_label']?.toString() ?? '',
      scheduleLabel:    j['schedule_label']?.toString() ?? '',
      dueDateEstimate:  j['due_date_estimate']?.toString(),
      maxDateEstimate:  j['max_date_estimate']?.toString(),
      daysOverdue:      j['days_overdue'] != null ? (j['days_overdue'] as num).toInt() : null,
      status:           VaccineDoseStatus.fromString(j['status']?.toString() ?? ''),
      waitingFor:       j['waiting_for']?.toString(),
    );
  }
}

/// Full vaccine card data returned by GET /vaccines/admin/card/:id
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
  final String overallStatus; // "up_to_date" | "action_needed" | "overdue"
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
    final rawVaccines     = (j['vaccines']      as List?) ?? [];
    final rawPending      = (j['pending_doses'] as List?) ?? [];
    return VaccineCardData(
      childName:            j['child_name']?.toString() ?? 'Unknown',
      dob:                  j['dob']?.toString(),
      sex:                  j['sex']?.toString(),
      serviceType:          j['service_type']?.toString(),
      dobNeedsVerification: j['dob_needs_verification'] == true || j['dob_needs_verification'] == 1,
      notImmunization:      j['not_immunization'] == true,
      ageInDays:            (j['age_in_days'] as num?)?.toInt() ?? 0,
      totalDosesRequired:   (j['total_doses_required'] as num?)?.toInt() ?? 0,
      totalDosesCompleted:  (j['total_doses_completed'] as num?)?.toInt() ?? 0,
      fullyUpToDate:        j['fully_up_to_date'] == true,
      overallStatus:        j['overall_status']?.toString() ?? 'up_to_date',
      vaccines: rawVaccines
          .map((v) => VaccineGroup.fromJson(v as Map<String, dynamic>))
          .toList(),
      pendingDoses: rawPending
          .map((p) => PendingDose.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// All completed doses across all vaccine groups (for the Completed section).
  List<VaccineDose> get completedDoses => vaccines
      .expand((g) => g.doses)
      .where((d) => d.status == VaccineDoseStatus.completed)
      .toList();
}

/// Badge summary returned by GET /vaccines/admin/badge/:id
class VaccineBadgeSummary {
  final String overallStatus; // "overdue"|"action_needed"|"up_to_date"|"unverified"
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

/// Service class — all API calls for the admin vaccine tracking feature.
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

  /// Fetch the full vaccine card for a patient.
  /// Returns [VaccineCardData] or throws on error.
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

  /// Fetch the lightweight badge summary for a single patient card.
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
}
