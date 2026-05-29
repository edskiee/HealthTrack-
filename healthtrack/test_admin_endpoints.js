// Test script for admin endpoints
const axios = require('axios');

// Configure axios defaults
const api = axios.create({
    baseURL: 'http://localhost:3000',
    timeout: 5000,
});

// Test data
const testAdmin = {
    username: 'testadmin',
    password: 'testpass123'
};

async function testRootEndpoint() {
    try {
        console.log('Testing root endpoint...');
        const response = await api.get('/');
        console.log('✅ Root endpoint:', response.data.message);
        return true;
    } catch (error) {
        console.error('❌ Root endpoint failed:', error.message);
        return false;
    }
}

async function testAdminLoginMissingData() {
    try {
        console.log('\nTesting admin login with missing data...');
        await api.post('/admin/login');
    } catch (error) {
        if (error.response && error.response.status === 400) {
            console.log('✅ Admin login correctly rejected missing data:', error.response.data.message);
            return true;
        } else {
            console.error('❌ Unexpected response for missing data:', error.message);
            return false;
        }
    }
}

async function testAdminRegisterMissingData() {
    try {
        console.log('\nTesting admin register with missing data...');
        await api.post('/admin/register');
    } catch (error) {
        if (error.response && error.response.status === 400) {
            console.log('✅ Admin register correctly rejected missing data:', error.response.data.message);
            return true;
        } else {
            console.error('❌ Unexpected response for missing data:', error.message);
            return false;
        }
    }
}

async function testIncorrectPath() {
    try {
        console.log('\nTesting incorrect path /api/admin/login...');
        await api.post('/api/admin/login');
        console.error('❌ Incorrect path should have failed');
        return false;
    } catch (error) {
        if (error.response && error.response.status === 404) {
            console.log('✅ Incorrect path correctly returned 404');
            return true;
        } else {
            console.error('❌ Unexpected error for incorrect path:', error.message);
            return false;
        }
    }
}

async function runAllTests() {
    console.log('🧪 Running HealthTrack Admin Endpoint Tests\n');
    
    let passedTests = 0;
    const totalTests = 4;
    
    if (await testRootEndpoint()) passedTests++;
    if (await testAdminLoginMissingData()) passedTests++;
    if (await testAdminRegisterMissingData()) passedTests++;
    if (await testIncorrectPath()) passedTests++;
    
    console.log(`\n🏁 Test Results: ${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
        console.log('🎉 All tests passed! The server routing is working correctly.');
        console.log('\n📝 Remember:');
        console.log('   - Use http://localhost:3000/admin/login for admin login');
        console.log('   - NOT http://localhost:3000/api/admin/login');
    } else {
        console.log('❌ Some tests failed. Please check the server configuration.');
    }
}

// Run the tests
runAllTests().catch(error => {
    console.error('💥 Test suite failed with an unexpected error:');
    console.error(error.message);
});