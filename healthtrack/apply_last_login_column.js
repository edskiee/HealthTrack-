const mysql = require('mysql2/promise');
require('dotenv').config();

async function applyLastLoginColumn() {
  let connection;
  
  try {
    // Create connection
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'healthtrack'
    });
    
    console.log('✅ Connected to database');
    
    // Check if last_login column exists
    const [columns] = await connection.execute(
      "SHOW COLUMNS FROM users LIKE 'last_login'"
    );
    
    if (columns.length > 0) {
      console.log('✅ last_login column already exists');
    } else {
      // Add last_login column
      await connection.execute(
        "ALTER TABLE users ADD COLUMN last_login TIMESTAMP NULL AFTER updated_at"
      );
      console.log('✅ Added last_login column to users table');
    }
    
    // Close connection
    await connection.end();
    console.log('✅ Database connection closed');
    
  } catch (error) {
    console.error('❌ Error applying last_login column:', error);
    if (connection) {
      await connection.end();
    }
    process.exit(1);
  }
}

// Run the function
applyLastLoginColumn();