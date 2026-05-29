import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // Notification channels
  static const String _appointmentReminderChannel = 'appointment_reminders';
  static const String _generalNotificationChannel = 'general_notifications';
  
  // Notification stream controllers
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  final StreamController<NotificationResponse> _notificationStreamController = StreamController<NotificationResponse>.broadcast();
  
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;
  Stream<NotificationResponse> get notificationStream => _notificationStreamController.stream;

  /// Initialize the notification service
  Future<bool> initialize() async {
    try {
      // Initialize timezone data
      tz_data.initializeTimeZones();
      String currentTimeZone = 'UTC';
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        currentTimeZone = timezoneInfo.toString();
      } catch (e) {
        debugPrint('⚠️ Could not get local timezone, using UTC: $e');
      }
      // Handle timezone properly
      try {
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
      } catch (e) {
        // Fallback to UTC if timezone not found
        tz.setLocalLocation(tz.getLocation('UTC'));
        debugPrint('⚠️ Timezone not found, using UTC: $e');
      }
      
      // Request notification permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();
      
      // Create notification channels
      await _createNotificationChannels();
      
      debugPrint('✅ Enhanced notification service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // iOS permissions
      if (Platform.isIOS) {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: true,
          provisional: false,
          sound: true,
        );
        
        debugPrint('🔔 iOS notification permissions: ${settings.authorizationStatus}');
      }
      
      // Android permissions are handled at runtime
      if (Platform.isAndroid) {
        // Check if we can show notifications
        final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final areNotificationsEnabled = await androidPlugin.areNotificationsEnabled();
          debugPrint('🔔 Android notifications enabled: $areNotificationsEnabled');
        }
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Initialize Firebase messaging
  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      debugPrint('🔔 FCM Token: $token');
      
      // Save token to backend
      if (token != null) {
        await _saveFcmTokenToBackend(token);
      }
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        debugPrint('🔄 FCM Token refreshed: $token');
        _saveFcmTokenToBackend(token);
      });
      
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Listen for background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Check for initial message (app opened from notification)
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
      
    } catch (e) {
      debugPrint('❌ Error initializing Firebase messaging: $e');
    }
  }

  /// Create notification channels
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      // Appointment reminders channel
      const AndroidNotificationChannel appointmentChannel = AndroidNotificationChannel(
        _appointmentReminderChannel,
        'Appointment Reminders',
        description: 'Notifications for upcoming appointments and reminders',
        importance: Importance.high,
        enableLights: true,
        ledColor: Colors.blue,
        enableVibration: true,
      );
      
      // General notifications channel
      const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
        _generalNotificationChannel,
        'General Notifications',
        description: 'General app notifications and updates',
        importance: Importance.defaultImportance,
        enableLights: true,
        ledColor: Colors.green,
        enableVibration: true,
      );
      
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(appointmentChannel);
      
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(generalChannel);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 Received foreground message: ${message.messageId}');
    
    // Show local notification for foreground messages
    _showLocalNotification(message);
    
    // Add to stream for UI updates
    _messageStreamController.add(message);
  }

  /// Handle message opened app
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 Message opened app: ${message.messageId}');
    
    // Add to stream for UI updates
    _messageStreamController.add(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _appointmentReminderChannel,
        'Appointment Reminders',
        channelDescription: 'Notifications for upcoming appointments and reminders',
        importance: Importance.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        color: Colors.blue,
        enableLights: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      );
      
      final DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );
      
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title ?? 'HealthTrack',
        message.notification?.body ?? 'You have a new notification',
        platformChannelSpecifics,
        payload: message.data.toString(),
      );
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');
    _notificationStreamController.add(response);
  }

  /// Save FCM token to backend
  Future<void> _saveFcmTokenToBackend(String token) async {
    try {
      // This would be implemented to save the token to your backend
      // You'll need to integrate this with your existing auth service
      debugPrint('💾 Saving FCM token to backend: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Schedule local notification for testing
  Future<void> scheduleTestNotification() async {
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'Test Reminder',
        'This is a test appointment reminder notification',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _appointmentReminderChannel,
            'Appointment Reminders',
            channelDescription: 'Notifications for upcoming appointments and reminders',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('✅ Test notification scheduled');
    } catch (e) {
      debugPrint('❌ Error scheduling test notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('🗑️ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// Check notification permissions
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      } else if (Platform.isIOS) {
        final settings = await _firebaseMessaging.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
               settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _messageStreamController.close();
    _notificationStreamController.close();
  }
}
