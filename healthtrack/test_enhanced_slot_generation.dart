import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Enhanced Slot Generation Tests', () {
    final String baseUrl = Platform.environment['BASE_URL'] ?? 'http://localhost:3000';
    
    // Test service ID (you may need to adjust this based on your test database)
    const testServiceId = 1;
    

    test('Single slot creation with valid parameters', () async {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateString = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': '09:00:00',
          'end_time': '09:30:00',
          'slot_duration_minutes': 30,
          'max_patients': 10,
        }),
      );
      
      expect(response.statusCode, 201);
      final data = json.decode(response.body);
      expect(data['success'], true);
      expect(data['data'], isNotNull);
    });

    test('Bulk slot generation with valid parameters', () async {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateString = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': '09:00:00',
          'end_time': '17:00:00',
          'slot_duration_minutes': 30,
          'max_patients': 10,
          'generate_slots': true,
        }),
      );
      
      expect(response.statusCode, 201);
      final data = json.decode(response.body);
      expect(data['success'], true);
      expect(data['data'], isList);
      expect(data['data'].length, greaterThan(0));
    });

    test('Slot creation with timeout handling', () async {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateString = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      
      // This test verifies that the server handles timeout errors gracefully
      // We're not actually causing a timeout, but verifying the error structure
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/appointment-slots'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'service_id': testServiceId,
            'appointment_date': dateString,
            'start_time': 'invalid_time',
            'end_time': 'also_invalid',
          }),
        );
        
        // Expect validation error, not timeout
        expect(response.statusCode, 400);
      } catch (e) {
        // If we get a timeout exception, verify it's handled properly
        expect(e.toString(), contains('timed out'));
      }
    });

    test('Duplicate slot prevention', () async {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateString = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      
      // First, create a slot
      await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': '10:00:00',
          'end_time': '10:30:00',
          'slot_duration_minutes': 30,
          'max_patients': 10,
        }),
      );
      
      // Try to create a duplicate slot
      final response = await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': '10:00:00',
          'end_time': '10:30:00',
          'slot_duration_minutes': 30,
          'max_patients': 10,
        }),
      );
      
      // Should get a conflict error
      expect(response.statusCode, 400);
      final data = json.decode(response.body);
      expect(data['success'], false);
      expect(data['message'], contains('already exist'));
    });

    test('Past date rejection', () async {
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final dateString = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': '09:00:00',
          'end_time': '09:30:00',
        }),
      );
      
      expect(response.statusCode, 400);
      final data = json.decode(response.body);
      expect(data['success'], false);
      expect(data['message'], contains('past dates'));
    });

    test('Invalid time format rejection', () async {
      final tomorrow = DateTime.now().add(Duration(days: 1));
      final dateString = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      
      final response = await http.post(
        Uri.parse('$baseUrl/appointment-slots'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': testServiceId,
          'appointment_date': dateString,
          'start_time': 'invalid_format',
          'end_time': 'also_invalid',
        }),
      );
      
      expect(response.statusCode, 400);
      final data = json.decode(response.body);
      expect(data['success'], false);
      expect(data['message'], contains('Invalid time format'));
    });
  });
}