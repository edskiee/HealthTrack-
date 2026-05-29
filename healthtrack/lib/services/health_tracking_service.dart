import 'package:flutter/foundation.dart';
import 'package:healthtrack/utils/time_utils.dart';

/// Schedule-based health tracking for Immunization / Maternal Care appointments.
/// Uses existing `appointments` API maps: `appointment_type`, `status`,
/// `appointment_date`, `appointment_time`.

enum HealthScheduleCategory { immunization, maternal }

/// Unified progress status for Health Tracking UI (maps from [HealthTrackingRowKind]).
enum ProgressStatus { completed, inProgress, missed }

enum HealthTrackingBadge {
  complete,
  inProgress,
  notStarted,
  upcoming,
}

/// Row displayed under Health Tracking (Approved → in progress, Completed, Missed / no_show).
enum HealthTrackingRowKind { inProgress, completed, missed }

@immutable
class HealthTrackingStats {
  final int totalCount;
  final int completedCount;
  final double completionRatePercent;
  final DateTime? nextSessionDate;
  final HealthTrackingBadge badge;

  const HealthTrackingStats({
    required this.totalCount,
    required this.completedCount,
    required this.completionRatePercent,
    required this.nextSessionDate,
    required this.badge,
  });

  String get sessionsCompletedLabel =>
      '$completedCount out of $totalCount sessions completed';
}

class HealthTrackingService {
  HealthTrackingService._();

  /// Local calendar day match (device timezone), per product spec.
  static bool isSameLocalCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isLocalToday(DateTime entryDate) {
    return isSameLocalCalendarDay(entryDate, DateTime.now());
  }

  static ProgressStatus progressStatusFromRowKind(HealthTrackingRowKind kind) {
    return switch (kind) {
      HealthTrackingRowKind.completed => ProgressStatus.completed,
      HealthTrackingRowKind.inProgress => ProgressStatus.inProgress,
      HealthTrackingRowKind.missed => ProgressStatus.missed,
    };
  }

  /// Parses API `completed_at` / `missed_at` (UTC) to **device local** [DateTime].
  static DateTime? parseApiTimestampToLocal(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      final normalized = s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}Z';
      return DateTime.parse(normalized).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// When the progress event occurred — for sorting (newest first). Uses outcome
  /// timestamps when present, else scheduled appointment date/time.
  static DateTime? progressEventTimestamp(Map<String, dynamic> appt) {
    final kind = rowKindForHealthTracking(appt);
    if (kind == null) return null;
    switch (kind) {
      case HealthTrackingRowKind.completed:
        final t = parseApiTimestampToLocal(appt['completed_at']);
        if (t != null) return t;
        return parseAppointmentDateTime(appt);
      case HealthTrackingRowKind.missed:
        final t = parseApiTimestampToLocal(appt['missed_at']);
        if (t != null) return t;
        return parseAppointmentDateTime(appt);
      case HealthTrackingRowKind.inProgress:
        return parseAppointmentDateTime(appt);
    }
  }

  /// Whether this row belongs in the **default** “today only” list (local date).
  static bool isTrackingEntryOnLocalToday(Map<String, dynamic> appt) {
    final kind = rowKindForHealthTracking(appt);
    if (kind == null) return false;
    switch (kind) {
      case HealthTrackingRowKind.completed:
        final t = parseApiTimestampToLocal(appt['completed_at']) ??
            parseAppointmentDateTime(appt);
        return t != null && isLocalToday(t);
      case HealthTrackingRowKind.missed:
        final t = parseApiTimestampToLocal(appt['missed_at']) ??
            parseAppointmentDateTime(appt);
        return t != null && isLocalToday(t);
      case HealthTrackingRowKind.inProgress:
        final dt = parseAppointmentDateTime(appt);
        return dt != null && isLocalToday(dt);
    }
  }

  static String moduleDisplayName(String? appointmentType) {
    if (isMaternalType(appointmentType)) return 'Maternal Care';
    if (isImmunizationType(appointmentType)) return 'Immunization';
    return 'Care';
  }

  /// Primary line for activity / task (notes preferred, else type + context).
  static String activityTitleForEntry(Map<String, dynamic> appt) {
    final notes = (appt['notes'] ?? '').toString().trim();
    if (notes.isNotEmpty) return notes;
    final type = (appt['appointment_type'] ?? '').toString().trim();
    final doctor = (appt['doctor_name'] ?? '').toString().trim();
    if (type.isNotEmpty && doctor.isNotEmpty) return '$type — $doctor';
    if (type.isNotEmpty) return type;
    return 'Scheduled visit';
  }

