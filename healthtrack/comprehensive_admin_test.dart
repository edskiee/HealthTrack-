import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Comprehensive test for admin login
  final String baseUrl = 'http://10.243.17.91:3000';
  final String adminLoginEndpoint = '/admin/login';
  
  print('=== COMPREHENSIVE ADMIN LOGIN TEST ===');
  print('Base URL: $baseUrl');
  print('Endpoint: $adminLoginEndpoint');
  
  // Test 1: Check if server is responding
  print('\n--- Test 1: Server Health Check ---');
  try {
    final healthResponse = await http.get(
      Uri.parse('$baseUrl/'),
    ).timeout(Duration(seconds: 5));
    
    print('Health Check Status: ${healthResponse.statusCode}');
    if (healthResponse.statusCode == 200) {
      print('✅ Server is responding');
      print('Health Response: ${healthResponse.body}');
    } else {
      print('❌ Server health check failed');
      return;
    }
  } catch (e) {
    print('❌ Server health check error: $e');
    return;
  }
  
  // Test 2: Test admin login endpoint directly
  print('\n--- Test 2: Admin Login Endpoint Test ---');
  try {
    final loginResponse = await http.post(
      Uri.parse('$baseUrl$adminLoginEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'edwin',
        'password': 'admin',
      }),
    ).timeout(Duration(seconds: 10));
    
    print('Login Status Code: ${loginResponse.statusCode}');
    print('Content-Type: ${loginResponse.headers['content-type']}');
    print('Response Body: "${loginResponse.body}"');
    print('Response Length: ${loginResponse.body.length}');
    
    // Check if response is empty
    if (loginResponse.body.isEmpty) {
      print('❌ Server returned empty response');
      return;
    }
    
    // Check if response is JSON
    if (!loginResponse.headers.containsKey('content-type') || 
        !loginResponse.headers['content-type']!.contains('application/json')) {
      print('❌ Server returned non-JSON response');
      print('Content-Type: ${loginResponse.headers['content-type']}');
      return;
    }
    
    // Try to parse JSON
    try {
      final data = jsonDecode(loginResponse.body);
      print('✅ Successfully parsed JSON response');
      print('Response Data: $data');
      
      // Check success field
      bool isSuccess = false;
      if (data['success'] is bool) {
        isSuccess = data['success'];
      } else if (data['success'] is String) {
        isSuccess = data['success'].toLowerCase() == 'true';
      } else if (data['success'] is int) {
        isSuccess = data['success'] == 1;
      }
      
      if (isSuccess) {
        print('✅ Admin login successful!');
      } else {
        print('❌ Admin login failed: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (parseError) {
      print('❌ JSON Parse Error: $parseError');
      return;
    }
  } catch (e) {
    print('❌ Login request error: $e');
    return;
  }
  
  print('\n=== TEST COMPLETED ===');
}