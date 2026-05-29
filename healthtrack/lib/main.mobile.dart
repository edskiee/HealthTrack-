import 'package:flutter/material.dart';
import 'package:healthtrack/splash_screen.dart';
import 'package:healthtrack/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthtrack/dashboard.dart';
import 'package:healthtrack/login_screen.dart';
import 'package:healthtrack/unified_register_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:healthtrack/services/fcm_service.dart';
import 'package:healthtrack/services/ip_initializer.dart';
import 'package:healthtrack/services/reminder_notification_service.dart';
import 'package:overlay_support/overlay_support.dart';

// Check for existing appointments and trigger notifications if needed
Future<void> _checkExistingAppointments() async {
  try {
    print('🔍 Checking for existing appointments on app startup...');
    
    // Wait a moment for services to be fully initialized
    await Future.delayed(Duration(seconds: 2));
    
    // Trigger the appointment notification check
    await FCMService.checkAndTriggerAppointmentNotifications();
  } catch (e) {
    print('❌ Error checking existing appointments: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  // Register top-level background handler before runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize FCM service
  await FCMService.initialize();
  
  // Initialize Reminder Notification service
  await ReminderNotificationService.initialize();
  
  // Check for existing appointments and trigger notifications if needed
  // This ensures users get notifications even if background jobs failed
  await _checkExistingAppointments();
  
  // Initialize IP detection
  await IpInitializer.initialize();
  
  final prefs = await SharedPreferences.getInstance();
  final bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(SettingsProvider(
    isDarkMode: isDarkMode,
    updateTheme: (bool value) {}, // placeholder, will be replaced by StatefulWidget
    child: const HealthTrackApp(),
  ));
}

class SettingsProvider extends InheritedWidget {
  final bool isDarkMode;
  final Function(bool) updateTheme;

  const SettingsProvider({
    super.key,
    required this.isDarkMode,
    required this.updateTheme,
    required super.child,
  });

  static SettingsProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
  }

  @override
  bool updateShouldNotify(SettingsProvider oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
}

class HealthTrackApp extends StatefulWidget {
  const HealthTrackApp({super.key});

  @override
  State<HealthTrackApp> createState() => _HealthTrackAppState();
}

class _HealthTrackAppState extends State<HealthTrackApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _updateTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsProvider(
      isDarkMode: _isDarkMode,
      updateTheme: _updateTheme,
      child: OverlaySupport.global(
        child: MaterialApp(
          title: 'HealthTrack',
          theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const UnifiedRegisterScreen(),
            '/dashboard': (context) => const DashboardScreen(),
          },
        ),
      ),
    );
  }
}