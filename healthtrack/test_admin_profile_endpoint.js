// Test script to verify the admin profile endpoint
const axios = require('axios');

async function testAdminProfileEndpoint() {
  const baseUrl = 'http://10.243.17.91:3000'; // Adjust this to your server URL
  
  console.log('🧪 Testing Admin Profile Endpoint');
  console.log('🌐 Base URL:', baseUrl);
  
  try {
    // Test getting admin profile with ID 1 (default admin)
    console.log('\n📋 Testing GET /admin/1');
    const response = await axios.get(`${baseUrl}/admin/1`);
    
    console.log('✅ Status:', response.status);
    console.log('✅ Response:', JSON.stringify(response.data, null, 2));
    
    if (response.data.success) {
      console.log('🎉 Admin profile fetched successfully!');
      console.log('👤 Admin ID:', response.data.admin.id);
      console.log('👤 Username:', response.data.admin.username);
      console.log('👤 Full Name:', response.data.admin.full_name || 'Not set');
      console.log('📧 Email:', response.data.admin.email || 'Not set');
    } else {
      console.log('❌ API returned success=false');
      console.log('📝 Message:', response.data.message);
    }
  } catch (error) {
    if (error.response) {
      console.log('❌ HTTP Error:', error.response.status);
      console.log('📝 Response:', JSON.stringify(error.response.data, null, 2));
    } else if (error.request) {
      console.log('❌ Network Error: Could not reach the server');
      console.log('🔧 Make sure the server is running at', baseUrl);
    } else {
      console.log('❌ Error:', error.message);
    }
  }
  
  console.log('\n🏁 Test completed');
}

// Run the test
testAdminProfileEndpoint();