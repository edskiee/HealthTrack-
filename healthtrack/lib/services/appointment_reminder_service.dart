import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'user_session.dart';
import 'user_session_storage.dart';
import 'api_config.dart';
import '../utils/time_utils.dart';

class AppointmentReminderService {
  static final AppointmentReminderService _instance = AppointmentReminderService._internal();
  factory AppointmentReminderService() => _instance;
  AppointmentReminderService._internal();

  /// Check for upcoming appointments on app launch
  Future<Map<String, dynamic>> checkUpcomingAppointments() async {
    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        return {
          'success': false,
          'message': 'User not logged in',
          'hasUpcoming': false
        };
      }

      final token = await UserSessionStorage.getToken();

      Object? lastException;
      for (final url in ApiConfig.fallbackBaseUrls) {
        try {
          final response = await http.get(
            Uri.parse('$url/appointment-reminders/user/${userSession.userId}/check-upcoming'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            return data;
          }
        } catch (e) {
          lastException = e;
          continue;
        }
      }

      return {
        'success': false,
        'message': 'Failed to check upcoming appointments: ${lastException?.toString()}',
        'hasUpcoming': false
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking upcoming appointments: $e');
      }
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'hasUpcoming': false
      };
    }
  }

  /// Get upcoming reminders for the user
  Future<List<Map<String, dynamic>>> getUpcomingReminders() async {
    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        return [];
      }

      final token = await UserSessionStorage.getToken();

      for (final url in ApiConfig.fallbackBaseUrls) {
        try {
          final response = await http.get(
            Uri.parse('$url/appointment-reminders/user/${userSession.userId}/upcoming'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true && data['data'] != null) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          }
        } catch (e) {
          continue;
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting upcoming reminders: $e');
      }
      return [];
    }
  }

  /// Initialize notification checking on app launch
  Future<void> initializeNotificationCheck() async {
    try {
      if (kDebugMode) {
        print('🔔 Initializing appointment reminder notification check...');
      }

      final result = await checkUpcomingAppointments();
      
      if (result['success'] == true && result['hasUpcoming'] == true) {
        if (kDebugMode) {
          print('📅 Found upcoming appointments, showing notifications');
        }

        // Show notification for each upcoming appointment
        final appointments = result['appointments'] as List<dynamic>? ?? [];
        for (final appointment in appointments) {
          await _showUpcomingAppointmentNotification(appointment);
        }
      } else {
        if (kDebugMode) {
          print('📅 No upcoming appointments found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing notification check: $e');
      }
    }
  }

  /// Show notification for upcoming appointment
  Future<void> _showUpcomingAppointmentNotification(Map<String, dynamic> appointment) async {
    try {
      final appointmentDate = appointment['appointment_date'] as String? ?? '';
      final appointmentTime = appointment['appointment_time'] as String? ?? '';
      final appointmentType = appointment['appointment_type'] as String? ?? 'Appointment';
      final doctorName = appointment['doctor_name'] as String? ?? '';
      
      final formattedSchedule = TimeUtils.formatAppointmentUtcDateTime(
        appointmentDate,
        appointmentTime,
        pattern: 'MMMM dd, yyyy hh:mm a',
      );

      String message = 'You have an upcoming $appointmentType on $formattedSchedule.';
      if (doctorName.isNotEmpty) {
        message += ' Doctor: $doctorName.';
      }
      
      // Show in-app notification (you can integrate with your notification system)
      await _showInAppNotification('Upcoming Appointment', message);
      
      if (kDebugMode) {
        print('🔔 Showed upcoming appointment notification: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing upcoming appointment notification: $e');
      }
    }
  }

  /// Show in-app notification via system local notification
  Future<void> _showInAppNotification(String title, String message) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();

      const androidDetails = AndroidNotificationDetails(
        'healthtrack_channel',
        'HealthTrack Notifications',
        channelDescription: 'General HealthTrack notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await plugin.show(
        DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
        title,
        message,
        details,
        payload: json.encode({'type': 'appointment_reminder', 'title': title, 'body': message}),
      );

      if (kDebugMode) {
        print('🔔 In-App Notification shown: $title - $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing in-app notification: $e');
      }
    }
  }

  /// Schedule periodic reminder checks (optional)
  Future<void> schedulePeriodicChecks() async {
    // This would typically be done using a background job scheduler
    // For now, this is a placeholder for future implementation
    if (kDebugMode) {
      print('⏰ Periodic reminder checks would be scheduled here');
    }
  }

  /// Handle received FCM notification for appointment reminders
  Future<void> handleAppointmentReminderNotification(Map<String, dynamic> notificationData) async {
    try {
      final notificationType = notificationData['notificationType'] as String? ?? '';
      
      if (notificationType == 'appointment_reminder') {
        final title = notificationData['title'] as String? ?? 'Appointment Reminder';
        final message = notificationData['body'] as String? ?? 'You have an upcoming appointment.';
        
        await _showInAppNotification(title, message);
        
        if (kDebugMode) {
          print('🔔 Handled appointment reminder notification: $title - $message');
        }
      } else if (notificationType == 'upcoming_appointment_check') {
        final title = notificationData['title'] as String? ?? 'Upcoming Appointment';
        final message = notificationData['body'] as String? ?? 'You have upcoming appointments.';
        
        await _showInAppNotification(title, message);
        
        if (kDebugMode) {
          print('🔔 Handled upcoming appointment check notification: $title - $message');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling appointment reminder notification: $e');
      }
    }
  }

  /// Cancel reminders for a specific appointment (if needed)
  Future<bool> cancelAppointmentReminders(int appointmentId) async {
    try {
      // This would typically call an API endpoint to cancel reminders
      // For now, this is a placeholder
      if (kDebugMode) {
        print('🗑️ Cancelled reminders for appointment $appointmentId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error cancelling appointment reminders: $e');
      }
      return false;
    }
  }

  /// Update reminder preferences (if needed)
  Future<bool> updateReminderPreferences(Map<String, dynamic> preferences) async {
    try {
      // This would typically call an API endpoint to update user preferences
      // For now, this is a placeholder
      if (kDebugMode) {
        print('⚙️ Updated reminder preferences: $preferences');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating reminder preferences: $e');
      }
      return false;
    }
  }
}
