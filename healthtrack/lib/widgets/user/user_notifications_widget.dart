import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/user_notification_service.dart';

class UserNotificationsWidget extends StatefulWidget {
  final int userId;
  final VoidCallback? onRefresh;
  
  const UserNotificationsWidget({
    super.key,
    required this.userId,
    this.onRefresh,
  });

  @override
  State<UserNotificationsWidget> createState() => _UserNotificationsWidgetState();
}

class _UserNotificationsWidgetState extends State<UserNotificationsWidget> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String? error;
  Timer? _refreshTimer;
  StreamSubscription? _notificationStream;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _startAutoRefresh();
    _startNotificationStream();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationStream?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  void _startNotificationStream() {
    _notificationStream = UserNotificationService.streamUserNotifications(widget.userId).listen(
      (newNotifications) {
        if (mounted) {
          setState(() {
            notifications = newNotifications;
            isLoading = false;
          });
        }
      },
      onError: (error) {
        // Handle notification stream error
        if (mounted) {
          setState(() {
            isLoading = false;
            this.error = 'Failed to load notifications';
          });
        }
      },
    );
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final newNotifications = await UserNotificationService.getUserNotifications(widget.userId);
      
      if (mounted) {
        setState(() {
          notifications = newNotifications;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load notifications: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int notificationId) async {
    try {
      await UserNotificationService.markNotificationAsRead(notificationId);
      
      if (mounted) {
        setState(() {
          final notification = notifications.firstWhere((n) => n['id'] == notificationId);
          if (notification.containsKey('is_read')) {
            notification['is_read'] = 1;
          }
        });
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await UserNotificationService.markAllNotificationsAsRead(widget.userId);
      
      if (mounted) {
        setState(() {
          for (var notification in notifications) {
            if (notification.containsKey('is_read')) {
              notification['is_read'] = 1;
            }
          }
        });
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(int notificationId) async {
    try {
      await UserNotificationService.deleteNotification(notificationId);
      
      if (mounted) {
        setState(() {
          notifications.removeWhere((n) => n['id'] == notificationId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'status_update':
        return Icons.update;
      case 'reminder':
        return Icons.notifications;
      case 'new_appointment':
        return Icons.calendar_today;
      default:
        return Icons.info;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'status_update':
        return Colors.blue;
      case 'reminder':
        return Colors.orange;
      case 'new_appointment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final unreadCount = notifications.where((n) => n['is_read'] == 0).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications (${notifications.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (unreadCount > 0)
                ElevatedButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text('Mark all read ($unreadCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        if (notifications.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No notifications yet'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = notification['is_read'] == 0;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: isUnread ? 4 : 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getNotificationColor(notification['notification_type']),
                      child: Icon(
                        _getNotificationIcon(notification['notification_type']),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notification['message'] ?? 'No message',
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      _formatDateTime(notification['created_at']),
                      style: TextStyle(
                        color: isUnread ? Colors.blue : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (isUnread) const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _deleteNotification(notification['id']),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    onTap: isUnread ? () => _markAsRead(notification['id']) : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}