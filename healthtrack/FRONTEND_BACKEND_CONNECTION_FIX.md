# Frontend-Backend Connection Fix Guide

## Problem Analysis

You were experiencing a 404 error when trying to log in to the admin interface because your Flutter frontend was trying to connect to the backend using an incorrect IP address.

## Root Cause

The issue was a mismatch between:
1. **Server IP**: Your Node.js backend was running on `http://10.243.17.91:3000` (ZeroTier IP)
2. **Frontend Configuration**: Your Flutter app was configured to connect to `http://192.168.254.102:3000` (incorrect IP)

## Solution Implemented

I've updated the [lib/services/api_config.dart](file:///c%3A/CapstoneSystemProject/healthtrack/lib/services/api_config.dart) file to use the correct IP addresses:

### Primary URL (Updated)
- Changed from: `http://192.168.254.102:3000`
- Changed to: `http://10.243.17.91:3000` (ZeroTier IP)

### Fallback URLs (Updated)
- Added your actual Wi-Fi IP: `http://192.168.254.120:3000`
- Kept other common fallbacks for compatibility

## How to Verify the Fix

1. Make sure your backend server is running:
   ```bash
   cd backend_nodejs
   npm start
   ```

2. Run your Flutter admin app:
   ```bash
   flutter run -d chrome -t lib/admin/main.admin.dart
   ```

3. Try to log in with valid admin credentials.

## Additional Troubleshooting Steps

### 1. Check Your Current IP Addresses
Run this command to see your current IP addresses:
```bash
ipconfig
```

Look for:
- ZeroTier IP (usually starting with 10.x.x.x)
- Wi-Fi/LAN IP (usually starting with 192.168.x.x)

### 2. Update API Configuration If Needed
If your IP addresses change, update the [api_config.dart](file:///c%3A/CapstoneSystemProject/healthtrack/lib/services/api_config.dart) file:
- Change the `defaultBaseUrl` to match your current ZeroTier IP
- Update the first entry in `fallbackBaseUrls` to match your current Wi-Fi IP

### 3. Test Backend Endpoints Directly
You can test if your backend is working correctly using curl:
```bash
# Test the root endpoint
curl http://10.243.17.91:3000

# Test admin login (will return validation error without data)
curl -X POST http://10.243.17.91:3000/admin/login
```

### 4. Check Server Logs
When you try to log in from the Flutter app, check the Node.js server terminal for logs:
- Successful requests will show up in the console
- Errors will be logged with details

## Understanding the Connection Flow

1. **Flutter App** → Sends login request to configured API URL
2. **API Config** → Provides the base URL and endpoint path
3. **Combined URL** → http://10.243.17.91:3000/admin/login
4. **Node.js Server** → Receives request on port 3000
5. **Express Router** → Routes request to admin login handler
6. **Admin Controller** → Processes login logic
7. **MySQL Database** → Validates credentials
8. **Response** → Sent back to Flutter app

## Common Connection Issues and Solutions

### Issue: "Failed to connect to server"
**Solution**: 
1. Verify the backend server is running
2. Check that the IP address in [api_config.dart](file:///c%3A/CapstoneSystemProject/healthtrack/lib/services/api_config.dart) matches your current IP
3. Ensure both devices are on the same network (or using ZeroTier)

### Issue: "CORS error"
**Solution**: 
Already handled in your backend [server.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/server.js) with permissive CORS settings.

### Issue: "404 Not Found"
**Solution**: 
1. Verify you're using the correct endpoint path (`/admin/login`, not `/api/admin/login`)
2. Check that routes are properly mounted in [server.js](file:///c%3A/CapstoneSystemProject/healthtrack/backend_nodejs/src/server.js)

## Best Practices for Development

1. **Always start the backend first** before running the frontend
2. **Keep IP addresses updated** in [api_config.dart](file:///c%3A/CapstoneSystemProject/healthtrack/lib/services/api_config.dart) when they change
3. **Use ZeroTier IP** for consistent connectivity across different networks
4. **Test endpoints directly** with curl or Postman during development
5. **Monitor server logs** for debugging connection issues

## Testing Your Connection

You can test the connection using this simple curl command:
```bash
curl -X POST http://10.243.17.91:3000/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username": "test", "password": "test"}'
```

This should return:
```json
{
  "success": false,
  "message": "Invalid username or password"
}
```

This response indicates that the connection is working correctly, even though the credentials are invalid.

With these changes, your admin login should now work properly!