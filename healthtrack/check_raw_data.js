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

async function checkRawData() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Check raw data using direct query
    console.log('\n=== RAW SERVICES_CONFIG DATA ===');
    const [servicesRows] = await connection.execute('SELECT id, service_name, required_fields, available_days FROM services_config');
    
    for (const row of servicesRows) {
      console.log(`\nService: ${row.service_name} (ID: ${row.id})`);
      console.log(`  Required fields: ${JSON.stringify(row.required_fields)}`);
      console.log(`  Available days: ${JSON.stringify(row.available_days)}`);
      
      // Check the actual string value
      if (row.required_fields !== null) {
        console.log(`  Required fields (toString): "${row.required_fields.toString()}"`);
      }
      if (row.available_days !== null) {
        console.log(`  Available days (toString): "${row.available_days.toString()}"`);
      }
    }
    
    console.log('\n=== RAW HEALTH_WORKERS DATA ===');
    const [workersRows] = await connection.execute('SELECT id, worker_name, assigned_services FROM health_workers');
    
    for (const row of workersRows) {
      console.log(`\nWorker: ${row.worker_name} (ID: ${row.id})`);
      console.log(`  Assigned services: ${JSON.stringify(row.assigned_services)}`);
      
      // Check the actual string value
      if (row.assigned_services !== null) {
        console.log(`  Assigned services (toString): "${row.assigned_services.toString()}"`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error checking raw data:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the function
checkRawData();