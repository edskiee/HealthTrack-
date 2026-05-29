// Comprehensive verification script for immunization registration flow
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

console.log('🧪 Comprehensive Verification of Immunization Registration Flow\n');

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

// Test data for immunization patient
const testImmunizationPatient = {
  // User account info
  username: `verification_user_${Date.now()}`,
  password: 'testpass123',
  email: 'verification@example.com',
  serviceType: 'immunization',
  full_name: 'Verification Test Mother',
  phone: '09123456789',
  address: '123 Verification Street, Test City',
  
  // Child/Patient info
  childName: 'Verification Test Child',
  motherName: 'Verification Test Mother',
  fatherName: 'Verification Test Father',
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
  recordDescription: 'Verification test immunization patient record',
};

// Test 1: Register immunization patient
async function testRegistration() {
  console.log('📝 Step 1: Registering Immunization Patient');
  
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
    // console.log(`   Response: ${JSON.stringify(response.data, null, 2)}`);
    
    if (response.statusCode === 200 || response.statusCode === 201) {
      if (response.data.success === true || response.data.success === "true") {
        console.log('   ✅ Registration successful');
        // The response structure shows user and patient data directly, not nested in 'data'
        const userData = response.data.user;
        const patientData = response.data.patient;
        if (userData && patientData) {
          console.log(`   User ID: ${userData.id}`);
          console.log(`   Patient ID: ${patientData.id}`);
          console.log(`   Child Name: ${patientData.child_fullname}`);
          return {
            user: userData,
            patient: patientData
          };
        } else {
          // Fallback to the nested structure
          const nestedData = response.data.data;
          if (nestedData && nestedData.user && nestedData.patient) {
            console.log(`   User ID: ${nestedData.user.id}`);
            console.log(`   Patient ID: ${nestedData.patient.id}`);
            console.log(`   Child Name: ${nestedData.patient.child_fullname}`);
            return nestedData;
          } else {
            console.log('   ⚠️  Unexpected response structure');
            return null;
          }
        }
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

// Test 2: Verify patient appears in patients list
async function testPatientsList() {
  console.log('\n📋 Step 2: Checking Patients List');
  
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
    console.log(`   Status: ${response.statusCode}`);
    
    if (response.statusCode === 200) {
      if (response.data.success === true) {
        const patients = response.data.data || [];
        console.log(`   ✅ Retrieved ${patients.length} patients`);
        
        // Look for our test patient
        const testPatient = patients.find(patient => 
          patient.childName === testImmunizationPatient.childName
        );
        
        if (testPatient) {
          console.log('   ✅ Test patient found in patients list');
          console.log(`   Patient ID: ${testPatient.id}`);
          console.log(`   Service Type: ${testPatient.serviceType}`);
          return true;
        } else {
          console.log('   ⚠️  Test patient not found in patients list');
          console.log('   Looking for:', testImmunizationPatient.childName);
          // Show first few patients
          const showCount = Math.min(3, patients.length);
          console.log('   First few patients:');
          for (let i = 0; i < showCount; i++) {
            console.log(`     - ${patients[i].childName} (${patients[i].serviceType})`);
          }
          return false;
        }
      } else {
        console.log('   ❌ Failed to retrieve patients list');
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve patients list with status:', response.statusCode);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving patients list: ${error.message}`);
    return false;
  }
}

// Test 3: Verify health record in main health records endpoint
async function testMainHealthRecordsEndpoint() {
  console.log('\n📋 Step 3: Checking Main Health Records Endpoint');
  
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
          console.log('   ✅ Test patient health record found in main endpoint');
          console.log(`   Record ID: ${patientRecord.id}`);
          console.log(`   Title: ${patientRecord.title}`);
          console.log(`   Record Type: ${patientRecord.record_type}`);
          return true;
        } else {
          console.log('   ⚠️  Test patient health record not found in main endpoint');
          console.log('   Looking for patient name:', testImmunizationPatient.childName);
          // Show first few records
          const showCount = Math.min(3, records.length);
          console.log('   First few records:');
          for (let i = 0; i < showCount; i++) {
            console.log(`     - ${records[i].patient_name} - ${records[i].title} (${records[i].record_type})`);
          }
          return false;
        }
      } else {
        console.log('   ❌ Failed to retrieve health records');
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve health records with status:', response.statusCode);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving health records: ${error.message}`);
    return false;
  }
}

// Test 4: Verify patient with records endpoint
async function testPatientsWithRecordsEndpoint() {
  console.log('\n📋 Step 4: Checking Patients with Records Endpoint');
  
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
          console.log('   ✅ Test patient found in patients-with-records endpoint');
          console.log(`   Patient ID: ${testPatient.patient_id}`);
          console.log(`   Service Type: ${testPatient.service_type}`);
          console.log(`   Health Records Count: ${testPatient.health_records ? testPatient.health_records.length : 0}`);
          
          if (testPatient.health_records && testPatient.health_records.length > 0) {
            const record = testPatient.health_records[0];
            console.log(`   Record Title: ${record.title}`);
            console.log(`   Record Type: ${record.record_type}`);
          }
          return true;
        } else {
          console.log('   ⚠️  Test patient not found in patients-with-records endpoint');
          console.log('   Looking for patient name:', testImmunizationPatient.childName);
          // Show first few patients
          const showCount = Math.min(3, patients.length);
          console.log('   First few patients:');
          for (let i = 0; i < showCount; i++) {
            const recordCount = patients[i].health_records ? patients[i].health_records.length : 0;
            console.log(`     - ${patients[i].child_fullname} (${patients[i].service_type}) - ${recordCount} records`);
          }
          return false;
        }
      } else {
        console.log('   ❌ Failed to retrieve patients with records');
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve patients with records with status:', response.statusCode);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving patients with records: ${error.message}`);
    return false;
  }
}

