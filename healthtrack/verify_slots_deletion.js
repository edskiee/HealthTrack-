/**
 * Verify Appointment Slots Deletion
 * Simple script to check if all appointment slots have been deleted
 */

const http = require('http');

const BASE_URL = 'http://localhost:3000';

function makeRequest(options) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            body: data
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

async function verifySlots() {
  console.log('🔍 Verifying appointment slots deletion...\n');
  
  const options = {
    hostname: new URL(BASE_URL).hostname,
    port: new URL(BASE_URL).port || 80,
    path: '/appointment-slots/user-view',
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode === 200 && response.body.success) {
      const count = response.body.data.length;
      
      console.log(`✅ Verification Result:`);
      console.log(`   Total appointment slots in database: ${count}`);
      
      if (count === 0) {
        console.log('\n✅ SUCCESS: All appointment slots have been completely removed!');
        console.log('ℹ️  No slots are currently displayed in the system.');
        console.log('ℹ️  Administrators can generate new slots at any time.\n');
      } else {
        console.log(`\n⚠️  Warning: ${count} slots still remain:`);
        response.body.data.forEach((slot, index) => {
          console.log(`   ${index + 1}. ID=${slot.id}, Service=${slot.service_id}, Date=${slot.appointment_date}`);
        });
        console.log('');
      }
      
      return count === 0;
    } else {
      console.log(`❌ Error: Could not verify deletion`);
      console.log(`   Response:`, response.body);
      return false;
    }
  } catch (error) {
    console.log(`❌ Error: ${error.message}`);
    return false;
  }
}

verifySlots();
