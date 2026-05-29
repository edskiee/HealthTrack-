const http = require('http');
const crypto = require('crypto');

// Test configuration
const SERVER_HOST = 'localhost';
const SERVER_PORT = 3000;

// Test data
const testAdmin = {
  username: 'testadmin_' + Math.random().toString(36).substring(7),
  password: 'testpass123'
};

console.log('🧪 Testing Admin Functionality\n');

// Function to make HTTP requests
function makeRequest(options, postData) {
  return new Promise((resolve, reject) => {
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
            headers: res.headers,
            data: jsonData
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: data
          });
        }
      });
    });
    
    req.on('error', (e) => {
      reject(e);
    });
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Test 1: Register a new admin
async function testAdminRegistration() {
  console.log('📝 Test 1: Admin Registration');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/admin/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify({
    username: testAdmin.username,
    password: testAdmin.password
  });
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Response: ${JSON.stringify(response.data)}`);
    
    if (response.statusCode === 200 && response.data.success) {
      console.log('   ✅ Registration successful\n');
      return true;
    } else {
      console.log('   ❌ Registration failed\n');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Registration error: ${error.message}\n`);
    return false;
  }
}

// Test 2: Login with the registered admin
async function testAdminLogin() {
  console.log('🔐 Test 2: Admin Login');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/admin/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify({
    username: testAdmin.username,
    password: testAdmin.password
  });
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Response: ${JSON.stringify(response.data)}`);
    
    if (response.statusCode === 200 && response.data.success) {
      console.log('   ✅ Login successful\n');
      return true;
    } else {
      console.log('   ❌ Login failed\n');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Login error: ${error.message}\n`);
    return false;
  }
}

// Test 3: Login with invalid credentials
async function testInvalidLogin() {
  console.log('🔒 Test 3: Invalid Login');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/admin/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify({
    username: 'invaliduser',
    password: 'invalidpass'
  });
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Response: ${JSON.stringify(response.data)}`);
    
    if (response.statusCode === 401 && !response.data.success) {
      console.log('   ✅ Invalid login properly rejected\n');
      return true;
    } else {
      console.log('   ❌ Invalid login not handled correctly\n');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Invalid login error: ${error.message}\n`);
    return false;
  }
}

// Test 4: Registration with duplicate username
async function testDuplicateRegistration() {
  console.log('👥 Test 4: Duplicate Registration');
  
  const options = {
    hostname: SERVER_HOST,
    port: SERVER_PORT,
    path: '/admin/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const postData = JSON.stringify({
    username: testAdmin.username,
    password: testAdmin.password
  });
  
  try {
    const response = await makeRequest(options, postData);
    console.log(`   Status: ${response.statusCode}`);
    console.log(`   Response: ${JSON.stringify(response.data)}`);
    
    if (response.statusCode === 409 && !response.data.success) {
      console.log('   ✅ Duplicate registration properly rejected\n');
      return true;
    } else {
      console.log('   ❌ Duplicate registration not handled correctly\n');
      return false;
    }
  } catch (error) {
    console.log(`   ❌ Duplicate registration error: ${error.message}\n`);
    return false;
  }
}

// Run all tests
async function runAllTests() {
  console.log(`🚀 Starting tests on http://${SERVER_HOST}:${SERVER_PORT}\n`);
  
  let passedTests = 0;
  const totalTests = 4;
  
  // Test 1: Registration
  if (await testAdminRegistration()) passedTests++;
  
  // Test 2: Valid login
  if (await testAdminLogin()) passedTests++;
  
  // Test 3: Invalid login
  if (await testInvalidLogin()) passedTests++;
  
  // Test 4: Duplicate registration
  if (await testDuplicateRegistration()) passedTests++;
  
  console.log(`\n🏁 Test Results: ${passedTests}/${totalTests} tests passed`);
  
  if (passedTests === totalTests) {
    console.log('🎉 All tests passed! Admin functionality is working correctly.');
  } else {
    console.log('⚠️  Some tests failed. Please check the implementation.');
  }
}

// Run the tests
runAllTests();