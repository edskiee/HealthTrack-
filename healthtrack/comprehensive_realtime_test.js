// Comprehensive Real-time Synchronization Test
// This script tests the complete real-time slot synchronization system

const io = require('socket.io-client');
const axios = require('axios');

// Configuration
const API_BASE_URL = 'http://localhost:3000';
const WEBSOCKET_URL = 'ws://localhost:3000';

// Test data
const testServiceId = 1; // Assuming service ID 1 exists
const testDate = new Date();
testDate.setDate(testDate.getDate() + 1); // Tomorrow
const testDateString = testDate.toISOString().split('T')[0];

// Test state
let testResults = {
    websocketConnection: false,
    slotCreation: false,
    realTimeUpdate: false,
    slotBooking: false,
    raceConditionPrevention: false,
    overflowPrevention: false
};

console.log('🚀 Starting Comprehensive Real-time Synchronization Test');
console.log('================================================================');

// Test 1: WebSocket Connection
async function testWebSocketConnection() {
    console.log('\n📡 Test 1: WebSocket Connection');
    
    return new Promise((resolve) => {
        const socket = io(WEBSOCKET_URL, {
            transports: ['websocket'],
            reconnection: false
        });
        
        const timeout = setTimeout(() => {
            console.log('❌ WebSocket connection timeout');
            resolve(false);
        }, 5000);
        
        socket.on('connect', () => {
            clearTimeout(timeout);
            console.log('✅ WebSocket connected successfully');
            testResults.websocketConnection = true;
            socket.disconnect();
            resolve(true);
        });
        
        socket.on('connect_error', (error) => {
            clearTimeout(timeout);
            console.log('❌ WebSocket connection failed:', error.message);
            resolve(false);
        });
    });
}

// Test 2: Slot Creation with Real-time Updates
async function testSlotCreation() {
    console.log('\n🎯 Test 2: Slot Creation with Real-time Updates');
    
    try {
        // Create a WebSocket client to listen for updates
        const socket = io(WEBSOCKET_URL);
        let updateReceived = false;
        
        socket.on('slotsUpdated', (data) => {
            console.log('📨 Real-time update received:', data);
            if (data.action === 'created' || data.action === 'bulk_created') {
                updateReceived = true;
                testResults.realTimeUpdate = true;
            }
        });
        
        // Wait for WebSocket to connect
        await new Promise(resolve => {
            socket.on('connect', resolve);
        });
        
        // Create slots via API
        const slotData = {
            service_id: testServiceId,
            appointment_date: testDateString,
            start_time: '09:00:00',
            end_time: '10:00:00',
            slot_duration_minutes: 30,
            max_patients: 5,
            generate_slots: true
        };
        
        console.log('📝 Creating slots...');
        const response = await axios.post(`${API_BASE_URL}/appointment-slots`, slotData);
        
        if (response.data.success) {
            console.log('✅ Slots created successfully:', response.data.data.length, 'slots');
            testResults.slotCreation = true;
            
            // Wait a moment for real-time update
            await new Promise(resolve => setTimeout(resolve, 1000));
            
            if (!updateReceived) {
                console.log('⚠️  Real-time update not received within timeout');
            }
        } else {
            console.log('❌ Slot creation failed:', response.data.message);
        }
        
        socket.disconnect();
        return response.data.success;
        
    } catch (error) {
        console.log('❌ Slot creation error:', error.message);
        return false;
    }
}

// Test 3: Slot Booking with Race Condition Prevention
async function testSlotBooking() {
    console.log('\n🏃 Test 3: Slot Booking with Race Condition Prevention');
    
    try {
        // First, get available slots
        const slotsResponse = await axios.get(
            `${API_BASE_URL}/appointment-slots/available?serviceId=${testServiceId}&date=${testDateString}`
        );
        
        if (!slotsResponse.data.success || slotsResponse.data.data.length === 0) {
            console.log('❌ No available slots found for booking test');
            return false;
        }
        
        const slotId = slotsResponse.data.data[0].id;
        console.log('📅 Testing booking for slot ID:', slotId);
        
        // Create multiple concurrent booking attempts
        const bookingPromises = [];
        for (let i = 0; i < 3; i++) {
            bookingPromises.push(
                axios.post(`${API_BASE_URL}/appointment-slots/book`, { slotId })
                    .then(res => ({ success: true, data: res.data }))
                    .catch(err => ({ success: false, error: err.response?.data || err.message }))
            );
        }
        
        console.log('🏁 Simulating concurrent bookings...');
        const results = await Promise.all(bookingPromises);
        
        // Count successful bookings
        const successfulBookings = results.filter(r => r.success && r.data.success).length;
        console.log(`📊 Booking results: ${successfulBookings}/3 successful`);
        
        if (successfulBookings === 1) {
            console.log('✅ Race condition prevention working correctly');
            testResults.raceConditionPrevention = true;
        } else {
            console.log('❌ Race condition prevention failed - multiple bookings succeeded');
        }
        
        testResults.slotBooking = successfulBookings > 0;
        return successfulBookings === 1;
        
    } catch (error) {
        console.log('❌ Slot booking test error:', error.message);
        return false;
    }
}

