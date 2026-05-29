// Comprehensive FCM Notification System Validation Test
process.env.TEST_MODE = 'true';

const http = require('http');

console.log('===========================================');
console.log('HealthTrack Comprehensive FCM Validation Test');
console.log('===========================================');

// Test scenarios
const testScenarios = [
    {
        name: 'Test 1: Basic Appointment Reminder',
        patientId: "72",
        title: "Test Appointment Reminder",
        message: "This is a test appointment reminder notification"
    },
    {
        name: 'Test 2: Check Patient FCM Token Status',
        patientId: "72"
    },
    {
        name: 'Test 3: General Patient Notification',
        patientId: "72",
        title: "General Health Update",
        message: "This is a general health notification",
        notificationType: "general"
    }
];

async function runTest(testScenario) {
    console.log(`\n${testScenario.name}`);
    console.log('-'.repeat(testScenario.name.length));
    
    const postData = JSON.stringify(testScenario);
    
    // Determine endpoint based on test type
    let endpoint = '/fcm-notifications/appointment-reminder';
    if (testScenario.name.includes('Check Patient')) {
        endpoint = '/fcm-notifications/check-patient-token';
    } else if (testScenario.name.includes('General')) {
        endpoint = '/fcm-notifications/patient-notification';
    }
    
    const options = {
        hostname: 'localhost',
        port: 3000,
        path: endpoint,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    return new Promise((resolve) => {
        const req = http.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                console.log(`Status: ${res.statusCode}`);
                
                try {
                    const responseData = JSON.parse(data);
                    console.log(`Response: ${JSON.stringify(responseData, null, 2)}`);
                    
                    if (res.statusCode === 200 && responseData.success) {
                        console.log('SUCCESS: Test passed');
                        resolve({ success: true, result: responseData });
                    } else {
                        console.log('FAILED: Test failed');
                        resolve({ success: false, result: responseData });
                    }
                } catch (parseError) {
                    console.log(`Raw Response: ${data}`);
                    console.log(`Parse Error: ${parseError.message}`);
                    resolve({ success: false, error: parseError.message });
                }
            });
        });

        req.on('error', (error) => {
            console.log(`Request Error: ${error.message}`);
            resolve({ success: false, error: error.message });
        });

        req.write(postData);
        req.end();
    });
}

async function runAllTests() {
    console.log('\nStarting comprehensive FCM notification system validation...\n');
    
    const results = [];
    
    for (const scenario of testScenarios) {
        const result = await runTest(scenario);
        results.push({ scenario: scenario.name, ...result });
        
        // Add delay between tests
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    console.log('\n===========================================');
    console.log('COMPREHENSIVE TEST RESULTS SUMMARY');
    console.log('===========================================');
    
    let passedTests = 0;
    let failedTests = 0;
    
    results.forEach(result => {
        if (result.success) {
            console.log(`PASS: ${result.scenario}`);
            passedTests++;
        } else {
            console.log(`FAIL: ${result.scenario}`);
            failedTests++;
            
            // Provide specific troubleshooting guidance
            if (result.result && result.result.error) {
                if (result.result.error.includes('Invalid argument in FCM message')) {
                    console.log('  -> Issue: FCM message structure contains unsupported fields');
                    console.log('  -> Fix: Remove unsupported fields from FCM message payload');
                } else if (result.result.error.includes('FCM token')) {
                    console.log('  -> Issue: Invalid or missing FCM token');
                    console.log('  -> Fix: Ensure patient has valid FCM token in database');
                } else if (result.result.error.includes('Patient not found')) {
                    console.log('  -> Issue: Patient ID not found in database');
                    console.log('  -> Fix: Verify patient exists in patients table');
                }
            }
        }
    });
    
    console.log(`\nTotal Tests: ${results.length}`);
    console.log(`Passed: ${passedTests}`);
    console.log(`Failed: ${failedTests}`);
    
    if (failedTests > 0) {
        console.log('\nNEXT STEPS:');
        console.log('1. Fix FCM message structure issues');
        console.log('2. Update invalid FCM tokens in database');
        console.log('3. Verify Firebase project configuration');
        console.log('4. Test with real FCM tokens from mobile app');
    } else {
        console.log('\nAll tests passed! FCM notification system is working correctly.');
    }
    
    console.log('===========================================');
}

// Run all tests
runAllTests().catch(console.error);
