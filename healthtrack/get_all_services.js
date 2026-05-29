const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/service-config',
  method: 'GET'
};

const req = http.request(options, res => {
  let data = '';
  
  res.on('data', chunk => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
    process.exit(0);
  });
});

req.on('error', error => {
  console.error('Error:', error);
  process.exit(1);
});

req.end();