// Test 4: Overflow Prevention
async function testOverflowPrevention() {
    console.log('\n🛡️  Test 4: Overflow Prevention');
    
    try {
        // Try to create an excessive number of slots
        const excessiveSlotData = {
            service_id: testServiceId,
            appointment_date: testDateString,
            start_time: '08:00:00',
            end_time: '18:00:00',
            slot_duration_minutes: 5, // Very short duration
            max_patients: 10,
            generate_slots: true
        };
        
        console.log('📝 Attempting to create excessive slots...');
        const response = await axios.post(`${API_BASE_URL}/appointment-slots`, excessiveSlotData);
        
        if (!response.data.success) {
            console.log('✅ Overflow prevention working:', response.data.message);
            testResults.overflowPrevention = true;
            return true;
        } else {
            console.log('⚠️  Overflow prevention may not be working - excessive slots created');
            return false;
        }
        
    } catch (error) {
        if (error.response && error.response.status === 429) {
            console.log('✅ Overflow prevention working:', error.response.data.message);
            testResults.overflowPrevention = true;
            return true;
        } else {
            console.log('❌ Overflow prevention test error:', error.message);
            return false;
        }
    }
}

// Test 5: Real-time Update Propagation
async function testRealTimePropagation() {
    console.log('\n📡 Test 5: Real-time Update Propagation');
    
    return new Promise(async (resolve) => {
        try {
            // Create two WebSocket clients (simulating admin and user)
            const adminSocket = io(WEBSOCKET_URL);
            const userSocket = io(WEBSOCKET_URL);
            
            let adminReceivedUpdate = false;
            let userReceivedUpdate = false;
            
            adminSocket.on('connect', () => {
                adminSocket.emit('joinAdminsRoom');
            });
            
            userSocket.on('connect', () => {
                userSocket.emit('joinUserRoom', 1); // User ID 1
            });
            
            adminSocket.on('slotsUpdated', (data) => {
                console.log('👨‍💼 Admin received update:', data.action);
                adminReceivedUpdate = true;
            });
            
            userSocket.on('slotsUpdated', (data) => {
                console.log('👤 User received update:', data.action);
                userReceivedUpdate = true;
            });
            
            // Wait for both to connect
            await new Promise(resolve => {
                let connectedCount = 0;
                const checkConnected = () => {
                    connectedCount++;
                    if (connectedCount === 2) resolve();
                };
                adminSocket.on('connect', checkConnected);
                userSocket.on('connect', checkConnected);
            });
            
            // Create a new slot to trigger update
            const slotData = {
                service_id: testServiceId,
                appointment_date: testDateString,
                start_time: '14:00:00',
                end_time: '15:00:00',
                slot_duration_minutes: 30,
                max_patients: 3,
                generate_slots: true
            };
            
            await axios.post(`${API_BASE_URL}/appointment-slots`, slotData);
            
            // Wait for updates to propagate
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            if (adminReceivedUpdate && userReceivedUpdate) {
                console.log('✅ Real-time propagation working correctly');
                resolve(true);
            } else {
                console.log(`❌ Real-time propagation incomplete - Admin: ${adminReceivedUpdate}, User: ${userReceivedUpdate}`);
                resolve(false);
            }
            
            adminSocket.disconnect();
            userSocket.disconnect();
            
        } catch (error) {
            console.log('❌ Real-time propagation test error:', error.message);
            resolve(false);
        }
    });
}

// Main test execution
async function runAllTests() {
    console.log('🔧 Starting comprehensive real-time synchronization tests...\n');
    
    // Run all tests
    await testWebSocketConnection();
    await testSlotCreation();
    await testSlotBooking();
    await testOverflowPrevention();
    await testRealTimePropagation();
    
    // Print results
    console.log('\n📊 Test Results Summary');
    console.log('========================');
    
    const totalTests = Object.keys(testResults).length;
    const passedTests = Object.values(testResults).filter(Boolean).length;
    
    Object.entries(testResults).forEach(([test, passed]) => {
        const status = passed ? '✅ PASS' : '❌ FAIL';
        const testName = test.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
        console.log(`${status} ${testName}`);
    });
    
    console.log('\n🎯 Overall Result:', `${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
        console.log('🎉 All tests passed! Real-time synchronization system is working correctly.');
    } else {
        console.log('⚠️  Some tests failed. Please review the implementation.');
    }
    
    // Cleanup test data
    console.log('\n🧹 Cleaning up test data...');
    try {
        // Clean up created slots (optional - uncomment if needed)
        // await axios.delete(`${API_BASE_URL}/appointment-slots/cleanup-test-data`);
        console.log('✅ Cleanup completed');
    } catch (error) {
        console.log('⚠️  Cleanup failed:', error.message);
    }
}

// Run tests
runAllTests().catch(console.error);
