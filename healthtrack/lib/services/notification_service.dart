import 'dart:convert';
import 'dart:async';
import 'api_service.dart'; // Import the new API service

class NotificationService {
  static final ApiService _apiService = ApiService.instance;

  // Initialize the service
  static Future<void> initialize() async {
    await _apiService.initialize();
  }

  // Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(int userId) async {
    try {
      final response = await _apiService.get('/notifications/user/$userId');

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
      // Enhanced error handling
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception(
          'Unable to connect to the server. Please check your network connection '
          'and ensure the backend server is running.'
        );
      } else if (e.toString().contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection and try again.'
        );
      } else {
        throw Exception("Failed to fetch user notifications: $e");
      }
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadNotificationsCount(int userId) async {
    try {
      final response = await _apiService.get('/notifications/user/$userId/unread-count');

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
      // Enhanced error handling
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception(
          'Unable to connect to server. Please check your network connection '
          'and ensure backend server is running.'
        );
      } else if (e.toString().contains('timeout')) {
        throw Exception(
          'Request timed out. Please check your internet connection and try again.'
        );
      } else {
        throw Exception("Failed to fetch unread notifications count: $e");
      }
    }
  }

  // Mark notification as read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await _apiService.put('/notifications/$notificationId/read');

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
      // Enhanced error handling for non-critical operations
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('timeout')) {
        print('⚠️ Network error marking notification as read: $e');
        return false; // Silent fail for non-critical operations
      } else {
        print('❌ Error marking notification as read: $e');
        return false;
      }
    }
  }

  // Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead(int userId) async {
    try {
      final response = await _apiService.put('/notifications/user/$userId/mark-all-read');

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
      // Enhanced error handling for non-critical operations
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('timeout')) {
        print('⚠️ Network error marking all notifications as read: $e');
        return false; // Silent fail for non-critical operations
      } else {
        print('❌ Error marking all notifications as read: $e');
        return false;
      }
    }
  }

  // Delete notification
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await _apiService.delete('/notifications/$notificationId');

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
      // Enhanced error handling for non-critical operations
      if (e.toString().contains('Connection refused') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('timeout')) {
        print('⚠️ Network error deleting notification: $e');
        return false; // Silent fail for non-critical operations
      } else {
        print('❌ Error deleting notification: $e');
        return false;
      }
    }
  }

  // Stream notifications (for real-time updates)
  static Stream<List<Map<String, dynamic>>> streamUserNotifications(int userId) async* {
    // Emit initial data
    try {
      final notifications = await getUserNotifications(userId);
      yield notifications;
    } catch (e) {
      print('Error fetching initial notifications: $e');
      yield [];
    }
    
    // Set up periodic updates with more frequent checks
    await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
      try {
        final notifications = await getUserNotifications(userId);
        yield notifications;
      } catch (e) {
        print('Error streaming notifications: $e');
        yield [];
      }
    }
  }

  // Stream unread count (for real-time badge updates)
  static Stream<int> streamUnreadCount(int userId) async* {
    // Emit initial count
    try {
      final count = await getUnreadNotificationsCount(userId);
      yield count;
    } catch (e) {
      print('Error fetching initial unread count: $e');
      yield 0;
    }
    
    // Set up periodic updates with more frequent checks
    await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
      try {
        final count = await getUnreadNotificationsCount(userId);
        yield count;
      } catch (e) {
        print('Error streaming unread count: $e');
        yield 0;
      }
    }
  }
}