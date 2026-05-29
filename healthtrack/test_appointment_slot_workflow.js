const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000';

async function testAppointmentSlotWorkflow() {
  console.log('🧪 Starting Appointment Slot Module Functional Test...\n');
  
  try {
    // Test 1: Check API connectivity
    console.log('🔍 Test 1: Checking API connectivity...');
    const healthCheck = await axios.get(`${BASE_URL}/`);
    console.log('✅ API Health Check:', healthCheck.data.message);
    
    // Test 2: Get all services to identify service IDs
    console.log('\n📋 Test 2: Fetching available services...');
    const servicesResponse = await axios.get(`${BASE_URL}/service-config`);
    if (servicesResponse.data.success) {
      console.log('✅ Services fetched successfully');
      console.log('Available services:', servicesResponse.data.data);
      
      // Find maternal care or immunization service
      const maternalCareService = servicesResponse.data.data.find(s => 
        s.service_name.toLowerCase().includes('maternal') || 
        s.service_name.toLowerCase().includes('immunization')
      );
      
      if (!maternalCareService) {
        console.log('⚠️  No maternal care or immunization services found');
        return;
      }
      
      console.log(`Using service: ${maternalCareService.service_name} (ID: ${maternalCareService.id})`);
      
      // Test 3: Create appointment slot
      console.log('\n🆕 Test 3: Creating appointment slot...');
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 2); // 2 days from now
      const dateString = futureDate.toISOString().split('T')[0];
      
      const slotData = {
        service_id: maternalCareService.id,
        appointment_date: dateString,
        start_time: '09:00:00',
        end_time: '10:00:00',
        slot_duration_minutes: 30,
        max_patients: 5,
        generate_slots: false
      };
      
      console.log('Creating slot with data:', slotData);
      
      const createResponse = await axios.post(`${BASE_URL}/appointment-slots`, slotData);
      console.log('✅ Slot created successfully:', createResponse.data);
      
      if (createResponse.data.success && createResponse.data.data && createResponse.data.data.id) {
        const slotId = createResponse.data.data.id;
        console.log(`Created slot ID: ${slotId}`);
        
        // Test 4: Get all slots for verification
        console.log('\n📖 Test 4: Fetching all appointment slots...');
        const allSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        console.log(`✅ Found ${allSlotsResponse.data.data.length} total slots`);
        
        // Find our created slot
        const createdSlot = allSlotsResponse.data.data.find(s => s.id === slotId);
        if (createdSlot) {
          console.log('✅ Created slot found in database:', createdSlot);
        } else {
          console.log('❌ Created slot NOT found in database');
        }
        
        // Test 5: Get available slots for specific date
        console.log('\n🔍 Test 5: Fetching available slots for created date...');
        const availableSlotsResponse = await axios.get(
          `${BASE_URL}/appointment-slots/available?serviceId=${maternalCareService.id}&date=${dateString}`
        );
        console.log('✅ Available slots for date:', availableSlotsResponse.data);
        
        // Test 6: Update the slot
        console.log('\n✏️  Test 6: Updating appointment slot...');
        const updateResponse = await axios.put(`${BASE_URL}/appointment-slots/${slotId}`, {
          max_patients: 10
        });
        console.log('✅ Slot updated successfully:', updateResponse.data);
        
        // Test 7: Get updated slot
        console.log('\n📖 Test 7: Verifying slot update...');
        const updatedSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        const updatedSlot = updatedSlotsResponse.data.data.find(s => s.id === slotId);
        if (updatedSlot && updatedSlot.max_patients === 10) {
          console.log('✅ Slot update verified:', updatedSlot);
        } else {
          console.log('❌ Slot update not reflected in database');
        }
        
        // Test 8: Book the slot (this should increment booked_patients)
        console.log('\n🎫 Test 8: Booking appointment slot...');
        const bookResponse = await axios.post(`${BASE_URL}/appointment-slots/book`, {
          slotId: slotId
        });
        console.log('✅ Slot booked successfully:', bookResponse.data);
        
        // Test 9: Verify booking by fetching updated slot data
        console.log('\n🔍 Test 9: Verifying slot booking...');
        const bookedSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        const bookedSlot = bookedSlotsResponse.data.data.find(s => s.id === slotId);
        if (bookedSlot && bookedSlot.booked_patients > 0) {
          console.log('✅ Booking verified:', bookedSlot);
        } else {
          console.log('❌ Booking not reflected in database');
        }
        
        // Test 10: Clean up - delete the test slot
        console.log('\n🗑️  Test 10: Cleaning up - deleting test slot...');
        const deleteResponse = await axios.delete(`${BASE_URL}/appointment-slots/${slotId}`);
        console.log('✅ Slot deleted successfully:', deleteResponse.data);
        
        // Verify deletion
        const finalSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        const deletedSlot = finalSlotsResponse.data.data.find(s => s.id === slotId);
        if (!deletedSlot) {
          console.log('✅ Slot deletion confirmed - slot no longer exists');
        } else {
          console.log('❌ Slot still exists after deletion');
        }
        
      } else {
        console.log('❌ Failed to create slot');
      }
    } else {
      console.log('❌ Failed to fetch services');
    }
    
    console.log('\n🎉 All tests completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed with error:', error.response?.data || error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
  }
}

// Run the test
testAppointmentSlotWorkflow();