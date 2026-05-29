// Test script to verify slot capacity fixes
const axios = require('axios');

const BASE_URL = 'http://localhost:3000';

async function testSlotCapacity() {
    console.log('🧪 Testing slot capacity fixes...\n');
    
    try {
        // Test 1: Create a slot with default parameters (should have max_patients = 1)
        console.log('📝 Test 1: Creating slot with default parameters...');
        const createResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
            service_id: 1,
            appointment_date: '2026-03-13',
            start_time: '09:00:00',
            end_time: '09:30:00',
            generate_slots: true
        });
        
        if (createResponse.data.success) {
            console.log('✅ Slots created successfully');
            const slots = createResponse.data.data;
            console.log(`📊 Generated ${slots.length} slots`);
            
            // Check first slot capacity
            const firstSlot = slots[0];
            console.log(`🔍 First slot details:`);
            console.log(`   - ID: ${firstSlot.id}`);
            console.log(`   - Time: ${firstSlot.start_time} - ${firstSlot.end_time}`);
            console.log(`   - Max patients: ${firstSlot.max_patients}`);
            console.log(`   - Booked patients: ${firstSlot.booked_patients}`);
            
            if (firstSlot.max_patients === 1) {
                console.log('✅ Slot capacity correctly set to 1');
            } else {
                console.log(`❌ Slot capacity incorrect: expected 1, got ${firstSlot.max_patients}`);
            }
        }
        
        // Test 2: Try to create slot with max_patients > 1 (should fail)
        console.log('\n📝 Test 2: Attempting to create slot with max_patients > 1...');
        try {
            const invalidResponse = await axios.post(`${BASE_URL}/appointment-slots`, {
                service_id: 1,
                appointment_date: '2026-03-13',
                start_time: '10:00:00',
                end_time: '10:30:00',
                max_patients: 5
            });
            console.log('❌ Server should have rejected max_patients > 1');
        } catch (error) {
            if (error.response && error.response.status === 400) {
                console.log('✅ Server correctly rejected max_patients > 1');
                console.log(`   Error message: ${error.response.data.message}`);
            } else {
                console.log('❌ Unexpected error:', error.message);
            }
        }
        
        // Test 3: Book the slot (should work)
        console.log('\n📝 Test 3: Booking the slot...');
        const bookResponse = await axios.post(`${BASE_URL}/appointment-slots/book`, {
            slotId: slots[0].id
        });
        
        if (bookResponse.data.success) {
            console.log('✅ Slot booked successfully');
            console.log(`   Remaining spots: ${bookResponse.data.data.remainingSpots}`);
            console.log(`   Is fully booked: ${bookResponse.data.data.isFullyBooked}`);
        }
        
        // Test 4: Try to book the same slot again (should fail)
        console.log('\n📝 Test 4: Attempting to book the same slot again...');
        try {
            const doubleBookResponse = await axios.post(`${BASE_URL}/appointment-slots/book`, {
                slotId: slots[0].id
            });
            console.log('❌ Server should have rejected double booking');
        } catch (error) {
            if (error.response && error.response.status === 409) {
                console.log('✅ Server correctly rejected double booking');
                console.log(`   Error message: ${error.response.data.message}`);
            } else {
                console.log('❌ Unexpected error:', error.message);
            }
        }
        
        // Test 5: Delete all slots for cleanup
        console.log('\n📝 Test 5: Deleting all slots for cleanup...');
        const deleteResponse = await axios.delete(`${BASE_URL}/appointment-slots?serviceId=1&date=2026-03-13`);
        
        if (deleteResponse.data.success) {
            console.log('✅ Slots deleted successfully');
            console.log(`   Deleted count: ${deleteResponse.data.data.deletedCount}`);
        }
        
        console.log('\n🎉 All tests completed!');
        
    } catch (error) {
        console.error('❌ Test failed:', error.response?.data || error.message);
    }
}

// Run the test
testSlotCapacity();
