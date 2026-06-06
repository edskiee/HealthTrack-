import 'package:flutter/material.dart';
import 'dart:async';
import 'home_tab.dart';
import 'appointments_tab.dart';
import 'notifications_tab.dart';
import 'healthcard_tab.dart';
import 'maternal_healthcard_tab.dart';
import 'utils/message_utils.dart';

import 'services/user_session.dart';
import 'services/startup_health_check.dart';
import 'widgets/common/real_time_notification_badge.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Timer? _notificationTimer;
  StreamSubscription<Map<String, dynamic>>? _notificationTapSub;

  late final List<Widget> _pages;

  final List<String> _titles = const [
    "Dashboard",
    "Appointments",
    "Notifications",
    "Health Card",
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      // Home tab - unified dashboard for both maternal and immunization users
      HomeTab(
        onQuickActionSelected: (String action) {
          if (action == "Appointments") {
            setState(() => _selectedIndex = 1);
          } else if (action == "Notifications") {
            setState(() => _selectedIndex = 2);
          } else if (action == "HealthCard") {
            setState(() => _selectedIndex = 3);
          }
          // Removed BookAppointment handling as per new requirements
        },
      ),
      const AppointmentTab(),
      NotificationsTab(
        onNotificationTap: (String msg) {
          // Check if context is still valid before showing message
          if (context.mounted) {
            MessageUtils.showInfoMessage(
              context,
              "Notification: $msg",
              title: "Notification Details",
            );
          }
        },
      ),
      // Health card tab - service type specific
      if (UserSession.instance.serviceType == 'maternal')
        const MaternalHealthCardTab()
      else
        const HealthCardTab(),
    ];

    _notificationTapSub = FCMService.notificationTapStream.listen(_handleNotificationTapData);

    // Check backend on dashboard load — silently skips if recently confirmed online
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StartupHealthCheck.run(context);
    });
  }

  void _handleNotificationTapData(Map<String, dynamic> payload) {
    final payloadType =
        (payload['type'] ?? payload['notificationType'] ?? '').toString();
    if (payloadType == 'appointment_in_progress' ||
        payloadType == 'appointment_completed' ||
        payloadType == 'appointment_missed') {
      if (mounted) {
        setState(() => _selectedIndex = 2);
      }
      return;
    }
    if (payloadType.contains('appointment')) {
      if (mounted) {
        setState(() => _selectedIndex = 1);
      }
    } else {
      if (mounted) {
        setState(() => _selectedIndex = 2);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _notificationTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double titleFontSize = screenWidth < 350 ? 16 : (screenWidth < 400 ? 18 : 22);

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        backgroundColor: Colors.blueAccent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove back arrow
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _pages[_selectedIndex],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            showUnselectedLabels: true,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home, size: 24), label: "Home"),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today, size: 24), label: "Appointments"),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications, size: 24),
                    RealTimeNotificationBadge(
                      unreadCountStream: NotificationService.streamUnreadCount(int.tryParse(UserSession.instance.userId) ?? 0),
                    ),
                  ],
                ),
                label: "Notifications",
              ),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle, size: 24), label: "Health Card"),
            ],
          ),
        ),
      ),
    );
  }
}