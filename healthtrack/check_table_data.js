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

async function checkTableData() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection(dbConfig);
    console.log('✅ Connected to MySQL database');
    
    // Check services_config table data
    console.log('\n=== SERVICES_CONFIG TABLE DATA ===');
    const [servicesRows] = await connection.execute('SELECT * FROM services_config');
    console.log(`Found ${servicesRows.length} services:`);
    servicesRows.forEach((row, index) => {
      console.log(`\nService ${index + 1}:`);
      Object.keys(row).forEach(key => {
        console.log(`  ${key}: ${row[key]} (type: ${typeof row[key]})`);
      });
    });
    
    // Check health_workers table data
    console.log('\n=== HEALTH_WORKERS TABLE DATA ===');
    const [workersRows] = await connection.execute('SELECT * FROM health_workers');
    console.log(`Found ${workersRows.length} workers:`);
    workersRows.forEach((row, index) => {
      console.log(`\nWorker ${index + 1}:`);
      Object.keys(row).forEach(key => {
        console.log(`  ${key}: ${row[key]} (type: ${typeof row[key]})`);
      });
    });
    
  } catch (error) {
    console.error('❌ Error checking table data:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n✅ Database connection closed');
    }
  }
}

// Run the function
checkTableData();