const http = require('http');

async function testConnection() {
  console.log('🔗 Testing server connection...');
  
  try {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/api/appointment-slots',
      method: 'GET'
    };
    
    const response = await new Promise((resolve, reject) => {
      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: body
          });
        });
      });
      
      req.on('error', reject);
      req.end();
    });
    
    console.log('📊 Status:', response.statusCode);
    console.log('📝 Content-Type:', response.headers['content-type']);
    console.log('📄 Body preview:', response.body.substring(0, 200));
    
    return response.statusCode === 200;
  } catch (error) {
    console.error('❌ ERROR:', error.message);
    return false;
  }
}

testConnection().then(success => {
  console.log(`\n🏁 Connection test ${success ? 'PASSED' : 'FAILED'}!`);
});
