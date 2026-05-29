# ZeroTier Setup Guide for HealthTrack Application

## Overview

This guide will help you set up ZeroTier to enable communication between your Flutter mobile app and Node.js backend server, even when they are on different physical networks.

## Prerequisites

1. ZeroTier installed on both your laptop (backend) and Android phone
2. Both devices joined to the same ZeroTier network
3. Backend server configured to bind to all interfaces (0.0.0.0)

## Step-by-Step Setup

### 1. Verify ZeroTier Installation

#### On Windows (Backend Laptop):
1. Open PowerShell as Administrator
2. Check if ZeroTier is installed:
   ```powershell
   zerotier-cli info
   ```
   If not installed, download from https://www.zerotier.com/download/

#### On Android (Mobile Device):
1. Download ZeroTier from Google Play Store
2. Open the app and verify installation

### 2. Create or Join a ZeroTier Network

#### If you don't have a network yet:
1. Go to https://my.zerotier.com
2. Sign up or log in
3. Click "Networks" then "Create a Network"
4. Note the 16-character Network ID

#### Join the network:
1. **On Windows:**
   ```powershell
   zerotier-cli join [NETWORK_ID]
   ```
   
2. **On Android:**
   - Open ZeroTier app
   - Tap the "+" button
   - Enter the Network ID
   - Tap "Join Network"

### 3. Authorize Devices on the Network

1. Go to https://my.zerotier.com
2. Click on your network
3. Find both devices in the "Members" section
4. Check the "Auth" box for each device to authorize them

### 4. Find ZeroTier IP Addresses

#### On Windows (Backend):
```powershell
ipconfig
```
Look for an interface with a name like "ZeroTier One" and note the IPv4 address (typically in 10.x.x.x range).

#### On Android:
1. Open the ZeroTier app
2. Tap on your network
3. Look for the "Managed IPs" section

### 5. Configure Your Application

#### Update API Configuration:
1. Open `lib/services/api_config.dart`
2. Replace `'10.x.x.x'` with your actual ZeroTier IP address:
   ```dart
   static const String _defaultLocalIp = 'YOUR_ZEROTIER_IP'; // e.g., '10.147.75.123'
   ```

#### Ensure Backend Server Binds to All Interfaces:
Your server.js already correctly binds to all interfaces:
```javascript
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running at http://0.0.0.0:${PORT}`);
});
```

### 6. Test the Connection

#### Start Your Backend Server:
```bash
cd backend_nodejs
node src/server.js
```

#### Test Connection from Mobile:
1. Ensure both devices are connected to the internet
2. Open your Flutter app
3. Try to access any feature that requires backend connectivity

### 7. Troubleshooting

#### Connection Issues:
1. Verify both devices show as "ONLINE" in the ZeroTier network
2. Ensure the backend server is running
3. Check that Windows Firewall allows connections on port 3000
4. Try pinging the ZeroTier IP from your mobile device using a network utility app

#### Firewall Configuration (Windows):
1. Open Windows Defender Firewall
2. Click "Advanced settings"
3. Click "Inbound Rules" then "New Rule"
4. Select "Port" and click "Next"
5. Select "TCP" and enter "3000" in specific local ports
6. Allow the connection and apply to all profiles
7. Name the rule "HealthTrack Backend" and finish

#### Testing with curl (Windows):
```powershell
curl http://[YOUR_ZEROTIER_IP]:3000/auth/check-username?username=test
```

### 8. Using Mobile Data

When using mobile data instead of Wi-Fi, your phone should still maintain the ZeroTier connection as long as:
1. The ZeroTier app is running in the background
2. Your phone has internet connectivity
3. Your laptop (backend) also has internet connectivity

The connection works because ZeroTier creates a virtual network layer that routes traffic through the internet, effectively making both devices appear to be on the same local network.

## Best Practices

1. **Keep ZeroTier Running**: Ensure the ZeroTier service is running on both devices
2. **Monitor Network Status**: Check that both devices show as "ONLINE" in the ZeroTier network
3. **Use Static IPs**: Consider setting static IPs in ZeroTier to avoid IP changes
4. **Security**: Only authorize trusted devices on your ZeroTier network

## Alternative Solutions

If ZeroTier doesn't work for your setup, consider these alternatives:

1. **LocalTunnel** (Recommended for development):
   ```bash
   npm install -g localtunnel
   lt --port 3000
   ```
   Then update `ngrokUrl` in your API config with the provided URL.

2. **Ngrok**:
   - Download from https://ngrok.com/download
   - Run: `ngrok http 3000`
   - Update `ngrokUrl` in your API config

3. **Port Forwarding**:
   - Configure your router to forward port 3000 to your laptop's local IP
   - Use your public IP address in the mobile app

## Support

If you continue to experience issues:
1. Verify network connectivity on both devices
2. Check ZeroTier network configuration
3. Ensure proper firewall settings
4. Confirm backend server is properly configured to accept external connections