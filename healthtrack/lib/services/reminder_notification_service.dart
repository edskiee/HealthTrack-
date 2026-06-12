import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:healthtrack/services/reminder_service.dart';
import 'package:healthtrack/services/user_session.dart';
import 'dart:convert';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  static FlutterLocalNotificationsPlugin? _localNotificationsPlugin;
  static bool _initialized = false;
  static bool _tzInitialized = false;
  
  // Initialize the reminder notification service
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _initializeTimeZone();

      // Initialize local notifications plugin
      _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Android initialization settings for reminder notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      // All platforms initialization settings
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      // Initialize the plugin
      await _localNotificationsPlugin?.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('🔔 Reminder notification tapped: ${response.payload}');
        },
      );

      // Ensure Android channel + permissions exist
      await _createReminderChannel();
      await _requestPlatformPermissionsIfNeeded();

      // Schedule reminders using OS scheduler (works when app is terminated)
      await syncSchedules();
      
      print('🟢 Reminder Notification Service initialized successfully');
      _initialized = true;
    } catch (e) {
      print('❌ Error initializing Reminder Notification Service: $e');
    }
  }
  
  /// Sync all reminders from backend into scheduled local notifications.
  /// This is the reliable path for foreground/background/terminated delivery.
  static Future<void> syncSchedules() async {
    try {
      if (_localNotificationsPlugin == null) return;
      if (!UserSession.instance.isLoggedIn) return;

      // Clear existing reminder notifications to prevent duplicates and stale schedules.
      // (We only clear the reminder channel's IDs by convention; cancelAll is too aggressive.)
      await _cancelAllReminderNotifications();

      final reminders = await ReminderService.getUserReminders();
      for (final reminder in reminders) {
        await _scheduleReminder(reminder);
      }

      final pending = await _localNotificationsPlugin?.pendingNotificationRequests() ?? [];
      final reminderPending = pending.where((p) => p.payload?.contains('"type":"reminder"') == true).length;
      print('✅ Reminder schedules synced. Pending reminder notifications: $reminderPending');
    } catch (e) {
      print('❌ Error syncing reminder schedules: $e');
    }
  }
  
  static Future<void> _scheduleReminder(Reminder reminder) async {
    if (_localNotificationsPlugin == null) return;
    await _initializeTimeZone();

    final scheduledLocal = _buildScheduledDateTime(reminder);
    if (scheduledLocal == null) return;

    final now = tz.TZDateTime.now(tz.local);
    if (!reminder.isRepeating && scheduledLocal.isBefore(now)) {
      // Don't schedule notifications in the past.
      return;
    }

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'healthtrack_reminder_channel',
        'Reminder Notifications',
        channelDescription: 'Notifications for scheduled reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(reminder.notes ?? 'You have a scheduled reminder'),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    final title = 'Reminder: ${reminder.title}';
    final body = reminder.notes ?? 'You have a scheduled reminder';

    if (!reminder.isRepeating) {
      await _localNotificationsPlugin?.zonedSchedule(
        _notificationIdForOnce(reminder.id),
        title,
        body,
        scheduledLocal,
        notificationDetails,
        payload: json.encode({
          ...reminder.toJson(),
          'type': 'reminder',
          'schedule': 'once',
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return;
    }

    // Repeating reminders
    final repeatInterval = reminder.repeatInterval;
    if (repeatInterval == 'daily') {
      // Schedule daily at the selected time (or midnight).
      final next = _nextDailyInstance(scheduledLocal);
      await _localNotificationsPlugin?.zonedSchedule(
        _notificationIdForDaily(reminder.id),
        title,
        body,
        next,
        notificationDetails,
        payload: json.encode({
          ...reminder.toJson(),
          'type': 'reminder',
          'schedule': 'daily',
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }

    // Weekly: schedule per selected day.
    final days = reminder.repeatDays ?? const <String>[];
    final normalized = days.contains('Everyday') ? _weekdayNames : days;
    for (final weekdayName in normalized) {
      final weekday = _weekdayFromName(weekdayName);
      if (weekday == null) continue;
      final next = _nextWeeklyInstance(scheduledLocal, weekday);
      await _localNotificationsPlugin?.zonedSchedule(
        _notificationIdForWeekly(reminder.id, weekday),
        title,
        body,
        next,
        notificationDetails,
        payload: json.encode({
          ...reminder.toJson(),
          'type': 'reminder',
          'schedule': 'weekly',
          'weekday': weekday,
        }),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static tz.TZDateTime? _buildScheduledDateTime(Reminder reminder) {
    final date = reminder.reminderDate;

    int hour = 0;
    int minute = 0;
    if (reminder.reminderTime != null) {
      final parts = reminder.reminderTime!.split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    final local = DateTime(date.year, date.month, date.day, hour, minute);
    return tz.TZDateTime.from(local, tz.local);
  }

  static const List<String> _weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static int? _weekdayFromName(String name) {
    final idx = _weekdayNames.indexOf(name);
    if (idx == -1) return null;
    return idx + 1; // DateTime weekday: 1=Mon ... 7=Sun
  }

  static tz.TZDateTime _nextDailyInstance(tz.TZDateTime targetTime) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, targetTime.hour, targetTime.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextWeeklyInstance(tz.TZDateTime seedTime, int weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, seedTime.hour, seedTime.minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static int _notificationIdForOnce(int reminderId) => reminderId;
  static int _notificationIdForDaily(int reminderId) => reminderId * 10 + 1;
  static int _notificationIdForWeekly(int reminderId, int weekday) => reminderId * 10 + weekday;

  static Future<void> _cancelAllReminderNotifications() async {
    if (_localNotificationsPlugin == null) return;
    // Cancel deterministic IDs we generate.
    // (Once + daily + each weekday)
    for (final pending in await _localNotificationsPlugin!.pendingNotificationRequests()) {
      final payload = pending.payload;
      if (payload != null && payload.contains('"type":"reminder"')) {
        await _localNotificationsPlugin?.cancel(pending.id);
      }
    }
  }

  static Future<void> _createReminderChannel() async {
    final android = _localNotificationsPlugin?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'healthtrack_reminder_channel',
        'Reminder Notifications',
        description: 'Notifications for scheduled reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    );
  }

  static Future<void> _requestPlatformPermissionsIfNeeded() async {
    final android = _localNotificationsPlugin?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> _initializeTimeZone() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.toString()));
    } catch (e) {
      // Fallback: keep default local location.
      print('⚠️ Failed to resolve local timezone; using default. Error: $e');
    }
    _tzInitialized = true;
  }
  
  // Dispose the service
  static void dispose() {
    _initialized = false;
  }
}