// Test script for foreign key validation in slot generation
const axios = require('axios');

// Configuration
const BASE_URL = 'http://localhost:3000'; // Adjust to your server URL
const VALID_SERVICE_ID = 16; // Immunization service (exists)
const INVALID_SERVICE_ID = 999; // Non-existent service ID
const TEST_DATE = new Date(Date.now() + 86400000).toISOString().split('T')[0]; // Tomorrow's date
const START_TIME = '09:00:00';
const END_TIME = '17:00:00';
const MAX_PATIENTS = 10;

async function testForeignKeyValidation() {
  try {
    console.log('Testing foreign key validation...\n');
    
    // Test 1: Try to generate slots with an invalid service ID
    console.log('Test 1: Attempting to generate slots with invalid service ID...');
    try {
      const response = await axios.post(`${BASE_URL}/appointment-slots`, {
        service_id: INVALID_SERVICE_ID,
        appointment_date: TEST_DATE,
        start_time: START_TIME,
        end_time: END_TIME,
        slot_duration_minutes: 30,
        max_patients: MAX_PATIENTS,
        generate_slots: true
      });
      
      if (response.data.success) {
        console.log(`✗ Unexpected success: ${response.data.message}`);
      } else {
        console.log(`✓ Correctly rejected: ${response.data.message}`);
      }
    } catch (error) {
      if (error.response && error.response.data) {
        console.log(`✓ Correctly rejected: ${error.response.data.message}`);
      } else {
        console.log('✗ Unexpected error:', error.message);
      }
    }
    
    // Test 2: Generate slots with a valid service ID
    console.log('\nTest 2: Generating slots with valid service ID...');
    try {
      const response = await axios.post(`${BASE_URL}/appointment-slots`, {
        service_id: VALID_SERVICE_ID,
        appointment_date: TEST_DATE,
        start_time: START_TIME,
        end_time: END_TIME,
        slot_duration_minutes: 30,
        max_patients: MAX_PATIENTS,
        generate_slots: true
      });
      
      if (response.data.success) {
        console.log(`✓ Success: Generated ${response.data.data.length} slots`);
        console.log(`Message: ${response.data.message}`);
      } else {
        console.log(`✗ Failed: ${response.data.message}`);
      }
    } catch (error) {
      if (error.response && error.response.data) {
        console.log(`✗ Failed: ${error.response.data.message}`);
      } else {
        console.log('✗ Unexpected error:', error.message);
      }
    }
    
    console.log('\n=== Test Summary ===');
    console.log('Foreign key validation tests completed. Check results above.');
    
  } catch (error) {
    console.error('Test failed with error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  }
}

// Run the test
testForeignKeyValidation();