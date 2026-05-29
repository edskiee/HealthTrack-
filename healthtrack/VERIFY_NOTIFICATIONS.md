# Notification System Verification Guide

This guide provides step-by-step instructions to verify that the push notification system is working correctly after the fixes.

## Prerequisites

1. A physical Android or iOS device (notifications may not work properly on emulators)
2. The HealthTrack app installed on the device
3. A valid FCM token from the device
4. Node.js installed on your development machine

## Testing Steps

### 1. Get FCM Token from Device

First, you need to obtain a valid FCM token from a device running the HealthTrack app:

1. Open the HealthTrack app on your device
2. Check the console logs for a line that looks like:
   ```
   ✅ FCM Token retrieved: abc123...
   ```
3. Copy the full token (not just the truncated part shown in the log)

### 2. Test Backend Notification Delivery

Run the test script with your FCM token:

```bash
cd backend_nodejs
node ../test_fcm_notifications.js YOUR_FULL_FCM_TOKEN_HERE
```

You should see output similar to:
```
🧪 Testing FCM Notification Delivery
===================================
📤 Sending test notification...
✅ Notification sent successfully!
   Message ID: projects/your-project-id/messages/0:1234567890123456
```

### 3. Verify Notification on Device

After running the test script:

1. Check if a notification banner appears on your device
2. Verify that the notification has:
   - A proper icon (bell icon)
   - Correct title ("Test Notification")
   - Correct body ("This is a test notification to verify banner delivery")
   - Proper coloring (blue accent color)

### 4. Test Different App States

Test notifications in all app states:

1. **Foreground state**: App is open and visible
2. **Background state**: App is running but not visible
3. **Terminated state**: App is completely closed

For each state:
1. Run the test script
2. Observe notification behavior
3. Tap on the notification to verify it opens the app correctly

### 5. Test Admin Notification Sending

Test sending notifications from the admin panel:

1. Log in to the admin dashboard
2. Navigate to the notifications section
3. Send a custom notification to a user
4. Verify the notification appears on the user's device

## Expected Results

After implementing the fixes, you should observe:

1. **Visible banner notifications** in all app states
2. **Proper notification icons and colors**
3. **Consistent sound and vibration** (based on device settings)
4. **Correct notification content** with title and body
5. **Proper logging** in the console for debugging

## Troubleshooting

If notifications are still not appearing:

1. **Check device settings**:
   - Ensure notifications are enabled for the app
   - Check that the app has permission to show notifications
   - Verify that Do Not Disturb mode is not blocking notifications

2. **Verify FCM token**:
   - Ensure the token is valid and not expired
   - Check that the token belongs to the correct app instance

3. **Check network connectivity**:
   - Ensure the device has internet access
   - Verify that Firebase services are reachable

4. **Review console logs**:
   - Look for any error messages in the Flutter console
   - Check backend logs for delivery failures

5. **Verify Firebase configuration**:
   - Ensure the google-services.json file is properly configured
   - Check that the Firebase project is set up correctly

## Additional Verification

### Check Database Integration

Verify that notifications are properly stored in the database:

1. Connect to the MySQL database
2. Run the query:
   ```sql
   SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
   ```
3. Confirm that new notifications appear in the table

### Test Error Handling

Test the system's error handling by providing invalid data:

1. Run the test script with an invalid FCM token
2. Verify that appropriate error messages are logged
3. Confirm that the system handles errors gracefully

## Conclusion

After following these verification steps, you should be confident that the push notification system is working correctly. The fixes implemented should ensure that:

- Banner notifications appear consistently across all device states
- Notifications are properly formatted with icons and colors
- Error handling is robust and informative
- The system integrates correctly with both the app and backend services