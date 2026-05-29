import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== FINAL DEBUG TEST ===');
  
  // Test different scenarios
  final scenarios = [
    {
      'name': 'Correct credentials',
      'username': 'edwin',
      'password': 'admin'
    },
    {
      'name': 'Wrong username',
      'username': 'nonexistent',
      'password': 'admin'
    },
    {
      'name': 'Wrong password',
      'username': 'edwin',
      'password': 'wrongpassword'
    },
    {
      'name': 'Empty credentials',
      'username': '',
      'password': ''
    }
  ];
  
  for (final scenario in scenarios) {
    print('\n--- Testing: ${scenario['name']} ---');
    
    try {
      final response = await http.post(
        Uri.parse('http://10.243.17.91:3000/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': scenario['username'],
          'password': scenario['password'],
        }),
      ).timeout(Duration(seconds: 10));
      
      print('Status: ${response.statusCode}');
      print('Headers: ${response.headers}');
      print('Body: "${response.body}"');
      print('Body length: ${response.body.length}');
      
      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON: $data');
        } catch (e) {
          print('JSON parse error: $e');
        }
      } else {
        print('⚠️  Empty response body');
      }
    } catch (e) {
      print('Request error: $e');
    }
  }
  
  print('\n=== DEBUG TEST COMPLETE ===');
}