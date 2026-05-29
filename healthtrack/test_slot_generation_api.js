// Test script to generate appointment slots with valid data
const http = require('http');

console.log('🔍 Testing Appointment Slot Generation');
console.log('='.repeat(60));

// First, get available services
async function getServices() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/service-config/services',
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    req.setTimeout(5000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    req.end();
  });
}

// Create appointment slots
async function createSlots(serviceId) {
  const postData = JSON.stringify({
    service_id: serviceId,
    appointment_date: '2026-03-15',
    start_time: '09:00:00',
    end_time: '12:00:00',
    slot_duration_minutes: 30,
    max_patients: 5,
    generate_slots: true
  });
  
  console.log(`\n📝 Creating slots with:`);
  console.log(`   Service ID: ${serviceId}`);
  console.log(`   Date: 2026-03-15`);
  console.log(`   Time: 09:00 - 12:00`);
  console.log(`   Duration: 30 minutes`);
  console.log(`   Max patients: 5`);
  console.log(`   Generate multiple slots: YES`);
  
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointment-slots',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          resolve(response);
        } catch (e) {
          resolve({ raw: data, statusCode: res.statusCode });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    req.setTimeout(15000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    
    req.write(postData);
    req.end();
  });
}

// Main test execution
async function runTest() {
  try {
    console.log('\n📡 Step 1: Fetching available services...');
    const servicesResponse = await getServices();
    
    if (!servicesResponse.success || !servicesResponse.data || servicesResponse.data.length === 0) {
      console.log('❌ No services found! Please add services first.');
      console.log('Response:', servicesResponse);
      process.exit(1);
    }
    
    console.log(`✅ Found ${servicesResponse.data.length} service(s):`);
    servicesResponse.data.forEach((service, index) => {
      console.log(`   ${index + 1}. ID: ${service.id}, Name: ${service.service_name}`);
    });
    
    // Use the first service
    const testServiceId = servicesResponse.data[0].id;
    
    console.log(`\n📡 Step 2: Generating slots for service ID ${testServiceId}...`);
    const creationResponse = await createSlots(testServiceId);
    
    if (creationResponse.success) {
      console.log('\n✅ SUCCESS! Slots generated successfully!');
      console.log(`   Message: ${creationResponse.message}`);
      console.log(`   Slots created: ${creationResponse.data ? creationResponse.data.length : 0}`);
      
      if (creationResponse.data && creationResponse.data.length > 0) {
        console.log('\n📋 Sample slot details:');
        creationResponse.data.slice(0, 3).forEach((slot, index) => {
          console.log(`   Slot ${index + 1}: ${slot.start_time} - ${slot.end_time} (${slot.slot_duration_minutes} min)`);
        });
        
        if (creationResponse.data.length > 3) {
          console.log(`   ... and ${creationResponse.data.length - 3} more slots`);
        }
      }
      
      console.log('\n' + '='.repeat(60));
      console.log('✅ API test completed successfully!\n');
    } else {
      console.log('\n❌ FAILED to generate slots!');
      console.log(`   Error: ${creationResponse.message}`);
      console.log('\n💡 Troubleshooting:');
      console.log('   - Check if the date is in the future');
      console.log('   - Verify the time range is valid (8 AM - 6 PM)');
      console.log('   - Ensure no overlapping slots exist');
      console.log('\n' + '='.repeat(60));
      process.exit(1);
    }
    
  } catch (error) {
    console.log('\n❌ Test failed with error:', error.message);
    if (error.code === 'ECONNREFUSED') {
      console.log('\n💡 Backend server is not running!');
      console.log('   Start it with: cd backend_nodejs && node src/server.js');
    }
    console.log('\n' + '='.repeat(60));
    process.exit(1);
  }
}

runTest();
