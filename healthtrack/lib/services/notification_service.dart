import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session_storage.dart';

/// Service for user-facing notification operations.
/// Uses direct HTTP (no ApiService health-check overhead) with the user JWT.
class NotificationService {
  static List<String> get _urls => ApiConfig.fallbackBaseUrls;

  // No-op initialize kept for compatibility with callers.
  static Future<void> initialize() async {}

  static Future<Map<String, String>> _authHeaders() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static bool _isSuccess(dynamic data) {
    final s = data['success'];
    if (s is bool) return s;
    if (s is String) return s.toLowerCase() == 'true';
    if (s is int) return s == 1;
    return false;
  }

  // ── GET user notifications ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    final headers = await _authHeaders();
    Exception? last;
    for (final base in _urls) {
      try {
        final res = await http
            .get(Uri.parse('$base/notifications/user/$userId'), headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (_isSuccess(data)) {
            return List<Map<String, dynamic>>.from(data['data'] ?? []);
          }
          last = Exception(data['message'] ?? 'Failed to fetch notifications');
        } else {
          last = Exception('HTTP ${res.statusCode}: Failed to fetch notifications');
        }
      } catch (e) {
        last = Exception('Failed to fetch notifications: $e');
      }
    }
    throw last ?? Exception('Failed to fetch notifications');
  }

  // ── GET unread count ──────────────────────────────────────────────────────

  static Future<int> getUnreadNotificationsCount(int userId) async {
    final headers = await _authHeaders();
    Exception? last;
    for (final base in _urls) {
      try {
        final res = await http
            .get(Uri.parse('$base/notifications/user/$userId/unread-count'),
                headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (_isSuccess(data)) return data['count'] ?? 0;
          last = Exception(data['message'] ?? 'Failed to fetch unread count');
        } else {
          last = Exception('HTTP ${res.statusCode}: Failed to fetch unread count');
        }
      } catch (e) {
        last = Exception('Failed to fetch unread count: $e');
      }
    }
    throw last ?? Exception('Failed to fetch unread count');
  }

  // ── Mark single notification as read ─────────────────────────────────────

  static Future<bool> markNotificationAsRead(int notificationId) async {
    final headers = await _authHeaders();
    for (final base in _urls) {
      try {
        final res = await http
            .put(Uri.parse('$base/notifications/$notificationId/read'),
                headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          return _isSuccess(data);
        }
      } catch (_) {
        continue;
      }
    }
    return false; // silent fail — non-critical
  }

  // ── Mark all notifications as read ───────────────────────────────────────

  static Future<bool> markAllNotificationsAsRead(int userId) async {
    final headers = await _authHeaders();
    for (final base in _urls) {
      try {
        final res = await http
            .put(Uri.parse('$base/notifications/user/$userId/mark-all-read'),
                headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          return _isSuccess(data);
        }
      } catch (_) {
        continue;
      }
    }
    return false; // silent fail — non-critical
  }

  // ── Delete notification ───────────────────────────────────────────────────

  static Future<bool> deleteNotification(int notificationId) async {
    final headers = await _authHeaders();
    for (final base in _urls) {
      try {
        final res = await http
            .delete(Uri.parse('$base/notifications/$notificationId'),
                headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          return _isSuccess(data);
        }
      } catch (_) {
        continue;
      }
    }
    return false; // silent fail — non-critical
  }

  // ── Streams (polling) ─────────────────────────────────────────────────────

  /// Polls every 15 seconds (reduced from 5s to lower server load).
  static Stream<List<Map<String, dynamic>>> streamUserNotifications(int userId) async* {
    try {
      yield await getUserNotifications(userId);
    } catch (_) {
      yield [];
    }
    await for (final _ in Stream.periodic(const Duration(seconds: 15))) {
      try {
        yield await getUserNotifications(userId);
      } catch (_) {
        yield [];
      }
    }
  }

  /// Polls every 30 seconds — badge only, no full reload needed.
  static Stream<int> streamUnreadCount(int userId) async* {
    try {
      yield await getUnreadNotificationsCount(userId);
    } catch (_) {
      yield 0;
    }
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      try {
        yield await getUnreadNotificationsCount(userId);
      } catch (_) {
        yield 0;
      }
    }
  }
}
