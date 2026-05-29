/**
 * Comprehensive Appointment Booking System Test
 * Tests slot availability synchronization, real-time updates, and booking flow
 */

const io = require('socket.io-client');
const http = require('http');

// Configuration
const BASE_URL = 'http://localhost:3000';
const WEBSOCKET_URL = 'http://localhost:3000';

// Test configuration
const TEST_CONFIG = {
    serviceId: 16, // Immunization service ID
    testDate: '2026-03-11', // Tomorrow's date
    testSlots: [
        '09:00:00',
        '10:00:00', 
        '11:00:00'
    ]
};

class AppointmentBookingTest {
    constructor() {
        this.socket = null;
        this.testResults = {
            slotCreation: false,
            realTimeUpdates: false,
            bookingFlow: false,
            availabilitySync: false,
            duplicateBookingPrevention: false
        };
        this.createdSlots = [];
        this.bookingResults = [];
    }

    async connectWebSocket() {
        return new Promise((resolve, reject) => {
            console.log('🔌 Connecting to WebSocket...');
            this.socket = io(WEBSOCKET_URL);
            
            this.socket.on('connect', () => {
                console.log('✅ WebSocket connected');
                resolve();
            });
            
            this.socket.on('connect_error', (error) => {
                console.error('❌ WebSocket connection failed:', error.message);
                reject(error);
            });
            
            this.socket.on('slotsUpdated', (data) => {
                console.log('📡 Received real-time slot update:', data);
                this.handleSlotUpdate(data);
            });
        });
    }

    handleSlotUpdate(data) {
        console.log(`🔄 Slot update received: Action=${data.action}, SlotId=${data.slotId}`);
        
        if (data.action === 'booked') {
            this.testResults.realTimeUpdates = true;
            console.log('✅ Real-time booking update received');
        }
    }

    async createTestSlots() {
        console.log('🏗️  Creating test slots...');
        
        for (const startTime of TEST_CONFIG.testSlots) {
            const endTime = this.calculateEndTime(startTime, 30); // 30-minute slots
            
            try {
                const response = await this.makeRequest('POST', '/appointment-slots', {
                    service_id: TEST_CONFIG.serviceId,
                    appointment_date: TEST_CONFIG.testDate,
                    start_time: startTime,
                    end_time: endTime,
                    slot_duration_minutes: 30,
                    max_patients: 1
                });
                
                if (response.success) {
                    this.createdSlots.push(response.data);
                    console.log(`✅ Created slot: ${startTime} - ${endTime}`);
                } else {
                    console.error(`❌ Failed to create slot ${startTime}:`, response.message);
                }
            } catch (error) {
                console.error(`❌ Error creating slot ${startTime}:`, error.message);
            }
        }
        
        this.testResults.slotCreation = this.createdSlots.length > 0;
        console.log(`📊 Slot creation result: ${this.createdSlots.length}/${TEST_CONFIG.testSlots.length} slots created`);
    }

    calculateEndTime(startTime, durationMinutes) {
        const [hours, minutes, seconds] = startTime.split(':').map(Number);
        const endMinutes = minutes + durationMinutes;
        const endHours = hours + Math.floor(endMinutes / 60);
        const finalMinutes = endMinutes % 60;
        
        return `${endHours.toString().padStart(2, '0')}:${finalMinutes.toString().padStart(2, '0')}:00`;
    }

    async testSlotAvailability() {
        console.log('🔍 Testing slot availability...');
        
        try {
            const response = await this.makeRequest('GET', `/appointment-slots/user-view?serviceId=${TEST_CONFIG.serviceId}&date=${TEST_CONFIG.testDate}`);
            
            if (response.success && response.data.length > 0) {
                const availableSlots = response.data.filter(slot => 
                    slot.is_user_available === true || 
                    (slot.is_available === 1 && slot.booked_patients < slot.max_patients)
                );
                
                console.log(`📊 Found ${response.data.length} total slots, ${availableSlots.length} available`);
                this.testResults.availabilitySync = availableSlots.length === this.createdSlots.length;
                
                return response.data;
            } else {
                console.error('❌ Failed to fetch slot availability');
                return [];
            }
        } catch (error) {
            console.error('❌ Error testing slot availability:', error.message);
            return [];
        }
    }

    async testBookingFlow() {
        console.log('📅 Testing appointment booking flow...');
        
        if (this.createdSlots.length === 0) {
            console.error('❌ No test slots available for booking');
            return false;
        }
        
        const testSlot = this.createdSlots[0];
        console.log(`🎯 Testing booking for slot ${testSlot.id}: ${testSlot.start_time}`);
        
        try {
            // First booking attempt
            const booking1 = await this.makeRequest('POST', '/appointment-slots/book', {
                slotId: testSlot.id
            });
            
            if (booking1.success) {
                console.log('✅ First booking successful');
                this.bookingResults.push({ slotId: testSlot.id, result: 'success', attempt: 1 });
                
                // Wait a moment for real-time updates
                await this.sleep(1000);
                
                // Second booking attempt (should fail)
                const booking2 = await this.makeRequest('POST', '/appointment-slots/book', {
                    slotId: testSlot.id
                });
                
                if (!booking2.success) {
                    console.log('✅ Duplicate booking correctly prevented');
                    this.testResults.duplicateBookingPrevention = true;
                    this.bookingResults.push({ slotId: testSlot.id, result: 'prevented', attempt: 2 });
                } else {
                    console.log('❌ Duplicate booking was NOT prevented - BUG!');
                    this.bookingResults.push({ slotId: testSlot.id, result: 'failed_prevention', attempt: 2 });
                }
                
                this.testResults.bookingFlow = true;
                return true;
            } else {
                console.error('❌ First booking failed:', booking1.message);
                this.bookingResults.push({ slotId: testSlot.id, result: 'failed', attempt: 1, error: booking1.message });
                return false;
            }
        } catch (error) {
            console.error('❌ Error during booking test:', error.message);
            return false;
        }
    }

