// Test script for complete maternal care registration flow
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data for maternal care patient
const testMaternalPatient = {
  // User account info
  username: `test_maternal_user_${Date.now()}`,
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
  
  // Child/Patient info (for compatibility with existing system)
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

console.log('🧪 Testing Complete Maternal Care Registration Flow\n');

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

// Test 1: Register maternal care patient
async function testMaternalRegistration() {
  console.log('📝 Test 1: Maternal Care Patient Registration');
  
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
        console.log(`   User ID: ${response.data.user ? response.data.user.id : response.data.data.user.id}`);
        console.log(`   Patient ID: ${response.data.patient ? response.data.patient.id : response.data.data.patient.id}`);
        console.log(`   Child Name: ${response.data.patient ? response.data.patient.child_fullname : response.data.data.patient.child_fullname}`);
        console.log(`   Service Type: ${response.data.user ? response.data.user.service_type : response.data.data.user.service_type}`);
        return response.data;
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

// Test 2: Login as the newly registered user
async function testLogin(userData) {
  console.log('\n🔐 Test 2: User Login');
  
  const loginData = {
    username: testMaternalPatient.username,
    password: testMaternalPatient.password
  };
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify(loginData);
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200) {
      if (response.data.success === "true" || response.data.success === true) {
        console.log('   ✅ Login successful');
        console.log(`   Service Type: ${response.data.user ? response.data.user.service_type : 'N/A'}`);
        return response.data;
      } else {
        console.log('   ❌ Login failed');
        console.log(`   Error: ${response.data.message}`);
        return null;
      }
    } else {
      console.log('   ❌ Login failed with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Login error: ${error.message}`);
    return null;
  }
}

// Test 3: Verify patient appears in admin panel
async function testAdminPatientList() {
  console.log('\n📋 Test 3: Verify Patient Appears in Admin Panel');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/patients',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.data.success) {
      const patients = response.data.data;
      console.log(`   ✅ Retrieved ${patients.length} patients from admin panel`);
      
      // Look for our test patient
      const testPatient = patients.find(p => 
        p.childName === testMaternalPatient.childName ||
        p.child_fullname === testMaternalPatient.childName
      );
      
      if (testPatient) {
        console.log('   ✅ Test patient found in admin panel');
        console.log(`   Patient ID: ${testPatient.id || testPatient.patient_id}`);
        console.log(`   Service Type: ${testPatient.serviceType || testPatient.service_type}`);
        return true;
      } else {
        console.log('   ⚠️ Test patient NOT found in admin panel');
        // Show last few patients for debugging
        const recentPatients = patients.slice(-3);
        console.log('   Recent patients:');
        recentPatients.forEach(p => {
          console.log(`     - ${p.childName || p.child_fullname} (${p.serviceType || p.service_type})`);
        });
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve patients');
      console.log(`   Status: ${response.statusCode}`);
      if (response.data) {
        console.log(`   Response: ${JSON.stringify(response.data)}`);
      }
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
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/health-records',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.data.success) {
      const records = response.data.data;
      console.log(`   ✅ Retrieved ${records.length} health records`);
      
      // Look for our test patient's health record
      const testRecord = records.find(r => 
        r.patient_name === testMaternalPatient.childName ||
        r.title === 'Initial Health Record'
      );
      
      if (testRecord) {
        console.log('   ✅ Test patient health record found');
        console.log(`   Record ID: ${testRecord.id}`);
        console.log(`   Title: ${testRecord.title}`);
        console.log(`   Record Type: ${testRecord.record_type}`);
        return true;
      } else {
        console.log('   ⚠️ Test patient health record NOT found');
        // Show last few records for debugging
        const recentRecords = records.slice(-3);
        console.log('   Recent records:');
        recentRecords.forEach(r => {
          console.log(`     - ${r.title} for ${r.patient_name} (${r.record_type})`);
        });
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve health records');
      console.log(`   Status: ${response.statusCode}`);
      if (response.data) {
        console.log(`   Response: ${JSON.stringify(response.data)}`);
      }
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving health records: ${error.message}`);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Starting Complete Maternal Care Registration Tests\n');
  
  try {
    // Test 1: Registration
    const registrationData = await testMaternalRegistration();
    
    if (!registrationData) {
      console.log('\n❌ Registration failed, stopping tests.');
      return;
    }
    
    // Wait a bit for database sync
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test 2: Login
    const loginData = await testLogin(registrationData);
    
    if (!loginData) {
      console.log('\n❌ Login failed, stopping tests.');
      return;
    }
    
    // Wait a bit more for sync
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test 3: Admin panel sync
    const patientInAdmin = await testAdminPatientList();
    
    // Test 4: Health records
    const healthRecordExists = await testHealthRecords();
    
    console.log('\n🏁 Complete Maternal Care Registration Testing Complete');
    
    if (patientInAdmin && healthRecordExists) {
      console.log('🎉 All maternal care registration tests PASSED!');
    } else {
      console.log('⚠️ Some maternal care registration tests failed.');
      if (!patientInAdmin) {
        console.log('   - Patient not found in admin panel');
      }
      if (!healthRecordExists) {
        console.log('   - Health record not found');
      }
    }
  } catch (error) {
    console.log(`\n💥 Test suite error: ${error.message}`);
  }
}

// Run the tests
runAllTests();