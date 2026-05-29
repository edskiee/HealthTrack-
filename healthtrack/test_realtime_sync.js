const io = require('socket.io-client');
const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000';

async function testRealtimeSync() {
  console.log('📡 Starting Real-time Synchronization Test...\n');
  
  try {
    // Connect to WebSocket
    console.log('🔌 Connecting to WebSocket server...');
    const socket = io(BASE_URL.replace('http', 'ws'), {
      transports: ['websocket'],
      reconnection: false
    });

    // Track events
    let slotUpdateReceived = false;
    let expectedEvent = null;
    
    // Set up listeners
    socket.on('connect', () => {
      console.log('✅ WebSocket connected successfully');
    });
    
    socket.on('slotsUpdated', (data) => {
      console.log('🔄 Received slotsUpdated event:', data);
      slotUpdateReceived = true;
      if (expectedEvent && expectedEvent.action === data.action) {
        console.log('✅ Expected event received:', expectedEvent.action);
      }
    });
    
    socket.on('connect_error', (error) => {
      console.log('❌ WebSocket connection error:', error);
    });
    
    socket.on('error', (error) => {
      console.log('❌ WebSocket error:', error);
    });
    
    // Wait for connection
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    if (!socket.connected) {
      console.log('❌ WebSocket connection failed');
      return;
    }
    
    // Test 1: Create a slot and verify real-time update
    console.log('\n🆕 Test 1: Creating slot and verifying real-time update...');
    
    // Prepare slot data
    const servicesResponse = await axios.get(`${BASE_URL}/service-config`);
    const servicesData = servicesResponse.data;
    
    const immunizationService = servicesData.data.find(s => 
      s.service_name.toLowerCase().includes('immunization') || 
      s.service_name.toLowerCase().includes('maternal')
    );
    
    if (!immunizationService) {
      console.log('⚠️  No immunization or maternal service found');
      socket.disconnect();
      return;
    }
    
    console.log(`Using service: ${immunizationService.service_name} (ID: ${immunizationService.id})`);
    
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 3);
    const dateString = futureDate.toISOString().split('T')[0];
    
    // Set expectation
    expectedEvent = { action: 'created' };
    slotUpdateReceived = false;
    
    // Create slot
    const slotData = {
      service_id: immunizationService.id,
      appointment_date: dateString,
      start_time: '14:00:00',
      end_time: '15:00:00',
      slot_duration_minutes: 30,
      max_patients: 3,
      generate_slots: false
    };
    
    console.log('Creating slot:', slotData);
    
    const response = await axios.post(`${BASE_URL}/appointment-slots`, slotData);
    const result = response.data;
    console.log('Slot creation response:', result);
    
    if (result.success && result.data && result.data.id) {
      const slotId = result.data.id;
      console.log(`Created slot ID: ${slotId}`);
      
      // Wait for WebSocket event
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      if (slotUpdateReceived) {
        console.log('✅ Real-time update received for slot creation');
      } else {
        console.log('❌ No real-time update received for slot creation');
      }
      
      // Test 2: Update the slot and verify real-time update
      console.log('\n✏️  Test 2: Updating slot and verifying real-time update...');
      
      expectedEvent = { action: 'updated' };
      slotUpdateReceived = false;
      
      const updateResponse = await axios.put(`${BASE_URL}/appointment-slots/${slotId}`, {
        max_patients: 8
      });
      const updateResult = updateResponse.data;
      console.log('Slot update response:', updateResult);
      
      // Wait for WebSocket event
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      if (slotUpdateReceived) {
        console.log('✅ Real-time update received for slot update');
      } else {
        console.log('❌ No real-time update received for slot update');
      }
      
      // Test 3: Book the slot and verify real-time update
      console.log('\n🎫 Test 3: Booking slot and verifying real-time update...');
      
      expectedEvent = { action: 'booked' };
      slotUpdateReceived = false;
      
      const bookResponse = await axios.post(`${BASE_URL}/appointment-slots/book`, {
        slotId: slotId
      });
      const bookResult = bookResponse.data;
      console.log('Slot booking response:', bookResult);
      
      // Wait for WebSocket event
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      if (slotUpdateReceived) {
        console.log('✅ Real-time update received for slot booking');
      } else {
        console.log('❌ No real-time update received for slot booking');
      }
      
      // Test 4: Delete the slot and verify real-time update
      console.log('\n🗑️  Test 4: Deleting slot and verifying real-time update...');
      
      expectedEvent = { action: 'deleted' };
      slotUpdateReceived = false;
      
      const deleteResponse = await axios.delete(`${BASE_URL}/appointment-slots/${slotId}`);
      const deleteResult = deleteResponse.data;
      console.log('Slot deletion response:', deleteResult);
      
      // Wait for WebSocket event
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      if (slotUpdateReceived) {
        console.log('✅ Real-time update received for slot deletion');
      } else {
        console.log('❌ No real-time update received for slot deletion');
      }
    } else {
      console.log('❌ Failed to create slot for real-time test');
    }
    
    // Disconnect
    socket.disconnect();
    console.log('\n🎉 Real-time synchronization tests completed!');
    
  } catch (error) {
    console.error('❌ Test failed with error:', error.response?.data || error.message);
  }
}

// Run the test
testRealtimeSync();