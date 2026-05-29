import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthtrack/services/fcm_service.dart';
import 'package:healthtrack/services/user_session.dart';

/// Background notification service for reliable notification handling across all app states
class BackgroundNotificationService {
  static BackgroundNotificationService? _instance;
  static BackgroundNotificationService get instance => _instance ??= BackgroundNotificationService._();
  
  BackgroundNotificationService._();
  
  FlutterLocalNotificationsPlugin? _localNotificationsPlugin;
  Timer? _backgroundCheckTimer;
  bool _isInitialized = false;
  
  /// Initialize the background notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing Background Notification Service...');
      
      // Initialize local notifications
      _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings with background support
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );
      
      // Initialize the plugin
      await _localNotificationsPlugin?.initialize(
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Create notification channels for Android
      await _createNotificationChannels();
      
      // Start background monitoring
      _startBackgroundMonitoring();
      
      _isInitialized = true;
      print('Background Notification Service initialized successfully');
    } catch (e) {
      print('Error initializing Background Notification Service: $e');
    }
  }
  
  /// Create notification channels for different notification types
  Future<void> _createNotificationChannels() async {
    // High priority channel for critical notifications
    await _localNotificationsPlugin?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'healthtrack_critical',
        'Critical Notifications',
        description: 'Critical alerts and reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
      ),
    );
    
    // Standard channel for regular notifications
    await _localNotificationsPlugin?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'healthtrack_standard',
        'Standard Notifications',
        description: 'Regular app notifications',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );
    
    // Background channel for silent notifications
    await _localNotificationsPlugin?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        'healthtrack_background',
        'Background Notifications',
        description: 'Background processing notifications',
        importance: Importance.low,
        enableVibration: false,
        playSound: false,
        showBadge: false,
      ),
    );
  }
  
  /// Start background monitoring for notifications
  void _startBackgroundMonitoring() {
    // Check for pending notifications every 30 seconds
    _backgroundCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkPendingNotifications();
    });
    
    print('Background monitoring started (30-second intervals)');
  }
  
  /// Check for pending notifications and display them
  Future<void> _checkPendingNotifications() async {
    try {
      if (!UserSession.instance.isLoggedIn) return;
      
      // This would typically check a local database or cache for pending notifications
      // For now, we'll ensure the FCM service is still connected
      await _ensureFCMConnection();
      
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }
  
  /// Ensure FCM connection is maintained
  Future<void> _ensureFCMConnection() async {
    try {
      // Get current FCM token to verify connection
      final token = await FCMService.getToken();
      if (token != null) {
        print('FCM connection verified in background');
      } else {
        print('FCM token null, attempting reconnection...');
        await FCMService.initialize();
      }
    } catch (e) {
      print('Error ensuring FCM connection: $e');
    }
  }
  
  /// Show a notification with enhanced background support
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.standard,
  }) async {
    try {
      if (_localNotificationsPlugin == null) return;
      
      String channelId;
      Importance importance;
      bool playSound;
      bool enableVibration;
      
      // Configure notification based on type
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
      
      // Android notification details
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelTitle(type),
        channelDescription: _getChannelDescription(type),
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
        category: _getNotificationCategory(type),
      );
      
      // iOS notification details
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
        threadIdentifier: 'healthtrack_notifications',
      );
      
      // Show notification
      await _localNotificationsPlugin?.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
      
      print('Background notification shown: $title - $body');
    } catch (e) {
      print('Error showing background notification: $e');
    }
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Background notification tapped: ${response.payload}');
    // Handle navigation or action based on payload
    _handleNotificationAction(response.payload);
  }
  
  /// Handle notification action based on payload
  void _handleNotificationAction(String? payload) {
    if (payload == null) return;
    
    try {
      // Parse payload and take appropriate action
      // This would typically navigate to specific screens
      print('Handling notification action for payload: $payload');
    } catch (e) {
      print('Error handling notification action: $e');
    }
  }
  
  /// Get channel title based on notification type
  String _getChannelTitle(NotificationType type) {
    switch (type) {
      case NotificationType.critical:
        return 'Critical Notifications';
      case NotificationType.background:
        return 'Background Notifications';
      case NotificationType.standard:
        return 'Standard Notifications';
    }
  }
  
  /// Get channel description based on notification type
  String _getChannelDescription(NotificationType type) {
    switch (type) {
      case NotificationType.critical:
        return 'Critical alerts and reminders that require immediate attention';
      case NotificationType.background:
        return 'Silent background processing notifications';
      case NotificationType.standard:
        return 'Regular app notifications and updates';
    }
  }
  
  /// Get notification category based on type
  AndroidNotificationCategory _getNotificationCategory(NotificationType type) {
    switch (type) {
      case NotificationType.critical:
        return AndroidNotificationCategory.alarm;
      case NotificationType.background:
        return AndroidNotificationCategory.system;
      case NotificationType.standard:
        return AndroidNotificationCategory.recommendation;
    }
  }
  
  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotificationsPlugin?.cancel(id);
      print('Notification cancelled: $id');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotificationsPlugin?.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }
  
  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _localNotificationsPlugin?.pendingNotificationRequests() ?? [];
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }
  
  /// Dispose the service
  void dispose() {
    _backgroundCheckTimer?.cancel();
    _backgroundCheckTimer = null;
    _isInitialized = false;
    print('Background Notification Service disposed');
  }
}

/// Notification types for different priority levels
enum NotificationType {
  critical,
  standard,
  background,
}
