# HealthTrack Notification System Troubleshooting Guide

## Current Status Analysis

Based on our investigation, we've identified the core reasons why notifications aren't working:

1. **No Valid FCM Tokens**: Almost all users in the database lack FCM tokens
2. **Invalid Test Token**: The one user with a token has a fake/test token that won't work with Firebase
3. **Previous Validation Issues**: Token validation was too restrictive for real FCM tokens

## How the Notification System Works

1. **App Initialization**: When the app starts, FCM service requests permission and gets an FCM token
2. **Login Process**: After successful login, the app saves the FCM token to the server
3. **Notification Sending**: Admin sends notifications via `/admin/notifications/send` endpoint
4. **Delivery**: Server uses Firebase Admin SDK to send push notifications to device tokens
5. **Display**: Device receives notification and displays it as a banner/system notification

## Steps to Fix Notifications

### Step 1: Run the App on a Real Device or Proper Emulator

The app must be run on:
- A physical Android/iOS device with Google Play Services (Android) or APNs enabled (iOS)
- An Android emulator with Google APIs and Google Play Store
- An iOS simulator (limited functionality)

**Why**: Fake/test tokens are generated in development environments without proper Firebase setup.

### Step 2: Log in to Generate a Real FCM Token

1. Launch the HealthTrack app
2. Log in with any user account
3. Check the console logs for FCM token generation messages:
   ```
   🔔 Notification permission status: AuthorizationStatus.authorized
   ✅ FCM Token retrieved: xxxx...
   ✅ FCM token saved to server successfully after login
   ```

### Step 3: Verify Token Storage in Database

Run this command to check if a real FCM token was saved:
```bash
node check_user_token.js
```

Look for output like:
```
✅ User has a valid FCM token
Token Status: ✅ REAL TOKEN
```

Instead of:
```
❌ User does not have an FCM token
Token Status: ❌ FAKE/TEST TOKEN
```

### Step 4: Test Notification Sending

Once you have a user with a real FCM token:

1. Run the debug test:
   ```bash
   node notification_debug_test.js
   ```

2. You should see:
   ```
   🎯 Testing notification send to user with real token:
   📤 Sending notification...
   📊 Response status: 200
   ✅ Notification sent successfully!
   🎉 FCM delivery successful!
   ```

## Common Issues and Solutions

### Issue 1: "No users with real FCM tokens found!"
**Cause**: App hasn't been run on a device with proper Firebase setup
**Solution**: 
1. Install the app on a real device
2. Log in to generate and save a real FCM token
3. Verify with `node check_user_token.js`

### Issue 2: "FCM delivery failed: invalid-registration-token"
**Cause**: FCM token has expired or become invalid
**Solution**:
1. Have the user log out and log back in to generate a new token
2. Check that the device has internet connectivity
3. Verify Firebase configuration in the app

### Issue 3: "FCM delivery failed: authentication-error"
**Cause**: Backend Firebase service account credentials are invalid
**Solution**:
1. Verify `healthtrack-d20c2-4ada6cfc53f1.json` file exists in backend directory
2. Check that the service account has Firebase Cloud Messaging API enabled
3. Ensure the file has proper read permissions

## Testing Different Scenarios

### Scenario 1: New User Registration
1. Register a new user in the app
2. Log in with the new user
3. Verify FCM token is saved in database
4. Send test notification to the user

### Scenario 2: Existing User Login
1. Log in with an existing user who has no FCM token
2. Verify FCM token is saved in database
3. Send test notification to the user

### Scenario 3: Token Refresh
1. Force close and reopen the app multiple times
2. Check logs for token refresh events:
   ```
   🔄 FCM Token refreshed: xxxx...
   ✅ FCM token saved to server successfully
   ```

## Backend Configuration Verification

Ensure these files are properly configured:

1. **Firebase Service Account**: `backend_nodejs/healthtrack-d20c2-4ada6cfc53f1.json`
2. **Database Connection**: Check `backend_nodejs/src/config/db.js` credentials
3. **Server Port**: Ensure backend is running on port 3000

## Frontend Configuration Verification

Check these configuration files:

1. **API Configuration**: `lib/services/api_config.dart`
2. **Firebase Configuration**: `lib/services/fcm_service.dart`
3. **Android Manifest**: `android/app/src/main/AndroidManifest.xml`

## Diagnostic Scripts

Use these scripts to troubleshoot:

1. **Check User Tokens**: `node check_user_token.js`
2. **Check All Tokens**: `node check_all_tokens.js`
3. **Simple Notification Test**: `node simple_notification_test.js`
4. **Comprehensive Debug**: `node notification_debug_test.js`

## Expected Behavior After Fix

Once properly configured:

1. App generates real FCM tokens on device login
2. Tokens are saved to the database
3. Admin notifications are successfully sent to Firebase
4. Devices receive and display notification banners
5. Local notifications appear even when app is in foreground

## Additional Notes

- FCM tokens are automatically refreshed by Firebase and the app handles this
- Tokens are validated before sending to prevent errors
- Invalid tokens are automatically cleared from the database
- Both notification and data payloads are sent for maximum compatibility