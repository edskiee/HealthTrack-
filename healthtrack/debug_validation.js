// Debug test for backend validation
const http = require('http');

function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          console.log('Raw response:', data);
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

async function debugValidation() {
  console.log('🔍 Debugging Backend Validation');
  console.log('='.repeat(40));
  
  // Test 1: Check if services are available
  try {
    const serviceOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/service-config',
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    };
    
    const serviceResponse = await makeRequest(serviceOptions);
    console.log('Services response:', serviceResponse.statusCode);
    console.log('Services data:', serviceResponse.body);
    
    if (!serviceResponse.body?.data?.length) {
      console.log('❌ No services found');
      return;
    }
    
    const service = serviceResponse.body.data[0];
    const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
    
    // Test 2: Test invalid duration (negative)
    console.log('\n🧪 Testing negative duration...');
    const slotOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/appointment-slots',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    };
    
    const slotData = JSON.stringify({
      service_id: service.id,
      appointment_date: tomorrow,
      start_time: '09:00:00',
      end_time: '10:00:00',
      slot_duration_minutes: -15, // This should be rejected
      max_patients: 10,
      generate_slots: true
    });
    
    const slotResponse = await makeRequest(slotOptions, slotData);
    console.log('Status:', slotResponse.statusCode);
    console.log('Response:', slotResponse.body);
    
    // Test 3: Test time range validation
    console.log('\n🧪 Testing invalid time range...');
    const timeRangeData = JSON.stringify({
      service_id: service.id,
      appointment_date: tomorrow,
      start_time: '17:00:00', // Later time
      end_time: '09:00:00',   // Earlier time
      slot_duration_minutes: 30,
      max_patients: 10,
      generate_slots: true
    });
    
    const timeRangeResponse = await makeRequest(slotOptions, timeRangeData);
    console.log('Status:', timeRangeResponse.statusCode);
    console.log('Response:', timeRangeResponse.body);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
}

debugValidation();