// Test database connectivity and notifications table existence
const mysql = require('mysql2/promise');

// Database configuration (from backend config)
const dbConfig = {
  host: 'localhost',
  user: 'root',
  password: 'edwin15',
  database: 'healthtrack',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

async function testDatabaseConnection() {
  let pool;
  
  try {
    console.log('Testing database connection...');
    
    // Create connection pool
    pool = mysql.createPool(dbConfig);
    console.log('✅ Database connection pool created');
    
    // Get a connection from the pool
    const connection = await pool.getConnection();
    console.log('✅ Got connection from pool');
    
    // Test if notifications table exists
    console.log('\nChecking if notifications table exists...');
    const [rows] = await connection.execute(
      "SHOW TABLES LIKE 'notifications'"
    );
    
    if (rows.length > 0) {
      console.log('✅ Notifications table exists');
      
      // Test querying the table
      console.log('\nTesting query on notifications table...');
      const [notifications] = await connection.execute(
        "SELECT COUNT(*) as count FROM notifications"
      );
      console.log(`✅ Query successful, found ${notifications[0].count} notifications`);
      
    } else {
      console.log('❌ Notifications table does not exist');
    }
    
    // Release connection back to pool
    connection.release();
    console.log('\n✅ Database test completed successfully');
    
  } catch (error) {
    console.error('❌ Database test failed:', error.message);
  }
}

testDatabaseConnection();