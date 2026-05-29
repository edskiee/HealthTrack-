import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Test the notifications endpoint
  final baseUrl = 'http://localhost:3000';
  final endpoint = '$baseUrl/admin/notifications';
  
  print('Testing notifications endpoint: $endpoint');
  
  try {
    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    
    print('Status code: ${response.statusCode}');
    print('Content-Type: ${response.headers['content-type']}');
    
    if (response.headers['content-type']?.contains('text/html') ?? false) {
      print('ERROR: Server returned HTML instead of JSON');
      print('Response body: ${response.body}');
    } else {
      print('SUCCESS: Server returned JSON');
      final data = json.decode(response.body);
      print('Response data: $data');
    }
  } catch (e) {
    print('ERROR: Failed to connect to server: $e');
  }
}