import 'package:flutter/foundation.dart';

/// Lightweight gate for anonymized telemetry — toggled from persisted admin prefs.
class AnalyticsGate {
  AnalyticsGate._();

  static bool recording = false;

  static void setEnabled(bool v) {
    recording = v;
  }

  /// Call from admin flows when telemetry would have been queued.
  static void record(String event,
      [Map<String, Object?> facts = const {}]) {
    if (!recording) return;
    if (kDebugMode) {
      debugPrint('[analytics gated] $event $facts');
    }
  }
}
