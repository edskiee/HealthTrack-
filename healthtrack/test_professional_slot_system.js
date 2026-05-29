// Comprehensive Test for Professional Slot Configuration System
// Tests the new automated slot calculation and custom duration features

const http = require('http');

// Configuration
const BASE_URL = 'http://localhost:3000';

// Helper function to make HTTP requests
function makeRequest(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
    
    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

// Test 1: Verify API Health and Service Availability
async function testApiHealth() {
  console.log('\n🧪 Test 1: API Health and Service Availability');
  
  try {
    // Test health endpoint
    const healthOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/',
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    };
    
    const healthResponse = await makeRequest(healthOptions);
    console.log(`   Health Status: ${healthResponse.statusCode}`);
    console.log(`   Success: ${healthResponse.body?.success || 'N/A'}`);
    
    // Test services endpoint
    const serviceOptions = {
      hostname: 'localhost',
      port: 3000,
      path: '/service-config',
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    };
    
    const serviceResponse = await makeRequest(serviceOptions);
    console.log(`   Services Status: ${serviceResponse.statusCode}`);
    console.log(`   Services Count: ${serviceResponse.body?.data?.length || 0}`);
    
    if (serviceResponse.body?.success && serviceResponse.body?.data?.length > 0) {
      console.log('   ✅ PASS: API is healthy and services are available');
      return serviceResponse.body.data;
    } else {
      console.log('  ❌ FAIL: Services not available');
      return null;
    }
  } catch (error) {
    console.error('   ❌ ERROR:', error.message);
    return null;
  }
}

// Test 2: Test Custom Duration Slot Generation
async function testCustomDurationSlotGeneration(services) {
  console.log('\n🧪 Test 2: Custom Duration Slot Generation');
  
  if (!services || services.length === 0) {
    console.log('   ❌ FAIL: No services available for testing');
    return false;
  }
  
  const service = services[0]; // Use first available service
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  
  // Test cases with different custom durations
  const testCases = [
    { duration: 15, startTime: '09:00:00', endTime: '10:00:00', expectedSlots: 4 },
    { duration: 20, startTime: '10:00:00', endTime: '11:00:00', expectedSlots: 3 },
    { duration: 45, startTime: '13:00:00', endTime: '16:00:00', expectedSlots: 4 },
    { duration: 90, startTime: '08:00:00', endTime: '12:00:00', expectedSlots: 2 }
  ];
  
  let allTestsPassed = true;
  
  for (const testCase of testCases) {
    try {
      console.log(`\n   Testing ${testCase.duration}-minute slots from ${testCase.startTime} to ${testCase.endTime}`);
      
      const slotOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/appointment-slots',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const slotData = JSON.stringify({
        service_id: service.id,
        appointment_date: tomorrow,
        start_time: testCase.startTime,
        end_time: testCase.endTime,
        slot_duration_minutes: testCase.duration,
        max_patients: 10,
        generate_slots: true
      });
      
      const slotResponse = await makeRequest(slotOptions, slotData);
      console.log(`   Status: ${slotResponse.statusCode}`);
      console.log(`   Success: ${slotResponse.body?.success}`);
      console.log(`   Generated Slots: ${slotResponse.body?.data?.length || 0}`);
      console.log(`   Expected Slots: ${testCase.expectedSlots}`);
      
      if (slotResponse.body?.success && 
          slotResponse.body?.data?.length === testCase.expectedSlots) {
        console.log(`   ✅ PASS: Correctly generated ${testCase.expectedSlots} slots`);
      } else {
        console.log(`   ❌ FAIL: Expected ${testCase.expectedSlots} slots, got ${slotResponse.body?.data?.length || 0}`);
        allTestsPassed = false;
      }
      
      // Clean up - delete generated slots
      if (slotResponse.body?.data) {
        for (const slot of slotResponse.body.data) {
          try {
            const deleteOptions = {
              hostname: 'localhost',
              port: 3000,
              path: `/appointment-slots/${slot.id}`,
              method: 'DELETE',
              headers: { 'Content-Type': 'application/json' }
            };
            await makeRequest(deleteOptions);
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
      
    } catch (error) {
      console.error(`   ❌ ERROR: ${error.message}`);
      allTestsPassed = false;
    }
  }
  
  return allTestsPassed;
}

// Test 3: Test Invalid Duration and Edge Cases
async function testInvalidDurationValidation(services) {
  console.log('\n🧪 Test 3: Invalid Duration and Edge Case Validation');
  
  if (!services || services.length === 0) {
    console.log('   ❌ FAIL: No services available for testing');
    return false;
  }
  
  const service = services[0];
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  
  const invalidCases = [
    { duration: -15, description: "Negative duration" },
    { duration: 0, description: "Zero duration" },
    { duration: 500, description: "Duration exceeding 8 hours" },
    { duration: "invalid", description: "Invalid duration format" }
  ];
  
  let allTestsPassed = true;
  
  for (const testCase of invalidCases) {
    try {
      console.log(`\n   Testing: ${testCase.description} (${testCase.duration})`);
      
      const slotOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/appointment-slots',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const slotData = JSON.stringify({
        service_id: service.id,
        appointment_date: tomorrow,
        start_time: '09:00:00',
        end_time: '10:00:00',
        slot_duration_minutes: testCase.duration,
        max_patients: 10,
        generate_slots: true
      });
      
      const slotResponse = await makeRequest(slotOptions, slotData);
      console.log(`   Status: ${slotResponse.statusCode}`);
      console.log(`   Success: ${slotResponse.body?.success}`);
      console.log(`   Message: ${slotResponse.body?.message || 'N/A'}`);
      
      // Should fail with 400 status for invalid inputs
      if (slotResponse.statusCode === 400 && !slotResponse.body?.success) {
        console.log(`  ✅ PASS: Correctly rejected invalid duration`);
      } else {
        console.log(`   ❌ FAIL: Should have rejected invalid duration`);
        allTestsPassed = false;
      }
      
    } catch (error) {
      console.error(`   ❌ ERROR: ${error.message}`);
      allTestsPassed = false;
    }
  }
  
  return allTestsPassed;
}

