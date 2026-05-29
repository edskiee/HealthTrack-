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

async function verifyAndFixData() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Check current data format
    console.log('\n=== CURRENT SERVICES_CONFIG DATA ===');
    const [servicesRows] = await connection.execute('SELECT id, service_name, required_fields, available_days FROM services_config');
    
    for (const row of servicesRows) {
      console.log(`\nService: ${row.service_name} (ID: ${row.id})`);
      console.log(`  Required fields: ${row.required_fields} (type: ${typeof row.required_fields})`);
      console.log(`  Available days: ${row.available_days} (type: ${typeof row.available_days})`);
      
      // Check if it's already valid JSON
      let isRequiredFieldsValid = false;
      let isAvailableDaysValid = false;
      
      try {
        if (row.required_fields) {
          JSON.parse(row.required_fields);
          isRequiredFieldsValid = true;
        }
      } catch (e) {
        isRequiredFieldsValid = false;
      }
      
      try {
        if (row.available_days) {
          JSON.parse(row.available_days);
          isAvailableDaysValid = true;
        }
      } catch (e) {
        isAvailableDaysValid = false;
      }
      
      console.log(`  Valid JSON - Required fields: ${isRequiredFieldsValid}, Available days: ${isAvailableDaysValid}`);
      
      // If not valid JSON, fix it
      if (!isRequiredFieldsValid || !isAvailableDaysValid) {
        console.log('  Fixing data...');
        
        // Fix required_fields
        let fixedRequiredFields = '[]';
        if (row.required_fields && typeof row.required_fields === 'string') {
          if (row.required_fields.startsWith('[') && row.required_fields.endsWith(']')) {
            // Already JSON array
            fixedRequiredFields = row.required_fields;
          } else if (row.required_fields.includes(',')) {
            // Comma-separated string
            const fieldsArray = row.required_fields.split(',').map(field => field.trim());
            fixedRequiredFields = JSON.stringify(fieldsArray);
          } else {
            // Single value
            fixedRequiredFields = JSON.stringify([row.required_fields.trim()]);
          }
        }
        
        // Fix available_days
        let fixedAvailableDays = '[]';
        if (row.available_days && typeof row.available_days === 'string') {
          if (row.available_days.startsWith('[') && row.available_days.endsWith(']')) {
            // Already JSON array
            fixedAvailableDays = row.available_days;
          } else if (row.available_days.includes(',')) {
            // Comma-separated string
            const daysArray = row.available_days.split(',').map(day => day.trim());
            fixedAvailableDays = JSON.stringify(daysArray);
          } else {
            // Single value
            fixedAvailableDays = JSON.stringify([row.available_days.trim()]);
          }
        }
        
        console.log(`    Fixed required_fields: ${fixedRequiredFields}`);
        console.log(`    Fixed available_days: ${fixedAvailableDays}`);
        
        // Update the row
        await connection.execute(
          'UPDATE services_config SET required_fields = ?, available_days = ? WHERE id = ?',
          [fixedRequiredFields, fixedAvailableDays, row.id]
        );
        console.log(`    ✅ Service ID ${row.id} updated successfully`);
      }
    }
    
    // Check health_workers data
    console.log('\n=== CURRENT HEALTH_WORKERS DATA ===');
    const [workersRows] = await connection.execute('SELECT id, worker_name, assigned_services FROM health_workers');
    
    for (const row of workersRows) {
      console.log(`\nWorker: ${row.worker_name} (ID: ${row.id})`);
      console.log(`  Assigned services: ${row.assigned_services} (type: ${typeof row.assigned_services})`);
      
      // Check if it's already valid JSON
      let isAssignedServicesValid = false;
      
      try {
        if (row.assigned_services) {
          JSON.parse(row.assigned_services);
          isAssignedServicesValid = true;
        }
      } catch (e) {
        isAssignedServicesValid = false;
      }
      
      console.log(`  Valid JSON - Assigned services: ${isAssignedServicesValid}`);
      
      // If not valid JSON, fix it
      if (!isAssignedServicesValid) {
        console.log('  Fixing data...');
        
        // Fix assigned_services
        let fixedAssignedServices = '[]';
        if (row.assigned_services && typeof row.assigned_services === 'string') {
          if (row.assigned_services.startsWith('[') && row.assigned_services.endsWith(']')) {
            // Already JSON array
            fixedAssignedServices = row.assigned_services;
          } else if (row.assigned_services.includes(',')) {
            // Comma-separated string of numbers
            const servicesArray = row.assigned_services.split(',').map(service => {
              const num = parseInt(service.trim());
              return isNaN(num) ? service.trim() : num;
            });
            fixedAssignedServices = JSON.stringify(servicesArray);
          } else {
            // Single value
            const serviceValue = row.assigned_services.trim();
            const num = parseInt(serviceValue);
            const finalValue = isNaN(num) ? serviceValue : num;
            fixedAssignedServices = JSON.stringify([finalValue]);
          }
        }
        
        console.log(`    Fixed assigned_services: ${fixedAssignedServices}`);
        
        // Update the row
        await connection.execute(
          'UPDATE health_workers SET assigned_services = ? WHERE id = ?',
          [fixedAssignedServices, row.id]
        );
        console.log(`    ✅ Worker ID ${row.id} updated successfully`);
      }
    }
    
    console.log('\n✅ Data verification and fixing completed!');
    
  } catch (error) {
    console.error('❌ Error verifying and fixing data:', error.message);
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
verifyAndFixData();