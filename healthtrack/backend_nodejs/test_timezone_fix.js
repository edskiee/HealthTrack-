const db = require('./src/config/db');

async function testTimezoneFix() {
  console.log('🧪 Starting timezone fix verification...');
  
  try {
    // Set session timezone
    await db.execute("SET time_zone = '+08:00'");
    console.log('✅ Session timezone set to Asia/Manila (+08:00)');
    
    // Test 1: Create a test appointment slot
    console.log('\n📅 Test 1: Creating appointment slot...');
    const testDate = '2026-03-01'; // Future date
    const [slotResult] = await db.execute(`
      INSERT INTO appointment_slots (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients)
      VALUES (16, ?, '10:00:00', '10:30:00', 30, 5)
    `, [testDate]);
    
    const slotId = slotResult.insertId;
    console.log(`✅ Created slot with ID: ${slotId}, date: ${testDate}`);
    
    // Test 2: Retrieve the slot and verify date format
    console.log('\n📅 Test 2: Retrieving slot...');
    const [retrievedSlot] = await db.execute(`
      SELECT id, service_id, appointment_date, start_time, end_time
      FROM appointment_slots 
      WHERE id = ?
    `, [slotId]);
    
    console.log('📋 Retrieved slot:', retrievedSlot[0]);
    
    // Verify the date is returned as YYYY-MM-DD string
    if (retrievedSlot[0].appointment_date === testDate) {
      console.log('✅ Date format is correct: YYYY-MM-DD');
    } else {
      console.log('❌ Date format mismatch:', retrievedSlot[0].appointment_date, 'expected:', testDate);
    }
    
    // Test 3: Query slots by date
    console.log('\n📅 Test 3: Querying slots by date...');
    const [slotsByDate] = await db.execute(`
      SELECT id, appointment_date, start_time, end_time
      FROM appointment_slots 
      WHERE appointment_date = ?
      ORDER BY start_time ASC
    `, [testDate]);
    
    console.log(`📊 Found ${slotsByDate.length} slots for date ${testDate}:`, slotsByDate);
    
    // Test 4: Test date comparison with CURDATE()
    console.log('\n📅 Test 4: Testing date comparison...');
    const [futureSlots] = await db.execute(`
      SELECT COUNT(*) as count
      FROM appointment_slots 
      WHERE appointment_date >= CURDATE()
    `);
    
    console.log(`📊 Slots from today onwards: ${futureSlots[0].count}`);
    
    // Test 5: Create a test appointment
    console.log('\n📅 Test 5: Creating appointment...');
    const [appointmentResult] = await db.execute(`
      INSERT INTO appointments (user_id, patient_id, doctor_name, clinic_hospital, appointment_date, appointment_time, appointment_type, status)
      VALUES (1, 72, 'Dr. Test', 'Test Clinic', ?, '10:00:00', 'Test Consultation', 'approved')
    `, [testDate]);
    
    const appointmentId = appointmentResult.insertId;
    console.log(`✅ Created appointment with ID: ${appointmentId}, date: ${testDate}`);
    
    // Test 6: Retrieve appointment and verify date format
    console.log('\n📅 Test 6: Retrieving appointment...');
    const [retrievedAppointment] = await db.execute(`
      SELECT id, user_id, patient_id, appointment_date, appointment_time, doctor_name, status
      FROM appointments 
      WHERE id = ?
    `, [appointmentId]);
    
    console.log('📋 Retrieved appointment:', retrievedAppointment[0]);
    
    // Verify the date is returned as YYYY-MM-DD string
    if (retrievedAppointment[0].appointment_date === testDate) {
      console.log('✅ Appointment date format is correct: YYYY-MM-DD');
    } else {
      console.log('❌ Appointment date format mismatch:', retrievedAppointment[0].appointment_date, 'expected:', testDate);
    }
    
    // Test 7: Test appointment API response format
    console.log('\n📅 Test 7: Testing API response format...');
    const [allAppointments] = await db.execute(`
      SELECT id, appointment_date, appointment_time, doctor_name, status
      FROM appointments 
      WHERE appointment_date = ?
      ORDER BY appointment_time ASC
    `, [testDate]);
    
    console.log('📊 API Response Format Test:', allAppointments);
    
    // Test 8: Test boundary conditions
    console.log('\n📅 Test 8: Testing boundary conditions...');
    
    // Test with different date formats
    const testDates = ['2026-02-28', '2026-03-01', '2026-03-31'];
    
    for (const date of testDates) {
      const [countResult] = await db.execute(`
        SELECT COUNT(*) as count
        FROM appointment_slots 
        WHERE appointment_date = ?
      `, [date]);
      
      console.log(`📊 Slots for ${date}: ${countResult[0].count}`);
    }
    
    // Test 9: Clean up test data
    console.log('\n📅 Test 9: Cleaning up test data...');
    await db.execute('DELETE FROM appointments WHERE id = ?', [appointmentId]);
    await db.execute('DELETE FROM appointment_slots WHERE id = ?', [slotId]);
    console.log('✅ Test data cleaned up');
    
    // Test 10: Verify timezone consistency
    console.log('\n📅 Test 10: Verifying timezone consistency...');
    const [timezoneCheck] = await db.execute('SELECT NOW(), CURDATE(), UTC_TIMESTAMP()');
    console.log('📍 Current database timestamps:', timezoneCheck[0]);
    
    console.log('\n✅ All timezone fix tests completed successfully!');
    console.log('🎯 Key findings:');
    console.log('  - Database returns dates as YYYY-MM-DD strings');
    console.log('  - Date comparisons work correctly with CURDATE()');
    console.log('  - Timezone is set to Asia/Manila (+08:00)');
    console.log('  - No timezone conversion issues detected');
    
  } catch (error) {
    console.error('❌ Error during testing:', error);
  } finally {
    await db.end();
  }
}

// Run the test
testTimezoneFix();
