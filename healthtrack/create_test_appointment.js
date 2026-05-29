/**
 * Create a test appointment for testing notifications
 */

const db = require('./backend_nodejs/src/config/db');

async function createTestAppointment() {
  try {
    console.log('=== Creating Test Appointment ===');
    
    // Get a test user
    const [users] = await db.execute('SELECT id, full_name FROM users WHERE id = 1');
    
    if (users.length === 0) {
      console.log('No test user found with ID 1');
      return;
    }
    
    const testUser = users[0];
    console.log(`Using test user: ${testUser.full_name} (ID: ${testUser.id})`);
    
    // Check for existing patient or create one
    let patientId;
    const [existingPatients] = await db.execute('SELECT id FROM patients WHERE user_id = ? LIMIT 1', [testUser.id]);
    
    if (existingPatients.length === 0) {
      // Create a test patient
      const [patientResult] = await db.execute(`
        INSERT INTO patients (user_id, child_fullname, child_age, child_gender, created_at, updated_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `, [
        testUser.id,
        'Test Child',
        5,
        'Male'
      ]);
      patientId = patientResult.insertId;
      console.log(`Created test patient with ID: ${patientId}`);
    } else {
      patientId = existingPatients[0].id;
      console.log(`Using existing patient with ID: ${patientId}`);
    }
    
    // Create a test appointment
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const appointmentDate = tomorrow.toISOString().split('T')[0];
    const appointmentTime = '10:00';
    
    const sql = `
      INSERT INTO appointments 
      (user_id, patient_id, appointment_date, appointment_time, appointment_type, doctor_name, clinic_hospital, status, notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `;
    
    const [result] = await db.execute(sql, [
      testUser.id,
      patientId,
      appointmentDate,
      appointmentTime,
      'General Checkup',
      'Dr. Smith',
      'HealthTrack Clinic',
      'approved',
      'Test appointment for notification system'
    ]);
    
    const appointmentId = result.insertId;
    console.log(`\n=== Test Appointment Created ===`);
    console.log(`Appointment ID: ${appointmentId}`);
    console.log(`User ID: ${testUser.id}`);
    console.log(`Date: ${appointmentDate}`);
    console.log(`Time: ${appointmentTime}`);
    console.log(`Type: General Checkup`);
    console.log(`Status: approved`);
    
    return appointmentId;
    
  } catch (error) {
    console.error('Error creating test appointment:', error);
    throw error;
  }
}

// Run the function
createTestAppointment()
  .then(appointmentId => {
    console.log(`\nTest appointment ${appointmentId} created successfully!`);
    console.log('You can now run the notification tests with this appointment ID.');
    process.exit(0);
  })
  .catch(error => {
    console.error('Failed to create test appointment:', error);
    process.exit(1);
  });
