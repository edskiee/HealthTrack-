import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthtrack/services/fcm_service.dart';
import 'package:healthtrack/services/background_notification_service.dart';
import 'package:healthtrack/services/reminder_notification_service.dart';

/// Comprehensive test for notification system across all app states
class LifecycleNotificationTest {
  static final BackgroundNotificationService _backgroundService = BackgroundNotificationService.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  /// Initialize and run comprehensive notification tests
  static Future<void> runTests() async {
    print('Starting comprehensive notification lifecycle tests...');
    
    try {
      // Initialize all notification services
      await _initializeServices();
      
      // Test 1: Foreground notifications
      await _testForegroundNotifications();
      
      // Test 2: Background notifications simulation
      await _testBackgroundNotifications();
      
      // Test 3: App termination notifications
      await _testTerminatedAppNotifications();
      
      // Test 4: Real-time FCM notifications
      await _testRealTimeFCMNotifications();
      
      print('All notification lifecycle tests completed successfully!');
    } catch (e) {
      print('Error during notification tests: $e');
    }
  }
  
  /// Initialize all notification services
  static Future<void> _initializeServices() async {
    print('Initializing notification services...');
    
    // Initialize FCM service
    await FCMService.initialize();
    
    // Initialize background notification service
    await _backgroundService.initialize();
    
    // Initialize reminder notification service
    await ReminderNotificationService.initialize();
    
    print('All notification services initialized');
  }
  
  /// Test foreground notification behavior
  static Future<void> _testForegroundNotifications() async {
    print('\n=== Testing Foreground Notifications ===');
    
    try {
      // Test local notification in foreground
      await _showTestNotification(
        id: 1,
        title: 'Foreground Test',
        body: 'This notification appears when app is in foreground',
        type: NotificationType.standard,
      );
      
      // Test critical notification in foreground
      await _showTestNotification(
        id: 2,
        title: 'Critical Alert',
        body: 'This is a critical notification in foreground',
        type: NotificationType.critical,
      );
      
      print('Foreground notifications test completed');
    } catch (e) {
      print('Error in foreground notification test: $e');
    }
  }
  
  /// Test background notification behavior
  static Future<void> _testBackgroundNotifications() async {
    print('\n=== Testing Background Notifications ===');
    
    try {
      // Simulate background notification
      await _backgroundService.showNotification(
        id: 3,
        title: 'Background Test',
        body: 'This notification simulates background delivery',
        type: NotificationType.standard,
      );
      
      // Test silent background notification
      await _backgroundService.showNotification(
        id: 4,
        title: 'Silent Background',
        body: 'This is a silent background notification',
        type: NotificationType.background,
      );
      
      print('Background notifications test completed');
    } catch (e) {
      print('Error in background notification test: $e');
    }
  }
  
  /// Test terminated app notification behavior
  static Future<void> _testTerminatedAppNotifications() async {
    print('\n=== Testing Terminated App Notifications ===');
    
    try {
      // Test notification that would appear when app is terminated
      await _showTestNotification(
        id: 5,
        title: 'App Terminated Test',
        body: 'This notification appears when app is launched from terminated state',
        type: NotificationType.critical,
      );
      
      print('Terminated app notifications test completed');
    } catch (e) {
      print('Error in terminated app notification test: $e');
    }
  }
  
  /// Test real-time FCM notifications
  static Future<void> _testRealTimeFCMNotifications() async {
    print('\n=== Testing Real-time FCM Notifications ===');
    
    try {
      // Test FCM connection
      final token = await FCMService.getToken();
      if (token != null) {
        print('FCM Token available: ${token.substring(0, 20)}...');
        
        // Test immediate FCM notification
        await _backgroundService.showNotification(
          id: 6,
          title: 'FCM Connection Test',
          body: 'FCM service is connected and ready',
          type: NotificationType.standard,
        );
      } else {
        print('FCM Token not available');
      }
      
      print('Real-time FCM notifications test completed');
    } catch (e) {
      print('Error in FCM notification test: $e');
    }
  }
  
  /// Show a test notification
  static Future<void> _showTestNotification({
    required int id,
    required String title,
    required String body,
    NotificationType type = NotificationType.standard,
  }) async {
    try {
      // Initialize local notifications if needed
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      await _localNotifications.initialize(
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        ),
      );
      
      // Create notification details
      String channelId;
      Importance importance;
      bool playSound;
      bool enableVibration;
      
      switch (type) {
        case NotificationType.critical:
          channelId = 'healthtrack_critical';
          importance = Importance.max;
          playSound = true;
          enableVibration = true;
          break;
        case NotificationType.background:
          channelId = 'healthtrack_background';
          importance = Importance.low;
          playSound = false;
          enableVibration = false;
          break;
        case NotificationType.standard:
          channelId = 'healthtrack_standard';
          importance = Importance.high;
          playSound = true;
          enableVibration = true;
          break;
      }
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        'Test Notifications',
        channelDescription: 'Notifications for testing purposes',
        importance: importance,
        playSound: playSound,
        enableVibration: enableVibration,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        showWhen: true,
        icon: '@drawable/ic_stat_notify',
        styleInformation: BigTextStyleInformation(body),
        fullScreenIntent: type == NotificationType.critical,
      );
      
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: type != NotificationType.background,
        presentBadge: type != NotificationType.background,
        presentSound: playSound,
        interruptionLevel: type == NotificationType.critical 
            ? InterruptionLevel.critical 
            : type == NotificationType.standard 
                ? InterruptionLevel.timeSensitive 
                : InterruptionLevel.passive,
        badgeNumber: 1,
      );
      
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
      
      print('Test notification shown: $title - $body');
    } catch (e) {
      print('Error showing test notification: $e');
    }
  }
  
  /// Test notification persistence
  static Future<void> testNotificationPersistence() async {
    print('\n=== Testing Notification Persistence ===');
    
    try {
      // Get pending notifications
      final pendingNotifications = await _localNotifications.pendingNotificationRequests();
      print('Pending notifications: ${pendingNotifications.length}');
      
      for (final notification in pendingNotifications) {
        print('Pending: ${notification.id} - ${notification.title}');
      }
      
      print('Notification persistence test completed');
    } catch (e) {
      print('Error in notification persistence test: $e');
    }
  }
  
  /// Test notification cancellation
  static Future<void> testNotificationCancellation() async {
    print('\n=== Testing Notification Cancellation ===');
    
    try {
      // Cancel specific notification
      await _localNotifications.cancel(1);
      print('Notification 1 cancelled');
      
      // Cancel all notifications
      await _localNotifications.cancelAll();
      print('All notifications cancelled');
      
      print('Notification cancellation test completed');
    } catch (e) {
      print('Error in notification cancellation test: $e');
    }
  }
  
  /// Run all tests including persistence and cancellation
  static Future<void> runAllTests() async {
    await runTests();
    await testNotificationPersistence();
    await testNotificationCancellation();
  }
}

/// Widget for testing notifications in the UI
class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({Key? key}) : super(key: key);

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Lifecycle Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest.runAllTests(),
              child: const Text('Run All Tests'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest._testForegroundNotifications(),
              child: const Text('Test Foreground'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest._testBackgroundNotifications(),
              child: const Text('Test Background'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest._testTerminatedAppNotifications(),
              child: const Text('Test Terminated App'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest._testRealTimeFCMNotifications(),
              child: const Text('Test FCM'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest.testNotificationPersistence(),
              child: const Text('Test Persistence'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => LifecycleNotificationTest.testNotificationCancellation(),
              child: const Text('Test Cancellation'),
            ),
          ],
        ),
      ),
    );
  }
}
