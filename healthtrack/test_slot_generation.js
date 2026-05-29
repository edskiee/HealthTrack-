// Test script for slot generation functionality
const axios = require('axios');

// Configuration
const BASE_URL = 'http://localhost:3000'; // Adjust to your server URL
const TEST_SERVICE_ID = 16; // Immunization service
const TEST_DATE = new Date(Date.now() + 86400000).toISOString().split('T')[0]; // Tomorrow's date
const START_TIME = '09:00:00';
const END_TIME = '17:00:00';
const MAX_PATIENTS = 10;

async function testSlotGeneration() {
  try {
    console.log('Testing slot generation...\n');
    
    // Test 1: Generate slots with valid parameters
    console.log('Test 1: Generating slots with valid parameters...');
    // Use a different date to avoid conflicts
    const testDate1 = new Date(Date.now() + 172800000).toISOString().split('T')[0]; // Day after tomorrow
    const response = await axios.post(`${BASE_URL}/appointment-slots`, {
      service_id: TEST_SERVICE_ID,
      appointment_date: testDate1,
      start_time: START_TIME,
      end_time: END_TIME,
      slot_duration_minutes: 30,
      max_patients: MAX_PATIENTS,
      generate_slots: true
    });
    
    if (response.data.success) {
      console.log(`✓ Success: Generated ${response.data.data.length} slots`);
      console.log(`Message: ${response.data.message}\n`);
    } else {
      console.log(`✗ Failed: ${response.data.message}\n`);
    }
    
    // Test 2: Try to generate slots with insufficient time range (now minimum 1 slot)
    console.log('Test 2: Attempting to generate slots with insufficient time range...');
    try {
      // Use a different date to avoid conflicts
      const testDate2 = new Date(Date.now() + 259200000).toISOString().split('T')[0]; // 3 days from now
      const shortResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
        service_id: TEST_SERVICE_ID,
        appointment_date: testDate2,
        start_time: '09:00:00',
        end_time: '09:10:00', // Only 10 minutes, not enough for even 1 slot
        slot_duration_minutes: 30,
        max_patients: MAX_PATIENTS,
        generate_slots: true
      });
      
      if (shortResponse.data.success) {
        console.log(`✗ Unexpected success: ${shortResponse.data.message}`);
      } else {
        console.log(`✓ Correctly rejected: ${shortResponse.data.message}`);
      }
    } catch (error) {
      if (error.response && error.response.data) {
        console.log(`✓ Correctly rejected: ${error.response.data.message}`);
      } else {
        console.log('✗ Unexpected error:', error.message);
      }
    }
    
    // Test 3: Try to generate slots for a past date
    console.log('\nTest 3: Attempting to generate slots for a past date...');
    try {
      const pastDate = new Date(Date.now() - 86400000).toISOString().split('T')[0]; // Yesterday's date
      const pastResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
        service_id: TEST_SERVICE_ID,
        appointment_date: pastDate,
        start_time: START_TIME,
        end_time: END_TIME,
        slot_duration_minutes: 30,
        max_patients: MAX_PATIENTS,
        generate_slots: true
      });
      
      if (pastResponse.data.success) {
        console.log(`✗ Unexpected success: ${pastResponse.data.message}`);
      } else {
        console.log(`✓ Correctly rejected: ${pastResponse.data.message}`);
      }
    } catch (error) {
      if (error.response && error.response.data) {
        console.log(`✓ Correctly rejected: ${error.response.data.message}`);
      } else {
        console.log('✗ Unexpected error:', error.message);
      }
    }
    
    // Test 4: Try to generate duplicate slots for the same service and date
    console.log('\nTest 4: Attempting to generate duplicate slots for the same service and date...');
    try {
      // Use the same date as test 1 to trigger duplicate prevention
      const testDate1 = new Date(Date.now() + 172800000).toISOString().split('T')[0]; // Day after tomorrow
      const duplicateResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
        service_id: TEST_SERVICE_ID,
        appointment_date: testDate1,
        start_time: '10:00:00',
        end_time: '18:00:00',
        slot_duration_minutes: 30,
        max_patients: MAX_PATIENTS,
        generate_slots: true
      });
      
      if (duplicateResponse.data.success) {
        console.log(`✗ Unexpected success: ${duplicateResponse.data.message}`);
      } else {
        console.log(`✓ Correctly rejected duplicate slots: ${duplicateResponse.data.message}`);
      }
    } catch (error) {
      if (error.response && error.response.data) {
        console.log(`✓ Correctly rejected duplicate slots: ${error.response.data.message}`);
      } else {
        console.log('✗ Unexpected error:', error.message);
      }
    }
    
    console.log('\n=== Test Summary ===');
    console.log('Slot generation tests completed. Check results above.');
    
  } catch (error) {
    console.error('Test failed with error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  }
}

// Run the test
testSlotGeneration();