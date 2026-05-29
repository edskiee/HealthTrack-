const http = require('http');

// Test the delete all slots functionality
async function testDeleteAllSlots() {
    console.log('🧪 Testing Delete All Slots API Endpoint');
    
    const baseUrl = 'http://localhost:3000';
    
    try {
        // Test 1: Get current slots count
        console.log('\n1️⃣ Getting current slots count...');
        const getResponse = await makeRequest('GET', '/appointment-slots');
        console.log(`Current slots count: ${getResponse.data.length}`);
        
        if (getResponse.data.length === 0) {
            console.log('⚠️ No slots found. Creating test slots first...');
            
            // Create a test slot
            const createResult = await makeRequest('POST', '/appointment-slots', {
                service_id: 1,
                appointment_date: '2026-03-12',
                start_time: '09:00:00',
                end_time: '09:30:00',
                slot_duration_minutes: 30,
                max_patients: 10
            });
            
            if (createResult.success) {
                console.log('✅ Test slot created successfully');
            } else {
                console.log('❌ Failed to create test slot');
                return;
            }
        }
        
        // Test 2: Delete all slots
        console.log('\n2️⃣ Testing delete all slots...');
        const deleteResponse = await makeRequest('DELETE', '/appointment-slots');
        
        if (deleteResponse.success) {
            console.log(`✅ Successfully deleted ${deleteResponse.data.deletedCount} slots`);
            console.log(`Response: ${deleteResponse.message}`);
        } else {
            console.log(`❌ Delete failed: ${deleteResponse.message}`);
            return;
        }
        
        // Test 3: Verify slots are deleted
        console.log('\n3️⃣ Verifying slots are deleted...');
        const verifyResponse = await makeRequest('GET', '/appointment-slots');
        
        if (verifyResponse.data.length === 0) {
            console.log('✅ All slots successfully deleted');
        } else {
            console.log(`❌ Still found ${verifyResponse.data.length} slots`);
        }
        
        // Test 4: Test with service filter
        console.log('\n4️⃣ Testing with service filter...');
        
        // Create slots for different services
        await makeRequest('POST', '/appointment-slots', {
            service_id: 1,
            appointment_date: '2026-03-12',
            start_time: '10:00:00',
            end_time: '10:30:00',
            slot_duration_minutes: 30,
            max_patients: 10
        });
        
        await makeRequest('POST', '/appointment-slots', {
            service_id: 2,
            appointment_date: '2026-03-12',
            start_time: '11:00:00',
            end_time: '11:30:00',
            slot_duration_minutes: 30,
            max_patients: 10
        });
        
        console.log('Created test slots for services 1 and 2');
        
        // Delete only service 1 slots
        const filteredDeleteResponse = await makeRequest('DELETE', '/appointment-slots?serviceId=1');
        
        if (filteredDeleteResponse.success) {
            console.log(`✅ Successfully deleted ${filteredDeleteResponse.data.deletedCount} slots for service 1`);
        } else {
            console.log(`❌ Filtered delete failed: ${filteredDeleteResponse.message}`);
        }
        
        // Verify service 2 slots still exist
        const finalCheck = await makeRequest('GET', '/appointment-slots');
        const service2Slots = finalCheck.data.filter(slot => slot.service_id === 2);
        
        if (service2Slots.length > 0) {
            console.log(`✅ Service 2 slots preserved (${service2Slots.length} slots)`);
        } else {
            console.log('❌ Service 2 slots were incorrectly deleted');
        }
        
        // Clean up remaining slots
        await makeRequest('DELETE', '/appointment-slots');
        
        console.log('\n🎉 All tests completed successfully!');
        
    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
}

function makeRequest(method, path, data = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'localhost',
            port: 3000,
            path: path,
            method: method,
            headers: {
                'Content-Type': 'application/json',
            }
        };
        
        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => {
                body += chunk;
            });
            res.on('end', () => {
                try {
                    const response = JSON.parse(body);
                    resolve(response);
                } catch (e) {
                    reject(new Error(`Invalid JSON response: ${body}`));
                }
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        if (data) {
            req.write(JSON.stringify(data));
        }
        
        req.end();
    });
}

// Run the test
testDeleteAllSlots().catch(console.error);
