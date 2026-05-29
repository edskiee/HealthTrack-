/**
 * HealthTrack Automated Reminder System Test Script
 * This script tests the complete notification system functionality
 * Run with: node test_reminder_system.js
 */

const { createAppointmentReminderSchedule, checkAndSendDueReminders, getUserUpcomingReminders, cleanupOldReminders } = require('./src/services/appointmentReminderService');
const { startNotificationScheduler, stopNotificationScheduler, getSchedulerStatus, manualReminderCheck, manualCleanup } = require('./src/services/notificationScheduler');
const { sendPushNotification } = require('./src/services/firebaseService');
const db = require('./src/config/db');

// Test configuration
const TEST_CONFIG = {
    testUserId: 1,
    testAppointmentDate: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 4 days from now
    testAppointmentTime: '10:00:00',
    testAppointmentType: 'Test Check-up',
    testDoctorName: 'Dr. Test Doctor',
    testClinic: 'Test Clinic',
    testFcmToken: 'test_fcm_token_for_validation'
};

// Test results tracker
const testResults = {
    passed: 0,
    failed: 0,
    total: 0,
    details: []
};

/**
 * Helper function to log test results
 */
function logTest(testName, success, details = '') {
    testResults.total++;
    if (success) {
        testResults.passed++;
        console.log(`✅ ${testName}: PASSED ${details ? '- ' + details : ''}`);
    } else {
        testResults.failed++;
        console.log(`❌ ${testName}: FAILED ${details ? '- ' + details : ''}`);
    }
    testResults.details.push({ testName, success, details });
}

/**
 * Test 1: Database Connection
 */
async function testDatabaseConnection() {
    try {
        const [results] = await db.execute('SELECT 1 as test');
        logTest('Database Connection', results.length > 0, 'Successfully connected to database');
        return true;
    } catch (error) {
        logTest('Database Connection', false, error.message);
        return false;
    }
}

/**
 * Test 2: System Settings
 */
async function testSystemSettings() {
    try {
        const [results] = await db.execute(`
            SELECT setting_key, setting_value 
            FROM system_settings 
            WHERE setting_key IN ('appointment_reminders_enabled', 'reminder_days_before', 'reminders_per_day', 'reminder_times')
        `);
        
        const settings = {};
        results.forEach(row => {
            settings[row.setting_key] = row.setting_value;
        });
        
        const hasRequiredSettings = settings.appointment_reminders_enabled && 
                                  settings.reminder_days_before && 
                                  settings.reminders_per_day && 
                                  settings.reminder_times;
        
        logTest('System Settings', hasRequiredSettings, `Found ${Object.keys(settings).length} settings`);
        return hasRequiredSettings;
    } catch (error) {
        logTest('System Settings', false, error.message);
        return false;
    }
}

/**
 * Test 3: Create Test Appointment
 */
async function createTestAppointment() {
    try {
        const [result] = await db.execute(`
            INSERT INTO appointments (
                user_id, appointment_date, appointment_time, appointment_type, 
                doctor_name, clinic_hospital, status
            ) VALUES (?, ?, ?, ?, ?, ?, 'approved')
        `, [
            TEST_CONFIG.testUserId,
            TEST_CONFIG.testAppointmentDate,
            TEST_CONFIG.testAppointmentTime,
            TEST_CONFIG.testAppointmentType,
            TEST_CONFIG.testDoctorName,
            TEST_CONFIG.testClinic
        ]);
        
        const appointmentId = result.insertId;
        logTest('Create Test Appointment', appointmentId > 0, `Created appointment ID: ${appointmentId}`);
        return appointmentId;
    } catch (error) {
        logTest('Create Test Appointment', false, error.message);
        return null;
    }
}

/**
 * Test 4: Create Reminder Schedule
 */
async function testCreateReminderSchedule(appointmentId) {
    try {
        const result = await createAppointmentReminderSchedule(
            appointmentId,
            TEST_CONFIG.testAppointmentDate,
            TEST_CONFIG.testAppointmentTime,
            TEST_CONFIG.testUserId
        );
        
        logTest('Create Reminder Schedule', result.success, result.message);
        return result.success;
    } catch (error) {
        logTest('Create Reminder Schedule', false, error.message);
        return false;
    }
}

/**
 * Test 5: Get User Upcoming Reminders
 */
async function testGetUserUpcomingReminders() {
    try {
        const reminders = await getUserUpcomingReminders(TEST_CONFIG.testUserId);
        logTest('Get User Upcoming Reminders', Array.isArray(reminders), `Found ${reminders.length} reminders`);
        return true;
    } catch (error) {
        logTest('Get User Upcoming Reminders', false, error.message);
        return false;
    }
}

/**
 * Test 6: Notification Scheduler
 */
async function testNotificationScheduler() {
    try {
        // Start scheduler
        const startResult = await startNotificationScheduler();
        logTest('Start Notification Scheduler', startResult.success, startResult.message);
        
        if (startResult.success) {
            // Check status
            const status = getSchedulerStatus();
            logTest('Scheduler Status Check', status.isRunning, `Running: ${status.isRunning}, Tasks: ${status.activeTasks}`);
            
            // Manual reminder check
            const checkResult = await manualReminderCheck();
            logTest('Manual Reminder Check', checkResult.success, checkResult.message);
        }
        
        return startResult.success;
    } catch (error) {
        logTest('Notification Scheduler', false, error.message);
        return false;
    }
}

/**
 * Test 7: FCM Token Validation
 */
