# HealthTrack Automated Reminder Notification System

## Overview

This comprehensive automated reminder notification system ensures users receive timely appointment reminders through Firebase Cloud Messaging (FCM) and local notifications. The system sends reminders **3 days before** scheduled appointments at **6:00 AM, 12:00 PM, and 6:00 PM**.

## Key Features

### ✅ Implemented Features

1. **Automated Scheduling**: Creates reminder schedules when appointments are approved
2. **Multiple Daily Reminders**: 3 reminders per day at specified times (6AM, 12PM, 6PM)
3. **FCM Integration**: Uses Firebase Cloud Messaging for push notifications
4. **Local Notifications**: Fallback local notifications for reliability
5. **Timezone Support**: Handles user timezone preferences
6. **Duplicate Prevention**: Prevents duplicate notifications through caching
7. **Error Handling**: Comprehensive error handling and logging
8. **Scalable Architecture**: Supports multiple users simultaneously
9. **Real-time Updates**: Works in foreground, background, and terminated app states
10. **Database Tracking**: Complete notification history and scheduling

## System Architecture

### Backend Components

1. **appointmentReminderService.js**: Core reminder scheduling and sending logic
2. **notificationScheduler.js**: Cron-based scheduler for automated checking
3. **firebaseService.js**: Enhanced FCM token validation and message sending
4. **Database Tables**: `appointment_reminders` and `notification_history`

### Frontend Components

1. **enhanced_notification_service_fixed.dart**: Flutter notification service
2. **FCM Integration**: Firebase messaging for push notifications
3. **Local Notifications**: Flutter local notifications plugin
4. **Permission Handling**: Android/iOS notification permissions

## Database Schema

### appointment_reminders Table
```sql
CREATE TABLE appointment_reminders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id INT NOT NULL,
    user_id INT NOT NULL,
    reminder_date DATE NOT NULL,
    reminder_time TIME NOT NULL,
    scheduled_datetime DATETIME NOT NULL,
    days_before INT NOT NULL,
    reminder_type VARCHAR(50) NOT NULL,
    status ENUM('scheduled', 'sent', 'failed', 'cancelled') DEFAULT 'scheduled',
    sent_at TIMESTAMP NULL,
    error_message TEXT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### notification_history Table
```sql
CREATE TABLE notification_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    payload JSON,
    status ENUM('sent', 'failed') NOT NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Configuration

### System Settings
- `appointment_reminders_enabled`: Enable/disable reminders
- `reminder_days_before`: Days before appointment (default: [3])
- `reminders_per_day`: Number of reminders per day (default: 3)
- `reminder_times`: Daily reminder times (default: ["06:00", "12:00", "18:00"])

### Notification Channels
- **Appointment Reminders**: High priority, blue LED, custom vibration
- **General Notifications**: Default priority, green LED
- **Urgent Notifications**: High priority, red LED, urgent vibration

## Installation & Setup

### 1. Database Migration
```bash
mysql -u username -p healthtrack < database/migrate_reminder_system.sql
```

### 2. Backend Dependencies
```bash
cd backend_nodejs
npm install node-cron
```

### 3. Frontend Dependencies
Ensure your `pubspec.yaml` includes:
```yaml
dependencies:
  flutter_local_notifications: ^19.5.0
  firebase_messaging: ^15.0.1
  firebase_core: ^3.4.0
  flutter_timezone: ^5.0.2
  timezone: ^0.10.1
```

### 4. Firebase Setup
1. Configure Firebase project with FCM
2. Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
3. Update service account credentials in backend

## Usage

### Backend Testing
```bash
cd backend_nodejs
node test_reminder_system.js
```

### Frontend Integration
```dart
import 'package:healthtrack/lib/services/enhanced_notification_service_fixed.dart';

// Initialize notification service
final notificationService = EnhancedNotificationService();
await notificationService.initialize();

// Listen for notifications
notificationService.messageStream.listen((message) {
  // Handle incoming messages
});

notificationService.notificationStream.listen((response) {
  // Handle notification taps
});
```

## Notification Flow

1. **Appointment Creation**: When appointment is approved → Create reminder schedule
2. **Scheduler Check**: Every minute → Check for due reminders
3. **Reminder Sending**: Send FCM + local notification
4. **Status Update**: Mark reminder as sent/failed
5. **History Logging**: Log to notification_history table

## Error Handling & Reliability

### Duplicate Prevention
- In-memory caching of recently processed reminders
- Database unique constraints on reminder scheduling
- Automatic cleanup of invalid FCM tokens

### Fallback Mechanisms
- Local notifications if FCM fails
- Test mode for development without real FCM
- Graceful degradation when services unavailable

### Monitoring & Logging
- Comprehensive error logging
- Notification history tracking
- System health monitoring

## Timezone Handling

- User timezone preferences stored in database
- Automatic timezone detection on app launch
- UTC fallback for invalid timezones
- Proper scheduling across timezone changes

## Security Considerations

- FCM token validation before storage
- Test mode to prevent accidental production notifications
- Input validation on all notification parameters
- Rate limiting to prevent spam

## Performance Optimization

- Database indexes for efficient querying
- In-memory caching for duplicate prevention
- Batch processing for multiple reminders
- Automatic cleanup of old records

## Troubleshooting

### Common Issues

1. **Notifications Not Received**
   - Check FCM token validity
   - Verify notification permissions
   - Review Firebase project settings

2. **Duplicate Notifications**
   - Check reminder cache status
   - Verify database constraints
   - Review scheduler configuration

3. **Timezone Issues**
   - Verify user timezone settings
   - Check system timezone configuration
   - Review appointment scheduling logic

### Debug Commands
```bash
# Check scheduler status
curl http://localhost:3000/health

# Manual reminder check
cd backend_nodejs && node -e "require('./src/services/notificationScheduler').manualReminderCheck()"

# View pending reminders
mysql -u username -p -e "SELECT * FROM appointment_reminders WHERE status = 'scheduled';" healthtrack
```

## Best Practices

1. **Testing**: Always test with the provided test script
2. **Monitoring**: Regularly check notification history and error logs
3. **Maintenance**: Run cleanup scripts periodically
4. **Updates**: Test system updates in staging first
5. **Backup**: Regular database backups before changes

## Future Enhancements

- Custom reminder schedules per user
- SMS fallback for critical notifications
- Email notification integration
- Advanced analytics and reporting
- User preference management UI
- Multi-language support

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review the test script output
3. Check database logs
4. Verify Firebase console configuration

---

**System Status**: ✅ Fully Implemented and Tested
**Last Updated**: 2026-04-27
**Version**: 1.0.0
