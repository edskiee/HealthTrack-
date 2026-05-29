const http = require('http');

// Test the dashboard endpoints
async function testDashboardEndpoints() {
  const baseUrl = 'http://10.243.17.91:3000';
  
  console.log('Testing dashboard endpoints...\n');
  
  // Test dashboard stats endpoint
  try {
    console.log('Testing /dashboard/stats endpoint...');
    const statsResponse = await makeRequest(`${baseUrl}/dashboard/stats`);
    console.log('Status:', statsResponse.statusCode);
    console.log('Response:', JSON.stringify(statsResponse.data, null, 2));
    console.log('---\n');
  } catch (error) {
    console.error('Error testing /dashboard/stats:', error.message);
    console.log('---\n');
  }
  
  // Test service config endpoint
  try {
    console.log('Testing /service-config endpoint...');
    const serviceConfigResponse = await makeRequest(`${baseUrl}/service-config`);
    console.log('Status:', serviceConfigResponse.statusCode);
    console.log('Response:', JSON.stringify(serviceConfigResponse.data, null, 2));
    console.log('---\n');
  } catch (error) {
    console.error('Error testing /service-config:', error.message);
    console.log('---\n');
  }
  
  // Test health workers endpoint
  try {
    console.log('Testing /health-workers endpoint...');
    const healthWorkersResponse = await makeRequest(`${baseUrl}/health-workers`);
    console.log('Status:', healthWorkersResponse.statusCode);
    console.log('Response:', JSON.stringify(healthWorkersResponse.data, null, 2));
    console.log('---\n');
  } catch (error) {
    console.error('Error testing /health-workers:', error.message);
    console.log('---\n');
  }
}

// Helper function to make HTTP requests
function makeRequest(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
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
        } catch (parseError) {
          reject(new Error(`Failed to parse JSON response: ${parseError.message}`));
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
testDashboardEndpoints();