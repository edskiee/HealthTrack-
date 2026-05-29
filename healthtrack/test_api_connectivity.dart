import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// Test script to verify API connectivity
class ApiConnectivityTest {
  static Future<void> testConnectivity() async {
    print('Testing API connectivity...');
    
    // Test each fallback URL
    const List<String> fallbackUrls = [
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000',
      'http://10.243.17.91:3000',
      'http://192.168.1.66:3000',
      'http://192.168.137.1:3000',
    ];
    
    for (String url in fallbackUrls) {
      print('Testing $url...');
      try {
        final response = await http.get(
          Uri.parse('$url/'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            print('✅ SUCCESS: $url is accessible');
            print('   Response: ${data['message']}');
            break; // Stop at first successful connection
          } else {
            print('❌ FAILED: $url returned data but success=false');
          }
        } else {
          print('❌ FAILED: $url returned status ${response.statusCode}');
        }
      } catch (e) {
        print('❌ ERROR: $url - $e');
      }
    }
  }
  
  static Future<void> testAppointmentSlotsEndpoint() async {
    print('\nTesting appointment slots endpoint...');
    
    const List<String> fallbackUrls = [
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      'http://10.0.2.2:3000',
      'http://10.243.17.91:3000',
      'http://192.168.1.66:3000',
      'http://192.168.137.1:3000',
    ];
    
    for (String url in fallbackUrls) {
      print('Testing $url/appointment-slots endpoint...');
      try {
        final response = await http.get(
          Uri.parse('$url/appointment-slots'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ SUCCESS: $url/appointment-slots is accessible');
          break; // Stop at first successful connection
        } else {
          print('❌ FAILED: $url/appointment-slots returned status ${response.statusCode}');
        }
      } catch (e) {
        print('❌ ERROR: $url/appointment-slots - $e');
      }
    }
  }
}

void main() async {
  print('API Connectivity Test for HealthTrack');
  print('=====================================');
  
  await ApiConnectivityTest.testConnectivity();
  await ApiConnectivityTest.testAppointmentSlotsEndpoint();
  
  print('\nTest completed.');
}