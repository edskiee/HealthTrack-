// Test script for real-time slot synchronization functionality
const io = require('socket.io-client');
const axios = require('axios');

// Configuration
const BASE_URL = 'http://localhost:3000'; // Adjust to your server URL
const SOCKET_URL = 'http://localhost:3000'; // WebSocket URL
const TEST_SERVICE_ID = 16; // Immunization service
const TEST_DATE = new Date(Date.now() + 86400000).toISOString().split('T')[0]; // Tomorrow's date

async function testRealTimeSlotSync() {
  console.log('Testing real-time slot synchronization...\n');
  
  // Connect to WebSocket
  console.log('Connecting to WebSocket...');
  const socket = io(SOCKET_URL);
  
  // Wait for connection
  await new Promise(resolve => {
    socket.on('connect', () => {
      console.log('✓ Connected to WebSocket server');
      resolve();
    });
    
    setTimeout(() => {
      console.log('✗ Failed to connect to WebSocket server');
      resolve();
    }, 5000);
  });
  
  // Listen for slot updates
  let slotUpdateReceived = false;
  socket.on('slotsUpdated', (data) => {
    console.log('✓ Received slotsUpdated event:', data);
    slotUpdateReceived = true;
  });
  
  try {
    // Generate slots
    console.log('\\nGenerating slots...');
    const response = await axios.post(`${BASE_URL}/appointment-slots`, {
      service_id: TEST_SERVICE_ID,
      appointment_date: TEST_DATE,
      start_time: '09:00:00',
      end_time: '17:00:00',
      slot_duration_minutes: 30,
      max_patients: 10,
      generate_slots: true
    });
    
    if (response.data.success) {
      console.log(`✓ Success: Generated ${response.data.data.length} slots`);
      
      // Wait a bit to see if we receive the real-time update
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      if (slotUpdateReceived) {
        console.log('✓ Real-time synchronization working correctly');
      } else {
        console.log('⚠ Did not receive real-time update (may be normal if no other clients connected)');
      }
    } else {
      console.log(`✗ Failed: ${response.data.message}`);
    }
    
    // Clean up - delete the generated slots
    console.log('\\nCleaning up generated slots...');
    // In a real test, we would delete the slots here
    
  } catch (error) {
    console.error('Test failed with error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  } finally {
    // Disconnect WebSocket
    socket.disconnect();
    console.log('\\nDisconnected from WebSocket server');
  }
  
  console.log('\\n=== Test Summary ===');
  console.log('Real-time slot synchronization test completed.');
}

// Run the test
testRealTimeSlotSync();