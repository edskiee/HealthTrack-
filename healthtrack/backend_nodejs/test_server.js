// Simple test script to verify server endpoints
const axios = require('axios');

// Test the root endpoint
async function testRootEndpoint() {
    try {
        const response = await axios.get('http://localhost:3000/');
        console.log('✅ Root endpoint test passed:');
        console.log(response.data);
    } catch (error) {
        console.error('❌ Root endpoint test failed:');
        console.error(error.message);
    }
}

// Test the admin login endpoint (correct path)
async function testAdminLoginEndpoint() {
    try {
        // This should return 400 since we're not sending required data
        const response = await axios.post('http://localhost:3000/admin/login');
        console.log('✅ Admin login endpoint test passed:');
        console.log(response.data);
    } catch (error) {
        // We expect a 400 error since we didn't send required data
        if (error.response && error.response.status === 400) {
            console.log('✅ Admin login endpoint is accessible (returned 400 as expected):');
            console.log(error.response.data);
        } else {
            console.error('❌ Admin login endpoint test failed:');
            console.error(error.message);
        }
    }
}

// Test the admin login endpoint (incorrect path that user might try)
async function testIncorrectAdminLoginEndpoint() {
    try {
        const response = await axios.post('http://localhost:3000/api/admin/login');
        console.log('Unexpected success for incorrect path:');
        console.log(response.data);
    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.log('✅ Correctly rejected incorrect path /api/admin/login with 404');
        } else {
            console.error('❌ Unexpected error for incorrect path:');
            console.error(error.message);
        }
    }
}

// Run all tests
async function runTests() {
    console.log('🧪 Testing HealthTrack API endpoints...\n');
    
    await testRootEndpoint();
    console.log(); // Empty line for spacing
    
    await testAdminLoginEndpoint();
    console.log(); // Empty line for spacing
    
    await testIncorrectAdminLoginEndpoint();
    console.log(); // Empty line for spacing
    
    console.log('🏁 Test completed!');
}

// Run the tests
runTests();