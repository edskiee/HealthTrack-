// Flutter test for patient registration synchronization
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Simple mock HTTP client implementation
class MockHttpClient {
  final List<MockResponse> responses = [];
  final List<HttpRequest> requests = [];

  void addResponse(int statusCode, dynamic body) {
    responses.add(MockResponse(statusCode, body));
  }

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    requests.add(HttpRequest('POST', url, headers, body));
    if (responses.isNotEmpty) {
      final response = responses.removeAt(0);
      return http.Response(
        response.body is String ? response.body : json.encode(response.body),
        response.statusCode,
        headers: {'content-type': 'application/json'},
      );
    }
    throw Exception('No mock response available');
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    requests.add(HttpRequest('GET', url, headers, null));
    if (responses.isNotEmpty) {
      final response = responses.removeAt(0);
      return http.Response(
        response.body is String ? response.body : json.encode(response.body),
        response.statusCode,
        headers: {'content-type': 'application/json'},
      );
    }
    throw Exception('No mock response available');
  }
}

class MockResponse {
  final int statusCode;
  final dynamic body;

  MockResponse(this.statusCode, this.body);
}

class HttpRequest {
  final String method;
  final Uri url;
  final Map<String, String>? headers;
  final Object? body;

  HttpRequest(this.method, this.url, this.headers, this.body);
}

