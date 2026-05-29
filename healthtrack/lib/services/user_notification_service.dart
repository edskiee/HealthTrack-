import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart'; // Import the new API config

class UserNotificationService {
  // 🎯 USE CONSISTENT URL CONFIGURATION:
  static String get baseUrl {
    return ApiConfig.baseUrl;
  }

  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/appointments/notifications/$userId"),
        headers: _headers,
      );

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
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch notifications');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch notifications");
      }
    } catch (e) {
      throw Exception("Failed to fetch user notifications: $e");
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadNotificationsCount(int userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/appointments/notifications/$userId/unread-count"),
        headers: _headers,
      );

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
          return data['count'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch unread count');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch unread count");
      }
    } catch (e) {
      throw Exception("Failed to fetch unread notifications count: $e");
    }
  }

  // Mark notification as read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/appointments/notifications/$notificationId/read"),
        headers: _headers,
      );

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
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to mark as read");
      }
    } catch (e) {
      throw Exception("Failed to mark notification as read: $e");
    }
  }

  // Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead(int userId) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/appointments/notifications/user/$userId/mark-all-read"),
        headers: _headers,
      );

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
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to mark all as read");
      }
    } catch (e) {
      throw Exception("Failed to mark all notifications as read: $e");
    }
  }

  // Delete notification
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/api/appointments/notifications/$notificationId"),
        headers: _headers,
      );

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
        return isSuccess;
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to delete notification");
      }
    } catch (e) {
      throw Exception("Failed to delete notification: $e");
    }
  }

  // Get appointment status history
  static Future<List<Map<String, dynamic>>> getAppointmentStatusHistory(int userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/appointments/user/$userId/status-history"),
        headers: _headers,
      );

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
          return List<Map<String, dynamic>>.from(data['data'] ?? []);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch status history');
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Failed to fetch status history");
      }
    } catch (e) {
      throw Exception("Failed to fetch appointment status history: $e");
    }
  }

  // Stream notifications (for real-time updates)
  static Stream<List<Map<String, dynamic>>> streamUserNotifications(int userId) async* {
    while (true) {
      try {
        final notifications = await getUserNotifications(userId);
        yield notifications;
      } catch (e) {
        print('Error streaming notifications: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  // Stream unread count (for real-time badge updates)
  static Stream<int> streamUnreadCount(int userId) {
    // Create a controller that will emit unread counts
    final controller = StreamController<int>();
    
    // Add the initial count
    getUnreadNotificationsCount(userId).then(
      (count) => controller.add(count),
      onError: (e) => controller.add(0)
    );
    
    // Set up periodic updates
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (controller.isClosed) return;
      getUnreadNotificationsCount(userId).then(
        (count) => controller.add(count),
        onError: (e) => controller.add(0)
      );
    });
    
    // Return the stream with cleanup
    return controller.stream.asBroadcastStream().map((count) {
      return count;
    });
  }
}