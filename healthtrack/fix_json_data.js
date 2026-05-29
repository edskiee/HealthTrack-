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

async function fixJsonData() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Fix services_config table data
    console.log('\n=== FIXING SERVICES_CONFIG TABLE DATA ===');
    const [servicesRows] = await connection.execute('SELECT id, required_fields, available_days FROM services_config');
    
    for (const row of servicesRows) {
      console.log(`\nFixing service ID ${row.id}:`);
      
      // Fix required_fields
      let fixedRequiredFields = '[]';
      if (row.required_fields && typeof row.required_fields === 'object') {
        const fieldsString = row.required_fields.toString();
        if (fieldsString.includes(',')) {
          const fieldsArray = fieldsString.split(',').map(field => field.trim());
          fixedRequiredFields = JSON.stringify(fieldsArray);
        } else {
          fixedRequiredFields = JSON.stringify([fieldsString.trim()]);
        }
        console.log(`  Required fields: ${fieldsString} -> ${fixedRequiredFields}`);
      }
      
      // Fix available_days
      let fixedAvailableDays = '[]';
      if (row.available_days && typeof row.available_days === 'object') {
        const daysString = row.available_days.toString();
        if (daysString.includes(',')) {
          const daysArray = daysString.split(',').map(day => day.trim());
          fixedAvailableDays = JSON.stringify(daysArray);
        } else {
          fixedAvailableDays = JSON.stringify([daysString.trim()]);
        }
        console.log(`  Available days: ${daysString} -> ${fixedAvailableDays}`);
      }
      
      // Update the row
      await connection.execute(
        'UPDATE services_config SET required_fields = ?, available_days = ? WHERE id = ?',
        [fixedRequiredFields, fixedAvailableDays, row.id]
      );
      console.log(`  ✅ Service ID ${row.id} updated successfully`);
    }
    
    // Fix health_workers table data
    console.log('\n=== FIXING HEALTH_WORKERS TABLE DATA ===');
    const [workersRows] = await connection.execute('SELECT id, assigned_services FROM health_workers');
    
    for (const row of workersRows) {
      console.log(`\nFixing worker ID ${row.id}:`);
      
      // Fix assigned_services
      let fixedAssignedServices = '[]';
      if (row.assigned_services && typeof row.assigned_services === 'object') {
        const servicesString = row.assigned_services.toString();
        if (servicesString.includes(',')) {
          const servicesArray = servicesString.split(',').map(service => parseInt(service.trim())).filter(service => !isNaN(service));
          fixedAssignedServices = JSON.stringify(servicesArray);
        } else {
          const serviceId = parseInt(servicesString.trim());
          fixedAssignedServices = isNaN(serviceId) ? '[]' : JSON.stringify([serviceId]);
        }
        console.log(`  Assigned services: ${servicesString} -> ${fixedAssignedServices}`);
      }
      
      // Update the row
      await connection.execute(
        'UPDATE health_workers SET assigned_services = ? WHERE id = ?',
        [fixedAssignedServices, row.id]
      );
      console.log(`  ✅ Worker ID ${row.id} updated successfully`);
    }
    
    console.log('\n✅ All data fixed successfully!');
    
  } catch (error) {
    console.error('❌ Error fixing JSON data:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the function
fixJsonData();