const db = require('./src/config/db');

async function normalizeAppointmentDates() {
  console.log('🔄 Starting appointment date normalization...');
  
  try {
    // Check current MySQL timezone
    const [timezoneResult] = await db.execute('SELECT @@global.time_zone, @@session.time_zone');
    console.log('📍 Current MySQL timezone settings:', timezoneResult[0]);
    
    // Set session timezone to Asia/Manila
    await db.execute("SET time_zone = '+08:00'");
    console.log('✅ Session timezone set to Asia/Manila (+08:00)');
    
    // Check appointments table structure
    const [appointmentsStructure] = await db.execute('DESCRIBE appointments');
    const appointmentDateColumn = appointmentsStructure.find(col => col.Field === 'appointment_date');
    console.log('📋 Appointments table appointment_date column:', appointmentDateColumn);
    
    // Check appointment_slots table structure  
    const [slotsStructure] = await db.execute('DESCRIBE appointment_slots');
    const slotDateColumn = slotsStructure.find(col => col.Field === 'appointment_date');
    console.log('📋 Appointment_slots table appointment_date column:', slotDateColumn);
    
    // Normalize appointments table - ensure all dates are in YYYY-MM-DD format
    console.log('🔧 Normalizing appointments table...');
    
    // Check for any datetime-formatted dates
    const [invalidAppointmentDates] = await db.execute(`
      SELECT id, appointment_date 
      FROM appointments 
      WHERE appointment_date LIKE '% %'
    `);
    
    if (invalidAppointmentDates.length > 0) {
      console.log(`⚠️  Found ${invalidAppointmentDates.length} appointments with datetime format, fixing...`);
      
      for (const appointment of invalidAppointmentDates) {
        // Convert datetime to date-only format
        const dateOnly = appointment.appointment_date.split(' ')[0];
        await db.execute(
          'UPDATE appointments SET appointment_date = ? WHERE id = ?',
          [dateOnly, appointment.id]
        );
        console.log(`✅ Fixed appointment ${appointment.id}: ${appointment.appointment_date} -> ${dateOnly}`);
      }
    } else {
      console.log('✅ All appointment dates are already in correct format');
    }
    
    // Normalize appointment_slots table
    console.log('🔧 Normalizing appointment_slots table...');
    
    const [invalidSlotDates] = await db.execute(`
      SELECT id, appointment_date 
      FROM appointment_slots 
      WHERE appointment_date LIKE '% %'
    `);
    
    if (invalidSlotDates.length > 0) {
      console.log(`⚠️  Found ${invalidSlotDates.length} slots with datetime format, fixing...`);
      
      for (const slot of invalidSlotDates) {
        const dateOnly = slot.appointment_date.split(' ')[0];
        await db.execute(
          'UPDATE appointment_slots SET appointment_date = ? WHERE id = ?',
          [dateOnly, slot.id]
        );
        console.log(`✅ Fixed slot ${slot.id}: ${slot.appointment_date} -> ${dateOnly}`);
      }
    } else {
      console.log('✅ All slot dates are already in correct format');
    }
    
    // Verify the fixes by sampling some records
    console.log('🔍 Verifying normalized data...');
    
    const [sampleAppointments] = await db.execute(`
      SELECT id, appointment_date 
      FROM appointments 
      ORDER BY id DESC 
      LIMIT 5
    `);
    
    console.log('📅 Sample appointment dates:', sampleAppointments);
    
    const [sampleSlots] = await db.execute(`
      SELECT id, appointment_date 
      FROM appointment_slots 
      ORDER BY id DESC 
      LIMIT 5
    `);
    
    console.log('📅 Sample slot dates:', sampleSlots);
    
    // Test date comparison queries
    console.log('🧪 Testing date comparison queries...');
    
    const today = new Date().toISOString().slice(0, 10);
    const [futureAppointments] = await db.execute(`
      SELECT COUNT(*) as count 
      FROM appointments 
      WHERE appointment_date >= ?
    `, [today]);
    
    console.log(`📊 Appointments from ${today} onwards:`, futureAppointments[0].count);
    
    const [futureSlots] = await db.execute(`
      SELECT COUNT(*) as count 
      FROM appointment_slots 
      WHERE appointment_date >= ?
    `, [today]);
    
    console.log(`📊 Slots from ${today} onwards:`, futureSlots[0].count);
    
    console.log('✅ Appointment date normalization completed successfully!');
    
  } catch (error) {
    console.error('❌ Error during normalization:', error);
  } finally {
    await db.end();
  }
}

// Run the normalization
normalizeAppointmentDates();
