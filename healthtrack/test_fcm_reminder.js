const http = require('http');

// Test the FCM notification endpoints
const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/fcm-notifications/check-patient-token',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  }
};

const testData = JSON.stringify({
  patientId: '78' // Test with patient ID 78
});

const req = http.request(options, (res) => {
  console.log(`Status: ${res.statusCode}`);
  
  res.on('data', (chunk) => {
    console.log(`Body: ${chunk}`);
  });
  
  res.on('end', () => {
    console.log('Test completed');
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(testData);
req.end();