// Test 4: Test Time Range Validation
async function testTimeRangeValidation(services) {
  console.log('\n🧪 Test 4: Time Range Validation');
  
  if (!services || services.length === 0) {
    console.log('   ❌ FAIL: No services available for testing');
    return false;
  }
  
  const service = services[0];
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  
  const timeRangeTests = [
    {
      startTime: '17:00:00',
      endTime: '09:00:00',
      description: "End time before start time"
    },
    {
      startTime: '08:00:00',
      endTime: '07:00:00',
      description: "End time much earlier than start time"
    }
  ];
  
  let allTestsPassed = true;
  
  for (const testCase of timeRangeTests) {
    try {
      console.log(`\n   Testing: ${testCase.description}`);
      
      const slotOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/appointment-slots',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const slotData = JSON.stringify({
        service_id: service.id,
        appointment_date: tomorrow,
        start_time: testCase.startTime,
        end_time: testCase.endTime,
        slot_duration_minutes: 30,
        max_patients: 10,
        generate_slots: true
      });
      
      const slotResponse = await makeRequest(slotOptions, slotData);
      console.log(`   Status: ${slotResponse.statusCode}`);
      console.log(`   Success: ${slotResponse.body?.success}`);
      console.log(`   Message: ${slotResponse.body?.message || 'N/A'}`);
      
      // Should fail with 400 status for invalid time ranges
      if (slotResponse.statusCode === 400 && !slotResponse.body?.success) {
        console.log(`  ✅ PASS: Correctly rejected invalid time range`);
      } else {
        console.log(`  ❌ FAIL: Should have rejected invalid time range`);
        allTestsPassed = false;
      }
      
    } catch (error) {
      console.error(`  ❌ ERROR: ${error.message}`);
      allTestsPassed = false;
    }
  }
  
  return allTestsPassed;
}

