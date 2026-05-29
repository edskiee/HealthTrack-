// Debug script to check health records endpoint
const http = require('http');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

console.log('🔍 Debugging Health Records Endpoint\n');

// Function to make HTTP requests
function makeRequest(options) {
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
    
    req.end();
  });
}

// Test health records endpoint
async function testHealthRecordsEndpoint() {
  console.log('📋 Testing Health Records Endpoint (/health-records)');
  
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
        
        // Show details of first few records
        const showCount = Math.min(5, records.length);
        console.log(`   Showing first ${showCount} records:`);
        for (let i = 0; i < showCount; i++) {
          const record = records[i];
          console.log(`     ${i+1}. ${record.patient_name || 'Unknown'} - ${record.title || 'Untitled'} (${record.record_type || 'Unknown'})`);
        }
        
        if (records.length === 0) {
          console.log('   ⚠️  No health records found');
        }
        
        return true;
      } else {
        console.log('   ❌ Failed to retrieve health records');
        console.log(`   Error: ${response.data.message}`);
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve health records with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data, null, 2)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving health records: ${error.message}`);
    return false;
  }
}

// Test patients with records endpoint
async function testPatientsWithRecordsEndpoint() {
  console.log('\n📋 Testing Patients with Records Endpoint (/health-records/all-patients)');
  
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
        
        // Show details of first few patients
        const showCount = Math.min(5, patients.length);
        console.log(`   Showing first ${showCount} patients:`);
        for (let i = 0; i < showCount; i++) {
          const patient = patients[i];
          const recordCount = patient.health_records ? patient.health_records.length : 0;
          console.log(`     ${i+1}. ${patient.child_fullname || 'Unknown'} (${patient.service_type || 'Unknown'}) - ${recordCount} records`);
        }
        
        if (patients.length === 0) {
          console.log('   ⚠️  No patients found');
        }
        
        return true;
      } else {
        console.log('   ❌ Failed to retrieve patients with records');
        console.log(`   Error: ${response.data.message}`);
        return false;
      }
    } else {
      console.log('   ❌ Failed to retrieve patients with records with status:', response.statusCode);
      console.log(`   Response: ${JSON.stringify(response.data, null, 2)}`);
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Error retrieving patients with records: ${error.message}`);
    return false;
  }
}

// Run debug tests
async function runDebugTests() {
  try {
    console.log('🚀 Starting Health Records Debug Tests\n');
    
    // Test health records endpoint
    const healthRecordsSuccess = await testHealthRecordsEndpoint();
    
    // Test patients with records endpoint
    const patientsWithRecordsSuccess = await testPatientsWithRecordsEndpoint();
    
    console.log('\n🏁 Debug Summary:');
    console.log(`   Health Records Endpoint: ${healthRecordsSuccess ? '✅ WORKING' : '❌ ISSUE'}`);
    console.log(`   Patients with Records Endpoint: ${patientsWithRecordsSuccess ? '✅ WORKING' : '❌ ISSUE'}`);
    
    if (healthRecordsSuccess && patientsWithRecordsSuccess) {
      console.log('\n✅ Both endpoints are working correctly');
    } else {
      console.log('\n⚠️  There may be an inconsistency between the endpoints');
    }
    
  } catch (error) {
    console.log(`\n💥 Debug test error: ${error.message}`);
  }
}

// Run the debug tests
runDebugTests();