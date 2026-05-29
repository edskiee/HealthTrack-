const http = require('http');

async function testSlotGeneration() {
  console.log('🧪 Testing slot generation with GenerateSlotsSafely procedure...');
  
  try {
    const data = JSON.stringify({
      service_id: 16,
      appointment_date: '2026-03-14',
      start_time: '09:00:00',
      end_time: '10:00:00',
      slot_duration_minutes: 30,
      max_patients: 10,
      generate_slots: true
    });
    
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/api/appointment-slots',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    };
    
    const response = await new Promise((resolve, reject) => {
      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          try {
            resolve({
              statusCode: res.statusCode,
              data: JSON.parse(body)
            });
          } catch (error) {
            reject(error);
          }
        });
      });
      
      req.on('error', reject);
      req.write(data);
      req.end();
    });
    
    if (response.statusCode === 201 && response.data.success) {
      console.log('✅ SUCCESS: Slot generation working!');
      console.log(`📊 Generated ${response.data.data?.length || 0} slots`);
      console.log('📝 Message:', response.data.message);
      return true;
    } else {
      console.log('❌ FAILED: Slot generation failed');
      console.log('📝 Error:', response.data.message || 'Unknown error');
      console.log('🔢 Status:', response.statusCode);
      return false;
    }
  } catch (error) {
    console.error('❌ ERROR:', error.message);
    return false;
  }
}

testSlotGeneration().then(success => {
  console.log(`\n🏁 Test ${success ? 'PASSED' : 'FAILED'}!`);
  process.exit(success ? 0 : 1);
});
