import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthtrack/services/api_config.dart';
import 'package:healthtrack/services/user_session.dart';
import 'package:healthtrack/services/websocket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:healthtrack/utils/time_utils.dart';
import 'dart:convert';
import 'dart:math';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Background message received: ${message.messageId}');
  await FCMService.handleBackgroundMessage(message);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  print('🔔 Notification tapped in background: ${response.payload}');
}

class FCMService {
  static FirebaseMessaging? _messaging;
  static FlutterLocalNotificationsPlugin? _localNotificationsPlugin;
  static StreamController<String>? _tokenController;
  static StreamController<Map<String, dynamic>>? _tapController;
  static bool _initialized = false;
  static int _tokenSaveAttempts = 0;
  static const int MAX_TOKEN_SAVE_ATTEMPTS = 3;

  // Initialize FCM service
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('🚀 Starting FCM Service initialization...');
      
      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;
      
      // Request permission for notifications (iOS and Android 13+)
      final NotificationSettings settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true, // For iOS - allows notifications to be delivered silently first
        carPlay: false,
        criticalAlert: true, // Enable critical alerts for urgent notifications
        announcement: true, // Enable announcements for accessibility
      ) ?? NotificationSettings(
        authorizationStatus: AuthorizationStatus.notDetermined,
        alert: AppleNotificationSetting.notSupported,
        badge: AppleNotificationSetting.notSupported,
        sound: AppleNotificationSetting.notSupported,
        carPlay: AppleNotificationSetting.notSupported,
        criticalAlert: AppleNotificationSetting.notSupported,
        announcement: AppleNotificationSetting.notSupported,
        notificationCenter: AppleNotificationSetting.notSupported,
        lockScreen: AppleNotificationSetting.notSupported,
        showPreviews: AppleShowPreviewSetting.notSupported,
        timeSensitive: AppleNotificationSetting.notSupported,
        providesAppNotificationSettings: AppleNotificationSetting.notSupported,
      );
      
      print('🔔 Notification permission status: ${settings.authorizationStatus}');
      
      // Initialize local notifications with proper configuration for all platforms
      await _initializeLocalNotifications();
      
      // Create notification channel for Android
      await _createNotificationChannel();
      
      // Get the FCM token with enhanced retry logic
      await _retrieveAndSaveToken();
      
      // Set up token refresh listener with enhanced error handling
      _messaging?.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...'); // Log only part of token for security
        if (_isValidFcmToken(newToken)) {
          _saveTokenToServer(newToken);
        } else {
          print('⚠️ Invalid FCM token received on refresh, skipping save to server');
        }
      }).onError((err) {
        print('❌ Error listening to token refresh: $err');
        // Attempt to recover by getting a new token
        _retrieveAndSaveToken();
      });

      // Background handler is registered once in main.mobile.dart (top-level, before runApp).
      // Do not register FirebaseMessaging.onBackgroundMessage here — duplicate registration breaks Flutter/FCM.

      // Handle foreground messages with enhanced logging
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // DEBUG
        print('// DEBUG FCM foreground onMessage messageId=${message.messageId} data=${message.data}');
        print('📬 Foreground message received: ${message.messageId}');
        print('📬 Message data: ${message.data}');
        if (message.notification != null) {
          print('📬 Message notification: ${message.notification?.title} - ${message.notification?.body}');
        }
        _handleMessageWithLogging(message);
      });
      
      // Handle message opened from terminated state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📬 Message opened from terminated state: ${message.messageId}');
        _handleMessageWithLogging(message);
        _emitTapEvent(message.data);
      });
      
      // Handle initial message when app is launched from terminated state
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('📬 Initial message when app launched: ${initialMessage.messageId}');
        _handleMessageWithLogging(initialMessage);
        _emitTapEvent(initialMessage.data);
      }
      
      _initialized = true;
      print('🟢 FCM Service initialized successfully');
      
      // Schedule periodic token refresh check
      _scheduleTokenRefreshCheck();
    } catch (e) {
      print('❌ Error initializing FCM Service: $e');
      // Retry initialization after delay
      Future.delayed(Duration(seconds: 30), () => initialize());
    }
  }
  
  // Enhanced token retrieval and saving with retry mechanism
  static Future<void> _retrieveAndSaveToken() async {
    try {
      print('🔄 Starting FCM token retrieval...');
      
      // Get the FCM token with enhanced retry mechanism
      String? token;
      int attempts = 0;
      const maxAttempts = 5; // Increased attempts
      
      while (token == null && attempts < maxAttempts) {
        attempts++;
        print('🔄 Attempt $attempts/$maxAttempts to retrieve FCM token...');
        
        try {
          token = await _messaging?.getToken();
          
          if (token != null) {
            print('🔍 Raw token retrieved (length: ${token.length})');
          } else {
            print('⚠️ FCM token retrieval returned null');
          }
        } catch (e) {
          print('❌ Error during token retrieval attempt $attempts: $e');
        }
        
        if (token == null) {
          final delay = Duration(seconds: 2 * attempts); // Exponential backoff
          print('⏳ Waiting ${delay.inSeconds} seconds before retry...');
          await Future.delayed(delay);
        }
      }
      
      if (token != null && _isValidFcmToken(token)) {
        print('✅ FCM Token retrieved successfully: ${token.substring(0, 20)}... (length: ${token.length})');
        // Reset save attempts counter for new token
        _tokenSaveAttempts = 0;
        // Save token to server if user is logged in
        await _saveTokenToServer(token);
      } else {
        print('⚠️ No valid FCM token retrieved from Firebase Messaging after $maxAttempts attempts');
        if (token != null) {
          print('🔍 Token validation failed. Token length: ${token.length}');
        }
        // Schedule another attempt with longer delay
        Future.delayed(Duration(minutes: 1), _retrieveAndSaveToken);
      }
    } catch (e) {
      print('❌ Error retrieving FCM token: $e');
      // Schedule another attempt with longer delay
      Future.delayed(Duration(minutes: 1), _retrieveAndSaveToken);
    }
  }
  
  // Background message handler - Top-level function required by Firebase
  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('Background message received: ${message.messageId}');
    print('Background message data: ${message.data}');
    
    // Initialize Firebase if needed
    try {
      await Firebase.initializeApp();
      print('Firebase initialized in background handler');
    } catch (e) {
      print('Firebase already initialized in background: $e');
    }
    
    // Initialize local notifications for background
    await _initializeLocalNotifications();
    
    // Avoid duplicate banners:
    // - If the FCM payload includes `notification`, Android/iOS will usually display it automatically
    //   while the app is background/terminated.
    // - Only show a local notification ourselves for data-only messages.
    if (message.notification == null) {
      await _showLocalNotification(message);
    } else {
      print('ℹ️ Skipping local notification in background handler (OS will display notification payload).');
    }
    
    // Handle additional processing
    _handleMessageWithLogging(message);
  }
  
  // Handle incoming messages with enhanced support for both notification and data payloads
  static void _handleMessage(RemoteMessage message) {
    print('📬 Message data: ${message.data}');
    if (message.notification != null) {
      print('📬 Message notification: ${message.notification?.title}');
    }
    
    // Only show a local notification ourselves for data-only messages.
    // When a notification payload is present and the app is in foreground,
    // the overlay_support banner in the tab already displays it — showing
    // a system banner on top would create duplicates.
    if (message.notification == null) {
      _showLocalNotification(message);
    }
  }
  
  // Enhanced message handler with better error handling and logging
  static void _handleMessageWithLogging(RemoteMessage message) {
    try {
      print('📬 Handling message: ${message.messageId}');
      print('📬 Message type: ${message.messageType}');
      print('📬 Message sender ID: ${message.senderId}');
      print('📬 Message category: ${message.category}');
      print('📬 Message collapse key: ${message.collapseKey}');
      
      _handleMessage(message);
    } catch (e) {
      print('❌ Error handling message: $e');
      // Still try to show notification even if there's an error
      _showLocalNotification(message);
    }
  }
  
  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    try {
      _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings with enhanced configuration
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        // Enable notification presentation in foreground for iOS
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );
      
      // Linux initialization settings
      final LinuxInitializationSettings initializationSettingsLinux =
          LinuxInitializationSettings(defaultActionName: 'Open notification');
      
      // All platforms initialization settings
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
        linux: initializationSettingsLinux,
      );
      
      // Initialize the plugin with enhanced callback handling
      await _localNotificationsPlugin?.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('🔔 Notification tapped: ${response.payload}');
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              _emitTapEvent(data);
            } catch (_) {}
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      print('🟢 Local notifications initialized');
    } catch (e) {
      print('❌ Error initializing local notifications: $e');
    }
  }
  
  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _localNotificationsPlugin?.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            'healthtrack_fcm_channel',
            'HealthTrack Notifications',
            description: 'HealthTrack app notifications',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            showBadge: true,
            // Enable showing notifications in all app states
            enableLights: true,
          ),
        );
        print('🔵 Created Android notification channel');
      }
    } catch (e) {
      print('❌ Error creating notification channel: $e');
    }
  }
  
  // Show local notification with enhanced configuration for system banners
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      if (_localNotificationsPlugin == null) return;
      
      // Extract notification details from both notification and data payloads
      final String title = message.notification?.title ?? 
                          message.data['title'] ?? 
                          message.data['notification']?['title'] ??
                          'HealthTrack Notification';
      String body = message.notification?.body ?? 
                         message.data['body'] ?? 
                         message.data['message'] ?? 
                         message.data['notification']?['body'] ??
                         'You have a new notification';
      body = _resolveAppointmentNotificationBody(message.data, body);
      final int notificationId = ((message.messageId?.hashCode ?? 
                               message.data['notificationId']?.hashCode ?? 
                               DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF);
      
      // Android notification details with enhanced configuration for system banners
      final AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'healthtrack_fcm_channel', 
        'HealthTrack Notifications',
        channelDescription: 'HealthTrack app notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        showProgress: false,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        // Enable showing notifications in all app states
        ticker: 'HealthTrack Notification',
        // Make sure notification appears as a banner
        styleInformation: BigTextStyleInformation(body),
        // Ensure notification shows in foreground
        ongoing: false,
        autoCancel: true,
        // Only use full screen intent for alarms/critical alerts; default to false.
        fullScreenIntent: false,
        // Category for system handling
        category: AndroidNotificationCategory.recommendation,
        // Additional settings for better visibility
        onlyAlertOnce: false,
        showWhen: true,
        color: const Color.fromARGB(255, 33, 150, 243),
      );
      
      // iOS notification details with enhanced configuration
      final DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // For iOS 10+ to show in foreground
        interruptionLevel: InterruptionLevel.timeSensitive,
        // Add subtitle if available
        subtitle: message.data['subtitle'],
        // Add thread identifier for grouping
        threadIdentifier: message.data['threadId'] ?? 'healthtrack_notifications',
        // Additional settings for better visibility
        badgeNumber: 1,
      );
      
      // Linux notification details
      final LinuxNotificationDetails linuxNotificationDetails =
          LinuxNotificationDetails();
      
      // All platforms notification details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
        linux: linuxNotificationDetails,
      );
      
      // Show the notification
      await _localNotificationsPlugin?.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(message.data), // Pass the data payload as JSON
      );
      
      print('🔔 Local notification shown: $title - $body');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  static String _resolveAppointmentNotificationBody(Map<String, dynamic> data, String fallbackBody) {
    final String type = (data['type'] ?? data['notificationType'] ?? '').toString();
    final bool isAppointmentType = type == 'appointment_approved' ||
        type == 'appointment_rescheduled' ||
        type == 'appointment_reminder' ||
        type == 'appointment_in_progress' ||
        type == 'appointment_completed' ||
        type == 'appointment_missed';

    if (!isAppointmentType) return fallbackBody;

    final String displayValue = (data['appointmentTimeDisplay'] ?? data['appointment_time_display'] ?? '').toString().trim();
    if (displayValue.isNotEmpty) {
      if (type == 'appointment_approved') {
        return 'Your appointment on $displayValue is confirmed.';
      }
      if (type == 'appointment_rescheduled') {
        return 'Your appointment has been moved to $displayValue.';
      }
      return 'Reminder: Your appointment is on $displayValue.';
    }

    final String utcTimestamp = (data['appointmentTimestampUtc'] ?? data['appointment_timestamp_utc'] ?? '').toString().trim();
    if (utcTimestamp.isEmpty) return fallbackBody;

    try {
      final String localDisplay = TimeUtils.formatUtcTimestampToManila(
        utcTimestamp,
        pattern: 'MMMM dd, yyyy hh:mm a',
      );
      if (localDisplay == utcTimestamp) return fallbackBody;
      if (type == 'appointment_approved') {
        return 'Your appointment on $localDisplay is confirmed.';
      }
      if (type == 'appointment_rescheduled') {
        return 'Your appointment has been moved to $localDisplay.';
      }
      return 'Reminder: Your appointment is on $localDisplay.';
    } catch (_) {
      return fallbackBody;
    }
  }
  
  // Save FCM token to server with enhanced retry mechanism
  static Future<void> _saveTokenToServer(String token) async {
    try {
      // Validate token format before sending
      if (!_isValidFcmToken(token)) {
        print('⚠️ Invalid FCM token format, skipping save to server');
        return;
      }
      
      // Get current user ID from session
      final userId = UserSession.instance.userId;
      if (userId.isEmpty) {
        print('⚠️ No user logged in, scheduling token save for after login');
        // Set up a listener for user login
        _scheduleTokenSaveAfterLogin(token);
        return;
      }
      
      // Check if we've exceeded maximum save attempts
      if (_tokenSaveAttempts >= MAX_TOKEN_SAVE_ATTEMPTS) {
        print('⚠️ Maximum token save attempts exceeded, stopping retries');
        return;
      }
      
      print('💾 Saving FCM token to server for user $userId...');
      final deviceId = await _getOrCreateDeviceId();
      
      // Send token to a working server URL (handles fallback URLs)
      final workingBaseUrl = await ApiConfig.getWorkingBaseUrl();
      final url = Uri.parse('$workingBaseUrl/auth/save-fcm-token');
      
      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'HealthTrack-Flutter-App',
          },
          body: json.encode({
            'userId': userId,
            'fcmToken': token,
            'deviceId': deviceId,
            'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
            'timestamp': DateTime.now().toIso8601String(),
          }),
        ).timeout(Duration(seconds: 30)); // Add timeout
        
        print('📡 Server response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('✅ FCM token saved to server successfully');
          // Reset attempts counter on success
          _tokenSaveAttempts = 0;
          
          // Emit token saved event for other parts of the app
          _tokenController?.add(token);
        } else {
          print('❌ Failed to save FCM token to server: ${response.statusCode}');
          print('📄 Response body: ${response.body}');
          
          // Increment attempts counter
          _tokenSaveAttempts++;
          
          // Retry with exponential backoff
          if (_tokenSaveAttempts < MAX_TOKEN_SAVE_ATTEMPTS) {
            final delay = Duration(seconds: 10 * _tokenSaveAttempts); // Increased delay
            print('🔄 Retrying token save in ${delay.inSeconds} seconds (attempt $_tokenSaveAttempts/$MAX_TOKEN_SAVE_ATTEMPTS)');
            Future.delayed(delay, () => _saveTokenToServer(token));
          }
        }
      } catch (e) {
        print('❌ HTTP error saving FCM token: $e');
        
        // Increment attempts counter
        _tokenSaveAttempts++;
        
        // Retry with exponential backoff
        if (_tokenSaveAttempts < MAX_TOKEN_SAVE_ATTEMPTS) {
          final delay = Duration(seconds: 10 * _tokenSaveAttempts);
          print('🔄 Retrying token save in ${delay.inSeconds} seconds (attempt $_tokenSaveAttempts/$MAX_TOKEN_SAVE_ATTEMPTS)');
          Future.delayed(delay, () => _saveTokenToServer(token));
        }
      }
    } catch (e) {
      print('❌ General error saving FCM token to server: $e');
      
      // Increment attempts counter
      _tokenSaveAttempts++;
      
      // Retry with exponential backoff
      if (_tokenSaveAttempts < MAX_TOKEN_SAVE_ATTEMPTS) {
        final delay = Duration(seconds: 10 * _tokenSaveAttempts);
        print('🔄 Retrying token save in ${delay.inSeconds} seconds (attempt $_tokenSaveAttempts/$MAX_TOKEN_SAVE_ATTEMPTS)');
        Future.delayed(delay, () => _saveTokenToServer(token));
      }
    }
  }
  
  // Validate FCM token format (more permissive to accept real tokens)
  static bool _isValidFcmToken(String token) {
    // FCM tokens are typically long strings (usually 100+ characters)
    // They should not be null, empty, or contain spaces
    if (token.isEmpty || token.contains(' ')) {
      return false;
    }
    
    // FCM tokens are usually quite long (100+ characters)
    if (token.length < 50) {
      // Very short tokens are likely fake/test tokens
      return false;
    }
    
    // More permissive regex that accepts real FCM token characters
    // Real FCM tokens can contain: alphanumeric, colons, dashes, underscores, and periods
    final fcmTokenRegex = RegExp(r'^[a-zA-Z0-9:_\-\.]+$');
    return fcmTokenRegex.hasMatch(token);
  }
  
  // Get FCM token stream
  static Stream<String> get tokenStream {
    _tokenController ??= StreamController<String>.broadcast();
    return _tokenController!.stream;
  }

  static Stream<Map<String, dynamic>> get notificationTapStream {
    _tapController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _tapController!.stream;
  }

  static void _emitTapEvent(Map<String, dynamic> data) {
    _tapController ??= StreamController<Map<String, dynamic>>.broadcast();
    _tapController!.add(data);
  }
  
  // Get current FCM token
  static Future<String?> getToken() async {
    final token = await _messaging?.getToken();
    if (token != null && _isValidFcmToken(token)) {
      return token;
    }
    return null;
  }

  static Future<void> syncTokenForCurrentUser() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null && _isValidFcmToken(token)) {
        await _saveTokenToServer(token);
      }
    } catch (e) {
      print('❌ Error syncing FCM token for current user: $e');
    }
  }
  
  // Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging?.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }
  
  // Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging?.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }
  
  // Request notification permissions (can be called manually if needed)
  static Future<bool> requestNotificationPermissions() async {
    try {
      final NotificationSettings settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
        carPlay: false,
        criticalAlert: false,
        announcement: false,
      ) ?? NotificationSettings(
        authorizationStatus: AuthorizationStatus.notDetermined,
        alert: AppleNotificationSetting.notSupported,
        badge: AppleNotificationSetting.notSupported,
        sound: AppleNotificationSetting.notSupported,
        carPlay: AppleNotificationSetting.notSupported,
        criticalAlert: AppleNotificationSetting.notSupported,
        announcement: AppleNotificationSetting.notSupported,
        notificationCenter: AppleNotificationSetting.notSupported,
        lockScreen: AppleNotificationSetting.notSupported,
        showPreviews: AppleShowPreviewSetting.notSupported,
        timeSensitive: AppleNotificationSetting.notSupported,
        providesAppNotificationSettings: AppleNotificationSetting.notSupported,
      );
      
      print('🔔 Notification permission requested. Status: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // Schedule periodic token refresh check
  static void _scheduleTokenRefreshCheck() {
    // Check token validity every 6 hours
    Timer.periodic(Duration(hours: 6), (timer) async {
      print('🔄 Periodic token refresh check...');
      try {
        final currentToken = await _messaging?.getToken();
        if (currentToken != null && _isValidFcmToken(currentToken)) {
          print('✅ Token is still valid');
          // Optionally re-save token to ensure it's up to date
          await _saveTokenToServer(currentToken);
        } else {
          print('⚠️ Token is invalid or missing, refreshing...');
          await _retrieveAndSaveToken();
        }
      } catch (e) {
        print('❌ Error during periodic token check: $e');
      }
    });
  }

  // Schedule token save after user login
  static void _scheduleTokenSaveAfterLogin(String token) {
    // Check for user login every 10 seconds for up to 5 minutes
    int attempts = 0;
    const maxAttempts = 30; // 30 * 10 seconds = 5 minutes
    
    Timer.periodic(Duration(seconds: 10), (timer) async {
      attempts++;
      final userId = UserSession.instance.userId;
      
      if (userId.isNotEmpty) {
        timer.cancel();
        print('👤 User detected, saving pending FCM token...');
        await _saveTokenToServer(token);
      } else if (attempts >= maxAttempts) {
        timer.cancel();
        print('⏰ Token save timeout - no user login detected within 5 minutes');
      }
    });
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random();
    final generated = "dev_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(1 << 32)}";
    await prefs.setString('device_id', generated);
    return generated;
  }

  // Enhanced method to check and trigger notifications for existing appointments
  static Future<void> checkAndTriggerAppointmentNotifications() async {
    try {
      final userId = UserSession.instance.userId;
      if (userId.isEmpty) {
        print('⚠️ No user logged in, skipping appointment notification check');
        return;
      }

      print('🔍 Checking for existing appointments to trigger notifications...');
      
      // This would call an API endpoint to get upcoming appointments
      // For now, we'll trigger a general reminder notification
      final url = Uri.parse('${ApiConfig.baseUrl}/appointments/user/$userId');
      
      try {
        // Fetch user JWT token for authenticated request
        final prefs = await SharedPreferences.getInstance();
        final userToken = prefs.getString('healthtrack_user_bearer_token') ?? '';
        
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (userToken.isNotEmpty) 'Authorization': 'Bearer $userToken',
          },
        ).timeout(Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final appointments = data['data'] as List;
            
            for (final appointment in appointments) {
              final appointmentDate = (appointment['appointment_date'] ?? '').toString();
              final appointmentTime = (appointment['appointment_time'] ?? '').toString();
              final appointmentUtcRaw = '$appointmentDate $appointmentTime'.trim();
              final appointmentManila = TimeUtils.parseUtcTimestampToManila(appointmentUtcRaw);
              final nowManila = TimeUtils.manilaNow();
              if (appointmentManila == null || nowManila == null) continue;
              final difference = appointmentManila.difference(nowManila);
              
              // Trigger notification for appointments within 24 hours
              if (difference.inHours <= 24 && difference.inHours > 0) {
                final title = 'Upcoming Appointment Reminder';
                final scheduleDisplay = TimeUtils.formatAppointmentUtcDateTime(
                  appointmentDate,
                  appointmentTime,
                  pattern: 'MMMM dd, yyyy hh:mm a',
                );
                final body = 'You have an appointment scheduled for ${appointment['appointment_type']} on $scheduleDisplay';
                
                // Show local notification immediately
                await _showImmediateLocalNotification(title, body);
                print('🔔 Triggered notification for upcoming appointment: $title');
              }
            }
          }
        }
      } catch (e) {
        print('❌ Error fetching appointments for notification check: $e');
      }
    } catch (e) {
      print('❌ Error in appointment notification check: $e');
    }
  }

  // Show immediate local notification
  static Future<void> _showImmediateLocalNotification(String title, String body) async {
    try {
      if (_localNotificationsPlugin == null) return;
      
      final int notificationId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      
      // Android notification details
      final AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'healthtrack_fcm_channel', 
        'HealthTrack Notifications',
        channelDescription: 'HealthTrack app notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        visibility: NotificationVisibility.public,
        ticker: 'HealthTrack Notification',
        styleInformation: BigTextStyleInformation(body),
        ongoing: false,
        autoCancel: true,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.reminder,
        onlyAlertOnce: false,
        showWhen: true,
        color: const Color.fromARGB(255, 33, 150, 243),
      );
      
      // iOS notification details
      final DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        threadIdentifier: 'healthtrack_appointments',
        badgeNumber: 1,
      );
      
      // Linux notification details
      final LinuxNotificationDetails linuxNotificationDetails =
          LinuxNotificationDetails();
      
      // All platforms notification details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iOSNotificationDetails,
        linux: linuxNotificationDetails,
      );
      
      // Show notification
      await _localNotificationsPlugin?.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode({
          'type': 'appointment_reminder',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      print('🔔 Immediate local notification shown: $title - $body');
    } catch (e) {
      print('❌ Error showing immediate local notification: $e');
    }
  }
}