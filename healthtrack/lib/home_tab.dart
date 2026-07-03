import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:healthtrack/services/user_session.dart';
import 'package:healthtrack/services/notification_service.dart';
import 'package:healthtrack/services/appointment_service.dart';
import 'package:healthtrack/services/health_tracking_service.dart';
import 'package:healthtrack/services/websocket_service.dart';
import 'package:healthtrack/widgets/user/health_tracking_card.dart';
import 'package:healthtrack/widgets/user/vaccine_dashboard_widget.dart';

class HomeTab extends StatefulWidget {
  final void Function(String action) onQuickActionSelected;

  const HomeTab({
    super.key,
    required this.onQuickActionSelected,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _scheduleAppointments = [];
  bool _loadingSchedules = false;
  late HealthScheduleCategory _trackingCategory;
  List<Map<String, dynamic>> _healthTips = [];
  bool _isLoading = true;
  String? _healthTrackingLoadError;
  Timer? _refreshTimer;
  StreamSubscription<int>? _notificationSubscription;
  StreamSubscription<void>? _userSessionNotificationSubscription;
  StreamSubscription<void>? _activeChildSubscription;
  final Random _random = Random();
  late void Function(Map<String, dynamic>) _onAppointmentRealtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackingCategory = UserSession.instance.serviceType == 'maternal'
        ? HealthScheduleCategory.maternal
        : HealthScheduleCategory.immunization;
    _onAppointmentRealtime = (_) {
      if (mounted) _fetchScheduleTracking();
    };
    _initializeData();
    _initHealthTrackingRealtime();
    _startAutoRefresh();
    _listenForNotificationChanges();
    _listenForUserSessionNotificationChanges();
    // Rebuild when active child changes so the tracking label updates
    _activeChildSubscription =
        UserSession.instance.onActiveChildChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  // Add this method to listen for notification changes from user session
  void _listenForUserSessionNotificationChanges() {
    _userSessionNotificationSubscription = UserSession.instance.onNotificationCountChanged.listen((_) {
      // When notification count changes, refresh the count
      _fetchUnreadNotifications();
    });
  }

  // Add this method to listen for notification changes
  void _listenForNotificationChanges() {
    final userSession = UserSession.instance;
    if (userSession.isLoggedIn) {
      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId > 0) {
        // Listen for real-time notification count updates
        _notificationSubscription = NotificationService.streamUnreadCount(userId).listen((count) {
          if (mounted) {
            setState(() {
              _unreadNotifications = count;
            });
          }
        });
      }
    }
  }

  void _initHealthTrackingRealtime() {
    Future.microtask(() async {
      try {
        await WebSocketService.instance.initialize();
        final uid = int.tryParse(UserSession.instance.userId) ?? 0;
        if (uid > 0) {
          WebSocketService.instance.joinUserRoom(uid);
        }
        WebSocketService.instance.addAppointmentUpdatedListener(_onAppointmentRealtime);
      } catch (e) {
        debugPrint('Health tracking realtime init: $e');
      }
    });
  }

  @override
  void dispose() {
    WebSocketService.instance.removeAppointmentUpdatedListener(_onAppointmentRealtime);
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _notificationSubscription?.cancel();
    _userSessionNotificationSubscription?.cancel();
    _activeChildSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchScheduleTracking();
    }
  }

