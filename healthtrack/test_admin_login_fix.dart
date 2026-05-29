import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Test the admin login with proper error handling
  final String baseUrl = 'http://10.243.17.91:3000';
  final String loginEndpoint = '/admin/login';
  
  print('Testing admin login with username "edwin" and password "admin"...');
  
  try {
    final response = await http.post(
      Uri.parse('$baseUrl$loginEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': 'edwin',
        'password': 'admin',
      }),
    ).timeout(Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    print('Content-Type: ${response.headers['content-type']}');
    print('Response Body: ${response.body}');
    
    // Test our JSON parsing fix
    if (response.body.isEmpty) {
      print('❌ Server returned an empty response');
      return;
    }
    
    if (!response.headers.containsKey('content-type') || 
        !response.headers['content-type']!.contains('application/json')) {
      print('❌ Server returned a non-JSON response');
      return;
    }
    
    try {
      final data = json.decode(response.body);
      print('✅ Successfully parsed JSON response:');
      print('Response data: $data');
      
      // Check if login was successful
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
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Connection error: $e');
  }
}