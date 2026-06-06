import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'admin_login_screen.dart';
import 'theme_provider.dart';
import 'services/admin_session_storage.dart';
import '../services/startup_health_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdminSessionStorage.warmUp();
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'HealthTrack Admin',
            themeMode: themeProvider.themeMode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            // AdminStartupGate runs the health check before showing the login screen
            home: const AdminStartupGate(),
          );
        },
      ),
    );
  }
}

/// Shows the wakeup overlay on web before navigating to the login screen.
/// On mobile this is handled by the SplashScreen instead.
class AdminStartupGate extends StatefulWidget {
  const AdminStartupGate({super.key});

  @override
  State<AdminStartupGate> createState() => _AdminStartupGateState();
}

class _AdminStartupGateState extends State<AdminStartupGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkServer());
  }

  Future<void> _checkServer() async {
    if (!mounted) return;
    // Run health check — shows overlay if server is waking up
    await StartupHealthCheck.run(context);
    if (!mounted) return;
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      // Minimal placeholder while the first health probe runs
      return const Scaffold(
        backgroundColor: Color(0xFF0047C8),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.health_and_safety_rounded,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'HealthTrack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Connecting…',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return const AdminLoginScreen();
  }
}
