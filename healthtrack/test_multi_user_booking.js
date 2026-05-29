/**
 * Multi-User Slot Booking Synchronization Test
 * Simulates multiple users trying to book the same slot simultaneously
 */

const io = require('socket.io-client');
const http = require('http');

class MultiUserBookingTest {
    constructor() {
        this.sockets = [];
        this.testResults = {
            slotCreation: false,
            multiUserSync: false,
            realTimeUpdates: false,
            duplicatePrevention: false,
            uiConsistency: false
        };
        this.testSlot = null;
        this.bookingAttempts = [];
        this.receivedUpdates = [];
    }

    async connectMultipleUsers(userCount = 3) {
        console.log(`🔌 Connecting ${userCount} users to WebSocket...`);
        
        for (let i = 0; i < userCount; i++) {
            const socket = io('http://localhost:3000');
            
            socket.on('connect', () => {
                console.log(`✅ User ${i + 1} connected`);
            });
            
            socket.on('slotsUpdated', (data) => {
                console.log(`📡 User ${i + 1} received slot update:`, data);
                this.receivedUpdates.push({
                    user: i + 1,
                    update: data,
                    timestamp: new Date().toISOString()
                });
            });
            
            this.sockets.push(socket);
        }
        
        // Wait for all connections
        await this.sleep(2000);
        return true;
    }

    async createTestSlot() {
        console.log('🏗️  Creating test slot for multi-user test...');
        
        try {
            const response = await this.makeRequest('POST', '/appointment-slots', {
                service_id: 16, // Immunization service
                appointment_date: '2026-03-15',
                start_time: '14:00:00',
                end_time: '14:30:00',
                slot_duration_minutes: 30,
                max_patients: 1
            });
            
            if (response.success) {
                this.testSlot = response.data;
                this.testResults.slotCreation = true;
                console.log(`✅ Created test slot: ${this.testSlot.id} at ${this.testSlot.start_time}`);
                return true;
            } else {
                console.error('❌ Failed to create test slot:', response.message);
                return false;
            }
        } catch (error) {
            console.error('❌ Error creating test slot:', error.message);
            return false;
        }
    }

    async simulateConcurrentBookings() {
        console.log('🎯 Simulating concurrent booking attempts...');
        
        if (!this.testSlot) {
            console.error('❌ No test slot available');
            return false;
        }
        
        // Clear previous updates
        this.receivedUpdates = [];
        
        // Simulate 3 users trying to book the same slot simultaneously
        const bookingPromises = [];
        
        for (let i = 0; i < 3; i++) {
            const bookingPromise = this.makeRequest('POST', '/appointment-slots/book', {
                slotId: this.testSlot.id
            }).then(result => ({
                user: i + 1,
                success: result.success,
                message: result.message,
                timestamp: new Date().toISOString()
            }));
            
            bookingPromises.push(bookingPromise);
        }
        
        // Execute all bookings concurrently
        const results = await Promise.all(bookingPromises);
        this.bookingAttempts = results;
        
        // Wait for real-time updates to propagate
        await this.sleep(3000);
        
        // Analyze results
        const successfulBookings = results.filter(r => r.success);
        const failedBookings = results.filter(r => !r.success);
        
        console.log(`📊 Booking Results: ${successfulBookings.length} successful, ${failedBookings.length} failed`);
        
        // Only one should succeed
        this.testResults.duplicatePrevention = successfulBookings.length === 1 && failedBookings.length === 2;
        
        if (this.testResults.duplicatePrevention) {
            console.log('✅ Duplicate booking prevention working correctly');
        } else {
            console.log('❌ Duplicate booking prevention failed');
        }
        
        return this.testResults.duplicatePrevention;
    }

    async verifyRealTimeUpdates() {
        console.log('🔍 Verifying real-time updates to all users...');
        
        const bookingUpdates = this.receivedUpdates.filter(update => update.update.action === 'booked');
        
        console.log(`📊 Received ${bookingUpdates.length} booking updates across all users`);
        
        // All connected users should receive the booking update
        this.testResults.realTimeUpdates = bookingUpdates.length === this.sockets.length;
        
        if (this.testResults.realTimeUpdates) {
            console.log('✅ All users received real-time updates');
        } else {
            console.log('❌ Not all users received real-time updates');
        }
        
        return this.testResults.realTimeUpdates;
    }

