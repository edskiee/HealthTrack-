import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static io.Socket? _socket;
  static bool _initialized = false;
  static bool _isConnecting = false;
  static bool _shouldReconnect = true;
  static int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static Timer? _reconnectTimer;
  static Timer? _healthCheckTimer;
  
  static FlutterLocalNotificationsPlugin? _localNotificationsPlugin;
  
  // Callbacks for different events
  Function(Map<String, dynamic>)? onAppointmentNotification;
  Function(Map<String, dynamic>)? onAppointmentUpdated;
  Function()? onSlotsUpdated;
  
  // Allow multiple listeners for slot updates
  final List<Function()> _slotsUpdatedListeners = [];

  /// Multiple listeners for appointment notification (avoids one screen clobbering another).
  final List<void Function(Map<String, dynamic>)> _appointmentNotificationListeners = [];

  /// Multiple listeners for appointment record updates (avoids one screen clobbering another).
  final List<void Function(Map<String, dynamic>)> _appointmentUpdatedListeners = [];
  
  WebSocketService._privateConstructor();
  
  static WebSocketService get instance {
    _instance ??= WebSocketService._privateConstructor();
    return _instance!;
  }
  
  // Add a listener for slot updates
  void addSlotsUpdatedListener(Function() listener) {
    _slotsUpdatedListeners.add(listener);
  }
  
  // Remove a listener for slot updates
  void removeSlotsUpdatedListener(Function() listener) {
    _slotsUpdatedListeners.remove(listener);
  }

  void addAppointmentUpdatedListener(void Function(Map<String, dynamic>) listener) {
    if (!_appointmentUpdatedListeners.contains(listener)) {
      _appointmentUpdatedListeners.add(listener);
    }
  }

  void removeAppointmentUpdatedListener(void Function(Map<String, dynamic>) listener) {
    _appointmentUpdatedListeners.remove(listener);
  }

  void addAppointmentNotificationListener(void Function(Map<String, dynamic>) listener) {
    if (!_appointmentNotificationListeners.contains(listener)) {
      _appointmentNotificationListeners.add(listener);
    }
  }

  void removeAppointmentNotificationListener(void Function(Map<String, dynamic>) listener) {
    _appointmentNotificationListeners.remove(listener);
  }
  
  // Get the correct WebSocket URL based on API service
  static Future<String> getWebSocketUrl() async {
    final apiService = ApiService.instance;
    await apiService.initialize();
    
    final baseUrl = apiService.baseUrl;
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    } else {
      return baseUrl.replaceFirst('http://', 'ws://');
    }
  }
  
  // Initialize the WebSocket connection with proper error handling
  Future<void> initialize() async {
    if (_initialized && _socket != null && _socket!.connected) {
      print('WebSocket already connected');
      return;
    }
    
    if (_isConnecting) {
      print('WebSocket connection already in progress');
      return;
    }
    
    try {
      _isConnecting = true;
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      final wsUrl = await getWebSocketUrl();
      print('Connecting to WebSocket: $wsUrl');
      
      _socket = io.io(wsUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': false, // We'll handle reconnection manually
        'timeout': 10000,
      });
      
      // Set up event listeners
      _setupEventListeners();
      
      // Connect to the server
      _socket?.connect();
      
      // Start health check timer
      _startHealthCheckTimer();
      
      _initialized = true;
      print('WebSocket service initialized');
    } catch (e) {
      print('Error initializing WebSocket service: $e');
      _isConnecting = false;
      
      // Schedule reconnection attempt
      if (_shouldReconnect) {
        _scheduleReconnect();
      }
    }
  }
  
  // Set up all event listeners
  void _setupEventListeners() {
    // Listen for connection events
    _socket?.onConnect((data) {
      print('WebSocket connected: ${_socket?.id}');
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      // Re-join rooms if previously connected
      _rejoinRooms();
    });
    
    // Listen for disconnection events
    _socket?.onDisconnect((data) {
      print('WebSocket disconnected: $data');
      _isConnecting = false;
      
      // Schedule reconnection if it wasn't intentional
      if (_shouldReconnect && data != 'io client disconnect') {
        _scheduleReconnect();
      }
    });
    
    // Listen for connection error events
    _socket?.onConnectError((data) {
      print('WebSocket connection error: $data');
      _isConnecting = false;
      
      // Schedule reconnection if we should keep trying
      if (_shouldReconnect) {
        _scheduleReconnect();
      }
    });
    
    // Listen for error events
    _socket?.onError((data) {
      print('WebSocket error: $data');
    });
    
    // Listen for appointment notifications
    _socket?.on('appointmentNotification', (data) {
      print('Appointment notification received: $data');
      Map<String, dynamic>? payload;
      if (data is Map) {
        try { payload = Map<String, dynamic>.from(data); } catch (_) {}
      }
      if (payload != null) {
        // Legacy single-slot callback (kept for backward compat)
        if (onAppointmentNotification != null) {
          onAppointmentNotification!(payload);
        }
        // Multi-listener list
        for (final listener in List<void Function(Map<String, dynamic>)>.from(_appointmentNotificationListeners)) {
          try { listener(payload); } catch (e) { print('appointmentNotification listener error: $e'); }
        }
      }
      _showLocalNotification(data);
    });
    
    // Listen for appointment updates
    _socket?.on('appointmentUpdated', (data) {
      print('Appointment updated: $data');
      Map<String, dynamic>? payload;
      if (data is Map) {
        try {
          payload = Map<String, dynamic>.from(data);
        } catch (_) {
          payload = null;
        }
      }
      if (payload != null) {
        if (onAppointmentUpdated != null) {
          onAppointmentUpdated!(payload);
        }
        for (final listener in List<void Function(Map<String, dynamic>)>.from(_appointmentUpdatedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            print('appointmentUpdated listener error: $e');
          }
        }
      }
    });
    
    // Listen for slot updates
    _socket?.on('slotsUpdated', (data) {
      print('Slots updated: $data');
      // Notify all listeners
      for (var listener in _slotsUpdatedListeners) {
        listener();
      }
      // Also notify the legacy callback if set
      if (onSlotsUpdated != null) {
        onSlotsUpdated!();
      }
    });
  }
  
  // Initialize local notifications with sound and icon
  Future<void> _initializeLocalNotifications() async {
    try {
      _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
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
      
      // Initialize the plugin
      await _localNotificationsPlugin?.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('Notification tapped: ${response.payload}');
        },
      );
      
      print('Local notifications initialized');
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }
  
  // Show local notification with sound and icon
  Future<void> _showLocalNotification(dynamic data) async {
    try {
      if (_localNotificationsPlugin == null) return;
      
      // Extract notification details
      final String title = data['title'] ?? 'Appointment Update';
      final String message = data['message'] ?? 'You have a new notification';
      final int notificationId = data['id'] ?? DateTime.now().millisecondsSinceEpoch;
      
      // Android notification details
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'healthtrack_appointment_channel', 
        'Appointment Notifications',
        channelDescription: 'Notifications for appointment updates',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        showProgress: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      );
      
      // iOS notification details
      const DarwinNotificationDetails iOSNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      // Linux notification details
      const LinuxNotificationDetails linuxNotificationDetails =
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
        message,
        notificationDetails,
        payload: 'appointment_notification',
      );
      
      print('Local notification shown: $title - $message');
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }
  
  // Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('Max reconnection attempts reached. Stopping reconnection.');
      _shouldReconnect = false;
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _calculateBackoffDelay(_reconnectAttempts));
    
    print('Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !_isConnecting) {
        print('Attempting to reconnect...');
        _reconnect();
      }
    });
  }
  
  // Calculate exponential backoff delay
  int _calculateBackoffDelay(int attempt) {
    // Exponential backoff with jitter: 2^attempt + random(0-2)
    final baseDelay = (1 << attempt).clamp(1, 30); // Max 30 seconds
    final jitter = (DateTime.now().millisecond % 3);
    return baseDelay + jitter;
  }
  
  // Manual reconnection attempt
  Future<void> _reconnect() async {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    
    _initialized = false;
    await initialize();
  }
  
  // Start periodic health check
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnected) {
        print('Health check failed: WebSocket not connected');
        if (_shouldReconnect && !_isConnecting) {
          _scheduleReconnect();
        }
      }
    });
  }
  
  // Re-join rooms after reconnection
  void _rejoinRooms() {
    // This will be handled by the calling components
    // They should re-join their rooms when they detect reconnection
    print('Rooms ready to be rejoined after reconnection');
  }
  
  // Join a user-specific room with connection check
  void joinUserRoom(int userId) {
    if (isConnected) {
      _socket?.emit('joinUserRoom', userId);
      print('Joined user room: user_$userId');
    } else {
      print('Cannot join user room: WebSocket not connected');
      // Try to connect and then join
      initialize().then((_) {
        if (isConnected) {
          joinUserRoom(userId);
        }
      });
    }
  }
  
  // Join admin room for slot management with connection check
  void joinAdminsRoom() {
    if (isConnected) {
      _socket?.emit('joinAdminsRoom');
      print('Joined admins room for slot management');
    } else {
      print('Cannot join admins room: WebSocket not connected');
      // Try to connect and then join
      initialize().then((_) {
        if (isConnected) {
          joinAdminsRoom();
        }
      });
    }
  }
  
  // Leave admin room
  void leaveAdminsRoom() {
    if (isConnected) {
      _socket?.emit('leaveAdminsRoom');
      print('Left admins room');
    }
  }
  
  // Leave a user-specific room
  void leaveUserRoom(int userId) {
    if (isConnected) {
      _socket?.emit('leaveUserRoom', userId);
      print('Left user room: user_$userId');
    }
  }
  
  // Disconnect the WebSocket
  void disconnect({bool intentional = true}) {
    _shouldReconnect = !intentional;
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    
    if (intentional) {
      _socket?.disconnect();
      print('WebSocket disconnected intentionally');
    } else {
      _socket?.disconnect();
      print('WebSocket disconnected');
    }
    
    _initialized = false;
    _isConnecting = false;
  }
  
  // Check if connected
  bool get isConnected => _socket?.connected ?? false;
  
  // Get connection status
  Map<String, dynamic> getStatus() {
    return {
      'connected': isConnected,
      'initialized': _initialized,
      'connecting': _isConnecting,
      'shouldReconnect': _shouldReconnect,
      'reconnectAttempts': _reconnectAttempts,
      'maxReconnectAttempts': _maxReconnectAttempts,
      'socketId': _socket?.id,
    };
  }
  
  // Force reconnection
  Future<void> forceReconnect() async {
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    await _reconnect();
  }
  
  // Dispose of resources
  void dispose() {
    disconnect(intentional: true);
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _slotsUpdatedListeners.clear();
    _appointmentNotificationListeners.clear();
    _appointmentUpdatedListeners.clear();
    onAppointmentNotification = null;
    onAppointmentUpdated = null;
    onSlotsUpdated = null;
  }
}