// Test 5: Test Real-time Slot Calculation Accuracy
async function testSlotCalculationAccuracy(services) {
  console.log('\n🧪 Test 5: Real-time Slot Calculation Accuracy');
  
  if (!services || services.length === 0) {
    console.log('   ❌ FAIL: No services available for testing');
    return false;
  }
  
  const service = services[0];
  const tomorrow = new Date(Date.now() + 86400000).toISOString().split('T')[0];
  
  // Test mathematical accuracy of slot calculation
  const calculationTests = [
    {
      startTime: '09:00:00',
      endTime: '12:00:00',
      duration: 30,
      expectedSlots: 6, // 3 hours = 180 minutes / 30 minutes = 6 slots
      description: "3-hour range with 30-minute intervals"
    },
    {
      startTime: '10:15:00',
      endTime: '11:45:00',
      duration: 45,
      expectedSlots: 2, // 1.5 hours = 90 minutes / 45 minutes = 2 slots
      description: "1.5-hour range with 45-minute intervals"
    },
    {
      startTime: '14:30:00',
      endTime: '17:00:00',
      duration: 20,
      expectedSlots: 7, // 2.5 hours = 150 minutes / 20 minutes = 7.5, so 7 full slots
      description: "2.5-hour range with 20-minute intervals"
    }
  ];
  
  let allTestsPassed = true;
  
  for (const testCase of calculationTests) {
    try {
      console.log(`\n   Testing: ${testCase.description}`);
      
      const slotOptions = {
        hostname: 'localhost',
        port: 3000,
        path: '/appointment-slots',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      };
      
      const slotData = JSON.stringify({
        service_id: service.id,
        appointment_date: tomorrow,
        start_time: testCase.startTime,
        end_time: testCase.endTime,
        slot_duration_minutes: testCase.duration,
        max_patients: 10,
        generate_slots: true
      });
      
      const slotResponse = await makeRequest(slotOptions, slotData);
      console.log(`   Status: ${slotResponse.statusCode}`);
      console.log(`   Success: ${slotResponse.body?.success}`);
      console.log(`   Generated Slots: ${slotResponse.body?.data?.length || 0}`);
      console.log(`   Expected Slots: ${testCase.expectedSlots}`);
      
      if (slotResponse.body?.success && 
          slotResponse.body?.data?.length === testCase.expectedSlots) {
        console.log(`  ✅ PASS: Calculation accurate (${testCase.expectedSlots} slots)`);
      } else {
        console.log(`   ❌ FAIL: Calculation inaccurate. Expected ${testCase.expectedSlots}, got ${slotResponse.body?.data?.length || 0}`);
        allTestsPassed = false;
      }
      
      // Clean up generated slots
      if (slotResponse.body?.data) {
        for (const slot of slotResponse.body.data) {
          try {
            const deleteOptions = {
              hostname: 'localhost',
              port: 3000,
              path: `/appointment-slots/${slot.id}`,
              method: 'DELETE',
              headers: { 'Content-Type': 'application/json' }
            };
            await makeRequest(deleteOptions);
          } catch (e) {
            // Ignore cleanup errors
          }
        }
      }
      
    } catch (error) {
      console.error(`   ❌ ERROR: ${error.message}`);
      allTestsPassed = false;
    }
  }
  
  return allTestsPassed;
}

// Main test execution
async function runAllTests() {
  console.log('🚀 Starting Professional Slot Configuration System Tests');
  console.log('='.repeat(60));
  
  let overallSuccess = true;
  
  try {
    // Test 1: API Health
    const services = await testApiHealth();
    if (!services) {
      console.log('\n❌ ABORTING: API not responding or no services available');
      return;
    }
    
    // Test 2: Custom Duration Generation
    const customDurationTest = await testCustomDurationSlotGeneration(services);
    if (!customDurationTest) overallSuccess = false;
    
    // Test 3: Invalid Duration Validation
    const invalidDurationTest = await testInvalidDurationValidation(services);
    if (!invalidDurationTest) overallSuccess = false;
    
    // Test 4: Time Range Validation
    const timeRangeTest = await testTimeRangeValidation(services);
    if (!timeRangeTest) overallSuccess = false;
    
    // Test 5: Calculation Accuracy
    const calculationTest = await testSlotCalculationAccuracy(services);
    if (!calculationTest) overallSuccess = false;
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(60));
    
    if (overallSuccess) {
      console.log('🎉 ALL TESTS PASSED!');
      console.log('✅ Professional Slot Configuration System is working correctly');
      console.log('✅ Custom duration support is functional');
      console.log('✅ Real-time calculation is accurate');
      console.log('✅ Validation is properly implemented');
    } else {
      console.log('❌ SOME TESTS FAILED');
      console.log('⚠️  Please review the failed test cases above');
    }
    
    console.log('\n📋 Key Features Verified:');
    console.log('  • Automatic slot calculation based on time range and duration');
    console.log('  • Custom duration support (any positive integer minutes)');
    console.log('  • Real-time validation and error handling');
    console.log('  • Mathematical accuracy in slot generation');
    console.log('  • Proper error responses for invalid inputs');
    
  } catch (error) {
    console.error('\n💥 FATAL ERROR:', error.message);
    console.log('❌ Test suite failed to complete');
  }
}

// Run the tests
runAllTests();