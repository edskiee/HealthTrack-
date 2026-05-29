# Complete ZeroTier Connection Guide for HealthTrack

## Summary

This guide provides complete instructions to connect your Flutter mobile app to your Node.js backend through ZeroTier One, enabling communication even when devices are on different networks.

## Prerequisites Checklist

- [ ] ZeroTier installed on laptop (backend)
- [ ] ZeroTier installed on Android phone
- [ ] Both devices joined to the same ZeroTier network
- [ ] Both devices authorized on the network
- [ ] Backend server configured to bind to all interfaces

## Step 1: Find Your ZeroTier IP Addresses

### On Windows (Backend Laptop):
1. Open PowerShell
2. Run: `ipconfig`
3. Look for "ZeroTier One" adapter
4. Note the IPv4 Address (e.g., 10.147.75.123)

### On Android (Mobile Device):
1. Open ZeroTier app
2. Tap on your network
3. Note the "Managed IPs" address

## Step 2: Update Your Configuration Files

### Update API Configuration:
In `lib/services/api_config.dart`, replace `'10.x.x.x'` with your actual ZeroTier IP:
```dart
static const String _defaultLocalIp = 'YOUR_ZEROTIER_IP'; // e.g., '10.147.75.123'
```

### Update Dynamic API Configuration:
In `lib/services/dynamic_api_config.dart`, replace `'10.x.x.x'` with your actual ZeroTier IP:
```dart
static const String _defaultLocalIp = 'YOUR_ZEROTIER_IP'; // e.g., '10.147.75.123'
```

## Step 3: Configure Windows Firewall

1. Open Windows Defender Firewall
2. Click "Advanced settings"
3. Click "Inbound Rules" then "New Rule"
4. Select "Port" and click "Next"
5. Select "TCP" and enter "3000" in specific local ports
6. Allow the connection and apply to all profiles
7. Name the rule "HealthTrack Backend" and finish

## Step 4: Start Your Backend Server

In your project directory:
```bash
cd backend_nodejs
node src/server.js
```

You should see:
```
🚀 Server running at http://0.0.0.0:3000
```

## Step 5: Test the Connection

### Using PowerShell (on Windows):
```powershell
curl http://[YOUR_ZEROTIER_IP]:3000/
```

### Using the Test Script:
1. Update `test_zerotier_connection.js` with your ZeroTier IP
2. Run: `node test_zerotier_connection.js`

## Step 6: Run Your Flutter App

1. Make sure your Android phone is connected to the internet
2. Run your Flutter app
3. Try logging in or registering a new user

## Troubleshooting

### If Connection Fails:

1. **Verify ZeroTier Status:**
   - Both devices should show as "ONLINE" in the ZeroTier network
   - Both devices should be authorized (check box in network member list)

2. **Check Backend Server:**
   - Ensure it's running and shows "Server running at http://0.0.0.0:3000"
   - Verify it's not blocked by firewall

3. **Test Basic Connectivity:**
   - Try pinging your ZeroTier IP from the mobile device
   - Use a network utility app if needed

4. **Check IP Configuration:**
   - Double-check that you've updated the IP addresses in both config files
   - Ensure you're using the correct IP (from the laptop, not the phone)

### Common Issues and Solutions:

1. **"Connection Refused" Error:**
   - Windows Firewall is blocking the connection
   - Backend server is not running
   - Wrong IP address in configuration

2. **Timeout Errors:**
   - Devices not properly connected to ZeroTier network
   - One or both devices not authorized
   - Internet connectivity issues

3. **"Network Unreachable" Error:**
   - ZeroTier service not running on one device
   - Incorrect Network ID used when joining

## Using Mobile Data

Your connection will work on mobile data because:
- ZeroTier creates a virtual network layer
- Traffic is routed through the internet
- Both devices appear to be on the same local network

Requirements:
- ZeroTier app running in background on Android
- Both devices must maintain internet connectivity
- Backend laptop must also have internet access

## Alternative Solutions

If ZeroTier doesn't work for your setup:

### LocalTunnel (Recommended):
```bash
npm install -g localtunnel
lt --port 3000
```
Then update `ngrokUrl` in your API config with the provided URL.

### Ngrok:
1. Download from https://ngrok.com/download
2. Run: `ngrok http 3000`
3. Update `ngrokUrl` in your API config

## Security Considerations

1. Only authorize trusted devices on your ZeroTier network
2. Consider using a private ZeroTier network
3. When using public tunneling services (localtunnel, ngrok), be aware that URLs are publicly accessible
4. In production, implement proper authentication and encryption

## Support

If you continue to experience issues:
1. Verify network connectivity on both devices
2. Check ZeroTier network configuration at https://my.zerotier.com
3. Ensure proper firewall settings
4. Confirm backend server is properly configured to accept external connections