async function testFcmTokenValidation() {
    try {
        // Save test FCM token
        await db.execute('UPDATE users SET fcm_token = ? WHERE id = ?', [TEST_CONFIG.testFcmToken, TEST_CONFIG.testUserId]);
        
        // Test FCM validation (in test mode, this should pass)
        const result = await sendPushNotification(TEST_CONFIG.testFcmToken, {
            title: 'Test Notification',
            body: 'This is a test notification',
            notificationType: 'test'
        });
        
        logTest('FCM Token Validation', result.success, result.message);
        return result.success;
    } catch (error) {
        logTest('FCM Token Validation', false, error.message);
        return false;
    }
}

/**
 * Test 8: Check Due Reminders
 */
async function testCheckDueReminders() {
    try {
        const result = await checkAndSendDueReminders();
        logTest('Check Due Reminders', result.success, result.message);
        return result.success;
    } catch (error) {
        logTest('Check Due Reminders', false, error.message);
        return false;
    }
}

/**
 * Test 9: Cleanup Old Reminders
 */
async function testCleanupOldReminders() {
    try {
        const result = await cleanupOldReminders();
        logTest('Cleanup Old Reminders', result.success, `Deleted ${result.deletedCount || 0} old reminders`);
        return result.success;
    } catch (error) {
        logTest('Cleanup Old Reminders', false, error.message);
        return false;
    }
}

/**
 * Test 10: Reminder Schedule Integrity
 */
async function testReminderScheduleIntegrity(appointmentId) {
    try {
        const [reminders] = await db.execute(`
            SELECT COUNT(*) as count, 
                   COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
                   COUNT(CASE WHEN status = 'sent' THEN 1 END) as sent,
                   COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed
            FROM appointment_reminders 
            WHERE appointment_id = ?
        `, [appointmentId]);
        
        const stats = reminders[0];
        const hasExpectedReminders = stats.count >= 3; // Should have 3 reminders (1 day before, 3 times)
        
        logTest('Reminder Schedule Integrity', hasExpectedReminders, 
               `Total: ${stats.count}, Scheduled: ${stats.scheduled}, Sent: ${stats.sent}, Failed: ${stats.failed}`);
        return hasExpectedReminders;
    } catch (error) {
        logTest('Reminder Schedule Integrity', false, error.message);
        return false;
    }
}

/**
 * Cleanup test data
 */
async function cleanupTestData(appointmentId) {
    try {
        if (appointmentId) {
            await db.execute('DELETE FROM appointment_reminders WHERE appointment_id = ?', [appointmentId]);
            await db.execute('DELETE FROM appointments WHERE id = ?', [appointmentId]);
        }
        await db.execute('UPDATE users SET fcm_token = NULL WHERE id = ?', [TEST_CONFIG.testUserId]);
        console.log('🧹 Test data cleaned up');
    } catch (error) {
        console.error('❌ Error cleaning up test data:', error);
    }
}

/**
 * Main test runner
 */
async function runTests() {
    console.log('🚀 Starting HealthTrack Automated Reminder System Tests\n');
    console.log('📋 Test Configuration:');
    console.log(`   User ID: ${TEST_CONFIG.testUserId}`);
    console.log(`   Appointment Date: ${TEST_CONFIG.testAppointmentDate}`);
    console.log(`   Appointment Time: ${TEST_CONFIG.testAppointmentTime}`);
    console.log(`   FCM Token: ${TEST_CONFIG.testFcmToken.substring(0, 20)}...\n`);
    
    let appointmentId = null;
    
    try {
        // Run tests in sequence
        await testDatabaseConnection();
        await testSystemSettings();
        appointmentId = await createTestAppointment();
        
        if (appointmentId) {
            await testCreateReminderSchedule(appointmentId);
            await testGetUserUpcomingReminders();
            await testReminderScheduleIntegrity(appointmentId);
        }
        
        await testNotificationScheduler();
        await testFcmTokenValidation();
        await testCheckDueReminders();
        await testCleanupOldReminders();
        
    } catch (error) {
        console.error('❌ Unexpected error during testing:', error);
    } finally {
        // Cleanup
        await cleanupTestData(appointmentId);
        
        // Stop scheduler if it was started
        try {
            await stopNotificationScheduler();
        } catch (error) {
            console.warn('⚠️ Error stopping scheduler:', error.message);
        }
    }
    
    // Print final results
    console.log('\n📊 Test Results Summary:');
    console.log(`   Total Tests: ${testResults.total}`);
    console.log(`   Passed: ${testResults.passed}`);
    console.log(`   Failed: ${testResults.failed}`);
    console.log(`   Success Rate: ${((testResults.passed / testResults.total) * 100).toFixed(1)}%`);
    
    if (testResults.failed > 0) {
        console.log('\n❌ Failed Tests:');
        testResults.details
            .filter(test => !test.success)
            .forEach(test => console.log(`   - ${test.testName}: ${test.details}`));
    }
    
    console.log('\n🎯 Automated Reminder System Test Complete!');
    
    // Exit with appropriate code
    process.exit(testResults.failed > 0 ? 1 : 0);
}

// Handle uncaught errors
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

process.on('uncaughtException', (error) => {
    console.error('❌ Uncaught Exception:', error);
    process.exit(1);
});

// Run tests
if (require.main === module) {
    runTests();
}

module.exports = {
    runTests,
    testDatabaseConnection,
    testSystemSettings,
    createTestAppointment,
    testCreateReminderSchedule,
    testNotificationScheduler,
    testFcmTokenValidation,
    testCheckDueReminders,
    cleanupTestData,
    TEST_CONFIG
};
