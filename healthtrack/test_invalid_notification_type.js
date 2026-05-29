const http = require('http');

// Test sending notification with invalid notification type
const postData = JSON.stringify({
  userId: '1',
  notificationType: 'admin_appointment_notification',  // This is INVALID according to backend validation
  message: 'Test notification with invalid type',
  title: 'Invalid Type Test'
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

console.log('Testing notification with invalid type: admin_appointment_notification');

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