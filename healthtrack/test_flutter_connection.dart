import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Test the dashboard stats endpoint
  final url = 'http://10.243.17.91:3000/dashboard/stats';
  print('Testing connection to: $url');
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
    
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Success: ${data['success']}');
      if (data['success']) {
        print('Data: ${data['data']}');
      }
    } else {
      print('Failed to fetch data');
    }
  } catch (e) {
    print('Error: $e');
  }
}