import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'admin_login_screen.dart';
import 'theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
            home: const AdminLoginScreen(),
          );
        },
      ),
    );
  }
}