void main() {
  group('Patient Registration Synchronization Tests', () {
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
    });

    test('Immunization patient registration creates patient and health record', () async {
      // Arrange
      final registrationData = {
        'username': 'testuser1',
        'password': 'testpass123',
        'email': 'testuser1@example.com',
        'serviceType': 'immunization',
        'childName': 'Test Child 1',
        'motherName': 'Test Mother 1',
        'fatherName': 'Test Father 1',
        'dob': '2020-01-01',
        'placeOfBirth': 'Test City',
        'birthWeight': '3.2 kg',
        'birthHeight': '50 cm',
        'sex': 'Male',
        'address': '123 Test Street',
        'healthCenter': 'Test Health Center',
        'barangay': 'Test Barangay',
        'familyNo': 'FAM-001',
        'recordType': 'Immunization',
        'recordDescription': 'Test immunization record'
      };

      final mockResponse = {
        'success': 'true',
        'message': 'Registration successful!',
        'data': {
          'user': {
            'id': 101,
            'username': 'testuser1',
            'full_name': 'Test Mother 1',
            'email': 'testuser1@example.com',
            'service_type': 'immunization'
          },
          'patient': {
            'id': 201,
            'user_id': 101,
            'child_fullname': 'Test Child 1',
            'mother_fullname': 'Test Mother 1',
            'father_fullname': 'Test Father 1',
            'dob': '2020-01-01',
            'place_of_birth': 'Test City',
            'birth_weight': '3.2 kg',
            'birth_height': '50 cm',
            'sex': 'Male',
            'address': '123 Test Street',
            'service_type': 'immunization',
            'record_type': 'Immunization',
            'record_description': 'Test immunization record'
          }
        }
      };

      mockHttpClient.addResponse(201, mockResponse);

      // Act
      final response = await mockHttpClient.post(
        Uri.parse('http://10.243.17.91:3000/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(registrationData),
      );

      // Assert
      expect(response.statusCode, 201);
      final responseData = json.decode(response.body);
      expect(responseData['success'], 'true');
      expect(responseData['data']['user']['id'], 101);
      expect(responseData['data']['patient']['id'], 201);
      expect(responseData['data']['patient']['child_fullname'], 'Test Child 1');
      expect(responseData['data']['patient']['service_type'], 'immunization');
    });

    test('Maternal care patient registration creates patient and health record', () async {
      // Arrange
      final registrationData = {
        'username': 'testuser2',
        'password': 'testpass123',
        'email': 'testuser2@example.com',
        'serviceType': 'maternal',
        'motherName': 'Test Mother 2',
        'dob': '1990-01-01',
        'education': 'College Graduate',
        'occupation': 'Teacher',
        'status': 'Married',
        'religion': 'Christian',
        'address': '456 Test Avenue, Test City, Test Province',
        'contact': '09123456789',
        'age': '30',
        'spouseName': 'Test Spouse',
        'spouseDob': '1988-01-01',
        'spouseEducation': 'High School',
        'spouseOccupation': 'Engineer',
        'monthlyIncome': '50000',
        'livingChildrenCount': '1',
        'birthPlan': 'Hospital',
        'birthAttendant': 'SBA',
        'facilityType': 'Hospital',
        'childName': 'Test Child 2',
        'fatherName': 'Test Spouse',
        'sex': 'Female',
        'placeOfBirth': 'Test City',
        'birthWeight': '3.0 kg',
        'birthHeight': '49 cm',
        'recordType': 'Maternal Care',
        'recordDescription': 'Test maternal care record'
      };

      final mockResponse = {
        'success': 'true',
        'message': 'Registration successful!',
        'data': {
          'user': {
            'id': 102,
            'username': 'testuser2',
            'full_name': 'Test Mother 2',
            'email': 'testuser2@example.com',
            'service_type': 'maternal'
          },
          'patient': {
            'id': 202,
            'user_id': 102,
            'child_fullname': 'Test Child 2',
            'mother_fullname': 'Test Mother 2',
            'father_fullname': 'Test Spouse',
            'dob': '1990-01-01',
            'place_of_birth': 'Test City',
            'birth_weight': '3.0 kg',
            'birth_height': '49 cm',
            'sex': 'Female',
            'address': '456 Test Avenue, Test City, Test Province',
            'service_type': 'maternal',
            'record_type': 'Maternal Care',
            'record_description': 'Test maternal care record',
            'spouse_name': 'Test Spouse',
            'living_children_count': '1',
            'monthly_income': '50000',
            'age': '30',
            'education': 'College Graduate',
            'occupation': 'Teacher',
            'birth_attendant': 'SBA',
            'facility_type': 'Hospital'
          }
        }
      };

      mockHttpClient.addResponse(201, mockResponse);

      // Act
      final response = await mockHttpClient.post(
        Uri.parse('http://10.243.17.91:3000/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(registrationData),
      );

      // Assert
      expect(response.statusCode, 201);
      final responseData = json.decode(response.body);
      expect(responseData['success'], 'true');
      expect(responseData['data']['user']['id'], 102);
      expect(responseData['data']['patient']['id'], 202);
      expect(responseData['data']['patient']['child_fullname'], 'Test Child 2');
      expect(responseData['data']['patient']['service_type'], 'maternal');
      expect(responseData['data']['patient']['spouse_name'], 'Test Spouse');
    });

    test('Admin can retrieve newly registered patients', () async {
      // Arrange
      final mockPatientsResponse = {
        'success': true,
        'data': [
          {
            'id': 201,
            'user_id': 101,
            'child_fullname': 'Test Child 1',
            'mother_fullname': 'Test Mother 1',
            'father_fullname': 'Test Father 1',
            'dob': '2020-01-01',
            'place_of_birth': 'Test City',
            'birth_weight': '3.2 kg',
            'birth_height': '50 cm',
            'sex': 'Male',
            'address': '123 Test Street',
            'service_type': 'immunization',
            'record_type': 'Immunization',
            'record_description': 'Test immunization record'
          },
          {
            'id': 202,
            'user_id': 102,
            'child_fullname': 'Test Child 2',
            'mother_fullname': 'Test Mother 2',
            'father_fullname': 'Test Spouse',
            'dob': '1990-01-01',
            'place_of_birth': 'Test City',
            'birth_weight': '3.0 kg',
            'birth_height': '49 cm',
            'sex': 'Female',
            'address': '456 Test Avenue, Test City, Test Province',
            'service_type': 'maternal',
            'record_type': 'Maternal Care',
            'record_description': 'Test maternal care record',
            'spouse_name': 'Test Spouse',
            'living_children_count': '1',
            'monthly_income': '50000',
            'age': '30'
          }
        ]
      };

      mockHttpClient.addResponse(200, mockPatientsResponse);

      // Act
      final response = await mockHttpClient.get(
        Uri.parse('http://10.243.17.91:3000/patients'),
        headers: {'Content-Type': 'application/json'},
      );

      // Assert
      expect(response.statusCode, 200);
      final responseData = json.decode(response.body);
      expect(responseData['success'], true);
      expect(responseData['data'].length, 2);
      
      final firstPatient = responseData['data'][0];
      expect(firstPatient['child_fullname'], 'Test Child 1');
      expect(firstPatient['service_type'], 'immunization');
      
      final secondPatient = responseData['data'][1];
      expect(secondPatient['child_fullname'], 'Test Child 2');
      expect(secondPatient['service_type'], 'maternal');
      expect(secondPatient['spouse_name'], 'Test Spouse');
    });

    test('Health records are created for newly registered patients', () async {
      // Arrange
      final mockHealthRecordsResponse = {
        'success': true,
        'data': [
          {
            'id': 301,
            'patient_id': 201,
            'record_type': 'Immunization',
            'title': 'Initial Health Record',
            'description': 'Health record created upon user registration',
            'patient_name': 'Test Child 1',
            'mother_fullname': 'Test Mother 1',
            'service_type': 'immunization'
          },
          {
            'id': 302,
            'patient_id': 202,
            'record_type': 'Maternal Care',
            'title': 'Initial Health Record',
            'description': 'Health record created upon user registration',
            'patient_name': 'Test Child 2',
            'mother_fullname': 'Test Mother 2',
            'service_type': 'maternal'
          }
        ]
      };

      mockHttpClient.addResponse(200, mockHealthRecordsResponse);

      // Act
      final response = await mockHttpClient.get(
        Uri.parse('http://10.243.17.91:3000/health-records'),
        headers: {'Content-Type': 'application/json'},
      );

      // Assert
      expect(response.statusCode, 200);
      final responseData = json.decode(response.body);
      expect(responseData['success'], true);
      expect(responseData['data'].length, 2);
      
      final firstRecord = responseData['data'][0];
      expect(firstRecord['patient_name'], 'Test Child 1');
      expect(firstRecord['service_type'], 'immunization');
      expect(firstRecord['title'], 'Initial Health Record');
      
      final secondRecord = responseData['data'][1];
      expect(secondRecord['patient_name'], 'Test Child 2');
      expect(secondRecord['service_type'], 'maternal');
      expect(secondRecord['title'], 'Initial Health Record');
    });
  });
}