    async verifySlotStatusAfterBooking() {
        console.log('🔍 Verifying slot status after booking...');
        
        try {
            const response = await this.makeRequest('GET', `/appointment-slots/user-view?serviceId=${TEST_CONFIG.serviceId}&date=${TEST_CONFIG.testDate}`);
            
            if (response.success) {
                const bookedSlot = response.data.find(slot => slot.id === this.createdSlots[0].id);
                
                if (bookedSlot) {
                    const isAvailable = bookedSlot.is_user_available === true || 
                                     (bookedSlot.is_available === 1 && bookedSlot.booked_patients < bookedSlot.max_patients);
                    
                    console.log(`📊 Slot status after booking: available=${isAvailable}, booked=${bookedSlot.booked_patients}/${bookedSlot.max_patients}`);
                    
                    // Slot should not be available after booking
                    const correctStatus = !isAvailable && bookedSlot.booked_patients >= bookedSlot.max_patients;
                    
                    if (correctStatus) {
                        console.log('✅ Slot status correctly updated after booking');
                        return true;
                    } else {
                        console.log('❌ Slot status not correctly updated after booking');
                        return false;
                    }
                } else {
                    console.error('❌ Booked slot not found in availability check');
                    return false;
                }
            } else {
                console.error('❌ Failed to verify slot status');
                return false;
            }
        } catch (error) {
            console.error('❌ Error verifying slot status:', error.message);
            return false;
        }
    }

    async cleanupTestSlots() {
        console.log('🧹 Cleaning up test slots...');
        
        for (const slot of this.createdSlots) {
            try {
                await this.makeRequest('DELETE', `/appointment-slots/${slot.id}`);
                console.log(`🗑️  Deleted slot ${slot.id}`);
            } catch (error) {
                console.error(`❌ Failed to delete slot ${slot.id}:`, error.message);
            }
        }
    }

    makeRequest(method, path, data = null) {
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
            
            if (data) {
                const jsonData = JSON.stringify(data);
                options.headers['Content-Length'] = Buffer.byteLength(jsonData);
            }
            
            const req = http.request(options, (res) => {
                let body = '';
                
                res.on('data', (chunk) => {
                    body += chunk;
                });
                
                res.on('end', () => {
                    try {
                        const response = JSON.parse(body);
                        resolve(response);
                    } catch (error) {
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

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async runFullTest() {
        console.log('🚀 Starting comprehensive appointment booking test...\n');
        
        try {
            // Connect to WebSocket
            await this.connectWebSocket();
            
            // Create test slots
            await this.createTestSlots();
            
            // Test slot availability
            await this.testSlotAvailability();
            
            // Test booking flow
            await this.testBookingFlow();
            
            // Verify slot status after booking
            const statusVerified = await this.verifySlotStatusAfterBooking();
            
            // Wait for any final real-time updates
            await this.sleep(2000);
            
            // Print results
            this.printTestResults();
            
            // Cleanup
            await this.cleanupTestSlots();
            
        } catch (error) {
            console.error('❌ Test failed with error:', error.message);
        } finally {
            if (this.socket) {
                this.socket.disconnect();
                console.log('🔌 WebSocket disconnected');
            }
        }
    }

    printTestResults() {
        console.log('\n📊 APPOINTMENT BOOKING SYSTEM TEST RESULTS');
        console.log('='.repeat(50));
        
        console.log(`✅ Slot Creation: ${this.testResults.slotCreation ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Real-time Updates: ${this.testResults.realTimeUpdates ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Booking Flow: ${this.testResults.bookingFlow ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Availability Sync: ${this.testResults.availabilitySync ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Duplicate Prevention: ${this.testResults.duplicateBookingPrevention ? 'PASS' : 'FAIL'}`);
        
        const allPassed = Object.values(this.testResults).every(result => result === true);
        
        console.log('\n' + '='.repeat(50));
        console.log(`🏆 OVERALL RESULT: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
        console.log('='.repeat(50));
        
        if (this.bookingResults.length > 0) {
            console.log('\n📅 Booking Results:');
            this.bookingResults.forEach(result => {
                console.log(`   Slot ${result.slotId}: Attempt ${result.attempt} - ${result.result}${result.error ? ' (' + result.error + ')' : ''}`);
            });
        }
        
        if (!allPassed) {
            console.log('\n❌ ISSUES FOUND:');
            if (!this.testResults.slotCreation) console.log('   - Slot creation failed');
            if (!this.testResults.realTimeUpdates) console.log('   - Real-time updates not working');
            if (!this.testResults.bookingFlow) console.log('   - Booking flow has issues');
            if (!this.testResults.availabilitySync) console.log('   - Availability synchronization problems');
            if (!this.testResults.duplicateBookingPrevention) console.log('   - Duplicate booking prevention failed');
        }
    }
}

// Run the test
if (require.main === module) {
    const test = new AppointmentBookingTest();
    test.runFullTest().catch(console.error);
}

module.exports = AppointmentBookingTest;
