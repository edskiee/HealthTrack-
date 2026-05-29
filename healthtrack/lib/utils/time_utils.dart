import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Utility class for standardized time formatting across the HealthTrack system
class TimeUtils {
  static const String _manilaTimezone = 'Asia/Manila';
  static bool _timezoneInitialized = false;
  static tz.Location? _manilaLocation;

  static void _ensureTimezoneInitialized() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _manilaLocation = tz.getLocation(_manilaTimezone);
    _timezoneInitialized = true;
  }

  static tz.TZDateTime? _parseUtcToManila(String rawTimestamp) {
    try {
      _ensureTimezoneInitialized();
      final normalized = rawTimestamp.trim();
      if (normalized.isEmpty) return null;
      final utc = DateTime.parse(normalized).toUtc();
      return tz.TZDateTime.from(utc, _manilaLocation!);
    } catch (_) {
      return null;
    }
  }

  static DateTime? parseUtcTimestampToManila(String utcTimestamp) {
    return _parseUtcToManila(utcTimestamp);
  }

  static DateTime? manilaNow() {
    try {
      _ensureTimezoneInitialized();
      return tz.TZDateTime.now(_manilaLocation!);
    } catch (_) {
      return null;
    }
  }

  /// Converts UTC timestamp into fixed Asia/Manila timezone display.
  /// Never uses device local timezone.
  static String formatUtcTimestampToManila(
    String utcTimestamp, {
    String pattern = 'MMMM dd, yyyy hh:mm a',
  }) {
    final manilaDateTime = _parseUtcToManila(utcTimestamp);
    if (manilaDateTime == null) return utcTimestamp;
    return DateFormat(pattern).format(manilaDateTime);
  }

  /// Source-of-truth formatter for appointment UTC date + UTC time fields.
  static String formatAppointmentUtcDateTime(
    String appointmentDate,
    String appointmentTime, {
    String pattern = 'MMMM dd, yyyy hh:mm a',
  }) {
    final raw = '${appointmentDate.trim()} ${appointmentTime.trim()}'.trim();
    if (raw.isEmpty) return '';
    return formatUtcTimestampToManila(raw, pattern: pattern);
  }

  /// Format a DateTime object to 12-hour format with AM/PM
  /// Example: 2:30 PM
  static String formatTime12Hour(DateTime dateTime) {
    final formatter = DateFormat('h:mm a');
    return formatter.format(dateTime);
  }

  /// Format a time string (HH:MM:SS or HH:MM) to 12-hour format with AM/PM
  /// Example: "14:30:00" -> "2:30 PM"
  static String formatTimeString12Hour(String timeString) {
    try {
      // Handle different time formats
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final dateTime = DateTime(2023, 1, 1, hour, minute);
          return formatTime12Hour(dateTime);
        }
      }
      return timeString; // Return as-is if parsing fails
    } catch (e) {
      return timeString; // Return as-is if parsing fails
    }
  }

  /// Format a DateTime object to a readable date format
  /// Example: Dec 25, 2023
  static String formatDate(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy');
    return formatter.format(dateTime);
  }

  /// Format a date string (YYYY-MM-DD) to a readable format
  /// Example: "2023-12-25" -> "Dec 25, 2023"
  static String formatDateString(String dateString) {
    try {
      return formatUtcTimestampToManila(dateString, pattern: 'MMM d, yyyy');
    } catch (e) {
      return dateString; // Return as-is if parsing fails
    }
  }

  /// Format a DateTime to show both date and time in 12-hour format
  /// Example: Dec 25, 2023 at 2:30 PM
  static String formatDateTime(DateTime dateTime) {
    final date = formatDate(dateTime);
    final time = formatTime12Hour(dateTime);
    return '$date at $time';
  }

  /// Format a timestamp string to show both date and time in 12-hour format
  /// Handles various formats like "2023-12-25 14:30:00" or "2023-12-25T14:30:00Z"
  static String formatTimestampString(String timestamp) {
    try {
      return formatUtcTimestampToManila(timestamp, pattern: 'MMM d, yyyy \'at\' h:mm a');
    } catch (e) {
      return timestamp; // Return as-is if parsing fails
    }
  }

  /// Format relative time (e.g., "2 hours ago", "Just now")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return formatDate(dateTime);
    }
  }

  /// Format relative time from timestamp string
  static String formatRelativeTimeString(String timestamp) {
    try {
      DateTime dateTime;
      if (timestamp.contains('T')) {
        dateTime = DateTime.parse(timestamp);
      } else {
        // Assume format like "2023-12-25 14:30:00"
        final parts = timestamp.split(' ');
        if (parts.length == 2) {
          final datePart = parts[0];
          final timePart = parts[1];
          dateTime = DateTime.parse('$datePart $timePart');
        } else {
          dateTime = DateTime.parse(timestamp);
        }
      }
      return formatRelativeTime(dateTime);
    } catch (e) {
      return timestamp; // Return as-is if parsing fails
    }
  }
}