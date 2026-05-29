# API Connectivity Troubleshooting Guide

## Issue: "Failed to generate slots: Network error connecting to http://192.168.137.1:3000"

### ✅ **SOLUTION IMPLEMENTED**

I have fixed the connectivity issue by:

1. **Updated API Configuration** - The app now tries multiple IP addresses in order:
   - `http://localhost:3000` (Primary - should work)
   - `http://127.0.0.1:3000` (Alternative localhost)
   - `http://10.243.17.91:3000` (Your ZeroTier IP)
   - `http://192.168.254.113:3000` (Your WiFi IP)
   - `http://192.168.137.1:3000` (Previously failing IP)

2. **Enhanced Error Handling** - Added detailed logging and user-friendly error messages

3. **Automatic Fallback** - App will try each URL until one works

### 🔧 **HOW TO VERIFY THE FIX**

1. **Start the Backend Server** (if not running):
   ```bash
   cd c:\CapstoneSystemProject\healthtrack\backend_nodejs
   node src/server.js
   ```

2. **Test Connectivity**:
   ```bash
   cd c:\CapstoneSystemProject\healthtrack
   node test_api_connectivity.js
   ```

3. **Restart the Flutter App** and try generating slots again

### 🚀 **EXPECTED BEHAVIOR**

- The app should now connect successfully on the first attempt (localhost:3000)
- You'll see detailed logging in the console showing which URL worked
- Slot generation should work without network errors

### 🐛 **IF ISSUES PERSIST**

1. **Check Server Status**:
   - Make sure the backend server is running on port 3000
   - Look for "HealthTrack API is running" message

2. **Check Firewall**:
   - Windows Firewall might block port 3000
   - Allow Node.js/JavaScript through firewall

3. **Check Port Conflicts**:
   - If port 3000 is busy, kill the process:
   ```bash
   taskkill /f /im node.exe
   ```

4. **Manual IP Override** (if needed):
   - Edit `lib/env_config.dart`
   - Change the first URL in `getFallbackUrls()` to your preferred IP

### 📱 **FOR MOBILE DEVICES**

If testing on mobile:
- Use your machine's IP: `http://192.168.254.113:3000`
- Ensure device and server are on same WiFi network
- Check mobile device firewall settings

### 🎯 **QUICK TEST**

Run this command to verify server is accessible:
```bash
curl http://localhost:3000/
```

Should return: `{"success":true,"message":"HealthTrack API is running"}`

---

**The fix is now implemented!** The app will automatically try working IP addresses and provide detailed error messages if connectivity issues persist.
