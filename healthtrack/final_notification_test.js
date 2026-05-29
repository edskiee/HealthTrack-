const http = require('http');

// Test with the actual configured base URL from the frontend
const postData = JSON.stringify({
  userId: '1',
  patientId: '1',
  notificationType: 'custom_message',
  message: 'Final test message to verify the fix',
  title: 'Final Test'
});

const options = {
  hostname: '10.243.17.91', // Using the actual configured IP
  port: 3000,
  path: '/admin/notifications/send',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Testing notification endpoint with configured IP address...');
console.log('Target: http://10.243.17.91:3000/admin/notifications/send');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    try {
      const jsonData = JSON.parse(data);
      console.log('Response:', JSON.stringify(jsonData, null, 2));
      
      if (res.statusCode === 200 && jsonData.success) {
        console.log('✅ SUCCESS: Notification system is working correctly!');
      } else {
        console.log('❌ ISSUE: Notification system returned an error');
      }
    } catch (e) {
      console.log('Raw response (not JSON):', data);
    }
  });
});

req.on('error', (e) => {
  console.error('❌ CONNECTION ERROR:', e.message);
  console.log('This indicates the server is not accessible at the configured IP address.');
  console.log('Possible solutions:');
  console.log('1. Check if the server is running');
  console.log('2. Verify the IP address configuration');
  console.log('3. Check network connectivity');
});

req.write(postData);
req.end();