const axios = require('axios');

// Test maternal care registration with different civil statuses
async function testMaternalRegistration() {
  const baseUrl = 'http://localhost:3000/api'; // Adjust if needed
  
  // Test data for Single status (should not require pregnancy info)
  const singleUserData = {
    username: 'single_mother_test',
    password: 'password123',
    email: 'single@test.com',
    serviceType: 'maternal',
    motherName: 'Single Mother',
    dob: '1990-01-01',
    education: 'College',
    occupation: 'Teacher',
    status: 'Single', // Single status - should not require pregnancy info
    religion: 'Christian',
    address: 'Test Address',
    contact: '1234567890',
    age: '30',
    // No pregnancy info required for Single status
    recordType: 'Maternal Care',
    recordDescription: 'Test maternal care record for single mother'
  };
  
  // Test data for Married status (should require pregnancy info)
  const marriedUserData = {
    username: 'married_mother_test',
    password: 'password123',
    email: 'married@test.com',
    serviceType: 'maternal',
    motherName: 'Married Mother',
    dob: '1985-05-15',
    education: 'High School',
    occupation: 'Nurse',
    status: 'Married', // Married status - should require pregnancy info
    religion: 'Catholic',
    address: 'Married Address',
    contact: '0987654321',
    age: '35',
    // Pregnancy info required for Married status
    spouseName: 'Spouse Name',
    spouseDob: '1983-03-10',
    spouseEducation: 'Bachelor',
    spouseOccupation: 'Engineer',
    monthlyIncome: '50000',
    livingChildrenCount: '2',
    birthPlan: 'Hospital',
    recordType: 'Maternal Care',
    recordDescription: 'Test maternal care record for married mother'
  };
  
  try {
    console.log('Testing maternal registration for Single status...');
    const singleResponse = await axios.post(`${baseUrl}/auth/register`, singleUserData);
    console.log('Single status registration result:', singleResponse.data.success ? 'SUCCESS' : 'FAILED');
    console.log('Message:', singleResponse.data.message);
    
    console.log('\nTesting maternal registration for Married status...');
    const marriedResponse = await axios.post(`${baseUrl}/auth/register`, marriedUserData);
    console.log('Married status registration result:', marriedResponse.data.success ? 'SUCCESS' : 'FAILED');
    console.log('Message:', marriedResponse.data.message);
    
    console.log('\n✅ All tests completed successfully!');
  } catch (error) {
    console.error('❌ Test failed:', error.response ? error.response.data : error.message);
  }
}

// Run the test
testMaternalRegistration();