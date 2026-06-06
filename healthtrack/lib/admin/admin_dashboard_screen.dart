import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:healthtrack/admin/services/admin_preferences_api_service.dart';
import 'package:healthtrack/admin/theme_provider.dart';
import 'package:healthtrack/admin/services/admin_session_storage.dart';
import 'package:healthtrack/admin/signals/admin_dashboard_signals.dart';
import 'package:healthtrack/services/startup_health_check.dart';

import 'dashboard_view.dart';
import 'manage_patients_view.dart';
import 'appointments_view.dart';
import 'health_records_view.dart';
import 'reports_view.dart';
import 'settings_view.dart';
import 'admin_tools_view.dart';
import 'admin_login_screen.dart';
import 'widgets/admin_sidebar.dart';
import '../utils/message_utils.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const AdminDashboardScreen({super.key, this.adminData});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _autoLogoutEnabled = false;
  Timer? _idleLogoutTimer;

  late final VoidCallback _dashboardSignalsListener;

  bool _truthy(dynamic raw) =>
      raw == true || raw == 1 || raw == 'true' || raw == '1';

  ThemeData _buildShellSkin(String mode, Brightness fallback) {
    Brightness brightness;
    if (mode == 'dark') {
      brightness = Brightness.dark;
    } else if (mode == 'system') {
      brightness = fallback;
    } else {
      brightness = Brightness.light;
    }
    final seed = brightness == Brightness.dark
        ? const Color(0xFF0284C7)
        : const Color(0xFF0EA5E9);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: seed,
      ),
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF020617) : Colors.grey.shade50,
    );
  }

  ThemeData _shellThemeFor(ThemeMode mode, Brightness platformBrightness) {
    late final String m;
    switch (mode) {
      case ThemeMode.dark:
        m = 'dark';
        break;
      case ThemeMode.system:
        m = 'system';
        break;
      case ThemeMode.light:
        m = 'light';
    }
    return _buildShellSkin(m, platformBrightness);
  }

  final List<SidebarMenuItem> _menuItems = const [
    SidebarMenuItem(title: 'Dashboard', icon: Icons.dashboard_outlined),
    SidebarMenuItem(title: 'Manage Patients', icon: Icons.people_outline),
    SidebarMenuItem(
      title: 'Appointments',
      icon: Icons.calendar_today_outlined,
    ),
    SidebarMenuItem(
      title: 'Health Records',
      icon: Icons.health_and_safety_outlined,
    ),
    SidebarMenuItem(
      title: 'Administrative Tools',
      icon: Icons.admin_panel_settings_outlined,
    ),
    SidebarMenuItem(title: 'Reports', icon: Icons.analytics_outlined),
    SidebarMenuItem(title: 'Settings', icon: Icons.settings_outlined),
  ];

  late List<Widget> screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardSignalsListener = () {
      _reloadShellPreferences();
    };
    adminDashboardSignals.addListener(_dashboardSignalsListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadShellPreferences();
      // Silently verify backend is still reachable after logging in
      StartupHealthCheck.run(context);
    });
    _initializeScreens();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    adminDashboardSignals.removeListener(_dashboardSignalsListener);
    _idleLogoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final mode = context.read<ThemeProvider>().themeMode;
    if (mode == ThemeMode.system && mounted) {
      setState(() {});
    }
  }

  void _idleKick() {
    if (!_autoLogoutEnabled) return;
    _idleLogoutTimer?.cancel();
    _idleLogoutTimer = Timer(const Duration(minutes: 30), _performIdleLogout);
  }

  Future<void> _performIdleLogout() async {
    try {
      await AdminPreferencesApi.logoutCurrentSession();
    } catch (_) {}
    await AdminSessionStorage.clear();
    if (!mounted) return;
    MessageUtils.showErrorMessage(
      context,
      'You were logged out automatically after thirty minutes idle.',
      title: 'Session timeout',
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _reloadShellPreferences() async {
    try {
      final payload = await AdminPreferencesApi.fetchPreferencesPayload();
      final prefs =
          payload['preferences'] as Map<String, dynamic>? ?? <String, dynamic>{};
      if (!mounted) return;
      final autoLogout = _truthy(prefs['auto_logout_enabled']);

      setState(() {
        _autoLogoutEnabled = autoLogout;
      });

      _idleKick();
    } catch (_) {
      /* Offline — keep dashboard usable */
    }
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminData != widget.adminData) {
      _initializeScreens();
    }
  }

  void _initializeScreens() {
    screens = [
      const DashboardView(),
      const ManagePatientsView(),
      const AppointmentsView(),
      const HealthRecordsView(),
      const AdminToolsView(),
      const ReportsView(),
      SettingsView(
        adminData: widget.adminData,
        onThemeModeChanged: (_) => pingAdminDashboard(),
      ),
    ];
    if (selectedIndex >= screens.length) {
      selectedIndex = 0;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirm Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to logout?"),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _logout();
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await AdminPreferencesApi.logoutCurrentSession();
    } catch (_) {}
    await AdminSessionStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String username = widget.adminData?["username"] ?? "Admin";
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final platformBrightness = MediaQuery.platformBrightnessOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool shouldAutoCollapse = constraints.maxWidth < 1100;
        final bool isCollapsed = shouldAutoCollapse || _isSidebarCollapsed;
        final shellTheme = _shellThemeFor(themeMode, platformBrightness);
        final surface = shellTheme.colorScheme.surface;

        return Theme(
          data: shellTheme,
          child: Scaffold(
            backgroundColor: shellTheme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _idleKick(),
                child: Row(
                  children: [
                    AdminSidebar(
                      menuItems: _menuItems,
                      selectedIndex: selectedIndex,
                      isCollapsed: isCollapsed,
                      username: username,
                      onMenuTap: (index) {
                        if (selectedIndex == index) return;
                        setState(() => selectedIndex = index);
                      },
                      onToggleCollapse: () {
                        if (shouldAutoCollapse) return;
                        setState(
                          () =>
                              _isSidebarCollapsed = !_isSidebarCollapsed,
                        );
                      },
                      onLogoutTap: () => _showLogoutDialog(context),
                    ),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOutCubic,
                        margin: EdgeInsets.all(isCollapsed ? 10 : 16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: IndexedStack(
                          index: selectedIndex
                              .clamp(0, screens.length - 1),
                          children: screens,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}