    async verifyUIConsistency() {
        console.log('🔍 Verifying UI consistency across users...');
        
        try {
            // Check slot availability from API
            const response = await this.makeRequest('GET', '/appointment-slots/user-view?serviceId=16&date=2026-03-15');
            
            if (response.success) {
                const bookedSlot = response.data.find(slot => slot.id === this.testSlot.id);
                
                if (bookedSlot) {
                    const isAvailable = bookedSlot.is_user_available === true || 
                                     (bookedSlot.is_available === 1 && bookedSlot.booked_patients < bookedSlot.max_patients);
                    
                    console.log(`📊 Slot status: available=${isAvailable}, booked=${bookedSlot.booked_patients}/${bookedSlot.max_patients}`);
                    
                    // Slot should not be available after booking
                    const correctStatus = !isAvailable && bookedSlot.booked_patients >= bookedSlot.max_patients;
                    
                    this.testResults.uiConsistency = correctStatus;
                    
                    if (correctStatus) {
                        console.log('✅ UI consistency verified - slot shows as booked');
                    } else {
                        console.log('❌ UI inconsistency - slot still shows as available');
                    }
                } else {
                    console.error('❌ Test slot not found in availability check');
                    this.testResults.uiConsistency = false;
                }
            } else {
                console.error('❌ Failed to verify UI consistency');
                this.testResults.uiConsistency = false;
            }
        } catch (error) {
            console.error('❌ Error verifying UI consistency:', error.message);
            this.testResults.uiConsistency = false;
        }
        
        return this.testResults.uiConsistency;
    }

    async cleanup() {
        console.log('🧹 Cleaning up test resources...');
        
        // Disconnect all sockets
        this.sockets.forEach((socket, index) => {
            socket.disconnect();
            console.log(`🔌 User ${index + 1} disconnected`);
        });
        
        // Delete test slot
        if (this.testSlot) {
            try {
                await this.makeRequest('DELETE', `/appointment-slots/${this.testSlot.id}`);
                console.log(`🗑️  Deleted test slot ${this.testSlot.id}`);
            } catch (error) {
                console.error(`❌ Failed to delete test slot:`, error.message);
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

    async runMultiUserTest() {
        console.log('🚀 Starting multi-user booking synchronization test...\n');
        
        try {
            // Connect multiple users
            await this.connectMultipleUsers(3);
            
            // Create test slot
            await this.createTestSlot();
            
            // Simulate concurrent bookings
            await this.simulateConcurrentBookings();
            
            // Verify real-time updates
            await this.verifyRealTimeUpdates();
            
            // Verify UI consistency
            await this.verifyUIConsistency();
            
            // Print results
            this.printResults();
            
        } catch (error) {
            console.error('❌ Multi-user test failed:', error.message);
        } finally {
            await this.cleanup();
        }
    }

    printResults() {
        console.log('\n📊 MULTI-USER BOOKING SYNCHRONIZATION TEST RESULTS');
        console.log('='.repeat(60));
        
        console.log(`✅ Slot Creation: ${this.testResults.slotCreation ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Real-time Updates: ${this.testResults.realTimeUpdates ? 'PASS' : 'FAIL'}`);
        console.log(`✅ Duplicate Prevention: ${this.testResults.duplicatePrevention ? 'PASS' : 'FAIL'}`);
        console.log(`✅ UI Consistency: ${this.testResults.uiConsistency ? 'PASS' : 'FAIL'}`);
        
        const allPassed = Object.values(this.testResults).every(result => result === true);
        
        console.log('\n' + '='.repeat(60));
        console.log(`🏆 OVERALL RESULT: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
        console.log('='.repeat(60));
        
        console.log('\n📅 Booking Attempts:');
        this.bookingAttempts.forEach(attempt => {
            console.log(`   User ${attempt.user}: ${attempt.success ? 'SUCCESS' : 'FAILED'}${attempt.message ? ' - ' + attempt.message : ''}`);
        });
        
        console.log('\n📡 Real-time Updates Received:');
        const updateCounts = {};
        this.receivedUpdates.forEach(update => {
            updateCounts[update.user] = (updateCounts[update.user] || 0) + 1;
        });
        
        Object.keys(updateCounts).forEach(user => {
            console.log(`   User ${user}: ${updateCounts[user]} updates`);
        });
        
        if (!allPassed) {
            console.log('\n❌ ISSUES FOUND:');
            if (!this.testResults.slotCreation) console.log('   - Test slot creation failed');
            if (!this.testResults.realTimeUpdates) console.log('   - Real-time updates not working properly');
            if (!this.testResults.duplicatePrevention) console.log('   - Duplicate booking prevention failed');
            if (!this.testResults.uiConsistency) console.log('   - UI consistency issues detected');
        }
    }
}

// Run the test
if (require.main === module) {
    const test = new MultiUserBookingTest();
    test.runMultiUserTest().catch(console.error);
}

module.exports = MultiUserBookingTest;
