const http = require('http');

// Test service filtering
async function testServiceFiltering() {
  console.log('Testing service filtering...\n');
  
  // Test without filter (should return all services)
  console.log('1. Testing without filter:');
  try {
    const allServicesResponse = await makeRequest('http://localhost:3000/service-config');
    console.log('Status:', allServicesResponse.statusCode);
    console.log('Services count:', allServicesResponse.data.data ? allServicesResponse.data.data.length : 0);
    if (allServicesResponse.data.data) {
      console.log('Service types:', allServicesResponse.data.data.map(s => s.service_type));
    }
    console.log('---\n');
  } catch (error) {
    console.error('Error:', error.message);
    console.log('---\n');
  }
  
  // Test with immunization filter
  console.log('2. Testing with immunization filter:');
  try {
    const immunizationResponse = await makeRequest('http://localhost:3000/service-config?service_type=immunization');
    console.log('Status:', immunizationResponse.statusCode);
    console.log('Services count:', immunizationResponse.data.data ? immunizationResponse.data.data.length : 0);
    if (immunizationResponse.data.data) {
      console.log('Service types:', immunizationResponse.data.data.map(s => s.service_type));
    }
    console.log('---\n');
  } catch (error) {
    console.error('Error:', error.message);
    console.log('---\n');
  }
  
  // Test with maternal filter
  console.log('3. Testing with maternal filter:');
  try {
    const maternalResponse = await makeRequest('http://localhost:3000/service-config?service_type=maternal');
    console.log('Status:', maternalResponse.statusCode);
    console.log('Services count:', maternalResponse.data.data ? maternalResponse.data.data.length : 0);
    if (maternalResponse.data.data) {
      console.log('Service types:', maternalResponse.data.data.map(s => s.service_type));
    }
    console.log('---\n');
  } catch (error) {
    console.error('Error:', error.message);
    console.log('---\n');
  }
}

// Helper function to make HTTP requests
function makeRequest(url) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: new URL(url).pathname + new URL(url).search,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const req = http.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({
            statusCode: res.statusCode,
            data: jsonData
          });
        } catch (error) {
          reject(error);
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.end();
  });
}

// Run the test
testServiceFiltering();