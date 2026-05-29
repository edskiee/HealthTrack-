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

async function detailedTest() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Test the exact query that the service uses
    console.log('\n=== TESTING SERVICES_CONFIG QUERY ===');
    const query = 'SELECT * FROM services_config ORDER BY service_name';
    const [rows] = await connection.execute(query);
    
    console.log(`Found ${rows.length} services:`);
    rows.forEach((row, index) => {
      console.log(`\nService ${index + 1}: ${row.service_name}`);
      console.log(`  ID: ${row.id}`);
      console.log(`  Required fields: ${JSON.stringify(row.required_fields)} (type: ${typeof row.required_fields})`);
      console.log(`  Available days: ${JSON.stringify(row.available_days)} (type: ${typeof row.available_days})`);
      
      // Try to parse the data
      try {
        if (row.required_fields) {
          if (Array.isArray(row.required_fields)) {
            console.log(`  ✅ Required fields is already an array: ${JSON.stringify(row.required_fields)}`);
          } else if (typeof row.required_fields === 'string') {
            if (row.required_fields.startsWith('[')) {
              const parsed = JSON.parse(row.required_fields);
              console.log(`  ✅ Required fields parsed as JSON: ${JSON.stringify(parsed)}`);
            } else {
              console.log(`  ℹ Required fields is a string: "${row.required_fields}"`);
            }
          }
        }
      } catch (e) {
        console.log(`  ❌ Error parsing required_fields: ${e.message}`);
      }
      
      try {
        if (row.available_days) {
          if (Array.isArray(row.available_days)) {
            console.log(`  ✅ Available days is already an array: ${JSON.stringify(row.available_days)}`);
          } else if (typeof row.available_days === 'string') {
            if (row.available_days.startsWith('[')) {
              const parsed = JSON.parse(row.available_days);
              console.log(`  ✅ Available days parsed as JSON: ${JSON.stringify(parsed)}`);
            } else {
              console.log(`  ℹ Available days is a string: "${row.available_days}"`);
            }
          }
        }
      } catch (e) {
        console.log(`  ❌ Error parsing available_days: ${e.message}`);
      }
    });
    
    // Test the health_workers query
    console.log('\n=== TESTING HEALTH_WORKERS QUERY ===');
    const workersQuery = `
      SELECT hw.*, 
             (SELECT COUNT(*) FROM health_worker_schedule WHERE worker_id = hw.id AND is_available = 1) as schedule_count
      FROM health_workers hw 
      ORDER BY hw.worker_name
    `;
    const [workerRows] = await connection.execute(workersQuery);
    
    console.log(`Found ${workerRows.length} workers:`);
    workerRows.forEach((row, index) => {
      console.log(`\nWorker ${index + 1}: ${row.worker_name}`);
      console.log(`  ID: ${row.id}`);
      console.log(`  Assigned services: ${JSON.stringify(row.assigned_services)} (type: ${typeof row.assigned_services})`);
      
      // Try to parse the data
      try {
        if (row.assigned_services) {
          if (Array.isArray(row.assigned_services)) {
            console.log(`  ✅ Assigned services is already an array: ${JSON.stringify(row.assigned_services)}`);
          } else if (typeof row.assigned_services === 'string') {
            if (row.assigned_services.startsWith('[')) {
              const parsed = JSON.parse(row.assigned_services);
              console.log(`  ✅ Assigned services parsed as JSON: ${JSON.stringify(parsed)}`);
            } else {
              console.log(`  ℹ Assigned services is a string: "${row.assigned_services}"`);
            }
          }
        }
      } catch (e) {
        console.log(`  ❌ Error parsing assigned_services: ${e.message}`);
      }
    });
    
  } catch (error) {
    console.error('❌ Error in detailed test:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the function
detailedTest();