  void _startAutoRefresh() {
    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchRealtimeData();
    });
  }

  Future<void> _initializeData() async {
    await _fetchRealtimeData();
    _initializeHealthTips();
  }

  void _initializeHealthTips() {
    final userSession = UserSession.instance;
    final serviceType = userSession.serviceType;
    
    List<Map<String, dynamic>> allTips;
    
    // Different health tips based on service type
    if (serviceType == 'maternal') {
      allTips = [
        {
          'icon': Icons.pregnant_woman,
          'title': 'Prenatal Vitamins',
          'description': 'Take your prenatal vitamins daily as prescribed by your doctor',
        },
        {
          'icon': Icons.restaurant,
          'title': 'Balanced Diet',
          'description': 'Eat foods rich in folic acid, iron, and calcium for healthy pregnancy',
        },
        {
          'icon': Icons.local_hospital,
          'title': 'Regular Checkups',
          'description': 'Attend all scheduled prenatal appointments for monitoring',
        },
        {
          'icon': Icons.directions_walk,
          'title': 'Light Exercise',
          'description': 'Take daily walks and practice prenatal yoga for better health',
        },
        {
          'icon': Icons.water_drop,
          'title': 'Stay Hydrated',
          'description': 'Drink 8-10 glasses of water daily for optimal health',
        },
        {
          'icon': Icons.bedtime,
          'title': 'Adequate Rest',
          'description': 'Get 7-9 hours of sleep and take naps when needed',
        },
        {
          'icon': Icons.monitor_weight,
          'title': 'Weight Management',
          'description': 'Monitor your weight gain according to your doctor\'s recommendations',
        },
        {
          'icon': Icons.self_improvement,
          'title': 'Stress Management',
          'description': 'Practice relaxation techniques to reduce stress during pregnancy',
        },
        {
          'icon': Icons.local_pharmacy,
          'title': 'Medication Safety',
          'description': 'Consult your doctor before taking any medications or supplements',
        },
        {
          'icon': Icons.warning,
          'title': 'Warning Signs',
          'description': 'Contact your doctor immediately if you experience any warning signs',
        },
      ];
    } else {
      // Default immunization tips
      allTips = [
        {
          'icon': Icons.water_drop,
          'title': 'Stay Hydrated',
          'description': 'Drink 8 glasses of water daily for optimal health',
        },
        {
          'icon': Icons.fitness_center,
          'title': 'Regular Exercise',
          'description': '30 minutes of daily exercise keeps your heart healthy',
        },
        {
          'icon': Icons.bedtime,
          'title': 'Healthy Sleep',
          'description': 'Get 7-9 hours of quality sleep every night',
        },
        {
          'icon': Icons.apple,
          'title': 'Eat More Fruits',
          'description': 'Include 5 servings of fruits and vegetables in your daily diet',
        },
        {
          'icon': Icons.directions_walk,
          'title': 'Take Regular Walks',
          'description': 'A 10-minute walk after meals helps with digestion and blood sugar',
        },
        {
          'icon': Icons.self_improvement,
          'title': 'Practice Mindfulness',
          'description': 'Take 5 minutes daily to breathe deeply and reduce stress',
        },
        {
          'icon': Icons.local_dining,
          'title': 'Portion Control',
          'description': 'Use smaller plates to help control portion sizes naturally',
        },
        {
          'icon': Icons.spa,
          'title': 'Stay Active',
          'description': 'Take the stairs instead of elevator when possible',
        },
        {
          'icon': Icons.wb_sunny,
          'title': 'Get Sunlight',
          'description': '15 minutes of morning sunlight helps vitamin D production',
        },
        {
          'icon': Icons.local_hospital,
          'title': 'Regular Checkups',
          'description': 'Schedule regular health checkups to prevent issues early',
        },
      ];
    }

    // Shuffle and select 3 random tips
    allTips.shuffle(_random);
    setState(() {
      _healthTips = allTips.take(3).toList();
    });
  }

  Future<void> _fetchRealtimeData() async {
    try {
      final userSession = UserSession.instance;
      final userId = userSession.userId;
      
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _healthTrackingLoadError = null;
      });
      return;
    }

      // Fetch unread notifications
      await _fetchUnreadNotifications();

      await _fetchScheduleTracking();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching realtime data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final userId = UserSession.instance.userId;
      if (userId.isEmpty) {
        debugPrint('No user ID found for notifications');
        setState(() {
          _unreadNotifications = 0;
        });
        return;
      }

      final unreadCount = await NotificationService.getUnreadNotificationsCount(int.parse(userId));
      setState(() {
        _unreadNotifications = unreadCount;
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      setState(() {
        _unreadNotifications = 0;
      });
    }
  }

  Future<void> _fetchScheduleTracking() async {
    final userId = UserSession.instance.userId;
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _scheduleAppointments = [];
          _loadingSchedules = false;
          _healthTrackingLoadError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingSchedules = true;
        _healthTrackingLoadError = null;
      });
    }

    try {
      final list = await AppointmentService.getUserAppointments(userId);
      if (!mounted) return;
      setState(() {
        _scheduleAppointments = list;
        _syncTrackingCategoryWithSchedules();
        _healthTrackingLoadError = null;
      });
    } catch (e) {
      debugPrint('Error fetching schedules for health tracking: $e');
      if (mounted) {
        setState(() {
          _scheduleAppointments = [];
          _healthTrackingLoadError =
              'Could not load appointments. Check your connection and try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health tracking could not be refreshed: $e',
              maxLines: 4,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingSchedules = false;
        });
      }
    }
  }

  void _syncTrackingCategoryWithSchedules() {
    final hasI = HealthTrackingService.hasImmunizationSchedules(_scheduleAppointments);
    final hasM = HealthTrackingService.hasMaternalSchedules(_scheduleAppointments);
    if (hasI && !hasM) {
      _trackingCategory = HealthScheduleCategory.immunization;
    } else if (hasM && !hasI) {
      _trackingCategory = HealthScheduleCategory.maternal;
    }
  }

  void _refreshHealthTips() {
    _initializeHealthTips();
  }

  @override
  Widget build(BuildContext context) {
    final userSession = UserSession.instance;
    final serviceType = userSession.serviceType;
    
    return RefreshIndicator(
      onRefresh: _fetchRealtimeData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
Container(
  width: double.infinity, 
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  padding: const EdgeInsets.symmetric(vertical: 24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: serviceType == 'maternal'
          ? [Colors.blueAccent.shade400, Colors.blue.shade200]
          : [Colors.blueAccent.shade400, Colors.blue.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: serviceType == 'maternal'
            ? Colors.blueAccent.withOpacity(0.3)
            : Colors.blueAccent.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center, 
    crossAxisAlignment: CrossAxisAlignment.center, 
    children: [
      Text(
        serviceType == 'maternal'
            ? "Welcome, ${userSession.fullName.isNotEmpty ? userSession.fullName : 'User'}!"
            : "Welcome, ${userSession.motherName.isNotEmpty ? userSession.motherName : userSession.fullName.isNotEmpty ? userSession.fullName : 'User'}!",
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      Text(
        serviceType == 'maternal'
            ? "Maternal Care Dashboard"
            : "Immunization Dashboard",
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  ),
),

const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              "Quick Actions",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(context, Icons.calendar_month, "Add Schedule", "Appointments"),
                _buildQuickAction(
                  context,
                  Icons.notifications_active,
                  "Notification",
                  "Notifications",
                  unreadCount: _unreadNotifications, 
                ),
                _buildQuickAction(context, Icons.health_and_safety, "Health Card", "HealthCard"),
              ],
            ),
          ],

          const SizedBox(height: 23),

          // Health Tracking Module
          _buildHealthTrackingModule(),

          const SizedBox(height: 28),

          // Vaccine Tracking — only for immunization service type
          if (UserSession.instance.serviceType != 'maternal') ...[
            // Show which child's data is being tracked when multiple children exist
            if (UserSession.instance.hasMultipleChildren) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Row(
                  children: [
                    Icon(Icons.child_care, size: 14, color: Colors.blueAccent.shade200),
                    const SizedBox(width: 4),
                    Text(
                      'Tracking: ${UserSession.instance.childName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueAccent.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const VaccineDashboardWidget(),
            const SizedBox(height: 28),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Health Tips",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),        
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _refreshHealthTips,
                tooltip: 'Get new health tips',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_healthTips.isEmpty) ...[
              _buildTip(Icons.info, "Loading Tips", "Health tips will appear here soon.."),
            ] else ...[
              for (final tip in _healthTips)
                _buildTip(tip['icon'], tip['title'], tip['description']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label,
    String action, {int unreadCount = 0}) {
  final screenWidth = MediaQuery.of(context).size.width;

  final buttonWidth = screenWidth / 4.2; 

  return InkWell(
    onTap: () {
      widget.onQuickActionSelected(action);
    },
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: buttonWidth,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, 
                color: UserSession.instance.serviceType == 'maternal' 
                  ? Colors.blueAccent 
                  : Colors.blueAccent, 
                size: 26), 
              if (unreadCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w600,
              overflow: TextOverflow.ellipsis,
            ),
            maxLines: 1,
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTip(IconData icon, String title, String description) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: UserSession.instance.serviceType == 'maternal'
            ? Colors.blueAccent.withOpacity(0.1)
            : Colors.blueAccent.withOpacity(0.1),
          child: Icon(icon, 
            color: UserSession.instance.serviceType == 'maternal'
              ? Colors.blueAccent
              : Colors.blueAccent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildHealthTrackingModule() {
    final allForCategory = HealthTrackingService.trackingEntriesForCategory(
      _scheduleAppointments,
      _trackingCategory,
    );
    final todayOnly = allForCategory
        .where(HealthTrackingService.isTrackingEntryOnLocalToday)
        .toList();
    final showToggle = HealthTrackingService.hasImmunizationSchedules(
          _scheduleAppointments,
        ) &&
        HealthTrackingService.hasMaternalSchedules(_scheduleAppointments);

    return HealthTrackingCard(
      appointments: todayOnly,
      categoryHasTrackedEntries: allForCategory.isNotEmpty,
      allRawAppointments: _scheduleAppointments,
      isLoading: _loadingSchedules,
      loadError: _healthTrackingLoadError,
      selectedCategory: _trackingCategory,
      showCategoryToggle: showToggle,
      onCategorySelected: (c) {
        setState(() => _trackingCategory = c);
      },
      onRetry: _fetchScheduleTracking,
    );
  }
}