// Run comprehensive verification
async function runComprehensiveVerification() {
  try {
    console.log('🚀 Starting Comprehensive Verification\n');
    
    // Give some time for any previous operations to settle
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 1: Register patient
    const registrationData = await testRegistration();
    if (!registrationData) {
      console.log('\n❌ Registration failed. Aborting verification.');
      return;
    }
    
    // Wait for data to propagate
    console.log('\n⏳ Waiting for data to propagate...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Step 2: Check patients list
    const patientsListOk = await testPatientsList();
    
    // Step 3: Check main health records endpoint
    const mainEndpointOk = await testMainHealthRecordsEndpoint();
    
    // Step 4: Check patients with records endpoint
    const patientsWithRecordsOk = await testPatientsWithRecordsEndpoint();
    
    console.log('\n📊 Final Verification Results:');
    console.log(`   Registration: ✅ SUCCESS`);
    console.log(`   Patients List: ${patientsListOk ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`   Main Health Records Endpoint: ${mainEndpointOk ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`   Patients with Records Endpoint: ${patientsWithRecordsOk ? '✅ PASS' : '❌ FAIL'}`);
    
    const allPassed = patientsListOk && mainEndpointOk && patientsWithRecordsOk;
    console.log(`\n🎯 Overall Result: ${allPassed ? '✅ ALL VERIFICATIONS PASSED' : '❌ SOME VERIFICATIONS FAILED'}`);
    
    if (allPassed) {
      console.log('\n🎉 Immunization Registration Flow Verification Successful!');
      console.log('   - New immunization patients are successfully registered');
      console.log('   - Patient data appears in the patients list');
      console.log('   - Health records are automatically created');
      console.log('   - Data is visible in all relevant admin panel views');
      console.log('   - The issue reported has been resolved');
    } else {
      console.log('\n🔧 Troubleshooting needed:');
      if (!patientsListOk) {
        console.log('   - Patient not appearing in patients list');
      }
      if (!mainEndpointOk) {
        console.log('   - Health record not visible in main health records endpoint');
      }
      if (!patientsWithRecordsOk) {
        console.log('   - Patient not appearing in patients-with-records endpoint');
      }
    }
    
  } catch (error) {
    console.log(`\n💥 Verification error: ${error.message}`);
  }
}

// Run the verification
runComprehensiveVerification();