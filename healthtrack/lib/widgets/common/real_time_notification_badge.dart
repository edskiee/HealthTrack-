import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/user_notification_service.dart';
import '../../services/user_session.dart';

class RealTimeNotificationBadge extends StatefulWidget {
  final Stream<int> unreadCountStream;
  final Color badgeColor;
  final Color textColor;
  final double size;
  final bool showZero;
  
  const RealTimeNotificationBadge({
    super.key,
    required this.unreadCountStream,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.size = 20,
    this.showZero = false,
  });

  @override
  State<RealTimeNotificationBadge> createState() => _RealTimeNotificationBadgeState();
}

class _RealTimeNotificationBadgeState extends State<RealTimeNotificationBadge> {
  int _unreadCount = 0;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _streamSubscription = widget.unreadCountStream.listen(
      (count) {
        if (mounted) {
          setState(() {
            _unreadCount = count;
          });
        }
      },
      onError: (error) {
        // Handle notification stream error
      },
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unreadCount == 0 && !widget.showZero) {
      return const SizedBox.shrink();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.badgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _unreadCount > 99 ? '99+' : _unreadCount.toString(),
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// Admin notification badge widget
class AdminNotificationBadge extends StatefulWidget {
  final Color badgeColor;
  final Color textColor;
  final double size;
  
  const AdminNotificationBadge({
    super.key,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.size = 20,
  });

  @override
  State<AdminNotificationBadge> createState() => _AdminNotificationBadgeState();
}

class _AdminNotificationBadgeState extends State<AdminNotificationBadge>
    with WidgetsBindingObserver {
  final StreamController<int> _unreadCountController = StreamController<int>();
  Timer? _refreshTimer;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialCount();
    _subscribeToStream();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _unreadCountController.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadUnreadNotificationCount();
      _refreshTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        _loadUnreadNotificationCount();
      });
    }
  }

  void _subscribeToStream() {
    // Periodically refresh the unread notification count
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUnreadNotificationCount();
    });
  }

  Future<void> _loadInitialCount() async {
    try {
      // Load initial unread notification count
      await _loadUnreadNotificationCount();
    } catch (e) {
      // Handle error loading initial admin notification count
      _unreadCountController.add(0);
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      // Fetch user's unread notifications
      final unreadCount = await UserNotificationService.getUnreadNotificationsCount(int.tryParse(UserSession.instance.userId) ?? 0);
      
      if (mounted && unreadCount != _lastCount) {
        _lastCount = unreadCount;
        _unreadCountController.add(unreadCount);
      }
    } catch (e) {
      // Handle error loading notification count
      if (mounted) {
        _unreadCountController.add(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCountController.stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.badgeColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: widget.textColor,
                fontSize: widget.size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

// User notification badge widget
class UserNotificationBadge extends StatefulWidget {
  final int userId;
  final Color badgeColor;
  final Color textColor;
  final double size;
  
  const UserNotificationBadge({
    super.key,
    required this.userId,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.size = 20,
  });

  @override
  State<UserNotificationBadge> createState() => _UserNotificationBadgeState();
}

class _UserNotificationBadgeState extends State<UserNotificationBadge>
    with WidgetsBindingObserver {
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  Timer? _refreshTimer;
  late final StreamSubscription _sessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoRefresh();
    _loadInitialCount();
    
    // Listen for manual refresh triggers
    _sessionSubscription = UserNotificationService.streamUnreadCount(widget.userId).listen((count) {
      if (mounted) {
        _unreadCountController.add(count);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _sessionSubscription.cancel();
    _unreadCountController.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
      _refreshTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadCount());
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadInitialCount() async {
    try {
      final count = await UserNotificationService.getUnreadNotificationsCount(widget.userId);
      _unreadCountController.add(count);
    } catch (e) {
      // Handle error loading initial user notification count
      _unreadCountController.add(0);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await UserNotificationService.getUnreadNotificationsCount(widget.userId);
      _unreadCountController.add(count);
    } catch (e) {
      // Handle error loading user notification count
      _unreadCountController.add(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCountController.stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.badgeColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: widget.textColor,
                fontSize: widget.size * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}