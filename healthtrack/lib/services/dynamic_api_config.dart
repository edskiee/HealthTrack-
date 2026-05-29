import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DynamicApiConfig {
  static const String _prefsKey = 'local_ip_address';
  static const String _defaultLocalIp = '10.243.17.91'; // Your ZeroTier IP address
  static const int port = 3000;
  
  // ✅ Localtunnel public URL
  // (Replace this link with your active localtunnel link each time you restart localtunnel)
  static const String ngrokUrl = "https://swift-jobs-sneeze.loca.lt";

  // ✅ Get the base URL with dynamic IP detection
  static Future<String> get baseUrl async {
    // Priority 1: Ngrok (for external and same WiFi access)
    if (ngrokUrl.isNotEmpty) {
      return ngrokUrl;
    }

    // Priority 2: Web platform
    if (kIsWeb) {
      return "http://localhost:$port";
    }

    // Priority 3: Mobile device with dynamic IP
    if (Platform.isAndroid || Platform.isIOS) {
      final ip = await _getStoredLocalIpAddress();
      return "http://$ip:$port";
    }

    // Priority 4: Desktop fallback
    return "http://localhost:$port";
  }

  // ✅ Get fallback URLs
  static Future<List<String>> get fallbackBaseUrls async {
    final ip = await _getStoredLocalIpAddress();
    return [
      ngrokUrl,                       // Ngrok public URL
      "http://$ip:$port",             // Dynamic local IP
      "http://192.168.1.100:$port",   // Common local IP pattern
      "http://192.168.0.100:$port",   // Alternative local IP pattern
      "http://10.0.2.2:$port",        // Android Emulator
      "http://localhost:$port",       // Localhost
      "http://127.0.0.1:$port",       // Alternative localhost
    ];
  }

  // ✅ Get stored local IP address or default
  static Future<String> _getStoredLocalIpAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefsKey) ?? _defaultLocalIp;
    } catch (e) {
      print("Failed to get stored IP address: $e");
      return _defaultLocalIp;
    }
  }

  // ✅ Update and store the local IP address
  static Future<void> updateLocalIpAddress(String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, ipAddress);
      print("Updated local IP address to: $ipAddress");
    } catch (e) {
      print("Failed to update local IP address: $e");
    }
  }

  // ✅ Detect local IP address automatically
  static Future<String?> detectLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        // Look for WiFi interfaces (common names)
        if (interface.name.toLowerCase().contains('wi') || 
            interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('eth')) {
          
          for (final address in interface.addresses) {
            // Only consider IPv4 addresses
            if (address.type == InternetAddressType.IPv4) {
              final ip = address.address;
              // Check if it's in a common private network range
              if (ip.startsWith('192.168.') || 
                  ip.startsWith('10.') || 
                  (ip.startsWith('172.') && 
                   int.parse(ip.split('.')[1]) >= 16 && 
                   int.parse(ip.split('.')[1]) <= 31)) {
                return ip;
              }
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print("Failed to detect local IP address: $e");
      return null;
    }
  }
}