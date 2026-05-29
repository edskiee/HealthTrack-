import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Test data for immunization patient registration
  final immunizationPatientData = {
    // User account info
    'username': 'test_immuno_user_${DateTime.now().millisecondsSinceEpoch}',
    'password': 'testpass123',
    'email': 'test_immuno@example.com',
    'serviceType': 'immunization',
    'full_name': 'Test Immunization Mother',
    'phone': '09123456789',
    'address': '123 Test Street, Test City',
    
    // Child/Patient info
    'childName': 'Test Immunization Child',
    'motherName': 'Test Immunization Mother',
    'fatherName': 'Test Immunization Father',
    'dob': '2020-01-01',
    'placeOfBirth': 'Test City',
    'birthWeight': '3.2 kg',
    'birthHeight': '50 cm',
    'sex': 'Male',
    
    // Immunization specific fields
    'healthCenter': 'Test Health Center',
    'barangay': 'Test Barangay',
    'familyNumber': 'FAM-001',
    
    // Record info
    'recordType': 'Immunization',
    'recordDescription': 'Test immunization patient record',
  };

  // Test data for maternal care patient registration
  final maternalPatientData = {
    // User account info
    'username': 'test_maternal_user_${DateTime.now().millisecondsSinceEpoch}',
    'password': 'testpass123',
    'email': 'test_maternal@example.com',
    'serviceType': 'maternal',
    'full_name': 'Test Maternal Mother',
    'phone': '09123456789',
    'address': '456 Test Avenue, Test City, Test Province',
    
    // Maternal Care specific info
    'motherName': 'Test Maternal Mother',
    'dob': '1990-01-01',
    'education': 'College Graduate',
    'occupation': 'Teacher',
    'status': 'Married',
    'religion': 'Christian',
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
    
    // Child/Patient info
    'childName': 'Test Maternal Child',
    'fatherName': 'Test Spouse',
    'sex': 'Female',
    'placeOfBirth': 'Test City',
    'birthWeight': '3.0 kg',
    'birthHeight': '49 cm',
    
    // Record info
    'recordType': 'Maternal Care',
    'recordDescription': 'Test maternal care patient record',
  };

  print('🧪 Testing Registration Flow\n');
  
  // Test 1: Register immunization patient
  print('📝 Test 1: Immunization Patient Registration');
  await testRegistration(immunizationPatientData, 'Immunization');
  
  // Test 2: Register maternal care patient
  print('\n📝 Test 2: Maternal Care Patient Registration');
  await testRegistration(maternalPatientData, 'Maternal Care');
  
  // Test 3: Verify patients appear in admin panel
  print('\n📋 Test 3: Verify Patients Appear in Admin Panel');
  await testAdminPatientList();
}

Future<void> testRegistration(Map<String, dynamic> patientData, String serviceType) async {
  try {
    final response = await http.post(
      Uri.parse('http://localhost:3000/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(patientData),
    );
    
    print('   Status: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      final success = data['success'] == 'true' || data['success'] == true;
      
      if (success) {
        print('   ✅ $serviceType registration successful');
        print('   User ID: ${data['data']['user']['id']}');
        print('   Patient ID: ${data['data']['patient']['id']}');
        print('   Child Name: ${data['data']['patient']['child_fullname']}');
        print('   Service Type: ${data['data']['patient']['service_type']}');
      } else {
        print('   ❌ $serviceType registration failed');
        print('   Error: ${data['message']}');
      }
    } else {
      print('   ❌ $serviceType registration failed with status: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
  } catch (error) {
    print('   ❌ $serviceType registration error: $error');
  }
}

Future<void> testAdminPatientList() async {
  try {
    // Fetch the patients list
    final response = await http.get(
      Uri.parse('http://localhost:3000/patients'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final success = data['success'] == 'true' || data['success'] == true;
      
      if (success) {
        final patients = data['data'] as List;
        print('   ✅ Retrieved ${patients.length} patients from admin panel');
        
        // Display last 2 patients
        final recentPatients = patients.length > 2 ? patients.sublist(patients.length - 2) : patients;
        for (var patient in recentPatients) {
          print('   - ${patient['child_fullname']} (${patient['service_type']})');
        }
      } else {
        print('   ❌ Failed to retrieve patients: ${data['message']}');
      }
    } else {
      print('   ❌ Failed to retrieve patients with status: ${response.statusCode}');
      print('   Response: ${response.body}');
    }
  } catch (error) {
    print('   ❌ Error retrieving patients: $error');
  }
}