// Test script for end-to-end patient registration flow
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data for immunization patient
const testImmunizationPatient = {
  // User account info
  username: `test_immuno_${Date.now()}`,
  password: 'testpass123',
  email: 'test_immuno@example.com',
  serviceType: 'immunization',
  full_name: 'Test Immunization Mother',
  phone: '09123456789',
  address: '123 Test Street, Test City',
  
  // Child/Patient info
  childName: 'Test Immunization Child',
  motherName: 'Test Immunization Mother',
  fatherName: 'Test Immunization Father',
  dob: '2020-01-01',
  placeOfBirth: 'Test City',
  birthWeight: '3.2 kg',
  birthHeight: '50 cm',
  sex: 'Male',
  
  // Immunization specific fields
  healthCenter: 'Test Health Center',
  barangay: 'Test Barangay',
  familyNumber: 'FAM-001',
  
  // Record info
  recordType: 'Immunization',
  recordDescription: 'Test immunization patient record'
};

// Test data for maternal care patient
const testMaternalPatient = {
  // User account info
  username: `test_maternal_${Date.now()}`,
  password: 'testpass123',
  email: 'test_maternal@example.com',
  serviceType: 'maternal',
  full_name: 'Test Maternal Mother',
  phone: '09123456789',
  address: '456 Test Avenue, Test City, Test Province',
  
  // Maternal Care specific info
  motherName: 'Test Maternal Mother',
  dob: '1990-01-01',
  education: 'College Graduate',
  occupation: 'Teacher',
  status: 'Married',
  religion: 'Christian',
  contact: '09123456789',
  age: '30',
  spouseName: 'Test Spouse',
  spouseDob: '1988-01-01',
  spouseEducation: 'High School',
  spouseOccupation: 'Engineer',
  monthlyIncome: '50000',
  livingChildrenCount: '1',
  birthPlan: 'Hospital',
  birthAttendant: 'SBA',
  facilityType: 'Hospital',
  
  // Child/Patient info
  childName: 'Test Maternal Child',
  fatherName: 'Test Spouse',
  sex: 'Female',
  placeOfBirth: 'Test City',
  birthWeight: '3.0 kg',
  birthHeight: '49 cm',
  
  // Record info
  recordType: 'Maternal Care',
  recordDescription: 'Test maternal care patient record'
};

console.log('🧪 Testing End-to-End Patient Registration Flow\n');

// Function to make HTTP requests
function makeRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: jsonData
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: data
          });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Test 1: Register immunization patient
async function testImmunizationRegistration() {
  console.log('📝 Test 1: Immunization Patient Registration');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/auth/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify(testImmunizationPatient);
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200 || response.statusCode === 201) {
      if (response.data.success === "true" || response.data.success === true) {
        console.log('   ✅ Immunization registration successful');
        console.log(`   User ID: ${response.data.data.user.id}`);
        console.log(`   Patient ID: ${response.data.data.patient.id}`);
        console.log(`   Child Name: ${response.data.data.patient.child_fullname}`);
        console.log(`   Service Type: ${response.data.data.patient.service_type}`);
        return response.data.data;
      } else {
        console.log('   ❌ Immunization registration failed');
        console.log(`   Error: ${response.data.message}`);
        return null;
      }
    } else {
      console.log('   ❌ Immunization registration failed with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Immunization registration error: ${error.message}`);
    return null;
  }
}

// Test 2: Register maternal care patient
async function testMaternalRegistration() {
  console.log('\n📝 Test 2: Maternal Care Patient Registration');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/auth/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify(testMaternalPatient);
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200 || response.statusCode === 201) {
      if (response.data.success === "true" || response.data.success === true) {
        console.log('   ✅ Maternal care registration successful');
        console.log(`   User ID: ${response.data.data.user.id}`);
        console.log(`   Patient ID: ${response.data.data.patient.id}`);
        console.log(`   Child Name: ${response.data.data.patient.child_fullname}`);
        console.log(`   Service Type: ${response.data.data.patient.service_type}`);
        return response.data.data;
      } else {
        console.log('   ❌ Maternal care registration failed');
        console.log(`   Error: ${response.data.message}`);
        return null;
      }
    } else {
      console.log('   ❌ Maternal care registration failed with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Maternal care registration error: ${error.message}`);
    return null;
  }
}

// Test 3: Verify patient appears in admin panel
async function testAdminPatientList() {
  console.log('\n📋 Test 3: Verify Patients Appear in Admin Panel');
  
  // Fetch the patients list
  const patientsOptions = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/patients',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const patientsResponse = await makeRequest(patientsOptions);
    
    if (patientsResponse.statusCode === 200 && patientsResponse.data.success) {
      const patients = patientsResponse.data.data;
      console.log(`   ✅ Retrieved ${patients.length} patients from admin panel`);
      
      // Display last 2 patients
      const recentPatients = patients.length > 2 ? patients.slice(-2) : patients;
      recentPatients.forEach(patient => {
        console.log(`   - ${patient.childName || patient.child_fullname} (${patient.serviceType || patient.service_type})`);
      });
      
      return true;
    } else {
      console.log('   ❌ Failed to retrieve patients');
      console.log(`   Status: ${patientsResponse.statusCode}`);
      console.log(`   Response: ${JSON.stringify(patientsResponse.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving patients: ${error.message}`);
    return false;
  }
}

// Test 4: Verify health records are created
async function testHealthRecords() {
  console.log('\n📋 Test 4: Verify Health Records Are Created');
  
  // Fetch the health records list
  const recordsOptions = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/health-records',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const recordsResponse = await makeRequest(recordsOptions);
    
    if (recordsResponse.statusCode === 200 && recordsResponse.data.success) {
      const records = recordsResponse.data.data;
      console.log(`   ✅ Retrieved ${records.length} health records from admin panel`);
      
      // Display last 2 records
      const recentRecords = records.length > 2 ? records.slice(-2) : records;
      recentRecords.forEach(record => {
        console.log(`   - ${record.title} for ${record.patient_name} (${record.record_type})`);
      });
      
      return true;
    } else {
      console.log('   ❌ Failed to retrieve health records');
      console.log(`   Status: ${recordsResponse.statusCode}`);
      console.log(`   Response: ${JSON.stringify(recordsResponse.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving health records: ${error.message}`);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  try {
    // Test registration flows
    const immunizationResult = await testImmunizationRegistration();
    const maternalResult = await testMaternalRegistration();
    
    // Test admin panel data
    await testAdminPatientList();
    await testHealthRecords();
    
    console.log('\n✅ All tests completed!');
  } catch (error) {
    console.log(`\n❌ Test suite error: ${error.message}`);
  }
}

// Run the tests
runAllTests();