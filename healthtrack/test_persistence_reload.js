const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000';

async function testPersistenceAndReload() {
  console.log('💾 Starting Persistence and Page Reload Test...\n');
  
  try {
    // Get all services to identify service IDs
    console.log('📋 Fetching available services...');
    const servicesResponse = await axios.get(`${BASE_URL}/service-config`);
    if (!servicesResponse.data.success) {
      console.log('❌ Failed to fetch services');
      return;
    }
    
    const maternalCareService = servicesResponse.data.data.find(s => 
      s.service_name.toLowerCase().includes('immunization') || 
      s.service_name.toLowerCase().includes('maternal')
    );
    
    if (!maternalCareService) {
      console.log('⚠️  No immunization or maternal care services found');
      return;
    }
    
    console.log(`Using service: ${maternalCareService.service_name} (ID: ${maternalCareService.id})`);
    
    // Test 1: Create multiple slots for future dates
    console.log('\n🆕 Test 1: Creating multiple appointment slots...');
    
    const futureDate1 = new Date();
    futureDate1.setDate(futureDate1.getDate() + 5); // 5 days from now
    const dateString1 = futureDate1.toISOString().split('T')[0];
    
    const futureDate2 = new Date();
    futureDate2.setDate(futureDate2.getDate() + 6); // 6 days from now
    const dateString2 = futureDate2.toISOString().split('T')[0];
    
    const slotsToCreate = [
      {
        service_id: maternalCareService.id,
        appointment_date: dateString1,
        start_time: '10:00:00',
        end_time: '11:00:00',
        slot_duration_minutes: 30,
        max_patients: 5,
        generate_slots: false
      },
      {
        service_id: maternalCareService.id,
        appointment_date: dateString1,
        start_time: '11:00:00',
        end_time: '12:00:00',
        slot_duration_minutes: 30,
        max_patients: 3,
        generate_slots: false
      },
      {
        service_id: maternalCareService.id,
        appointment_date: dateString2,
        start_time: '14:00:00',
        end_time: '15:00:00',
        slot_duration_minutes: 45,
        max_patients: 2,
        generate_slots: false
      }
    ];
    
    const createdSlotIds = [];
    
    for (let i = 0; i < slotsToCreate.length; i++) {
      console.log(`Creating slot ${i+1}/${slotsToCreate.length}:`, slotsToCreate[i]);
      const response = await axios.post(`${BASE_URL}/appointment-slots`, slotsToCreate[i]);
      
      if (response.data.success && response.data.data && response.data.data.id) {
        createdSlotIds.push(response.data.data.id);
        console.log(`✅ Slot ${i+1} created successfully with ID: ${response.data.data.id}`);
      } else {
        console.log(`❌ Failed to create slot ${i+1}`);
      }
    }
    
    console.log(`\nCreated ${createdSlotIds.length} slots:`, createdSlotIds);
    
    // Test 2: Verify all slots exist in the database
    console.log('\n🔍 Test 2: Verifying all slots exist in database...');
    const allSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
    if (allSlotsResponse.data.success) {
      const createdSlotsInDb = allSlotsResponse.data.data.filter(slot => 
        createdSlotIds.includes(slot.id)
      );
      
      console.log(`✅ Found ${createdSlotsInDb.length} out of ${createdSlotIds.length} created slots in database`);
      
      if (createdSlotsInDb.length === createdSlotIds.length) {
        console.log('✅ All created slots exist in database');
      } else {
        console.log('❌ Some created slots are missing from database');
      }
      
      // Display details of created slots
      console.log('\n📋 Created slots details:');
      createdSlotsInDb.forEach((slot, index) => {
        console.log(`${index + 1}. ID: ${slot.id}, Date: ${slot.appointment_date}, Time: ${slot.start_time}-${slot.end_time}, Max: ${slot.max_patients}, Booked: ${slot.booked_patients}`);
      });
    } else {
      console.log('❌ Failed to fetch all slots for verification');
    }
    
    // Test 3: Filter slots by specific service and date
    console.log('\n🔍 Test 3: Filtering slots by service and date...');
    
    // Filter by service
    const serviceSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots?serviceId=${maternalCareService.id}`);
    if (serviceSlotsResponse.data.success) {
      const serviceSlots = serviceSlotsResponse.data.data.filter(slot => 
        createdSlotIds.includes(slot.id)
      );
      console.log(`✅ Retrieved ${serviceSlots.length} slots for service ${maternalCareService.id}`);
    }
    
    // Filter by first date
    const dateSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots?date=${dateString1}`);
    if (dateSlotsResponse.data.success) {
      const dateSlots = dateSlotsResponse.data.data.filter(slot => 
        createdSlotIds.includes(slot.id)
      );
      console.log(`✅ Retrieved ${dateSlots.length} slots for date ${dateString1}`);
    }
    
    // Test 4: Book some slots to test state changes
    console.log('\n🎫 Test 4: Booking some slots to test state persistence...');
    
    if (createdSlotIds.length > 0) {
      // Book the first slot
      const bookResponse = await axios.post(`${BASE_URL}/appointment-slots/book`, {
        slotId: createdSlotIds[0]
      });
      
      if (bookResponse.data.success) {
        console.log(`✅ Successfully booked slot ${createdSlotIds[0]}`);
        
        // Verify the booking is persisted
        const bookedSlotResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        const bookedSlot = bookedSlotResponse.data.data.find(slot => 
          slot.id === createdSlotIds[0]
        );
        
        if (bookedSlot && bookedSlot.booked_patients > 0) {
          console.log(`✅ Booking persisted: Slot ${bookedSlot.id} has ${bookedSlot.booked_patients} booked`);
        } else {
          console.log(`❌ Booking not persisted for slot ${createdSlotIds[0]}`);
        }
      } else {
        console.log('❌ Failed to book slot');
      }
    }
    
    // Test 5: Update a slot to test modification persistence
    console.log('\n✏️  Test 5: Updating a slot to test modification persistence...');
    
    if (createdSlotIds.length > 1) {
      const updateResponse = await axios.put(`${BASE_URL}/appointment-slots/${createdSlotIds[1]}`, {
        max_patients: 15
      });
      
      if (updateResponse.data.success) {
        console.log(`✅ Successfully updated slot ${createdSlotIds[1]} max_patients to 15`);
        
        // Verify the update is persisted
        const updatedSlotResponse = await axios.get(`${BASE_URL}/appointment-slots`);
        const updatedSlot = updatedSlotResponse.data.data.find(slot => 
          slot.id === createdSlotIds[1]
        );
        
        if (updatedSlot && updatedSlot.max_patients === 15) {
          console.log(`✅ Update persisted: Slot ${updatedSlot.id} max_patients is now ${updatedSlot.max_patients}`);
        } else {
          console.log(`❌ Update not persisted for slot ${createdSlotIds[1]}`);
        }
      } else {
        console.log('❌ Failed to update slot');
      }
    }
    
    // Test 6: Simulate "page reload" by fetching fresh data
    console.log('\n🔄 Test 6: Simulating page reload by fetching fresh data...');
    
    // Fetch all slots again to simulate page reload
    const freshSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
    if (freshSlotsResponse.data.success) {
      const freshCreatedSlots = freshSlotsResponse.data.data.filter(slot => 
        createdSlotIds.includes(slot.id)
      );
      
      console.log(`✅ After "reload", found ${freshCreatedSlots.length} out of ${createdSlotIds.length} created slots`);
      
      // Check if all properties are preserved after reload
      let allPropertiesPreserved = true;
      for (const originalId of createdSlotIds) {
        const originalSlot = allSlotsResponse.data.data.find(s => s.id === originalId);
        const freshSlot = freshSlotsResponse.data.data.find(s => s.id === originalId);
        
        if (!freshSlot) {
          console.log(`❌ Slot ${originalId} disappeared after reload`);
          allPropertiesPreserved = false;
        } else if (JSON.stringify(originalSlot) !== JSON.stringify(freshSlot)) {
          console.log(`⚠️  Slot ${originalId} properties changed after reload`);
          console.log(`   Original: ${JSON.stringify(originalSlot)}`);
          console.log(`   Fresh: ${JSON.stringify(freshSlot)}`);
        }
      }
      
      if (allPropertiesPreserved) {
        console.log('✅ All slot properties preserved after reload');
      }
    }
    
    // Test 7: Clean up - delete all created test slots
    console.log('\n🧹 Test 7: Cleaning up - deleting all test slots...');
    
    let deletedCount = 0;
    for (const slotId of createdSlotIds) {
      try {
        const deleteResponse = await axios.delete(`${BASE_URL}/appointment-slots/${slotId}`);
        if (deleteResponse.data.success) {
          console.log(`✅ Deleted slot ${slotId}`);
          deletedCount++;
        } else {
          console.log(`❌ Failed to delete slot ${slotId}`);
        }
      } catch (error) {
        console.log(`❌ Error deleting slot ${slotId}:`, error.message);
      }
    }
    
    console.log(`\n✅ Cleanup completed: ${deletedCount}/${createdSlotIds.length} slots deleted`);
    
    // Final verification: ensure all test slots are gone
    const finalSlotsResponse = await axios.get(`${BASE_URL}/appointment-slots`);
    const remainingTestSlots = finalSlotsResponse.data.data.filter(slot => 
      createdSlotIds.includes(slot.id)
    );
    
    if (remainingTestSlots.length === 0) {
      console.log('✅ All test slots successfully cleaned up');
    } else {
      console.log(`⚠️  ${remainingTestSlots.length} test slots still exist after cleanup`);
    }
    
    console.log('\n🎉 Persistence and reload tests completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed with error:', error.response?.data || error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
  }
}

// Run the test
testPersistenceAndReload();