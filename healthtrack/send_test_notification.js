const http = require('http');

// Send a test notification
const postData = JSON.stringify({
  userId: '1',
  notificationType: 'test',
  message: 'Test notification for dashboard verification',
  title: 'Dashboard Test'
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

console.log('Sending test notification...');

const req = http.request(options, (res) => {
  console.log(`Status code: ${res.statusCode}`);
  console.log(`Content-Type: ${res.headers['content-type']}`);
  
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    if (res.headers['content-type'] && res.headers['content-type'].includes('text/html')) {
      console.log('ERROR: Server returned HTML instead of JSON');
      console.log('Response body:', data);
    } else {
      console.log('SUCCESS: Server returned JSON');
      try {
        const jsonData = JSON.parse(data);
        console.log('Response:', JSON.stringify(jsonData, null, 2));
      } catch (e) {
        console.log('Response body:', data);
      }
    }
  });
});

req.on('error', (e) => {
  console.error('ERROR: Failed to connect to server:', e.message);
});

req.write(postData);
req.end();