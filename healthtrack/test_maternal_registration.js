const db = require('./backend_nodejs/src/config/db');

async function testMaternalRegistration() {
  const connection = await db.getConnection();
  
  try {
    console.log('Testing maternal registration SQL query...');
    
    // Start transaction
    await connection.beginTransaction();
    
    // First, create a test user with unique username
    const timestamp = Date.now();
    const userInsertQuery = `
      INSERT INTO users (
        username, email, password, full_name, phone, address, service_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    
    const [userInsertResult] = await connection.execute(userInsertQuery, [
      `testuser_maternal_${timestamp}`,
      `testuser_maternal_${timestamp}@example.com`,
      'password123',
      'Test Mother',
      '1234567890',
      'Test Address, City, Province',
      'maternal'
    ]);
    
    const newUserId = userInsertResult.insertId;
    console.log(`✅ Created test user with ID: ${newUserId}`);
    
    // Now test the maternal patient insertion (the fixed query)
    const patientInsertQuery = `
      INSERT INTO patients (
        user_id, mother_fullname, father_fullname, child_fullname, dob,
        place_of_birth, birth_weight, birth_height, sex, address, status, service_type,
        record_type, record_description,
        family_serial_number, contact_number, spouse_name, living_children_count, 
        monthly_income, religion, city, province, age, education, occupation, 
        birth_attendant, facility_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    
    const patientValues = [
      newUserId, // Link patient to user
      'Test Mother',
      'Test Father',
      'Test Child',
      '1990-01-01',
      'Test Hospital',
      '3.5 kg',
      '50 cm',
      'Female',
      'Test Address, City, Province',
      'active', // Status value
      'maternal', // Set patient service type to match user service type
      'Maternal Care',
      'Maternal care patient record',
      'FAM-001', // family_serial_number
      '1234567890',
      'Test Spouse',
      2,
      50000.00,
      'Christian',
      'City',
      'Province',
      30,
      'College',
      'Engineer',
      'SBA',
      'Hospital'
    ];
    
    const [patientInsertResult] = await connection.execute(patientInsertQuery, patientValues);
    
    const newPatientId = patientInsertResult.insertId;
    console.log(`✅ Created maternal patient record with ID: ${newPatientId}`);
    
    // Create initial health record for the patient
    const healthRecordSql = `
      INSERT INTO health_records (
        user_id, patient_id, record_type, title, description, date_recorded
      ) VALUES (?, ?, ?, ?, ?, CURDATE())
    `;
    
    const healthRecordValues = [
      newUserId,
      newPatientId,
      'Maternal Care',
      'Initial Health Record',
      'Health record created upon user registration'
    ];
    
    await connection.execute(healthRecordSql, healthRecordValues);
    console.log(`✅ Created initial health record for patient ID: ${newPatientId}`);
    
    // Rollback the transaction to clean up test data
    await connection.rollback();
    console.log('✅ Test completed successfully and rolled back');
    
  } catch (error) {
    await connection.rollback();
    console.error('❌ Error testing maternal registration:', error.message);
    if (error.sql) {
      console.error('Query:', error.sql);
    }
    if (error.sqlMessage) {
      console.error('SQL Message:', error.sqlMessage);
    }
    process.exit(1);
  } finally {
    connection.release();
  }
}

testMaternalRegistration();