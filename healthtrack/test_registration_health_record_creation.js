// Test script to verify that health records are created during patient registration
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data for immunization patient
const testImmunizationPatient = {
  // User account info
  username: 'test_health_record_' + Math.random().toString(36).substring(7),
  password: 'testpass123',
  email: 'test_health_record@example.com',
  serviceType: 'immunization',
  
  // Child/Patient info
  childName: 'Test Health Record Child',
  motherName: 'Test Health Record Mother',
  fatherName: 'Test Health Record Father',
  dob: '2020-01-01',
  placeOfBirth: 'Test City',
  birthWeight: '3.2 kg',
  birthHeight: '50 cm',
  sex: 'Male',
  address: '123 Test Street, Test City',
  
  // Health center info (for Immunization)
  healthCenter: 'Test Health Center',
  barangay: 'Test Barangay',
  familyNumber: 'FAM-001',
  
  // Record info
  recordType: 'Immunization',
  recordDescription: 'Test health record creation'
};

console.log('🧪 Testing Health Record Creation During Registration\n');

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

// Test 1: Register patient
async function testRegistration() {
  console.log('📝 Test 1: Patient Registration');
  
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
        console.log('   ✅ Registration successful');
        console.log(`   User ID: ${response.data.user ? response.data.user.id : 'N/A'}`);
        console.log(`   Patient ID: ${response.data.patient ? response.data.patient.id : 'N/A'}`);
        return response.data; // Return the entire data object
      } else {
        console.log('   ❌ Registration failed');
        console.log(`   Error: ${response.data.message}`);
        return null;
      }
    } else {
      console.log('   ❌ Registration failed with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Registration error: ${error.message}`);
    return null;
  }
}

// Test 2: Verify health records are created
async function testHealthRecords(userId, patientId) {
  console.log('\n📋 Test 2: Verify Health Records Are Created');
  
  const healthRecordsOptions = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/health-records',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(healthRecordsOptions);
    
    if (response.statusCode === 200 && response.data.success) {
      const records = response.data.data;
      console.log(`   ✅ Retrieved ${records.length} health records`);
      
      // Check if our test patient has a health record
      const healthRecord = records.find(r => 
        r.patient_id == patientId
      );
      
      if (healthRecord) {
        console.log('   ✅ Health record found for test patient');
        console.log(`   Record ID: ${healthRecord.id}`);
        console.log(`   Title: ${healthRecord.title}`);
        console.log(`   Description: ${healthRecord.description}`);
        return true;
      } else {
        console.log('   ❌ Health record NOT found for test patient');
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve health records');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Health records test error: ${error.message}`);
    return false;
  }
}

// Run tests
async function runTests() {
  console.log('🚀 Starting Health Record Creation Tests\n');
  
  try {
    // Test registration
    const registrationData = await testRegistration();
    
    if (registrationData && registrationData.user && registrationData.patient) {
      // Wait a bit for database sync
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Test health records
      const healthRecordExists = await testHealthRecords(
        registrationData.user.id, 
        registrationData.patient.id
      );
      
      console.log('\n🏁 Health Record Creation Testing Complete');
      
      if (healthRecordExists) {
        console.log('🎉 Health record creation test PASSED!');
      } else {
        console.log('❌ Health record creation test FAILED.');
      }
    } else {
      console.log('\n❌ Registration failed, skipping health record test.');
    }
  } catch (error) {
    console.log(`\n💥 Test suite error: ${error.message}`);
  }
}

// Run the tests
runTests();