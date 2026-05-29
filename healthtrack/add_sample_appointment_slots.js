// Script to add sample appointment slots for December 16, 2025
// For demonstration purposes only

const mysql = require('mysql2/promise');

// Database connection configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'healthtrack'
};

async function addSampleSlots() {
  let connection;
  
  try {
    // Create database connection
    connection = await mysql.createConnection(dbConfig);
    
    // First, let's get the service IDs for Maternal Care and Immunization
    const [services] = await connection.execute(
      "SELECT id, service_name FROM services_config WHERE service_name IN ('Maternal Care', 'Immunization')"
    );
    
    console.log('Available services:');
    services.forEach(service => {
      console.log(`- ${service.service_name}: ID ${service.id}`);
    });
    
    // Get service IDs
    const maternalCareService = services.find(s => s.service_name === 'Maternal Care');
    const immunizationService = services.find(s => s.service_name === 'Immunization');
    
    if (!maternalCareService || !immunizationService) {
      console.error('Required services not found in database');
      return;
    }
    
    const targetDate = '2025-12-16';
    
    // Delete any existing slots for this date to avoid duplicates
    await connection.execute(
      "DELETE FROM appointment_slots WHERE appointment_date = ? AND service_id IN (?, ?)",
      [targetDate, maternalCareService.id, immunizationService.id]
    );
    
    console.log(`\nDeleted existing slots for ${targetDate}`);
    
    // Add 5 sample slots for Maternal Care (9:00 AM to 1:00 PM)
    const maternalCareSlots = [
      { start: '09:00:00', end: '09:30:00' },
      { start: '09:40:00', end: '10:10:00' }, // 10-minute break
      { start: '10:20:00', end: '10:50:00' }, // 10-minute break
      { start: '11:00:00', end: '11:30:00' }, // 10-minute break
      { start: '11:40:00', end: '12:10:00' }  // 10-minute break
    ];
    
    for (const slot of maternalCareSlots) {
      await connection.execute(
        `INSERT INTO appointment_slots 
         (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, booked_patients, is_available)
         VALUES (?, ?, ?, ?, 30, 1, 0, 1)`,
        [maternalCareService.id, targetDate, slot.start, slot.end]
      );
    }
    
    console.log(`Added ${maternalCareSlots.length} slots for Maternal Care on ${targetDate}`);
    
    // Add 5 sample slots for Immunization (2:00 PM to 6:00 PM)
    const immunizationSlots = [
      { start: '14:00:00', end: '14:30:00' },
      { start: '14:40:00', end: '15:10:00' }, // 10-minute break
      { start: '15:20:00', end: '15:50:00' }, // 10-minute break
      { start: '16:00:00', end: '16:30:00' }, // 10-minute break
      { start: '16:40:00', end: '17:10:00' }  // 10-minute break
    ];
    
    for (const slot of immunizationSlots) {
      await connection.execute(
        `INSERT INTO appointment_slots 
         (service_id, appointment_date, start_time, end_time, slot_duration_minutes, max_patients, booked_patients, is_available)
         VALUES (?, ?, ?, ?, 30, 1, 0, 1)`,
        [immunizationService.id, targetDate, slot.start, slot.end]
      );
    }
    
    console.log(`Added ${immunizationSlots.length} slots for Immunization on ${targetDate}`);
    
    // Verify the slots were added
    const [addedSlots] = await connection.execute(
      `SELECT s.*, sc.service_name 
       FROM appointment_slots s 
       JOIN services_config sc ON s.service_id = sc.id 
       WHERE s.appointment_date = ? 
       ORDER BY s.service_id, s.start_time`,
      [targetDate]
    );
    
    console.log(`\nTotal slots added: ${addedSlots.length}`);
    console.log('\nSlot details:');
    addedSlots.forEach(slot => {
      console.log(`${slot.service_name}: ${slot.start_time} - ${slot.end_time} (${slot.max_patients - slot.booked_patients} available)`);
    });
    
    console.log('\n✅ Sample appointment slots added successfully!');
    console.log(`📅 Date: ${targetDate}`);
    console.log(`🏥 Services: Maternal Care (ID: ${maternalCareService.id}), Immunization (ID: ${immunizationService.id})`);
    console.log(`🎫 Slots per service: 5`);
    
  } catch (error) {
    console.error('Error adding sample slots:', error);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run the script
addSampleSlots();