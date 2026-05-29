const http = require('http');

// Test the administrative tools endpoints
async function testAdminTools() {
  const baseUrl = 'http://10.243.17.91:3000';
  
  console.log('Testing administrative tools endpoints...\n');
  
  // Test service config endpoints
  try {
    console.log('=== SERVICE CONFIG ENDPOINTS ===');
    
    // Test GET all services
    console.log('Testing GET /service-config endpoint...');
    const getAllServicesResponse = await makeRequest(`${baseUrl}/service-config`);
    console.log('Status:', getAllServicesResponse.statusCode);
    console.log('Success:', getAllServicesResponse.data.success);
    console.log('Services count:', getAllServicesResponse.data.data ? getAllServicesResponse.data.data.length : 0);
    console.log('---\n');
    
    // Test GET service by ID (first service)
    if (getAllServicesResponse.data.data && getAllServicesResponse.data.data.length > 0) {
      const firstServiceId = getAllServicesResponse.data.data[0].id;
      console.log(`Testing GET /service-config/${firstServiceId} endpoint...`);
      const getServiceResponse = await makeRequest(`${baseUrl}/service-config/${firstServiceId}`);
      console.log('Status:', getServiceResponse.statusCode);
      console.log('Success:', getServiceResponse.data.success);
      console.log('Service name:', getServiceResponse.data.data ? getServiceResponse.data.data.service_name : 'N/A');
      console.log('---\n');
    }
    
  } catch (error) {
    console.error('Error testing service config endpoints:', error.message);
    console.log('---\n');
  }
  
  // Test health workers endpoints
  try {
    console.log('=== HEALTH WORKERS ENDPOINTS ===');
    
    // Test GET all health workers
    console.log('Testing GET /health-workers endpoint...');
    const getAllWorkersResponse = await makeRequest(`${baseUrl}/health-workers`);
    console.log('Status:', getAllWorkersResponse.statusCode);
    console.log('Success:', getAllWorkersResponse.data.success);
    console.log('Workers count:', getAllWorkersResponse.data.data ? getAllWorkersResponse.data.data.length : 0);
    console.log('---\n');
    
    // Test GET health worker by ID (first worker)
    if (getAllWorkersResponse.data.data && getAllWorkersResponse.data.data.length > 0) {
      const firstWorkerId = getAllWorkersResponse.data.data[0].id;
      console.log(`Testing GET /health-workers/${firstWorkerId} endpoint...`);
      const getWorkerResponse = await makeRequest(`${baseUrl}/health-workers/${firstWorkerId}`);
      console.log('Status:', getWorkerResponse.statusCode);
      console.log('Success:', getWorkerResponse.data.success);
      console.log('Worker name:', getWorkerResponse.data.data ? getWorkerResponse.data.data.worker_name : 'N/A');
      console.log('---\n');
    }
    
  } catch (error) {
    console.error('Error testing health workers endpoints:', error.message);
    console.log('---\n');
  }
  
  console.log('✅ Administrative tools testing completed!');
}

// Helper function to make HTTP requests
function makeRequest(url, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    };
    
    if (data) {
      options.headers['Content-Length'] = Buffer.byteLength(JSON.stringify(data));
    }
    
    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(responseData);
          resolve({
            statusCode: res.statusCode,
            data: jsonData
          });
        } catch (parseError) {
          reject(new Error(`Failed to parse JSON response: ${parseError.message}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Run the test
testAdminTools();