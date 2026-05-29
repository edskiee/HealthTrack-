const mysql = require('mysql2/promise');

// Database configuration
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function insertCorrectData() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Clear existing data
    console.log('\n=== CLEARING EXISTING DATA ===');
    await connection.execute('DELETE FROM health_worker_schedule');
    await connection.execute('DELETE FROM health_workers');
    await connection.execute('DELETE FROM services_config');
    
    // Insert services_config data with proper JSON
    console.log('\n=== INSERTING SERVICES_CONFIG DATA ===');
    const servicesData = [
      {
        service_name: 'Immunization',
        service_description: 'Child immunization and vaccination services',
        service_type: 'immunization',
        is_enabled: true,
        required_fields: JSON.stringify(['child_name', 'vaccine_type', 'date_of_birth', 'parent_guardian']),
        available_days: JSON.stringify(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
        max_appointments_per_day: 30
      },
      {
        service_name: 'Maternal Care',
        service_description: 'Prenatal and postnatal care services for mothers',
        service_type: 'maternal',
        is_enabled: true,
        required_fields: JSON.stringify(['mother_name', 'expected_delivery_date', 'contact_number', 'address']),
        available_days: JSON.stringify(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
        max_appointments_per_day: 20
      },
      {
        service_name: 'Dental Checkup',
        service_description: 'Pediatric dental examination and cleaning',
        service_type: 'dental',
        is_enabled: true,
        required_fields: JSON.stringify(['child_name', 'date_of_birth', 'parent_guardian', 'emergency_contact']),
        available_days: JSON.stringify(['Monday', 'Wednesday', 'Friday']),
        max_appointments_per_day: 15
      },
      {
        service_name: 'EPI Program',
        service_description: 'Expanded Program on Immunization services',
        service_type: 'epi',
        is_enabled: true,
        required_fields: JSON.stringify(['child_name', 'vaccine_type', 'date_of_birth', 'parent_guardian']),
        available_days: JSON.stringify(['Tuesday', 'Thursday', 'Saturday']),
        max_appointments_per_day: 25
      },
      {
        service_name: 'General Checkup',
        service_description: 'Routine pediatric health checkup',
        service_type: 'checkup',
        is_enabled: true,
        required_fields: JSON.stringify(['child_name', 'date_of_birth', 'parent_guardian', 'reason_for_visit']),
        available_days: JSON.stringify(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']),
        max_appointments_per_day: 40
      }
    ];
    
    for (const service of servicesData) {
      const query = `
        INSERT INTO services_config 
        (service_name, service_description, service_type, is_enabled, required_fields, available_days, max_appointments_per_day)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `;
      
      const values = [
        service.service_name,
        service.service_description,
        service.service_type,
        service.is_enabled,
        service.required_fields,
        service.available_days,
        service.max_appointments_per_day
      ];
      
      const [result] = await connection.execute(query, values);
      console.log(`✅ Inserted service: ${service.service_name} (ID: ${result.insertId})`);
    }
    
    // Insert health_workers data with proper JSON
    console.log('\n=== INSERTING HEALTH_WORKERS DATA ===');
    const workersData = [
      {
        worker_name: 'Dr. Maria Santos',
        role: 'Pediatrician',
        specialization: 'Child Development',
        email: 'maria.santos@healthtrack.com',
        phone: '+639123456789',
        is_active: true,
        assigned_services: JSON.stringify([1, 5])
      },
      {
        worker_name: 'Dr. Juan Dela Cruz',
        role: 'OB-GYN',
        specialization: 'Maternal Care',
        email: 'juan.delacruz@healthtrack.com',
        phone: '+639123456790',
        is_active: true,
        assigned_services: JSON.stringify([2])
      },
      {
        worker_name: 'Dr. Ana Reyes',
        role: 'Dentist',
        specialization: 'Pediatric Dentistry',
        email: 'ana.reyes@healthtrack.com',
        phone: '+639123456791',
        is_active: true,
        assigned_services: JSON.stringify([3])
      },
      {
        worker_name: 'Dr. Carlos Garcia',
        role: 'Nurse',
        specialization: 'Immunization',
        email: 'carlos.garcia@healthtrack.com',
        phone: '+639123456792',
        is_active: true,
        assigned_services: JSON.stringify([1, 4])
      }
    ];
    
    for (const worker of workersData) {
      const query = `
        INSERT INTO health_workers 
        (worker_name, role, specialization, email, phone, is_active, assigned_services)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `;
      
      const values = [
        worker.worker_name,
        worker.role,
        worker.specialization,
        worker.email,
        worker.phone,
        worker.is_active,
        worker.assigned_services
      ];
      
      const [result] = await connection.execute(query, values);
      console.log(`✅ Inserted worker: ${worker.worker_name} (ID: ${result.insertId})`);
    }
    
    console.log('\n✅ All data inserted successfully!');
    
    // Verify the data
    console.log('\n=== VERIFYING INSERTED DATA ===');
    const [services] = await connection.execute('SELECT id, service_name, required_fields, available_days FROM services_config');
    console.log('Services:');
    services.forEach(service => {
      console.log(`  ${service.service_name}:`);
      console.log(`    Required fields: ${service.required_fields}`);
      console.log(`    Available days: ${service.available_days}`);
    });
    
    const [workers] = await connection.execute('SELECT id, worker_name, assigned_services FROM health_workers');
    console.log('Workers:');
    workers.forEach(worker => {
      console.log(`  ${worker.worker_name}:`);
      console.log(`    Assigned services: ${worker.assigned_services}`);
    });
    
  } catch (error) {
    console.error('❌ Error inserting correct data:', error.message);
    if (error.stack) {
      console.error('Stack trace:', error.stack);
    }
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the function
insertCorrectData();