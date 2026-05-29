import 'dart:io';
import 'package:healthtrack/services/dynamic_api_config.dart';

class IpUtils {
  /// Get all network interfaces and their IP addresses
  static Future<List<Map<String, dynamic>>> getNetworkInterfaces() async {
    final interfaces = await NetworkInterface.list();
    final List<Map<String, dynamic>> result = [];
    
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4) {
          result.add({
            'interface': interface.name,
            'ip': address.address,
            'isPrivate': _isPrivateNetwork(address.address),
          });
        }
      }
    }
    
    return result;
  }
  
  /// Check if an IP address is in a private network range
  static bool _isPrivateNetwork(String ip) {
    return ip.startsWith('192.168.') || 
           ip.startsWith('10.') || 
           (ip.startsWith('172.') && 
            int.parse(ip.split('.')[1]) >= 16 && 
            int.parse(ip.split('.')[1]) <= 31);
  }
  
  /// Automatically detect and update the local IP address
  static Future<String?> autoDetectAndUpdateIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      // Look for WiFi interfaces first
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wi') || 
            interface.name.toLowerCase().contains('wlan')) {
          
          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4 && 
                _isPrivateNetwork(address.address)) {
              await DynamicApiConfig.updateLocalIpAddress(address.address);
              return address.address;
            }
          }
        }
      }
      
      // If no WiFi interface found, try any private network interface
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              _isPrivateNetwork(address.address)) {
            await DynamicApiConfig.updateLocalIpAddress(address.address);
            return address.address;
          }
        }
      }
      
      return null;
    } catch (e) {
      print("Error detecting IP address: $e");
      return null;
    }
  }
  
  /// Manually set the IP address
  static Future<void> setIpAddress(String ipAddress) async {
    await DynamicApiConfig.updateLocalIpAddress(ipAddress);
  }
}