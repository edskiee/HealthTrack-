# IP Configuration for HealthTrack Application

## Overview

This document explains how the HealthTrack application handles IP address configuration for connecting to the backend server without requiring a USB connection every time.

## How It Works

The application uses a multi-layered approach to connect to the backend server:

1. **Primary Connection**: Uses a public tunnel URL (localtunnel) for external access
2. **Local Network Connection**: Automatically detects and uses the local IP address
3. **Fallback URLs**: Tries multiple common IP patterns if the primary connection fails

## Automatic IP Detection

The application automatically detects your local IP address when it starts:

1. It scans all network interfaces on your device
2. Identifies WiFi interfaces (wi, wlan, eth)
3. Extracts IPv4 addresses in private network ranges (192.168.x.x, 10.x.x.x, 172.16.x.x - 172.31.x.x)
4. Stores the detected IP address for future use

## Manual IP Configuration

If automatic detection fails, you can manually update the IP address:

1. Open the app settings (to be implemented)
2. Enter your computer's IP address
3. Save the configuration

## Common IP Patterns

The application tries these common IP patterns if automatic detection fails:

- `192.168.1.100:3000`
- `192.168.0.100:3000`
- `192.168.254.106:3000` (your current IP)
- `10.0.2.2:3000` (Android emulator)
- `localhost:3000`
- `127.0.0.1:3000`

## Finding Your Computer's IP Address

### Windows:
1. Open Command Prompt
2. Run: `ipconfig`
3. Look for "Wireless LAN adapter" or "Ethernet adapter"
4. Find the IPv4 Address (e.g., 192.168.254.106)

### macOS:
1. Open Terminal
2. Run: `ifconfig`
3. Look for en0 or en1 interfaces
4. Find the inet address

### Linux:
1. Open Terminal
2. Run: `ifconfig` or `ip addr`
3. Look for wlan0 or eth0 interfaces
4. Find the inet address

## Testing the Connection

To test if the connection is working:

1. Ensure your backend server is running (`node backend_nodejs/src/server.js`)
2. Make sure both your computer and mobile device are on the same WiFi network
3. Open the HealthTrack app
4. Try to log in or register a new user

## Troubleshooting

### Connection Issues:
1. Verify both devices are on the same WiFi network
2. Check that the backend server is running on port 3000
3. Ensure Windows Firewall allows connections on port 3000
4. Try manually entering your computer's IP address

### IP Address Not Detected:
1. Check that WiFi is enabled on your mobile device
2. Verify that your computer and mobile device are on the same network
3. Manually enter your computer's IP address in the app settings

### Firewall Issues:
1. Open Windows Firewall settings
2. Allow Node.js or port 3000 through the firewall
3. Ensure private networks are allowed

## Using LocalTunnel (Recommended for Development)

For a more stable connection that works across different networks:

1. Install localtunnel globally: `npm install -g localtunnel`
2. Start your backend server: `node backend_nodejs/src/server.js`
3. Expose it with localtunnel: `lt --port 3000`
4. Copy the provided URL and update it in `lib/services/api_config.dart`

Example:
```bash
# Terminal 1 - Start backend server
cd backend_nodejs
node src/server.js

# Terminal 2 - Expose with localtunnel
lt --port 3000
# Output: your url is: https://random-subdomain.loca.lt
```

Update the `ngrokUrl` in `api_config.dart` with this URL.

## Using Ngrok (Alternative)

If you prefer to use Ngrok:

1. Install ngrok: https://ngrok.com/download
2. Start your backend server: `node backend_nodejs/src/server.js`
3. Expose it with ngrok: `ngrok http 3000`
4. Copy the HTTPS URL and update it in `lib/services/api_config.dart`