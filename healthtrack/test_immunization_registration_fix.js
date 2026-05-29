// Test script to verify immunization registration and health record creation fix
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data for immunization patient
const testImmunizationPatient = {
  // User account info
  username: `test_immuno_user_${Date.now()}`,
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
  recordDescription: 'Test immunization patient record',
};

console.log('🧪 Testing Immunization Registration and Health Record Creation\n');

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
    console.log(`   Response: ${JSON.stringify(response.data, null, 2)}`);
    
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

// Test 2: Check if health records are created
async function testHealthRecords(patientData) {
  console.log('\n📋 Test 2: Checking Health Records for Registered Patient');
  
  if (!patientData) {
    console.log('   ⚠️  Skipping health records test - no patient data');
    return false;
  }
  
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
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200) {
      if (response.data.success === true) {
        const records = response.data.data || [];
        console.log(`   ✅ Retrieved ${records.length} health records`);
        
        // Look for our test patient's record
        const patientRecord = records.find(record => 
          record.patient_name === testImmunizationPatient.childName
        );
        
        if (patientRecord) {
          console.log('   ✅ Found health record for our test patient');
          console.log(`   Record ID: ${patientRecord.id}`);
          console.log(`   Patient Name: ${patientRecord.patient_name}`);
          console.log(`   Record Type: ${patientRecord.record_type}`);
          console.log(`   Title: ${patientRecord.title}`);
          return true;
        } else {
          console.log('   ⚠️  Health record not found for our test patient');
          console.log('   Looking for patient name:', testImmunizationPatient.childName);
          console.log('   All records:');
          records.forEach(record => {
            console.log(`     - ${record.patient_name} (${record.record_type}): ${record.title}`);
          });
          return false;
        }
      } else {
        console.log('   ❌ Failed to retrieve health records');
        console.log(`   Error: ${response.data.message}`);
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve health records with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving health records: ${error.message}`);
    return false;
  }
}

// Test 3: Check patients with records endpoint
async function testPatientsWithRecords(patientData) {
  console.log('\n📋 Test 3: Checking Patients with Records Endpoint');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/health-records/all-patients',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200) {
      if (response.data.success === true) {
        const patients = response.data.data || [];
        console.log(`   ✅ Retrieved ${patients.length} patients with records`);
        
        // Look for our test patient
        const testPatient = patients.find(patient => 
          patient.child_fullname === testImmunizationPatient.childName
        );
        
        if (testPatient) {
          console.log('   ✅ Found our test patient in all-patients endpoint');
          console.log(`   Patient ID: ${testPatient.patient_id}`);
          console.log(`   Child Name: ${testPatient.child_fullname}`);
          console.log(`   Service Type: ${testPatient.service_type}`);
          console.log(`   Health Records Count: ${testPatient.health_records ? testPatient.health_records.length : 0}`);
          
          if (testPatient.health_records && testPatient.health_records.length > 0) {
            console.log('   Health Records:');
            testPatient.health_records.forEach(record => {
              console.log(`     - ${record.title} (${record.record_type})`);
            });
          }
          return true;
        } else {
          console.log('   ⚠️  Test patient not found in all-patients endpoint');
          console.log('   Looking for patient name:', testImmunizationPatient.childName);
          console.log('   All patients:');
          patients.forEach(patient => {
            console.log(`     - ${patient.child_fullname} (${patient.service_type})`);
          });
          return false;
        }
      } else {
        console.log('   ❌ Failed to retrieve patients with records');
        console.log(`   Error: ${response.data.message}`);
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve patients with records with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving patients with records: ${error.message}`);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  try {
    console.log('🚀 Starting Immunization Registration and Health Record Tests\n');
    
    // Test registration
    const patientData = await testImmunizationRegistration();
    
    // Wait a moment for data to propagate
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test health records
    const healthRecordsFound = await testHealthRecords(patientData);
    
    // Test patients with records
    const patientsWithRecordsFound = await testPatientsWithRecords(patientData);
    
    console.log('\n🏁 Test Summary:');
    console.log(`   Registration: ${patientData ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`   Health Records: ${healthRecordsFound ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`   Patients with Records: ${patientsWithRecordsFound ? '✅ PASS' : '❌ FAIL'}`);
    
    const allPassed = patientData && healthRecordsFound && patientsWithRecordsFound;
    console.log(`\n🎯 Overall Result: ${allPassed ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}`);
    
    if (allPassed) {
      console.log('\n🎉 The immunization registration flow is working correctly!');
      console.log('   - New patients are successfully registered');
      console.log('   - Health records are automatically created');
      console.log('   - Data is visible in the admin panel');
    } else {
      console.log('\n🔧 Troubleshooting needed:');
      if (!patientData) {
        console.log('   - Registration is failing');
      }
      if (!healthRecordsFound) {
        console.log('   - Health records are not being created or not visible');
      }
      if (!patientsWithRecordsFound) {
        console.log('   - Patients with records endpoint is not working correctly');
      }
    }
    
  } catch (error) {
    console.log(`\n💥 Test suite error: ${error.message}`);
  }
}

// Run the tests
runAllTests();