  /// Full history for Immunization **and** Maternal Care, deduped by id, newest first.
  static List<Map<String, dynamic>> allTrackingEntriesMerged(
    List<Map<String, dynamic>> appointments,
  ) {
    final imm = trackingEntriesForCategory(
      appointments,
      HealthScheduleCategory.immunization,
    );
    final mat = trackingEntriesForCategory(
      appointments,
      HealthScheduleCategory.maternal,
    );
    final seen = <dynamic>{};
    final out = <Map<String, dynamic>>[];
    for (final a in [...imm, ...mat]) {
      final id = a['id'];
      if (id != null) {
        if (seen.contains(id)) continue;
        seen.add(id);
      }
      out.add(a);
    }
    out.sort((a, b) {
      final ta = progressEventTimestamp(a);
      final tb = progressEventTimestamp(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return out;
  }

  static bool _isCancelled(Map<String, dynamic> appt) {
    final s = (appt['status'] ?? '').toString().toLowerCase().trim();
    return s == 'cancelled';
  }

  static bool _isCompleted(Map<String, dynamic> appt) {
    final s = (appt['status'] ?? '').toString().toLowerCase().trim();
    return s == 'completed';
  }

  static String _normStatus(Map<String, dynamic> appt) {
    return (appt['status'] ?? '').toString().toLowerCase().trim();
  }

  /// Approved visits currently shown to the user as **In Progress**.
  static HealthTrackingRowKind? rowKindForHealthTracking(Map<String, dynamic> appt) {
    final s = _normStatus(appt);
    if (s == 'approved') return HealthTrackingRowKind.inProgress;
    if (s == 'completed') return HealthTrackingRowKind.completed;
    if (s == 'no_show') return HealthTrackingRowKind.missed;
    return null;
  }

  /// Appointments that belong on the Health Tracking list for the selected category.
  static List<Map<String, dynamic>> trackingEntriesForCategory(
    List<Map<String, dynamic>> appointments,
    HealthScheduleCategory category,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final a in appointments) {
      if (_isCancelled(a)) continue;
      final type = a['appointment_type']?.toString();
      final inCat = switch (category) {
        HealthScheduleCategory.immunization => isImmunizationType(type),
        HealthScheduleCategory.maternal => isMaternalType(type),
      };
      if (!inCat) continue;
      if (rowKindForHealthTracking(a) == null) continue;
      out.add(a);
    }
    out.sort((a, b) {
      final ta = progressEventTimestamp(a);
      final tb = progressEventTimestamp(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return out;
  }

  static String categoryLabelForType(String? appointmentType) {
    return moduleDisplayName(appointmentType);
  }

  /// Formats `completed_at` / `missed_at` from the API (UTC `DATETIME`) for display in Manila.
  static String formatOutcomeTimestamp(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    final normalized = s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}Z';
    try {
      return TimeUtils.formatUtcTimestampToManila(
        normalized,
        pattern: 'MMMM d, y • h:mm a',
      );
    } catch (_) {
      return s;
    }
  }

  static String formatAppointmentScheduleLine(Map<String, dynamic> appt) {
    final date = (appt['appointment_date'] ?? '').toString();
    final time = (appt['appointment_time'] ?? '').toString();
    if (date.isEmpty) return 'Schedule TBD';
    return TimeUtils.formatAppointmentUtcDateTime(
      date,
      time,
      pattern: 'MMMM d, y • h:mm a',
    );
  }

  static bool isImmunizationType(String? appointmentType) {
    final t = (appointmentType ?? '').toLowerCase().trim();
    return t == 'immunization' || t.contains('immunization');
  }

  static bool isMaternalType(String? appointmentType) {
    final t = (appointmentType ?? '').toLowerCase().trim();
    return t == 'maternal care' || t.contains('maternal');
  }

  static List<Map<String, dynamic>> filterForCategory(
    List<Map<String, dynamic>> appointments,
    HealthScheduleCategory category,
  ) {
    return appointments.where((a) {
      if (_isCancelled(a)) return false;
      final type = a['appointment_type']?.toString();
      switch (category) {
        case HealthScheduleCategory.immunization:
          return isImmunizationType(type);
        case HealthScheduleCategory.maternal:
          return isMaternalType(type);
      }
    }).toList();
  }

  static bool hasImmunizationSchedules(List<Map<String, dynamic>> appointments) {
    return appointments.any((a) {
      if (_isCancelled(a)) return false;
      return isImmunizationType(a['appointment_type']?.toString());
    });
  }

  static bool hasMaternalSchedules(List<Map<String, dynamic>> appointments) {
    return appointments.any((a) {
      if (_isCancelled(a)) return false;
      return isMaternalType(a['appointment_type']?.toString());
    });
  }

  static DateTime? parseAppointmentDateTime(Map<String, dynamic> appt) {
    final dateRaw = appt['appointment_date'];
    final timeRaw = appt['appointment_time'];
    String? dateStr;
    if (dateRaw is DateTime) {
      dateStr = dateRaw.toIso8601String().split('T').first;
    } else {
      dateStr = dateRaw?.toString();
    }
    if (dateStr == null || dateStr.isEmpty) return null;

    String timeStr = '00:00:00';
    if (timeRaw != null) {
      if (timeRaw is DateTime) {
        timeStr =
            '${timeRaw.hour.toString().padLeft(2, '0')}:${timeRaw.minute.toString().padLeft(2, '0')}:${timeRaw.second.toString().padLeft(2, '0')}';
      } else {
        final t = timeRaw.toString();
        if (t.length >= 5) {
          timeStr = t.length >= 8 ? t : '$t:00';
        }
      }
    }

    try {
      final datePart = dateStr.split('T').first;
      final parts = datePart.split('-');
      if (parts.length != 3) return null;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final timeParts = timeStr.split(':');
      final hh = timeParts.isNotEmpty ? int.parse(timeParts[0]) : 0;
      final mm = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final ss = timeParts.length > 2 ? int.parse(timeParts[2].split('.').first) : 0;
      return DateTime(y, m, d, hh, mm, ss);
    } catch (_) {
      return null;
    }
  }

  /// Computes progress for one category. Cancelled rows are excluded from totals.
  static HealthTrackingStats computeStats(
    List<Map<String, dynamic>> appointments,
    HealthScheduleCategory category,
  ) {
    final relevant = filterForCategory(appointments, category);
    final total = relevant.length;
    final completed = relevant.where(_isCompleted).length;

    final rate = total == 0 ? 0.0 : (completed / total) * 100.0;

    final incomplete = relevant.where((a) => !_isCompleted(a)).toList();
    DateTime? nextSession;
    if (incomplete.isNotEmpty) {
      final withDates = <Map<String, dynamic>>[];
      for (final a in incomplete) {
        final dt = parseAppointmentDateTime(a);
        if (dt != null) {
          withDates.add(a);
        }
      }
      if (withDates.isNotEmpty) {
        withDates.sort((a, b) {
          final da = parseAppointmentDateTime(a)!;
          final db = parseAppointmentDateTime(b)!;
          return da.compareTo(db);
        });
        final now = DateTime.now();
        final upcoming = withDates
            .map(parseAppointmentDateTime)
            .whereType<DateTime>()
            .where((dt) => dt.isAfter(now))
            .toList()
          ..sort();
        if (upcoming.isNotEmpty) {
          nextSession = upcoming.first;
        } else {
          nextSession = parseAppointmentDateTime(withDates.first);
        }
      }
    }

    final badge = _resolveBadge(
      total: total,
      completed: completed,
      nextSession: nextSession,
    );

    return HealthTrackingStats(
      totalCount: total,
      completedCount: completed,
      completionRatePercent: rate,
      nextSessionDate: nextSession,
      badge: badge,
    );
  }

  static HealthTrackingBadge _resolveBadge({
    required int total,
    required int completed,
    required DateTime? nextSession,
  }) {
    if (total == 0) {
      return HealthTrackingBadge.notStarted;
    }
    if (completed >= total) {
      return HealthTrackingBadge.complete;
    }
    if (completed > 0) {
      return HealthTrackingBadge.inProgress;
    }
    // completed == 0 && total > 0
    final now = DateTime.now();
    if (nextSession != null && nextSession.isAfter(now)) {
      return HealthTrackingBadge.upcoming;
    }
    return HealthTrackingBadge.notStarted;
  }
}
