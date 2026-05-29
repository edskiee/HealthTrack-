import 'dart:io';
import 'dynamic_api_config.dart';

class IpInitializer {
  /// Initialize and detect the local IP address
  static Future<void> initialize() async {
    try {
      // Get current local IP address
      final detectedIp = await _detectLocalIpAddress();
      if (detectedIp != null) {
        // Update the API config with the detected IP
        await DynamicApiConfig.updateLocalIpAddress(detectedIp);
        print("✅ IP address initialized: $detectedIp");
      } else {
        print("⚠️ Could not detect local IP address, using default");
      }
    } catch (e) {
      print("❌ Error initializing IP address: $e");
    }
  }

  /// Detect the local IP address
  static Future<String?> _detectLocalIpAddress() async {
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