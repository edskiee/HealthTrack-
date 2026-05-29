import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> debugAdminLogin() async {
  print('=== DEBUG ADMIN LOGIN ===');
  
  final String baseUrl = 'http://10.243.17.91:3000';
  final String endpoint = '/admin/login';
  final String fullUrl = '$baseUrl$endpoint';
  
  print('URL: $fullUrl');
  
  try {
    print('Sending request...');
    final response = await http.post(
      Uri.parse(fullUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': 'edwin',
        'password': 'admin',
      }),
    ).timeout(Duration(seconds: 15));
    
    print('--- RESPONSE DETAILS ---');
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: "${response.body}"');
    print('Body Length: ${response.body.length}');
    
    if (response.body.isEmpty) {
      print('❌ ERROR: Response body is empty');
      return;
    }
    
    // Check content type
    final contentType = response.headers['content-type'] ?? '';
    print('Content-Type: $contentType');
    
    if (!contentType.contains('application/json')) {
      print('❌ ERROR: Response is not JSON');
      return;
    }
    
    // Try to parse JSON
    print('Attempting to parse JSON...');
    try {
      final data = jsonDecode(response.body);
      print('✅ JSON parsed successfully');
      print('Data: $data');
      
      // Check success field
      final success = data['success'];
      print('Success field: $success (type: ${success.runtimeType})');
      
      if (success == true || success == 'true' || success == 1) {
        print('✅ LOGIN SUCCESSFUL');
      } else {
        print('❌ LOGIN FAILED: ${data['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ JSON PARSING ERROR: $e');
      print('Raw response: ${response.body}');
    }
  } catch (e) {
    print('❌ REQUEST ERROR: $e');
  }
}

void main() {
  debugAdminLogin();
}