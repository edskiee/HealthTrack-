/**
 * Flutter ZeroTier Connection Test
 * 
 * This script helps verify that your Flutter app can connect to the backend
 * through ZeroTier.
 */

import 'package:http/http.dart' as http;

void main() async {
  // Configuration - Replace with your actual ZeroTier IP
  const String zeroTierIp = '10.243.17.91'; // e.g., '10.147.75.123'
  const int port = 3000;
  
  // print('🧪 Flutter ZeroTier Connection Test');
  // print('===================================');
  // print('Testing connection to: http://$zeroTierIp:$port');
  // print('');
  
  // Test endpoints
  final testEndpoints = [
    '/',
    '/auth/check-username?username=test',
    '/auth/check-email?email=test@example.com'
  ];
  
  // print('Running connection tests...\n');
  
  final results = <Map<String, dynamic>>[];
  
  for (final endpoint in testEndpoints) {
    try {
      final url = 'http://$zeroTierIp:$port$endpoint';
      // print('Testing: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      // print('✅ $endpoint - Status: ${response.statusCode}');
      results.add({
        'endpoint': endpoint,
        'success': true,
        'status': response.statusCode,
      });
    } catch (e) {
      // print('❌ $endpoint - Error: $e');
      results.add({
        'endpoint': endpoint,
        'success': false,
        'error': e.toString(),
      });
    }
    
    // Small delay between requests
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // print('\n📋 Test Results Summary:');
  // print('======================');
  
  final successful = results.where((r) => r['success'] == true).length;
  final failed = results.where((r) => r['success'] == false).length;
  
  // print('Successful: $successful');
  // print('Failed: $failed');
  // print('Total: ${results.length}');
  
  if (successful > 0) {
    // print('\n🎉 Connection test passed! Your Flutter app can connect through ZeroTier.');
    // print('Make sure to update your API configuration with the correct ZeroTier IP.');
  } else {
    // print('\n❌ Connection test failed. Please check:');
    // print('1. Both devices are connected to the same ZeroTier network');
    // print('2. Both devices are authorized on the network');
    // print('3. Your backend server is running');
    // print('4. Your ZeroTier IP address is correct in the API configuration');
    // print('5. Your mobile device has internet connectivity');
  }
}