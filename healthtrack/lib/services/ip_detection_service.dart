import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IpDetectionService {
  // Common IP patterns to try
  static final List<String> commonIpPatterns = [
    '192.168.1',    // Most common router default
    '192.168.0',    // Alternative common router default
    '192.168.254',  // Your current network
    '10.0.0',       // Class A private network
    '172.16',       // Class B private network
  ];

  // Common ports to try
  static final List<int> commonPorts = [3000, 8080, 8000];

  /// Detect the correct server IP and port
  static Future<String?> detectServerUrl() async {
    // First, try the localtunnel URL if available
    try {
      final response = await http.get(
        Uri.parse('https://swift-jobs-sneeze.loca.lt'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return 'https://swift-jobs-sneeze.loca.lt';
      }
    } catch (e) {
      print('LocalTunnel not accessible: $e');
    }

    // Get device's network interfaces
    final interfaces = await NetworkInterface.list();
    
    // Try to find the WiFi interface and test common IP patterns
    for (final interface in interfaces) {
      // Look for WiFi interfaces (common names)
      if (interface.name.toLowerCase().contains('wi') || 
          interface.name.toLowerCase().contains('wlan') ||
          interface.name.toLowerCase().contains('eth')) {
        
        for (final address in interface.addresses) {
          // Only consider IPv4 addresses
          if (address.type == InternetAddressType.IPv4) {
            final baseIp = address.address.split('.').sublist(0, 3).join('.');
            
            // Try common IP patterns with this base
            for (final pattern in commonIpPatterns) {
              // Try the pattern itself
              final testIp = pattern.contains('.') 
                ? pattern 
                : '$baseIp.${pattern.split('.').last}';
              
              for (final port in commonPorts) {
                final url = 'http://$testIp:$port';
                try {
                  print('Testing URL: $url');
                  final response = await http.get(
                    Uri.parse('$url/auth/check-username?username=test'),
                    headers: {'Content-Type': 'application/json'},
                  ).timeout(const Duration(seconds: 3));
                  
                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    // If we get a valid response from our auth endpoint
                    if (data is Map && data.containsKey('success')) {
                      print('Found server at: $url');
                      return url;
                    }
                  }
                } catch (e) {
                  print('Failed to connect to $url: $e');
                  continue;
                }
              }
            }
          }
        }
      }
    }

    // If we can't detect automatically, return null
    return null;
  }

  /// Get a list of potential server URLs to try
  static List<String> getPotentialServerUrls() {
    final urls = <String>[];
    
    // Add common local IP patterns
    for (final pattern in commonIpPatterns) {
      for (final port in commonPorts) {
        urls.add('http://$pattern.100:$port');
        urls.add('http://$pattern.101:$port');
        urls.add('http://$pattern.106:$port'); // Your current IP ends in 106
      }
    }
    
    // Add localhost variants
    for (final port in commonPorts) {
      urls.add('http://localhost:$port');
      urls.add('http://127.0.0.1:$port');
      urls.add('http://10.0.2.2:$port'); // Android emulator
    }
    
    return urls;
  }
}