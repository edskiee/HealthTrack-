const http = require('http');

// Test sending notification with valid notification type (should now work)
const postData = JSON.stringify({
  userId: '1',
  notificationType: 'admin_appointment_notification',  // This should now be VALID
  message: 'Test notification with valid type',
  title: 'Valid Type Test'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/admin/notifications/send',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('Testing notification with valid type: admin_appointment_notification');

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
    } catch (e) {
      console.log('Response body:', data);
    }
  });
});

req.on('error', (e) => {
  console.error('ERROR:', e.message);
});

req.write(postData);
req.end();