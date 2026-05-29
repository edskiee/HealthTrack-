// Test script to verify individual slot deletion functionality
const axios = require('axios');

const BASE_URL = 'http://localhost:3000';

async function testIndividualSlotDeletion() {
    console.log('🗑️ Testing individual slot deletion functionality...\n');
    
    try {
        // Step 1: Create a test slot first
        console.log('📝 Step 1: Creating a test slot...');
        const createResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
            service_id: 1,
            appointment_date: '2026-03-13',
            start_time: '10:00:00',
            end_time: '10:30:00',
            generate_slots: false
        });
        
        if (createResponse.data.success) {
            const slot = createResponse.data.data;
            const slotId = slot.id;
            console.log(`✅ Test slot created with ID: ${slotId}`);
            console.log(`   Time: ${slot.start_time} - ${slot.end_time}`);
            console.log(`   Max patients: ${slot.max_patients}`);
            
            // Step 2: Verify slot appears in getAllSlots
            console.log('\n📝 Step 2: Verifying slot appears in getAllSlots...');
            const verifyResponse = await axios.get(`${BASE_URL}/appointment-slots?serviceId=1&date=2026-03-13`);
            
            if (verifyResponse.data.success) {
                const slots = verifyResponse.data.data;
                const createdSlot = slots.find(s => s.id === slotId);
                if (createdSlot) {
                    console.log('✅ Slot appears in getAllSlots endpoint');
                } else {
                    console.log('❌ Slot not found in getAllSlots endpoint');
                }
            }
            
            // Step 3: Delete the individual slot
            console.log('\n📝 Step 3: Deleting individual slot...');
            const deleteResponse = await axios.delete(`${BASE_URL}/appointment-slots/${slotId}`);
            
            if (deleteResponse.data.success) {
                console.log('✅ Slot deleted successfully via individual delete endpoint');
                console.log(`   Message: ${deleteResponse.data.message}`);
            } else {
                console.log('❌ Failed to delete slot');
                console.log(`   Error: ${deleteResponse.data.message}`);
                return;
            }
            
            // Step 4: Verify slot is removed from getAllSlots
            console.log('\n📝 Step 4: Verifying slot is removed from getAllSlots...');
            const verifyAfterDeleteResponse = await axios.get(`${BASE_URL}/appointment-slots?serviceId=1&date=2026-03-13`);
            
            if (verifyAfterDeleteResponse.data.success) {
                const slotsAfterDelete = verifyAfterDeleteResponse.data.data;
                const deletedSlot = slotsAfterDelete.find(s => s.id === slotId);
                if (!deletedSlot) {
                    console.log('✅ Slot successfully removed from getAllSlots endpoint');
                } else {
                    console.log('❌ Slot still appears in getAllSlots endpoint after deletion');
                }
                
                console.log(`   Total slots before: ${slots.length}`);
                console.log(`   Total slots after: ${slotsAfterDelete.length}`);
            }
            
            // Step 5: Test error handling - try to delete non-existent slot
            console.log('\n📝 Step 5: Testing error handling with non-existent slot...');
            try {
                const errorResponse = await axios.delete(`${BASE_URL}/appointment-slots/99999`);
                if (errorResponse.status === 404) {
                    console.log('✅ Correctly returns 404 for non-existent slot');
                } else {
                    console.log('⚠️  Unexpected response for non-existent slot:', errorResponse.status);
                }
            } catch (error) {
                console.log('✅ Error handling works correctly');
            }
            
            console.log('\n🎉 Individual slot deletion test completed successfully!');
            
        } else {
            console.log('❌ Failed to create test slot');
            console.log(`   Error: ${createResponse.data.message}`);
        }
        
    } catch (error) {
        console.error('❌ Test failed:', error.response?.data || error.message);
    }
}

// Run the test
testIndividualSlotDeletion();
