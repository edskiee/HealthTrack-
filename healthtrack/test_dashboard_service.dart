import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Test the dashboard service methods directly
  final baseUrl = 'http://10.243.17.91:3000';
  
  print('Testing Dashboard Service Methods');
  print('Base URL: $baseUrl');
  
  // Test dashboard stats
  await testDashboardStats(baseUrl);
  
  // Test recent activities
  await testRecentActivities(baseUrl);
  
  // Test today's appointments
  await testTodaysAppointments(baseUrl);
}

Future<void> testDashboardStats(String baseUrl) async {
  print('\n=== Testing Dashboard Stats ===');
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/stats'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Success: ${data['success']}');
      if (data['success'] == true) {
        print('Data: ${data['data']}');
      } else {
        print('Error Message: ${data['message']}');
      }
    } else {
      print('Failed with status: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> testRecentActivities(String baseUrl) async {
  print('\n=== Testing Recent Activities ===');
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/activities'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Success: ${data['success']}');
      if (data['success'] == true) {
        print('Count: ${data['count']}');
        print('Data Length: ${data['data'].length}');
        if (data['data'].length > 0) {
          print('First Activity: ${data['data'][0]}');
        }
      } else {
        print('Error Message: ${data['message']}');
      }
    } else {
      print('Failed with status: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

Future<void> testTodaysAppointments(String baseUrl) async {
  print('\n=== Testing Today\'s Appointments ===');
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/appointments'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(Duration(seconds: 10));
    
    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Success: ${data['success']}');
      if (data['success'] == true) {
        print('Count: ${data['count']}');
        print('Data Length: ${data['data'].length}');
        if (data['data'].length > 0) {
          print('First Appointment: ${data['data'][0]}');
        } else {
          print('No appointments today');
        }
      } else {
        print('Error Message: ${data['message']}');
      }
    } else {
      print('Failed with status: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}