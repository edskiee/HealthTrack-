const http = require('http');

// Helper function to make HTTP requests
function makeRequest(options) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve({ status: res.statusCode, data: jsonData });
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${e.message}`));
        }
      });
    });

    req.on('error', (e) => {
      reject(new Error(`Request failed: ${e.message}`));
    });

    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

// Check available services
async function checkServices() {
  console.log('🔍 Checking available services...');
  
  try {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: '/service-config',
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const result = await makeRequest(options);
    console.log(`Status: ${result.status}`);
    console.log('Response:', JSON.stringify(result.data, null, 2));
    
    if (result.status === 200 && result.data.success) {
      console.log('\n✅ Available Services:');
      console.log('==================');
      result.data.data.forEach((service, index) => {
        console.log(`${index + 1}. ID: ${service.id}, Name: ${service.service_name}, Type: ${service.service_type}, Enabled: ${service.is_enabled}`);
      });
      
      // Find first enabled service
      const firstEnabledService = result.data.data.find(service => service.is_enabled);
      if (firstEnabledService) {
        console.log(`\n🎯 First enabled service: ID ${firstEnabledService.id} (${firstEnabledService.service_name})`);
        return firstEnabledService.id;
      } else {
        console.log('\n❌ No enabled services found');
        return null;
      }
    } else {
      console.log('❌ Failed to fetch services');
      return null;
    }
  } catch (error) {
    console.error('❌ Error checking services:', error.message);
    return null;
  }
}

// Run the check
checkServices();
