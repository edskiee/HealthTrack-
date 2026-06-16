import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/notification_service.dart';
import 'services/user_session.dart';
import 'services/websocket_service.dart';
import 'utils/time_utils.dart';

class NotificationsTab extends StatefulWidget {
  final void Function(String) onNotificationTap;

  const NotificationsTab({super.key, required this.onNotificationTap});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late WebSocketService _webSocketService;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  late void Function(Map<String, dynamic>) _onAppointmentSocketRefresh;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _webSocketService = WebSocketService.instance;
    _onAppointmentSocketRefresh = (_) {
      if (mounted) _loadNotifications();
    };

    // Initialize services first
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize notification service
      await NotificationService.initialize();
      
      // Initialize WebSocket connection
      await _initializeWebSocket();
      
      // Load initial notifications after services are ready
      await _loadNotifications();

      // Mark all as read immediately after first load, before starting the stream
      await _markAllAsRead();

      // Now start the polling stream — read state is already persisted on server
      _listenForRealTimeNotifications();
      
      // Listen for unread count changes to keep UI in sync
      _listenForUnreadCountChanges();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize services. Please try again.';
      });
    }
  }

  // Add this method to listen for real-time notification updates
  void _listenForRealTimeNotifications() {
    final userSession = UserSession.instance;
    if (userSession.isLoggedIn) {
      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId > 0) {
        _notificationsSubscription = NotificationService.streamUserNotifications(userId).listen((newNotifications) {
          if (!mounted) return;
          setState(() {
            // Merge server data with local read state.
            // If we already have a notification marked as read locally, keep it read
            // even if the server hasn't caught up yet.
            final localReadIds = <String>{};
            for (final n in notifications) {
              if (n['isRead'] == true) {
                localReadIds.add(n['id']?.toString() ?? '');
              }
            }
            notifications = newNotifications.map((n) {
              final idStr = n['id']?.toString() ?? '';
              final serverRead = n['is_read'] == 1 || n['is_read'] == true;
              final localRead = localReadIds.contains(idStr);
              final nType = n["notification_type"]?.toString();
              final apiTitle = n["title"]?.toString().trim();
              final resolvedTitle = (apiTitle != null && apiTitle.isNotEmpty)
                  ? apiTitle
                  : _getNotificationTitle(nType);
              return {
                "type": _getNotificationType(nType),
                "title": resolvedTitle,
                "message": n["message"],
                "time": TimeUtils.formatRelativeTimeString(n["created_at"]),
                "created_at": n["created_at"],
                "icon": _getNotificationIcon(nType),
                "color": _getNotificationColor(nType),
                "isRead": serverRead || localRead,
                "id": n["id"],
              };
            }).toList()
              ..sort((a, b) =>
                  (b["created_at"]?.toString() ?? '')
                      .compareTo(a["created_at"]?.toString() ?? ''));
          });
        });
      }
    }
  }

  // Add this method to listen for unread count changes
  void _listenForUnreadCountChanges() {
    final userSession = UserSession.instance;
    if (userSession.isLoggedIn) {
      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId > 0) {
        // Listen for unread count changes — update badge only, don't reload
        _unreadCountSubscription = NotificationService.streamUnreadCount(userId).listen((count) {
          if (mounted) {
            setState(() {
              // Badge updates automatically via unreadCount getter over the
              // already-loaded notifications list; no full reload needed.
            });
          }
        });
      }
    }
  }

  Future<void> _initializeWebSocket() async {
    try {
      // Initialize WebSocket service
      await _webSocketService.initialize();
      
      // Use the multi-listener API so we don't clobber other screens' callbacks
      _webSocketService.addAppointmentNotificationListener(_handleRealTimeNotification);
      _webSocketService.addAppointmentUpdatedListener(_onAppointmentSocketRefresh);

      // Join user room if logged in
      final userSession = UserSession.instance;
      if (userSession.isLoggedIn) {
        final userId = int.tryParse(userSession.userId) ?? 0;
        if (userId > 0) {
          _webSocketService.joinUserRoom(userId);
        }
      }
    } catch (e) {
      print('❌ Error initializing WebSocket: $e');
    }
  }

  void _handleRealTimeNotification(Map<String, dynamic> notificationData) {
    try {
      final rawId = notificationData['id'];
      if (rawId == null) {
        _loadNotifications();
        return;
      }

      final nType = notificationData['notification_type']?.toString();
      final serverTitle = notificationData['title']?.toString().trim();
      final resolvedTitle = (serverTitle != null && serverTitle.isNotEmpty)
          ? serverTitle
          : _getNotificationTitle(nType);

      final formattedNotification = {
        "type": _getNotificationType(nType),
        "title": resolvedTitle,
        "message": notificationData["message"],
        "time": TimeUtils.formatRelativeTimeString(notificationData["created_at"]),
        "created_at": notificationData["created_at"],
        "icon": _getNotificationIcon(nType),
        "color": _getNotificationColor(nType),
        "isRead": notificationData["is_read"] == true ||
            notificationData["is_read"] == 1,
        "id": rawId,
      };

      // Add to the notifications list and re-sort
      setState(() {
        final idStr = rawId.toString();
        notifications.removeWhere((n) => n['id']?.toString() == idStr);
        notifications.add(formattedNotification);
        notifications.sort((a, b) {
          final as = a['created_at']?.toString() ?? '';
          final bs = b['created_at']?.toString() ?? '';
          return bs.compareTo(as);
        });
      });
      
      // Show in-app notification banner
      _showNotificationBanner(formattedNotification);
      
      // Notify any listeners about the change in unread count
      UserSession.instance.notifyNotificationCountChanged();
    } catch (e) {
      print('❌ Error handling real-time notification: $e');
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        throw Exception("User not logged in");
      }

      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId <= 0) {
        throw Exception("Invalid user session. Please log in again.");
      }

      final appointmentNotifications = await NotificationService.getUserNotifications(userId);
      
      // Build a set of IDs already marked read locally before this refresh
      final localReadIds = <String>{};
      for (final n in notifications) {
        if (n['isRead'] == true) {
          localReadIds.add(n['id']?.toString() ?? '');
        }
      }

      // Sort by created_at descending (newest first)
      final sortedNotifications = List<Map<String, dynamic>>.from(appointmentNotifications)
        ..sort((a, b) => 
          (b["created_at"]?.toString() ?? '').compareTo(a["created_at"]?.toString() ?? ''));
      
      final formattedNotifications = sortedNotifications.map((notification) {
        final nType = notification["notification_type"]?.toString();
        final apiTitle = notification["title"]?.toString().trim();
        final resolvedTitle = (apiTitle != null && apiTitle.isNotEmpty)
            ? apiTitle
            : _getNotificationTitle(nType);
        final idStr = notification["id"]?.toString() ?? '';
        final serverRead = notification["is_read"] == 1 || notification["is_read"] == true;
        final localRead = localReadIds.contains(idStr);
        return {
          "type": _getNotificationType(notification["notification_type"]),
          "title": resolvedTitle,
          "message": notification["message"],
          "time": TimeUtils.formatRelativeTimeString(notification["created_at"]),
          "created_at": notification["created_at"],
          "icon": _getNotificationIcon(notification["notification_type"]),
          "color": _getNotificationColor(notification["notification_type"]),
          "isRead": serverRead || localRead,
          "id": notification["id"],
        };
      }).toList();

      if (mounted) {
        setState(() {
          notifications = formattedNotifications;
          _isLoading = false;
          _errorMessage = '';
        });
        
        // Update the notification count
        UserSession.instance.notifyNotificationCountChanged();
      }
    } catch (e) {
      String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());
      
      if (mounted) {
        setState(() {
          _errorMessage = userFriendlyMessage;
          _isLoading = false;
        });
      }
    }
  }

  // Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(String technicalError) {
    if (technicalError.contains('Unauthorized') ||
        technicalError.contains('401') ||
        technicalError.contains('session expired') ||
        technicalError.contains('Session expired') ||
        technicalError.contains('Invalid authentication')) {
      return 'Your session has expired. Please log out and log in again.';
    } else if (technicalError.contains('timed out') ||
        technicalError.contains('TimeoutException') ||
        technicalError.contains('starting up')) {
      return 'The server is taking too long to respond. It may be waking up — please retry in a moment.';
    } else if (technicalError.contains('Unable to connect to server') ||
        technicalError.contains('Connection refused') ||
        technicalError.contains('SocketException') ||
        technicalError.contains('Network is unreachable') ||
        technicalError.contains('Failed host lookup')) {
      return 'Unable to load notifications. Please check your internet connection.';
    } else if (technicalError.contains('User not logged in')) {
      return 'Please log in to view your notifications.';
    } else if (technicalError.contains('Server configuration error') ||
        technicalError.contains('500')) {
      return 'The server encountered a configuration issue. Please try again later.';
    } else if (technicalError.contains('Failed to fetch notifications') ||
        technicalError.contains('HTTP')) {
      return 'Unable to load notifications at this time. Please try again later.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _getNotificationType(String? notificationType) {
    switch (notificationType) {
      case 'new_appointment':
      case 'admin_appointment_notification':
      case 'appointment_reminder':
      case 'appointment_in_progress':
      case 'appointment_completed':
      case 'appointment_missed':
      case 'appointment_approved':
      case 'appointment_rescheduled':
      case 'appointment_confirmation':
        return 'Appointments';
      case 'appointment_update':
      case 'status_update':
        return 'Appointments';
      case 'medication_reminder':
      case 'follow_up_reminder':
      case 'reminder':
        return 'Reminders';
      case 'custom_message':
      case 'system':
      default:
        return 'System';
    }
  }

  String _getNotificationTitle(String? notificationType) {
    switch (notificationType) {
      case 'new_appointment':
        return 'New Appointment';
      case 'admin_appointment_notification':
        return 'New Appointment Request';
      case 'appointment_reminder':
        return 'Appointment Reminder';
      case 'appointment_in_progress':
        return 'Appointment In Progress';
      case 'appointment_completed':
        return 'Appointment Completed';
      case 'appointment_missed':
        return 'Appointment Missed';
      case 'appointment_approved':
        return 'Appointment Approved';
      case 'appointment_rescheduled':
        return 'Appointment Rescheduled';
      case 'appointment_confirmation':
        return 'Appointment Confirmed';
      case 'appointment_update':
        return 'Appointment Update';
      case 'status_update':
        return 'Appointment Status Update';
      case 'medication_reminder':
        return 'Medication Reminder';
      case 'follow_up_reminder':
        return 'Follow-up Reminder';
      case 'reminder':
        return 'Reminder';
      case 'custom_message':
        return 'Custom Message';
      case 'system':
        return 'System Notification';
      default:
        return 'Notification';
    }
  }

  IconData _getNotificationIcon(String? notificationType) {
    switch (notificationType) {
      case 'appointment_in_progress':
        return Icons.pending_actions_rounded;
      case 'appointment_completed':
        return Icons.check_circle_rounded;
      case 'appointment_missed':
        return Icons.cancel_rounded;
      case 'new_appointment':
      case 'admin_appointment_notification':
        return Icons.calendar_today;
      case 'appointment_reminder':
        return Icons.event;
      case 'appointment_approved':
      case 'appointment_confirmation':
        return Icons.event_available;
      case 'appointment_rescheduled':
        return Icons.edit_calendar;
      case 'appointment_update':
        return Icons.event_available;
      case 'status_update':
        return Icons.info;
      case 'medication_reminder':
        return Icons.local_pharmacy;
      case 'follow_up_reminder':
        return Icons.repeat;
      case 'reminder':
        return Icons.alarm;
      case 'custom_message':
        return Icons.message;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? notificationType) {
    switch (notificationType) {
      case 'appointment_in_progress':
        return const Color(0xFF2563EB);
      case 'appointment_completed':
        return Colors.green.shade700;
      case 'appointment_missed':
        return Colors.red.shade700;
      case 'new_appointment':
      case 'admin_appointment_notification':
        return Colors.blueAccent;
      case 'appointment_reminder':
        return Colors.lightBlue;
      case 'appointment_approved':
      case 'appointment_confirmation':
        return Colors.green;
      case 'appointment_rescheduled':
        return Colors.orange;
      case 'appointment_update':
        return Colors.green;
      case 'status_update':
        return Colors.orange;
      case 'medication_reminder':
        return Colors.purpleAccent;
      case 'follow_up_reminder':
        return Colors.deepPurple;
      case 'reminder':
        return Colors.orangeAccent;
      case 'custom_message':
        return Colors.teal;
      case 'system':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }



  // Show in-app notification banner
  void _showNotificationBanner(Map<String, dynamic> notification) {
    final title = notification["title"] as String? ?? "Notification";
    final message = notification["message"] as String? ?? "You have a new notification";
    final icon = notification["icon"] as IconData? ?? Icons.notifications;
    final color = notification["color"] as Color? ?? Colors.blueAccent;
    
    showOverlayNotification(
      (context) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(message),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              OverlaySupportEntry.of(context)!.dismiss();
              // Navigate to notifications tab when banner is tapped
              widget.onNotificationTap("notifications");
            },
          ),
        );
      },
      duration: const Duration(seconds: 5),
      position: NotificationPosition.top,
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(int.parse(notificationId));
      
      // Update local state immediately without full reload
      setState(() {
        final index = notifications.indexWhere((n) => n["id"].toString() == notificationId);
        if (index != -1) {
          notifications[index]["isRead"] = true;
        }
        
        // Re-sort the notifications to maintain proper order
        notifications.sort((a, b) => 
          (b["created_at"] as String).compareTo(a["created_at"] as String));
      });
      
      // Notify any listeners about the change in unread count
      UserSession.instance.notifyNotificationCountChanged();
    } catch (e) {
      // Silently fail - not critical
    }
  }
  
  Future<void> _markAllAsRead() async {
    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) return;
      
      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId <= 0) return;
      await NotificationService.markAllNotificationsAsRead(userId);
      
      // Update local state
      setState(() {
        for (var i = 0; i < notifications.length; i++) {
          notifications[i]["isRead"] = true;
        }
      });
      
      // Notify any listeners about the change in unread count
      UserSession.instance.notifyNotificationCountChanged();
    } catch (e) {
      // Silently fail - not critical
    }
  }

  int get unreadCount =>
      notifications.where((n) => !(n["isRead"] as bool? ?? false)).length;

  // Show detailed notification viewer dialog
  void _showNotificationViewer(BuildContext context, Map<String, dynamic> notification) {
    // Mark as read when opening the viewer
    if (!(notification["isRead"] as bool? ?? false) && notification["id"] != null) {
      _markAsRead(notification["id"].toString());
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                notification["icon"] as IconData? ?? Icons.notifications,
                color: notification["color"] as Color? ?? Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notification["title"] as String? ?? "Notification",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification["message"] as String? ?? "No message",
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      notification["time"] as String? ?? "Unknown time",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (notification.containsKey("type"))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.category, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "Category: ${notification["type"]}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (notification["isRead"] as bool? ?? false)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Read",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Unread",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _webSocketService.removeAppointmentNotificationListener(_handleRealTimeNotification);
    _webSocketService.removeAppointmentUpdatedListener(_onAppointmentSocketRefresh);

    // Leave user room when disposing
    final userSession = UserSession.instance;
    if (userSession.isLoggedIn) {
      final userId = int.tryParse(userSession.userId) ?? 0;
      if (userId > 0) {
        _webSocketService.leaveUserRoom(userId);
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔔 Header with unread badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$unreadCount unread",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadNotifications,
                  ),
                ],
              )
            ],
          ),
        ),

        if (_isLoading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage.isNotEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadNotifications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blueAccent,
            tabs: const [
              Tab(text: "All"),
              Tab(text: "Appointments"),
              Tab(text: "Reminders"),
              Tab(text: "System"),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(context, notifications),
                _buildList(context,
                    notifications.where((n) => n["type"] == "Appointments").toList()),
                _buildList(context,
                    notifications.where((n) => n["type"] == "Reminders").toList()),
                _buildList(context,
                    notifications.where((n) => n["type"] == "System").toList()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          "No notifications",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
        final item = items[index];
        // Fix the null safety issue by providing a default value
        final isRead = item["isRead"] as bool? ?? false;

        return GestureDetector(
          onTap: () {
            // Show detailed notification viewer (will mark as read)
            _showNotificationViewer(context, item);
          },
            child: Card(
            color: isRead ? null : Colors.blue.shade50.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (item["color"] as Color?)?.withOpacity(0.2) ?? Colors.grey.withOpacity(0.2),
                    child: Icon(
                      item["icon"] as IconData? ?? Icons.notifications,
                      color: item["color"] as Color? ?? Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item["title"] as String? ?? "Notification",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold, // 🔴 bold if unread
                                ),
                              ),
                            ),
                            if (!isRead)
                              const Icon(Icons.circle,
                                  color: Colors.red, size: 10), // 🔴 dot badge
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item["message"] as String? ?? "No message",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item["time"] as String? ?? "Unknown time",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}