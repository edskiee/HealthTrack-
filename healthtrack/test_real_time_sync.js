// Test script for real-time synchronization between admin and user
const io = require('socket.io-client');
const axios = require('axios');

// Configuration
const SERVER_URL = 'http://localhost:3000'; // Adjust to your server URL
const TEST_SERVICE_ID = 18; // Immunization service
const TEST_DATE = '2026-01-28'; // A future date
const START_TIME = '09:00:00';
const END_TIME = '17:00:00';
const MAX_PATIENTS = 10;

// Connect to WebSocket server
const socket = io(SERVER_URL);

socket.on('connect', () => {
  console.log('🟢 Connected to WebSocket server');
  
  // Listen for slot updates
  socket.on('slotsUpdated', (data) => {
    console.log('🔄 Received slotsUpdated event:', data);
  });
});

socket.on('disconnect', () => {
  console.log('🔴 Disconnected from WebSocket server');
});

async function testRealTimeSync() {
  try {
    console.log('Testing real-time synchronization...\n');
    
    // Test: Generate slots and check if event is emitted
    console.log('Step 1: Generating slots...');
    const response = await axios.post(`${SERVER_URL}/appointment-slots`, {
      service_id: TEST_SERVICE_ID,
      appointment_date: TEST_DATE,
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
    
    // Wait a bit to see if the WebSocket event is received
    console.log('Step 2: Waiting for real-time update events...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    console.log('\nStep 3: Checking if slots are available via API...');
    const slotsResponse = await axios.get(`${SERVER_URL}/appointment-slots`, {
      params: {
        serviceId: TEST_SERVICE_ID,
        date: TEST_DATE
      }
    });
    
    if (slotsResponse.data.success) {
      console.log(`✓ Found ${slotsResponse.data.data.length} slots for the date`);
    } else {
      console.log(`✗ Failed to fetch slots: ${slotsResponse.data.message}`);
    }
    
    console.log('\n=== Test Summary ===');
    console.log('Real-time synchronization test completed.');
    console.log('Check console output for WebSocket events.');
    
  } catch (error) {
    console.error('Test failed with error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  } finally {
    socket.disconnect();
  }
}

// Run the test after a short delay to allow WebSocket connection
setTimeout(testRealTimeSync, 1000);
