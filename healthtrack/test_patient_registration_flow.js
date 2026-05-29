// Test script for end-to-end patient registration flow
const http = require('http');
const crypto = require('crypto');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data for immunization patient
const testImmunizationPatient = {
  // User account info
  username: 'test_immuno_' + Math.random().toString(36).substring(7),
  password: 'testpass123',
  email: 'test_immuno@example.com',
  serviceType: 'immunization',
  
  // Child/Patient info
  childName: 'Test Immunization Child',
  motherName: 'Test Immunization Mother',
  fatherName: 'Test Immunization Father',
  dob: '2020-01-01',
  placeOfBirth: 'Test City',
  birthWeight: '3.2 kg',
  birthHeight: '50 cm',
  sex: 'Male',
  address: '123 Test Street, Test City',
  
  // Health center info (for Immunization)
  healthCenter: 'Test Health Center',
  barangay: 'Test Barangay',
  familyNo: 'FAM-001',
  
  // Record info
  recordType: 'Immunization',
  recordDescription: 'Test immunization patient record'
};

// Test data for maternal care patient
const testMaternalPatient = {
  // User account info
  username: 'test_maternal_' + Math.random().toString(36).substring(7),
  password: 'testpass123',
  email: 'test_maternal@example.com',
  serviceType: 'maternal',
  
  // Maternal Care specific info
  motherName: 'Test Maternal Mother',
  dob: '1990-01-01',
  education: 'College Graduate',
  occupation: 'Teacher',
  status: 'Married',
  religion: 'Christian',
  address: '456 Test Avenue, Test City, Test Province',
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
  
  // First, we need to login as admin to get access
  const adminLoginOptions = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/admin/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const adminLoginData = JSON.stringify({
    username: 'admin',
    password: 'test'
  });
  
  try {
    const loginResponse = await makeRequest(adminLoginOptions, adminLoginData);
    
    if (loginResponse.statusCode === 200 && loginResponse.data.success) {
      console.log('   ✅ Admin login successful');
      
      // Now fetch the patients list
      const patientsOptions = {
        hostname: SERVER_HOST,
        port: SERVER_PORT,
        path: '/patients',
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const patientsResponse = await makeRequest(patientsOptions);
      
      if (patientsResponse.statusCode === 200 && patientsResponse.data.success) {
        const patients = patientsResponse.data.data;
        console.log(`   ✅ Retrieved ${patients.length} patients from admin panel`);
        
        // Check if our test patients are in the list
        const immunizationPatient = patients.find(p => 
          p.childName === testImmunizationPatient.childName
        );
        
        const maternalPatient = patients.find(p => 
          p.childName === testMaternalPatient.childName
        );
        
        if (immunizationPatient) {
          console.log('   ✅ Immunization test patient found in admin panel');
        } else {
          console.log('   ⚠️ Immunization test patient NOT found in admin panel');
        }
        
        if (maternalPatient) {
          console.log('   ✅ Maternal care test patient found in admin panel');
        } else {
          console.log('   ⚠️ Maternal care test patient NOT found in admin panel');
        }
        
        return { immunizationPatient, maternalPatient };
      } else {
        console.log('   ❌ Failed to retrieve patients from admin panel');
        return null;
      }
    } else {
      console.log('   ❌ Admin login failed');
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Admin panel test error: ${error.message}`);
    return null;
  }
}

// Test 4: Verify health records are created
async function testHealthRecords() {
  console.log('\n📋 Test 4: Verify Health Records Are Created');
  
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
      
      // Check if our test patients have health records
      const immunizationRecord = records.find(r => 
        r.patient_name === testImmunizationPatient.childName
      );
      
      const maternalRecord = records.find(r => 
        r.patient_name === testMaternalPatient.childName
      );
      
      if (immunizationRecord) {
        console.log('   ✅ Immunization test patient health record found');
      } else {
        console.log('   ⚠️ Immunization test patient health record NOT found');
      }
      
      if (maternalRecord) {
        console.log('   ✅ Maternal care test patient health record found');
      } else {
        console.log('   ⚠️ Maternal care test patient health record NOT found');
      }
      
      return { immunizationRecord, maternalRecord };
    } else {
      console.log('   ❌ Failed to retrieve health records');
      return null;
    }
  } catch (error) {
    console.log(`   ❌ Health records test error: ${error.message}`);
    return null;
  }
}

// Run all tests
async function runAllTests() {
  console.log('🚀 Starting End-to-End Patient Registration Tests\n');
  
  try {
    // Test registrations
    const immunizationData = await testImmunizationRegistration();
    const maternalData = await testMaternalRegistration();
    
    // Wait a bit for database sync
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test admin panel sync
    await testAdminPatientList();
    
    // Test health records
    await testHealthRecords();
    
    console.log('\n🏁 End-to-End Testing Complete');
    
    if (immunizationData && maternalData) {
      console.log('🎉 All registration tests passed!');
    } else {
      console.log('⚠️ Some registration tests failed.');
    }
  } catch (error) {
    console.log(`\n💥 Test suite error: ${error.message}`);
  }
}

// Run the tests
runAllTests();